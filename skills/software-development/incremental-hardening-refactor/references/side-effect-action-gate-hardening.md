# Side-effect action gate hardening

Use when a live product has natural-language actions that may call external transports/tools (messaging, email, calendar, payments, files, home automation, etc.).

## Invariants

- Sensitive actions must preview first and require explicit approval; never let detection of an action imply execution.
- Approvals must bind to a pending action in the same conversation/session, preferably via an action id in metadata.
- Legacy/provider tools that cannot persist metadata may get a narrow adapter, but only when scoped by source, endpoint, conversation id, and an existing latest pending action. Do not make the fallback global.
- Keep response contracts stable for legacy endpoints: add preview fields if needed, but do not leak debug timings/worker internals into older tool paths unless that endpoint already promises them.
- Real side-effect execution should use an explicit runtime allowlist. For every executable payload type, require code, tests, docs, and QA review before it can call a bridge/provider.
- Unsupported or future executable payloads must fail closed before queueing, clear pending state, and produce no completion notification or bridge call.
- Simulated/preview-only sensitive intents without executable payloads should remain safe and behavior-preserving; do not break existing “preview/simulation” behavior while adding execution guards.
- Draft edits should replace approval bindings/action ids so stale approvals cannot execute older text.
- Expired pending actions should return an explicit status (for example `actionState: "expired"`) when the supplied action id matched a previously pending action whose TTL elapsed. State that nothing executed, clear the real pending action, and ask for a fresh preview instead of collapsing this case into generic `missing_context`.
- Keep the real pending-action store authoritative for execution; shadow conversation state may help UX, but queueing must still require an active same-conversation pending action with the exact expected action id.

## Red/green test ideas

- Legacy entrypoint produces `needs_confirmation` + `actionId` for the same sensitive intent as the new entrypoint.
- Approval without metadata is `missing_context` for normal clients.
- Legacy provider fallback without metadata works only for the named source and same conversation after a preview.
- Wrong conversation, stale metadata, malformed metadata, or no pending action all return safe `missing_context` and do not call the tool.
- Inject a fake future payload type (cast around the union type) and assert the queue returns no job, clears pending state, and produces no notification after the executor delay.
- Create a preview, advance time beyond the pending-action TTL, then approve with the matching action id and assert `expired`, no queue, no notification/bridge call, and a user-facing “fresh preview required” message.

## Verification

Run focused tests around the action gate/queue, typecheck, full workspace tests/build/audit, `git diff --check`, then have a QA/security reviewer inspect edge cases before commit.