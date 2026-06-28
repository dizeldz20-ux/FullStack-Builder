# Config-Only Repo Build: Verified Baseline Pattern

When the user asks to build a project from `plan.md` (or equivalent) and the
result is **configuration only** — no custom runtime code, just YAML/MD/sh
files that wire an existing tool together — use this pattern. It is the safe
default for any "voice agent / bot / glue project" built on top of an existing
agent runtime (Hermes, LangChain, custom CLI, etc.).

The pattern is: **never claim a config works without an executable smoke test
that proves it**. The smoke test runs against the real config and a fake or
real key, prints exactly which step passed and which failed, and exits 0 only
on full pass.

## Why this exists

A "config-only" repo is the easiest kind to lie about. There is no build
command, no test suite, no runtime error you can hit. The default failure
mode is:

- Agent writes `config.yaml`, `.env.example`, and a `setup.sh`.
- Agent says "done, push it."
- User pushes, runs `setup.sh`, hits a 401, has no idea which provider or
  which env var is wrong, and files a bug.
- Agent never knew the config was wrong because the agent never ran it.

The verified baseline pattern eliminates this by making the config *executable*
on the agent's side: the agent runs a smoke test, sees real pass/fail output,
and reports that to the user. The user runs the same script on their side and
gets the same output. There is one source of truth.

## The four files, always

For any config-only repo built on an existing runtime, ship these four files:

1. **`config/<name>.yaml`** — the actual config. Comments at the top explain
   every block. Never includes secrets.
2. **`config/.env.example`** — template for env vars. No real values. Each
   key has a one-line comment: where to get it, what it gates, what to do
   if it is missing.
