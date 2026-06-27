# ci-patterns.md (stub)

> **[stub]** — This file is referenced from `e2e-testing/SKILL.md` and `tasks/ci-integration.md` but is not yet implemented in the public release. It should provide CI integration patterns for Playwright tests.

This file should cover:
- GitHub Actions workflow for Playwright
- Caching `~/.cache/ms-playwright` between runs
- Sharding tests across multiple workers (matrix strategy)
- Storing test artifacts (screenshots, videos, traces) on failure
- Slack/Discord notifications on test failure
- Required secrets (e.g. TEST_USER_EMAIL, TEST_USER_PASSWORD)

**To fill this stub**, copy the developer's local Vault version (if present) or implement from scratch.