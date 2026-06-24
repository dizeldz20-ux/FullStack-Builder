<purpose>
להתקין ולהגדיר Playwright (`@playwright/test`) בפרויקט Node/TypeScript או Python, להוריד את שלושת ה-browsers (Chromium, Firefox, WebKit), ולוודא ש-test ראשון עובר. כולל `playwright.config.ts` עם baseURL, projects, ו-storage state, ותיקיות סטנדרטיות (`tests/`, `e2e/`, `playwright-report/`).
</purpose>

<user-story>
As a the user שמתחיל פרויקט, אני רוצה Playwright מותקן ומוכן לכתיבת smoke tests תוך 5 דקות, so that אני יכול להתמקד ב-flow העסקי ולא בתשתית.
</user-story>

<when-to-use>
- User מבקש "תתקין Playwright בפרויקט"
- פרויקט חדש שצריך E2E coverage
- מעבר מ-Cypress ל-Playwright (רק אם אושר)
- הוספת E2E layer לפרויקט קיים עם unit tests אבל בלי E2E
- Entry point routes here via `/e2e-testing setup`
</when-to-use>

<context>
@frameworks/selector-strategies.md (כשמתחילים לכתוב selectors)
</context>

<references>
@frameworks/page-object-model.md (POM pattern — טען לפני כתיבת test ראשון)
@frameworks/auth-in-tests.md (כשיש authenticated pages)
@references/playwright-vs-cypress-decision.md (אם the user שואל "למה לא Cypress?")
</references>

<steps>

<step name="verify_prerequisites" priority="first">
לפני התקנה, בדוק:

1. **Node 18+** (Playwright דורש 18+):
   ```bash
   node --version
   # Must be >= 18.0.0
   ```

2. **TypeScript** (או flow מקביל ב-JS):
   ```bash
   cat package.json | jq '.devDependencies.typescript'
   ```

3. **האם Cypress כבר מותקן?** (אם כן — אל תוסיף Playwright, ראה Pitfall ב-SKILL.md):
   ```bash
   grep -E '"cypress"' package.json
   ```

4. **האם `playwright.config.ts` כבר קיים?**
   ```bash
   ls -la playwright.config.ts playwright.config.js cypress.config.ts 2>/dev/null
   ```

אם אחד מהתנאים נופל — **עצור וספר ל-the user**. אל תתקין Playwright על פרויקט עם Cypress, או על Node < 18.
</step>

<step name="install_dependencies">
התקן את החבילה הרשמית + browsers:

```bash
npm install -D @playwright/test
npx playwright install --with-deps chromium firefox webkit
```

