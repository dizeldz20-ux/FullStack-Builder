# Page Object Model (POM) for Playwright

## What & Why

**Page Object Model** = design pattern שבו כל page באפליקציה היא class, וכל selector הוא property של ה-class. ה-test עצמו קורא actions מ-POM, לא כותב selectors inline.

**למה זה חשוב:**

| בלי POM | עם POM |
|---|---|
| `await page.locator('input[name="email"]').fill('a@b.com')` ב-20 tests | `await signup.fillEmail('a@b.com')` ב-20 tests |
| שינוי HTML → לערוך 20 tests | שינוי HTML → לערוך POM אחד |
| selectors חוזרים → drift | single source of truth |
| test קשה לקריאה | test = business flow |

**Anti-pattern (שראיתי הרבה):**

```typescript
// ❌ selectors inline ב-test
test('user signs up', async ({ page }) => {
  await page.goto('/signup')
  await page.locator('input[name="email"]').fill('a@b.com')
  await page.locator('input[type="password"]').fill('xxx')
  await page.getByRole('button', { name: /sign up/i }).click()
  await expect(page).toHaveURL('/dashboard')
  await expect(page.locator('h1')).toContainText('Welcome')
})
```

**עם POM:**

```typescript
// ✅ test = business flow
test('user signs up', async ({ page }) => {
  const signup = new SignupPage(page)
  await signup.goto()
  await signup.signUp('a@b.com', 'xxx', 'Alice')

  const dashboard = new DashboardPage(page)
  await dashboard.expectLoaded()
})
```

---

## Core Structure

### תיקייה סטנדרטית

```
e2e/
├── pages/
│   ├── base.page.ts          # common functionality
│   ├── signup.page.ts
│   ├── login.page.ts
│   ├── dashboard.page.ts
│   ├── settings.page.ts
│   └── checkout.page.ts
├── fixtures/
│   └── auth.fixture.ts
└── *.spec.ts
```

**קובץ אחד לכל page.** לא POM ענק עם 30 pages, לא POM מפוצל לפי component (input, button — מטורף).

### Base Page (אופציונלי אבל מומלץ)

```typescript
// e2e/pages/base.page.ts
import { type Page, type Locator } from '@playwright/test'

export abstract class BasePage {
  readonly page: Page
  abstract readonly path: string  // כל page מגדיר path

  constructor(page: Page) {
    this.page = page
  }

  async goto() {
    await this.page.goto(this.path)
  }

  async waitForLoaded() {
    await this.page.waitForLoadState('networkidle')
  }

  async getTitle(): Promise<string> {
    return await this.page.title()
  }

  async getCurrentUrl(): Promise<string> {
    return this.page.url()
  }
}
```

**למה abstract:** כל page חייב להגדיר `path` — שכחת = compile error (TypeScript).

### דוגמה מלאה — SignupPage

```typescript
// e2e/pages/signup.page.ts
import { type Page, type Locator, expect } from '@playwright/test'
import { BasePage } from './base.page'

export class SignupPage extends BasePage {
  readonly path = '/signup'

  // Locators — public readonly
  readonly emailInput: Locator
  readonly passwordInput: Locator
  readonly nameInput: Locator
  readonly submitButton: Locator
  readonly errorMessage: Locator
  readonly termsCheckbox: Locator

  constructor(page: Page) {
    super(page)
    this.emailInput = page.getByLabel('Email')
    this.passwordInput = page.getByLabel('Password')
    this.nameInput = page.getByLabel('Full name')
    this.submitButton = page.getByRole('button', { name: /sign up|create account/i })
    this.errorMessage = page.getByRole('alert')
    this.termsCheckbox = page.getByLabel(/i agree to/i)
  }

  // High-level actions — what a user does
  async signUp(email: string, password: string, name: string) {
    await this.emailInput.fill(email)
    await this.passwordInput.fill(password)
    await this.nameInput.fill(name)
    await this.termsCheckbox.check()
    await this.submitButton.click()
  }

  // Composed actions — multi-step
  async signUpAndExpectError(
    email: string,
    password: string,
    name: string,
    expectedError: string | RegExp
  ) {
    await this.signUp(email, password, name)
    await expect(this.errorMessage).toContainText(expectedError)
  }
}
```

### דוגמה — DashboardPage

```typescript
// e2e/pages/dashboard.page.ts
import { type Page, type Locator, expect } from '@playwright/test'
import { BasePage } from './base.page'

export class DashboardPage extends BasePage {
  readonly path = '/dashboard'

  readonly welcomeHeading: Locator
  readonly userMenu: Locator
  readonly logoutButton: Locator
  readonly itemsList: Locator
  readonly createItemButton: Locator

  constructor(page: Page) {
    super(page)
    this.welcomeHeading = page.getByRole('heading', { name: /welcome|dashboard/i })
    this.userMenu = page.getByTestId('user-menu')
    this.logoutButton = page.getByRole('button', { name: /log out|sign out/i })
    this.itemsList = page.getByTestId('items-list')
    this.createItemButton = page.getByRole('button', { name: /create|new item|add/i })
  }

  async expectLoaded() {
    await expect(this.welcomeHeading).toBeVisible()
  }

  async logout() {
    await this.userMenu.click()
    await this.logoutButton.click()
  }

  async getItemCount(): Promise<number> {
    return await this.itemsList.getByRole('listitem').count()
  }
}
```

