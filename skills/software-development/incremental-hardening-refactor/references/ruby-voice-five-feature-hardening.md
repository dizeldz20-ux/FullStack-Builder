# [your-voice-product] Agent: Five-Phase Backend Hardening

Use when adding 5 small, self-contained infrastructure features to a
Node.js / TypeScript voice-action backend, each with its own tests, and
each must be safe to ship independently without breaking the existing
test suite. Pattern validated on `[your-voice-product]-hermes-agent/backend` in
2026-06 where the goal was: split one 2,110-line monolith into 8 modules
AND add 5 new infrastructure features in the same session, ending at
**189/189 tests passing**.

After the five features ship, the next session in this codebase
ran a **post-implementation code quality audit** that found 15 real
issues across 6 categories. 11 of them were genuine bugs that would
have shipped to production. They were fixed and 11 regression tests
were added, ending at **235/235 tests passing**.
See `references/post-implementation-code-quality-audit.md` for the
full audit pattern.

## When this pattern fits

- You have a voice-action backend (WhatsApp / Telegram / Gmail / Calendar
  / TTS / STT) that already works end-to-end.
- The user wants concrete, runnable improvements — not architectural
  redesigns.
- Each new feature can be expressed as a self-contained module that
  does NOT require a route handler change in the same commit.
- Tests already exist; you can verify a build + test gate per feature.

## The five feature types (one per infrastructure concern)

In the validated case, the five features were:

1. **Worker Mode Auto-detect** — extend an existing enum
   (`HermesWorkerMode: 'off' | 'queue'` → `'off' | 'queue' | 'auto'`)
   with a pure-function policy module that maps runtime metrics
   (`inFlightVoiceTurns`, `p95BrainDurationMs`) to a mode decision.
2. **Audit Log for sensitive actions** — append-only JSONL file with
   rotation; record every Gmail / Calendar / WhatsApp / Telegram
   send (success or failure); never log email bodies; fail-soft on
   disk errors via an `onError` callback.
3. **TTS cache** — filesystem cache keyed by
   `sha256(voiceId + modelId + normalizedText)`; lazy prune on read;
   explicit `pruneXxxCache()` for tests.
4. **Voice Activity Detection (VAD)** — RMS-energy-based 16-bit PCM
   silence trimming; pure function returning a typed result with
   `leadingSilenceFrames`, `trailingSilenceFrames`, `allSilence`,
   `originalFrameCount`, `trimmedFrameCount` diagnostics.
5. **Multi-language switching** — detect language from text and route
   to per-language `voiceId` + `modelId` for TTS.

## The order that proved safe

```
Feature 1 (Worker Mode Auto)   → enum extension, pure function, ~13 tests
Feature 2 (Audit Log)           → file I/O + rotation, ~12 tests
Feature 3 (TTS Cache)           → file I/O + TTL + LRU, ~12 tests
Feature 4 (VAD)                 → pure function on Buffer, ~13 tests
Feature 5 (Multi-language)      → depends on Feature 3 (TTS cache
                                  per-language), ~10+ tests
```

Why this order:
- 1 is the safest (enum + pure function, no I/O).
- 2 and 3 introduce I/O but in independent, swappable paths.
- 4 is also pure (input is a Buffer, output is a Buffer) and does not
  depend on the cache or the audit log.
- 5 depends on 3 because each language's cached entries are partitioned
  by voice/model, so the cache module must be in place first.

## Per-feature shape

For every feature, the deliverable is:

1. **One new module file** in `src/services/<featureName>.ts` that
   exports a small focused API.
2. **One test file** `src/services/<featureName>.test.ts` with 10–15
   unit tests.
3. **Zero changes** to existing modules unless the new module's types
   need to be re-exported from the facade. Even then, add re-exports;
   do not modify the original function bodies.
