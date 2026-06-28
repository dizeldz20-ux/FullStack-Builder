# Browser voice runtime stabilization checklist

Use this when a live browser voice app is mostly working but has accumulated runtime changes and the user wants stabilization before real device/phone QA. Keep changes narrow and regression-tested; defer broad cleanup until after live QA.

## Hazards to audit

1. **Auth-protected browser preflight**
   - If frontend requests include `Authorization` or an app token header, every browser-facing route must allow those headers in CORS preflight.
   - For provider-token minting routes, keep origin allowlisting strict; do not solve preflight failures by adding wildcard CORS.
   - Test allowed-origin OPTIONS and disallowed-origin rejection before provider calls.

2. **Async completion drain races**
   - If a request can return `pending` and later complete through a polling/drain endpoint, scope drains by a stable correlation key.
   - Use turn/request ids for delayed assistant replies and action ids for side-effect completions.
   - A filtered drain should remove matching active notifications and retain nonmatching active notifications.
   - Frontend should pass the pending correlation id into polling and ignore mismatched delayed replies defensively.

3. **Cancel intent before update intent**
   - For pending side-effect previews, cancellation phrases must be classified before follow-up/edit keywords.
   - This matters for phrases like Hebrew `לא תודה`, where `תודה` could otherwise trigger a draft-update path.
   - Add a regression test that cancellation clears pending state and does not call the brain/action executor.

4. **Env/config alias drift**
   - When runtime/deploy notes already reference an env var alias, support it in code instead of requiring the operator to rename during QA.
   - Document accepted aliases in `.env.example` and add a regression test for file-based secret loading if relevant.

## Verification pattern

Run focused tests around the changed runtime paths first, then the full gate:

```bash
npm run test --workspace backend -- <focused-backend-tests>
npm run test --workspace frontend -- <focused-frontend-tests>
git diff --check && npm test && npm run build && npm audit --audit-level=high
```

If a full gate finds only whitespace after tests/build/audit passed, fix it and rerun the full gate. Do not tell the user live QA is ready until the rerun exits 0.

## Diff review before commit

Before committing, run or delegate a no-edit review focused on the uncommitted diff:

- Did the CORS/auth fix preserve strict allowed origins?
- Can one pending turn/action consume another's notification?
- Are cancellation patterns ordered before edit/update patterns?
- Did docs gain placeholders/aliases without real secrets?
- Are generated artifacts excluded unless intentionally tracked?

Then inspect `git status`, `git diff --stat`, and commit one coherent stabilization slice.