3. **`scripts/setup.sh`** — installs the config into the runtime's home
   directory (e.g., `~/.hermes/config.yaml`). Must be:
   - Idempotent (re-runnable)
   - Backed up (timestamped, e.g., `config.yaml.bak.YYYYMMDD-HHMMSS`)
   - Non-destructive on missing files (create parent dirs, do not assume
     the runtime's config already exists)
   - Tested with `HERMES_HOME=/tmp/staging` before touching the real home
4. **`scripts/verify-baseline.sh`** — smoke test. Must be:
   - Self-contained (sources env from a known location, runs curl/python
     inline, prints pass/fail per step)
   - Exit 0 only on full pass, exit 1 on any failure
   - Print every step's HTTP code, file size, or key it tested
   - Mask any value that might be a secret (use a `mask()` helper that
     shows `first4...last4` for `>8 char` strings, `***` for shorter)
   - Have a "fake key" mode for testing that the auth header / URL pattern
     is right (a 401 from a dummy key is still useful evidence)

## The verify-baseline script shape

A working `verify-baseline.sh` looks like this in spirit:

```bash
#!/usr/bin/env bash
set -uo pipefail

# 1. Environment — print where keys are loaded from
# 2. CLI presence — is the runtime on PATH?
# 3. Key presence — is each required key in env? (no values echoed)
# 4. LLM ping — does the brain respond to a one-line test prompt in the
#    project's target language? (prints first 400 chars of response)
# 5. TTS ping — does the speech provider produce an audio file? (prints
#    HTTP code, file size, leaves the file in $TMPDIR for the next step)
# 6. STT round-trip — feed the TTS output back through STT, verify the
#    transcript contains the original text (proves both directions work)
# 7. Summary — print pass count, fail count, exit code
```

The LLM step is the most important. It is the only one that does not require
a real key (in most setups, the LLM is already configured for the agent's own
work). Running it proves the YAML is parseable, the provider URLs are right,
and the language the project targets actually works end-to-end.

## Pitfalls this pattern catches

1. **YAML syntax errors.** `yaml.safe_load` will throw on a typo; the merge
   step in `setup.sh` will print a clear error. The agent runs the merge
   in staging, so it sees the error before the user does.

2. **Missing keys in the runtime's existing config.** If `~/.hermes/config.yaml`
   already has 200 lines of other config and the merge would clobber
   something, the merge script must shallow-merge (dict-by-dict) and only
   override keys that the project owns. The pattern is to define a
   `PROJECT_KEYS = [...]` list at the top of the merge script and only touch
   those keys.

3. **Secrets in committed files.** Run `grep -rE "(sk-[a-zA-Z0-9]{20,}|sk_live_|maton_live_)" config/ scripts/ docs/ README.md` before every commit. If any
   match, fail the commit and explain.

4. **`HERMES_HOME=foo cmd` not propagating to subshells.** This is a real
   bash gotcha. `HERMES_HOME=/tmp/staging ./scripts/setup.sh` works; the
   `env` prefix is not needed. `HERMES_HOME=/tmp/staging setup.sh` with the
   var declared on the same line as the command works. But running it inside
   a script where the var was set in a previous line may not propagate to a
   child `bash -c`. Test the staging path explicitly; do not assume.

5. **Glob expansion of `***` in tool strings.** When a script string contains
   the literal characters `***` (e.g., a token-mask like `Bearer *** `),
   `bash` and the agent's own tool pipeline can glob-expand the asterisks
   to file lists. Workaround: build the string with `printf '%s' "value"`
   or use single quotes for the literal portion. Verify by reading the
   file back after writing and confirming the string is intact.

6. **Bash `case` block parsing of parentheses in echo strings.** A `case`
   arm that contains `echo "..." (parentheses) ...` will be misparsed.
   Workaround: use `{}` or `[]` in echo strings inside `case` blocks. Run
   `bash -n <script>` after every edit to catch this early.

## The "what to commit" rule

Before commit, run this exact sequence:

1. `git status` — confirm only the files you intended changed
2. `git diff --stat` — confirm the diff is the right shape (no surprise
   rewrites of large files)
3. `grep -rE "(sk-|gsk_|maton_live_|secret.*=)" config/ scripts/ docs/`
   — confirm zero secrets
4. `bash -n scripts/*.sh` — confirm every script parses
5. `./scripts/verify-baseline.sh` — confirm the smoke test still runs
   (even if it fails on missing keys; the failure mode is informative)
6. `git remote -v` — confirm the target remote before any push
7. `git add <exact files>` — never `git add .` in a repo with secrets in
   working tree (e.g., a `.env` from previous runs)
8. `git commit -m "..."` — one coherent change per commit

## When to push

Do not push until:

- The user has run the smoke test on their side and it passed.
- OR the user has explicitly asked for a push to a specific branch (e.g.,
  "push to a feature branch, I'll review before merge").

If pushing to a personal repo on the user's own account, push when the user
asks. If pushing to a shared repo, push only when the user has approved a
specific remote + branch + commit message. The standard "verify the remote
before destructive actions" rule applies.

## Worked example: voice agent repo built from plan.md

What the agent did, in order, in a session that worked well:

1. Read the existing `PLAN.md` (404 lines) and identified what was
   already-implemented vs aspirational vs wrong-about-the-current-state.
2. Asked 3 focused clarification questions (gateway choice, default STT,
   key file location) — answers came from a 3-option multiple choice.
3. Built the four files in a single commit. Ran the smoke test, which
   passed 4/8 (LLM, hermes CLI, both mask-present checks) and failed 4/8
   (TTS, STT) for the correct reason: keys not set.
4. The user then pasted a real API key into chat. The agent refused to
   use it (see `agent-repo-security-vetter` SKILL "Hard Rules"), built
   gateway support anyway with no key required, and committed a second
   time. The repo works without a key; keys are an optional upgrade.

The user ends up with a repo they can run on their machine in two commands
(`./scripts/setup.sh` + `./scripts/verify-baseline.sh`), with a clear
documented path from "no keys" to "all green."

## Related references

- `agent-repo-security-vetter` — covers the secret-in-chat refusal pattern
  that this pattern assumes
- `incremental-hardening-refactor` — the parent skill; this file is the
  "config-only build" slice of that broader workflow
