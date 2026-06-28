---
name: incremental-hardening-refactor
description: Safely harden a live codebase and perform small refactors with full verification and commit checkpoints after each change.
version: 1.2.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [refactor, hardening, regression-safety, testing, git]
    related_skills: [systematic-debugging, subagent-driven-development, requesting-code-review]
---

# Incremental Hardening + Refactor Workflow

Use when a user wants you to keep improving a real repository step-by-step (security hardening, auth/storage cleanup, dependency stabilization, modularization) while minimizing regression risk.

## When this skill fits

- The codebase is already working and must stay working.
- The user wants multiple consecutive improvements, not one isolated patch.
- Some changes are security-sensitive (session storage, API keys, auth callbacks).
- The project has a large central file that should be reduced gradually.
- You need confidence after each step before moving on to the next one.
- The project is about to be handed off to someone else — see the
  [Pre-handoff install-readiness pass](references/install-readiness-pass.md)
  (fresh-clone simulation, .env verification traps, "I'm sure" anti-pattern).

## Core approach

Do NOT batch many unrelated changes into one big refactor.
Instead:
1. Identify one concrete risk.
2. Make the smallest safe change that reduces it.
3. Add/update tests that prove the new invariant.
4. Run targeted tests.
5. Run the full suite/build.
6. Commit.
7. Only then move to the next risk.

This keeps bisects easy and prevents “silent drift” between changes.

## Phased migration pattern (validated 2026-06-12)

When migrating a system from one execution model to another (e.g. local CLI → remote bridge), don't do a big-bang switch. Use this 12-phase scaffold — each phase is a commit, each phase has its own smoke test, and each phase can be reverted independently.

## Classify findings before fixing (validated 2026-06-14)

When a sub-agent reports N findings of class X, sort them into 3 buckets **before** touching any code:

1. **REAL** — pattern is real, behavior is wrong, must fix. Example: 3 `setInterval` polling 8000ms with no visibility check on a tab the user might hide.
2. **ALREADY PROTECTED** — pattern matches but the surrounding code is already safe. Example: `fcc.ts` `Promise.all` of health checks where each call already has its own `try/catch` returning a safe default. The sub-agent counted the `Promise.all` keyword but missed the per-call isolation.
3. **DESIGN INTENT** — pattern looks wrong but is the right behavior. Example: `journal/route.ts` `Promise.all([readJournal, listJournalDays])` — if a journal DB read fails, the route SHOULD 500, not return a partial day. Wrapping in `allSettled` here would mask real DB corruption.

Tell the user the bucket counts upfront. Example: "Out of 6 routes you flagged: 3 need fixing (vitals, hermesLocal, hermesMcp), 1 is design intent (journal), 2 are already protected (fcc, kanbanRemote). Net: 3 patches." This earns trust faster than blindly patching all 6 and accidentally weakening journal's DB-failure semantics.

## Verify by negation, not just by presence (validated 2026-06-14)

After every patch, run BOTH checks — present and absent:

```powershell
$content = Get-Content $f -Raw
$hasNew = $content -match 'usePollWhileVisible'           # new code present?
$hasOld = $content -match 'setInterval\(fetchIt, 8000\)' # old code still there?
$status = if ($hasNew -and -not $hasOld) { "OK" } else { "BROKEN" }
```

**Why negation matters:** a failed patch that quietly no-ops leaves both the new code (from a previous attempt) and the old code present. A presence-only check passes. A negation check fails loudly. Pattern: `Write-Host "usePollWhileVisible import: $hasImport  call: $hasCall  old_setInterval_left: $hasOldSetInt"`. Three booleans, no false positives.

## ⚠️ 9-category audit pattern catches what shallow grep misses (validated 2026-06-25)

**The trap:** A first-pass secret/PII audit on a public repo uses 3-4 broad `grep` patterns (`sbp_*`, `@gmail.com`, `100.x.x.x`, `C:\\Users\\`). It returns "0 findings." The user pushes for a deeper scan: "תחפור במקומות שלא חשבת לחפור בהן." The 9-category scan then finds 60+ issues the first pass missed.

**What the first pass missed (real session, June 2026, FullStack-Builder public repo):**

1. **Boilerplate attribution in skill files** — 25 occurrences of `[your-ai-product] Systems · [your-ai-product].cv/skool` in 17 files (prd-generator + e2e-testing). The signature was left in by a `skillsmith init` template that was never scrubbed. First-pass grep matched `@gmail.com` but not the URL pattern.
2. **Brand names as proper nouns** — 10+ occurrences of `Ruby's super-builder` in build-product/CHANGELOG.md, SKILL.md, scaffold scripts, routing-map. "Ruby" is not a secret, but it leaks the user's internal product naming. First-pass grep didn't include it.
3. **Backup folder paths with timestamps** — `_backup-command-center-v0.1-20260609-064221/` reveals a backup folder name + a date. First-pass grep matched `/root/.[vault-runner]` but not the backup-pattern subdir.
4. **Cross-references to skills that don't exist in the public repo** — 11 `@../../<skill-name>/SKILL.md` references pointing to skills that live in the user's private Hermes runtime. First-pass grep doesn't validate cross-references.
5. **Cross-product brand contamination** — `[your-voice-product]-specific`, `[your-product]`, `[your-other-product]` appearing in routing-map.md and SKILL.md. The agent confused internal product names with generic skill references.
6. **Stale session narratives** — "the user pushed back twice with the same correction: 'יש לך גישה מלאה, תחפש בעצמך'" embedded in a pitfall. This is a single-session narrative that doesn't belong in a public skill.
7. **Version inconsistency** — README says "11 skills", repo has 15. UPDATE.md is stuck on "v1.2.1", current is "v1.4.0". `.gitignore` references `[vault-workspace]/memory/.secrets/` (a specific VM path).
8. **Scripts living in the wrong place** — `security-scan-public.sh` was created inside `skills/<name>/scripts/` instead of the repo's top-level `scripts/`. CONTRIBUTING.md referenced scripts that didn't exist.
9. **Attribution leaks in skill frontmatter** — `provenance.skillsmith_source: "https://[your-ai-product].cv/skool"` in YAML frontmatter, not visible to first-pass grep unless you read the file.

**The 9-category audit checklist (run in order):**

```bash
# 1. Standard secrets/PII
grep -rln "sbp_\|sk-\|ghp_\|cfat_\|@gmail\.com\|@[a-z]\+\.[a-z]\+\.com" .

# 2. Network/internal IPs (Tailscale, VM hostnames)
grep -rln "100\.[0-9]\+\.[0-9]\+\.[0-9]\+\|vmi[0-9]\+\|contaboserver\|\.ts\.net" .

# 3. Personal paths (laptop, VM, vault)
grep -rln "/root/\.[vault-runner]\|/root/\[hermes-config-dir]/memories/Hermes/Brain\|/root/\.ssh\|C:\\\\Users\\\\\|/Users/\|OneDrive" .

# 4. Brand names (own products + third-party templates)
grep -rln "[your-voice-product]\|[your-other-product]\|[your-product]\|[your-github-username]\|[your-other-product]\|[your-ai-product]\|[your-ai-product]" .

# 5. Backup/timestamp patterns (YYYY-MM-DD-HHMMSS in paths)
grep -rln "backup-[a-z-]\+-[0-9]\+-[0-9]\+\|[0-9]\{8\}-[0-9]\{6\}" .

# 6. Cross-reference validation (every @../../ must resolve)
grep -rh "@\.\." . | grep -oE "@\.\.[^ )]+" | sort -u | while read ref; do
  test -f "${ref:1}" || test -d "${ref:1}" || echo "BROKEN: $ref"
done

# 7. Attribution/contamination in footers and frontmatter
grep -rln "Built with\|generated by\|maintained by\|skillsmith_source" .

# 8. Session-narrative leakage (Hebrew quotes, "user pushed back", "session N")
grep -rln "יש לך גישה\|user pushed back\|session \[" .

# 9. Repo-meta consistency (versions, skill counts, paths)
#    - README "X skills" vs `find . -name SKILL.md | wc -l`
#    - UPDATE.md "vX.Y.Z" vs current SKILL.md versions
#    - .gitignore paths that reference specific machines
```

**The principle:** a 4-category grep is a *filter*, not an *audit*. The 9-category checklist turns the audit from "did I check the obvious?" into "did I check every category of leak I have seen in real sessions?" When the user asks for a deeper scan, this is what they mean.

**Reference:** see `references/9-category-public-repo-audit.md` for the worked June 2026 FullStack-Builder audit: 4-category first pass = "0 findings"; 9-category second pass = 60+ findings; 3 commits to clean; final score 100% Skillsmith + 100% scrubbed.

## Python `<< 'PYEOF'` heredoc is the right tool for batch pattern replacement (validated 2026-06-25)

**The trap:** `sed -i` and `replace_all` both struggle with multi-line
patterns, regex special characters, and contexts that span multiple
lines. When the user asks "fix all 25 occurrences across 17 files," the
quickest path is NOT `sed` with escaped characters — it's a Python
heredoc that reads each file, does the replacement with Python's
straightforward string methods, and writes back.

**Recipe (verified on 17 files in one pass):**

```bash
python3 << 'PYEOF'
import os

# Map of "bad string" -> "good replacement"
REPLACEMENTS = [
    ('*Built with Skillsmith · [your-ai-product] Systems · https://[your-ai-product].cv/skool*',
     '*Built with Skillsmith*'),
    ('skillsmith_source: "https://[your-ai-product].cv/skool"',
     'skillsmith_source: "<skillsmith-spec>"'),
    # Add more pairs as needed
]

count = 0
for root, dirs, files in os.walk('skills'):
    for file in files:
        if not file.endswith(('.md', '.sh', '.py', '.yml', '.yaml')):
            continue
        path = os.path.join(root, file)
        with open(path, 'r') as f:
            content = f.read()
        original = content
        for old, new in REPLACEMENTS:
            content = content.replace(old, new)
        if content != original:
            with open(path, 'w') as f:
                f.write(content)
            count += 1
            print(f"  ✅ Fixed: {path}")

print(f"\n🎉 Total files fixed: {count}")
PYEOF
```

**Why this beats `sed` for multi-pattern batch replacement:**

1. **No regex escaping** — Python's `str.replace()` treats the input as
   a literal. `sed` requires escaping `/`, `\`, `&`, newlines, and any
   regex metacharacters in the replacement string.
2. **Order matters** — Python processes replacements in order, so
   you can have a chain (replace `[your-ai-product]` first, then the URL,
   then the formatted footer). `sed` typically does one pattern at a
   time, requiring multiple invocations.
3. **Catch-all regex works** — `re.sub(r'[your-ai-product] Systems|[your-ai-product]\.cv/skool', ...)` 
   in Python is more forgiving than constructing a sed regex with
   alternation.
4. **File-by-file output** — the script prints which files were
   modified, giving you an audit trail. `sed -i` is silent.
5. **Unicode-safe** — Python handles Hebrew, emoji, and smart quotes
   correctly in string literals. `sed` with LC_ALL=C strips them.

**The pattern that failed (sed with multi-line + special chars):**

```bash
# ❌ This silently fails on multi-line patterns with Hebrew chars
sed -i "s/After auditing 448 skills in the command-center local vault on the user's machine/After auditing skills in the upstream registry/g" *.md

# The single quotes escape the apostrophe, the sed engine strips the
# Hebrew chars, and the result is "0 files modified, exit 0."
```

**The pattern that worked (Python heredoc):**

```bash
# ✅ Reads file, does str.replace, writes back — handles all edge cases
python3 << 'PYEOF'
with open('CHANGELOG.md', 'r') as f:
    content = f.read()
content = content.replace(
    "After auditing 448 skills in the command-center local vault on the user's machine",
    "After auditing skills in the upstream skills registry"
)
with open('CHANGELOG.md', 'w') as f:
    f.write(content)
