# Legacy entrypoint action-gate parity

Use this when a product already has a safer new route/manager path, but older route/tool/webhook entrypoints still exist for compatibility.

## Core invariant

A hardening slice is incomplete if only the newest endpoint uses the action/approval gate. Every entrypoint that can express the same sensitive intent must share the same deterministic preview/approval/cancel semantics, even if its response shape remains legacy-compatible.

## Safe migration pattern

1. Inventory entrypoints for the same class of user intent:
   - new web/API route;
   - legacy server-tool route;
   - provider webhook/tool callback;
   - CLI/background trigger if present.
2. Pick one old entrypoint and write a RED test proving it currently bypasses or weakens the manager/gate.
3. Preserve the old response contract where clients depend on it.
4. Add only the safe gate fields the old client can consume (`requiresConfirmation`, `actionState`, `actionId`, summary/preview text as appropriate).
5. Keep route-specific observability boundaries intact. If the old contract did not expose timings/worker internals, do not add them just because the new route has them.
6. Require the same approval binding used by the new route, e.g. matching `metadata.pendingActionId` / conversation / action id.
7. Add a negative test for bare approval without metadata returning a safe `missing_context`/no-op state.
8. Update docs/runbooks in the same slice so they do not keep teaching the bypassed legacy behavior.

## Test pitfall

Do not over-assert incidental mode labels in fallback/mock tests. If mock/local mode is still valid, the invariant is that sensitive actions preview and require binding, not that the route reports a particular brain/provider mode.

## Verification

Run focused route tests, typecheck/build, full suite, audit/security scan if present, diff check, then QA/security review before commit.