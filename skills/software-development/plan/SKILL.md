---
name: plan
description: "Plan mode: write an actionable markdown plan to .hermes/plans/, no execution. Bite-sized tasks, exact paths, complete code. Also use for kickoffs on multi-step work: verify the codebase first, lock scope axes with the user, then propose 5 principles + plan before any code. For the user (Telegram, Hebrew): clarify() with short labels, no tech detail in options; treat 'stop' / 'עצור' / 'תוריד את X' as hard scope lock."
version: 2.3.0
author: Hermes Agent (writing-craft adapted from obra/superpowers)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [planning, plan-mode, implementation, workflow, design, documentation, kickoff, scope-discipline]
    related_skills: [subagent-driven-development, test-driven-development, requesting-code-review]
---

# Plan Mode

Use this skill when the user wants a plan instead of execution.

## Core behavior

For this turn, you are planning only.

- Do not implement code.
- Do not edit project files except the plan markdown file.
- Do not run mutating terminal commands, commit, push, or perform external actions.
- You may inspect the repo or other context with read-only commands/tools when needed.
- Your deliverable is a markdown plan saved inside the active workspace under `.hermes/plans/`.

## Output requirements

Write a markdown plan that is concrete and actionable.

Include, when relevant:
- Goal
- Current context / assumptions
- Proposed approach
- Step-by-step plan
- Files likely to change
- Tests / validation
- Risks, tradeoffs, and open questions

If the task is code-related, include exact file paths, likely test targets, and verification steps.

## Save location

Save the plan with `write_file` under:
- `.hermes/plans/YYYY-MM-DD_HHMMSS-<slug>.md`

Treat that as relative to the active working directory / backend workspace. Hermes file tools are backend-aware, so using this relative path keeps the plan with the workspace on local, docker, ssh, modal, and daytona backends.

If the runtime provides a specific target path, use that exact path.
If not, create a sensible timestamped filename yourself under `.hermes/plans/`.

## Interaction style

- If the request is clear enough, write the plan directly.
- If no explicit instruction accompanies `/plan`, infer the task from the current conversation context.
- If it is genuinely underspecified, ask a brief clarifying question instead of guessing.
- After saving the plan, reply briefly with what you planned and the saved path.

---

# Writing the Plan Well

The rest of this skill is the craft of authoring a *good* implementation plan — the content that goes inside the markdown file above.

## Overview

Write comprehensive implementation plans assuming the implementer has zero context for the codebase and questionable taste. Document everything they need: which files to touch, complete code, testing commands, docs to check, how to verify. Give them bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume the implementer is a skilled developer but knows almost nothing about the toolset or problem domain. Assume they don't know good test design very well.

**Core principle:** A good plan makes implementation obvious. If someone has to guess, the plan is incomplete.

## When a Full Implementation Plan Helps

**Always use before:**
- Implementing multi-step features
- Breaking down complex requirements
- Delegating to subagents via subagent-driven-development

**Don't skip when:**
- Feature seems simple (assumptions cause bugs)
- You plan to implement it yourself (future you needs guidance)
- Working alone (documentation matters)

## Bite-Sized Task Granularity

**Each task = 2-5 minutes of focused work.**

Every step is one action:
- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

**Too big:**
```markdown
### Task 1: Build authentication system
[50 lines of code across 5 files]
```

**Right size:**
```markdown
### Task 1: Create User model with email field
[10 lines, 1 file]

### Task 2: Add password hash field to User
[8 lines, 1 file]

### Task 3: Create password hashing utility
[15 lines, 1 file]
```

## Plan Document Structure

### Header (Required)

Every plan MUST start with:

```markdown
# [Feature Name] Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

### Task Structure

Each task follows this format:

````markdown
### Task N: [Descriptive Name]

**Objective:** What this task accomplishes (one sentence)

**Files:**
- Create: `exact/path/to/new_file.py`
- Modify: `exact/path/to/existing.py:45-67` (line numbers if known)
- Test: `tests/path/to/test_file.py`

**Step 1: Write failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify failure**

Run: `pytest tests/path/test.py::test_specific_behavior -v`
Expected: FAIL — "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify pass**

Run: `pytest tests/path/test.py::test_specific_behavior -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## Writing Process

### Step 1: Understand Requirements

Read and understand:
- Feature requirements
- Design documents or user description
- Acceptance criteria
- Constraints

### Step 2: Explore the Codebase

Use Hermes tools to understand the project:

```python
# Understand project structure
search_files("*.py", target="files", path="src/")

# Look at similar features
search_files("similar_pattern", path="src/", file_glob="*.py")

# Check existing tests
search_files("*.py", target="files", path="tests/")

# Read key files
read_file("src/app.py")
```

### Step 3: Design Approach

Decide:
- Architecture pattern
- File organization
- Dependencies needed
- Testing strategy

### Step 4: Write Tasks

Create tasks in order:
1. Setup/infrastructure
2. Core functionality (TDD for each)
3. Edge cases
4. Integration
5. Cleanup/documentation

### Step 5: Add Complete Details

For each task, include:
- **Exact file paths** (not "the config file" but `src/config/settings.py`)
- **Complete code examples** (not "add validation" but the actual code)
- **Exact commands** with expected output
- **Verification steps** that prove the task works

### Step 6: Review the Plan

Check:
- [ ] Tasks are sequential and logical
- [ ] Each task is bite-sized (2-5 min)
- [ ] File paths are exact
- [ ] Code examples are complete (copy-pasteable)
- [ ] Commands are exact with expected output
- [ ] No missing context
- [ ] DRY, YAGNI, TDD principles applied

## Principles

### DRY (Don't Repeat Yourself)

**Bad:** Copy-paste validation in 3 places
**Good:** Extract validation function, use everywhere

### YAGNI (You Aren't Gonna Need It)

**Bad:** Add "flexibility" for future requirements
**Good:** Implement only what's needed now

```python
# Bad — YAGNI violation
class User:
    def __init__(self, name, email):
        self.name = name
        self.email = email
        self.preferences = {}  # Not needed yet!
        self.metadata = {}     # Not needed yet!

# Good — YAGNI
class User:
    def __init__(self, name, email):
        self.name = name
        self.email = email
```

### TDD (Test-Driven Development)

Every task that produces code should include the full TDD cycle:
1. Write failing test
2. Run to verify failure
3. Write minimal code
4. Run to verify pass

See `test-driven-development` skill for details.

### Frequent Commits

Commit after every task:
```bash
git add [files]
git commit -m "type: description"
```

## Common Mistakes

### Vague Tasks

**Bad:** "Add authentication"
**Good:** "Create User model with email and password_hash fields"

### Incomplete Code

**Bad:** "Step 1: Add validation function"
**Good:** "Step 1: Add validation function" followed by the complete function code

### Missing Verification

**Bad:** "Step 3: Test it works"
**Good:** "Step 3: Run `pytest tests/test_auth.py -v`, expected: 3 passed"

### Missing File Paths

**Bad:** "Create the model file"
**Good:** "Create: `src/models/user.py`"

## Execution Handoff

After saving the plan, offer the execution approach:

**"Plan complete and saved. Ready to execute using subagent-driven-development — I'll dispatch a fresh subagent per task with two-stage review (spec compliance then code quality). Shall I proceed?"**

