---
name: subagent-driven-development
description: "Execute plans via delegate_task subagents (2-stage review)."
version: 1.1.0
author: Hermes Agent (adapted from obra/superpowers)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [delegation, subagent, implementation, workflow, parallel]
    related_skills: [writing-plans, requesting-code-review, test-driven-development]
---

# Subagent-Driven Development

## Overview

Execute implementation plans by dispatching fresh subagents per task with systematic two-stage review.

**Core principle:** Fresh subagent per task + two-stage review (spec then quality) = high quality, fast iteration.

## When to Use

Use this skill when:
- You have an implementation plan (from writing-plans skill or user requirements)
- Tasks are mostly independent
- Quality and spec compliance are important
- You want automated review between tasks

**vs. manual execution:**
- Fresh context per task (no confusion from accumulated state)
- Automated review process catches issues early
- Consistent quality checks across all tasks
- Subagents can ask questions before starting work

## The Process

### 0. Resume safely from handoff/context compaction

When continuing an existing task from a compacted context or previous session:
- read the handoff/context and verify the live repo state before delegating or editing
- summarize what you understand in the controller session
- propose a short next-slice plan before the first code change
- if the next operation is risky (auth, schema, secrets, destructive git/db operations), get explicit approval before executing that risky step
- only then dispatch subagents or implement; this prevents subagents from amplifying stale assumptions from a summary

### 1. Read and Parse Plan

Read the plan file. Extract ALL tasks with their full text and context upfront. Create a todo list:

```python
# Read the plan
read_file("docs/plans/feature-plan.md")

# Create todo list with all tasks
todo([
    {"id": "task-1", "content": "Create User model with email field", "status": "pending"},
    {"id": "task-2", "content": "Add password hashing utility", "status": "pending"},
    {"id": "task-3", "content": "Create login endpoint", "status": "pending"},
])
```

**Key:** Read the plan ONCE. Extract everything. Don't make subagents read the plan file — provide the full task text directly in context.

### 2. Per-Task Workflow

For EACH task in the plan:

#### Step 1: Dispatch Implementer Subagent

Use `delegate_task` with complete context:

```python
delegate_task(
    goal="Implement Task 1: Create User model with email and password_hash fields",
    context="""
    TASK FROM PLAN:
    - Create: src/models/user.py
    - Add User class with email (str) and password_hash (str) fields
    - Use bcrypt for password hashing
    - Include __repr__ for debugging

    FOLLOW TDD:
    1. Write failing test in tests/models/test_user.py
    2. Run: pytest tests/models/test_user.py -v (verify FAIL)
    3. Write minimal implementation
    4. Run: pytest tests/models/test_user.py -v (verify PASS)
    5. Run: pytest tests/ -q (verify no regressions)
    6. Commit: git add -A && git commit -m "feat: add User model with password hashing"

    PROJECT CONTEXT:
    - Python 3.11, Flask app in src/app.py
    - Existing models in src/models/
    - Tests use pytest, run from project root
    - bcrypt already in requirements.txt
    """,
    toolsets=['terminal', 'file']
)
```

#### Step 2: Dispatch Spec Compliance Reviewer

After the implementer completes, verify against the original spec:

```python
delegate_task(
    goal="Review if implementation matches the spec from the plan",
    context="""
    ORIGINAL TASK SPEC:
    - Create src/models/user.py with User class
    - Fields: email (str), password_hash (str)
    - Use bcrypt for password hashing
    - Include __repr__

    CHECK:
    - [ ] All requirements from spec implemented?
    - [ ] File paths match spec?
    - [ ] Function signatures match spec?
    - [ ] Behavior matches expected?
    - [ ] Nothing extra added (no scope creep)?

    OUTPUT: PASS or list of specific spec gaps to fix.
    """,
    toolsets=['file']
)
```

**If spec issues found:** Fix gaps, then re-run spec review. Continue only when spec-compliant.

#### Step 3: Dispatch Code Quality Reviewer

After spec compliance passes:

```python
delegate_task(
    goal="Review code quality for Task 1 implementation",
    context="""
    FILES TO REVIEW:
    - src/models/user.py
    - tests/models/test_user.py

    CHECK:
    - [ ] Follows project conventions and style?
    - [ ] Proper error handling?
    - [ ] Clear variable/function names?
    - [ ] Adequate test coverage?
    - [ ] No obvious bugs or missed edge cases?
    - [ ] No security issues?

    OUTPUT FORMAT:
    - Critical Issues: [must fix before proceeding]
    - Important Issues: [should fix]
    - Minor Issues: [optional]
    - Verdict: APPROVED or REQUEST_CHANGES
    """,
    toolsets=['file']
)
```

**If quality issues found:** Fix issues, re-review. Continue only when approved.

#### Step 4: Mark Complete

```python
todo([{"id": "task-1", "content": "Create User model with email field", "status": "completed"}], merge=True)
```

### 3. Final Review

After ALL tasks are complete, dispatch a final integration reviewer. For concurrency, lifecycle, abort/timeout, queueing, or security-sensitive changes, also dispatch a focused diff reviewer even if focused tests already pass. Ask them to look specifically for races and missing edge-case tests; in one Hermes voice-agent queue spike, this caught an abort-before-runner deadlock that all happy-path tests missed.

