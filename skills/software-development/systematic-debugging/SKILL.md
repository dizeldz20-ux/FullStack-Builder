---
name: systematic-debugging
description: "4-phase root cause debugging: understand bugs before fixing."
version: 1.2.0
author: Hermes Agent (adapted from obra/superpowers)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [debugging, troubleshooting, problem-solving, root-cause, investigation]
    related_skills: [test-driven-development, writing-plans, subagent-driven-development]
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to Use

Use for ANY technical issue:
- Test failures
- Bugs in production
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**
- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- Someone wants it fixed NOW (systematic is faster than thrashing)

## The Four Phases

You MUST complete each phase before proceeding to the next.

---

## Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

### 1. Read Error Messages Carefully

- Don't skip past errors or warnings
- They often contain the exact solution
- Read stack traces completely
- Note line numbers, file paths, error codes

**Action:** Use `read_file` on the relevant source files. Use `search_files` to find the error string in the codebase.

### 2. Reproduce Consistently

- Can you trigger it reliably?
- What are the exact steps?
- Does it happen every time?
- If not reproducible → gather more data, don't guess

**Action:** Use the `terminal` tool to run the failing test or trigger the bug:

```bash
# Run specific failing test
pytest tests/test_module.py::test_name -v

# Run with verbose output
pytest tests/test_module.py -v --tb=long
```

### 3. Check Recent Changes

- What changed that could cause this?
- Git diff, recent commits
- New dependencies, config changes

**Action:**

```bash
# Recent commits
git log --oneline -10

# Uncommitted changes
git diff

# Changes in specific file
git log -p --follow src/problematic_file.py | head -100
```

### 4. Gather Evidence in Multi-Component Systems

**WHEN system has multiple components (API → service → database, CI → build → deploy):**

**BEFORE proposing fixes, add diagnostic instrumentation:**

For EACH component boundary:
- Log what data enters the component
- Log what data exits the component
- Verify environment/config propagation
- Check state at each layer

Run once to gather evidence showing WHERE it breaks.
THEN analyze evidence to identify the failing component.
THEN investigate that specific component.

### 5. Trace Data Flow

**WHEN error is deep in the call stack:**

- Where does the bad value originate?
- What called this function with the bad value?
- Keep tracing upstream until you find the source
- Fix at the source, not at the symptom

**Action:** Use `search_files` to trace references:

```python
# Find where the function is called
search_files("function_name(", path="src/", file_glob="*.py")

# Find where the variable is set
search_files("variable_name\\s*=", path="src/", file_glob="*.py")
```

### Phase 1 Completion Checklist

- [ ] Error messages fully read and understood
- [ ] Issue reproduced consistently
- [ ] Recent changes identified and reviewed
- [ ] Evidence gathered (logs, state, data flow)
- [ ] Problem isolated to specific component/code
- [ ] Root cause hypothesis formed

**STOP:** Do not proceed to Phase 2 until you understand WHY it's happening.

## Phase 2: Pattern Analysis

**Find the pattern before fixing:**

### 1. Find Working Examples

- Locate similar working code in the same codebase
- What works that's similar to what's broken?

**Action:** Use `search_files` to find comparable patterns:

```python
search_files("similar_pattern", path="src/", file_glob="*.py")
```

### 2. Compare Against References

- If implementing a pattern, read the reference implementation COMPLETELY
- Don't skim — read every line
- Understand the pattern fully before applying

### 3. Identify Differences

- What's different between working and broken?
- List every difference, however small
- Don't assume "that can't matter"

### 4. Understand Dependencies

- What other components does this need?
- What settings, config, environment?
- What assumptions does it make?

## Phase 3: Hypothesis and Testing

**Scientific method:**

### 1. Form a Single Hypothesis

- State clearly: "I think X is the root cause because Y"
- Write it down
- Be specific, not vague

### 2. Test Minimally

- Make the SMALLEST possible change to test the hypothesis
- One variable at a time
- Don't fix multiple things at once

### 3. Verify Before Continuing

- Did it work? → Phase 4
- Didn't work? → Form NEW hypothesis
- DON'T add more fixes on top

### 4. When You Don't Know

- Say "I don't understand X"
- Don't pretend to know
- Ask the user for help
- Research more

## Phase 4: Implementation

**Fix the root cause, not the symptom:**

### 1. Create Failing Test Case

- Simplest possible reproduction
- Automated test if possible
- MUST have before fixing
- Use the `test-driven-development` skill

### 2. Implement Single Fix

- Address the root cause identified
- ONE change at a time
- No "while I'm here" improvements
- No bundled refactoring

### 3. Verify Fix

```bash
# Run the specific regression test
pytest tests/test_module.py::test_regression -v

# Run full suite — no regressions
pytest tests/ -q
```

