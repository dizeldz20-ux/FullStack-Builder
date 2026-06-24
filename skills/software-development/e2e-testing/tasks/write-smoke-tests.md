<purpose>
לכתוב smoke tests ראשונים על ה-flow הקריטי: sign-up → email verification → login → dashboard. כולל את הדפוס הקבוע שלנו (storage state + POM + fixture user) שחוסך 90% מזמן הריצה ומונע DB pollution.
</purpose>

<user-story>
As a the user שבונה מוצר, אני רוצה smoke test שמוודא ש-user יכול להירשם, לאמת email, להתחבר, ולהגיע לדשבורד — תוך 30 שניות ובלי ליצור עשרות users זבל, so that כל PR מאומת אוטומטית.
</user-story>

<when-to-use>
- User אומר "תכתוב smoke test ראשון"
- User אומר "תבנה את ה-flow של sign-up → dashboard"
- אחרי `/e2e-testing setup` — תמיד הצע את ה-smoke הזה
- מוצר חדש שצריך E2E coverage על ה-flow הקריטי
- Entry point routes here via `/e2e-testing smoke`
</when-to-use>

<context>
@frameworks/page-object-model.md (חובה — כל test בנוי על POM)
@frameworks/auth-in-tests.md (חובה — storage state + fixture user pattern)
</context>

<references>
@frameworks/selector-strategies.md (איך לבחור selectors נכון)
@references/email-testing-patterns.md (email verification — Mailosaur/Mailtrap/Resend)
@tasks/setup-playwright.md (אם Playwright עוד לא מותקן)
</references>

<steps>

<step name="gather_context" priority="first">
לפני שמתחילים, צריך לדעת:

