# Post-Implementation Code Quality Audit

Use when a user asks to "scan the new code", "rate the code quality",
"is it clean enough", "find bugs", "review what we built", or similar.
The pattern: after building N new feature modules, run a structured
multi-category audit, fix the real bugs, and add regression tests so
the bugs cannot silently come back.

Validated on the Ruby voice agent case in 2026-06 where five
infrastructure features (Worker Mode Auto, Audit Log, TTS Cache, VAD,
Multi-language) were scanned together and 15 real issues were found
across 6 categories in a single audit pass. 11 of them were genuine
bugs that would have shipped to production; the rest were performance
and hardening concerns. 11 regression tests were added; 235/235 tests
pass.

## When this pattern fits

- The user has just built (or just had you build) a batch of new
  feature modules.
- They want a second-pass review, not "is it done" check.
- The codebase already has a test gate and a typecheck gate
  (`tsc --noEmit`).
- Public API of existing modules must not change.
- You need a structured way to find bugs without re-reading every
  file linearly.

## Before the six categories: the "is it wired in?" pre-check

Run this **before** the per-category scan. It is the single
highest-value check, and the existing 6 categories do not catch it.

A new feature module can pass every test, type-check cleanly, and
still be **dead code** — never called by the live pipeline. The
audit on the Ruby voice 5-feature build in 2026-06 found 15
in-module bugs and fixed them; a follow-up pass that the user
explicitly requested ("עדיין מה נכשל ותתקן") then discovered
that **4 of the 5 features were not actually called from the
live handlers**:

- `hermesBridge.ts:453` had `workerMode === 'queue'` but no
  `'auto'` branch — `resolveAutoWorkerMode` was exported and
  tested but never consulted. The `'auto'` value silently fell
  through to the direct-run path.
- `elevenlabsTts.ts` had a hard-coded voice lookup; the
  `pickTtsProfile` and `readTtsCacheEntry` helpers existed but
  were never invoked. Every TTS call burned credits and routed
  Hebrew to Adam instead of Liam.
- `gmailActions.sendGmailMessage` had no call to
  `recordAuditEntry`; the audit log module sat on disk and never
  received a single row.

### The pre-check recipe

For every new public function exported by the new modules:

1. `grep -rn "newFunctionName" src/routes src/app.ts
   src/handlers` (or whatever the live entry-point directory is
   called in the repo).
2. If the function name is only found in `src/services/` and in
   its own `.test.ts`, it is **not wired in**. Stop the audit and
   wire it in first.
3. If the function is called but only inside a feature-flag /
   env-var branch, verify the env var is set in production.
4. If the function is called via a dynamic `import()` / lazy
   load, trace the call site manually — grep does not find lazy
   loads.

The grep is intentionally aggressive: it should match import
statements, function calls, and type usages. False positives
(matching a same-named helper in another module) are cheap;
false negatives (the live code never calls the new function) are
the bug class this check exists for.

### What the wiring commit looks like

Once a dead-code gap is found, the wiring commit is its own
deliverable, not a footnote of the audit. It usually touches:

- The route handler / middleware that should call the new
  function (often `src/routes/<feature>.ts` or a central
  `app.ts`)
- A new optional dep injection seam on the function being wired
  (so legacy callers and tests stay unaffected)
- An `integration.test.ts` block that exercises the live path
  with mocked upstreams and asserts the new function's side
  effects (cache file exists, audit log line was written,
  timings reflect the resolved mode)

In the Ruby voice case, the wiring commit added 10 integration
tests and brought the total from 235 → 245 passing.

### Why this is not part of any of the 6 categories

The 6 categories are about *correctness within the new module*.
A new module that is never called has no runtime bugs to find —
its bugs are a missing import in someone else's file. Categories
1–6 are the wrong shape for that, so the pre-check is a separate
gate, run first, and its output (list of unwired functions)
becomes a sub-task list that blocks the rest of the audit.

## The six audit categories (in priority order)

1. **CRITICAL — data correctness under load**
   Pure bugs that produce wrong output, throw, or corrupt state.
   Look for: off-by-one in frame/byte math, sentinel-value mishandling,
   unhandled zero/empty inputs, missing `existsSync` guards before
   `statSync` / `renameSync`, JSON.parse without try/catch,
   math that can go negative and is then clamped to zero,
   **scope-mismatched resource declarations in `try` blocks** (see
   pitfall 0f below — `const` declared inside `try` is invisible to
   `finally` and `catch` in the same `try`).