**הסבר `--with-deps`** — מתקין system dependencies נדרשים (libsdl, libnss, וכו'). בלי זה ה-browsers ייפלו בריצה על אובונטו/דביאן.

**הסבר שלושת ה-browsers** — Chromium לרוב הבדיקות, Firefox לבדיקת cross-browser, WebKit ל-Safari (macOS/iOS users).

**אם `chromium בלבד`** (CI חסכוני):
```bash
npx playwright install --with-deps chromium
```

**Python (pytest-playwright):**
```bash
pip install pytest-playwright
playwright install --with-deps chromium firefox webkit
```

המתן לסיום. ההתקנה לוקחת 1-3 דקות.
</step>

<step name="create_config">
צור `playwright.config.ts` בשורש הפרויקט:

```typescript
import { defineConfig, devices } from '@playwright/test'

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:3000'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { open: 'never' }],
    ['list'],
  ],
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],
  webServer: process.env.BASE_URL ? undefined : {
    command: 'npm run dev',
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
})
```

**הסבר ההגדרות החשובות:**

| Setting | Value | למה |
|---|---|---|
| `testDir` | `./e2e` | תיקייה נפרדת מ-unit tests |
| `retries` | `CI ? 2 : 0` | local ללא retries (רוצים לראות fail), CI עם 2 (network noise) |
| `workers` | `CI ? 1 : undefined` | CI sequential (יציב), local parallel |
| `baseURL` | env או `localhost:3000` | מאפשר `await page.goto('/dashboard')` במקום URL מלא |
| `webServer` | `npm run dev` | מריץ את האפליקציה אוטומטית (local) |
| `screenshot` | `'only-on-failure'` | רק בכשל — חוסך disk |
| `video` | `'retain-on-failure'` | רק בכשל — חוסך disk |
| `trace` | `'on-first-retry'` | trace.zip רק אם יש retry — חיוני ל-CI debug |

**אם ה-baseURL הוא staging** (לא local):
```bash
BASE_URL=https://staging.example.com npx playwright test
```
</step>

<step name="create_directory_structure">
צור את התיקיות הסטנדרטיות:

```bash
mkdir -p e2e/{pages,fixtures,utils}
mkdir -p .auth
mkdir -p playwright-report
echo ".auth/" >> .gitignore
echo "playwright-report/" >> .gitignore
echo "test-results/" >> .gitignore
echo "blob-report/" >> .gitignore
```

**המבנה:**

```
e2e/
├── pages/              # Page Object Models (POM)
├── fixtures/           # custom test fixtures (auth, db, etc.)
├── utils/              # helper functions
├── *.spec.ts           # test files
└── .auth/              # storage state (gitignored)
playwright-report/      # HTML report (gitignored)
test-results/           # failure artifacts (gitignored)
```

ראה `@frameworks/page-object-model.md` לפירוט על מבנה ה-pages/ תיקייה.
</step>

<step name="add_npm_scripts">
הוסף ל-`package.json` את ה-scripts:

```json
{
  "scripts": {
    "e2e": "playwright test",
    "e2e:headed": "playwright test --headed",
    "e2e:ui": "playwright test --ui",
    "e2e:debug": "playwright test --debug",
    "e2e:chromium": "playwright test --project=chromium",
    "e2e:update-snapshots": "playwright test --update-snapshots",
    "e2e:report": "playwright show-report",
    "e2e:trace": "playwright show-trace",
    "e2e:codegen": "playwright codegen"
  }
}
```

**מה כל script עושה:**

| Script | מה |
|---|---|
| `e2e` | ריצה רגילה (headless, parallel) |
| `e2e:headed` | ריצה עם browser גלוי — לדיבאג |
| `e2e:ui` | Playwright UI mode — time-travel, watch |
| `e2e:debug` | step-by-step debugger |
| `e2e:chromium` | רק Chromium (מהיר יותר) |
| `e2e:update-snapshots` | לעדכן baselines (רק ב-branch ייעודי) |
| `e2e:report` | פתח HTML report |
| `e2e:trace` | פתח trace viewer על `test-results/.../trace.zip` |
| `e2e:codegen` | צור selectors אוטומטית מהדפדפן |
</step>

<step name="smoke_test">
ודא שהכל עובד עם smoke test ראשון. צור `e2e/smoke.spec.ts`:

```typescript
import { test, expect } from '@playwright/test'

test('homepage loads and shows title', async ({ page }) => {
  await page.goto('/')

  // Adjust this to match your app
  await expect(page).toHaveTitle(/Your App/i)

  // Smoke passes if we got here without an exception
  expect(true).toBe(true)
})
```

**הרץ:**
```bash
npm run e2e:chromium
```

**הצלחה** — output דומה ל:
```
Running 1 test using 1 worker
  1 passed (2.3s)
```

**כישלון** — `playwright-report/` נוצר עם screenshots + trace. הרץ `npm run e2e:report` או `npm run e2e:trace`.

**אם ה-app לא רץ** — `webServer` אמור להריץ `npm run dev` אוטומטית. אם לא, ודא ש-`npm run dev` עובד ידנית.
</step>

<step name="verify_reporting">
ודא ש-reporting עובד:

```bash
npm run e2e:report
```

זה פותח את `playwright-report/index.html` בדפדפן. אם הוא ריק — ודא ש-test אכן רץ (לא נכשל ב-webServer).

**בדוק שכל ה-artifacts נוצרים:**

| Artifact | מתי | איפה |
|---|---|---|
| `playwright-report/` | תמיד | שורש הפרויקט |
| `test-results/*/trace.zip` | on-retry | תיקיית test-results |
| `test-results/*/video.webm` | on-failure | תיקיית test-results |
| `test-results/*/screenshot.png` | on-failure | תיקיית test-results |

הארבעה חיוניים ל-CI. ראה `@tasks/ci-integration.md`.
</step>

</steps>

<output>
## Artifacts
- `playwright.config.ts` — קונפיג מלא (3 projects, baseURL, webServer)
- `e2e/` — תיקייה עם smoke test + pages/fixtures/utils stubs
- `.auth/` — תיקיית storage state (gitignored)
- `playwright-report/`, `test-results/` — output (gitignored)
- `package.json` scripts: `e2e`, `e2e:headed`, `e2e:ui`, `e2e:debug`, `e2e:chromium`, `e2e:update-snapshots`, `e2e:report`, `e2e:trace`, `e2e:codegen`

## Verification
```bash
# 1. Check files exist
ls -la playwright.config.ts
ls e2e/smoke.spec.ts

# 2. Run smoke test
npm run e2e:chromium
# Expected: 1 passed (2-5s)

# 3. Check report
npm run e2e:report
# Expected: HTML report opens with 1 passing test
```
</output>

<acceptance-criteria>
- [ ] `@playwright/test` מותקן ב-`devDependencies`
- [ ] `npx playwright --version` מחזיר גרסה (1.40+)
- [ ] שלושת ה-browsers הורדו (`ls ~/.cache/ms-playwright/` מכיל chromium/firefox/webkit)
- [ ] `playwright.config.ts` קיים עם 3 projects (chromium/firefox/webkit)
- [ ] `e2e/smoke.spec.ts` עובר ב-`npm run e2e:chromium`
- [ ] `playwright-report/` נוצר אחרי ריצה
- [ ] `.auth/`, `playwright-report/`, `test-results/`, `blob-report/` ב-`.gitignore`
- [ ] `package.json` כולל 9 e2e:* scripts
- [ ] Cypress לא קיים ב-`package.json` (או הוסר אם היה)
</acceptance-criteria>

*Built with Skillsmith*
