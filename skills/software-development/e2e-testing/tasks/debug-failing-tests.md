<purpose>
לדבאג tests שנופלים או flaky: trace viewer, codegen, locator debugging, retry strategies, ו-Playwright UI mode. כולל טריאז' של root cause (network, timing, state, race) ולא "פשוט תוסיף `await page.waitForTimeout(2000)`".
</purpose>

<user-story>
As a the user שיש לו test ש-flaky או נופל רנדומלית, אני רוצה להבין למה ולתקן את הבעיה האמיתית, so that ה-CI הופך לאמין ולא מקור לתסכול.
</user-story>

<when-to-use>
- User אומר "הטסט נופל רנדומלית"
- "יש לי test שעובד local אבל נופל ב-CI"
- "תעזור לי להבין למה ה-toHaveScreenshot נשבר"
- "תראה לי איך לדבאג"
- "יש לי timeout ב-page.goto"
- Entry point routes here via `/e2e-testing debug`
</when-to-use>

<context>
@frameworks/flaky-test-strategies.md (טען תמיד — מכיל triage flow)
@frameworks/selector-strategies.md (כשהבעיה היא selector)
</context>

<references>
@tasks/ci-integration.md (אם הבעיה רק ב-CI)
@tasks/visual-regression.md (אם visual test flaky)
</references>

<steps>

<step name="identify_failure_mode" priority="first">
לפני שמתחילים לדבאג, סווג את הכישלון:

**4 הקטגוריות העיקריות:**

| סימפטום | קטגוריה | כלי ראשוני |
|---|---|---|
| Test נופל רנדומלית (pass/fpass מתחלף) | **flaky** | trace viewer + retry |
| Test נופל תמיד באותה שורה | **deterministic** | trace viewer + log |
| עובד local, נופל ב-CI | **environment** | diff env vars, CI logs |
| Visual regression נשבר | **ui-change** | diff image, mask |

**לכל אחד — flow שונה.** אל תתחיל ב-`waitForTimeout`.
</step>

<step name="open_trace_viewer">
**זה הצעד הראשון תמיד.** trace.zip מכיל את כל מה שקרה: DOM, network, console, screenshots לאורך זמן.

**איפה ה-trace:**

```bash
# Local — test-results/<test-name>/trace.zip
ls test-results/*/trace.zip

# CI — artifact: test-results-<shard>
# Download from GH Actions / GitLab
```

**איך לפתוח:**

```bash
npx playwright show-trace test-results/login-page-matches-baseline-chromium/trace.zip
# Or via npm script:
npm run e2e:trace
```

**מה לחפש ב-trace:**

1. **Network tab** — בקשה אדומה? 401/500? timeout? CORS?
2. **Console tab** — `Error:` אדום? Unhandled promise rejection?
3. **DOM snapshots** — האלמנט היה שם כשלוחצים עליו? או שלא הופיע בכלל?
4. **Before/After screenshots** — האם ה-UI השתנה בין הצילומים?

**Anti-pattern:** להסתכל רק על ה-`Error: locator.fill: Timeout exceeded` בלי לראות למה ה-locator לא מצא כלום.
</step>

<step name="use_healed_mode">
**להריץ test אחד ב-`--debug` mode** — step-by-step עם DevTools:

```bash
npx playwright test --debug e2e/signup.spec.ts
# Or via npm script:
npm run e2e:debug
```

זה פותח:
1. Playwright Inspector (toolbar למעלה: pause/step/continue)
2. Browser עם ה-test
3. Console logs

**קיצורי מקלדת שימושיים:**

| Key | מה |
|---|---|
| F8 | pause/resume |
| F10 | step over |
| F11 | step into |
| Shift+F11 | step out |
| Click בדף | pick locator |

**לוגים:** `console.log` ב-test → מופיע ב-Inspector.
</step>

<step name="use_codegen_for_selectors">
**כשה-locator לא יציב**, השתמש ב-codegen:

```bash
npx playwright codegen https://staging.example.com
# Or via npm script:
npm run e2e:codegen
```

זה פותח:
1. דפדפן עם ה-URL
2. Recording panel
3. **כל קליק/fill** → מייצר selector + code

**שימושי ל:**
- selectors חדשים שעובדים
- בדיקה איזה selector הכי יציב
- refactor של selector ישן שלא עובד

**Anti-pattern:** לכתוב `page.locator('div > div > div:nth-child(3) > button')` ידנית במקום להשתמש ב-codegen.

