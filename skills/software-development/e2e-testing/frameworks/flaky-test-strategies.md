# Flaky Test Strategies

## What Is Flaky

**Test flaky** = עובר לפעמים, נופל לפעמים, בלי שינוי בקוד. הסיוט של כל CI.

**למה זה קטלני:**
- צוות מתעלם מ-failures ("זה רק flaky")
- בעיות אמיתיות מוסתרות
- CI הופך ל"עובר או לא" — לא מקור אמת
- On-call מתעורר ל-failures שלא קשורים

**הכלל הבסיסי:** retry מסתיר בעיות, לא פותר אותן. תמיד חפש root cause.

---

## Triage Flow

```
Test נופל
  │
  ├─► Deterministic (אותה שורה תמיד)?
  │     │
  │     └─► Trace viewer → תקן את הבאג
  │
  └─► Flaky (pass/fail מתחלף)?
        │
        ├─► Network flakiness (502/503/timeout)?
        │     └─► Fix infra / mock / toPass
        │
        ├─► Timing (element not ready)?
        │     └─► החלף waitForTimeout ב-auto-wait / waitForResponse
        │
        ├─► State (data מ-test אחר)?
        │     └─► Unique data / cleanup / isolation
        │
        └─► Race (click לפני navigation)?
              └─► Promise.all + waitForURL
```

---

## Pattern 1: Network Flakiness

### סימפטומים
- 502/503/504 ב-network tab
- "Request timeout" ב-error
- עובד ב-localhost, נופל ב-staging (latency)

### ❌ Anti-patterns

```typescript
// ❌ רק מסתיר
await page.waitForTimeout(5000)  // "give it time"

// ❌ רק מסתיר
await page.goto('/dashboard', { timeout: 30_000 })  // יותר זמן ≠ פתרון
```

### ✅ Fixes

**Approach 1: `toPass` עם exponential backoff:**

```typescript
await expect(async () => {
  const response = await page.goto('/dashboard')
  expect(response?.status()).toBeLessThan(400)
}).toPass({
  timeout: 10_000,
  intervals: [500, 1000, 2000],  // 500ms, 1s, 2s between retries
})
```

**Approach 2: Wait for specific response:**

```typescript
// ❌ goto + guess
await page.goto('/dashboard')
await expect(page.getByText('Welcome')).toBeVisible()

// ✅ wait for API
await page.goto('/dashboard')
await page.waitForResponse(resp =>
  resp.url().includes('/api/dashboard') && resp.status() === 200
)
await expect(page.getByText('Welcome')).toBeVisible()
```

