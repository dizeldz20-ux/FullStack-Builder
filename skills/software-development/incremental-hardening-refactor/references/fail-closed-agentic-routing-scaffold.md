# Fail-closed agentic routing scaffold

Use this when adding an agent/router layer over a live product path before a real executor boundary exists.

## Pattern

- First slice is routing/guard only, not execution.
- Add a decision type for explicit delegation requests, but do not let it fall through to an existing local runner just because a runner exists.
- Add a separate guard/service with its own explicit `=1` flag.
- The guard should still fail closed when enabled if there is no approved cloud-only executor.
- Reject unknown agent names and secret-like prompts before any delegation boundary.
- Return truthful status text that says no approved executor exists yet; do not simulate successful delegation.
- Tests should prove:
  1. default flag is off and only exact `1` enables it;
  2. enabled-without-executor returns `executor_unavailable`;
  3. secret-like prompts are rejected without echoing the secret;
  4. explicit delegation does not call the legacy/local runner;
  5. unknown/non-delegation prompts keep the prior path.

## Verification and commit hygiene

- Run focused service/router/bridge tests first.
- Then run full tests, typecheck, build, and `git diff --check`.
- Grep/review new files for accidental `fetch`, `spawn`, `exec`, `fs`, raw secrets, or live send paths.
- Stage only files in the slice; leave unrelated dirty docs/files out of the commit unless the user explicitly asks.
