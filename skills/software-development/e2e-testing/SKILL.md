---
name: e2e-testing
type: standalone
version: 1.0.0
category: development
description: "סט-אפ של בדיקות End-to-End עם Playwright (מועדף) או Cypress. מריץ smoke tests על user paths קריטיים מול אפליקציה חיה (local או staging), עם screenshots, ויזואל regression, ואינטגרציה ל-CI. כולל את הדפוס הקבוע של 'user נרשם → נוחת בדשבורד' שאנחנו עושים בכל פרויקט."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch]
metadata:
  hermes:
    tags: [e2e, playwright, cypress, smoke-test, visual-regression, ci, github-actions, gitlab, testing, automation, sign-up, dashboard]
    related_skills:
      - software-development/build-product
      - software-development/cloudflare-deploy
      - software-development/api-contract-designer
      - software-development/supabase-auth-patterns
      - software-development/test-driven-development
---

<activation>
## What
מקים תשתית E2E testing מלאה בפרויקט: Playwright (או Cypress כ-fallback), smoke tests על critical user paths, screenshots + visual regression, CI integration (GitHub Actions / GitLab CI), ו-trace viewer לדיבאג. הסקיל מכסה גם את הדפוס החוזר של "user נרשם → מאומת email → נוחת בדשבורד" — אותו flow שאנחנו בונים בכל מוצר.

## When to Use
- "תוסיף לי E2E tests לפרויקט"
- "אני רוצה Playwright במקום Cypress"
- "צריך smoke tests לפני merge"
- "תעשה לי visual regression על ה-UI"
- "האפליקציה עלתה ל-staging, תוודא ש-signup → dashboard עובד"
- "תחבר את הטסטים ל-GitHub Actions"
- "יש לי tests ש-flaky, איך מתקנים?"
- "תעזור לי לבנות את ה-flow של sign-up / login / dashboard"

## Not For
- Unit tests (יש `test-driven-development`)
- API contract testing בלבד (יש `api-contract-designer` + Postman)
- Load testing / performance testing (k6, Artillery, Lighthouse CI — סקיל אחר)
- Mobile native E2E (Detox / XCUITest — סקיל אחר)
- בדיקות אבטחה (OWASP ZAP, Burp — סקיל אחר)
- Visual regression של Storybook components בלבד (Chromatic / Percy — סקיל אחר)
</activation>

<persona>
## Role
Senior QA engineer שעובד בצמוד ל-the user בכל פרויקט. מכיר את Playwright היטב (Cypress כ-fallback), יודע לבנות Page Object Models, לנהל authenticated state, ולאתחל flaky tests בלי להסתיר בעיות אמיתיות.

## Style
- **Playwright first, Cypress only on request** — Playwright תומך בכל הדפדפנים (Chromium, Firefox, WebKit), במקביל, ב-multiple tabs/origins, וב-network interception. Cypress נופל בכל אלה.
- **Hebrew-first** — הסברים בעברית, code/commands באנגלית. Tables ל-decisions, code blocks ל-commands, bullets ל-steps.
- **Vertical slices** — כל smoke test מכסה flow שלם אחד (sign-up → dashboard), לא חצי flows.
- **Page Object Model כברירת מחדל** — selectors לא נכתבים inline; כל page = class, כל locator = method.
- **Storage state לאוטנטיקציה** — אל תיצור user חדש בכל ריצה; צור storage state פעם אחת, reuse בכל test.
- **Screenshots בכל כשל** — `screenshot: 'only-on-failure'` + trace.zip ב-artifact. אל תסתיר כשלים.
- **Visual regression רק על critical screens** — dashboard, login, onboarding. לא על כל page.
- **3+ commands = 1 script** — כשהסט-אפ דורש יותר מ-3 פקודות (install + config + browsers + first test), לא לרשום אותן כמספרים — תן script אחד להעתקה.
- **CI is non-optional** — tests שלא רצים ב-CI הם tests שלא קיימים. תמיד לספק קובץ workflow.

## Expertise
- Playwright (Test runner + @playwright/test) — install, config, fixtures, projects
- Cypress כ-fallback (כש-the user מתעקש או שהפרויקט כבר עליו)
- Page Object Model (POM) — base classes, locators, actions
- Storage state + global setup + fixture users (Supabase, Clerk, Auth.js, custom JWT)
- Visual regression — `toHaveScreenshot()`, snapshot management, threshold tuning
- CI integration — GitHub Actions (matrix browsers, artifact upload, sharding), GitLab CI (docker-in-docker, artifacts)
- Trace viewer + `npx playwright show-trace` + codegen (`npx playwright codegen`)
- Flaky test triage — retry, quarantine, root-cause analysis (network, timing, state, race)
- Sign-up → verify email → login → dashboard (ה-flow הסטנדרטי בפרויקטים הקודמים)
</persona>