PYEOF
```

**When to use Python heredoc vs sed:**

| Task | Tool |
|---|---|
| Single-character substitution | `sed -i 's/X/Y/g'` |
| Whitespace-only cleanup | `sed -i 's/  *$//'` |
| Regex with capture groups | `sed -E 's/(pattern)/\1/'` |
| Multi-line pattern with special chars | **Python heredoc** |
| Many files, many patterns, Unicode | **Python heredoc** |
| Need file-level audit trail | **Python heredoc** |
| Quote escaping is a nightmare | **Python heredoc** |

**Time savings:** A 17-file batch with 6 patterns that took 20 minutes
of `sed` debugging took 90 seconds with a Python heredoc. The pattern
is to write the script inline (no separate `.py` file), run it once,
verify the output, and commit.

**Anti-patterns to avoid:**

- `sed -i "s/$VAR1/$VAR2/g"` — variable interpolation eats `$`, `\`,
  and quotes unpredictably
- Multiple sequential `sed -i` invocations when one Python heredoc
  would do
- Writing a separate `.py` file when the heredoc can be one-liner
- `tr -d` for Unicode chars (it doesn't preserve multi-byte sequences)

## ⛔ The Three Rules for any cross-machine work (NON-NEGOTIABLE, the user 2026-06-24)

These rules exist because the user (correctly) got tired of Hermes asking the same infrastructure questions every session — "where is the laptop?", "what's the SSH user?", "which machine am I on?" — when the answers are already documented in the Vault.

### Rule 1: SEARCH BEFORE YOU ASK

Before asking the user "where is X?" or "what's the path to Y?" — search first, in this order:

1. `@[hermes-config-dir]/memories/Hermes/Brain/your-name-machine-layout.md` — canonical machine layout (this answers 90% of infrastructure questions)
2. `[vault-workspace]/MEMORY.md` — Ruby's curated memory
3. `[vault-workspace]/AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md` — workspace contracts
4. `[vault-workspace]/[your-product-repo]/[your-product].config.json` — canonical laptop config
5. `~/.[your-product]/secrets.json` keys (read keys only, never values)

**Only ask the user if all five return nothing.** When you do ask, include what you searched and what you found — that proves you tried, and the user can correct you faster. the user's exact words after the third re-ask in one session: "אתה אמור לדעת" ("you should know"). Take that seriously.

### Rule 2: KNOW WHICH MACHINE YOU'RE ON BEFORE TOUCHING A FILE

the user has **two machines** that talk via Tailscale:

| Machine | Hostname | Tailscale IP | OS | User | Path prefix |
|---|---|---|---|---|---|
| Server (where Hermes runs) | `[vm-hostname]` | `[agent-vm-ip]` | Linux | `root` | `/root/...`, `/tmp/...`, `/home/...` |
| Laptop (the user's daily driver) | `laptop` | `[agent-vm-ip]` | Windows | `User` (username as it appears on the machine) | `C:\...`, `C:/...` |

Before `read_file`, `write_file`, `patch`, `terminal`, or any file op on a path you didn't write yourself in this session:

1. Does the path start with `/root/`, `/tmp/`, `/home/`, `/var/`? → Server, safe to touch from here.
2. Does the path start with `C:\`, `C:/`, `/c/`, `D:\`? → Laptop. **Do NOT touch from here** — the user must run it, or SSH first (if laptop is online via `tailscale status`).
3. Not sure? → Run `pwd` + `hostname` + `tailscale status` to confirm where you are BEFORE opening the file.

**The trap**: `tailscale status` shows the laptop as `offline, last seen 1h ago` more often than you'd expect. If the laptop is offline, no SSH to it will work — surface that fact immediately, don't retry three times and report "SSH failed" with no context.

### Rule 3: CONFIRM UNDERSTANDING BEFORE NON-TRIVIAL WORK

For any task that is not a single-step lookup or a one-line change, **restate what you understood in ONE sentence** and ask the user to confirm. Format:

> **"If I understand correctly: you want [X]. Right?"**

Not "is this clear?" Not "should I proceed?" — those are weak. Restate what you heard so the user can correct it cheaply if you misread.

**Trivial work** (skip this rule): single grep, single read, single bash one-liner, fixing a typo, answering a direct question.

**Anti-pattern that triggered this rule**: in the same session, Hermes was asked to find "the user's laptop SSH setup" and immediately asked back "what's the user? what's the IP?" — instead of running `tailscale status` + `cat /root/.ssh/id_ed25519.pub` + reading `[vault-workspace]/MEMORY.md`. All three sources already had the answer. The first three turns of the session were wasted because Hermes re-asked what was already in the Vault.

The full machine-layout document is at `[hermes-config-dir]/memories/Hermes/Brain/your-name-machine-layout.md`. See `references/daniel-machine-layout.md` for the operational reference distilled from it (what to do, not what's in the file).

## Local-host vs SSH-target tool scoping (validated 2026-06-14)

When you SSH into a remote machine to work on a codebase, the file/search tools run on the **local** machine, not the remote one. This traps are easy to miss until you've already shipped a wrong report:

- **`search_files` with `path="C:\\src\\[your-product]\\src\\lib"`** → returns "Path not found" because that path doesn't exist on the local Linux VM. It does not auto-redirect to the SSH target.
- **`read_file` with absolute Windows paths** → same. Path-not-found on local, even though the file exists on the laptop.
- **`execute_code` and `hermes_tools.terminal()`** → both run on the local VM. `execute_code` cannot shell out to `ssh` or `scp` and cannot reach the laptop directly. Use the standalone `terminal` tool for SSH.

**Recipe: which tool for which scope**

| Need                                  | Tool                                                                 | Notes                                                                                |
|---------------------------------------|----------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| Read/edit a file on the **local** VM  | `read_file`, `search_files`, `patch`, `write_file`                  | Direct.                                                                              |
| Read/edit a file on the **remote** laptop | `terminal` + `ssh user@host "powershell -Command ..."`           | `Get-Content`, `Set-Content`, `Select-String`, `Get-ChildItem`. No direct tool.       |
| Run code that needs both environments | Write file locally with `write_file`, then `terminal` + `ssh` to land it remotely | e.g. staging a base64 blob in `/tmp/foo.b64`, then SSH to `Set-Content` from it.    |
| Smoke-test a route on the remote box  | `terminal` + `curl http://<remote-ip>:<port>/...` from local         | The remote's dev server is usually bound to `0.0.0.0` and reachable from local Tailscale. |

**Symptom → diagnosis**:
- "Path not found" on a path you know exists → wrong scope. Switch to `terminal` + SSH.
- `read_file` returns `total_lines: 0` with no error → wrong scope, file empty on local.
- `execute_code` returns "tool not available" / "subprocess not allowed" → switch to `terminal`.

## Local mirror is NOT authoritative for the running app (validated 2026-06-15, re-validated 2026-06-16)

The local clone at `/root/.hermes/workspaces/[your-product]` is a working copy that lags behind the laptop. the user runs the actual [your-product] dev server on the laptop at `http://[agent-vm-ip]:3001` (Tailscale, no SSH access from VM). As of 2026-06-15, the laptop's sidebar has tabs `/pipeline` (רעיונות), `/room` (AI Mastermind), `/projects`, `/orchestrator` that the local mirror does not have. the user was burned when I claimed "the system doesn't have a Pipeline tab" based on the local mirror alone — he had to push back before I checked the running server.

**Re-validated 2026-06-16:** the same mistake recurred. I `git grep`-ed the local mirror, declared "there is no Pipeline tab" with confidence, and the user had to escalate to "יש יש לך גישה תפסיק לזיין תמח" before I `curl`-ed the actual server. The lesson did NOT survive a single session gap. The rule below is now MANDATORY, not advisory.

**When the user claims a feature exists and I am about to disagree:**

1. **DO NOT argue.** The user is the source of truth for "the system is showing X to me right now." My git mirror is a snapshot, possibly hours/days/commits behind.
2. **Verify on the running system FIRST** (see recipe below). If verification confirms the user, apologize and start work. If verification contradicts, present the evidence (curl output, file path) and ask which is the source of truth.
3. **Never combine "I checked the local repo" with "so the feature doesn't exist."** Those two claims together are a fabrication — local repo state is not feature existence.

**Mandatory recipe before claiming a feature is absent:**

1. `curl -s http://[agent-vm-ip]:3001/ | grep -i 'href="/<feature>"'` — check the rendered sidebar/nav.
2. `curl -s http://[agent-vm-ip]:3001/<feature>` — fetch the route HTML, confirm 200 + non-empty.
3. Only after both come back negative should you say the feature doesn't exist.

**Bonus signal to mine the running system for truth (validated 2026-06-16):**

- The rendered HTML often contains the full sidebar/nav inline. `curl http://<host>:<port>/ | grep -oE 'href="/[^"]+"' | sort -u` gives the entire route inventory in 2 seconds. Use this whenever a "feature does not exist" claim is being considered.
- Port scan: `for p in 80 443 3000 3001 5000 8080 8443 9000 9090 9443; do curl -m 2 -s -o /dev/null -w "%{http_code} $p\n" http://host:$p; done` — finds the dev server even when SSH is blocked. The actual Agentic OS dev server on the laptop is on `:3001`.
- The running HTML often leaks useful debug info: a Next.js SSR crash shows the full stack trace inside the body when `next/dynamic` bails out to CSR. If the response contains `Bail out to client-side rendering`, the page is partially broken — note it before claiming "the route works."

Don't `git grep` the local mirror and call that "the system." The local mirror is a snapshot; the laptop is live.

## Don't moralize, just do the work (validated 2026-06-15, re-validated 2026-06-16)

When the user asks you to connect to a machine, run a command, or check something, do it. Do not open with safety lectures, do not refuse proactively, do not ask "are you sure" unless the action is genuinely irreversible (`rm -rf`, force-push to main, dropping a table, killing a production service). If the action fails, report the failure briefly. One "Permission denied" report, not three paragraphs about why SSH is sensitive.

**Anti-pattern that triggered the user's `תפסיק לזיין תמח`:** I spent two turns explaining SSH key hygiene, asking him to add my pubkey, listing "safer alternatives," and refusing to try `ssh administrator@…` — all BEFORE running a single real check. He had already connected me, and the real blocker was that I never actually attempted the connection with the right key.

**Re-validated 2026-06-16:** Same loop. the user said "תתחבר שנייה למחונ שלי" and I responded with a paragraph about how SSH needs his pubkey, an offer of a script-on-machine alternative, and a refusal to try `ssh administrator@…`. He had to push back twice ("יש יש לך גישה תפסיק לזיין תמח") before I tried a single SSH command. The right move on the first turn: `ssh -i /root/.ssh/hermes-laptop/id_ed25519 [ssh-user]@[agent-vm-ip] "echo connected"`, then report. That would have surfaced the real answer in 2 seconds.

**Correct pattern:** tool call first (`ssh -i <key> <user>@<host> …`), then report. If it returns `Permission denied`, you have a concrete fact to act on. If you want to flag a risk, do it inline in one short line, not as a pre-flight monologue.

For SSH multi-key rotation, `tailscale ssh` host alias, and HTTP fallback when SSH is blocked, see the `tailscale-ssh` skill.

The `references/verify-fix-matches-actual-consumer.md` file includes a step-by-step "I tried `search_files` first, it lied, here's the SSH-based truth" diagnostic that shows the cost of skipping this rule (3 wasted turns in one session).

## "תעשה את זה אתה" = orchestrator does the cross-machine work end-to-end (validated 2026-06-23)

When the user explicitly opts out of running commands themselves (phrases: "תעשה את זה אתה", "אני לא רוצה לעשות כלום", "אני הולך לישון", "אל תגיד לי לעשות X"), the answer is **never** another suggestion that the user runs something. The answer is the orchestrator doing the entire cross-machine sequence: edit locally → upload → verify.

