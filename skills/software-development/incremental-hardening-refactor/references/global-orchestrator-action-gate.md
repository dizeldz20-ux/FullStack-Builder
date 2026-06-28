# Global Orchestrator Action Gate Refactors

Use this when a refactor moves side-effect gating from a service-specific implementation into a new global orchestrator/manager.

## Key invariant

If the new orchestrator disables the old downstream action gate on fallback, the new gate must preserve classifier parity with the old one. A single omitted sensitive pattern can become a safety bypass.

## Safe sequence

1. Start with shadow-mode manager/orchestrator:
   - route all relevant entrypoints through it;
   - normalize/classify/record bounded short-term state;
   - delegate execution unchanged.
2. In the next slice, let the orchestrator own only the safe action gate:
   - preview sensitive action;
   - require same-conversation pending binding;
   - require matching `metadata.pendingActionId` before queue/execute;
   - cancel pending actions without delegating;
   - delegate fallback with downstream voice/action gates disabled to avoid duplicate execution paths.
3. Before disabling the old gate, regression-test parity with old helpers/patterns:
   - payment: `תשלום`, `pay`, `payment`;
   - destructive/delete/remove terms;
   - send/message terms;
   - calendar/meeting/schedule terms;
   - cancellation, including bare Hebrew `לא` for open pending actions.
4. Keep follow-up/draft-update turns non-executing until a later slice. They may delegate to the brain with action execution disabled, but must not queue/send.
5. When enabling draft updates, update only an existing pending draft and return a fresh preview:
   - gate by current pending payload type before editing (for example `whatsapp_self_send` only);
   - put heuristics in a small bounded draft-update service, not inside the queue/execution path;
   - replace the pending action with a new `actionId` rather than mutating text under the old approval handle;
   - require stale old approvals to return `missing_context`;
   - unsupported/no-pending follow-ups should delegate safely with downstream action execution disabled and must not create hidden pending actions.
6. Clear shadow state after queueing as well as after completion/cancellation. Real pending stores often clear at queue time; stale shadow `pendingActionId` causes confusing approvals/follow-ups.

## Regression tests to add

- Sensitive payment request creates preview and does not call the brain.
- Orphan approval returns `missing_context`.
- Wrong-conversation approval with a real action id returns `missing_context`.
- Matching approval queues only when `metadata.pendingActionId` matches state/pending store.
- Bare `לא` cancels an open pending action without calling the brain.
- Follow-up like “תעשה את זה יותר קצר” does not queue/send and calls the brain with action execution disabled when no supported pending draft exists.
- Draft update with an existing pending self-send returns a new preview with a new `actionId`.
- Stale approval using the old pre-edit `actionId` returns `missing_context` and does not queue/send.
- Appending a simple edit such as “תוסיף תודה בסוף” updates the draft and again rotates the `actionId`.
- State cleanup removes `pendingActionId` after queued approval.

## Dry live smoke

Run a no-side-effect smoke:

- preview sensitive action → `needs_confirmation`;
- update a supported pending draft → `needs_confirmation` with a new `actionId`;
- stale approval using the old action id → `missing_context`;
- second draft update → another new `actionId`;
- orphan/no-pending draft update → no `actionState`, no confirmation, safe delegation only;
- orphan approval → `missing_context`;
- wrong conversation approval → `missing_context`;
- payment request → `needs_confirmation`;
- bare `לא` after preview → `cancelled`;
- notification queue after cancel → empty.

## Review prompt

Ask QA/security to inspect specifically for dropped classifier patterns, fallback bypass, same-conversation/metadata binding, cancellation parity, stale shadow state after queue, and accidental follow-up execution.