2. **PERFORMANCE — sustained-load bottlenecks**
   Look for: O(N) readdir/statSync inside hot read paths,
   `for (const ch of str)` on long strings (use charCodeAt),
   repeated work in per-request code that should be hoisted,
   `JSON.stringify` of the entire request body in logs.

3. **ROBUSTNESS — clock skew, partial input, race conditions**
   Look for: timestamp comparisons that assume monotonic now,
   concurrent-write safety on the same file path,
   partial trailing frames / partial trailing bytes,
   corrupt meta or header files failing the entire read,
   non-deterministic sort orders on ties.

4. **SECURITY / SAFETY — even when the user did not ask for security**
   Look for: env values that are eval'd, secrets in audit logs,
   file paths that accept `..`, regex DoS, unbounded file size.

5. **API STABILITY — public surface, no silent drift**
   Look for: enum values that callers may not handle,
   default-value drift, function signatures that became wider
   in a way that breaks inference at call sites.

6. **DOCUMENTATION — why, not just what**
   Look for: hard-coded magic numbers without comments,
   env var ranges that look arbitrary, non-obvious invariants
   that are not stated.

## How to run the audit efficiently

1. **Read all the new files end-to-end once** before you start
   looking for bugs. Mental model first; bug hunting second.
2. **Look for sentinel-value patterns.** A variable that
   initializes to `0` or `totalFrames` and is later compared to
   a target is a classic bug. Trace every such variable.
3. **Trace all error-handling paths.** `try { } catch { /* ignore */ }`
   is a smell unless the failure is genuinely safe to ignore.
4. **Walk through the high-RPS code path mentally.** A TTS cache
   read, a route handler, an audit log write — anything that fires
   per-request. What runs every time that should run once?
5. **Check the import line of every file.** `O_APPEND` from
   `node:fs` does not exist in TypeScript types. The test-runner
   uses tsx/esbuild and silently strips type-only errors.
6. **Compile the bug list before fixing anything.** Categorize
   by severity; this lets you decide what to fix in this pass
   vs. defer.

## The "fix and add regression test" loop

For every CRITICAL or ROBUSTNESS bug:

1. Write the **regression test FIRST** as if the bug were
   already fixed. This proves the test catches the bug.
2. Run the test alone; it should fail with the same error the
   bug would produce.
3. Now apply the minimum fix.
4. Re-run the targeted test, then the full suite, then `tsc --noEmit`.
5. Commit one fix + one regression test as a single commit
   (or as part of the same hardening commit).

This loop produces a commit history that reads like a
bug-fix changelog instead of a vague "refactor + harden" blob.

## The 9-category secret/PII audit (added 2026-06-25)

The 6-category audit above is for code quality after building a
feature. A **separate** audit pattern exists for public-repo
scrubbing (cleaning a repo before publishing it). The two are
similar in shape (multi-category checklist, manual verification,
regression test) but the categories are completely different.

**The trap**: a 4-category grep on a public repo returns "0
findings" and gives the user false confidence. The deeper
9-category scan finds 60+ issues the first pass missed.

