# Monolith → Modules: Safe Extraction Recipe for 100+ Function Files

Use when you face a single 1,500–3,000 line TypeScript/JavaScript file that
mixes 100+ functions across multiple domains (here-doc classification, channel
routing, action stores, network calls, normalization helpers, etc.) and you
need to break it into modules WITHOUT breaking the existing test suite.

This pattern was validated on a real `voiceActions.ts` (2,110 lines / 148
functions / 152 tests / 5,066 lines in `askRuby.test.ts` alone) where the
target was to extract a public-API-preserving facade that splits by domain.

## The 8-step extraction loop

1. **Categorize first, extract second.** `grep -E '^(async )?function '` the
   file, then group functions by domain. Do not start typing until you have a
   target module list with rough function counts per module. For a 148-function
   file a typical split is 6–10 modules.

2. **Extract the lowest-coupling domain first.** Pure functions with no
   dependencies on the shared in-memory store are safest to extract first.
   Examples that worked well: `hebrewNormalize.ts` (16 utility functions for
   text normalization), `pendingActionStore.ts` (types + Map-backed store).

3. **Re-declare the type signatures in the new module.** For each function you
   extract, copy the signature, the body, and the imports it needs. Do NOT
   widen or narrow the return type — see pitfall 4a in the parent SKILL.md.

4. **Add the import block in the OLD file.** Use a single import block for
   the new module's exports at the top of the monolith. Keep the old file's
   own `function name() { ... }` declaration removed in the same commit.

5. **Run `tsc --noEmit` BEFORE running tests.** The extraction's return-type
   drift is invisible to `node --test` / `tsx` / `esbuild` because they
   transpile without type-checking. If you only run the test gate you will
   see green when the type system is actually broken. Run
   `npx tsc -p tsconfig.json --noEmit` explicitly.

6. **Run the full test suite.** `npm test` (or whatever the project uses).
   The full test suite is the regression net that proves the extraction is
   pure mechanical, not behavioral. In the validation case: 152/152 pass
   after extracting two modules (~30 functions).

7. **Re-export public types from the monolith.** External consumers import
   from the monolith path (e.g. `from './voiceActions.js'`). When you move
   types to a new module, the monolith must re-export them so the public API
   does not break. Strategy: at the end of the monolith, add
   `export { Type1, Type2 } from './pendingActionStore.js'` and similar
   re-export blocks for the types that were moved.

8. **Commit, then pick the next domain.** One commit per module extracted.
   Bisect stays clean. If a commit breaks tests, the diff that broke them is
   exactly the new module + the import in the monolith.

## Reusable module order (lowest coupling first)

In the voiceActions.ts case the working order was:

1. **`hebrewNormalize.ts`** — pure text helpers, regex constants, no shared
   state, no network. 16 functions, ~250 lines.
2. **`pendingActionStore.ts`** — in-memory Maps + types. No network, but
   defines the `PendingVoiceAction` / `VoiceNotification` types the rest of
   the code uses. About 100 lines.
3. **`matonClient.ts`** — `MATON_BASE_URL`, `resolveMatonApiKey()`,
   `googleActionsEnabled()`, shared by Gmail and Calendar.
4. **`recipientResolver.ts`** — `resolveGmailSelfRecipient()`,
   `resolveTelegramSelfRecipient()`, `resolveWhatsAppSelfPhone()`.
5. **`telegramActions.ts`** — Telegram self-test, send payload builder,
   send executor.
6. **`whatsappActions.ts`** — same shape as Telegram but for WhatsApp bridge.
7. **`gmailActions.ts`** — `sendMatonGmail()`, draft handlers, read-only list
   helpers.
8. **`calendarActions.ts`** — create / delete / update / list. Largest module
   (~30 functions).

After all 8 modules exist, the original `voiceActions.ts` shrinks to a
~150-line public-API facade that re-exports the public types and functions
from the modules.

## Why "facade" instead of "update all import sites"

The voiceActions.ts case had consumers in `rubyBridge.ts` and `askRuby.ts`
that imported from `'./voiceActions.js'`. Migrating those call sites to the
new module paths is a separate commit. Keeping the facade in place means:

- the rest of the refactor is invisible to consumers
- tests keep working without import-path changes
- you can delete the facade later, one consumer at a time, with
  typecheck+test coverage proving each step

## What this looks like in the original file

```diff
+ import {
+   draftChannel,
+   extractDraftBody,
+   extractDraftRecipient,
+   formatDraftChannel,
+   // ... 13 more
+ } from './hebrewNormalize.js'

- function normalizeSpeech(message: string) { ... }
- function stripRubyAndPlease(text: string): string { ... }
- function hasDraftSignal(normalized: string): boolean { ... }
- // ... 13 more local declarations removed
```

After all 8 modules are in place, add the public re-export block at the
bottom of the monolith:

```ts
export {
  PendingVoiceAction,
  VoiceActionNotification,
  HermesReplyNotification,
  VoiceNotification,
  VoiceActionType,
  VoiceActionState,
  VoiceActionPayload,
} from './pendingActionStore.js'
```

## Pitfalls specific to this refactor pattern

- **Do not rename functions during extraction.** Mechanical moves only.
  Renames belong in a follow-up commit that is its own line item in the
  diff.