---

## Locator Strategies (Cheat Sheet)

**לפי סדר עדיפות (Playwright ממליץ):**

| # | Strategy | דוגמה | מתי להשתמש |
|---|---|---|---|
| 1 | `getByRole` | `getByRole('button', { name: 'Submit' })` | תמיד עדיף — accessible |
| 2 | `getByLabel` | `getByLabel('Email')` | form fields |
| 3 | `getByPlaceholder` | `getByPlaceholder('Search...')` | search bars |
| 4 | `getByText` | `getByText('Welcome back')` | static text |
| 5 | `getByTestId` | `getByTestId('user-menu')` | when semantic isn't enough |
| 6 | CSS / XPath | `page.locator('.btn-primary')` | ❌ last resort |

**`getByRole` מנצח כי:**
- ✅ accessible (screen readers עובדים)
- ✅ robust לשינויי CSS
- ✅ מתעד intention (button, link, heading — לא div)

**למה לא CSS:**

```typescript
// ❌ שביר
page.locator('div.container > form > div:nth-child(2) > input')

// ✅ יציב
page.getByLabel('Email')
```

**מתי כן `data-testid`:**

```html
<!-- אם אין semantic role/label -->
<div data-testid="user-menu">...</div>
```

```typescript
page.getByTestId('user-menu')
```

**זה הסטנדרט שלנו:**
- ✅ `data-testid` על elements בלי role/label ייחודי
- ❌ `data-testid` על כל element — זה עצלנות
- ❌ `id="..."` בלי data-testid — id משתנה לפי framework

---

## Composition Patterns

### Page-to-Page Navigation

```typescript
// ✅ Navigation מ-POM
async clickSignupLink(): Promise<SignupPage> {
  await this.signupLink.click()
  await this.page.waitForURL('/signup')
  return new SignupPage(this.page)
}

// ב-test
const login = new LoginPage(page)
const signup = await login.clickSignupLink()  // ← typed return
await signup.signUp(...)
```

**Anti-pattern:** לחזור ל-test כדי לבדוק URL, או ליצור POM חדש ב-test.

### Shared Components

```typescript
// e2e/components/navigation.component.ts
import { type Page, type Locator } from '@playwright/test'

export class Navigation {
  readonly page: Page
  readonly logo: Locator
  readonly dashboardLink: Locator
  readonly settingsLink: Locator
  readonly logoutButton: Locator

  constructor(page: Page) {
    this.page = page
    this.logo = page.getByTestId('logo')
    this.dashboardLink = page.getByRole('link', { name: 'Dashboard' })
    this.settingsLink = page.getByRole('link', { name: 'Settings' })
    this.logoutButton = page.getByRole('button', { name: 'Logout' })
  }
}
```

```typescript
// e2e/pages/dashboard.page.ts
import { Navigation } from '../components/navigation.component'

export class DashboardPage extends BasePage {
  readonly navigation: Navigation

  constructor(page: Page) {
    super(page)
    this.navigation = new Navigation(page)
  }
}
```

---

## Anti-Patterns

### ❌ Locator inline ב-test
```typescript
await page.locator('input[name="email"]').fill('a@b.com')  // ❌
```

### ❌ POM עם selectors חיצוניים
```typescript
export class SignupPage {
  static EMAIL = 'input[name="email"]'  // ❌ זה CSS selector, לא POM
}
```

### ❌ POM עם assertions
```typescript
// POM צריך actions, לא assertions על העולם החיצון
async signUp(...) {
  await this.fillForm(...)
  await expect(this.page).toHaveURL('/dashboard')  // ❌ זה ל-POM של ה-dashboard
}
```

### ❌ One POM per test file
```typescript
// signup.spec.ts מכיל POM של signup בתוך ה-spec — זה לא POM, זה helper
// → תעביר ל- e2e/pages/signup.page.ts
```

### ❌ Magic strings ב-test
```typescript
await page.getByRole('button', { name: 'Sign up now and create your account' })  // ❌
```
→ תעביר ל-POM:
```typescript
// signup.page.ts
this.submitButton = page.getByRole('button', { name: /sign up/i })  // ✅ regex
```

---

## מתי לא POM?

POM הוא default. **לא** כדאי POM עבור:

- **Single-page apps עם routes דינמיים** — POM נשבר כל refactor. שקול FSM (Finite State Machine) במקום.
- **Tiny apps (< 5 pages)** — overhead גדול מדי.
- **Test יחיד שבודק flow שלם** — POM over-engineering.

**ברירת מחדל:** POM. אם ה-flow מורכב מדי (modal → drawer → toast → redirect), שקול test API במקום (route ייעודי ל-test data setup).

---

*Built with Skillsmith*