When executing, use the `subagent-driven-development` skill:
- Fresh `delegate_task` per task with full context
- Spec compliance review after each task
- Code quality review after spec passes
- Proceed only when both reviews approve

## Remember

```
Bite-sized tasks (2-5 min each)
Exact file paths
Complete code (copy-pasteable)
Exact commands with expected output
Verification steps
DRY, YAGNI, TDD
Frequent commits
```

**A good plan makes implementation obvious.**

## the user kickoff overlay (user preference)

For builds that touch UX, safety, or are large enough to warrant a
kickoff, the user expects a short pre-plan section in the deliverable
*before* any code is written. The session where this pattern was
established (June 2026, Hermes Voice → self-hosted STT migration)
worked in this exact shape:

### 1. Read source docs / research first, then summarize

If the change is informed by upstream docs, an external spec, or a
prior research thread, **read it, summarize it in the user's language,
and quote the relevant numbers**. the user will say "stop and read the
docs" if you skip this. For the voice pipeline session the
deliverable was a Hebrew summary of the Hermes Agent Voice Mode docs
(RMS=200, 0.3s, 3.0s, 15s defaults), a side-by-side "what we did
wrong" table, and a decision template. The summary came *before* any
code or even architecture proposal.

### 2. Present 5 concrete build principles

Before any code, list 5 numbered design rules that the new build
will follow. For the voice pipeline session:

1. Two-stage VAD matching Hermes defaults exactly.
2. Pluggable STT provider abstraction.
3. Hallucination filter mandatory.
4. Self-hosted by default; Deepgram as opt-in fallback.
5. ElevenLabs TTS preserved — do not touch.

These principles serve as the contract that subsequent code review
can be checked against. If the implementation drifts from any
principle, that is a flag.

### 3. Ask 5 decision questions in order

Before coding, surface the choices that meaningfully shape the
architecture. The voice pipeline session used these five:

1. Adopt Hermes defaults verbatim, or override?
2. Default STT backend — local or cloud?
3. Install the new dependency now?
4. Keep the existing flow as fallback, or delete it?
5. Keep the existing TTS, or switch?

The pattern: questions are ordered so the first answer shapes the
later ones, and each maps to one of the 5 principles. Wait for
explicit answers before proceeding. Do not start coding on "I will
use sensible defaults" — the user wants to be asked.

### 4. Then propose the architecture, then code

Only after the principles + decisions are locked, present the
file layout and start writing. This sequence has been verified
across multiple sessions to avoid rebuilds and mid-build scope
negotiations.

---

## Pitfall: Don't build a new plan from scratch when 50+ existing plans already cover the territory

The kickoff overlay above is for *greenfield* work or work that
genuinely has no existing research behind it. For *existing
projects*, do the existing-research check **before** the
"5 principles" step.

**Symptom:** user asks "build me X in this repo" and the repo
already has `docs/plans/`, `references/`, `PLAN.md`, or
`sessions/.../plans/` directories with prior plans that touch
the same surface. If the agent skips reading them and proposes
5 fresh principles + a fresh plan, two things happen:

1. The user has to interrupt with "stop, read the existing
   research first" — wasted turns.
2. The new plan may contradict the existing research (which is
   usually more thorough than what the agent produces in one
   turn).

**Check before kickoff:**

```bash
# Look for prior plans in the obvious places
ls -la docs/plans/ .hermes/plans/ PLAN.md 2>/dev/null
# Find skills with references/ directories touching the domain
ls ~/.hermes/skills/ | while read s; do
  [ -d ~/.hermes/skills/$s/references ] && \
    ls ~/.hermes/skills/$s/references 2>/dev/null | head -5
done
# Find plans in session transcripts if relevant
session_search query="<domain keywords>" limit=5
```

If prior plans exist, the kickoff shifts to:
- Read the most relevant 2-4 references (not all of them).
- In the user's language, summarize what the prior research
  already established.
- Surface the *delta* — what does the new ask change vs the
  prior plan? Often the answer is "nothing, the prior plan is
  the answer; let's pick up at task N".
- Only then offer principles + plan.

**Reference:** see `references/dont-rebuild-existing-plans.md`
for a worked example (the June 2026 hermes-elevenlabs-ruby
session, where 150+ references existed under
`[your-voice-product]-product-squad/references/`).

---

## Pitfall: Confirm scope before the kickoff — and watch for silent scope expansion

The kickoff is about *what the user asked for*. Three failure
modes recur:

1. **Asking the wrong question at clarification time.** The
   agent asks "which scope?" with one of the choices being
   something the user has already excluded. Example: in the
   hermes-elevenlabs-ruby session, the agent offered
   "rubpo only / repo+gateway / everything-incl-UI" and the
   user said "drop the gateway — that's a separate solved
   problem." The right call was to ask "is the gateway in
   scope?" *first*, not bundle it as an option.

2. **Scope drift between turns.** User says "build me X" in
   turn 1. In turn 3 the agent is touching Y, Z, W because
   they "seem related." When the user says "stop" or
   "עצור", that is a strong signal the agent drifted.

3. **Clarifying before verifying.** The agent asks "which
   scope?" without first running the existing smoke-test,
   checking git status, or hitting a health endpoint. The
   user then has to push back: "תבדוק קודם" or "תראה לי
   מה עובד קודם." The clarifying question often answers
   itself once you have the actual state in front of you.

## Pitfall: Don't ask the user for facts that are already in their system

This is the **"ask first, look second"** failure mode. The agent calls `clarify()` to ask the user for information that already exists somewhere the agent has access to.

**Trigger signals (when this rule fires):**

- "What stack do you build in?" → check `package.json`, `requirements.txt`, prior `AGENTS.md`
- "Which product is this for?" → check `~/.[vault-runner]/workspace/`, prior sessions via `session_search`, the user's `MEMORY.md` Project Contexts
- "What's your deploy target?" → check `~/.hermes/config.yaml`, `vercel.json`, `Dockerfile`, project `docs/hosting-architecture-decision.md`
- "What are your security defaults?" → check the existing skill (`incremental-hardening-refactor` is canonical for the user), `AGENTS.md` red lines, `RUBY_HARDENING_RULES.md`
- "Do you use TDD / vertical slices / subagents?" → check existing skill descriptions in `~/.hermes/skills/software-development/`
- "What does this code currently do?" → `read_file` the file, `git log` the area, ask `cavecrew-investigator`

**The user's correction that surfaced this rule** (2026-06-24, build-product kickoff):

> "לא הבנתי מה אתה רוצה לוודא מולי... יש לך גישה מלאה... תחפש בעצמך... לך אמור להיות את כל המידע הרלוונטי כדי לתכנן איזה שלב נכון יותר ממני... אתה יודע יותר טוב ממני זה בטוח"

Translation: "Why are you asking me? You have full access. Search yourself. You should have all the relevant info to plan which step is right — you know better than me."

**The rule, in order:**

1. **Before any `clarify()`, run the search.** Check, in this order:
   - The user's `MEMORY.md` (via Vault or session memory)
   - The project `AGENTS.md` (if one exists in the active repo)
   - The relevant `references/` directory in the relevant Hermes skill
   - Prior sessions via `session_search query="<domain keywords>"`
   - The actual repo: `ls`, `cat package.json`, `git log`, `git remote -v`