**Approach 3: Mock external services (only when test isn't about them):**

```typescript
test('dashboard shows error state', async ({ page }) => {
  // Mock the API to return 503 — that's what we're testing
  await page.route('**/api/dashboard', (route) => {
    route.fulfill({ status: 503, body: 'Service Unavailable' })
  })

  await page.goto('/dashboard')
  await expect(page.getByText(/error|try again/i)).toBeVisible()
})
```

**Approach 4: Fix the network (real fix):**
- Rate limiting too strict
- DB query slow (add index)
- CORS preflight failing

---

## Pattern 2: Timing Flakiness

### סימפטומים
- "Element is not visible"
- "Element is not enabled"
- "Element is not stable" (during click)
- "Locator resolved to N elements"

### ❌ Anti-patterns

```typescript
// ❌ "wait for magic time"
await page.waitForTimeout(2000)
await page.click('button')

// ❌ "wait for the same thing twice"
await page.click('button')
await page.waitForTimeout(500)
await page.click('button')  // just in case
```

### ✅ Fixes

**Approach 1: Playwright auto-wait (default — usually enough):**

```typescript
// Playwright auto-waits for: visible, enabled, stable, attached
await page.getByRole('button', { name: 'Submit' }).click()
```

**Approach 2: Explicit state assertion:**

```typescript
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled()
await page.getByRole('button', { name: 'Submit' }).click()
```

**Approach 3: Wait for network/component:**

```typescript
// Wait for image to load
await page.locator('img.product').waitFor({ state: 'visible' })
// Wait for animation
await page.locator('.modal').waitFor({ state: 'visible' })
// Wait for skeleton to disappear
await expect(page.getByTestId('skeleton')).toBeHidden()
```

**Approach 4: Wait for specific event:**

```typescript
// For data loading
await page.waitForResponse('**/api/items')
// For websocket
await page.waitForEvent('websocket')
// For localStorage change
await page.waitForFunction(() => localStorage.getItem('token') !== null)
```

**Anti-pattern:** `waitForTimeout` בלי הצדקה. אם אתה חייב, הוסף comment:
```typescript
// KNOWN ISSUE: 3rd-party iframe takes 1.5s to render
// See JIRA-1234 — fix scheduled
await page.waitForTimeout(1500)
```

---

## Pattern 3: State Flakiness (Test Isolation)

### סימפטומים
- עובר לבד, נופל עם הסדר השני
- "User already exists"
- "Item not found" (test אחר מחק)
- Test נופל רק כשמופעל יחד עם אחרים

### ❌ Anti-patterns

```typescript
// ❌ shared user
const testUser = { email: 'shared@example.com', ... }

test('user A creates post', async ({ page }) => {
  // depends on user not having posts
})

test('user A sees their posts', async ({ page }) => {
  // depends on first test running
})
```

### ✅ Fixes

**Approach 1: Unique data per test:**

```typescript
function uniqueEmail() {
  return `e2e-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@example.com`
}

test('user creates post', async ({ page }) => {
  const email = uniqueEmail()  // ← never collides
  // ...
})
```

**Approach 2: `serial` mode + clear order:**

```typescript
test.describe.serial('user flow', () => {
  test('signup', async ({ page }) => { /* ... */ })
  test('create item', async ({ page }) => { /* depends on signup */ })
  test('see item', async ({ page }) => { /* depends on create */ })
})
```

**Approach 3: `beforeEach` cleanup:**

```typescript
test.beforeEach(async ({ request }) => {
  // Reset DB state
  await request.post('http://localhost:3000/api/test/reset', {
    headers: { 'x-test-key': process.env.TEST_RESET_KEY! },
  })
})
```

**Approach 4: `test.fixme` for known-broken:**

```typescript
test('flaky on CI', async ({ page }) => {
  test.fixme(process.env.CI === 'true', 'Flaky on CI, see JIRA-1234')
  // ... test code
})
```

---

## Pattern 4: Race Conditions

### סימפטומים
- Click → assertion מוקדם מדי
- Form submitted → page already navigated away
- Modal opened → elements not rendered yet

### ❌ Anti-patterns

```typescript
// ❌ click then check URL — race!
await page.getByRole('link', { name: 'Dashboard' }).click()
await expect(page).toHaveURL('/dashboard')

// ❌ submit then check response
await page.getByRole('button', { name: 'Submit' }).click()
await expect(page.getByText('Success')).toBeVisible()
```

### ✅ Fixes

**Approach 1: `Promise.all` (the standard fix):**

```typescript
await Promise.all([
  page.waitForURL('/dashboard'),
  page.getByRole('link', { name: 'Dashboard' }).click(),
])
```

**Approach 2: `waitForResponse` for form submission:**

```typescript
const [response] = await Promise.all([
  page.waitForResponse(resp => resp.url().includes('/api/signup') && resp.status() === 200),
  page.getByRole('button', { name: 'Sign up' }).click(),
])
```

**Approach 3: Wait for explicit state change:**

```typescript
await page.getByRole('button', { name: 'Submit' }).click()
await expect(page.getByText('Success')).toBeVisible()  // auto-retries
```

**Approach 4: Network idle (use sparingly):**

```typescript
await page.getByRole('button', { name: 'Submit' }).click()
await page.waitForLoadState('networkidle')
// Now safe to assert
```

**Anti-pattern:** `networkidle` כ-default — זה לא deterministic. השתמש רק כשבאמת צריך.

---

## Visual Regression Flakiness

(ראה גם `@tasks/visual-regression.md`)

### סיבות נפוצות

| סיבה | פתרון |
|---|---|
| Font לא נטען | `await page.evaluate(() => document.fonts.ready)` |
| Image לא נטען | `await page.waitForLoadState('networkidle')` |
| Animation פעיל | `animations: 'disabled'` ב-config |
| Timestamp / user data | `mask: [...]` |
| Color scheme שונה | `await page.emulateMedia({ colorScheme: 'light' })` |
| OS-level rendering | baseline per-OS |

### ❌ Anti-pattern

```typescript
// ❌ baseline פתוח לדרינגים
await expect(page).toHaveScreenshot('login.png')
// No waits, no animations disabled, no mask
```

### ✅ Fix

```typescript
await page.goto('/login')
await page.evaluate(() => document.fonts.ready)
await page.waitForLoadState('networkidle')

await expect(page).toHaveScreenshot('login.png', {
  maxDiffPixels: 100,
  animations: 'disabled',
  caret: 'hide',
  mask: [page.getByTestId('captcha')],
})
```

---

## Retry Strategy

**`retries` = safety net, לא fix.**

| CI strategy | retries | rationale |
|---|---|---|
| Aggressive | `0` | catch every flaky immediately |
| Balanced | `1` | allow 1 network glitch |
| Lenient | `2-3` | prod-like, allow 2-3 retries |
| ❌ Wrong | `5+` | hides real problems |

**`playwright.config.ts`:**

```typescript
retries: process.env.CI ? 1 : 0,
```

**Per-test override (last resort):**

```typescript
test('this specific test is known-flaky', async ({ page }) => {
  test.setTimeout(60_000)
  // ... test
})
```

**מתי retry עוזר:**
- Network glitch (real infrastructure issue)
- CI runner cold start

**מתי retry מסתיר:**
- Timing issues
- Race conditions
- State contamination
- Visual regression
- Test isolation

---

## Quarantine Pattern

**כש-test באמת לא מתוקן עכשיו** — הוצא מ-CI:

```typescript
// Option 1: fixme
test('flaky test', async ({ page }) => {
  test.fixme(true, 'JIRA-1234 — fix scheduled for sprint 24')
  // ... test
})

// Option 2: skip the whole describe
test.describe.skip('flaky suite', () => {
  // ... tests
})

// Option 3: tag-based filter
test('flaky', async ({ page }) => {
  // ... test
  // Tagged via filename: e2e/flaky.spec.ts → excluded in playwright.config.ts
})
```

**הכלל:** כל skip → issue reference (JIRA/Linear/GitHub). אחרת → permanent skip.

**`playwright.config.ts` exclude:**

```typescript
export default defineConfig({
  testIgnore: ['**/flaky/**', '**/*-flaky.spec.ts'],
})
```

---

## Detection & Monitoring

**CI dashboard — track flakiness rate:**

```yaml
- name: Track flakiness
  if: always()
  run: |
    # Count retries vs total
    # Upload to Datadog/Sentry/Custom
```

**Slack alert:**

```yaml
- name: Notify on flakiness
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "E2E tests flaky on ${{ github.head_ref }}: ${{ steps.tests.outputs.failures }}"
      }
```

**`playwright-report` → check `flaky` column** — Playwright HTML report מראה אילו tests עברו ב-retry.

---

## Root Cause Checklist (כש-test נופל)

לפני שאתה מוסיף retry/waitForTimeout, עבור על הרשימה:

- [ ] **Network tab ב-trace** — יש 500/network error?
- [ ] **Console tab ב-trace** — יש unhandled rejection?
- [ ] **DOM snapshots ב-trace** — האלמנט היה שם?
- [ ] **לוגים של האפליקציה** — מה קרה בצד השני?
- [ ] **Local reproduction** — `npm run e2e:debug` עובר?
- [ ] **CI-only?** — diff env vars, missing secrets, baseURL
- [ ] **Race?** — `Promise.all` במקום click+wait?
- [ ] **State?** — `uniqueEmail()` במקום shared user?
- [ ] **Visual?** — mask dynamic content, disable animations?

**רק אחרי שעברת על הכל — ועדיין לא מצאת root cause** — שקול retry.

---

*Built with Skillsmith*