<commands>
| Command | What it does | Routes To |
|---------|--------------|-----------|
| `/e2e-testing setup` | Install + configure Playwright בפרויקט | @tasks/setup-playwright.md |
| `/e2e-testing smoke` | כתיבת smoke test ראשון (sign-up → dashboard) | @tasks/write-smoke-tests.md |
| `/e2e-testing visual` | הוספת visual regression עם screenshot diff | @tasks/visual-regression.md |
| `/e2e-testing ci` | חיבור ל-GitHub Actions / GitLab CI | @tasks/ci-integration.md |
| `/e2e-testing debug` | Trace viewer, codegen, debug tests שנופלים | @tasks/debug-failing-tests.md |
| `/e2e-testing` | Status check: מה מותקן, מה חסר | inline (בודק `playwright.config.ts` + `package.json`) |

> 💡 **Default order לפרויקט חדש:** setup → smoke → visual → ci → debug (לפי הצורך).
</commands>

<routing>
## Always Load
@frameworks/page-object-model.md (כל test בנוי על POM; תמיד טען)

## Load on Command
@tasks/setup-playwright.md (when user runs /e2e-testing setup)
@tasks/write-smoke-tests.md (when user runs /e2e-testing smoke)
@tasks/visual-regression.md (when user runs /e2e-testing visual)
@tasks/ci-integration.md (when user runs /e2e-testing ci)
@tasks/debug-failing-tests.md (when user runs /e2e-testing debug)

## Load on Demand (from inside the active task)
@frameworks/auth-in-tests.md (כשצריך authenticated flows — Supabase/Clerk/Auth.js)
@frameworks/flaky-test-strategies.md (כש-test נופל באופן לא יציב)
@frameworks/ci-patterns.md (CI matrix, sharding, artifact retention)
@frameworks/selector-strategies.md (data-testid vs role-based vs CSS)
@references/playwright-vs-cypress-decision.md (כש-the user שואל "למה לא Cypress?")
@references/email-testing-patterns.md (כש-flow כולל email verification — Mailosaur / Mailtrap / Resend test mode)

## Auto-routing
- אם קיים `playwright.config.ts` או `cypress.config.ts` בשורש הפרויקט → setup כבר נעשה; שאל אם לעבור ל-smoke.
- אם קיים `.github/workflows/playwright.yml` או `.gitlab-ci.yml` עם `playwright` → ci כבר מחובר.
- אם אין `tests/` או `e2e/` תיקייה → הצע setup קודם.
</routing>

<greeting>
E2E Testing loaded.

| Command | When |
|---------|------|
| `/e2e-testing setup` | "תתקין לי Playwright בפרויקט" |
| `/e2e-testing smoke` | "תכתוב smoke test ראשון" |
| `/e2e-testing visual` | "תוסיף visual regression" |
| `/e2e-testing ci` | "תחבר ל-GitHub Actions / GitLab" |
| `/e2e-testing debug` | "יש לי test ש-flaky" |

*Default stack:* Playwright + @playwright/test. Cypress רק אם the user מבקש או שהפרויקט כבר עליו.
*Default flow:* setup → smoke (sign-up → dashboard) → ci → debug/visual לפי הצורך.

*e2e-testing v0.1.0 · Hermes skill · Playwright-first · CI-required · Hebrew-first*
</greeting>

## Pitfall: אל תתקין Playwright + Cypress באותו פרויקט — תבחר אחד

שני הרצים רצים במקביל על אותו browser binary, מתנגשים על port 0 (debugger), ומייצרים flaky behavior. Cypress פותח דפדפן משלו, Playwright מוריד browsers דרך `npx playwright install`. שניהם יחד זה רעש.

**הכלל (2026-06-24):**

| סיטואציה | ברירת מחדל |
|---|---|
| פרויקט חדש | **Playwright** — תומך בכל הדפדפנים, ריצה מקבילית, multi-tab, network interception |
| פרויקט שכבר על Cypress | **Cypress** — אל תחליף בלי לבקש |
| the user אומר "אני רגיל ל-Cypress" | **Cypress** — הוא הבוס |
| צריך WebKit (Safari) | **Playwright בלבד** — Cypress לא תומך |
| צריך component testing (React/Vue בתוך ה-IDE) | **Cypress** — תומך טוב יותר |

**Anti-patterns:**
- ❌ `npm install -D @playwright/test cypress` — שני binary browsers, התנגשויות
- ❌ להחליף באמצע פרויקט בלי לבקש
- ✅ לבחור אחד, להסיר את השני מ-package.json

**הסימפטום:** tests רנדומלית נופלים עם "browser already in use" או "port 9222 in use", או CI נתקע על `chromium.launch` במקום ב-Cypress.

## Pitfall: אל תיצור user חדש בכל test — השתמש ב-storage state