1. **baseURL** — local (`http://localhost:3000`) או staging (`https://staging.example.com`)?
2. **Auth provider** — Supabase? Clerk? Auth.js? Custom JWT? (משפיע על איך מאמתים email)
3. **Email testing** — יש Mailosaur/Mailtrap/Resend test mode? או שה-email verification מדלג ב-staging?
4. **User schema** — מה השדות ב-signup form? (email, password, name, וכו')
5. **Routes** — `/signup`, `/verify-email`, `/login`, `/dashboard`?
6. **Storage strategy** — localStorage (Supabase default) או cookies (Auth.js default)?

**שאל את the user אם לא ברור.** התשובות קובעות את הקוד.
</step>

<step name="create_page_objects">
צור POM לכל page ב-flow. דוגמה מלאה ב-`@frameworks/page-object-model.md`. כאן — skeleton מינימלי:

**`e2e/pages/signup.page.ts`:**

```typescript
import { type Page, type Locator, expect } from '@playwright/test'

export class SignupPage {
  readonly page: Page
  readonly emailInput: Locator
  readonly passwordInput: Locator
  readonly nameInput: Locator
  readonly submitButton: Locator

  constructor(page: Page) {
    this.page = page
    this.emailInput = page.getByLabel('Email')
    this.passwordInput = page.getByLabel('Password')
    this.nameInput = page.getByLabel('Full name')
    this.submitButton = page.getByRole('button', { name: /sign up|create account/i })
  }

  async goto() {
    await this.page.goto('/signup')
  }

  async signUp(email: string, password: string, name: string) {
    await this.emailInput.fill(email)
    await this.passwordInput.fill(password)
    await this.nameInput.fill(name)
    await this.submitButton.click()
  }
}
```

**`e2e/pages/login.page.ts`:**

```typescript
import { type Page, type Locator } from '@playwright/test'

export class LoginPage {
  readonly page: Page
  readonly emailInput: Locator
  readonly passwordInput: Locator
  readonly submitButton: Locator

  constructor(page: Page) {
    this.page = page
    this.emailInput = page.getByLabel('Email')
    this.passwordInput = page.getByLabel('Password')
    this.submitButton = page.getByRole('button', { name: /sign in|log in/i })
  }

  async goto() {
    await this.page.goto('/login')
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email)
    await this.passwordInput.fill(password)
    await this.submitButton.click()
  }
}
```

**`e2e/pages/dashboard.page.ts`:**

```typescript
import { type Page, type Locator, expect } from '@playwright/test'

export class DashboardPage {
  readonly page: Page
  readonly welcomeHeading: Locator
  readonly userMenu: Locator

  constructor(page: Page) {
    this.page = page
    this.welcomeHeading = page.getByRole('heading', { name: /welcome|dashboard/i })
    this.userMenu = page.getByTestId('user-menu')
  }

  async goto() {
    await this.page.goto('/dashboard')
  }

  async expectLoaded() {
    await expect(this.welcomeHeading).toBeVisible()
  }
}
```

**העיקרון:** selectors בתוך POM, לא ב-test. test = קריאת actions מ-POM.
</step>

<step name="create_auth_setup">
זה הלב של הדפוס. **ריצה פעם אחת** → storage state → **שימוש חוזר בכל test**.

**`e2e/auth.setup.ts`:**

```typescript
import { test as setup, expect } from '@playwright/test'
import { SignupPage } from './pages/signup.page'
import { LoginPage } from './pages/login.page'

const AUTH_FILE = '.auth/user.json'

setup('sign up + verify + log in', async ({ page }) => {
  // Generate unique test user (won't collide with parallel runs)
  const testEmail = `e2e-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@example.com`
  const testPassword = 'TestPassword123!_e2e'
  const testName = 'E2E Test User'

  // 1. Sign up
  const signup = new SignupPage(page)
  await signup.goto()
  await signup.signUp(testEmail, testPassword, testName)

  // 2. Handle email verification
  // Option A: Auto-confirm via Supabase admin API (preferred for CI)
  // Option B: Mailosaur/Mailtrap API to fetch verification link
  // Option C: If staging has email verification disabled, just wait for redirect
  await verifyEmail(testEmail)

  // 3. Log in
  const login = new LoginPage(page)
  await login.goto()
  await login.login(testEmail, testPassword)

  // 4. Confirm we landed on dashboard
  await expect(page).toHaveURL(/\/dashboard/)

  // 5. Save storage state for all future tests
  await page.context().storageState({ path: AUTH_FILE })
})

async function verifyEmail(email: string) {
  // Implement based on your auth provider. Examples:
  //
  // Supabase: use admin API to update user.email_confirmed_at
  //   import { createClient } from '@supabase/supabase-js'
  //   const supabase = createClient(URL, SERVICE_ROLE_KEY)
  //   await supabase.auth.admin.updateUserById(userId, { email_confirm: true })
  //
  // Mailosaur: fetch latest email, click verification link
  //   import MailosaurClient from 'mailosaur'
  //   const client = new MailosaurClient(process.env.MAILOSAUR_API_KEY!)
  //   const email = await client.messages.get(serverId, { sentTo: email })
  //   const link = email.html.links[0].href
  //   await page.goto(link)
  //
  // No-op for staging where verification is disabled
}
```

**חשוב — להוסיף `setup` כ-project ב-`playwright.config.ts`:**

```typescript
projects: [
  {
    name: 'setup',
    testMatch: /.*\.setup\.ts/,
  },
  {
    name: 'chromium',
    testMatch: /.*\.spec\.ts/,
    use: {
      ...devices['Desktop Chrome'],
      storageState: '.auth/user.json',  // ← reuse
    },
    dependencies: ['setup'],  // ← run setup first
  },
  // ... firefox, webkit
]
```

**Anti-pattern:** אל תעשה `await page.goto('/signup')` בכל test. זה מוסיף 5-15 שניות לכל אחד. ראה Pitfall ב-SKILL.md.
</step>

<step name="write_signup_test">
טסט שמכסה את **flow ה-signup עצמו** (לא רק dashboard, כי ה-flow הזה הוא הקריטי):

**`e2e/signup.spec.ts`:**

```typescript
import { test, expect } from './fixtures/auth.fixture'  // custom fixture
import { SignupPage } from './pages/signup.page'
import { LoginPage } from './pages/login.page'
import { DashboardPage } from './pages/dashboard.page'

test.describe('Sign up → dashboard', () => {
  test('new user can sign up and reach dashboard', async ({ page }) => {
    // Note: this test does NOT use storageState — it tests the actual flow
    const testEmail = `e2e-flow-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@example.com`
    const testPassword = 'TestPassword123!_e2e'
    const testName = 'E2E Flow User'

    // 1. Sign up
    const signup = new SignupPage(page)
    await signup.goto()
    await signup.signUp(testEmail, testPassword, testName)

    // 2. Should redirect to "check your email" or directly to dashboard
    await expect(page).toHaveURL(/verify-email|dashboard/)

    // 3. Verify email (via your mechanism)
    // ... same as auth.setup.ts ...

    // 4. Log in (if not auto-logged-in)
    const login = new LoginPage(page)
    await login.goto()
    await login.login(testEmail, testPassword)

    // 5. Land on dashboard
    const dashboard = new DashboardPage(page)
    await dashboard.expectLoaded()
  })

  test('shows validation error for invalid email', async ({ page }) => {
    const signup = new SignupPage(page)
    await signup.goto()
    await signup.emailInput.fill('not-an-email')
    await signup.submitButton.click()

    await expect(page.getByText(/invalid email|valid email/i)).toBeVisible()
  })

  test('shows validation error for short password', async ({ page }) => {
    const signup = new SignupPage(page)
    await signup.goto()
    await signup.emailInput.fill('valid@example.com')
    await signup.passwordInput.fill('123')
    await signup.submitButton.click()

    await expect(page.getByText(/at least 8|password too short/i)).toBeVisible()
  })

  test('shows error for duplicate email', async ({ page }) => {
    // Assumes 'taken@example.com' already exists
    const signup = new SignupPage(page)
    await signup.goto()
    await signup.signUp('taken@example.com', 'Password123!', 'Test')

    await expect(page.getByText(/already exists|email taken/i)).toBeVisible()
  })
})
```

**זה ה-test הקריטי** — מכסה את ה-flow מקצה לקצה. רץ איטי (5-15 שניות), אבל רץ פעם אחת. שאר ה-tests משתמשים ב-storage state.
</step>

<step name="write_dashboard_test">
עכשיו, **עם storage state** — בלי login, בלי DB write:

**`e2e/dashboard.spec.ts`:**

```typescript
import { test, expect } from './fixtures/auth.fixture'
import { DashboardPage } from './pages/dashboard.page'

test.describe('Dashboard', () => {
  test('loads with user data', async ({ page }) => {
    const dashboard = new DashboardPage(page)
    await dashboard.goto()
    await dashboard.expectLoaded()
  })

  test('user menu shows email', async ({ page }) => {
    await page.goto('/dashboard')
    await page.getByTestId('user-menu').click()
    await expect(page.getByText(/@example\.com/)).toBeVisible()
  })

  test('can log out', async ({ page }) => {
    await page.goto('/dashboard')
    await page.getByTestId('user-menu').click()
    await page.getByRole('button', { name: /log out|sign out/i }).click()

    await expect(page).toHaveURL(/\/(login|$)/)
  })
})
```

**זה מהיר** — 1-3 שניות לכל test. אפשר 50 tests כאלה בלי timeout.
</step>

<step name="run_and_verify">
הרץ את כל ה-tests:

```bash
npm run e2e:chromium
```

**ציפייה:**

```
Running 7 tests using 3 workers
  ✓ auth.setup.ts (15s)
  ✓ signup.spec.ts (45s)
    ✓ new user can sign up and reach dashboard
    ✓ shows validation error for invalid email
    ✓ shows validation error for short password
    ✓ shows error for duplicate email
  ✓ dashboard.spec.ts (8s)
    ✓ loads with user data
    ✓ user menu shows email
    ✓ can log out
  7 passed (1m 15s)
```

**אם setup נכשל** — בדוק `verifyEmail()` helper. הוא הכי שביר.

**אם dashboard tests נופלים על redirect ל-login** — storage state לא נשמר / לא נטען. בדוק:
1. `.auth/user.json` קיים
2. `playwright.config.ts` `storageState` מצביע לנכון
3. `auth.setup.ts` רץ (`dependencies: ['setup']`)
</step>

</steps>

<output>
## Artifacts
- `e2e/auth.setup.ts` — flow מלא פעם אחת, שומר `.auth/user.json`
- `e2e/pages/signup.page.ts` — POM ל-signup
- `e2e/pages/login.page.ts` — POM ל-login
- `e2e/pages/dashboard.page.ts` — POM ל-dashboard
- `e2e/signup.spec.ts` — 4 tests על ה-flow (validation + happy path)
- `e2e/dashboard.spec.ts` — 3 tests עם storage state (מהיר)
- `e2e/fixtures/auth.fixture.ts` — custom test fixture שעוטף את ה-storage state
- `.auth/user.json` — storage state (gitignored)

## Verification
```bash
# Run all tests
npm run e2e:chromium
# Expected: 7+ tests pass in 1-2 minutes

# Check storage state
cat .auth/user.json | jq '.cookies | length'
# Expected: >= 2 (session + csrf or similar)

# View report
npm run e2e:report
```
</output>

<acceptance-criteria>
- [ ] `e2e/auth.setup.ts` קיים ויוצר `.auth/user.json`
- [ ] `e2e/pages/*.page.ts` — לפחות SignupPage, LoginPage, DashboardPage
- [ ] `e2e/signup.spec.ts` כולל happy path + validation errors
- [ ] `e2e/dashboard.spec.ts` רץ עם storageState (ללא login בכל test)
- [ ] `playwright.config.ts` כולל `setup` project + `dependencies: ['setup']`
- [ ] כל ה-tests עוברים ב-`npm run e2e:chromium`
- [ ] Suite רץ ב-1-2 דקות (לא 10+) — storage state עובד
- [ ] אין users זבל ב-DB (רק 1 מ-`auth.setup.ts`)
- [ ] POM לא מכיל selectors inline ב-tests
</acceptance-criteria>

*Built with Skillsmith*
