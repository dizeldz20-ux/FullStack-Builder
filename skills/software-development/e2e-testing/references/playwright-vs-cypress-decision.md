# Playwright vs Cypress — Decision Guide

## TL;DR

**ב-95% מהמקרים → Playwright.** Cypress הוא רק fallback אם יש סיבה טכנית קונקרטית. הסקיל הזה מועדף Playwright (`@playwright/test`), ו-Cypress רק כשממש חייבים.

---

## השוואה מהירה

| קריטריון | Playwright | Cypress |
|---|---|---|
| **Browsers** | Chromium, Firefox, WebKit (3 engines אמיתיים) | Chromium-based (Firefox בהרחבה, WebKit חסר) |
| **שפות** | TypeScript, JavaScript, Python, Java, .NET | JavaScript / TypeScript בלבד |
| **ריצה ב-CI** | מצוין — auto-wait, sharding, matrix | טוב — אבל איטי יותר על suites גדולים |
| **Parallel by default** | ✅ built-in sharding (`--shard`) | ❌ דורש Cypress Cloud (בתשלום) |
| **Multi-tab / iframe** | ✅ native | ❌ חסר |
| **Network mocking** | ✅ `page.route()` מובנה | ⚠️ `cy.intercept()` עובד, פחות granular |
| **Trace viewer** | ✅ built-in (time-travel debug) | ⚠️ Dashboard בלבד |
| **Visual regression** | ✅ `toHaveScreenshot()` מובנה | ⚠️ plugin חיצוני |
| **Authentication reuse** | ✅ `storageState` (מומלץ ב-frameworks/auth-in-tests.md) | ⚠️ דורש plugin |
| **Mobile emulation** | ✅ device descriptors מובנים | ⚠️ דרך viewport בלבד |
| **API testing** | ✅ `request` fixture מובנה | ✅ `cy.request()` |
| **Component testing** | ✅ מובנה | ✅ מובנה |
| **מחיר** | חינם, קוד פתוח | חינם (Community) / בתשלום (Cloud + parallelization) |
| **Sponsor** | Microsoft | Cypress.io (VC-backed) |
| **Roadmap velocity** | מהיר מאוד — releases חודשיים | איטי יותר מאז 2023 |

---

## הכלל שלנו

```
1. פרויקט חדש → Playwright (default)
2. פרויקט קיים עם Cypress + מתחזק → השאר (אל תעבור בלי סיבה)
3. מעבר Cypress → Playwright → רק אם:
   a. צריך WebKit/Safari testing (Cypress לא תומך)
   b. צריך parallel CI בלי לשלם ל-Cypress Cloud
   c. צריך multi-tab / iframe / multi-origin
   d. הצוות כותב ב-Python/Java ולא רוצה להחזיק JS test stack
```

---

## מתי Cypress כן מנצח (נדיר, אבל קיים)

### 1. Frontend-heavy team עם zero DevOps appetite
Cypress Test Runner הוא UI מלא — אפשר לראות כל step, time-travel, pause. אם הצוות הוא designers / junior devs שלא מסתדרים עם CLI / traces, Cypress נותן lower floor.

### 2. Legacy project שכבר עובד
מעבר Cypress → Playwright = 2-5 ימים של refactoring POM, fixtures, hooks, CI pipeline. אם הפרויקט יציב ואין trigger עסקי — אל תעבור.

### 3. Component testing בלבד (לא E2E)
Cypress component testing עובד טוב עם React/Vue ו-mounts מהירים. Playwright CT עובד גם כן, אבל Cypress היה שם קודם ויש לו קהילה גדולה יותר של recipes ל-React.

### 4. Plugin ecosystem קריטי
למשל: Cypress accessibility plugin (`cypress-axe`) בוגר יותר מ-Playwright `@axe-core/playwright`. אם יש לך dep על plugin ספצי שלא קיים ב-Playwright — זה סיבה להישאר.

---

## מתי Playwright מנצח (כמעט תמיד)

### 1. WebKit / Safari coverage
זה ה-reason #1. **Cypress לא תומך ב-WebKit native.** רק Chromium + Firefox (דרך extension, לא engine אמיתי). אם האפליקציה שלך רצה ב-Safari (ולכל iOS user יש Safari), חייב Playwright.

```typescript
// playwright.config.ts
projects: [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
  { name: 'webkit', use: { ...devices['Desktop Safari'] } }, // ← Cypress can't
]
```