### 4. If Fix Doesn't Work — The Rule of Three

- **STOP.**
- Count: How many fixes have you tried?
- If < 3: Return to Phase 1, re-analyze with new information
- **If ≥ 3: STOP and question the architecture (step 5 below)**
- DON'T attempt Fix #4 without architectural discussion

### 5. If 3+ Fixes Failed: Question Architecture

**Pattern indicating an architectural problem:**
- Each fix reveals new shared state/coupling in a different place
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms elsewhere

**STOP and question fundamentals:**
- Is this pattern fundamentally sound?
- Are we "sticking with it through sheer inertia"?
- Should we refactor the architecture vs. continue fixing symptoms?

**Discuss with the user before attempting more fixes.**

This IS NOT a failed hypothesis — this is a wrong architecture.

## Async Test Flake Pattern: Fixed Sleeps vs Background Side Effects

When a flaky test waits for background work with a fixed sleep (`setTimeout(40/80/120ms)`, `sleep(0.1)`) and then asserts that a side effect occurred, treat the sleep as a prime suspect before changing production code.

Investigation steps:
- Trace the async boundary: timer, promise continuation, queue worker, HTTP callback, notification enqueue, or drain endpoint.
- Compare the nominal timing margin with real overhead. A "should finish in 70ms" assumption is not evidence under CI/load.
- Check whether the read operation is destructive (for example, drain-once notification endpoints). Polling such endpoints can consume state, so keep and assert on the first successful body rather than polling then fetching again.
- Prefer bounded condition-based polling in tests (`waitFor` with timeout/interval) over longer fixed sleeps.
- Keep the fix test-only unless evidence shows production behavior is wrong.

See `references/async-test-flakes.md` for a compact recipe and examples.

## Pitfall: Fabricated outputs — when the agent reports success it never verified (validated 2026-06-14)

A recurring failure mode in long sessions, especially when SSH or tunnel access drops mid-task: the agent confidently reports commit SHAs, file sizes, validation results, or "I fixed it" conclusions without re-running the tool calls in the current turn. The user trusts the report, the next session's verification (or the user's re-check) finds nothing changed.

**Telltale signature in the agent's own output**: a celebratory "🎉 / ✅ / shipped / verified / validated" paragraph that is NOT directly preceded by the corresponding tool output in the same turn. Specific numeric values (byte counts, SHAs, line numbers) that don't have a fresh `wc` / `git log` / `cat` to back them up.

**Mandatory 5-check recipe before any "I fixed it" claim**:
1. Re-verify access is alive (one trivial `whoami` if SSH was used earlier).
2. Re-grep the file that allegedly changed.
3. Re-show the commit / artifact identity (`git log --oneline | grep <sha>`, `ls -la`, `head -c 200`).
4. Run the validation you claimed ran (the actual `grep` for the `✓` items).
5. Show the tool call that produced the artifact, not the reasoning.

If any check cannot be shown, say so explicitly. "I lost access, here's what I last saw, please confirm" is the right user-facing message — not a confident "yes I shipped it" that turns out to be a fabrication.

**Recovery pattern**: state the fabrication, show what you *can* verify, ask the user to confirm, do not back-fill.

See `references/fabricated-output-pattern.md` for the full worked example (2026-06-14 multi-agent orchestration framework session: claimed commits `6f6e32a` / `b95513a` / `a7dec6f` that did not exist), the 5-check recipe, the telltale signatures, and the recovery pattern.

## Red Flags — STOP and Follow Process

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **"One more fix attempt" (when already tried 2+)**
- **Each fix reveals a new problem in a different place**

**ALL of these mean: STOP. Return to Phase 1.**

**If 3+ fixes failed:** Question the architecture (Phase 4 step 5).

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question the pattern, don't fix again. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence, trace data flow | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare, identify differences | Know what's different |
| **3. Hypothesis** | Form theory, test minimally, one variable at a time | Confirmed or new hypothesis |
| **4. Implementation** | Create regression test, fix root cause, verify | Bug resolved, all tests pass |

## Hermes Agent Integration

### Investigation Tools

Use these Hermes tools during Phase 1:

- **`search_files`** — Find error strings, trace function calls, locate patterns
- **`read_file`** — Read source code with line numbers for precise analysis
- **`terminal`** — Run tests, check git history, reproduce bugs
- **`web_search`/`web_extract`** — Research error messages, library docs

### With delegate_task

For complex multi-component debugging, dispatch investigation subagents:

```python
delegate_task(
    goal="Investigate why [specific test/behavior] fails",
    context="""
    Follow systematic-debugging skill:
    1. Read the error message carefully
    2. Reproduce the issue
    3. Trace the data flow to find root cause
    4. Report findings — do NOT fix yet

    Error: [paste full error]
    File: [path to failing code]
    Test command: [exact command]
    """,
    toolsets=['terminal', 'file']
)
```