| Category | What it catches |
|---|---|
| 1. Standard secrets/PII | `@gmail.com`, `sbp_*`, `sk-*`, `ghp_*` |
| 2. Network/internal IPs | `100.x.x.x`, `vmi[0-9]+`, `contaboserver`, `.ts.net` |
| 3. Personal paths | `/root/.[vault-runner]`, `C:\Users\`, OneDrive |
| 4. Brand names | `[your-voice-product]`, `[your-other-product]`, `[your-product]`, `[your-ai-product]` |
| 5. Backup/timestamp patterns | `[0-9]{8}-[0-9]{6}` in paths |
| 6. Cross-reference validation | `@\.\.` paths that don't resolve |
| 7. Attribution leaks | `Built with`, `skillsmith_source`, `provenance:` |
| 8. Session-narrative leakage | Hebrew quotes, "user pushed back", "session [" |
| 9. Repo-meta consistency | version drift, placeholder strings (`YOUR-USERNAME`) |

**Why categories 4-9 are missed**: the first pass focuses on
secrets/PII and stops at category 3. Categories 4-9 are the ones
the user means when they say "תחפור במקומות שלא חשבת לחפור בהן."

See `references/9-category-public-repo-audit.md` for the full
worked example (FullStack-Builder, 60+ findings across 3 commits).

**Time cost**: the 9-category pass takes ~15 minutes vs. the
2-minute shallow pass. The shallow pass is worse than no audit
because it returns false confidence.

## Pitfalls specific to this audit pattern

### 0. "Tests pass + new module exists" does NOT mean the feature ships

This is the dead-code bug class. A new `src/services/<feature>.ts` can
have 100% test coverage and still not be called by the live pipeline.
The single most reliable check: `grep -rn "<newFunctionName>" src/routes
src/handlers src/app.ts` (or whatever the live entry-point directory is
called). If the function only appears in `src/services/` and in its own
`.test.ts`, it is dead code. The five-feature Ruby voice build landed
five dead-code modules in one pass — every one had 100% test coverage,
nothing called them, and the user had to prompt a second pass to find
and wire them in.

The wiring commit is its own deliverable, not a footnote of the audit.
It usually touches:
- the route handler / bridge / TTS module that should call the new
  function
- a new optional dep injection seam on the function being wired
  (so legacy callers and tests stay unaffected)
- an `integration.test.ts` block that exercises the live path with
  mocked upstreams and asserts the new function's side effects
  (cache file exists, audit log line was written, timings reflect
  the resolved mode)

See `references/post-implementation-code-quality-audit.md` for the
full "is it wired in?" pre-check recipe and what a wiring commit
looks like end-to-end.

### 0a. Wires that look wired but route to a duplicate implementation

The classic anti-pattern after a "split the monolith" refactor:
`voiceActions.ts` becomes a facade that **re-exports** the new
modules (good) but **also retains its own local copies** of the
functions for the dispatch path (bad). The new modules then have
zero callers — the dispatch path uses the local copies. Grep finds
the function name in `src/services/` (where the re-export lives) and
in `src/services/voiceActions.ts` (the local copy), but never in
`src/routes/` or any live handler. Both the new module and the
duplicate local function coexist, both pass tests, and the audit
"wires" the new module by reading its API while the live code still
runs the old local function.

The diagnostic: after the wiring commit, the new module's function
is called, but the duplicate local function is still in
`voiceActions.ts` and is the one that actually executes. The
behaviour tests still pass because the local copy was also correct.

The fix has two valid options:
1. **Replace the local copy** with a call to the new module's
   function. Keep the audit dep injection seam on the new module.
   Existing tests that spy on the local function need to be
   updated to spy on the new module's function.
2. **Delete the new module entirely** if its only purpose was to
   be a "cleaner" home for code that already lives in the
   monolith. Sometimes the right answer is to admit the refactor
   was premature and let the monolith keep the function.

Option 1 is almost always the right answer in production codebases
where the new module is supposed to be the public API.

### 0b. Audit log + cache + cache audit dep = invisible module-level state

Two modules in the five-feature Ruby voice build were
**module-level lazy singletons** that leaked state across tests:

- `elevenlabsTts.ts` lazily loaded `ttsCache.js` on first call and
  cached the imported module in a module-level `_cacheImpl`
  variable.
- A `_pickProfileImpl` variable held the language profile picker.

In CI, a test that warmed the cache in one file poisoned the next
file's tests. Symptom: `not ok 121 — createElevenLabsSpeech
calls ElevenLabs REST TTS with Liam voice` with
`Expected values to be strictly equal: 0 !== 1` — the second test
got a cache hit and never called fetch.

Two complementary fixes, both required:
1. **Make the side-effect opt-in via env var.** The cache is
   loaded only when `RUBY_TTS_CACHE_DIR` is set. Without the env
   var, the function falls through to a live fetch every time —
   so unit tests and minimal deployments do not silently start
   writing to `/tmp`.
2. **Export a `_resetXxxForTest()` hook** from the module that
   clears the lazy state. Tests call
   `test.beforeEach(() => { _resetTtsCacheForTest() })` to
   isolate each test. Production code never calls it; only tests
   do. The leading underscore is a clear "this is a test-only
   seam" signal.

### 0c. Audit log "swallow on failure" is mandatory, not optional

The five-feature audit module writes a JSONL line per sensitive
action. If the write fails (disk full, bad path, permission), the
voice pipeline must NOT throw — it should log via `onError` and
continue. Same pattern is required for the wiring commit that
passes the audit dep into `sendGmailMessage` / `sendTelegramMessage`
/ `sendWhatsAppMessage` / calendar mutations. The pattern:

```ts
function safeAuditRecord(audit, entry) {
  if (!audit) return
  try { audit.record({ durationMs: Date.now() - startedAt, ...entry }) }
  catch { /* audit must never break the send path */ }
}
```

Every branch in the action (disabled, no key, provider error,
exception) calls `safeAuditRecord` BEFORE returning the user-facing
string. Skipping the swallow is the most common way an audit
logging refactor turns into a regression that breaks Gmail sends
in production.

### 0d. The opt-in env var pattern: `RUBY_<MODULE>_<SETTING>`

For any new side-effect module (cache, audit log, language
detection), gate the actual behaviour behind a `RUBY_<MODULE>_*`
env var so the feature is off by default. The pattern:

- `RUBY_TTS_CACHE_DIR` — TTS cache activates only when this is set
- `RUBY_AUDIT_LOG_PATH` — audit log writes only when this is set
- `RUBY_HERMES_AUTO_INFLIGHT_THRESHOLD`,
  `RUBY_HERMES_AUTO_BRAIN_BUDGET_MS` — auto mode thresholds

This means: (a) tests do not need to set the env var to verify
the no-side-effect path, (b) existing deployments do not need to
add env vars to keep working, (c) the operator decides explicitly
when to turn the side effect on. The "is it wired in?" check
should also verify the env var is set in production before
declaring the feature live.

### 0e. Detect success vs failure by the user-facing string

When the existing action functions all return Hebrew user-facing
strings and the only "success" path starts with the literal prefix
`בוצע` ("done"), the wiring commit can use that prefix as a
success detector inside `executeConfirmedVoiceAction`:

```ts
const success = result.startsWith('בוצע')
safeRecord({
  actionType: success ? action.payload.type : `${action.payload.type}_failed`,
  outcome: success ? 'success' : 'failure',
  error: success ? undefined : result.slice(0, 120),
})
```

This works for the Ruby voice agent because every "executed
something real" reply in that codebase starts with `בוצע — ...`.
For codebases without that convention, branch on the action type
explicitly or have the action functions return a tagged result
(`{ kind: 'success' | 'failure', reply: string, error?: string }`).

### 0f. `const` declared inside `try` is invisible to `finally` and `catch`

A subtle JavaScript scope bug that survived code review and
type-check but blew up at runtime in a real component (Hermes
dashboard iframe probe, June 2026):

```ts
const probeDashboard = async (url: string) => {
  if (!url) return;
  try {
    const ctrl = new AbortController();
    const to = setTimeout(() => ctrl.abort(), 10000);  // ← declared INSIDE try
    await fetch(url, { method: "HEAD", signal: ctrl.signal });
    setState("up");
  } catch (e) { setState("error"); }
  finally { clearTimeout(to); }  // ← ReferenceError: to is not defined
};
```

The author thought "declare the timer where I use it", but
`const` is block-scoped to the `try` block. The `finally` runs
*after* the `try` block exits, and from the `finally`'s lexical
position `to` was never declared — ReferenceError at runtime.

**Why `tsc` does not catch this**: TypeScript's strict mode
catches TDZ violations only when the variable is referenced
*before* its declaration in the SAME block. Cross-block
references (`try` body → outer `finally`) pass the type checker
because `to` is in scope relative to the function body — it just
isn't initialized yet by the time `finally` runs. The error only
fires when the `try` block exits normally and `finally` runs.

**Fix**: declare resources BEFORE the `try`, use them inside,
clean them up in `finally`:

```ts
const probeDashboard = async (url: string) => {
  if (!url) return;
  const ctrl = new AbortController();   // ← outside try
  const to = setTimeout(() => ctrl.abort(), 10000);
  try {
    await fetch(url, { method: "HEAD", signal: ctrl.signal });
    setState("up");
  } catch (e) { setState("error"); }
  finally { clearTimeout(to); }  // ← now in scope
};
```

**Audit rule** for any async function with `try`/`finally` cleanup:
- Identify every resource declared inside the `try` body that
  the `finally` references.
- Move the declaration to immediately before the `try` block.
- This applies to: timers (`setTimeout` → `clearTimeout`),
  AbortControllers, file handles (`openSync` → `closeSync`),
  database transactions (`begin` → `commit`/`rollback`),
  subscriptions (`addEventListener` → `removeEventListener`),
  child processes (`spawn` → `kill`).

**The smell that flags it during code review**: if a `finally`
block references a variable that is only declared inside its
`try` block, that is a bug. ESLint's `no-unsafe-finally` does
NOT cover this (it only catches return/throw inside finally).
The audit must look for the pattern manually.

**Regression test recipe**: write a test that triggers the
`finally` cleanup (e.g. cause the `try` to throw via a mocked
rejection, or simply exit normally) and assert the cleanup ran
without throwing. A simple `expect(() => probeDashboard("..."))
.not.toThrow()` covers the ReferenceError class, but a stronger
test mocks `clearTimeout` and asserts it was called with the
expected handle.

### 1. Treating "tests pass" as "code is correct"

The test gate passes when the existing tests still pass. The audit
may find bugs that the existing tests did not cover. The audit's
output IS the new tests. Do not stop at "I read the code, the bugs
are obvious" — write the regression tests, prove the fix, commit.

### 2. Fixing bugs without categorizing them first

If you start patching before you finish scanning, you lose track
of the bug list. You also waste time re-reading the same file.
Run the scan to completion, then fix in severity order.

### 3. Touching the public API during the audit

The user wanted a quality pass, not a redesign. New env vars are
fine. New helper modules are fine. Changing the signature of
`recordAuditEntry()` or removing an exported type is not fine.
If the audit reveals a real API issue, file it as a follow-up;
do not silently change callers.

### 4. Throttling or caching inside read paths without invalidation

A common fix for "O(N) readdir on every read" is to add a
"last-pruned-at" timestamp and skip the work if it ran recently.
This is correct UNLESS an explicit prune (`clearXxx`, admin
"purge cache") is supposed to be visible immediately. Make sure
the explicit-prune path invalidates the throttle cache.

### 5. Using `Math.max(0, ...)` to "fix" negative math

A common shape: `Math.max(0, (trailing - leading) * frameBytes)`.
This silently zeros the output when the real bug is that
`trailing` or `leading` is wrong. The fix is to figure out why
the variables are wrong, not to clamp them. The clamp is a
symptom masker, not a fix.

### 6. Mixing JSON parsing and the surrounding read

`JSON.parse(readFileSync(metaPath, 'utf8'))` without try/catch
fails the entire read when the meta file is corrupt. The user
expects "cache miss" semantics on a corrupt file, not "read
failure". Wrap the parse; fall back to defaults.

## Output format the user expects

When reporting the audit back, structure as:

1. **What I found** — categorized list with `file:line` evidence
   for every finding.
2. **What I fixed** — one line per fix, mapped to the finding.
3. **What I added** — regression tests, with brief description of
   what bug each one would catch.
4. **Build + test gate** — `tsc --noEmit` clean, `npm test` count
   before vs. after.

The user does not want a "code quality rating" score on its own;
they want a categorized finding list with concrete file:line
evidence and a clear before/after diff in the test count.

## Example output shape

```
# Found 15 issues across 6 categories.

## CRITICAL (3)
- vad.ts:122 — pure tone returns empty buffer (trailing=0 mishandled)
- ttsCache.ts:70 — future mtime treated as stale (clock skew)
- auditLog.ts:79 — statSync on non-existent file (no existsSync guard)

## PERFORMANCE (2)
- ttsCache.ts:83 — pruneIfNeeded is O(N) readdir on every hit
- languageDetector.ts:32 — for-of on String (use charCodeAt)

## ROBUSTNESS (5)
- ttsCache.ts:79 — JSON.parse without try/catch fails entire read
...

## Fixed: 15.  Regression tests added: 11.  Tests: 224 → 235 pass.
```

## What to commit

A single commit that bundles all the fixes + regression tests
is fine for a focused audit pass. Format the commit message
as a categorized list mirroring the audit output, not as a
vague "hardening + tests" summary. The reviewer should be able
to see the bug list, the fix list, and the test list in the
commit message body.