Standard final integration review:

```python
delegate_task(
    goal="Review the entire implementation for consistency and integration issues",
    context="""
    All tasks from the plan are complete. Review the full implementation:
    - Do all components work together?
    - Any inconsistencies between tasks?
    - All tests passing?
    - Ready for merge?
    """,
    toolsets=['terminal', 'file']
)
```

### 4. Verify and Commit

```bash
# Run full test suite
pytest tests/ -q

# Review all changes
git diff --stat

# Final commit if needed
git add -A && git commit -m "feat: complete [feature name] implementation"
```

## Task Granularity

**Each task = 2-5 minutes of focused work.**

**Too big:**
- "Implement user authentication system"

**Right size:**
- "Create User model with email and password fields"
- "Add password hashing function"
- "Create login endpoint"
- "Add JWT token generation"
- "Create registration endpoint"

## Red Flags — Never Do These

- Start implementation without a plan
- Skip reviews (spec compliance OR code quality)
- Proceed with unfixed critical/important issues
- Dispatch multiple implementation subagents for tasks that touch the same files
- Make subagent read the plan file (provide full text in context instead)
- Skip scene-setting context (subagent needs to understand where the task fits)
- Ignore subagent questions (answer before letting them proceed)
- Accept "close enough" on spec compliance
- Skip review loops (reviewer found issues → implementer fixes → review again)
- Let implementer self-review replace actual review (both are needed)
- **Start code quality review before spec compliance is PASS** (wrong order)
- Move to next task while either review has open issues

## Handling Issues

### If Subagent Asks Questions

- Answer clearly and completely
- Provide additional context if needed
- Don't rush them into implementation

### If Reviewer Finds Issues

- Implementer subagent (or a new one) fixes them
- Reviewer reviews again
- Repeat until approved
- Don't skip the re-review

### If Subagent Fails a Task

- Dispatch a new fix subagent with specific instructions about what went wrong
- Don't try to fix manually in the controller session (context pollution)

## Efficiency Notes

**Why fresh subagent per task:**
- Prevents context pollution from accumulated state
- Each subagent gets clean, focused context
- No confusion from prior tasks' code or reasoning

**Why two-stage review:**
- Spec review catches under/over-building early
- Quality review ensures the implementation is well-built
- Catches issues before they compound across tasks

**Cost trade-off:**
- More subagent invocations (implementer + 2 reviewers per task)
- But catches issues early (cheaper than debugging compounded problems later)

## Integration with Other Skills

### With writing-plans

This skill EXECUTES plans created by the writing-plans skill:
1. User requirements → writing-plans → implementation plan
2. Implementation plan → subagent-driven-development → working code

### With test-driven-development

Implementer subagents should follow TDD:
1. Write failing test first
2. Implement minimal code
3. Verify test passes
4. Commit

Include TDD instructions in every implementer context.

### With requesting-code-review

The two-stage review process IS the code review. For final integration review, use the requesting-code-review skill's review dimensions.

### With systematic-debugging

If a subagent encounters bugs during implementation:
1. Follow systematic-debugging process
2. Find root cause before fixing
3. Write regression test
4. Resume implementation

## Example Workflow

```
[Read plan: docs/plans/auth-feature.md]
[Create todo list with 5 tasks]

--- Task 1: Create User model ---
[Dispatch implementer subagent]
  Implementer: "Should email be unique?"
  You: "Yes, email must be unique"
  Implementer: Implemented, 3/3 tests passing, committed.

[Dispatch spec reviewer]
  Spec reviewer: ✅ PASS — all requirements met

[Dispatch quality reviewer]
  Quality reviewer: ✅ APPROVED — clean code, good tests

[Mark Task 1 complete]

--- Task 2: Password hashing ---
[Dispatch implementer subagent]
  Implementer: No questions, implemented, 5/5 tests passing.

[Dispatch spec reviewer]
  Spec reviewer: ❌ Missing: password strength validation (spec says "min 8 chars")

[Implementer fixes]
  Implementer: Added validation, 7/7 tests passing.

[Dispatch spec reviewer again]
  Spec reviewer: ✅ PASS

[Dispatch quality reviewer]
  Quality reviewer: Important: Magic number 8, extract to constant
  Implementer: Extracted MIN_PASSWORD_LENGTH constant
  Quality reviewer: ✅ APPROVED

[Mark Task 2 complete]

... (continue for all tasks)

[After all tasks: dispatch final integration reviewer]
[Run full test suite: all passing]
[Done!]
```

## Remember

```
Fresh subagent per task
Two-stage review every time
Spec compliance FIRST
Code quality SECOND
Never skip reviews
Catch issues early
```

**Quality is not an accident. It's the result of systematic process.**

## Pitfall: Scope lock + live re-verification before touching files

The plan in the dispatch context is **a hypothesis**, not a verified spec. A subagent that treats the plan as ground truth without re-checking the live system will faithfully implement a fabrication — overwriting working code, importing symbols that do not exist, or storing data in the wrong format.

**The rule, in order:**