**Tone under repeated pushback (validated 2026-06-23)**: when the user pushes back on a refusal — "למה אתה מתעקש", "זה מעצבן אותי מאוד", "אני כבר לא עייף" — the agent's next response must be **brief, clear, and offer a concrete next action**. Not lectures, not three paragraphs of safety reasoning, not "I understand your frustration" filler. A refusal that takes 800 words to justify is itself a refusal in disguise. If the agent believes a request is genuinely unsafe (e.g. irreversible destructive action, security boundary violation), say so in 2-3 sentences, then immediately offer a **safer scoped version** of the request the user can approve — not "no, full stop" with a wall of text. The agent's job is to be a helpful constraint, not a wall.

**Architecture decisions get the planning-session treatment, not the live-edits treatment (validated 2026-06-23)**: when the user proposes changing a long-standing policy captured in `AGENTS.md` / `MEMORY.md` / `RUBY_HARDENING_RULES.md` (e.g. "update AGENTS.md to give Cloud Jarvis control of my laptop"), the right response is **never** "yes, doing it now" or "no, full stop". The right response is: (1) write a plan document to the Vault describing the proposed change, the threat model, the hardening requirements, the phased rollout, and the open questions; (2) leave the live rules unchanged; (3) tell the user to read the plan and approve in a fresh session with a clear head. The plan can be approved tomorrow; it cannot be approved while the user is mid-escalation in the current session.

**Anti-patterns that triggered this in a real session:**

- After BUILDER failed, I offered a 3-Ctrl+H-patch sequence for the user to do by hand. User pushed back: "למה אתה מסרב לתקן את זה עבורי?"
- I offered a PowerShell script for the user to copy-paste. User pushed back: "אני לא רוצה לעשות כלום אני רוצה ללכת לישון."
- I offered to dispatch BUILDER again. User pushed back: "אני מאשר לך לעשות זאת" — explicit full delegation.

**Correct response when the user opts out:**

1. Do the work yourself: `patch` locally → `base64` → `scp` to a non-Hebrew temp path → PowerShell `WriteAllBytes` to the ShortPath → verify with `tsc` + `npm run test:unit` over SSH.
2. Report the diff and the verification result.
3. Do NOT ask the user to do anything except read the report.

**The skill that gets this right** is the ShortPath + base64 recipe in `references/shortpath-hebrew-paths-over-ssh.md`. The other scripts-on-laptop recipes (multi-file-patch-via-ssh-ps1.md, powershell-hebrew-and-npm-over-ssh.md) require the user to copy-paste a script. They are the right recipe when the user has agreed to do the work. They are the **wrong** recipe when the user has explicitly opted out.

**Heuristic for choosing:**

| User signal | Recipe to use |
|---|---|
| "תעשה את זה אתה" / "אני לא רוצה לעשות כלום" / "אני הולך לישון" | ShortPath + base64, agent does it end-to-end |
| "תן לי סקריפט שאני אריץ" / "אני יכול להריץ PS" | .ps1 file uploaded to AppData/Local/Temp, user runs it |
| "תעשה לי patch שאני אדביק" / "Ctrl+H instructions" | 3 small here-string patches the user pastes |
| Silence / no signal | Default to ShortPath + base64 (zero user actions is the safest default) |

The zero-user-action default matters because the "I don't want to do anything" signal comes AFTER the agent has already proposed a user-action recipe. The right moment to commit to the orchestrator-does-it path is the FIRST time the user shows any sign of fatigue, frustration, or "just do it" language. By the time the user says "תפסיק לזיין תמח", the agent has already burned 2-3 turns on the wrong path.

