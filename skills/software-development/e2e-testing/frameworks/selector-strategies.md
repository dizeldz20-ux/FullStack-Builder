# selector-strategies.md (stub)

> **[stub]** — This file is referenced from `e2e-testing/SKILL.md` and multiple `tasks/*.md` but is not yet implemented in the public release. It should provide robust selector strategies for Playwright tests.

This file should cover:
- Priority order: `data-testid` > `getByRole` > `getByLabel` > `getByText` > CSS selector
- Why `data-testid` is the most resilient (independent of styling/i18n)
- Anti-patterns: nth-child, brittle CSS paths, class names that change with refactor
- ARIA roles for `getByRole`: button, link, heading, textbox, combobox
- How to add `data-testid` to components without polluting the codebase

**To fill this stub**, copy the developer's local Vault version (if present) or implement from scratch.