1. **Read the plan as if it were a research proposal, not a spec.** The plan may be wrong. Assume it is wrong until verified.
2. **Before any `write_file`, `patch`, `npm install`, `mkdir`, or `git commit`:** run the **scope lock check**. The plan MUST contain an explicit "do not touch" list and a "verify before write" list. If it does not, surface this to the controller before touching anything.
3. **Run the same pre-verification the planner should have run.** For every file the plan proposes to create, confirm it does not exist. For every file it proposes to modify, read the current version. For every symbol it proposes to import, confirm it is exported. For every data format it proposes, open a real file and look. **Cite the evidence in the dispatch response** — `read_file output`, `grep output`, `ls output`.
4. **Refuse to execute a step that violates the scope lock.** If the plan says "do not touch `pipeline.ts`" and the natural fix requires touching it, the plan is wrong — return to the controller with the evidence, do not improvise the scope.
5. **Refuse to execute a step that contradicts live evidence.** If the plan says "import `fccAdminStatus`" and `grep "export" src/lib/fcc.ts` shows it is not exported, do not add a custom import shim or a `// @ts-ignore` to make the plan compile. Return to the controller.

**The four-question filter before writing the first line:**

- [ ] Does the file I am about to create already exist? *(read the parent dir or `git ls-files`)*
- [ ] Does the file I am about to modify actually exist? *(open it, read 1-50 lines)*
- [ ] Is the symbol I am about to import actually exported? *(`grep "^export" file.ts`)*
- [ ] Is the data format I am about to write actually what the live system reads? *(open a real instance of the data and compare)*

Any "I do not know" or "I assumed" answer to one of those questions is a **stop and surface** event, not a "I'll just check while writing" event.

**Worked example from a real session (June 2026, Agentic OS `/pipeline`):**

The plan claimed `shape/route.ts` and `build/route.ts` did not exist. The subagent that was about to create them should have run `git ls-files src/app/api/pipeline` first. The output would have shown both files. The subagent would then refuse to create them, return to the controller with: "the plan's premise is false, here is the live state, here is what the plan should have been." Instead, the subagent caught the issue only because the **user** had the discipline to make the implementer load a critical-review skill (`superpowers:executing-plans`) before any code change.

**Related rules (do not duplicate — already in `plan`):**

- `plan` skill, "Plan that modifies code MUST verify the current state of that code first" — the planner's side of the same rule.
- The whole pitfall chain exists to prevent the failure mode: confident plan → unverified implementation → overwrites working code.

**Discipline the controller must enforce:**

When dispatching an implementer, include this block in the context (do not assume the subagent will infer it):

```
SCOPE LOCK (you may not exceed this):
- Files you may create: <list>
- Files you may modify: <list>
- Files you MUST NOT touch: <list>
- Symbols you may import: <list>
- Dependencies you may add: <list>

LIVE RE-VERIFICATION (you must run before any write):
- <specific checks the implementer must run>

If the plan's structural claims contradict the live state, RETURN TO CONTROLLER
with the evidence. Do not improvise, do not add shims, do not proceed.
```

**Anti-patterns to refuse in the implementer's response:**

- "I added a small shim to make `fccAdminStatus` importable." — the symbol is not exported for a reason. Do not work around the plan's wrong import.
- "I went ahead and created the new module because the old one looked incomplete." — the old one is probably the working one. Read it.
- "I changed `pipeline.ts` to support the new flow." — the scope lock said no.
- "I stored `designSpec` as JSON because the plan said so." — the plan is wrong; the renderer expects markdown. Read the renderer.

## Pitfall: Verify the plan against the live system, not against the planner's intent

A subtler form of the same failure mode: the subagent reads the plan, understands what the planner **meant** to do, and implements that intent in a way that goes beyond the scope or contradicts a different part of the live system.

**The rule:** implement what the plan **says**, not what it **means**. If the plan says "import X" and X is not exported, do not substitute Y. Return to the controller.

This is a discipline rule, not a strict verification rule. The trap is: the plan is wrong in a way that the planner would have caught if they had been there. The subagent is there. The subagent must catch it.

## Pitfall: autonomous subagent timeouts on single large-file work (validated 2026-06-22)

**Trigger**: a task asks a subagent to make N specific edits to a single large file (≥1500 lines, especially ≥2000), or to read the whole file then edit it.

**Symptom**: the subagent starts, makes 1-2 of the requested edits, then hangs. The `delegate_task` call returns after 600s with `status: "timeout"` and `api_calls: 25-30 completed`. The user waited 10 minutes for nothing. The first edit may or may not have landed — you have to verify on disk before re-dispatching, otherwise you risk double-patching or a half-patched file.

**Verified 2026-06-22 on a multi-agent orchestration framework (`OpenClawStudio.tsx`, 2076 lines)**:

- Dispatch 1: "fix 4 memory leaks in OpenClawStudio.tsx, file attached in context". → Timeout. 25 API calls. Result: 1 of 4 fixes landed (the simplest one — a `keydown` listener cleanup).
- Dispatch 2: same context, retry. → Timeout. 25 API calls. Result: 0 of 3 remaining fixes landed. The 25 calls were all re-reading the file and reasoning, not editing.
- Dispatch 3: same context, retry. → Timeout. 25 API calls. Result: 0 of 3 remaining fixes landed.

**Three timeouts, 0 useful work** beyond the first edit. The subagent was clearly stuck in a loop of "read the file → realize it does not match my assumption → re-read the file" and never reached the edit step.