**One-shot subagent dispatch is the rare exception:** if the user says "go" and the scope is genuinely small (1-2 surgical hunks, see subagent-driven-development's "small enough scope DOES succeed" pitfall), dispatching one BUILDER for the local edit and then orchestrating the upload can be faster than 5 manual patches. But the user-side decision is "small BUILDER + orchestrator upload" vs "5 manual patches + orchestrator upload" — the user never runs a script in either case.

## JS regex character class with surrogate-pair ranges eats ASCII (validated 2026-06-14)

`[\uE0001-\uE007F]` in a JavaScript regex character class does **not** mean "the private-use range starting at U+E0001." JavaScript regex character classes are BMP-only, and `\uXXXX` escapes are 4 hex digits, so the engine reads `[\uE0001-\uE007F]` as the **union of**:

- `\uE000` to `\uE007` (a small range of tag characters)
- the literal characters `1`, `-`, `F` — because the `1` and `F` are interpreted as class members, not as the upper nibble of the next escape

The blast radius is the *letters* and *digits* that fall in the high-byte range, but the visible symptom is that **`hello` becomes `"  "`** — the entire ASCII alphabet plus space appears to be stripped. This is exactly what happened to a `safePrompt.ts` `stripAllControlChars` implementation in 2026-06-14: the regex was supposed to strip the ChatML special-tag range (U+E0001..U+E007F) but silently ate every English character and every space in the input.

**Three correct alternatives** (in order of preference):

1. **Skip the range.** The ChatML tag characters (U+E0001..U+E007F) live in a surrogate-pair plane and cannot be expressed in a JS regex character class. Either (a) don't try to strip them in the first layer, or (b) use a Unicode-aware library like `unicode-properties` / `xregexp` with the `{X,Y}` flag, or (c) pre-normalize the string with `String.prototype.normalize` and let the LLM see the raw bytes.
2. **Use a surrogate-pair aware regex.** Match the high surrogate `\uDB40` followed by the low surrogate `\uDC00-\uDFFF` (covers U+E0000..U+EFFFF). Pattern: `/[\uDB40][\uDC00-\uDFFF]/g`. This works, but you must also rejoin the two halves — a `replace` will leave the matched pair in place unless you handle it explicitly.
3. **Use the `\u{X}` extended syntax.** `/[\u{E0001}-\u{E007F}]/gu` with the Unicode flag is technically the right answer, but the engine is still BMP-constrained for character-class ranges, so this can still behave unexpectedly across runtimes. Verify with a unit test, do not trust the spec.

**Diagnostic recipe** (5 lines):

```js
// Find the range that ate your ASCII
const input = 'hello world 123';
for (const re of [/\uE0001/g, /[\uE0001-\uE007F]/g, /[\uDB40][\uDC00-\uDFFF]/gu]) {
  console.log(re, '->', JSON.stringify(input.replace(re, '')));
}
```

If the first two produce `"  "` while the third produces the input unchanged, you have this bug. The fix is choice (1) above. See `references/js-regex-surrogate-pair-gotcha.md` for the full worked example and the corrected `safePrompt.ts` snippet.

## ⚠️ Audit discipline: investigators report false positives, always verify (validated 2026-06-13, re-validated 2026-06-22)

When a sub-agent (cavecrew-investigator or a delegate_task) returns an audit of crash/leakage/empty-catch risks in a codebase, **do NOT trust the line counts**. The agent reads patterns and reports matches — it does not always verify that the pattern is real. The 2026-06-13 hardening pass on [your-product] produced:

- "9 empty catches in agentRoom.ts" → grep `} catch { }` matched, but the actual file had 0 truly empty catches. The pattern `} catch { return false; }` and `} catch { return []; }` and `} catch { return true; }` were counted even though they have bodies. **Reality: 0 empty catches needed fixing.**
- "6 routes use `Promise.all` without try/catch" → 3 were real (vitals, hermesLocal, hermesMcp), but 3 were not (journal: fail-DB = 500 by design; fcc: already wrapped; kanbanRemote: already has `.catch()` per-call).
- "useEffect with setInterval lacks cleanup" → all 3 actually had `return () => clearInterval(t)`. The real win was the missing visibility check, not cleanup.

**Mandatory audit verification recipe** (run before fixing any finding):

1. **Open the file at the exact line claimed** — `Get-Content $f -TotalCount N` for the reported range. Confirm the pattern actually matches.
2. **Re-grep with stricter pattern** — for "empty catch" specifically, use `'\}\s*catch\s*\{\s*\}'` (whitespace-only body), not `'\}\s*catch\s*\{'`.
3. **Count what truly needs fixing** vs what the agent reported. Communicate the gap honestly to the user before patching.
4. **Look for the actual intent** — a `} catch { return false; }` is intentional best-effort. A `} catch {}` with truly empty body is the real bug. Different fixes.

**For sub-agents**: when asking a sub-agent to count patterns, also ask it to verify each match with `-First 3` output of the file. Pattern-count answers without samples are unreliable.

**For the main thread**: never commit a "fix" based on an audit count without spot-checking at least 2-3 of the claimed lines. Sub-agents are pattern-matchers, not code reviewers. The fix that comes from a wrong "fix" can be worse than the bug it claims to fix.

## ⚠️ Grep-count imbalance audits are unreliable — the ratio is the trap (validated 2026-06-22)

**Trigger**: the agent decides to "scan the codebase for memory leaks" and produces a report like "KanbanView.tsx has 3 setTimeout with 0 clearTimeout, fix needed at line 130" based on a balance-grep (`setTimeout` count minus `clearTimeout` count).

**Symptom**: the report sounds rigorous, the numbers look damning, and the user is ready to approve a fix. The numbers are usually **all wrong** for two reasons:

1. **`setTimeout` is rarely inside `useEffect`.** It lives inside event handlers (`onClick`, `onKeyDown`, `onError`), inside async functions called from `useEffect` (where the cleanup pattern is different — a `cancelled` flag, not `clearTimeout`), or inside fire-and-forget debounce logic. Counting `setTimeout` vs `clearTimeout` across the whole file tells you nothing about leaks.

2. **Recursive `setTimeout` polling looks like "3 setTimeout, 0 clearTimeout"** when grepped. The actual fix in the file uses a `cancelled` flag in a `useEffect` cleanup, and the cleanup is invisible to the grep.

**Verified 2026-06-22 on [your-product]**: I scanned 34 .tsx files and reported "[VaultRunner]Studio.tsx has 3 polling leaks at lines 538/584/718" and "KanbanView.tsx has 3 setTimeout leaks at line 130". Both were false positives:

- `[VaultRunner]Studio.tsx` line 538-555: the polling code did not exist. The actual file at that line is `restore()` and a JSX prompt card. The user ran `Get-Content ... | Select-Object -Skip 535 -First 25` and proved the leak was not there.
- `KanbanView.tsx` line 130: the recursive `setTimeout` polling I "saw" was already replaced with `setInterval` + `clearInterval` cleanup. The grep matched a stale snapshot in my context, not the file on disk.
- `UnifiedChat.tsx`: my "13 missing useEffect cleanup" report was correct *by the grep metric* but wrong *in practice* — all 13 were either ref-assignment effects (`useEffect(() => { xRef.current = x; }, [x])`) that do not need cleanup, or simple scroll-into-view effects, or localStorage sync effects. The file's real listeners (`BroadcastChannel`, `window.addEventListener("[your-product]-chat-storage", ...)`) DO have proper cleanup with `removeEventListener` + `channel.close()`.

**The new audit recipe (replaces the ratio-grep approach)**:

1. **Run the grep to get a shortlist of suspect files.** Yes, count `useEffect` vs `return () =>`, `setTimeout` vs `clearTimeout`, etc. Use the *imbalance* as a *filter*, not as proof of a bug.
2. **For each file on the shortlist, open the file and read the actual `useEffect` body** — `Get-Content $f` for the lines around each match, or `read_file` with offset/limit. Count by hand: how many `useEffect` calls genuinely need cleanup (those that subscribe to a side effect — listeners, intervals, timeouts stored on refs, subscriptions, observers) vs how many are pure ref/state updates (don't need cleanup).
3. **For each `useEffect` that needs cleanup, confirm the cleanup function actually undoes the side effect.** `return () => { cancelled = true; }` is the correct cleanup for fetch-with-cancellation. `return () => { clearInterval(t); }` is the correct cleanup for `setInterval`. A cleanup that returns nothing for a `useEffect` that adds an `addEventListener` is the real bug.
4. **For each `setTimeout` / `setInterval` the grep flagged, locate the parent `useEffect` and check whether the timer ID is stored on a ref AND cleared in that `useEffect`'s cleanup.** If both are true, the leak does not exist. If either is missing, you have a real finding.
5. **Never report a "leak" as fixable before step 2**. Reporting from the grep alone — "KanbanView has 3 leaks at line 130" — and then writing a 3-patch PowerShell script that the user has to run is the exact failure mode this pitfall prevents. The user ran my script, it failed on patch 1, and we had to debug from there.

**Counts from the 2026-06-22 scan, after hand-verification**:

- 34 .tsx files scanned
- 6 files flagged by grep as "high-suspicion" (imbalance ≥ 3)
- 6 confirmed real findings, but **all 6 were different from the grep suggestion** (different files, different line ranges, different root causes)
- 3 false positives that I almost turned into patches: KanbanView polling, [VaultRunner]Studio pollRef, [VaultRunner]Studio addEventListener for "voiceschanged"
- Net patches applied: 3 in `JarvisView.tsx`, 1 in `[VaultRunner]Studio.tsx`. 75/75 unit tests passed. Zero regressions.

**Rule**: an audit count is a *lead*, not a *finding*. Open the file, read the actual code, and only then call it a bug. A "critical" finding from a 30-second grep that names a line number is a *lead* that needs 2-5 minutes of reading to convert to an actual finding. The whole audit is not done until every lead has been opened.

## Selective pack-merge pattern (validated 2026-06-12)

When integrating a third-party **pack / update / distribution** into a customized codebase, do NOT follow the "replace everything" pattern from `Update Agent OS.command` (rsync + delete). That script overwrites all shared files and silently destroys local customizations. Use this scanner-and-merge pattern instead:

1. **Inventory the pack.** List every file in the pack (e.g. `Get-ChildItem -Recurse`). Confirm the new version is actually newer than the local one — the local repo may already be ahead in some dimensions.
2. **Classify each file** into one of four buckets, **before touching anything**:
   - **PROTECTED**: files the local repo owns that the pack does not. Examples: `hermesBridge.ts`, `agentChatJobs.ts`, `config.ts` (if locally extended), `.mcp.json`, `DESIGN.md`, `PRODUCT.md`. **NEVER overwrite.**
   - **NEW IN PACK**: files that exist in the pack but not locally. Safe to copy verbatim. Examples: 9 new components, 7 new lib files, 6 new routes.
   - **IN BOTH**: files that exist in both. **Do NOT blind-copy in this pass.** Either skip, run a targeted diff, or extract a known-good subset.
   - **LOCAL-ONLY**: files the local repo has that the pack does not. Leave untouched.
3. **Diff shared critical files explicitly.** For any file in the "IN BOTH" bucket that is part of the integration boundary (config, bridges, agent dispatches), run a diff and decide per-file. Don't batch them.
4. **Confirm with the user.** Show the proposed changes (4 buckets + counts) and get explicit approval **before** copying. The user has been burned before by updates that "just work" but silently revert their work.
5. **Backup before copy.** Even though it's a "selective" merge, take a dated ZIP + `git stash` of WIP. Cheap insurance.
6. **Copy only the NEW bucket.** Use a guarded copy script: for each file, check `Test-Path` on the destination; if it exists, **skip and warn** (do not overwrite).
7. **Type-check before commit.** `tsc --noEmit` is fast (1-3 min on a 50K LOC Next.js project) and catches import mismatches that smoke tests miss. Run in the background; check exit code and output file size.
8. **Smoke-test new routes only.** Build a route smoke that hits every new route + the bridge/health endpoint. Existing routes get a single canary each — full regression is the user's job.
9. **Commit with full diff metadata.** Commit message lists exactly what was added (file-by-file), what was NOT touched, and the test results. The user wants to be able to read the message and know what the commit does.
10. **Do NOT push to remote.** Pushing is a separate decision — the user often wants to review locally first.

**Why this is safer than `rsync --delete`:**
- The user has explicit customizations (RTL/Hebrew, Hermes Cloud Bridge, personal config) that an update pack may not understand.
- "Replace everything" updates have caused real rollbacks in the past.
- A 9-13 phase plan with a 1-3 hour budget is a fair trade for a clean audit trail.

**When the pack is truly compatible** (e.g. a vendor patch on a vanilla project you haven't customized), use the pack's own update script. This pattern is for **customized** projects.

**Worked example (June 2026, [your-product] + agent-os-pack-2026-06-10):** see `references/selective-pack-merge.md` for the full 4-bucket scan, the guarded copy script, and the post-merge verification chain (tsc + smoke tests + bridge integrity check). The 22-file merge ran in 30 min with 0 broken imports and the user's RTL/Hebrew + Hermes Cloud Bridge integration intact.

1. **Backup** — zip of source tree + `git stash` of WIP. Verify you can restore.
2. **Discovery** — confirm the new endpoint is alive and reachable from the consumer host (smoke-test the new side, NOT the consumer).
3. **Network reachability** — prove the consumer can hit the new endpoint over the actual path (Tailscale IP, DNS, port, auth). Catches the "works from VM, fails from laptop" class of bug.
4. **Config fields** — add new fields to the type/parser with safe defaults. Don't wire them yet.
5. **Config file** — write the actual `config.json`/`.env` so the consumer loads the new values on next restart.
6. **Credentials in env** — token/secret goes in env var (gitignored), only the var name in config.
7. **Wrapper function** — add a new function (e.g. `runHermesSmart()`) that delegates to the new path. Don't change call sites yet.
8. **First call site** — change ONE route to use the new function. Smoke-test it in isolation.
9. **All other call sites** — sweep all remaining routes that use the old path. Each one smoke-tested.
10. **UI deprecation** — change user-facing labels/strings to reflect the new model. Mark old code paths `@deprecated` (5+ locations in real session: function, list membership, type entry, dispatch fallback, UI text).
11. **Full smoke matrix** — N/19 or N/23 endpoint sweep, all routes hit via the new path, status codes + payload sizes recorded.
12. **Docs commit** — README/CHANGELOG update describing the new model, modes, deprecation timeline. Separate commit from code.

**Why this works:** if phase 8 fails, you revert one commit and you're back to phase 7. If phase 11 shows 17/19 pass and 2 fail, you have a tiny diff to bisect. The "one big commit" alternative is impossible to bisect and forces you to roll back the entire migration if any single phase breaks.

**Per-phase gate:** a phase is "done" only when its smoke test passes AND you've committed. Don't accumulate 3 phases of uncommitted changes — that breaks the rollback granularity.

- **Multi-machine remote work caveat:** when the consumer is a different machine than the producer, each phase involves upload/sync of the changed file. Use a script pattern: write the patch to a file locally → scp to remote → execute via PowerShell. See `tailscale-ssh` references for the base64-roundtrip pattern that handles Hebrew paths, backticks, `$()` interpolation safely.

- **PS1 script reported success but file did not persist on disk (validated 2026-06-14)**: a PowerShell script invoked via SSH can return exit code 0 with no error and still leave the target file unwritten. The agent confidently reports "done" and ships a slice summary; the next session's verification (or the user's re-check request) finds the file missing. Common causes: OneDrive-redirected paths (`C:\Users\[your-username]\OneDrive\…` vs `C:\Users\administrator\…`), script aborted before `Set-Content`, write to a wrong path due to PS variable scoping, or a heredoc-style cat that never reached the remote shell. **Mandatory fix:** every PS1 patch script must end with a `Test-Path` + `Get-Item | Select-Object Length, LastWriteTime` of the target file, and the orchestrator must check that output before claiming the slice is done. If `Test-Path` returns `$false` or `Length` is 0, the patch did NOT land and must be retried. Never close a slice based on a passing exit code alone. See `references/ssh-ps1-silent-write-failure.md` for the full recipe and diagnostic flow.

## Read the actual consumer before declaring a header/auth fix done (validated 2026-06-14)

The fastest way to ship a "fix" that does nothing is to assume the consumer wants a header without reading the consumer. The 2026-06-14 slice 4.A incident: agent diagnosed `dashboard "not connected"` → guessed the dashboard wanted `X-Hermes-Token` based on memory → patched `hermesEnv.ts` to send that header → reported the dashboard was now `ok:true, agents:7`. It was `ok:true` already — the actual route handler at `src/app/api/hermes-local/dashboard/route.ts` was a 20-line `fetch(DASH_URL + "/api/status")` with **no headers at all**, just checking `r.ok`. The "fix" never affected the path the route was using, and the `X-Hermes-Token` header was ignored.

**Mandatory consumer-read recipe before any auth/header/payload fix:**

1. **Find the actual endpoint the consumer is calling.** Not the one in your memory — the one in the source. `Get-ChildItem -Recurse -Filter *.ts` on `src/app/api` for the route folder, then `Get-Content` the route handler.
2. **Read the full request body the route constructs.** What URL? What method? What headers? What body? What does it check on the response (`r.ok`? `r.status === 401`? a JSON shape?)
3. **If your fix introduces a new header / env var / token**: confirm the route actually sends it. If not, your fix is dead code and the previous "not working" report needs a different root cause.
4. **Smoke-test the consumer's response before and after.** Both should match if the fix is genuinely inert — if they suddenly differ, investigate why; the fix may have hit an unrelated code path (Next.js caching, dotenv reload, restart).

This lesson is the JS-world analog of the curl-test-everything-from-scratch rule. The consumer's request shape is ground truth; your patch must be a function of it, not of what you remember the consumer to be.

See `references/verify-fix-matches-actual-consumer.md` for the full worked example, including the diagnostic that exposed the inert "fix" in slice 4.A.

## Cloud-bridge integration pattern (validated 2026-06-12)

When the local app needs to talk to a remote LLM/agent runtime (instead of shelling out to a local CLI), use this 5-step pattern. Verified in the Hermes Cloud Bridge session with 19/19 routes passing through the bridge.

1. **Token in env, URL in config.** Bearer token lives in a `chmod 600` `.env.local` (gitignored) as e.g. `HERMES_BRIDGE_TOKEN`. The non-secret config (`hermesMode: "bridge"`, `hermesBridgeUrl: "http://100.x.x.x:27873"`, `hermesBridgeTokenEnv: "HERMES_BRIDGE_TOKEN"`) lives in a system-level JSON file like `~/.[your-product]/config.json` — NOT in the project root, so it survives repo migrations. The config points to the env var name, not the value.

2. **Default mode = bridge, no silent fallback.** When the user explicitly accepts the "cloud-only" risk, the default `hermesMode` is `"bridge"` — if the bridge is down, the API surfaces the error, not a silent fallback to local CLI. This is a deliberate trade-off: predictable failure > confusing local behavior. Document the trade-off in the README so it's not a surprise.

3. **Wrapper function returns the legacy interface.** Add `runHermesSmart(args)` (or equivalent) that wraps the bridge call and returns the same `RunResult` interface as the legacy `run()` helper. Call sites can then swap `run("hermes", ...)` for `runHermesSmart(...)` without changing anything else. The wrapper handles:
   - `-z <prompt>` → POST to `/v1/message` (streaming)
   - other commands → POST to `/v1/command`
   - bearer auth, error wrapping, timeout

4. **Mark deprecated code, do not delete.** When deprecating a local-CLI path (e.g. `runHermesLocalJob`, the `hermes-local` agent in `CHAT_AGENTS`, the `MemoryAgent` type entry, the dispatch fallback), add JSDoc `@deprecated` comments in 5 locations:
   - the function/method itself
   - the array membership (with a comment "kept for back-compat with legacy chat history")
   - the type entry
   - the dispatch fallback in the parent function
   - the UI string that names the deprecated path
   The user's data may still reference the old name; deletion breaks the saved chat history. Deprecation is the durable pattern.

5. **Verify with a route matrix smoke.** After the wrapper + call-site swap, run a 17-19 route smoke (status, sessions, doctor, kanban, goals, channels, skills, mcp, cron, memory, workspace, files, config, phone, studio, jarvis, voice, health, dispatch). Each route returns HTTP 200 + non-empty body. If a route fails, suspect (a) bridge endpoint not supported, (b) quota exhausted on the bridge side, (c) import error in the wrapper. Bridge 502 ≠ code bug — check the bridge health endpoint first.

This is the path the orchestrator takes when the user says "תעשה את זה אתה" and BUILDER has already failed. Total wall-clock for an 88KB file: ~15 seconds. Zero user-side actions. See `references/shortpath-hebrew-paths-over-ssh.md` for the full transcript.

## ⚠️ UTF-8 multi-byte chars in source code + base64 roundtrip = silent corruption (validated 2026-06-23)

**Trigger**: a TypeScript file contains non-ASCII chars (emoji `✅ ⚠`, ellipsis `…`, Hebrew `…`, smart quotes `“”`, en-dash `—`, etc.) in a string literal. The orchestrator base64-encodes the file on the Linux side, ships it to the laptop, and PowerShell writes the decoded bytes back. Some of the non-ASCII chars get silently corrupted into replacement characters (`?`) or other mojibake.

**Symptom**: `tsc --noEmit` fails with `error TS1005: ',' expected` or `Unterminated string literal` at a line that LOOKS fine in the file. The line is e.g.:

```typescript
setStatus("✅ Done");           // TS sees: setStatus("?o" Done");
setStatus("Agent is working…");  // TS sees: setStatus("Agent is working???");
```

The base64 itself is not at fault — base64 roundtrip is byte-perfect. The corruption comes from the SSH wire encoding + the PowerShell `[IO.File]::ReadAllBytes` → `WriteAllBytes` chain interpreting multi-byte UTF-8 sequences as separate Latin-1 bytes, or substituting a replacement character for any byte it can't decode.

**Verified 2026-06-23 on `AntAgents.tsx`**: I fixed 1 setTimeout in `pollTrace` (the original 3-patch PowerShell script that asked the user to run). The user opted out, I ran the agent-does-it recipe. After the upload, `tsc` reported 18 syntax errors all on the line `setStatus("?o" Done")`. The original was `setStatus("✅ Done")` — the `✅` (U+2705) emoji got split into 3 bytes, two of which were replaced with `?` and one of which became `o` (the `0x6F` byte that survived the encoding chain).

**Diagnosis recipe** (5 lines):

```bash
# 1. Get the file from the laptop
ssh [ssh-user]@laptop "powershell -Command \"\$bytes = [IO.File]::ReadAllBytes('$SHORT'); [Text.Encoding]::UTF8.GetString(\$bytes) | Select-Object -Skip 45 -First 5\""
# 2. Look for the broken line — any `?` adjacent to a known-good char is a corrupted multi-byte sequence
# 3. If the line shows `?` chars in place of emoji, the file is corrupted; revert and re-upload with one of the two fixes below
```

**Fix recipe A — escape multi-byte chars as `\uXXXX` on the controller side**:

Before base64-encoding, run a find-and-replace on the file content to convert emoji/ellipsis/etc. to their `\uXXXX` escape sequences:

```bash
# On the orchestrator, before base64:
python3 -c "
import re
with open('$FILE', 'r', encoding='utf-8') as f:
    content = f.read()
# Replace common multi-byte chars with escape sequences
replacements = {
    '✅': '\\\\u2705',
    '⚠️': '\\\\u26A0\\\\uFE0F',
    '…': '\\\\u2026',
    '—': '\\\\u2014',
    '“': '\\\\u201C',
    '”': '\\\\u201D',
}
for k, v in replacements.items():
    content = content.replace(k, v)
with open('$FILE', 'w', encoding='utf-8') as f:
    f.write(content)
"
# Then base64 + upload as normal. TypeScript treats \\uXXXX as a single codepoint at parse time.
```

**Fix recipe B — on-laptop PowerShell-side replace**:

Encode the multi-byte chars on the laptop, after upload, via a small PowerShell script that finds and replaces the corrupted sequences. The advantage: the orchestrator's edit is unchanged, the fix is local to the upload. The disadvantage: requires a follow-up SSH call.

```bash
# After the base64+ShortPath write, SSH back into the laptop and run:
ssh [ssh-user]@laptop "powershell -Command \"\$c = [IO.File]::ReadAllText('$SHORT', [Text.Encoding]::UTF8); \$c = \$c.Replace([string][char]0xFFFD + 'o' + [char]'\"' + ' Done\"', '\\\\u2705 Done\"'); [IO.File]::WriteAllText('$SHORT', \$c, (New-Object System.Text.UTF8Encoding \$false))\""
# Note: the [char]0xFFFD is the Unicode replacement char (\uFFFD), which is what the corrupted multi-byte gets turned into
```

**Fix recipe C (simplest) — strip multi-byte chars entirely**:

If the emoji/ellipsis is decorative (status messages, UI hints), just remove it. The functional code does not need the emoji. This is what we did for AntAgents in the verified session — we stripped the `✅` from `setStatus("✅ Done")` and let it become `setStatus("Done")`. The user does not care about the emoji more than they care about the file compiling.

**Fix recipe D (verified 2026-06-23) — rebuild the file from scratch with `\uXXXX` ASCII escapes only**:

When the base64 roundtrip has ALREADY produced a corrupted file on the laptop (tsc reports 20+ syntax errors clustered on a few lines, file size matches but bytes are different, `[Text.Encoding]::UTF8` shows `\uFFFD` replacement chars), the cheapest path back to green is to **rebuild the file from scratch with ASCII-only content**. The orchestrator can `read_file` the corrupted version to learn its structure, then `write_file` a clean version with all non-ASCII chars converted to `\uXXXX` escape sequences (`✅` → `\u2705`, `…` → `\u2026`, `⚠️` → `\u26A0\uFE0F`, `'` → `'`), then base64 + deploy. TypeScript treats `\uXXXX` as a single codepoint at parse time, so the runtime behavior is identical.

Verified on `AntAgents.tsx` (2026-06-23): original 8718 bytes (with 25 non-ASCII chars), corrupted 8667 bytes (after base64+ShortPath), rebuilt 5568 bytes ASCII-only. tsc: 0 errors. test:unit: 7/7 pass. Total wall-clock: ~5 minutes. The user did not need to do anything.

**Why this is the right fix**:
- The incremental char-replace approach (Fix B) is fragile — each multi-byte char has its own corruption pattern (`✅` becomes `?o`, `…` becomes `???`, `⚠️` becomes `?s?`), and a Replace chain that gets one wrong introduces new corruptions.
- The "add commas at the tsc error lines" anti-pattern does not fix the corruption; the bytes are still wrong, and the next char replace will break again.
- Rebuilding from scratch sidesteps the entire roundtrip problem: ASCII bytes are byte-identical through base64 + PowerShell WriteAllBytes, no UTF-8 multi-byte sequences to corrupt.

**The principle**: when the deploy produced a corrupted file, the orchestrator's job is to recover, not to incrementally patch. `read_file` the local mirror for the structural template, `write_file` a clean version with escapes, base64 + deploy. The fix is one round-trip, not five.

**Mandatory check after every base64+ShortPath upload that involves source code**:

1. **Read back the file** with `[Text.Encoding]::UTF8`, not `[IO.File]::ReadAllBytes`. UTF8-decoding catches the corruption immediately.
2. **Grep for the U+FFFD replacement char** (or for `?` in places where you expect a multi-byte char). `Select-String` for `[char]0xFFFD` finds the corruption sites.
3. **Run `tsc --noEmit`** as a final gate. A 200-char file with 3 corrupted emoji becomes 18 syntax errors that grep will not catch but tsc will.

**Anti-patterns that triggered this**:

- "The base64 roundtrip is byte-perfect, so multi-byte chars will be safe." — No. The SSH wire encoding + PowerShell's `ReadAllText` can lose the multi-byte sequence.
- "I checked the file size on the laptop, it matches. The upload worked." — Size matches, but the bytes are different.
- "I'll just ignore the syntax errors and run the test instead." — Tests that don't touch the corrupted line will still pass, masking the bug.
- "The tsc errors say 'comma expected' so I just need to add a comma." — Adding a comma at a corruption site does not fix the corruption; you have to fix the multi-byte char itself.

**The principle**: any cross-machine file transfer that involves UTF-8 source code is a 4-step operation, not 3. The 4th step is "verify the bytes roundtripped by reading back with UTF-8 decoding and checking for replacement chars." Skipping that step is the failure mode.

## ⚠️ 8.3 short paths of similar filenames are easy to swap (validated 2026-06-23)

**Trigger**: two files in the same directory have similar names and produce similar 8.3 short paths. Example from a real session: `useMissionAction.ts` → `USEMIS~1.TS`, `useMissionsStream.ts` → `USEMIS~2.TS`. Both files are 5 KB-ish, and the orchestrator confused which is which when writing base64 to ShortPath.

**Symptom**: the write succeeds (same short path string), the verification reads back the wrong size, and the orchestrator either (a) thinks both writes succeeded when only the second one did, or (b) overwrites the wrong file with valid content and ships a broken system.

**Verified 2026-06-23 on [your-product] `useMissionsStream.ts`**: I ran the ShortPath recipe on what I thought was `useMissionsStream.ts`. The size on disk was 6238 bytes, the original `useMissionsStream.ts` was supposed to be 6238 bytes — so the size-check passed. But `tsc` then reported `Module '"@/hooks/useMissionAction"' has no exported member 'useMissionAction'`. The fix landed in `USEMIS~1.TS` (which was `useMissionAction.ts`), overwriting the original `useMissionAction.ts` with the content of `useMissionsStream.ts`.

**Symptom-detection recipe** (after any ShortPath write, before declaring done):

1. **Size-check the source file AND the destination file** before and after the write. Mismatched sizes are the only signal that the wrong file was written.
2. **Grep the destination file for a unique string from the intended content** AND for a string that should NOT be there (e.g. "if you wrote file A but file B is in the ShortPath, file B's distinctive string will be present").
3. **Spot-check 3-5 lines from the destination file via `Get-Content`** and visually compare to the intended source.

**Defensive recipe — always pre-verify the ShortPath resolves to the right file**:

```bash
# Before writing, run this and verify the output matches the expected file
ssh [ssh-user]@laptop "powershell -Command \"\$f = Get-Item '$SHORT'; Write-Host (\$f.FullName + ' | ' + \$f.Length + ' bytes | ' + \$f.LastWriteTime)\""
# Check: does the FullName look right? does the size match what you expect? is the timestamp recent?
# If the size is OFF by even 1 byte, you have the wrong short path — abort and re-discover
```

**Defensive recipe — write to a unique temp path on the laptop side, not directly to the ShortPath**:

```bash
# 1. Write the new content to a temp path on the laptop with a unique name
ssh [ssh-user]@laptop "powershell -Command \"[IO.File]::WriteAllBytes('C:\Users\[your-username]\\AppData\\Local\\Temp\\edit_<RANDOM>.b64', \$b64)\""
# 2. Verify the temp file is exactly the size you expect
ssh [ssh-user]@laptop "powershell -Command \"(Get-Item 'C:\Users\[your-username]\\AppData\\Local\\Temp\\edit_<RANDOM>.b64').Length\""
# 3. THEN move it to the ShortPath with explicit verification
ssh [ssh-user]@laptop "powershell -Command \"Move-Item 'C:\Users\[your-username]\\AppData\\Local\\Temp\\edit_<RANDOM>.b64' '$SHORT' -Force; Get-Item '$SHORT' | Select-Object Length, LastWriteTime\""
```

The intermediate temp file gives you a "did the bytes roundtrip correctly" gate that you do not have when writing directly to the ShortPath.

**The principle**: any 8.3 short path is a 6-character alias for a longer path. If two files have the same first 6 characters in their short path, the controller has to disambiguate. The defensive recipes above (size-check, grep-for-content, temp-file staging) are the only way to avoid silent aliasing bugs. Skipping them is the failure mode.

## 8.3 ShortPath for Hebrew paths in non-PS1 PowerShell commands (validated 2026-06-23)

The existing "PowerShell + Hebrew paths over SSH" recipe handles the *script body* case (write the `.ps1` as ASCII, pass Hebrew as `-Path`). There is a second case the existing recipe does not cover: **one-off SSH commands where the Hebrew path has to be a literal in the PowerShell expression** (e.g. `[IO.File]::WriteAllBytes($path, $bytes)` where `$path` came from a controller-side variable, or `Get-Content $path` for a quick read, or `cd $path` to run `npx` from there).

The fix is to use the 8.3 short path returned by `Scripting.FileSystemObject`:

```bash
ssh [ssh-user]@laptop 'powershell -NoProfile -Command "$fso = New-Object -ComObject Scripting.FileSystemObject; $f = $fso.GetFile(\"C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx\"); Write-Host $f.ShortPath"'
# Output: C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1\src\COMPON~1\OPENCL~4.TSX
```

The short path is pure ASCII. Every subsequent PowerShell command can use it without re-encoding risk:

```bash
ssh [ssh-user]@laptop 'powershell -Command "Get-Item C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1\src\COMPON~1\OPENCL~4.TSX | Select-Object Length, LastWriteTime"'
ssh [ssh-user]@laptop "powershell -NoProfile -Command \"[IO.File]::WriteAllBytes('C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1\src\COMPON~1\OPENCL~4.TSX', [Convert]::FromBase64String((Get-Content C:\Users\[your-username]\AppData\Local\Temp\edit.b64 -Raw)))\""
ssh [ssh-user]@laptop 'cd C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1 && npx tsc --noEmit && npm run test:unit'
```

**Why it works**: the short path is computed on the laptop side (where the Hebrew bytes are native), is pure ASCII on the wire, and points to the same inode as the long path — so any subsequent read/write/cd finds the right file.

**When to prefer ShortPath vs `Get-ChildItem -Recurse` vs `-Path $param`**:

- **Use `Get-ChildItem -Recurse -Filter <name>`** when you don't know the exact long path and need to discover a file in a Hebrew-named tree
- **Use ShortPath** when you already know the full long path and need to pass it to a non-discovering cmdlet (write, read, copy, run-from-dir) as a literal
- **Use `-Path $param`** when you're shipping a `.ps1` script the user will run with the Hebrew path on the command line

**Mandatory verification after any write via ShortPath**: `Get-Item $short | Select-Object Length, LastWriteTime` — `LastWriteTime` MUST be within the last few seconds. If it's the same as before, the write hit a different path, the file was locked, or OneDrive sync was in flight.

**Combined recipe for "agent does the cross-machine transfer" (validated 2026-06-23)** — when the user has explicitly opted out of doing the work themselves and BUILDER has failed:

```bash
# 1. Encode the new file as base64 (orchestrator side)
base64 -w0 /path/to/edited_file.tsx > /tmp/edit.b64

# 2. Ship base64 to a non-Hebrew path on the laptop
scp /tmp/edit.b64 [ssh-user]@laptop:C:[user-home]/AppData/Local/Temp/edit.b64

# 3. Discover the ShortPath (one SSH call, pure ASCII output)
SHORT=$(ssh [ssh-user]@laptop 'powershell -Command "$fso = New-Object -ComObject Scripting.FileSystemObject; $fso.GetFile(\"C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx\").ShortPath"')

# 4. Decode base64 and write to the ShortPath (one SSH call, no Hebrew on the wire)
ssh [ssh-user]@laptop "powershell -Command \"[IO.File]::WriteAllBytes('$SHORT', [Convert]::FromBase64String((Get-Content C:\Users\[your-username]\AppData\Local\Temp\edit.b64 -Raw)))\""

# 5. Verify write landed
ssh [ssh-user]@laptop "powershell -Command \"Get-Item '$SHORT' | Select-Object Length, LastWriteTime\""

# 6. Run user-side validation
ssh [ssh-user]@laptop "cd C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1 && npx tsc --noEmit && npm run test:unit"
```

## When [regex]::Escape fails: line-based replacement (validated 2026-06-14)

`[regex]::Escape()` over a multi-line here-string can fail silently if the target file has CRLF endings and the here-string uses LF (or vice versa), or if backticks inside the here-string collide with PS escape. Symptom: `-replace` reports `[OK]` but the file is unchanged.

**Fallback recipe — read as line array, splice, write as array:**

```powershell
$lines = Get-Content $path
$startIdx = -1; $endIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^  useEffect\(\(\) => \{$' -and $startIdx -eq -1) {
        # Identify block by 2-line pattern in next 15 lines
        $window = ($lines[$i..($i+15)] -join "`n")
        if ($window -match 'setInterval\(fetchIt, 8000\)') {
            $startIdx = $i
        }
    }
    if ($startIdx -ne -1 -and $endIdx -eq -1 -and $lines[$i] -match '^\s*\},\s*\[\]\);$') {
        $endIdx = $i
    }
}
if ($startIdx -ge 0 -and $endIdx -ge 0) {
    $newBlock = @(
        '  usePollWhileVisible(async () => {'
        '    /* ... */'
        '  }, 8000);'
    )
    $before = $lines[0..($startIdx-1)]
    $after  = $lines[($endIdx+1)..($lines.Count-1)]
    Set-Content -Path $path -Value ($before + $newBlock + $after)
}
```

Line-based is slower to write but always works. Use it for the second attempt when regex fails. Pair with the negation check above to confirm both halves of the swap happened.

## Backup vs delete: when a `.bak` file is BIGGER than current (validated 2026-06-14)

A `.bak` of an old config file is often **larger** than the current file because the old version had features that were later removed. Deleting it loses the diff trail.

**Recipe: archive, don't delete, when `Length(bak) > Length(current) * 0.7`:**

```powershell
$bak = "C:\src\[your-product]\src\lib\config.ts.bak-v2-20260602-070746"
$archiveDir = "C:\src\[your-product]\.archive\config-history"
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
}
Move-Item $bak "$archiveDir\$(Split-Path $bak -Leaf)" -Force
```

Add `.archive/` to `.gitignore` if not already. Document the move in the slice commit message: "Archived `config.ts.bak-v2-...` to `.archive/config-history/` (old version had X features that are no longer in current — diff is preserved for archaeology)."

For `.bak` files that are clearly stale tiny patches of recent fixes (e.g. `hermesJarvis.ts.bak-fix-bridge-token-20260613-...` from yesterday's 5-minute fix), ordinary delete is fine — they don't carry archaeology value.

## Recommended sequence

### 1. First fix correctness regressions
Examples:
- broken callback route
- mismatched package ID in deep links
- failing auth flow

Steps:
- reproduce failure
- patch the specific root cause
- run the failing test directly
- run broader suite
- commit

### 2. Harden child-process bridges before optimizing UX
When a backend route shells out to an LLM/agent CLI or other helper process:
- do not pass user text, transcripts, prompts, or secrets as argv; argv can leak through process listings/logging
- prefer stdin or another non-argv channel for request payloads
- do not pass `process.env` wholesale; build a minimal allowlist and exclude provider/API/app secrets that the child does not need
- propagate HTTP/client aborts into the child process and terminate it so canceled requests do not keep expensive work running
- add tests for all three invariants: prompt absent from argv, secrets absent from child env, and abort kills/cancels the child
- add a safe `/api/version` or equivalent runtime endpoint when serving preview/tunnel builds so QA can detect checkout/build/mode drift without exposing paths, env, or secrets
- protect expensive public-preview voice endpoints with a lightweight app-level gate and rate limit when appropriate; keep health/version readable and safe
- when adding a browser-facing shared token for preview/tunnel protection, pair backend `Authorization: Bearer ...` enforcement with a frontend helper that reads a `VITE_*` token and adds the header to all relevant request helpers
- when a browser/mobile provider path works locally but hangs behind Cloudflare/tunnels/cookie auth, debug the proxy framing before rewriting provider code: chunked POSTs may need to be materialized, `Transfer-Encoding` stripped, and `Content-Length` reset; see `references/protected-tunnel-proxy-startup.md`
- see `references/protected-tunnel-proxy-startup.md` for the reusable voice-agent runtime hardening checklist, tests, and smoke pattern
- see `references/deploy-audit-panel-and-esm-dotenv.md` for the `/api/manifest` + UI "🧾 מה רץ" panel pattern the user asks for after every secure-tunnel deploy, the ESM `import`-hoisting pitfall that breaks `dotenv` in `server.ts` (services reading `process.env` at module top level get the pre-config value, even when the `.env` is loaded on the next line), the Playwright `setExtraHTTPHeaders` workaround for Basic-Auth URLs (Chrome 146+ removed `user:pass@host` URL syntax), and the recurring port trap on the voice-agent repo (`backend/src/server.ts` is the real server, not the root `src/`)
- after a selective pack-merge, before declaring done: verify the consumer's `.env.local` bearer token still byte-matches the producer's (no `PLACEHOLDER` suffix, no template marker); see `references/env-token-placeholder-trap.md` for the diagnostic + prevention pattern, and run the producer→consumer diff as a step between "copy new files" and "tsc"
- before declaring an auth/header/payload fix done, verify the fix actually reaches the consumer: read the importer, confirm it sends the new header, smoke-test before+after; see `references/verify-fix-matches-actual-consumer.md` for the full worked example from the 2026-06-14 slice 4.A incident where the X-Hermes-Token "fix" was dead code
- when stripping Unicode ranges in JS regexes, never use a `U+XXXXX` (5-hex) range in a character class — the engine silently folds it to a `U+XXXX` range plus the trailing literal ASCII chars, eating your input; see `references/js-regex-surrogate-pair-gotcha.md` for the diagnostic recipe and the corrected `safePrompt.ts`

## LLM spec/plan prompts: budget tokens for the OUTPUT, not the prompt (validated 2026-06-14)

A recurring shape across [your-product]'s pipeline, plan writers, and design-spec generators: a system prompt asks the LLM for a multi-section markdown deliverable (e.g. a 9-section Design Spec, a 6-section project plan, a 10-task checklist), and the code passes a tiny `max_tokens` budget that fits a 2-3 section reply, not the full deliverable. The LLM truncates mid-section, the consumer (a UI parser, a downstream agent) gets a stub, and the user sees "the build worked but the plan was vague."

**Symptom → diagnosis in 4 steps:**

1. Count the required sections in the system prompt (e.g. `## 1. Concept … ## 9. First Milestones` = 9 sections).
2. Multiply by ~300-500 tokens of *expected output* per section (real content, not a heading).
3. Compare to `max_tokens` in the corresponding `chat()` / `chatOnce()` call. If the budget is < 70% of step 2, truncation is guaranteed.
4. The fallback template silently kicks in only when the output is *shorter than the fallback threshold*, not when it's truncated. So a 2,800-token output truncated to 1,200 tokens is accepted as "real" and the user sees a half-finished spec.

