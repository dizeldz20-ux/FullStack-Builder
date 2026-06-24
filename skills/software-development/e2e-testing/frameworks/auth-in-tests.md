# Authenticated Flows in Tests

## The Core Problem

**Sign-up → verify email → login → dashboard** לוקח 5-15 שניות. אם תעשה את זה בכל אחד מ-50 tests, ה-suite ירוץ 10+ דקות. גם תיצור 50 users זבל ב-DB. גם verification email יחסום את ה-rate limit של Mailosaur/Mailtrap.

**הפתרון:** **Storage State** — צלם state של user מאומת פעם אחת, reuse בכל test.

---

## Storage State Pattern

### מה זה

`storageState` = JSON snapshot של localStorage, sessionStorage, cookies. Playwright יכול לשמור אותו ולטעון אותו.

```typescript
// Save state
await page.context().storageState({ path: '.auth/user.json' })

// Load state (in next test)
test.use({ storageState: '.auth/user.json' })
```

**מה נשמר:**

| Auth Provider | Storage |
|---|---|
| Supabase | `localStorage` (sb-xxx-auth-token) |
| Clerk | `localStorage` (__clerk_client_jwt) |
| Auth.js (NextAuth) | `cookies` (next-auth.session-token) |
| Custom JWT | `localStorage` או `cookies` |

---

## Auth Setup Flow

### תיקייה סטנדרטית

```
e2e/
├── auth.setup.ts              # flow מלא פעם אחת
├── fixtures/
│   └── auth.fixture.ts        # custom test עם storageState
└── *.spec.ts                  # tests שמשתמשים ב-storage state
```

### `auth.setup.ts` — flow מלא

```typescript
// e2e/auth.setup.ts
import { test as setup, expect } from '@playwright/test'
import { SignupPage } from './pages/signup.page'
import { LoginPage } from './pages/login.page'
import { DashboardPage } from './pages/dashboard.page'

const AUTH_FILE = '.auth/user.json'

setup('sign up + verify + log in', async ({ page }) => {
  // 1. Generate unique user (won't collide with parallel runs)
  const testEmail = `e2e-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@example.com`
  const testPassword = 'TestPassword123!_e2e'
  const testName = 'E2E Test User'

  // 2. Sign up via UI (preferred — tests the real flow)
  const signup = new SignupPage(page)
  await signup.goto()
  await signup.signUp(testEmail, testPassword, testName)

  // 3. Verify email (choose one approach below)
  await verifyEmail(testEmail)

  // 4. Log in (if not auto-logged-in)
  const login = new LoginPage(page)
  await login.goto()
  await login.login(testEmail, testPassword)

  // 5. Confirm dashboard
  const dashboard = new DashboardPage(page)
  await dashboard.expectLoaded()

  // 6. Save state
  await page.context().storageState({ path: AUTH_FILE })
})
```

### `fixtures/auth.fixture.ts` — custom test

```typescript
// e2e/fixtures/auth.fixture.ts
import { test as base, expect } from '@playwright/test'
import path from 'path'

export const test = base.extend({
  // Auto-load storage state for every test
  storageState: path.resolve(__dirname, '../.auth/user.json'),
})

export { expect }
```

**ב-test — import מה-fixture, לא מ-`@playwright/test`:**

```typescript
// e2e/dashboard.spec.ts
import { test, expect } from './fixtures/auth.fixture'  // ← not @playwright/test

test('dashboard loads', async ({ page }) => {
  // Already logged in!
  await page.goto('/dashboard')
  await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible()
})
```

### `playwright.config.ts` — wire it up

```typescript
export default defineConfig({
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
        storageState: '.auth/user.json',
      },
      dependencies: ['setup'],
    },
    // ... firefox, webkit
  ],
})
```

---

## Email Verification Approaches

### A. Supabase Admin API (recommended)

```typescript
// e2e/auth.setup.ts
import { createClient } from '@supabase/supabase-js'

async function verifyEmail(email: string) {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!  // ← service role, not anon
  )

  // Find user by email
  const { data: { users } } = await supabase.auth.admin.listUsers()
  const user = users.find(u => u.email === email)
  if (!user) throw new Error(`User ${email} not found`)

  // Confirm email
  await supabase.auth.admin.updateUserById(user.id, { email_confirm: true })
}
```

**Pros:** מהיר, לא תלוי ב-email service
**Cons:** דורש service role key (סוד!)

**CI secret:** `SUPABASE_SERVICE_ROLE_KEY` → never in repo, never in `.env` (only in CI secrets)

### B. Mailosaur / Mailtrap API