4. **One verify cycle**:
   `npx tsc -p tsconfig.json --noEmit` AND `npm test` (or
   `tsx --test src/**/*.test.ts` for this project's runner).

If `npx tsc` passes but `npm test` fails, the test runner is using
tsx/esbuild/swc and the type drift is in a runtime-only path. Read the
TypeScript error first, fix the type, re-run.

If `npm test` passes but `npx tsc` fails, **do not trust the green**.
The test gate is necessary but not sufficient; the typecheck gate is
the one that catches narrowing/widening drift.

## Three pitfalls specific to this 5-feature pattern

### 1. Mixing file-I/O side effects into the type module

When extracting a feature that needs to be both a *type* and an
*implementation* (e.g. an audit log with both an `AuditEntry` type and
a `recordAuditEntry()` function), keep the type in the same file as
the function. Do not split into `<feature>-types.ts` and
`<feature>-impl.ts` for the first commit. That split is a follow-up
that only pays off when there is a second consumer of the types.

### 2. Letting the cache prune run inside the write helper

In the TTS cache, the first implementation called
`pruneIfNeeded(dir, maxFiles)` from inside `writeTtsCacheEntry()`. This
made it impossible to write-then-`utimesSync`-then-prune atomically in
a test, because prune ran before the file's mtime could be adjusted.
Fix: export `pruneTtsCache()` as its own function. Production code does
not need to call it explicitly; the test does.

### 3. `ESM` does not support `require()`

`require('node:fs')` and `require('node:path')` are **not** valid in ESM
context. Use top-level `import` statements or dynamic `import()`. In
the validated case, three test files initially had inline `require`
calls (rescued from JS-era snippets) and the entire test suite failed
with `ReferenceError: require is not defined`. Fix: hoist the imports
to the top of the file. Symptom: tests fail at module load with
"require is not defined" in a file that looks syntactically normal.

## VAD-specific guidance

For the silence-trimming helper, the leading/trailing frame search
loop has a subtle off-by-one. The pattern that works:

```ts
let leading = totalFrames
for (let f = 0; f <= totalFrames - minNonSilent; f++) {
  if (isSilent[f]) continue
  let ok = true
  for (let k = 1; k < minNonSilent; k++) {
    if (isSilent[f + k]) { ok = false; break }
  }
  if (ok) { leading = f; break }
}
```

The earlier implementation used a `continue outer` after `f += k`,
which miscounted when a non-silent run was followed by silence that
started a new run within `minNonSilent` frames. The fix is to
**commit to the current frame index** when an inner-loop break
occurs, not skip ahead by `k` (the inner loop's frame `k` is the one
that failed the test, not part of the run we just abandoned).

Also: initialize `leading` to `totalFrames` (not `0`) and `trailing`
to `0` (not `totalFrames`). This makes the "no run found" case
degenerate to "trim everything", and the `allSilence` predicate
becomes `leading === totalFrames`. Cleaner than the alternative of
sentinel values.

## Multi-language switching — dependency on the TTS cache

The fifth feature ("multi-language switching") is a routing layer
over the TTS cache. Each language has its own `voiceId` and
`modelId` pair, so the cache key naturally partitions by language:

```ts
export function ttsCacheFilename(key: TtsCacheKey): string {
  const text = key.text.trim().replace(/\s+/g, ' ')
  const hash = createHash('sha256')
    .update(key.voiceId).update('\u0000')
    .update(key.modelId).update('\u0000')
    .update(text).digest('hex')
  return `${hash}.bin`
}
```

Adding a `language` field to `TtsCacheKey` is a non-breaking extension:
existing keys (Liam voice + eleven_v3) continue to hash to the same
file. The multi-language switcher can pick a different `(voiceId, modelId)`
pair per detected language and the cache does the rest.

## Summary metrics from the validated case

| Metric | Before | After 5 features | After audit | After wiring |
|---|---|---|---|---|
| `voiceActions.ts` LOC | 2,110 | 1,926 | 1,926 (unchanged) | 1,926 (unchanged) |
| Modules in `src/services/` | ~10 | 18 | 18 (unchanged) | 18 (unchanged) |
| Test files | 11 | 14 | 15 (+regression.test.ts) | 16 (+integration.test.ts) |
| Total tests | 152 | 189 | 235 (+11 audit regression) | 245 (+10 integration) |
| Typecheck errors | 0 | 0 | 0 | 0 |
| `npm test` failures | 0 | 0 | 0 | 0 |
| Real bugs caught by audit | — | — | 11 (3 critical) | 11 (already fixed) |
| Live-wire call sites for new modules | — | 0 of 5 | 0 of 5 | 5 of 5 |

The "After wiring" column matters: the audit pass found 11 in-module
bugs but did NOT verify the modules were called from the live
pipeline. A follow-up user-prompted pass then found that 4 of 5
features were dead code — fully unit-tested, never reached. The
wiring commit added the dep-injection seams (e.g. an optional
`audit?` param on `sendGmailMessage`), called the new helpers from
the live route / bridge / TTS code, and added 10 integration tests
that exercise the previously-unwired branches. See
`references/post-implementation-code-quality-audit.md` for the
"is it wired in?" pre-check that catches this earlier next time.

Audit findings (categorized; full list in
`references/post-implementation-code-quality-audit.md`):

- 3 CRITICAL: VAD pure-tone returns empty buffer, TTS cache
  future-mtime treated as stale, audit log rotates non-existent file.
- 2 PERFORMANCE: TTS cache prune is O(N) readdir per read,
  language detector uses slow `for-of` on long strings.
- 5 ROBUSTNESS: corrupt meta fails read, partial trailing frame
  mishandled, non-deterministic sort on ties, throttle not invalidated
  after explicit prune, range cap undocumented.
- 5 polish: imports, comments, dead code, hard-cap reasoning.

## What did **not** change:
- Public API of any existing module
- Number of routes in `src/routes/`
- Wire format of `/api/ask-ruby` or `/api/voice-turn`
- Any feature flag toggle
- Any environment variable

That last bullet is intentional. New env vars (`RUBY_HERMES_AUTO_INFLIGHT_THRESHOLD`,
`RUBY_TTS_CACHE_DIR`, `RUBY_AUDIT_LOG_PATH`) are **opt-in** with safe
defaults; existing deployments do not need to set them to keep working.

## Wiring the five features into the live pipeline (post-audit pass)

The audit pass found 15 in-module bugs and fixed them. The follow-up
wiring pass found that **4 of 5 features were dead code** — fully
unit-tested, never reached by the live pipeline. The wiring commit
brought 5/5 to live and added 12 more integration tests (235 → 257
passing).

The wiring pass has its own shape that the audit pass does not
cover. The pattern that proved safe:

### Step 1. Discover the dead-code gap

For every new public function exported by the five new modules, run:

```bash
grep -rn "<newFunctionName>" src/routes src/handlers src/app.ts
```

If the function name only appears in `src/services/` and in its own
`.test.ts`, it is dead code. The five-feature build found four of
five in this state:

- `hermesBridge.ts` had `workerMode === 'queue'` but no `'auto'`
  branch — `resolveAutoWorkerMode` was exported and tested but
  never consulted.
- `elevenlabsTts.ts` had a hard-coded voice lookup; `pickTtsProfile`
  and `readTtsCacheEntry` existed but were never invoked.
- `gmailActions.sendGmailMessage` had no call to `recordAuditEntry`.
- `whatsappActions.sendWhatsAppMessage`,
  `telegramActions.sendTelegramMessage`, and the three
  `*MatonCalendarEvent` functions in `calendarActions.ts` — same
  story.

### Step 2. Identify the dispatcher and its call sites

For Ruby voice, the dispatch path is `voiceActions.ts` → it has a
local `executeConfirmedVoiceAction` (the local duplicate of what
the new modules would do) called from a `setTimeout` inside
`queueConfirmedVoiceAction`. The setTimeout is the only real call
site; the `switch` statement in `executeConfirmedVoiceAction` is
a dispatcher that the production code never reaches.

The wiring fix:
1. Add an optional `audit?` parameter to
   `executeConfirmedVoiceAction` and a per-action audit facade
   inside the `setTimeout` callback so the async lifecycle
   (success / failure / exception) of each pending voice action
   is recorded.
2. Route the audit facade through `recordAuditEntry` from
   `auditLog.ts` so JSONL writes happen with the right
   `conversationId` and `ts`.
3. Detect success vs failure by checking whether the action's
   reply starts with the Hebrew literal `בוצע` (every successful
   action in this codebase returns `בוצע — ...`).

### Step 3. Add dep injection seams

The audit log wiring required touching six different action
functions. To avoid breaking the existing call sites and the
existing tests that pass a `fetchImpl` mock, every action was
extended with an optional `audit?` and `conversationId?` parameter
at the end of the signature:

```ts
export async function sendGmailMessage(
  payload: GmailSendPayload,
  env: NodeJS.ProcessEnv = process.env,
  fetchImpl: FetchLike = fetch,
  audit?: { record: (entry: ...) => void },  // NEW
  conversationId?: string,                    // NEW
): Promise<string>
```

Existing callers (and the existing tests) pass 2 or 3 args and
work unchanged. The new voice-actions dispatcher passes 5.

### Step 4. Make the TTS module cache opt-in

`elevenlabsTts.ts` was loading the TTS cache as a module-level
lazy singleton. This poisoned cross-test state in CI. Two
complementary fixes, both required:

1. The cache is loaded only when `RUBY_TTS_CACHE_DIR` is set.
   Without the env var, the function falls through to a live
   fetch every time.
2. Export a `_resetTtsCacheForTest()` hook. Tests call
   `test.beforeEach(() => { _resetTtsCacheForTest() })`. The
   leading underscore is a clear "test-only seam" signal.

### Step 5. Build the chunked VAD wrapper

The pure `trimSilence` function takes a complete PCM buffer. A
real WebSocket audio pipeline feeds it in chunks (16-bit
little-endian, 20ms frames at 16kHz). Without a chunked wrapper,
the pure function is unreachable from any live audio source.

The wrapper is `vadIntegration.ts` → `createVadChunker()` returns
a `{ push, flush, reset, byteLength }` API. The chunker:
- accumulates chunks until `flush()` is called
- caps memory at `maxFrames * frameBytes` (default 5000 frames,
  ~100 seconds)
- exposes a `reset()` to clear between utterances
- returns the trimmed PCM plus the same diagnostics as the pure
  function (`leadingSilenceFrames`, `allSilence`, etc.)

This is the bridge between the pure-function testable VAD and
the streaming audio pipeline that needs it.

### Step 6. Add integration tests for the live path

The integration tests in `integration.test.ts` and
`voiceActionsAudit.test.ts` exercise the live path with mocked
upstreams (TTS fetch, Maton Google API, WhatsApp bridge) and
assert that the new functions' side effects actually fire:

- TTS live fetch writes the result to the cache (second call
  is a hit).
- TTS routes Hebrew text to the Hebrew voice.
- Worker Mode auto with high in-flight resolves to `queue`; low
  load resolves to `off`.
- Audit log: Gmail success writes a single JSONL line with the
  expected shape; failure writes a `*_failed` entry; no audit
  dep means no writes.

12 new tests in the wiring pass, all green.

### Step 7. Expose cache status on the HTTP response

The `/api/elevenlabs/tts` route now returns an `X-TTS-Cache:
hit|miss` header and includes `cacheHit: true|false` in its log
event. The Tauri/webapp surfaces cache hits in the UI; ops can
query the log for `cacheHit=true` rate. This is the observability
side of the wiring — the feature is wired in, now it is also
*visible* that it is wired in.

### Summary metrics for the full five-feature lifecycle

| Metric | Pre-build | After 5 features | After audit | After wiring |
|---|---|---|---|---|
| `voiceActions.ts` LOC | 2,110 | 1,926 | 1,926 | 2,011 (audit hooks added) |
| Modules in `src/services/` | ~10 | 18 | 18 | 19 (+vadIntegration) |
| Test files | 11 | 14 | 15 | 17 (+integration, +voiceActionsAudit) |
| Total tests | 152 | 189 | 235 | **257** |
| Typecheck errors | 0 | 0 | 0 | 0 |
| Live-wire call sites for new modules | 0 of 5 | 0 of 5 | 0 of 5 | **5 of 5** |
| Cache observability | n/a | n/a | n/a | `X-TTS-Cache` header + log flag |

The "5 of 5" row is the only metric that matters. Everything else
is supporting infrastructure.