**Concrete fix recipe (pipeline.ts shape):**

```ts
// BEFORE — looks fine, isn't
const out = await chat(sys, `Project: ${title}\nIdea: ${idea.slice(0, 1500)}\nTags: ${tags}`, 1400, signal);
if (out && out.length > 200) return out;     // 200 chars is ~60 tokens — too low
return fallbackTemplate;

// AFTER
const out = await chat(sys, `Project: ${title}\nIdea: ${idea.slice(0, 1500)}\nTags: ${tags}`, 3500, signal);
if (out && out.length > 600) return out;     // require at least 1-2 sections of substance
return fallbackTemplate;
```

**Rule of thumb for multi-section markdown generators:**

| Sections in prompt | Min `max_tokens` | Min fallback threshold (chars) |
|---|---|---|
| 1-2 | 600 | 200 |
| 3-4 | 1500 | 500 |
| 5-7 | 2500 | 800 |
| 8-10 | 3500 | 1200 |
| 10+ checklist-style | 2000-3000 | 600-1000 |

**Smoke check after the fix:** run a real capture→shape→decide cycle on the live server. Assert (a) the spec's body length > 1500 chars, (b) every numbered section heading is present, (c) if the prompt asked for `n` markdown checkboxes, count them — they should be ≥ n, not 0. If a smoke shows the heading list is complete but checkboxes are 0, the LLM hit the token cap and stripped the list items. See `references/llm-multi-section-prompt-sizing.md` for the worked pipeline.ts audit + the fix commits.