### With test-driven-development

When fixing bugs:
1. Write a test that reproduces the bug (RED)
2. Debug systematically to find root cause
3. Fix the root cause (GREEN)
4. The test proves the fix and prevents regression

## Real-World Impact

From debugging sessions:
- Systematic approach: 15-30 minutes to fix
- Random fixes approach: 2-3 hours of thrashing
- First-time fix rate: 95% vs 40%
- New bugs introduced: Near zero vs common

**No shortcuts. No guessing. Systematic always wins.**

## Phase 1 Pitfall: HTTP 200 from curl is not "it works"

A failure mode that recurs in voice/tunnel/proxy work:

- `curl https://<route>` returns `200`
- The agent reports "fixed"
- The user retries and still sees the same error

The hidden trap is that the curl probe exercises a *different code path* than the user's real flow.

Common real-world mismatches that look like 200 in curl but fail for the user:

1. **Vite proxy with dead upstream** — Vite returns the upstream's HTTP status only if it can connect. If the upstream process is *not running at all*, Vite returns `500` (not `502`/`504`). So a 200 from `curl http://localhost:8787/api/health` does not mean the Vite proxy path `https://<tunnel>/api/health` will work — the proxy may be hitting nothing.
2. **Mock/fake response shape** — A route that returns a synthesized `200 { ok: true }` looks healthy, but the consuming code expects a real `conversationToken`, `signedUrl`, or signed envelope and breaks on the next step. The 200 hides the missing field.
3. **Localhost vs tunnel origin** — `curl localhost` skips the proxy, skips CORS, and skips Cloudflare's header transforms. Behavior diverges.
4. **No-mic browser sandbox** — Playwright/headless browser returns 200 for the API and then errors on `getUserMedia` because no microphone exists. The user has a microphone; their flow does not stop at the API.

**Verification standard for the kind of bug that "was fixed three times"** (e.g. voice start, 500 on a proxy route, OAuth callback loop):

Before claiming fixed, run **all** of:

1. `curl` against the same origin the user is hitting (the tunnel, not localhost).
2. `curl` with the same auth/headers the user's browser sends (cookie, Basic Auth, Bearer).
3. A real browser session (Playwright or similar) that *exercises the full flow* — not just the first API call. For voice, that means clicking Start, waiting through the connection window, and inspecting the conversation record / WebRTC state.
4. `lsof -iTCP:<port> -sTCP:LISTEN` (or `ss -tlnp`) to confirm the *expected* upstream is actually listening. The wrong process can be squatting on the port (e.g. an unrelated daemon on a nearby port).
5. Process identity check: `ps -p <pid> -o pid,ppid,cmd` and `readlink /proc/<pid>/cwd` to confirm the listening process is the one you think it is.

If any of these cannot be confirmed, say so explicitly. Do not write "fixed" based on the green check alone.

### Telltale signature: "fix N" keeps needing more fixes

If the same symptom recurs after a verified-looking fix, suspect a verification gap from the list above before changing production code again. The most common culprit is item 1 (proxy/port mismatch) followed by item 2 (mock response shape).

### Mock tokens are toxic in voice/WebRTC paths

A specific instance of item 2 worth calling out: in any ElevenLabs/voice flow that eventually opens a WebRTC connection, a `mock_token_*` or `mock_signed_url_*` returned by the backend will pass the API smoke and fail at the next step with `invalid authorization token` or a quick room disconnect. The browser only fails the connection *after* the API call already returned 200, so the failure is far from the cause.

Rule of thumb for voice routes:

- If a real provider key is available, call the real provider. Do not silently add a "mock" branch.
- If you do add a temporary mock for a smoke, do not ship it. A mock that works for one curl is a footgun for the next user.
- If the user reports a token/invalid-authorization error after a fix, the most likely cause is a mock branch left in production code, not a transport problem.

## Long-lived backend process pitfall

When a `tsx watch` / `nodemon` / `ts-node-dev` process is supposed to keep the backend alive in the background but is not actively reloading:

- The process can exit silently on the first unhandled error, on a watcher crash, or when the parent terminal detaches.
- `lsof -iTCP:<port>` then shows nothing and a new `tsx` start works, but the next dev cycle hits the same dead-port symptom.

Mitigations that worked in practice:

- Prefer plain `npx tsx src/server.ts` (no `watch`) for long-lived backend dev servers behind a tunnel, and re-run it explicitly when code changes.
- If a watcher is needed, run it under a supervisor (e.g. `process` action with `notify_on_complete=true`) so a silent exit is at least visible.
- After *any* backend restart, immediately re-run `curl http://localhost:<port>/api/health` to confirm it is still up before handing the user a tunnel URL.