2. **If the search returns an answer, use it.** Don't ask the user what you just found.
3. **If the search is empty, ask one focused question with a *default*.** "I don't see X in your AGENTS.md or memory. Default to Y — confirm?" Not "what's X?" with no default.
4. **Never ask 3+ questions in a row before doing the search.** If you're tempted to, the search hasn't been thorough enough.
5. **Ask only the questions that are *irreversibly consequential*** (e.g. "private repo or public?", "delete existing or preserve?"). Reversible defaults should not be questions.

**The tension with gstack ETHOS "User Sovereignty"** — User Sovereignty says the user decides, not the model. This rule says the model should *find the answer itself first*, then ask only the residuals. The reconciliation: **boil the ocean in execution, minimize the questions to the user.** Ask only when the answer is irreversible, when the search is truly empty, or when the user's stated preference (in memory) is to be asked about that specific thing.

**Anti-patterns:**

- ❌ `clarify("What stack?", ["TS", "Python", "Go", "Rust"])` when `package.json` says TS
- ❌ `clarify("Which product?", ["[your-voice-product]", "Agentic OS", "[your-other-product]"])` when the working directory is `[vault-workspace]/[your-product-repo]`
- ❌ `clarify("Local-first or managed backend?", [...])` when `docs/hosting-architecture-decision.md` already says "managed HTTPS"
- ❌ `clarify("Hebrew or English UI?", [...])` when the user's `USER.md` says "מעדיף תקשורת בעברית"
- ✅ `clarify("Repo is empty. Build from scratch? Or pull from template?")` — when search confirmed it's empty
- ✅ `clarify("I see 3 products. Which one is this build for?")` — when search surfaced multiple, ambiguous candidates

**Worked example** (2026-06-24, the build-product kickoff that this rule came from): the agent asked three separate `clarify()` calls — "what language", "what scale", "where to save the skill" — before realizing it had access to all three answers already: the user's `MEMORY.md` says TS/Node primary, prior sessions show production-scale, and the user explicitly said "save to my Vault at ~/[hermes-config-dir]/memories/Hermes/". All three clarifications were unnecessary. The fix is encoded in this pitfall.

**Reference:** see `references/dont-ask-when-search-answers.md` for a 4-question decision checklist (search? → use? → ask with default? → ask only if irreversible?) and a worked counter-example.

## Pitfall: Plan that modifies code MUST verify the current state of that code first

**The rule:** Before writing any plan that proposes to **create, modify, or delete** files, configurations, or external state, the assumptions in the plan must be backed by an **observation in the same turn** — not by memory, an older VM copy, a previous session's notes, or a cached plan from a different repo. **Plan before verification = fabrication.**

**Where the trap fires:**

The agent is asked to fix a feature, refactor a module, or add behavior in a system. The agent remembers (or believes it remembers) the shape of the code — that `shape/route.ts` doesn't exist yet, that `fccAdminStatus` is exported, that the Vault stores JSON, that the prompt contract is in the system prompt. The agent writes a plan that creates files, imports symbols, and asserts formats. The plan looks detailed. It is **wrong on every structural claim**, because the live code has changed since the agent last touched it. The downstream implementer (Claude, Codex, or a subagent) gets a plan that does not match reality and either:

1. **Follows the plan verbatim** → overwrites working code with a parallel-but-incompatible implementation, breaks the preview, breaks the renderer, breaks the build because a symbol isn't exported.
2. **Stops to verify** → burns 30+ minutes rediscovering what the planner should have already known.
3. **Gives up** → the user gets "the plan is broken" with no actual work done.

**The user's experience** (from a June 2026 Agentic OS `/pipeline` session, captured in `references/plan-before-verification-fabrication.md`):

> The agent wrote a 419-line plan proposing to create `shape/route.ts` and `build/route.ts` that already existed, import `fccAdminStatus` that was not exported, store `designSpec` as JSON when it was actually a markdown string parsed by `DesignSpecView` at `PipelineView.tsx:399-534`, and call `agy.exe` for shape when the real flow used the Hermes bridge. The plan was handed to Claude Code, which (correctly) loaded `superpowers:executing-plans` and rejected the plan as "fundamentally wrong about the current state" before writing a single line. The agent would have wiped out working, sophisticated code.

**Concrete checks the planner must do, in the same turn the plan is written:**

- **Files proposed to create** → confirm they don't exist. `Get-ChildItem`, `search_files`, `git ls-files`. Don't trust the previous session's notes.
- **Files proposed to modify** → confirm they exist and read the current version. `read_file` with offset/limit, not a recollection of the shape.
- **Symbols proposed to import** → confirm they are exported. `grep "export"`, look at the actual file, not at a stale memory of the API.
- **Data formats proposed to read or write** → confirm the actual format. Open a real file, hit a real endpoint, look at a real response body. Don't guess YAML vs JSON vs markdown headers.
- **Endpoints / paths** → confirm the live route exists. `curl`, browser snapshot, the actual error you get when the route is wrong.
- **Token budgets, model names, binary paths** → confirm by querying the live system (`where agy.exe`, `curl /health`, `Select-String ... model`). The user once had to run three PowerShell commands over a 15-minute back-and-forth just to confirm the binary path the agent had assumed.

**What the plan must look like after verification:**

Every structural claim in the plan has a citation. Format the citation as a short inline evidence tag, e.g.:

```markdown
### Task 2: Add the `/api/pipeline/shape` endpoint

**Pre-verified facts (this turn, observed live):**
- `src/app/api/pipeline/shape/route.ts` already exists. [read_file, 1-200]
- It delegates to `src/lib/pipeline.ts` which exports `classifyIdea`. [grep "export function classifyIdea"]
- `classifyIdea` calls the Hermes bridge at `/v1/chat/completions`, NOT `agy.exe`. [read_file src/lib/pipeline.ts:180-220]
- The Vault stores items as `LOCAL MEMORY VUALT/AGENT OS MEMORY/Agentic OS/Pipeline/items/<slug>.md`. [ls, see client spec session]

**Scope lock:** do not touch `pipeline.ts`, do not create new modules, do not modify `PipelineView.tsx`. Only adjust the prompt + token budget inside `classifyIdea`. Single-function change, no new files.
```

If a planner cannot produce those citations because the live system is not reachable, the planner's deliverable is **not a plan** — it is a request to the user to provide the missing evidence. Stop and ask.

**Anti-patterns that indicate the rule was violated:**

- "I'll create `src/app/api/pipeline/shape/route.ts`" — when that file already exists in the live system.
- "Import `fccAdminStatus` from `@/lib/fcc`" — when that symbol is not exported (`fcc.ts:322`).
- "The design spec is stored as `{summary, components, criteria}` JSON" — when the renderer at `PipelineView.tsx:399-534` expects `## 1. Concept ... ## 9.` markdown.
- "Call `agy.exe --print-timeout 300s`" — when the real shape flow uses the Hermes bridge and never touches `agy.exe`.
- "Use `claude-sonnet-4-6` as the model" — when the live `fcc.ts` shows the model is read dynamically from `fccAdminStatus()`.

If any of these appear in a plan, the plan is fabrication. Re-verify the live state and rewrite.

**Reference:** see `references/plan-before-verification-fabrication.md` for the full worked session (the June 2026 Agentic OS `/pipeline` plan that proposed 4 missing files that all already existed, 1 import that was not exported, 1 data format that was wrong, and 1 binary path that was wrong).