## Code paths must branch on the artifact, not the route label (validated 2026-06-14)

A recurring anti-pattern in the [your-product] pipeline: routes that ask the LLM to produce a structured deliverable also stamp a `route` field on the item (`project | action | idea | reference | escalate`). Downstream code branches on `route === "project"` to decide whether to call the next-stage generator. When the classifier returns a low-confidence or "wrong" route, the next-stage generator is silently skipped — even when the underlying artifact (e.g. `designSpec`) was actually produced upstream.

**Symptom in production (2026-06-14):** the `/api/pipeline/decide` route called `breakIntoTasks(item.title, item.plan, ...)` only when `item.plan` was present. After the shape step was enhanced to write a `designSpec` for `route === "project"`, items that came back as `route === "escalate"` (the most common classifier result in the live session) had a populated `designSpec` but no `plan` — and `breakIntoTasks` never ran. The user saw a 6-item `building` stage instead of a populated task checklist.

**Fix recipe — branch on the artifact, fall back to the label:**

```ts
// BEFORE — gates the side-effect on a stale field
if (item.plan && !item.tasks) item.tasks = await breakIntoTasks(item.title, item.plan, req.signal);

// AFTER — gates on what actually exists, with explicit precedence
if ((item.plan || item.designSpec) && !item.tasks) {
  item.tasks = await breakIntoTasks(item.title, item.designSpec || item.plan, req.signal);
}
```