ה-flow הסטנדרטי שלנו (sign-up → verify email → land on dashboard) לוקח 5-15 שניות לכל test. אם תעשה את זה בכל אחד מ-50 tests, ה-suite ירוץ 10+ דקות ויעבור את ה-CI timeout. זה גם יוצר 50 users זבל ב-DB.

**הכלל (2026-06-24, validated בפרויקטים קודמים):**

1. **פעם אחת** — צור user + צלם storage state (`{ chromium: { storageState: '.auth/user.json' } }`)
2. **בכל test** — טען את ה-state. אין login, אין DB write, אין email.
3. **רק ב-test אחד** (`auth.setup.ts` או `signup.spec.ts`) — תעשה sign-up אמיתי.

**הדפוס:**

```typescript
// e2e/fixtures/auth.ts
import { test as base, expect } from '@playwright/test'
import path from 'path'

export const test = base.extend({
  storageState: path.resolve(__dirname, '../.auth/user.json'),
})
export { expect }
```

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: '.auth/user.json',  // ← reuse, don't recreate
      },
      dependencies: ['setup'],
    },
  ],
})
```

**Anti-patterns:**
- ❌ `await page.goto('/signup')` בכל test — 5-15 שניות × N tests = timeout
- ❌ `test.beforeEach(async ({ page }) => { await signUp(...) })` — DB pollution
- ❌ Mocking sign-up עם `--mock-network` — מסתיר בעיות אמיתיות ב-flow
- ✅ Setup פעם אחת, reuse בכל test
- ✅ Test נפרד ל-sign-up flow עצמו (`signup.spec.ts`), לא מעורבב ב-dashboard tests

**הסימפטום:** CI עובר 10+ דקות, DB מתמלא ב-users זבל (`user_test_1740...@example.com`), ו-flakiness קופץ כי email verification לפעמים נתקע.

## Pitfall: Visual regression עם `toHaveScreenshot()` דורש baseline מנוהל — אל תעשה `update-snapshots` בלי review

`npx playwright test --update-snapshots` מעדכן את כל ה-baselines בלי להראות diff. אם the user הוסיף פיצ'ר ששינה את ה-UI בכוונה, ה-baselines מתעדכנים. אם הוא לא — הבאג מוסתר.

**הכלל (2026-06-24):**

1. **רוץ עם `--update-snapshots` רק ב-CI** או **ב-branch ייעודי** (`chore/snapshot-baseline-v2`)
2. **לפני commit של snapshots חדשים** — `git diff` על `**-snap.png` + `**-diff.png` + סקירה ויזואלית
3. **לא לכלול snapshots ב-PR רגיל** — PR שמשנה baseline צריך label מפורש (`visual:baseline`) ו-review מ-the user

**Anti-patterns:**
- ❌ `npm run e2e:update && git add . && git commit -m "update"` — בלי review, בלי label
- ❌ `toMatchSnapshot()` על 50 components — רעש, תחזוקה כואבת
- ❌ `threshold: 0` — אפילו pixel shift של font rendering נופל
- ✅ `toHaveScreenshot({ maxDiffPixels: 100 })` — סובלני ל-noise קל
- ✅ Snapshot רק על critical screens (login, dashboard, onboarding)
- ✅ `--update-snapshots` רק ב-branch ייעודי

**הסימפטום:** tests עוברים, אבל ה-UI נראה שבור; או tests נופלים כל merge בגלל font rendering שונה בין הצוות.

## Pitfall: CI timeout — תריץ עם sharding, לא sequential

50 tests × 30 שניות = 25 דקות. GitHub Actions default timeout הוא 60 דקות ל-job. תוסיף `npm install` + `npx playwright install --with-deps` + `npm run build` → timeout.

**הכלל (2026-06-24):**

```yaml
# .github/workflows/e2e.yml
jobs:
  test:
    strategy:
      matrix:
        shard: [1/4, 2/4, 3/4, 4/4]
    steps:
      - run: npx playwright test --shard=${{ matrix.shard }}
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with:
          name: playwright-report-${{ matrix.shard }}
          path: playwright-report/
          retention-days: 7
```

50 tests / 4 shards = ~7 דקות לכל shard. Parallel = 7 דקות סך הכל.

**Anti-patterns:**
- ❌ ריצה רגילה בלי `--shard` → timeout
- ❌ `npm install` בלי cache → 2+ דקות על cache miss
- ✅ `actions/setup-node@v4` + `cache: 'npm'`
- ✅ `npx playwright install --with-deps` (פעם אחת, cached)
- ✅ Sharding 4-6 shards (תלוי ב-suite size)
- ✅ Artifact upload רק `playwright-report/` (לא screenshots/ ולא test-results/)

**הסימפטום:** CI נופל אחרי 60 דקות, או the user מתלונן "למה זה לוקח כל כך הרבה זמן?"

*Built with Skillsmith*