---

## Pitfall: A plan is rarely a loop — but when it is, design the loop first

Most plans are one-shot workflows (write tasks, ship, exit).
But a non-trivial subset are loops in disguise: "roll out 10
features over 6 weeks", "migrate 50 users to a new auth
flow", "refactor 30 files with regression-safe commits". For
those, the `plan` skill is necessary but not sufficient — the
plan needs an explicit loop shape (trigger, action, feedback
check, stop rule, escalation).

**The rule:** if the plan has a recurring execution pattern,
invoke the `software-development/loop-library` skill in
**Design** or **Find** mode *alongside* `plan`. The loop
catalog (45 published loops) has ready-made scaffolds for the
common shapes (Builder-Reviewer, Plan Quality, Test
Stabilizer, Reflection). Only Design when no fit.

**Bridge reference:** see `references/loop-aware-planning.md`
for the decision tree ("is this a loop?" test), the mapping
from existing `plan` pitfalls to library loops, the 2026-06-24
build-product v1.2 worked example, and trigger phrases that
tell you when to invoke `loop-library` vs `plan` alone.

**Anti-pattern:** writing a 50-task plan with no exit
conditions, no feedback checks, and no escalation rule —
then handing it to a subagent and hoping it stops when it's
done. Without a loop shape, the subagent has no signal for
"done"; it will run until it hits a hard error or runs out of
context.

**Why this is its own pitfall, not "Loop prompting checklist"
in Runbooks:** the Runbooks entry is about *prompting an LLM*
to loop safely (max_iter, budget, done-signal). This pitfall
is about *designing a deliverable* (the plan file itself) to
include a loop, so the executor has clear bounds from the
start. Both are needed; they live in different places.

---

## Pitfall: Mid-stream read-only lock ("show me first" / "רק לראות")

A new turn of "show me" / "רק לראות" / "רק לבדוק" inside an
otherwise-approved build is a *strong* scope signal: the user
wants the agent to surface state, not to commit to a direction.
Three rules:

1. **Treat the rest of the turn as read-only.** No writes, no
   new files, no commits, no `npm install`, no `git clone`
   outside `/tmp`. Even "harmless" prep work is out of scope
   for that turn.

2. **End the turn with state, not proposals.** Show the
   evidence (smoke-test result, file tree, git status, health
   endpoint) and a short list of "what's green / what's red /
   what's ambiguous." Do not jump into "here's the plan."

3. **Wait for an explicit next-step prompt.** The user picks
   "verify state / build slice 1 / change plan / stop." Do
   not auto-continue into build mode just because the state
   report looked good.

**Symptom this rule exists for:** in the
final-voice-agent session, the user said "רק בדיקת ui" after
I'd been planning to build a 4-step pipeline. I treated it as
a read-only request, ran the existing UI smoke, and reported
state. That response was the right one. The mistake I almost
made (and the rule exists to prevent) is starting the
"and now let me build slice 1" path inside the same turn.