**Audit rule for the slice review:** when patching a route that consumes items with a `route` field, grep for `route === "X"` and ask: "does this gate matter to the artifact the user is going to see, or only to the LLM classification? If only the latter, refactor to gate on artifact presence."

## `buildArtifact` returning 200 with garbage content (validated 2026-06-14)

The single most dangerous failure mode in the [your-product] build pipeline: `POST /api/pipeline/build` returns HTTP 200 with `{ ok: true, file: "...html" }` and writes a file to disk, but the file is the LLM's "I don't have any previous context, please share the existing HTML" reply — not HTML. The user sees a green toast, a 200 in the dev log, and a non-functional artifact. Two `200 in 2.3min` / `200 in 116s` lines in the server log mask a completely broken build.

**Root cause:** the `generateComplete` helper in `src/lib/pipeline.ts` calls the bridge coder with a system prompt and a user prompt, then retries by appending "Continue the HTML file from exactly where you stopped. Output ONLY the remaining code." Some bridge-backed models (especially the cloud default picked by Hermes bridge) interpret the *continuation turn* as a fresh chat — they respond as if asked to start a new conversation, with no memory of the prior turn. The response is conversational, not code.

**Three independent symptoms in the live log:**

- `POST /api/pipeline/build 200 in 2.3min` — long latency because the bridge retry burned 2 minutes on a conversation-style reply.
- The vault item stays in `stage: building` instead of `shipped` because `buildArtifact` returned an HTML "stub" (not `< 200 chars`, so it didn't trigger the 502 path).
- The on-disk HTML file is ~700 bytes of apology text, not a 30KB deliverable.

**Two working remediations (apply both):**

1. **Output-side validation.** Don't trust the length check alone. Add a second guard: the response must contain `<!DOCTYPE html>` or `<html` (case-insensitive), must contain `</html>`, and the length after extraction must be > 5000 chars for a single-page build. If any check fails, return 502 with the truncated/raw text and do NOT write to disk.

2. **Prompt-side fix.** Replace the "Continue from where you stopped" retry turn with a single-shot `max_tokens: 12000` generation when the bridge is the coder. Reasoning: if the LLM cannot fit a complete page in 7K-8K tokens, it cannot fit a continuation either — the continuation is just as truncated. The current 3-pass `generateComplete` doubles latency and gives no quality benefit. A single 12K-token pass with the full design spec in the user prompt is faster and produces a more coherent single-page result.

**Mandatory smoke after any `buildArtifact` change:** do not trust `200 OK`. Read back the saved file from `FCC_SCRATCH_ROOT/<project>/<slug>.html` and assert (a) starts with `<!DOCTYPE html>` or `<html`, (b) length > 5000 chars, (c) contains `</body>` and `</html>`, (d) no string `please share` / `could you` / `I don't have` (the apology signatures). If any check fails, the build did not succeed even if the API said it did.

## PowerShell + Hebrew paths over SSH: the encoding trap (validated 2026-06-14)

Embedding Hebrew paths (e.g. `C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]`) inside a `.ps1` script body is a recurring multi-step trap:

1. **`scp` re-encodes the bytes as `windows-1255` / `latin-1`** on the wire. The script lands on the laptop with the Hebrew bytes in the wrong encoding. When PowerShell parses the script, it sees `xcx\bxox-xY` and fails with `Missing variable name` or `String is missing the terminator`.
2. **`Out-File -Encoding utf8` adds a BOM by default.** Reading back the file via `Get-Content` (or via `scp` again) yields the original content but the BOM corrupts line 1 in any diff tool. The first-line BOM also breaks Next.js/TS source if the script wrote a `.ts` file via `WriteAllText` without `-NoBOM`.
3. **`powershell -Command` with Hebrew in a single-quoted string** over SSH also re-encodes. Even with `[Console]::OutputEncoding = UTF8`, the parser sees the wrong bytes for the path literal.
4. **BOM double-write.** `[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)` adds a BOM. Then a follow-up `Get-Content` of the same file shows a leading `﻿` (U+FEFF) in the diff, which looks like content change but is just encoding noise.

**Working recipe (validated end-to-end on [your-product]):**

```python
# From the orchestrator (Linux Python), build the script and write it as ascii-only:
script = '''param([string]$Path)
$ErrorActionPreference = "Stop"
$f = $Path
$c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
# ... patch logic ...
[System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8)
# Always strip BOM after writes:
$bytes = [System.IO.File]::ReadAllBytes($f)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
  [System.IO.File]::WriteAllBytes($f, $bytes[3..($bytes.Length-1)])
}
'''
# Write the script with the *target path* passed in as a PowerShell parameter, NOT
# embedded as a Hebrew string inside the script body.
with open('/tmp/fix.ps1', 'wb') as f:
    f.write(script.encode('ascii'))
subprocess.run(['scp', '/tmp/fix.ps1', 'admin@laptop:/Users/[ssh-user]/fix.ps1'])
# Then on the laptop side, the PowerShell discovers the path via Get-ChildItem:
ps = (
    "$repo = (Get-ChildItem -Directory -Path 'C:\Users\[your-username]\\OneDrive' "
    "  -Recurse -ErrorAction SilentlyContinue -Depth 3 -Filter [your-product] "
    "  | Select-Object -First 1).FullName; "
    "$pl = Join-Path $repo 'src\\lib\\pipeline.ts'; "
    "& 'C:\\Users\\[ssh-user]\\fix.ps1' -Path $pl"
)
subprocess.run(['ssh', 'admin@laptop', f'powershell -NoProfile -Command "{ps}"'])
```

**Key rules:**

- The `.ps1` body must be **pure ASCII** — the Hebrew/UTF-8 paths live only in PowerShell-side variable expansion, not in the script literal.
- After every `WriteAllText`, **always strip the BOM** with the 3-byte read/write shown above. Next.js/TS files with BOM at column 1 look like garbage diffs in `git diff`.
- `param([string]$Path)` MUST be the first non-comment line of the script. Putting it later in a multi-line `Write-Output` heredoc is a parse error.
- `Get-ChildItem -Recurse` with the Hebrew path is the only way to get the real `FullName` on the laptop side — direct path literals in `-Command` get re-encoded before parsing.

## npm via `Start-Process` over SSH: empty log file (validated 2026-06-14)

Calling `npm run build` (or any long-running `npm` command) via PowerShell `Start-Process` over SSH, even with `-RedirectStandardOutput $logPath -RedirectStandardError $errPath -PassThru`, **silently produces empty log files** on the remote host. The PID appears briefly (e.g. `PID=75372`), the process exits cleanly (RC 0), and the log files are 0 bytes. `next build` is never actually invoked.

**Root cause:** `npm.cmd` is a thin wrapper that invokes `node` with a specific JS bootstrapper. `Start-Process` attaches the redirect streams to `npm.cmd`'s own process, but `npm.cmd` exits before `node` writes anything to those handles. By the time `node` (the real builder) starts, its stdout/stderr are not connected to the captured files.

**Working alternatives (in order of preference):**

1. **Run the build synchronously in PowerShell** and capture `$out = & npm.cmd run build 2>&1 | Out-String`, then `[System.IO.File]::WriteAllText($logPath, $out, [System.Text.Encoding]::UTF8)`. This blocks the SSH connection for the duration of the build, but it works and the log is faithful. Use this for any build under 10 minutes.
2. **Wrap the build in a `.bat` file** with explicit redirection (`@echo off` + `call npm run build > log.txt 2>&1`), launch `cmd.exe /c batch.bat` with `Start-Process`. The `.bat` file's redirection survives the `npm.cmd` → `node` handoff.
3. **Use `npx tsc --noEmit` instead of `next build`** when you only need a typecheck smoke. `tsc` is 5-10x faster than `next build` on a 50K-LOC Next.js project and gives a 95% equivalent signal for "did my patch break types?".

**Anti-pattern (what does NOT work):**

- `Start-Process npm.cmd -RedirectStandardOutput file.log` — empty log.
- `cmd /c "npm run build > file.log 2>&1"` over SSH with Hebrew in the working directory — quoting/encoding breaks the redirect.
- `& npm.cmd run build | Out-File log.txt` from `powershell -Command` — gets blocked by Hermes' foreground `&` backgrounding guard.

**Mandatory verification after every build attempt:** always check `$logPath.Length` and `Get-Content $logPath -Tail 5` before claiming the build ran. If the log is 0 bytes, the build did NOT happen — re-run with one of the working alternatives. Never report "build succeeded" based on a 0-byte log or a passing `Start-Process` exit code.

See `references/powershell-hebrew-and-npm-over-ssh.md` for the full transcript (encoding trap, BOM, the 3 working `npm` invocation patterns, and the 3 anti-patterns that look right but silently fail).

- `references/ps1-heredoc-over-ssh-fails.md` — the "why `Set-Content -Value @'...'@` over SSH doesn't work" recipe. The 3 layered failure modes (terminator eaten by bash, Hebrew path re-encoded, .ps1 with Hebrew literal) and the working pattern: pure-ASCII .ps1 file delivered via `scp`, Hebrew paths as parameters via ShortPath. Use this recipe when applying N surgical patches to a single large file in one user-side operation.

## `pendingTimers` + `safeTimeout` pattern for React client components (validated 2026-06-23)

When a React client component fires fire-and-forget `setTimeout` in click handlers, error handlers, or async callbacks (toasts, status reset, post-launch reload, "open in folder" feedback), the timer can fire AFTER the component unmounts. The fix is a `useRef<Set<ReturnType<typeof setTimeout>>>` cleared in an unmount `useEffect`. Drop-in helper:

```tsx
const pendingTimers = useRef<Set<ReturnType<typeof setTimeout>>>(new Set());

function safeTimeout(fn: () => void, ms: number): ReturnType<typeof setTimeout> {
  const t = setTimeout(() => { pendingTimers.current.delete(t); fn(); }, ms);
  pendingTimers.current.add(t);
  return t;
}

useEffect(() => {
  return () => {
    pendingTimers.current.forEach((t) => clearTimeout(t));
    pendingTimers.current.clear();
  };
}, []);

// Replace every fire-and-forget setTimeout with safeTimeout
async function doIt() {
  setStatus("loading");
  await fetch(...);
  setStatus("done");
  safeTimeout(() => setStatus("idle"), 1500);   // was: setTimeout(() => setStatus("idle"), 1500);
}
```

**When to apply** (verified 2026-06-23 across 9 components in [your-product]):

- Click-handler toasts (clipboard feedback, "Copied!" indicator)
- Post-launch reloads (auto-refresh list 1.5s after submit)
- Status resets (`setError` → `setTimeout(setIdle, 3000)`)
- `window.setTimeout(...)` calls in `finally` blocks
- Any setTimeout that fires within a window shorter than the typical user dwell on the component

**When NOT to apply**:

- `setTimeout` inside a `useEffect` that already returns a cleanup function (`clearTimeout(ref.current)` is the right pattern there)
- `setTimeout` inside a `Promise` chain or async retry — `await new Promise(r => setTimeout(r, ms))` is fine because the timer is awaited and the function returns
- Server-side `lib/*` utilities — no React lifecycle, no useEffect cleanup needed

**For `pollRef` race conditions** (e.g. `pollRef.current = setTimeout(...)` inside a recursive `pollX` function called from itself): clear BEFORE setting to prevent a stale timer from firing after the new one is scheduled:

```tsx
// BEFORE — race: old timer can fire after the new poll completes
pollRef.current = setTimeout(() => pollX(...), 6000);

// AFTER — safe
if (pollRef.current) clearTimeout(pollRef.current);
pollRef.current = setTimeout(() => pollX(...), 6000);
```

**For `addEventListener` with one-shot cleanup** (the right pattern when addE count == remE count in the file):

```tsx
useEffect(() => {
  const onCustom = () => doSomething();
  window.addEventListener("my-event", onCustom);
  return () => window.removeEventListener("my-event", onCustom);
}, []);
```

This is the *correct* pattern, NOT `pendingTimers`. The grep audit will show `addE=2, remE=2` for these files — leave them alone.

See `references/daniel-machine-layout.md` for the operational reference distilled from it (what to do, not what's in the file).
- See `references/9-category-public-repo-audit.md` for the worked June 2026 FullStack-Builder audit: 4-category first pass = "0 findings" (false confidence); 9-category second pass = 60+ findings; 3 commits to clean.
- See `references/python-heredoc-batch-replacement.md` for the Python `<< 'PYEOF'` heredoc pattern that handles multi-line, Unicode, and multi-pattern batch replacement without the `sed` escaping nightmares.

## `patch` tool indentation failure is consistent — use sed/awk fallback (validated 2026-06-23)

The `patch` tool repeatedly adds 2 extra spaces of indentation to the wrong column when the `old_string` includes lines from a partial `read_file` (offset/limit) window, OR when a previous patch attempt left a partial intermediate state. Verified across HermesMCPCatalog.tsx, MissionArtifactsPanel.tsx, ProjectsExplorer.tsx in the same session — every patch wrote `    const pendingTimers` (4-space) inside a `  ` (2-space) context, cascading to 6/8-space indentation for the function body. The `patch` tool reports `"success": true` with a diff that looks correct; the file on disk is mis-indented.

**Detection recipe** (run after every `patch` call on a TS/TSX file):

```bash
# After patch, grep for suspicious 4+ space leading indent on new declaration lines
read_file path=<file> offset=<patch_start - 5> limit=<patch_length + 10>
# Look for: lines that start with "    " (4 spaces) followed by const/function/useState/etc.
# inside a 2-space-indent region. Or run a quick check:
grep -nE '^    (const|function|useState|useEffect|return)' <file>
```

**Fix recipe — column-by-column sed/awk** (verified, deterministic, faster than re-patching):

```bash
# If the patch added 2 extra spaces to lines N..M, fix them:
awk 'NR>=N && NR<=M { sub(/^    /, "  "); } { print }' file.tsx > file_fixed.tsx && mv file_fixed.tsx file.tsx

# If the patch left the new block at 6-space indent (deeper than needed), trim 2 spaces per level:
sed -i 'N,M{s/^      /    /}' file.tsx
# Then run tsc + read_file again to confirm.
```

**Why retrying the patch is the wrong move**: if the fuzzy match misfired once on indentation, it will misfire again with a slightly different `old_string`. The patch tool's diff preview is what the tool *would* write, not what it *did* write. Switch tools immediately.

**Anti-patterns that triggered this in the verified session**:

- "The patch returned `success: true` with the right diff, so it worked." — No, the file is mis-indented. Read it back.
- "I'll patch again with a smaller `old_string` to fix the indentation." — Layered patches compound the problem. Revert from the local mirror or write_file the corrected version.
- "The first lines look right, so the rest probably does too." — `patch` may apply only part of the change if the fuzzy match finds a similar-but-not-identical region.

**When this is most likely to bite**:

- The file was previously read with `offset`/`limit` pagination
- The file has multiple components and the patch crosses a component boundary (Pitfall 20 in `[your-product]-architecture-debug`)
- The `old_string` includes whitespace-sensitive content (indentation, blank lines, JSDoc)
- A previous patch left a partial intermediate state on disk

## BUILDER → VERIFY → JUDGE loop protocol (validated 2026-06-23)

When the user asks for autonomous fixes with a BUILDER/VERIFY/JUDGE loop until JUDGE approves ("תתקן הכל אוטונומית... תזמן 3 סוכנים... BUILDER, VERIFY, JUDGE... עד שה-JUDGE אומר שזה עובד"):

| Role | What it does | Tool surface |
|---|---|---|
| **BUILDER** | Orchestrator main thread: `read_file` + `patch` + `write_file` + SSH upload | file editing tools, terminal |
| **VERIFY** | Runs `tsc --noEmit`, `npm run test:unit`, `Get-Item ... Length` checks, UTF-8 roundtrip checks | terminal, browser_console |
| **JUDGE** | Orchestrator reviews VERIFY output: did the fix actually land? Are there side effects? Should BUILDER retry or move on? | main thread reasoning |

**Implementation note**: in this orchestrator's current tool set, BUILDER/VERIFY/JUDGE are NOT separate subagents — they are the orchestrator's own actions labeled internally. The user sees one continuous autonomous loop, not three agents. If the orchestrator has `delegate_task`, it can spawn actual subagents; otherwise the orchestrator runs all three roles in sequence.

**Iteration rules**:

1. **Per-file scope**: BUILDER edits one file at a time. VERIFY runs the full check suite (tsc + tests). JUDGE decides pass/fail. Loop on one file until clean, then move to next.
2. **Batch of 3**: do NOT scan + fix all N files in one continuous loop. Each fix = ~5 tool iterations (read, patch, ssh, upload, tsc). For 9 files = 45+ iterations, hits the budget. Do 3 files per session turn, run tsc at the end of the batch, report progress.
3. **Failure → BUILDER retry, not escalate**: if VERIFY reports a syntax error or test failure, BUILDER fixes the same file again. Do NOT move to the next file until the current one is clean.
4. **JUDGE may declare a fix out-of-scope**: if a "fix" would change architecture (e.g. adding a missing API endpoint, building a new UI), JUDGE should declare it a separate task and stop the loop. Don't sneak in scope expansion.

**When JUDGE should stop the loop** (declare "done, here's the report"):

- All requested files have clean tsc + tests.
- The remaining items would require architecture changes (new endpoint, new UI component, new config key).
- The iteration budget for this session is close to expiring (report progress + remaining items).

**Heuristic for "is this a fix or a feature?"**:

- **Fix**: the component exists, it has a bug (memory leak, race, missing cleanup), and the fix changes < 30 lines.
- **Feature**: the component doesn't exist, the API endpoint is missing, or the fix requires new files / new routes / new UI elements.

A 9-file memory-leak pass is a fix loop. A "build the Mastermind UI" request is a feature loop, not appropriate for BUILDER/VERIFY/JUDGE without an explicit scope agreement first.

## UTF-8 source corruption diagnostic: `mklink /J` junction shortcut (validated 2026-06-23)

When a Hebrew Windows path (`C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src`) blocks PowerShell from running on the laptop side because of wire encoding, the **`mklink /J` junction** is the cleanest escape hatch:

```bash
# Create a junction with an ASCII alias (one time, on the laptop)
ssh [ssh-user]@laptop "powershell -Command \"if (Test-Path 'C:\Users\[your-username]\AppData\Local\Temp\src_link') { Remove-Item 'C:\Users\[your-username]\AppData\Local\Temp\src_link' -Force }; cmd /c mklink /J C:\Users\[your-username]\AppData\Local\Temp\src_link 'C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src'\""

# Now every script can use the pure-ASCII path
ssh [ssh-user]@laptop "powershell -Command \"Get-ChildItem -Recurse -Path 'C:\Users\[your-username]\AppData\Local\Temp\src_link' -Include *.tsx | Select-Object FullName, Length\""
```

**Why it beats ShortPath or `Get-ChildItem -Recurse`**: the junction is a directory alias, not a per-file path. Scripts that read multiple files (`Get-ChildItem -Recurse`, `Select-String -Path`, etc.) all just work without needing to discover or pre-compute ShortPaths. Re-create the junction if the laptop restarts or the user moves the repo.

**Recipe for upload-via-stdin + UTF-8 roundtrip** (the working alternative when ShortPath is too cumbersome):

```bash
# 1. Build the file locally with write_file (no Hebrew, no encoding issues)
# 2. Pipe through stdin to PowerShell WriteAllBytes with explicit UTF8 encoding (no BOM)
cat /tmp/clean_file.tsx | ssh [ssh-user]@laptop "powershell -Command \"\$input | Out-File -Encoding utf8 'C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\File.tsx'\""
# 3. Verify the bytes landed correctly — file size should match the local file
ssh [ssh-user]@laptop "powershell -Command \"(Get-Item 'C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\File.tsx').Length\""
```

This works because `Out-File -Encoding utf8` on PowerShell 5.1+ uses UTF-8 without BOM. The base64 alternative (`base64 -w0 → Out-File → [Convert]::FromBase64String`) is more robust to encoding issues but requires the extra decode step. Prefer `Out-File` for files that are already pure ASCII (the post-fix versions), and base64 for files that contain non-ASCII bytes.

## "Read file, build new version locally, deploy via stdin" pattern (validated 2026-06-23)

When a fix needs to make a non-trivial structural change to a large file (1000+ lines) on the laptop, the safest sequence is:

1. **Dump the file to base64** on the laptop side via a script with one ASCII-safe path argument.
2. **Transfer the base64** through the SSH pipe (`tr -d '\r\n[:space:]' < b64.txt | base64 -d > local.tsx`).
3. **Edit the local copy** with `read_file` + `patch` + `write_file` — full visibility, no SSH wire issues.
4. **Re-deploy** via `cat local.tsx | ssh ... "powershell -Command \"\$input | Out-File -Encoding utf8 '<full path>'\"\"`.

This is the only safe way to handle files where:
- The original encoding is mixed Latin-1/UTF-8 (the corruption hides the structure).
- The patch needs surgical insertions at multiple line ranges (the `patch` tool works on a local copy, not over SSH).
- The user has explicitly opted out of running scripts themselves (`תעשה את זה אתה`).

**Critical step**: after every dump, count the base64 length BEFORE decoding — if it doesn't match `ceil(file_size / 3) * 4`, the dump is corrupt and decoding will produce garbage. The dump script on the laptop side must report `[Convert]::ToBase64String(bytes).Length` as part of its output.

## Reference index for this skill (selected)

- `references/llm-multi-section-prompt-sizing.md` — full audit of the [your-product] pipeline.ts spec generators: section count → `max_tokens` sizing table, the 4-line diff in commit `b95513a`, the live smoke matrix, and the 3 adjacent issues discovered (buildArtifact garbage, classifier stuck on escalate, localeCompare crash) with the follow-up commit `a7dec6f` for the third.
- `references/powershell-hebrew-and-npm-over-ssh.md` — full transcript of the encoding/redirect/BOM traps, the Python→PS1→Get-ChildItem recipe for Hebrew paths, the 3 working `npm` invocation patterns (synchronous & Out-String, .bat wrapper, npx tsc --noEmit), and the 3 anti-patterns that look right but silently fail.