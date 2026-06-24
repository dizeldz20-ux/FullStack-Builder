# Cavecrew Prompts — Pre-built archeology prompts

When `build-product` automatically invokes `cavecrew-investigator`, `cavecrew-builder`, or `cavecrew-reviewer`, use these pre-built prompts. Each is tuned for a specific scenario.

<references>
@cavecrew-investigator (Hermes skill — read-only locator)
@cavecrew-builder (Hermes skill — 1-2 file editor)
@cavecrew-reviewer (Hermes skill — diff reviewer)
</references>

---

## 1. Feature-area mapper (build-feature Phase 0)

**When:** First time touching a code area for a new feature
**Subagent:** `cavecrew-investigator`
**Mode:** parallel-safe (spawn 2 if >20 files)

```text
You are investigating the code area I'm about to touch for a new feature.

Repo: <repo-path>
Stack: <detected-from-package.json-or-requirements.txt>
Recent commits: <git log --oneline -10>
AGENTS.md (if exists): <path-or-none>

INVESTIGATE:
1. Map the code area this feature will touch (top 10 file:line entries)
2. List 3-5 risky branches or legacy paths that look dangerous to modify
3. Identify existing tests in this area (file paths only)
4. Note any project-specific conventions in AGENTS.md or README

OUTPUT FORMAT (caveman-compressed, file:line only):
Defs: <path:line> — <symbol> — <note>
Refs: <path:line> — <symbol> — <note>
Tests: <path:line> — <symbol> — <note>
Risky: <path:line> — <symbol> — <note>

DO NOT propose fixes. DO NOT edit. Investigate only.
```

---

## 2. Stuck-recovery archeologist (stuck-recover Phase 1)

**When:** Build is stuck, need to compare what the user thinks vs reality
**Subagent:** `cavecrew-investigator`
**Mode:** sequential

```text
You are investigating why a build is stuck.

Repo: <repo-path>
Last shipped slice: <from state.md>
Last attempted task: <from state.md or recent git log>
Stuck duration: <how long>

INVESTIGATE:
1. What is the ACTUAL state of the code right now? (file:line table)
2. What was last attempted? (git log -10 + recent uncommitted changes)
3. Are there any error messages, test failures, or broken imports?
4. What does the "current path" look like vs what the user thinks is happening?

OUTPUT FORMAT (caveman-compressed):
Reality: <one paragraph — what's actually true>
Recent: <last 3 commits>
Failed: <last test failures or errors if any>
Path: <step-by-step of what code currently does in the stuck area>

DO NOT propose fixes. Investigate only.
```

---

## 3. Ship-readiness auditor (ship.md Phase 0)

**When:** About to ship, need to find pre-ship issues
**Subagent:** `cavecrew-investigator`
**Mode:** sequential (1 invocation)

```text
You are auditing the codebase for pre-ship issues.

Repo: <repo-path>
Branch: <branch-being-shipped>
Last 20 commits: <git log --oneline -20>

INVESTIGATE:
1. Any secrets in code? (grep for api_key, password, token patterns)
2. Any TODO/FIXME/console.log/debugger left in production-bound code?
3. Any untracked files that should be committed or .gitignored?
4. Any test files that don't actually test behavior (mock-everything, no assertions)?
5. Any import cycles or broken references?

OUTPUT FORMAT (caveman-compressed):
Secrets: <path:line> — <pattern> — <action-needed>
Debug: <path:line> — <debug-call> — <action-needed>
Untracked: <path> — <note>
Bad-tests: <path:line> — <test-name> — <why-bad>
Broken: <path:line> — <import> — <note>

DO NOT propose fixes. Investigate only.
```

---

## 4. Pre-edit risk check (incremental-hardening, sub-classify)

**When:** About to edit a sensitive area (auth, secrets, schema)
**Subagent:** `cavecrew-investigator`
**Mode:** sequential

```text
You are classifying the risk of an upcoming edit.

Repo: <repo-path>
Target files: <list>
Edit type: <auth|secrets|schema|api-contract|other>

INVESTIGATE:
1. What other code depends on these files? (callers, importers)
2. What tests cover them? Are tests behavior-based or implementation-coupled?
3. Is there a backup path / rollback strategy documented?
4. What's the blast radius if this edit breaks something?

OUTPUT FORMAT (caveman-compressed):
Callers: <path:line> — <symbol> — <note>
Coverage: <path> — <test-style> — <coverage-pct-or-qualitative>
Blast: <area> — <impact-radius>

Bucket: REAL | ALREADY_PROTECTED | DESIGN_INTENT
```

---

## 5. Surgical edit dispatch (cavecrew-builder)

**When:** Need a 1-2 file typo fix / mechanical rename / single-function rewrite
**Subagent:** `cavecrew-builder`
**Mode:** NEVER parallel with other editors

```text
You are making a surgical edit.

Target: <absolute-path>
Scope: <1-line description>
Forbidden: <list of files NOT to touch>

Edit ONLY if scope is 1-2 files. Refuse if scope > 2 files.

Return receipt:
Files changed: <list>
Diff stat: <+/-/>
Receipt: <what was done, where, why>
```

---

## 6. Diff reviewer (cavecrew-reviewer, pre-commit)

**When:** Pre-commit, need a quick scan
**Subagent:** `cavecrew-reviewer`
**Mode:** sequential

```text
You are reviewing a diff before commit.

Branch: <branch>
Diff stat: <output of git diff --stat>
Files changed: <list>

OUTPUT (one-line-per-finding):
- <path:line> — <finding> — <severity: critical|major|minor>
- <path:line> — <finding> — <severity>

No fixes. No proposals. Findings only.
```

---

## How to dispatch from build-product

```bash
# In a task file, when cavecrew invocation is needed:

# 1. Identify which prompt (#1-6 above) fits
# 2. Fill the placeholders with repo-specific values
# 3. Dispatch via delegate_task with:
#    - role: "leaf"
#    - toolsets: ["terminal", "file"]  (for investigator/builder)
#    - goal: paste the filled prompt
# 4. Wait for receipt
# 5. Incorporate into next phase

# Example pseudocode in next-slice planning:
nxt=$(delegate_task(
  goal=$(cat frameworks/cavecrew-prompts.md | sed -n '/^## 1/,/^---/p' \
        | sed "s|<repo-path>|$PWD|g; s|<detected...>|$STACK|g")
  role="leaf"
  toolsets=["terminal", "file"]
))
```

---

## Anti-patterns in cavecrew dispatch

| Don't | Why |
|-------|-----|
| Run 3 cavecrew-investigators in parallel on the same area | Diminishing returns; costs tokens |
| Use cavecrew-builder for 3+ file refactor | Will refuse; use subagent-driven-development instead |
| Skip the prompt template, hand-write a casual question | Templates enforce the caveman-compressed output contract |
| Forget to fill placeholders | Subagent gets confused about repo path / stack |
| Dispatch cavecrew-builder while another editor is active | File conflict; sequential only |