**Stronger form of the same rule (the user's pattern, June 2026):**
when the user says "review the code" / "look at the code" / "תעבור
על הקוד" without a build intent, treat it as **read-only over the
existing working tree** — do **not** `git clone` to `/tmp/`, do
**not** `npm install` to verify, do **not** even start the dev
servers. The user wants the agent's eyes on the code in place,
not a fresh end-to-end re-run. If verification requires running
something, ask first; do not assume "I'll just spin up a clone
in /tmp to test" is welcome. A `git clone` to `/tmp/` can be
welcome in a different context (e.g. "is the build clean for
recipients?") but the user signals that explicitly with words
like "test in /tmp" or "build verification" — not with "review
the code".

The escalation ladder for a "review the code" turn:

```
1. Read files in the working tree the user pointed at.
2. Grep the working tree for the specific patterns the user
   asked about (secrets, bugs, references, etc.).
3. Report findings + a short diff/patch plan.
4. WAIT for an explicit "go fix it" before touching files.
```

The most common drift this prevents: the agent hears "review",
also wants to "verify", `git clone`s to `/tmp/`, runs `npm install`,
sees a transient error, fixes it, and now the user has a surprise
commit in `/tmp/`, a working tree in the original repo they did
not know was being modified, and an extra 5 minutes of cleanup.
Trust the user's framing. "Review" means read + report.

## Pitfall: Background-process exit logs must not be sent to the user

When the user starts a long-lived process in the background (server,
dev server, watcher, tunnel), its eventual **exit is silent by
default**. Do not narrate it to the user in chat.

A real failure pattern from the final-voice-agent session:
- User asks to start a backend or Vite dev server.
- Agent runs `terminal(background=true, ...)` without
  `notify_on_complete=true`.
- The process eventually exits (restart, manual kill, or natural end).
- The system appends a one-line "process exited" note to the next
  tool result.
- The agent treats that note as if the user asked about it and
  produces a full Hebrew paragraph explaining "the backend was
  killed, here's what happened."
- The user gets spammed with "your server closed" messages every
  time the agent restarts anything.
- User reacts: "למה אתה שולח לי בהודעה כל פעם את מה שאתה עובד
  ברקע תראה מה אתה שולח לי כל רגע בטעות" — clear frustration
  signal.

**Rule:** treat background-process exit notices as **silent
operational telemetry**, not as user-facing events. Do not produce
a "your server stopped" message in response. The only exception is
when the user explicitly asked to be told when a specific process
ends, or when a long-running *test/build/CI* task finishes — and
even then, report the result, not the "process exited" event
itself.

This rule is independent of the **out-of-band user message**
mechanism: that is a *user* speaking mid-turn, not the *system*
noting that a process ended. Process-exit lines in tool results
are not user messages.

## Pitfall: For investigation/performance tasks, measure first, plan second

This pitfall is *adjacent* to "Plan before verification = fabrication" above but
distinct. The fabrication pitfall catches plans that *assume file shape*. This
one catches plans that *assume performance shape* — "the slow pages are A, B, C"
without ever measuring.

**Symptom (what the agent does wrong):** the user reports a vague performance
problem ("tabs are slow", "everything takes forever"). The agent immediately
drafts a plan: "Step 1: add `usePollWhileVisible` to the 4 polling files.
Step 2: convert `Promise.all` to `Promise.allSettled` in 3 route files.
Step 3: instrument...". The plan is plausible. It is also *probably aimed at
the wrong files*. Without measurements, the agent is pattern-matching to the
last performance fix it remembers, not to this codebase's actual hot spots.

**Rule:** for any investigation / performance / behavior task, **the first
slice of the plan is always measurement** — not fix. The deliverable is
*observed numbers* and *ranked hypotheses*, not a fix.

**Concrete pre-plan measurement (run before drafting, cite in the plan):**

```bash
# For "this app is slow" claims:
for path in / /a /b /c /d /e; do
  total=0
  for i in 1 2 3; do
    t=$(curl -s -m 30 -o /dev/null -w "%{time_total}" "$LAPTOP$path" 2>/dev/null)
    total=$(echo "$total + $t" | bc)
  done
  avg=$(echo "scale=3; $total / 3" | bc)
  size=$(curl -s -m 30 -o /dev/null -w "%{size_download}" "$LAPTOP$path" 2>/dev/null)
  echo "$path -> avg ${avg}s, size ${size} bytes"
done
```

Then rank by `time` (worst first). Only the worst 1-2 get a fix plan. The
others are within noise — do not touch them.

**Same rule for other investigations:**

- "the LLM is hallucinating" → before planning, sample N real outputs and
  tabulate failure mode. Don't fix until the failure pattern is named.
- "the API is slow" → before planning, time 10-20 requests end-to-end with
  `time curl ...`, sort by P50/P95. Don't fix until you know which calls.
- "memory is leaking" → before planning, take a heap snapshot at T0 and T+1h,
  diff the objects. Don't fix until you can name the leaking allocation.

**Why this matters for plans:** a plan grounded in measurements is *smaller*
than one grounded in pattern-matching. The user's June 2026 perf audit plan
went from "fix setInterval in 4 files + Promise.allSettled in 3 routes +
catch{} in 1 file + safePrompt regex in 1 file" (~10 file changes) to "focus
on `/` (6.5s) and `/chat` (4.4s), the other 5 routes are within noise" after
a 30-second measurement. The smaller plan is *more correct*, not just cheaper
to execute — the bigger plan was aimed at the wrong files.

**Anti-pattern:** "I'll add instrumentation as the first task, then we can
measure." Instrumentation during a fix is not measurement; it's guess-then-
confirm. Measure first, then plan the fix around what you learned.

**Reference:** see `references/measure-first-plan-second.md` for a worked
example (June 2026 Agentic OS perf audit: 7 routes × 3 hits, ranked, plan
refined from 10 file changes to 2 routes).

## Pitfall: "תעדכן את ה-AGENTS.md" — user pivots to relaxing a hard rule mid-task

**Trigger:** while the agent is mid-task on a focused, in-scope
deliverable (bug hunt, hardening pass, performance audit), the user
suddenly asks to relax a documented hard rule. Concrete shapes
that fired in real sessions:

- "תעדכן את ה-AGENTS.md כדי שהסוכן ישלוט במחשב האישי שלי" (asked
  in the middle of a memory-leak hardening session, 6 hours in,
  while tired)
- "עכשיו תתקין את X על המחשב שלי" mid-bug-fix
- "תעבור למצב לא-בטוח" mid-feature
- "תתעלם מהapproval gate" mid-action

**Why this is its own pitfall, not the "Bypass / anti-circumvention"
one above:** the Bypass pitfall covers requests that **circumvent
someone else's** protection (Cloudflare, ToS). This pitfall covers
requests that **relax the user's own previously-documented
hardening**, often based on momentary user state (fatigue, frustration,
"just this once"), in a session whose charter is something else.

**The rule, in order:**

1. **Do not execute. Do not modify the governance file. Do not
   modify any code.** The user has a documented hardening decision
   (e.g. "Cloud Jarvis בטוח, no shell, no filesystem" — see the
   May 2026 pattern in `[your-product]-architecture-debug`). That
   decision is the **default**. Reversing it requires a deliberate
   session, not a one-line mid-task instruction.
2. **Acknowledge the request explicitly.** Don't pretend the user
   said something else. "אני שומע שאתה רוצה להרחיב את Cloud Jarvis
   לשליטה במחשב האישי" — name the change.
3. **Name the contradiction.** "זו החלטה שונה מההחלטה ממאי 2026, ש
   היתה מתועדת ב-AGENTS.md, ב-RUBY_HARDENING_RULES, וב-MEMORY."
4. **Refuse to act in this session**, with one short sentence. Not
   five paragraphs of safety lecture — the Bypass pitfall is right
   that one refusal is the whole refusal. The rest of the turn is
   the alternative, not the moralizing.
5. **Offer the structured alternative.** A planning deliverable in
   the Vault, NOT a code change, NOT an AGENTS.md edit, NOT a
   "I'll start building it and we can stop later." The plan
   captures the user's intent, the security analysis, the
   proposed hardening (allowlist, confirmation gate, audit log,
   time-bound session, kill switch), the open questions, and the
   phased rollout. The plan is the user's *decision aid*, not a
   green light to start coding.
6. **Defer the decision to a fresh session with a clear head.** The
   user is tired, the session is mid-task, and architectural
   reversals do not belong in either state. The plan's last
   section should explicitly say "Next step: read this tomorrow
   with a clear head. Do not implement until then."

**Why the alternative is a plan, not a refusal-with-no-path:**

- A flat refusal with no alternative is the anti-pattern the user
  pushed back on multiple times ("לא מסרב", "אני רוצה שתעזור").
  The user has a real goal (control their computer by voice). The
  goal is legitimate. The right answer is "let's plan this
  properly so the security model survives."
- A plan in the Vault is the user's decision aid. They can come
  back to it tomorrow, edit it, accept the proposed hardening, or
  decide the risk is too high. The plan does not commit anyone to
  anything.
- Writing the plan costs the agent 1-2 turns. The plan is short
  (1-2 pages), in the user's language, and lists the open
  questions explicitly. It's the highest-leverage thing the agent
  can do for this class of request.

**Anti-patterns to refuse:**

- "I'll just edit AGENTS.md to add a `laptopControlAllowed: true`
  flag and we can wire it up." No. The hardening is not a flag
  away.
- "Let me start with the easiest piece — opening Chrome — and we
  can add safety later." The first time you open something on
  someone's machine, the trust boundary is already crossed. There
  is no "easy piece."
- "OK, you have full approval — going for it." The user said
  "yes" in a fatigued mid-task context, not in a planning
  context. The yes is not the right yes.
- Asking 5 questions inline instead of writing a plan. The user
  is tired; the questions will be answered in the morning from
  the plan, not in the chat at 1am.

**Worked example (2026-06-23, [your-product] hardening session):**
mid-session, after 6 hours of memory-leak work, the user said
"אני רוצה שתשנה את התוכנית שכך jarvis ישלוט על המחשב האישי".
This contradicted the documented May 2026 "Cloud Jarvis בטוח,
no shell" decision. The agent refused to modify AGENTS.md in
that session, wrote a 1-page plan to the Vault at
`[hermes-config-dir]/memories/Hermes/Brain/Architecture/Cloud Jarvis
Laptop Control Plan.md` with: target capability, threat model,
hardening requirements (allowlist, per-action confirmation, audit
log, time-bound session, kill switch, sandbox, network egress
control), open architectural questions, comparison vs current
safe Cloud Jarvis, recommended 4-phase rollout (Phase 1 =
read-only + open apps only, Phase 2 = sandboxed file ops, Phase 3
= shell with allowlist, Phase 4 = full capability only if 1-3
clean), and the explicit "next step: read tomorrow with a clear
head" footer. The user accepted the alternative and the session
returned to the bug-hunt. The plan lives in the Vault, is not
implemented, and is the user's decision aid for whenever they
want to revisit the topic.

**Reference:** see `references/mid-task-hardening-reversal.md` for
the full worked example including the plan structure and the
explicit "what I will NOT do without explicit approval" section
that the planning document opens with.

## Pitfall: Bypass / anti-circumvention requests are a hard refusal, not a negotiation

**The trap:** the user pushes for a tool that *circumvents someone else's
protection* — Cloudflare bypass, residential proxy spoofing, fingerprint
spoofing, "stealth" browser launchers, "I'll just rotate user agents", "use
cloudscraper / undetected-chromedriver", "I'll pay for one credit, just try
it once", "I don't care about ToS, just do it." The same request often
arrives in 3+ increasingly-plausible shapes:

1. **Direct:** "build me a Cloudflare bypass."
2. **Justified:** "it's a public site, the data should be free, just do it."
3. **De-risked:** "I'll only use it once / it's for research / I'll pay for
   the service so it's fine / it's not illegal, just against ToS."
4. **Disclaimed:** "I don't care about the legality, just do it." (This is
   the most dangerous because the agent might read it as user-consent to
   proceed.)

**The rule, in order:**

1. **Refuse the build.** Do not write the bypass code, do not add the
   dependency (`cloudscraper`, `undetected-chromedriver`, custom Chromium
   patches, residential proxy pools), do not start the headless browser with
   stealth flags. Each of these is the *thing the user is asking for*, not a
   tool to do it.
2. **Refuse the "try it once" variant.** One try is enough to consume the
   counter, leave a fingerprint, or get a residential proxy banned. The
   "I'll only do it once" framing does not change the action.
3. **Name the boundary once, in plain terms.** No need for a lecture. A
   single sentence: "I can't help build a Cloudflare bypass. That's a hard
   rule for me, not a negotiation." If pressed, repeat. **Do not apologize
   twice** — see `telegram-output-discipline`. One refusal is the whole
   refusal; the rest of the turn is the alternative.
4. **Offer a real alternative.** The pattern that works (verified June 2026
   for `payngo.co.il` + Cloudflare):

   | Alternative | What the user does | What I do |
   |---|---|---|
   | Talk to the site owner | email, ask for API | help draft the email |
   | Use a paid scraping service (Bright Data, ScraperAPI, Firecrawl stealth) | pay $50-200/mo, get a real proxy pool | integrate the API into the existing tool, do not bypass |
   | Use a different site | pick a site without aggressive anti-bot | build the scrape against the friendlier target |
   | Public data sources | search engines, RSS, catalogs | build against the open source |

5. **Hold the line on the alternative, too.** The user may say "no, the
   data is on this exact site, do the bypass." That is a *re-ask* of the
   original request, not a new request. Same refusal applies. The
   alternative is "use the paid service" or "talk to the owner," not
   "negotiate down to a softer bypass."

**Why this is a class-level rule, not a one-off:**

- The request recurs. It is the *most* common security-adjacent ask in
  client work and personal tooling. Any agent that builds scrapers,
  crawlers, form-fillers, or "data extraction from a site" tools will be
  asked this within 5-10 sessions.
- The "just this once" framing is real and tempting. It is also a
  well-known social-engineering pattern. The agent's only defense is to
  treat the framing as a *re-ask*, not a *new request*.
- The cost of *building* the bypass is borne by the user (ToS violation,
  IP ban, possible legal), not by the agent. The cost of *refusing to
  build* is borne by the agent (user frustration). The agent must put
  the user's long-term cost ahead of the agent's short-term friction.

**What the agent can do without crossing the line:**

- Use a *legitimate* residential proxy service the user already pays for
  (Bright Data, Smartproxy) — that's a third-party service, not a bypass.
- Use a stealth proxy tier of a paid scraping service (Firecrawl stealth,
  ScraperAPI) — same.
- Build the tool to *fail closed* on blocked sites, with a clear
  error message that tells the user which site blocked them and why.
- Help the user *contact the site owner* and *request API access*.

**What the agent cannot do, even if the user explicitly asks:**

- Build a Cloudflare bypass.
- Use `cloudscraper`, `undetected-chromedriver`, `playwright-extra` with
  stealth plugins, or similar.
- Customize a Chromium build to spoof TLS, canvas, or audio fingerprints.
- Use a "stealth" residential proxy pool that the user does not already
  have a paid contract for.
- Add code comments like `// bypass Cloudflare for site X` even as a
  joke — code is reviewed; jokes in code become TODOs.

**Reference:** see `references/bypass-hard-refusal.md` for the worked
example (June 2026 `payngo.co.il` + Cloudflare, 3 pushbacks from user,
agent held the line, ended on a paid-service alternative).

## Pitfall: Multi-slice plans need per-slice approval, not per-plan approval

A plan with N slices and one big "approve" is fragile. The
user typically wants to verify after each slice that:

- The slice ran end-to-end with the actual tools and providers.
- The output matches what the plan promised.
- No hidden assumptions surfaced (e.g., a provider is in
  fallback, a quota is exhausted, a config key was wrong).

**Pattern that worked** in the final-voice-agent session:

```
After plan is approved:
  for each slice in plan:
    1. Build the slice.
    2. Verify with the actual tools (real curl, real providers,
       real stdout, not "I would expect this to work").
    3. Report: slice N done, evidence X, what's next.
    4. WAIT for explicit "continue" or "next slice" before
       starting slice N+1.
```

The "wait" step is non-negotiable. The user has the right to
re-plan between slices, especially when verification surfaces
something the plan didn't predict (e.g., "the Hermes CLI does
not expose `text_to_speech` as a subcommand — we need a direct
ElevenLabs bridge instead").

## Pitfall: Hermes `tts` is an internal agent-tool, not a public endpoint

When designing a voice-agent web UI on top of Hermes, the obvious
assumption is "call the Hermes TTS endpoint to get audio." That
endpoint **does not exist** in the public surface. Verified in the
2026-06 final-voice-agent session:

- `hermes` CLI subcommands do **not** include `tts` or
  `text-to-speech`. The TTS dispatch lives in
  `tools/tts_tool.py` and is called *from inside an agent turn*
  when the agent decides to invoke the `tts` tool.
- The Hermes API server on `:8642` (when it is running) exposes
  OpenAI-compatible `/v1/chat/completions` and similar routes. It
  does not expose a TTS-only route.
- So a thin "browser → backend → Hermes → audio" pipeline
  cannot be built by calling Hermes. The pattern that works:

```
[Browser] → POST /api/voice/turn
              │
              ▼
[Your backend] → ask Hermes (LLM) → [reply text]
              │
              ▼
[Your backend] → call provider directly (ElevenLabs/MiniMax/etc.)
              → return OGG/Opus to browser
```

The TTS step must call the provider **directly from your
backend**, using the same config keys Hermes would have used
(`tts.elevenlabs.voice_id`, etc.) but not going through Hermes
itself.

**Implication for design:** if the user wants voice in a web UI
on top of Hermes, you need a thin backend that:
1. Calls Hermes (CLI subprocess or API server) for the LLM reply.
2. Calls the TTS provider directly (with the user's API key) for
   the audio.

**Don't** promise the user "Hermes will speak for you" — Hermes
will *think* for you, and your backend will speak.

This pitfall does **not** apply to Hermes-gateway-driven voice
(Telegram, WhatsApp, etc.) because there the gateway itself calls
the `tts` tool from inside the agent turn.

## Pitfall: Hermes subprocess env isolation — gateway keys are not inherited

When the user runs a backend via `npx tsx` outside the gateway's
process, the keys in the gateway's environment are **not**
available to the backend. Verified 2026-06 in the
`final-voice-agent` session:

- `hermes gateway run` process holds `MINIMAX_API_KEY` in its
  environment.
- A separate `tsx src/server.ts` invocation does **not** see
  that env, even if both are owned by the same user.
- `/proc/<gateway-pid>/environ` is readable only if the calling
  process has the right uid AND the gateway pid is correct. A
  recently-restarted gateway changes pid.
- So an "I'll just inherit the gateway env" assumption breaks
  after any restart.

**Options when the user wants the new backend to use the same
keys as the gateway:**

1. **Source the same env file the gateway uses** (e.g.
   `~/.hermes/.env` via `set -a && . ~/.hermes/.env && set +a`).
   Works if both processes read the same file.
2. **Read keys directly from `~/.hermes/config.yaml`** and
   resolve `key_env` to `process.env`. Mirror what Hermes itself
   does at startup.
3. **Run the new backend as a systemd unit alongside the
   gateway** with the same `EnvironmentFile=`. Most reliable.

Do not promise "the keys are already there" without verifying
in the actual shell that will run the backend.

## Pitfall: When the user says "start from scratch" / "להתחיל מחדש", confirm what "fresh" means

"From scratch" has at least three distinct meanings that look
similar:

- **New repo, greenfield** — create a fresh repo, do not touch
  existing code.
- **Nuke an existing repo and rebuild inside it** — overwrite the
  existing repo's content, keep the name and remote.
- **Analyze first, no edits** — read the existing code, decide
  what to copy, but do not change anything yet.

In the final-voice-agent session, the user said "להתחיל
מחדש" and I correctly asked a clarification before creating
the new repo. Without that clarification, I would have picked
"new repo" by default — which happened to be right, but
"nuke existing" would have been a destructive mistake.

**Rule:** when the user says "from scratch" or any equivalent
phrasing, ask a 3-choice `clarify`:
- new repo
- nuke existing and rebuild in place
- analyze first, decide later

before any `mkdir` / `gh repo create` / file write.

**Order of operations for the first 3 turns of a kickoff:**

```
Turn 1: read-only verification
  - clone/inspect the repo(s) mentioned
  - run existing smoke tests, hit health endpoints
  - check git status, git remote, git log
  - skim PLAN.md, README, key config files
  Report: what's actually here, what works, what's broken.

Turn 2: scope axes (only if verification surfaced ambiguity)
  - present 2-4 explicit in/out axes as a checklist, not
    a multiple-choice bundle
  - default each axis to a sensible value, let user override
  - if the verification already answered the question,
    skip this turn entirely

Turn 3+: principles + questions + plan
  - only after scope is locked
```

**Scope-axes format (clarify):** present each axis as a
short Hebrew/English label, default value, and one-line
reason. Do NOT present 4 multiple-choice options that all
look similar. Example axes for the hermes-elevenlabs-ruby
session:

- Repo code (in) — what the user pointed me at
- Gateway / Telegram service (out) — already solved
- Jarvis UI surface (in) — relevant to the ask
- Provider live smokes (out) — already verified

**Watch for "stop" / "עצור" / "תוריד את X" mid-stream.** When
the user removes an item from scope, do not re-add it in
a later turn. Update the working scope list and stick to it.

## Pitfall: "Clone this URL, push to my own private GitHub, install on my server" — the 3-phase version of "from scratch"

When the user's "from scratch" message includes a specific
URL to clone from plus an install-on-server intent, the
clarification splits into **three** irreversible phases, each
of which needs its own approval:

1. **Clone + research** (read-only, low risk)
2. **Push to a new private GitHub repo under the user's
   name** (medium risk — repo lives in the user's namespace
   forever, even if deleted)
3. **Install on the user's server** (high risk — port
   conflicts, dependency bloat, service interference, model
   downloads)

The natural failure mode is to bundle all three into a
single "go" because the user said "וגם... וגם..." in the
same message. They are NOT the same risk class. Treat them
as three slices of one kickoff and ask for slice-by-slice
approval.

**Concretely, the order in a "clone + push + install" request:**

```
Turn 1:  Clone-for-inspection + research summary + scope
         axes (private repo name, install now or research
         first, which slices are in/out)
         + WAIT for user answers

Turn 2:  Push to private GitHub (only after Turn 1 approved)
         + verify with curl 404 to anonymous
         + WAIT for "go install" or "do research first"

Turn 3+: Install per the repo's docs
         + verify ports, dependencies, services are not
           already in use (Hermes gateway on :8642, Caddy
           on :443, etc.)
```

**Why the push is the real irreversible step, not the
install.** The install is reversible: kill the process,
uninstall the venv, remove the systemd unit. The push is not
reversible in a clean way: the repo URL is in the user's
namespace, in the git remote, in any CI / webhook / notification
that fires on `dizeldz20-ux/<name>`, and in the chat history.
If the user later says "actually, that's a fork of a sketchy
repo", the cleanup is `gh repo delete` + scrub the chat + hope
nobody bookmarked it. Pre-push vet is the right time to catch
that.

**Worked example from a real session:** the user said "תפתח
פרוייקט חדש בגיטהאב פרטי / תקרא לא Jarvis / תשכפל את
הריפו https://github.com/[your-org]/[your-product].git / ותתקין אותו
על השרת". The agent did the right thing on phase 3 (stopped
before install, asked scope axes) and the right thing on phase 1
(verified the source repo, ran security quick-check via the
existing secrets patterns from `safe-public-repo-push`).
The improvement opportunity: phase 1 should have explicitly
loaded `agent-repo-security-vetter` for a proper red-flag
scan of [your-org]/[your-product] BEFORE the push, not relied on the
secrets-pattern subset from `safe-public-repo-push`. The
vetter's Step 3 (red-flag scan: shell execution, network
exfiltration, secret access, destructive actions, privilege
escalation, obfuscation, prompt injection) catches things
the secrets scan does not.