**The rule, validated empirically**:

1. **A subagent's effective work budget on a large file is roughly 1-2 patches.** Past that, the subagent burns the rest of the call window on context re-loading and re-verification, even when the patches themselves are trivial.
2. **Files >1500 lines need to be split, not delegated wholesale.** Either:
   - Dispatch N subagents, each with a 30-line offset/limit context window (`read_file(path, offset=X, limit=30)`) and a specific 1-patch scope.
   - Or: read the file in the main thread with `read_file` + `offset`/`limit`, identify the exact line ranges, dispatch one subagent per patch with the line range pinned.
3. **Never attach a 2000-line file as raw context to the subagent** and say "make these N edits". The subagent will read the file once, then spend the remaining 9 minutes re-reading segments trying to confirm the patches still apply after the first edit. The 25-call budget is real and not optional.
4. **If a subagent times out, the file is in an unknown state.** Always verify on disk before re-dispatching. Use `Select-String` or `read_file` to check which of the requested edits are already present. The "retry the same thing" instinct is wrong — the same subagent with the same context will fail the same way.
5. **The fallback when subagents time out is a one-shot PowerShell script** that the user runs on their own machine. The script takes the file path as a parameter, reads the file, applies the patches with idempotent replace operations, and reports which patches succeeded via `Test-Path` / `Select-String` checks after each one. This is a synchronous, deterministic operation that finishes in 1-2 seconds and never gets confused by context size.

**Worked example recipe (the pattern that finally worked, 2026-06-22)**:

```powershell
# 1. The user runs this on the laptop, one paste
$file = "C:\path\to\OpenClawStudio.tsx"
$content = Get-Content $file -Raw

# 2. Define each patch as a here-string of the OLD block and the NEW block
$old1 = @"
  useEffect(() => {
    if (!jobId) return;
    const tick = async () => { ...old... };
    tick();
  }, [jobId, apiBase, status]);
"@
$new1 = @"
  useEffect(() => {
    if (!jobId) return;
    let cancelled = false;
    const tick = async () => { ...new with cancelled flag... };
    tick();
    return () => { cancelled = true; clearTimeout(pollRef.current); };
  }, [jobId, apiBase, status]);
"@

# 3. Verify the OLD block exists before replacing (otherwise the script aborts)
if ($content -notmatch "pollRef.current = window.setTimeout\(tick, 1500\)") {
    Write-Host "ERROR: Patch 1 target not found. Aborting." -ForegroundColor Red
    exit 1
}

# 4. Apply, save, verify
$content = $content.Replace($old1, $new1)
$content | Set-Content $file -NoNewline
Write-Host "Patch 1 OK" -ForegroundColor Green

# 5. Repeat for patches 2, 3, ...
# 6. Run user-side validation: npx tsc --noEmit && npm run test:unit
```

**Why this works when subagents fail**: the script is synchronous, reads the file once, applies each patch with an explicit "abort if not found" guard, and writes once at the end. There is no opportunity for the agent to lose context between patches. Total time: 1-3 seconds for a 2000-line file with 3 patches.

**Anti-pattern**: writing the script with the Hebrew path embedded in the script body. The Hebrew path bytes get re-encoded over SSH, the script fails to parse. Pass the path as a `-Path` parameter, not as a string literal inside the script — see `incremental-hardening-refactor` "PowerShell + Hebrew paths over SSH" for the full recipe.

**Cost of getting this wrong**: 30 minutes of user time per large file, 0 patches landed. The user said "תעשה את זה אתה עבורי בבקשה אני לא רוצה לעשות כלום" — they want the agent to handle it, not ask them to do it. The PowerShell script is the right answer because (a) it runs on the user's machine where the file is, (b) it applies the patches in one shot, (c) it has built-in abort-on-failure, and (d) the user only copy-pastes, no decisions to make.

## Pitfall: research subagent with broad toolsets burns its budget on web calls (validated 2026-06-25, iPracticom engagement)

A different timeout pattern from the code-edit one above: the subagent isn't doing BUILDER work on a large file, it's doing **research synthesis** with the full `toolsets=['web', 'file', 'terminal']` triple.

**Symptom**: `delegate_task` returns `status: "timeout"` after 600s with `api_calls: 24` and the file was never written. The summary output is `null`. No useful work landed.

**Verified 2026-06-25**: dispatched a research task to write a 30-40 page Hebrew document comparing 4 SaaS voice-agent platforms (PolyAI / Vapi / Retell / Bland). Gave it `toolsets=['web', 'file', 'terminal']` and a "research then write to Vault" goal. The subagent made 24 calls, all of them web fetches to vendor pricing pages that needed JS rendering or login walls. It never reached the `write_file` step.

**The lesson, in three pieces**:

1. **`web` + `file` + `terminal` together is a research trap, not a research toolset.** The subagent has no idea what its budget is, so it tries to fetch every pricing page, read every docs page, verify every claim — exactly the depth-first behavior you want from a researcher, exactly the behavior that exhausts the 10-minute window before the deliverable is produced. The deliverable never lands.