### 2. Parallel CI בלי לשלם
```bash
# Playwright — free, built-in
npx playwright test --shard=1/4
npx playwright test --shard=2/4
# ... 4 shards in parallel → 50 tests in 7 דקות
```

```bash
# Cypress — דורש Dashboard plan ($) למשהו שווה ערך
cypress run --record --key=$CYPRESS_RECORD_KEY --parallel --ci-build-id=$CI_BUILD_ID
```

על פרויקט בן 50-200 tests, זה ההבדל בין **0$** ל-**$300+/חודש**.

### 3. Multi-tab, multi-origin, iframe
```typescript
// Playwright — native
const popup = await page.waitForEvent('popup')
await popup.locator('button').click()

// Cypress — לא נתמך. חייב לפתוח URL ישירות, לא דרך window.open
```

### 4. Network mocking מתקדם
```typescript
// Playwright
await page.route('**/api/checkout', async route => {
  await route.fulfill({
    status: 500,
    body: JSON.stringify({ error: 'Forced failure for test' })
  })
})

// Cypress
cy.intercept('POST', '/api/checkout', { statusCode: 500, body: { error: 'Forced failure' } })
// עובד, אבל Playwright נותן יותר שליטה (route.continue עם req modification)
```

### 5. Trace viewer + video
Playwright שומר trace שלם (DOM snapshots + network + actions) לכל test, ואפשר לפתוח אותו בדפדפן עם time-travel debug. Cypress נותן video + screenshots, אבל לא את אותו level של granularity.

```bash
npx playwright show-trace test-results/.../trace.zip
```

---

## Migration Checklist (Cypress → Playwright)

רק אם החלטת לעבור. **אל תעבור בלי trigger עסקי ברור.**

### שלב 1: Setup חדש במקביל
```bash
npm install -D @playwright/test
npx playwright install --with-deps
```

אל תמחק את Cypress עדיין. תן ל-POMs לחיות ב-`e2e/` (Playwright) ו-`cypress/` (Cypress) במקביל.

### שלב 2: תרגם POMs
Cypress POM הוא בערך object literal. Playwright POM הוא class.

```javascript
// Cypress
class SignupPage {
  visit() { cy.visit('/signup') }
  fillEmail(e) { cy.get('input[name="email"]').type(e) }
}

// Playwright
class SignupPage {
  constructor(page) { this.page = page }
  async goto() { await this.page.goto('/signup') }
  async fillEmail(e) { await this.page.locator('input[name="email"]').fill(e) }
}
```

### שלב 3: החלף fixtures / commands
| Cypress | Playwright |
|---|---|
| `cy.request('POST', '/api/login', {...})` | `await request.post('/api/login', { data: {...} })` |
| `cy.getCookie('session')` | `await context.cookies()` |
| `cy.fixture('user.json')` | `import user from './fixtures/user.json'` |
| Custom commands (`Cypress.Commands.add`) | Test fixtures + helpers |

### שלב 4: CI
החלף `cypress-io/github-action` ב-`@playwright/test` + sharding. ראה `@tasks/ci-integration.md`.

### שלב 5: מחיקת Cypress
רק אחרי שכל test עבר ל-Playwright ו-suite ירוק לפחות שבוע ב-CI. **לא לפני.**

---

## Anti-patterns

- ❌ "Cypress יותר קל למתחילים" → נכון ל-3 ימים. אחרי זה Playwright משתלם.
- ❌ "Cypress יותר יציב" → לא נכון. לשניהם יש flakes, לשניהם יש פתרונות.
- ❌ "נשתמש בשניהם" → dual stack = פי 2 תחזוקה, פי 2 onboarding, רק תסכול.
- ❌ "Cypress Cloud שווה את הכסף" → עבור CI של 50+ tests, השדרוג ל-Playwright + sharding מחזיר את עצמו תוך חודש.
- ✅ "יש לנו trigger עסקי ברור (WebKit / parallel / cost)" → עבור.

---

## Related

- `@tasks/setup-playwright.md` — איך מתקינים Playwright מאפס
- `@frameworks/page-object-model.md` — POM pattern שעובד בשניהם
- `@frameworks/auth-in-tests.md` — storage state pattern (Playwright native)
- `@frameworks/flaky-test-strategies.md` — מתי כל פריימוורק flake

*Built with Skillsmith*