**טיפ:** העדיפו `getByRole`, `getByLabel`, `getByTestId` על CSS. ראה `@frameworks/selector-strategies.md`.
</step>

<step name="diagnose_flaky_test">
**לפי הקטגוריה (מ-step 1):**

### 1. Network flakiness
**סימפטום:** tests נופלים על 502/503/504, network timeouts.

```typescript
// ❌ No retry
await page.goto('/dashboard')

// ✅ Add retry on specific errors
await expect(async () => {
  await page.goto('/dashboard')
}).toPass({ timeout: 10_000, intervals: [500, 1000, 2000] })

// ✅ Better: fix the network (rate limit, slow endpoint)
// Or: use waitForResponse
await page.waitForResponse(resp => resp.url().includes('/api/dashboard') && resp.status() === 200)
```

**טיפ:** `toPass()` עם exponential backoff עדיף על `waitForTimeout`.

### 2. Timing flakiness
**סימפטום:** test עובר לפעמים, נופל לפעמים. האלמנט "לא מוכן".

```typescript
// ❌ Brittle: hard wait
await page.waitForTimeout(2000)

// ✅ Playwright auto-waits
await page.getByRole('button', { name: 'Submit' }).click()

// ✅ Better: explicit state wait
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled()

// ✅ Best: wait for API
await page.waitForResponse('**/api/signup')
await page.getByRole('button', { name: 'Submit' }).click()
```

**Anti-pattern:** `waitForTimeout` — מסתיר race condition, מאט tests.

### 3. State flakiness
**סימפטום:** test נופל כי data מ-test אחר נשאר.

```typescript
// ❌ Brittle: shared user
test('user A creates item', async ({ page }) => { /* ... */ })
test('user A sees item', async ({ page }) => { /* depends on first */ })

// ✅ Solution 1: serial + order
test.describe.configure({ mode: 'serial' })

// ✅ Solution 2: unique data per test
const email = `test-${Date.now()}-${Math.random()}@example.com`

// ✅ Solution 3: cleanup in afterEach
test.afterEach(async ({ page }) => {
  // Reset DB to known state, clear cookies, etc.
})
```

### 4. Race condition
**סימפטום:** click → navigation → assertion מוקדם מדי.

```typescript
// ❌ Race: click then check URL
await page.getByRole('link', { name: 'Dashboard' }).click()
await expect(page).toHaveURL('/dashboard')  // ← may fail

// ✅ Wait for navigation
await Promise.all([
  page.waitForURL('/dashboard'),
  page.getByRole('link', { name: 'Dashboard' }).click(),
])
```

**עוד דוגמאות:** ראה `@frameworks/flaky-test-strategies.md`.
</step>

<step name="fix_visual_regression_flakiness">
**הקטגוריה הכי שכיחה.** Visual tests נופלים בגלל:

| סיבה | פתרון |
|---|---|
| Font עוד לא נטען | `await page.evaluate(() => document.fonts.ready)` |
| Image עוד לא נטען | `await page.waitForLoadState('networkidle')` |
| Animation פעיל | `await page.locator('.animated').waitFor({ state: 'hidden' })` |
| Timestamp / user data | `mask: [page.getByTestId('timestamp')]` |
| Time of day (dark mode vs light) | `await page.emulateMedia({ colorScheme: 'light' })` |
| Different renderings per OS | `await page.emulateMedia({ reducedMotion: 'reduce' })` |

**Anti-pattern:** `maxDiffPixels: 0` — אפילו pixel shift של font rendering נופל.

**פתרון נכון:**

```typescript
await expect(page).toHaveScreenshot('login.png', {
  maxDiffPixels: 100,           // tolerate small differences
  animations: 'disabled',       // freeze animations
  caret: 'hide',                // hide blinking cursor
  scale: 'css',                 // use CSS pixels
  mask: [                       // hide dynamic content
    page.getByTestId('timestamp'),
    page.getByTestId('user-avatar'),
  ],
})

// Wait for stability BEFORE screenshot
await page.evaluate(() => document.fonts.ready)
await page.waitForLoadState('networkidle')
```

**אם ה-baseline פשוט לא נכון** (UI השתנה בכוונה):
1. צור branch ייעודי: `chore/snapshot-baseline-v3`
2. הרץ: `npm run e2e:update-snapshots -- visual.spec.ts -g "specific test"`
3. eyeball את ה-diff
4. PR עם label `visual:baseline`

ראה `@tasks/visual-regression.md` step "handle_baseline_updates".
</step>

