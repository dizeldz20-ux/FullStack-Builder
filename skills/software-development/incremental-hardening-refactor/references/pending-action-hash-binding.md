# Pending action hash binding for voice approvals

Use when hardening a voice/personal-assistant flow that creates a pending side-effect action and later consumes a natural-language approval.

## Problem

A same-conversation `actionId` check is better than a bare "yes", but it is still weaker than binding the approval to the exact previewed payload. If callers or route tests approve with only `pendingActionId`, stale or partially replayed approval metadata can execute the wrong queued action after the action payload changes.

## Safer invariant

- A pending confirmation response exposes both:
  - `actionId`
  - `actionHash` — deterministic hash of the pending action payload/summary/target data already used by the backend.
- Approval metadata must include both:
  - `metadata.pendingActionId`
  - `metadata.pendingActionHash`
- Execution only proceeds when both fields match the currently pending action.
- Missing or mismatched hash returns a safe `missing_context`/no-open-action status and performs no side effect.
- Do not implicitly cancel the pending action on hash mismatch unless the product intentionally wants that behavior and tests prove it.

## Implementation checklist

1. Add RED tests for:
   - preview exposes a 64-char hex `actionHash`
   - approval with only `pendingActionId` is rejected
   - approval with wrong hash is rejected
   - approval with matching id+hash queues/executes the action
2. Update the core approval helper signature from id-only to id+hash, e.g. `queueConfirmedVoiceAction(conversationId, expectedActionId, expectedActionHash)`.
3. Parse/validate `metadata.pendingActionHash` narrowly (`/^[a-f0-9]{64}$/`).
4. Include `actionHash` in every response mapper that returns `actionId`, including route-level contracts such as `/api/ask-ruby` and `/api/voice/turn`.
5. Update older route/service tests that approve actions to pass both fields from the preview response.
6. Run focused route+bridge approval tests before the full gate.

## Verification gates

- Focused: route + bridge approval tests for the affected endpoints.
- Full: `npm test -- --runInBand`, `npm run typecheck`, `npm run build`.
- QA: `git diff --check`, inspect for no new executor/network/side-effect path, and stage only files for the hardening slice.