**Default scope axes for any "clone X, push to private repo,
install on my server" request:**

| Axis | Default | Why |
|---|---|---|
| Vet before push (red-flag scan on the source repo) | **IN** | irreversible once pushed |
| Read every line of upstream docs/SETUP.md/TROUBLESHOOTING.md | **IN** | the install phase can't be designed without it |
| Surface port conflicts, env-var collisions with existing services | **IN** | critical on a server with Hermes/Caddy already running |
| Run any `npm install` / `pip install` of upstream deps | **OUT** until scope is locked | high disk + bandwidth + time cost |
| Modify upstream code to fit the user's environment | **OUT** until scope is locked | the rebrand/install phase is a separate slice |
| Touch any other repo on the user's GitHub | **OUT** | explicit user instruction: "אל תיגע בשום ריפו אחר" |

If the user says "all of the above", do it in slices, not as
one big approve. The first big-approve is the one that
explodes.

## Pitfall: Phase 3 (install) on a server with prior services — Linux adaptation, port conflicts, and the heavy-pip consent gate

Phase 3 is the part that touches the user's live server. Three
sub-pitfalls recur, all from the same failure mode: **the
upstream SETUP.md was written for the original author's
machine, not yours**.

### Sub-pitfall A: macOS-targeted SETUP.md ≠ your Linux VPS

