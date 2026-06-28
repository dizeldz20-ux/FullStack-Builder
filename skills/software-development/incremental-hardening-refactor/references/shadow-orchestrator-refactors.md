# Shadow-mode orchestrator refactors

Use this reference when adding an orchestration layer to a live system without breaking existing behavior.

## Pattern

When a feature needs a new manager/orchestrator over an already-working path, introduce it in shadow mode first:

```text
existing route/service
→ new orchestrator wrapper
→ normalize/classify/record bounded state
→ delegate to the existing implementation unchanged
→ return the existing response unchanged
```

Only later should the orchestrator make routing or execution decisions.

## Why

This prevents architecture work from silently changing user-visible behavior. It also creates a safe place to add tests for future intent/state behavior before using those classifications to drive side effects.

## Steps

1. Add a narrow orchestrator interface and dependency injection for the existing implementation.
2. Route all relevant entrypoints through the orchestrator, not just the first action that motivated it.
3. Add normalization and classifier/state interfaces that are transport-neutral.
4. Record state in-memory with bounded TTL/turn count/text length.
5. Keep side effects delegated to the existing implementation.
6. Add tests proving:
   - options/input are passed through unchanged;
   - response shape/identity is preserved;
   - classifier/state recording happens;
   - orphan approvals or missing context do not execute anything;
   - no new network/send calls were introduced.
7. Run focused tests first, then typecheck, full tests/build, and dry smoke without live side effects.

## Pitfalls

- Do not make the orchestrator action-specific if the user asked for a system-level conversational manager.
- Avoid circular imports between normalization and intent/state modules; shared utilities should either live below both modules or be duplicated narrowly until extracted safely.
- Do not let shadow classifications alter execution until a later explicit behavior-changing slice.
- For personal assistants, user approval may be sufficient policy-wise, but still bind approval to a concrete pending action in the same conversation/session.