<step name="fix_local_vs_ci_difference">
**עובד local, נופל ב-CI.** הפתרון הוא להבין מה שונה:

| סיבה | איך לאמת |
|---|---|
| **TZ / locale** | `process.env.TZ` ב-CI vs local |
| **Browser version** | Playwright Docker image → fixed version |
| **CPU speed** | CI slower → timeouts |
| **Network latency** | CI → prod network, not localhost |
| **Missing env var** | `env: BASE_URL: ${{ secrets.X }}` |
| **File system permissions** | test-results/ write |
| **Different Node version** | lockfile לא מעודכן |
| **Missing `--with-deps`** | system libs חסרים |

**Diagnostic script — הרץ ב-CI כדי לראות env:**

```yaml
- name: Debug env
  if: failure()
  run: |
    echo "Node: $(node --version)"
    echo "TZ: $TZ"
    echo "BASE_URL: $BASE_URL"
    echo "CI: $CI"
    npx playwright --version
    ls ~/.cache/ms-playwright/
```

**Anti-pattern:** "אני אנסה להגדיל את ה-timeout ואולי זה יעבוד" → לא עובד.
</step>

<step name="add_targeted_retry">
**רק כמוצא אחרון** — `retries: 2` ב-CI. זה מסתיר בעיות אמיתיות.

**קבע מתי retry עוזר ומתי לא:**

| בעיה | retry עוזר? | הערות |
|---|---|---|
| Network glitch (502/503) | ✅ | infrastructure |
| Animation not done | ❌ | masking |
| Race condition | ❌ | לא deterministic |
| Test isolation | ❌ | design fix |
| Time-dependent (cron) | ❌ | לא ניתן לבדוק |
| Visual regression | ❌ | זה בדיוק מה שרוצים לתפוס |

**הגדרה נכונה:**

```typescript
// playwright.config.ts
retries: process.env.CI ? 1 : 0,  // רק CI, רק 1

// או per-test:
test('flaky network test', async ({ page }) => {
  test.setTimeout(60_000)
  // ... test code
})
```

**Anti-pattern:** `retries: 5` ב-CI + "הכל ירוק" — בעיות מוסתרות, אף פעם לא מתוקנות.

**הכלל:** retry הוא **safety net**, לא **fix**. אם test צריך retry, יש בעיה אמיתית. תקן אותה.
</step>

<step name="quarantine_pattern">
**כש-test באמת flaky ולא מתוקן** — הוצא אותו מ-CI:

```typescript
// Mark as fixme — runs locally but skipped in CI
test('flaky test - under investigation', async ({ page }) => {
  test.fixme(process.env.CI === 'true', 'Flaky, see JIRA-1234')

  // ... test code
})
```

**או:**

```typescript
test.describe.skip('flaky tests', () => {
  test('this one', async ({ page }) => { /* ... */ })
})
```

**Anti-pattern:** `.skip()` בלי תיעוד — הבעיה נשכחת.

**הכלל:** כל `fixme` / `skip` חייב reference ל-issue (JIRA/Linear/GitHub). אחרת — זה skip permanent.
</step>

</steps>

<output>
## Artifacts
- `playwright-report/` — HTML report עם trace viewer
- `test-results/<test>/trace.zip` — trace לכל test
- `test-results/<test>/error-context.md` — markdown של failure
- (אופציונלי) `e2e/debug.spec.ts` — test זמני לבדיקה

## Verification
```bash
# 1. Single test with --debug
npm run e2e:debug -- e2e/signup.spec.ts

# 2. Open trace from last failure
ls test-results/*/trace.zip | head -1
npx playwright show-trace $(ls test-results/*/trace.zip | head -1)

# 3. Use codegen for new selectors
npm run e2e:codegen https://staging.example.com

# 4. Check flaky
for i in {1..5}; do npm run e2e:chromium -- e2e/dashboard.spec.ts; done
```
</output>

<acceptance-criteria>
- [ ] יש trace.zip לכל test שנכשל
- [ ] `--debug` נפתח עם Inspector
- [ ] `codegen` עובד ומייצר selectors יציבים
- [ ] אין `waitForTimeout` בטסטים (אלא אם יש הצדקה מתועדת)
- [ ] אין `retries > 1` ב-CI
- [ ] כל `fixme` / `skip` עם reference ל-issue
- [ ] Root cause מתועד ב-PR description (network/timing/state/race/ui)
- [ ] זמן הדיבאג: < 15 דקות לבעיה deterministic, < 30 דקות ל-flaky
</acceptance-criteria>

*Built with Skillsmith*
