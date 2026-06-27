# email-testing-patterns.md (stub)

> **[stub]** — This file is referenced from `e2e-testing/SKILL.md` and `tasks/write-smoke-tests.md` but is not yet implemented in the public release. It should provide patterns for testing email flows end-to-end.

This file should cover:
- Disposable inbox services (Mailinator, Mailtrap, Mailslurp)
- How to wait for an email to arrive (poll the inbox API)
- Extracting verification links / OTP codes from email bodies
- E2E flow: sign up → check email → click verification link → assert logged in
- Cleaning up the inbox between test runs

**To fill this stub**, copy the developer's local Vault version (if present) or implement from scratch.