- **Do not move tests in the same commit.** Tests stay in their original
  `*.test.ts` files. They keep importing from the monolith until the facade
  is fully populated.
- **Do not try to dedupe call-site boilerplate in the same commit.** The
  extraction is one commit. The dedupe is a follow-up.
- **Track the function-count target.** A 148-function file split into 6–10
  modules is the right shape. If you end up with 2 modules, you have not
  split enough; if you end up with 20, each module is too small to be
  navigable.

## When the store type depends on per-channel payload types

Real failure mode seen during extraction: the in-memory store
(`pendingActionStore.ts`) needs to reference `PendingVoiceAction`, which
holds a `payload: VoiceActionPayload` field. But the union of payload
shapes (`TelegramSendPayload`, `GmailSendPayload`, etc.) is only declared
in the monolith because the channel modules depend on the store, and
introducing a circular import is forbidden.

The pattern that works:

1. **Declare a generic-compatible alias in the store module first.** The
   alias has the *same* shape (the same union of literal `type` fields
   with the same per-variant fields), but it does not need to import the
   per-channel payload types from the monolith.
2. **Keep the local `VoiceActionPayload` in the monolith** for ergonomic
   type narrowing at call sites; the store alias lives in parallel.
3. **Document the equivalence** with a comment in the store module that
   says "this alias mirrors the union declared in `voiceActions.ts`;
   keep them in sync when a new channel is added."

Example alias from the validated case:

```ts
// pendingActionStore.ts
export type StoreVoiceActionPayload = {
  type: 'telegram_self_test'
} | {
  type: 'telegram_send'
  recipientKey: string
  recipientLabel: string
  chatId: string
  text: string
} | { type: 'whatsapp_send'; /* ... */ }
  // ...one variant per channel
```

Do NOT try to "lift" the payload union out of the monolith in the same
extraction. That turns a 30-line mechanical move into a 200-line cross-file
type shuffle and tends to break tests that import the union from
`./voiceActions.js`.

## Re-exporting functions from the facade, not just types

A "re-export facade" needs to re-export **function** names too, not just
`type`s. Real failure mode: the monolith had a helper `resetVoiceActionStoreForTests()`
that was imported by `rubyBridge.ts` and `askRuby.ts` for test setup.
When the function moved into `pendingActionStore.ts`, the consumers'
imports broke because the monolith no longer re-exported it.

Pattern:

```ts
// voiceActions.ts (the facade)
import { resetVoiceActionStoreForTests as _reset } from './pendingActionStore.js'

export { resetVoiceActionStoreForTests } from './pendingActionStore.js'
```

Why the local alias: it makes the import explicit in the facade and
prevents a future reader from "cleaning up" what looks like an unused
import. The re-export is the entire reason the import exists.

Test this in the same commit: after the extraction, add a focused test
that imports the function via the facade path and confirms it is the
*same reference* (or at least equivalent) as the one in the source
module. Otherwise a future "import cleanup" can silently drop the
re-export and break a downstream test.

## When a local function is hidden behind the import name

Real failure mode: the monolith declared `safeEmailSenderLabel` twice,
once with the signature `(value: string | undefined, fallback: string) =>
string` and once with `(value: string | undefined) => string`. A naive
`patch` of one of them based on a grep for `function safeEmailSenderLabel`
will remove the wrong declaration. The remaining declaration then has a
broken body (e.g. it calls a sibling `safeEmailText` that was removed in
the same commit) and tests fail with cryptic `Cannot find name 'safeEmailText'`
errors.

Mitigation:

- Before patching a "duplicate" function, run `grep -n 'function <name>' <file>`
  and read both bodies.
- Prefer `patch` (Hermes / patch tool) with sufficient surrounding context
  to disambiguate; do not rely on `replace_all: true` for renames.
- After every extraction commit, re-run `npx tsc --noEmit`. A duplicated
  function with a now-broken body will fail the typecheck before the
  test gate.

## Tests that need `utimesSync` to simulate aging

When the new module has a TTL / age-based eviction policy (cache pruning,
stale-notification cleanup, etc.), unit tests cannot rely on `Date.now()`
alone — writing a file and immediately reading it gives mtime = now,
which is never "older than 1ms". Use `utimesSync` to backdate the file:

```ts
import { utimesSync } from 'node:fs'

const file = join(dir, cacheFilename(key))
const oldTime = (Date.now() - 60_000) / 1000  // 60 seconds ago, in seconds
utimesSync(file, oldTime, oldTime)

const result = readCache(key, { maxAgeMs: 1 })
assert.equal(result, undefined)
```

For the prune path, use `utimesSync` with a *future* timestamp so
the entry is "newer than" the others, ensuring deterministic
`sort by mtime` ordering in the test:

```ts
const future = (Date.now() + 5 * (i + 1)) / 1000
utimesSync(file, future, future)
```

Combine this with **splitting the write and the prune** into separate
exported functions. If the cache's `write` helper also runs prune
inline, the test cannot write-then-utime-then-prune atomically; the
prune sees the wrong mtime. Export `pruneXxxCache()` as its own
function so tests can call it explicitly between writes and utimes
adjustments.

## When to stop extracting

Stop when the monolith is small enough that a new reader can see the entire
public API in one screen (~150–300 lines), and every extracted module has
its own focused tests OR the monolith's existing tests still cover the
behaviour of every extracted function.