```typescript
// e2e/auth.setup.ts
import MailosaurClient from 'mailosaur'

async function verifyEmail(email: string) {
  const client = new MailosaurClient(process.env.MAILOSAUR_API_KEY!)
  const serverId = process.env.MAILOSAUR_SERVER_ID!

  // Wait for verification email
  const message = await client.messages.get(serverId, {
    sentTo: email,
    timeout: 30_000,
  })

  // Extract verification link
  const link = message.html?.links[0]?.href ?? message.text?.links[0]?.href
  if (!link) throw new Error('No verification link found in email')

  // Click it
  await page.goto(link)
}
```

**Pros:** בודק את ה-email content באמת
**Cons:** איטי (10-30 שניות), דורש Mailosaur account

### C. Disable verification in staging

```bash
# In Supabase Dashboard → Auth → Email
# Disable "Enable email confirmations" for staging env
```

**Pros:** הכי פשוט
**Cons:** staging ≠ prod, בעיות email verification לא נתפסות

### D. Database direct update (last resort)

```typescript
async function verifyEmail(email: string) {
  // For Supabase: UPDATE auth.users SET email_confirmed_at = NOW() WHERE email = $1
  const { Client } = require('pg')
  const client = new Client({ connectionString: process.env.DATABASE_URL })
  await client.connect()
  await client.query('UPDATE auth.users SET email_confirmed_at = NOW() WHERE email = $1', [email])
  await client.end()
}
```

**Pros:** בלי תלות חיצונית
**Cons:** שביר (schema changes), דורש DB access

---

## Multiple Users (Roles)

כשצריך tests עם admin, regular user, וכו':

```typescript
// e2e/auth.setup.ts
const USERS = {
  regular: { email: '...', password: '...', name: 'Regular' },
  admin: { email: '...', password: '...', name: 'Admin' },
}

for (const [role, user] of Object.entries(USERS)) {
  setup(`authenticate as ${role}`, async ({ page }) => {
    // ... sign up + verify + log in ...
    await page.context().storageState({ path: `.auth/${role}.json` })
  })
}
```

```typescript
// playwright.config.ts
projects: [
  // ... setup ...
  {
    name: 'chromium-regular',
    testMatch: /regular\.spec\.ts/,
    use: { storageState: '.auth/regular.json' },
    dependencies: ['setup'],
  },
  {
    name: 'chromium-admin',
    testMatch: /admin\.spec\.ts/,
    use: { storageState: '.auth/admin.json' },
    dependencies: ['setup'],
  },
]
```

---

## OAuth Flows (Google, Apple, GitHub)

**בעיה:** OAuth דורש redirect חיצוני, אי אפשר לבדוק בלי mocking.

**פתרון 1 — Mock OAuth provider:**

```typescript
// e2e/auth.setup.ts
test('sign in with Google (mocked)', async ({ page, context }) => {
  // Intercept Google OAuth
  await context.route('**/accounts.google.com/**', (route) => {
    // Return mock response
    route.fulfill({
      status: 200,
      body: JSON.stringify({ id_token: 'mock-token' }),
    })
  })

  // Click "Sign in with Google"
  await page.getByRole('button', { name: /google/i }).click()

  // Should be logged in
  await expect(page).toHaveURL('/dashboard')
})
```

**Pros:** בודק את ה-UI flow
**Cons:** לא בודק את ה-OAuth integration עצמו

**פתרון 2 — Auto-confirm + bypass OAuth (Supabase):**

```typescript
// Supabase → Auth → Providers → Google → Disable
// (only for staging, never prod)
```

**פתרון 3 — Test accounts (Google test users):**

```bash
# Google Cloud Console → APIs & Services → OAuth consent screen
# Add test users (max 100)
# Use these in CI
```

---

## Storage State Gotchas

| בעיה | פתרון |
|---|---|
| State לא נטען | בדוק path, `__dirname` נכון |
| State פג תוקף | tokens בתוקף (refresh לפני setup) |
| State לא per-browser | `chromium-user.json`, `firefox-user.json` נפרדים |
| State contamination בין tests | `test.beforeEach` → נקה cookies |
| State גדול מדי | רק את ה-cookies/localStorage הנדרשים |

**טיפ:** הוסף `.auth/` ל-`.gitignore`. ה-state מכיל tokens רגישים.

```gitignore
.auth/
```

---

## CI Considerations

**CI Secrets (חובה):**

```yaml
env:
  BASE_URL: ${{ secrets.STAGING_URL }}
  SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
  SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  MAILOSAUR_API_KEY: ${{ secrets.MAILOSAUR_API_KEY }}
  MAILOSAUR_SERVER_ID: ${{ secrets.MAILOSAUR_SERVER_ID }}
```

**Storage state caching:**

```yaml
- name: Cache auth state
  uses: actions/cache@v4
  with:
    path: .auth/
    key: auth-state-${{ hashFiles('e2e/auth.setup.ts') }}
    restore-keys: |
      auth-state-
```

**Pros:** setup רץ פעם אחת, לא בכל shard
**Cons:** state ישן עלול לפוג — הוסף `if-no-files-found: create`

---

*Built with Skillsmith*