Open-source voice/HUD projects almost always ship docs for
the author's platform (macOS Apple Silicon, in 80%+ of the
2025-2026 cases). Reading the SETUP.md verbatim and trying
to follow it on Ubuntu will hit:

- **`launchd` plists** that don't exist on Linux
  → write a systemd unit instead.
- **`lsof -ti tcp:$port`** in stop scripts
  → swap to `fuser -n tcp $port` or `ss -tlnp | awk`.
- **`ipconfig getifaddr en0`** for cert SAN
  → swap to `ip -4 addr show eth0 | awk '/inet /{print $2}' | cut -d/ -f1`.
- **Hard-coded `tls_ports: [443, 8766]`** when 443 is Caddy
  → re-plan the port map; do not silently move to a free port
    without telling the user, and do not try to kill the
    incumbent service.

**Rule:** before running *any* install command, do a
"platform diff" pass: `grep -rn "launchctl\|lsof\|ipconfig\|scutil\|brew\|defaults" server/scripts/ docs/`
and list every macOS-specific line. Each one is a question
that needs a Linux answer before install, not during.

**Worked example from a real session:** the [your-org]/[your-product]
SETUP.md assumed macOS throughout. On the user's Ubuntu VPS
the right substitution set was: launchd → systemd, lsof →
fuser/ss, ipconfig en0 → `ip addr show eth0`, port 443 → 8766
(Caddy already bound 443). Document the substitution table
in chat before install so the user can verify.