2. **For research, give the subagent `file` + `terminal` only and an existing knowledge base, OR `web` + `file` only with a hard "no more than N fetches" budget.** The split depends on the goal:
   - **Synthesis from known data** (e.g., compare 4 vendors, write 30-page doc): give it `file` + `terminal` only. Tell it to write from existing knowledge and mark uncertain numbers with "דורש אימות" rather than fetch live data.
   - **Live-data research** (e.g., today's prices, breaking news): give it `web` + `file`, but cap the budget: "no more than 8 web fetches total, prioritize vendor pricing pages, skip login-walled docs."

3. **If the subagent times out on a research task, the deliverable is usually in its last response.** Read the parent-thread summary if any, and either dispatch a smaller follow-up ("write what you already know to file X, no more web fetches") or write the document yourself from the subagent's partially-returned reasoning. Don't re-dispatch the same broad scope — that's a guaranteed second timeout.

**Worked example from the iPracticom engagement (validated 2026-06-25)**:

Dispatch 1 (timeout):
```python
delegate_task(
    goal="Write a 30-40 page Hebrew research doc on 4 SaaS voice platforms",
    toolsets=['web', 'file', 'terminal'],  # ← trap: web dominates the budget
)
# Result: timeout, 24 calls, no file written
```

Dispatch 2 (success, ~3 minutes):
```python
delegate_task(
    goal="Write a 15-20 page Hebrew research doc from existing knowledge",
    context="Write from your existing knowledge of these companies, not live web fetches. Mark any uncertain pricing as 'דורש אימות' rather than fetching the live price.",
    toolsets=['file', 'terminal'],  # ← no web: subagent MUST synthesize from memory
)
# Result: completed, file written, 331 lines, ~15-18 pages
```

The second dispatch produced a real artifact in 200 seconds. The first burned 600 seconds on web fetches that were never converted to a deliverable. Same goal, same model, same Vault target — the only difference was the toolset scope and the explicit instruction to write from knowledge rather than fetch.

**Rule of thumb for research subagents**: if the deliverable can be produced from "what you already know + what's in the repo", give it `file` + `terminal` only. If the deliverable depends on live data the agent cannot know, give it `web` + `file` with an explicit fetch budget. Never all three.

## Pitfall: research subagent that "succeeds" but fabricates specifics (validated 2026-06-25, iPracticom engagement)

A third failure mode distinct from the previous two (timeout from web+file+terminal, timeout from large-file edits): the subagent returns `status: "completed"`, writes the file, the deliverable looks plausible — but on closer inspection the document contains **specific numbers, URLs, and feature claims that are not real**.

**Symptom** (what you see in the subagent summary):

- `status: "completed"`, file written, plausible length (e.g., 27KB / 331 lines / "15-18 pages")
- "All four vendors compared, pricing tables included, recommendations given"
- The deliverable reads like a polished research document

**What actually happened** (what's inside the file):

- Pricing tables contain numbers the subagent cannot know ("PolyAI: $3,000-10,000/mo")
- URLs and feature claims that read authoritatively but were never verified
- The "knowledge-based, no web fetches" instruction was followed, but the agent treated its general knowledge as ground truth instead of a hypothesis

**Why this is worse than a timeout** (validated reasoning):

- A timeout produces `status: "timeout"` and a null summary. You notice immediately and re-dispatch.
- A fabrication produces a deliverable that **looks done**. The user might forward it to a customer before the agent verifies it.
- The agent's own confidence is high because it followed the instructions ("no web fetches, mark unknowns") and yet the document still reads as definitive.

**Verified 2026-06-25**: dispatched a research task to write a 15-20 page Hebrew document comparing 4 SaaS voice-agent platforms. Gave it `toolsets=['file', 'terminal']` (intentionally excluded `web` after the prior timeout). The subagent returned `status: "completed"` with a 27KB document. The document looked complete and included pricing tables, feature comparisons, and a clear recommendation. **The user pushed back on the Pipecat claim earlier in the same session** — and the saved document still claimed "Pipecat supports SIP" based on general knowledge, with a fabricated justification.

**The rule, in three pieces**:

1. **"Completed" + "looks plausible" is NOT evidence the deliverable is correct.** Especially for research subagents writing from general knowledge, the deliverable's prose quality is uncorrelated with its factual accuracy. The subagent's job was to write a coherent document — and it did. Verifying that the claims are real is a separate step.

2. **The controller MUST verify every specific claim** before passing the deliverable to the user. Specifically:
   - **Numbers** (prices, latency, line counts, star counts) — must trace to a source the subagent actually consulted. If the subagent cannot cite the source, the number is unverified.
   - **URLs** — must `curl -I` to confirm 200 OK. Even a 404 is better than a plausible-looking-but-fake URL.
   - **Feature claims** ("supports SIP", "works with FreeSWITCH") — must `grep` the actual repo or docs. The Pipecat incident proved this twice in one session.
   - **Vendor names and product names** — if the subagent references a company you haven't heard of, the subagent may have hallucinated it. The iPracticom engagement had a subagent reference "PolyAI" as if it were Israeli when it is actually UK-based with an R&D office in Tel Aviv — a small but reputation-damaging error in front of the customer.

3. **Two layers of defense** (work in combination):

   **In the subagent dispatch context, add the verification hygiene:**

   ```
   RESEARCH SUBAGENT HYGIENE (you MUST follow):

   - For every specific number (price, latency, line count, star count) you write:
     state the source. If you did not fetch it in this session, write "הערכה — דורש אימות".
     DO NOT make up plausible-looking numbers even if they "feel right".

   - For every URL you cite: verify it. If you did not `curl -I` it in this
     session, do not cite it. Better to omit the URL than cite a fake one.

   - For every feature claim ("supports SIP", "integrates with X"):
     either grep the actual repo/docs, or qualify with "לפי התיעוד הרשמי"
     plus the date you last verified. Never write a feature claim as fact
     based on memory.

   - Mark ALL vendor-specific claims that did not come from a fetched source
     as "דורש אימות מול הספק".

   The controller will verify these claims before forwarding the document.
   Fabricated specifics destroy trust faster than honest gaps.
   ```

   **In the controller, before forwarding the deliverable to the user:**

   ```python
   # 1. Read the file
   # 2. Extract every number, URL, and feature claim
   # 3. For each one: cite the source, or delete/qualify
   # 4. NEVER forward a research document whose specifics you have not verified
   ```

   This is the same discipline as the "scope lock" pitfall earlier in this skill — the agent is responsible for verifying its own claims, and the controller is the second line of defense. The difference here is the failure mode is **silent** (no error, no timeout), so the verification has to be deliberate.

**Worked example from the iPracticom engagement (validated 2026-06-25)**:

The subagent returned a 331-line Hebrew document comparing 4 vendors. It looked complete. The pricing tables were "specific" with dollar amounts and ranges. The recommendation was clear.

The controller verified by:
- `git clone --depth 1 https://github.com/aicc2025/sip-to-ai` → repo exists, 63⭐, matches the subagent's description
- `curl -sS https://raw.githubusercontent.com/pipecat-ai/pipecat/main/README.md | head -80` → confirms Pipecat is not Israeli and not the "default recommendation"
- `ls src/pipecat/transports/` in the cloned Pipecat repo → only `daily`, `livekit`, `smallwebrtc`, `websocket`, `vonage`, `local` — NO `sip` directory. The subagent's "Pipecat supports SIP via twilio_daily_sip_dialin" claim needed qualification.

Three of the document's main claims needed correction or qualification before the user could forward it. The subagent's prose was polished; its specifics were not grounded.

**Rule of thumb for research subagents**: a polished-looking deliverable from a subagent is not a finished product — it is a first draft that needs the controller to verify each specific claim against a real source. Budget 15-30 minutes of controller time for verification on any research deliverable longer than ~10 pages.

**Complement to the previous pitfall** — same 1802-line `OpenClawStudio.tsx`, same BUILDER subagent, but a different outcome when the scope was tight enough.

**Trigger**: the user wants 1-3 truly small, surgical changes to a single large file. Examples that worked in a real session:

- Add 1 new `useRef` declaration
- Modify 1 useEffect body to use the new ref instead of an inline closure
- Add 1 new `useEffect` with cleanup for the new ref

Total: 3 hunks, each ≤ 8 lines, total diff ~12 lines. **The rest of the file is irrelevant.**

**Symptom of success** (vs the timeout pattern from the previous pitfall):

- `delegate_task` returns `status: "completed"` (not `timeout`)
- `exit_reason: "max_iterations"` not `timeout`
- 50 API calls, ~485 seconds — about the same wall-clock as a timeout, but the budget was actually used productively
- The subagent reads the file (not the whole file, but enough to find the three insertion points), makes the edits, saves, and reports a clean diff
- All 3 changes verified on disk

**Why the same file, same subagent, succeeded this time:**

1. **Tiny scope = tiny diff.** The subagent does not need to re-read the file 5 times to understand the change; it just lands each hunk in the right place.
2. **No internal cross-references.** The 3 changes are independent (add a ref, use it once, add a cleanup) — no risk that fixing one breaks another.
3. **Verification is cheap.** The subagent can read the surrounding 30 lines after each edit and visually confirm correctness. With 4-polling-leak scope, every patch invalidates the line numbers of the next patch, so it has to re-read.

**The rule, refined**:

| Scope (lines changed) | Pattern                                      | Expected outcome |
|-----------------------|----------------------------------------------|------------------|
| 1-2 hunks, ≤ 6 lines total, no cross-refs  | BUILDER in one shot          | Usually succeeds |
| 3-5 hunks, ≤ 25 lines, light cross-refs    | BUILDER with explicit anchors (line numbers or before/after quotes) | Sometimes succeeds, sometimes reads too much |
| 5+ hunks, OR > 30 lines, OR heavy cross-refs | PowerShell script via SSH OR per-hunk subagent dispatch | Don't try BUILDER — known timeout pattern |

**Critical detail for the "small enough" path**: in the dispatch context, give the subagent the EXACT before/after text for each hunk (not "find where to put it"), AND tell it explicitly "do NOT re-read the file between edits — apply all 3 hunks, then read the result once." The re-read-between-edits loop is what burns the API budget on the 5+ hunk case.

**Pitfall: explicit content anchors prevent subagent re-verification loops (validated 2026-06-23)**

When dispatching a small-scope BUILDER, the difference between "succeeds" and "times out" is often the granularity of the anchors you give it. Two patterns:

**Pattern A (fails)**: "Add a `voicesHandlerRef` near the other refs, modify the addEventListener call to use it, and add a useEffect with cleanup. The file is attached in context."

**Pattern B (works)**: Three numbered edits with exact before/after text. The subagent does not need to find the insertion points, does not need to re-read between edits, and does not need to verify context. Each edit is mechanical.

The subagent with Pattern A spends 15+ API calls re-reading the file to find the "right" insertion points, second-guessing the order of changes, and verifying that its own edits are consistent. The subagent with Pattern B spends those API calls on the actual edits. Same task, ~5x faster.

**Why the "small enough scope" path includes this rule**: when the file is 1500+ lines and the scope is 3+ hunks, the subagent is one bad read away from a 10-minute timeout. Explicit content anchors are the only way to keep the API budget on the edits and not on file navigation.

**Worked example dispatch context (validated 2026-06-23)**:

```

```
GOAL: Apply 3 surgical edits to OpenClawStudio.tsx, then verify with tsc + tests.
DO NOT read the whole file. DO NOT re-read between edits.

Edit 1 — add ref after line 945:
OLD: const silenceTimerRef = useRef<...>(null);
NEW: const silenceTimerRef = useRef<...>(null);
     const voicesHandlerRef = useRef<(() => void) | null>(null);

Edit 2 — replace the addEventListener call in the pre-warm useEffect:
OLD: window.speechSynthesis.addEventListener?.("voiceschanged", () => { ... });
NEW: voicesHandlerRef.current = () => { ... };
     window.speechSynthesis.addEventListener?.("voiceschanged", voicesHandlerRef.current);

Edit 3 — add a new useEffect right after useEffect(() => { loadHistory(); }, []):
NEW: useEffect(() => {
       return () => {
         if (voicesHandlerRef.current) {
           window.speechSynthesis.removeEventListener?.("voiceschanged", voicesHandlerRef.current);
           voicesHandlerRef.current = null;
         }
       };
     }, []);

After all 3 edits, run: npx tsc --noEmit && npm run test:unit
Report: which edits landed, tsc result, test result. If you cannot find an exact
match for an OLD block, STOP and report which block was missing — do not improvise.
```

**What "do it yourself" looks like when the user explicitly opts out (validated 2026-06-23)**: when BUILDER fails and the user says "תעשה את זה אתה" or "אני לא רוצה לעשות כלום", the right answer is NOT another BUILDER attempt, NOR a Ctrl+H patch the user has to apply, NOR a PowerShell script the user has to run. The right answer is the orchestrator (you) doing the cross-machine transfer yourself via:

1. `scp /tmp/edited_file.ext <windows-username>@laptop:C:/Users/<windows-username>/AppData/Local/Temp/edited_file.ext` — ASCII path on the laptop side, no Hebrew round-trip
2. SSH + `[Scripting.FileSystemObject].GetFile(hebrewPath).ShortPath` to get the 8.3 short path
3. SSH + `powershell -Command "[IO.File]::WriteAllBytes($shortPath, [Convert]::FromBase64String(...))"` to write the bytes
4. SSH + `npx tsc --noEmit && npm run test:unit` to verify

See `incremental-hardening-refactor` "PowerShell + Hebrew paths over SSH" + the ShortPath recipe for the full worked transcript. The user is the source of truth for "I want you to do it, not me" — the moment that signal fires, stop proposing user-side workarounds. See also `incremental-hardening-refactor/references/shortpath-hebrew-paths-over-ssh.md` for the end-to-end transcript (scp → Temp → ShortPath → WriteAllBytes → tsc + test:unit, all from the orchestrator).

---

## Pitfall: Parallel scrub + parent continues (validated 2026-06-25, build-product v1.4.0 publish)

When the user says "תזמן סאבאייגנט שיתקן ואתה תמשיך" — schedule a subagent to fix [X] while you continue [Y] — this is the parallel-scrub pattern. Common in any "publish to public" workflow where 30+ files need personal-info scrub and the parent still needs to handle the SKILL.md recursion table, the loops.md update, and the final audit.

**The pattern (validated 2026-06-25):**

- **Parent owns (do not delegate)**: SKILL.md, CHANGELOG.md, frameworks/loops.md, the 3 task files (deploy-to-cloudflare.md, ship.md, new-product.md), and the version bump in frontmatter. These are the orchestrator's structural files; a subagent that touches them risks breaking the parent flow mid-flight.
- **Subagent owns (delegate)**: all the OTHER files — references/, scripts/, tasks/* (non-build-product), and the README.md + every other skill that has personal/brand refs to scrub. The subagent does ~30 file edits in one shot.
- **Coordination via hard constraints in the subagent's `context`**: "DO NOT modify `skills/software-development/build-product/SKILL.md`. DO NOT touch `/root/.hermes/skills/`. DO NOT push to git. ONLY edit files in `/tmp/FullStack-Builder/`."

**The subagent prompt shape (template):**

```
Fix all personal/brand references in /tmp/FullStack-Builder/ public repo.

Hard constraints:
- ONLY edit /tmp/FullStack-Builder/ (public mirror)
- DO NOT touch /root/.hermes/skills/ (local source)
- DO NOT push to git (parent will do that)
- DO NOT modify skills/software-development/build-product/SKILL.md (parent owns it)
- Hebrew chars OK in source content but brand names NOT OK

Specific replacements needed:
- File A: line X "Old" → "New"
- File B: line Y "Old" → "New"
- File C: REMOVE entirely (replaced by another file or no longer needed)

After all fixes, print a summary. Parent will run final audit + commit + push.
```

**Why this works:**

- The subagent does **bulk mechanical edits** (sed/perl/patch across many files) — perfect for `delegate_task`'s 10-minute budget because the per-file work is small and the total work is large.
- The parent does **structural work** (SKILL.md recursion table, version bumps, final audit, commit, push) — needs full context and serial dependency, can't be parallelized.
- **No conflict** because the file ownership is partitioned explicitly. The subagent edits `references/` + `tasks/` of other skills; the parent edits `build-product/SKILL.md`, `build-product/CHANGELOG.md`, `build-product/frameworks/loops.md`, `build-product/tasks/{deploy-to-cloudflare,ship,new-product}.md`.

**The coordination risk — the recursion table pitfall (validated 2026-06-25)**:

The parent's SKILL.md includes a "scrub rename map" table that documents what to remove (Cloudflare Account ID, Tailscale IPs, voice IDs, etc.). If the parent and subagent both touch this file, two scenarios:

1. **Subagent edits SKILL.md despite the constraint** — uses `patch` with `old_string="Daniel → the user"` and lands a half-scrub. Parent then re-runs the rsync, OVERWRITING the subagent's scrub with the still-tainted source. The leak persists.
2. **Parent edits SKILL.md recursion table** — but the recursion table ITSELF contains real values (e.g., `<agent-vm-ip>` listed as an example to scrub). The parent's "fix" of the recursion table means the table now has `<agent-vm-ip>` placeholders. But the rsync from source already brought the real values to public — parent must `rsync` AGAIN after the source fix.

**The fix**: the recursion table MUST live ONLY in source, and be fully scrubbed (all values replaced with `<your-X>` placeholders) BEFORE the rsync. The parent does this in one shot:

1. Parent: rewrite SKILL.md recursion table with `<your-X>` placeholders (source).
2. Parent: rsync source → public (now public has scrubbed table).
3. Subagent: scrub all OTHER files in public (don't touch SKILL.md).
4. Parent: re-validate, commit, push.

**If the subagent reports it found a leak in SKILL.md anyway** — the parent's `git diff` after the subagent completes will show no change in SKILL.md (parent already scrubbed it before rsync). The subagent's leak report is then a hint that the parent's scrub missed something; re-read SKILL.md top to bottom.

**Anti-patterns:**

- ❌ Both parent and subagent edit SKILL.md → conflict, lost work, double-scrub
- ❌ Subagent edits source `/root/.hermes/skills/` → parent can't re-sync cleanly
- ❌ Subagent pushes to git → parent's later commit/push conflicts with the subagent's push
- ❌ Subagent edits build-product/SKILL.md recursion table → parent's rsync clobbers it
- ✅ Partition file ownership explicitly in the subagent's `context`
- ✅ Parent scrubs SKILL.md BEFORE rsync, so the public has the cleaned table
- ✅ Subagent reports findings at the end, parent re-validates, parent commits

**Symptom you're violating the rule:**

- `git status` after both parent and subagent finish shows conflicting edits in SKILL.md
- The subagent's "fixed X files" report includes a line about SKILL.md — the constraint wasn't strong enough
- The public has both the subagent's scrub AND the parent's recursion-table update on the same lines → conflict markers in `git diff`
- The final audit finds the same leak that the subagent claimed to fix → the rsync clobbered it

**Worked example recipe (the pattern that finally worked, 2026-06-25)**:

```python
# Parent does first
edit_file('SKILL.md', 'recursion table with real values', 'recursion table with <your-X> placeholders')
rsync -av --delete /root/.hermes/skills/software-development/build-product/ /tmp/FullStack-Builder/skills/software-development/build-product/

# Then dispatch subagent
delegate_task(
    goal="Fix personal/brand references in /tmp/FullStack-Builder/ public repo (35 files)",
    context="""
Hard constraints:
- ONLY edit /tmp/FullStack-Builder/ (public mirror)
- DO NOT touch /root/.hermes/skills/ (local source)
- DO NOT push to git
- DO NOT modify skills/software-development/build-product/SKILL.md

Parent has already scrubbed SKILL.md. Your job: scrub everything else.
""",
    toolsets=["file", "terminal"],
)

# Parent continues with: re-validate, commit, push (NO parallel work on public)
```

## Further reading (load when relevant)

When the orchestration involves significant context usage, long review loops, or complex validation checkpoints, load these references for the specific discipline:

- **`references/context-budget-discipline.md`** — Four-tier context degradation model (PEAK / GOOD / DEGRADING / POOR), read-depth rules that scale with context window size, and early warning signs of silent degradation. Load when a run will clearly consume significant context (multi-phase plans, many subagents, large artifacts).
- **`references/gates-taxonomy.md`** — The four canonical gate types (Pre-flight, Revision, Escalation, Abort) with behavior, recovery, and examples. Load when designing or reviewing any workflow that has validation checkpoints — use the vocabulary explicitly so each gate has defined entry, failure behavior, and resumption rules.

Both references adapted from gsd-build/get-shit-done (MIT © 2025 Lex Christopherson).