**Cross-platform install on a Linux VPS is a class of work**
that has its own reference: see
`references/cross-platform-voice-install-on-linux-vps.md`
for the full macOS→Linux substitution table, the 4-line
port/service-collision check, the systemd unit template, the
10-slice install order, and the failure modes that hit on
the first `apt install` / `uv pip install` / first Whisper
model warm (worked example: [your-org]/[your-product] on the user's
Ubuntu 24.04 VPS, June 2026). That reference also covers
**agent-side** install gotchas that aren't part of the
upstream project: bash history expansion eating secrets in
heredocs, Playwright refusing self-signed certs, and the
`--index-url` vs `--extra-index-url` pip resolver trap.

### Sub-pitfall B: Port and service collision check is mandatory

Before `pip install` or `apt install`, run this 4-line check
and put the output in the chat:

```bash
ss -tlnp 2>/dev/null | grep -vE "::1|127.0.0.53" | head -30
# Plus: which services own which ports
for port in 443 8642 8765 8766 9119 9443 18789; do
  pids=$(ss -tlnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+' | head -3)
  [ -n "$pids" ] && echo "port $port: PID $pids" || echo "port $port: free"
done
# Plus: Hermes-specific
curl -s -o /dev/null -w "Hermes :8642 → HTTP %{http_code}\n" \
  --max-time 3 http://127.0.0.1:8642/health
```

If a port the upstream assumes is **already in use by a
service the user wants to keep** (Caddy, Hermes gateway,
existing voice agent), do not kill that service. The right
move is either: (a) re-plan the new service to a free port
and document the change in `server.yaml`, or (b) add a
virtual host to the incumbent. The wrong move is "the docs
say 443, so I'll kill Caddy" — that's a destructive
side-effect the user did not approve.

**Caddyfile-as-source-of-truth pattern:** before adding any
new virtual host to Caddy, dump its current config from the
admin API (`curl -s http://127.0.0.1:2019/config/ | jq .`)
to see what routes are already claimed. Adding a host without
checking can shadow an existing route the user depends on.

**Symmetric pattern — check Caddy BEFORE installing a
port-conflicting service:** when the install plan needs
port 443 (or any other port a reverse proxy commonly holds),
introspect the proxy FIRST, not as a debugging step after the
new service fails to bind. Caddy exposes its full live config
on `http://127.0.0.1:2019/config/` (admin API) — one `curl
... | jq '.apps.http.servers'` shows every host, every
route, every upstream. This is the right way to answer
"is 443 really free or is Caddy squatting on it for 8
routes I forgot about" without reading the Caddyfile by
hand. Also reveals which services the proxy depends on
(e.g. the agent's own dashboard at `:9119`, [VaultRunner] at
`:18789`) so you can warn the user that touching Caddy
will affect those. Pitfall: the admin API returns
strips-sensitive-header info in plain text including
upstream auth tokens — do not paste the full dump into
chat or into a `/tmp/` file the user can see.

### Sub-pitfall C: Heavy `pip install` on a shared VPS needs explicit consent and background execution

`uv pip install faster-whisper silero-vad torch` is a 500MB+
download on a shared VPS. It **will** exceed the foreground
terminal timeout (default 180s) and Hermes will block with
"BLOCKED: Command timed out without user response." This is
a consent prompt, not an error — the right response is to
**stop, surface the install size and time, and ask**.

**The pattern that works:**

1. After scope is locked, before install, list the deps that
   will be pulled with their approximate size: "faster-whisper
   ~50MB, silero-vad ~30MB, torch CPU ~200MB, anthropic
   ~5MB, RealtimeSTT ~10MB. Total ~300MB download + 1-2 min
   install time. Run in background with notify_on_complete?"
2. Use `terminal(background=true, notify_on_complete=true, ...)`,
   not foreground with a high timeout. The user can keep
   working (or deciding other things) and gets notified once.
3. While the install runs, do *only* the read-only / non-conflict
   work in parallel: write the systemd unit, the server.yaml,
   the cert script, the Hermes plugin install — anything that
   doesn't need the Python deps to be present.
4. **Never** do `uv pip install` with a giant dep list in
   foreground. The terminal tool's consent gate will fire and
   the user will lose trust.

**Why this is a separate pitfall from the 3-phase approve:**
the 3-phase approve is about *what* to install. This is about
*how* to install a known-good step without making the user
wait or wonder if the agent is hung. Same risk class (long
mutating ops on a shared server), different layer.

**Worked example from a real session:** the [your-org]/[your-product]
install on the user's VPS hit this pitfall on the first
`uv pip install` attempt. The agent did not pre-flight the
install size, used a 300s foreground timeout, and the
terminal tool blocked with "user has NOT consented to this
action." The fix was to surface the install size first, ask
for `background=true, notify_on_complete=true` approval via
`clarify`, and only then run the install.

### Cross-platform install checklist (use this for any phase-3 install)

Before the first mutating command, every item must be true
and reported in chat:

- [ ] Read SETUP.md + TROUBLESHOOTING.md + ARCHITECTURE.md
      from the source repo in full
- [ ] Ran the platform-diff `grep` above; documented every
      macOS-specific line and the Linux substitute
- [ ] Ran the port/service-collision check; documented
      which ports are free, which are taken, and by what
- [ ] Listed the dep list with approximate download size and
      got explicit consent for `background + notify_on_complete`
- [ ] Hermes (or whatever agent backend) health-check
      confirmed reachable and the API key is in `~/.hermes/.env`
- [ ] Confirmed the install path: `/opt/<name>` vs `/root/<name>`
      vs `/srv/<name>` (the user's preference matters)
- [ ] Confirmed the service supervisor: systemd (Linux),
      launchd (macOS), docker, or hand-run
- [ ] A clear plan for what to do if the install fails at
      step N (rollback path, where logs go, how to kill)

**Reference:** see
`references/cross-platform-voice-install-on-linux-vps.md`
for the full macOS→Linux substitution table, the 4-line
port/service-collision check, the systemd unit template, the
8-slice install order, and the failure modes that hit on
the first `apt install` / `uv pip install` / first Whisper
model warm (worked example: [your-org]/[your-product] on the user's
Ubuntu 24.04 VPS, June 2026).
