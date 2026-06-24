<purpose>
להוסיף visual regression testing עם `toHaveScreenshot()` של Playwright: לכלול ב-baseline את ה-screenshots הקריטיים (login, dashboard, onboarding), להגדיר threshold סביר, ולנהל את ה-snapshots בצורה בטוחה (לא `update-snapshots` בלי review).
</purpose>

<user-story>
As a the user שמשנה UI לעיתים קרובות, אני רוצה לדעת אוטומטית אם שינוי עיצוב שבר משהו בעמוד קריטי, so that אני לא מגלה את זה מ-user זועם ב-Sentry.
</user-story>

<when-to-use>
- User אומר "תוסיף visual regression"
- "הלקוח אומר שה-UI נראה שונה בין גרסאות"
- "אני רוצה לוודא שה-design system נשמר"
- "תעשה לי screenshot diff"
- אחרי `setup` + `smoke` — תמיד הצע visual על critical screens
- Entry point routes here via `/e2e-testing visual`
</when-to-use>

<context>
@tasks/write-smoke-tests.md (POM חייב להיות קיים לפני)
@frameworks/page-object-model.md
</context>

<references>
@frameworks/selector-strategies.md (איך לבחור selectors יציבים — משפיע על stability של visual tests)
@frameworks/flaky-test-strategies.md (visual regression הוא source #1 של flakiness)
</references>

<steps>

<step name="identify_critical_screens" priority="first">
Visual regression עובד רק על screens קריטיים. לא על כל page.

**שאל את the user:**

1. אילו screens הכי חשובים ל-marketing / first impression?
2. אילו screens הכי חשובים ל-conversion?
3. אילו screens השתנו לאחרונה?

**רשימת ברירת מחדל (5-7 screens מקסימום):**

| Screen | למה קריטי |
|---|---|
| `/` (landing / marketing) | first impression |
| `/signup` | conversion |
| `/login` | conversion |
| `/dashboard` (empty state) | core UX |
| `/dashboard` (with data) | core UX |
| `/onboarding/step-1` | first-time user experience |
| `/settings` | trust + retention |

**לא לעשות:**
- ❌ כל 50 ה-pages (רעש, תחזוקה כואבת)
- ❌ Pages עם תוכן דינמי (news feed, search results) — baseline לעולם לא יציב
- ❌ Animations / loading states (הזמן משתנה, baselines נשברים)

**Anti-pattern:** `toMatchSnapshot()` על 50 components → 50 false positives בכל merge.
</step>

<step name="configure_screenshot_settings">
עדכן את `playwright.config.ts` עם settings נכונים:

```typescript
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      // Tolerate small rendering differences (font, anti-aliasing)
      maxDiffPixels: 100,
      // Or use percentage-based:
      // maxDiffPixelRatio: 0.02,  // 2% of total pixels

      // Disable animations during screenshot
      animations: 'disabled',

      // Don't fail on caret blink in text fields
      caret: 'hide',

      // Mask dynamic content (timestamps, user names, etc.)
      // Use page.screenshot({ mask: [...] }) per-test
    },
  },
})
```

**הסבר:**

| Setting | Value | למה |
|---|---|---|
| `maxDiffPixels` | `100` | סובלן ל-font rendering, anti-aliasing |
| `animations` | `'disabled'` | CSS animations + transitions עצורות בזמן screenshot — אחרת baselines משתנים |
| `caret` | `'hide'` | blinking cursor לא גורם ל-failures |
| `scale` | `'css'` (default) | השתמש ב-CSS pixels, לא device pixels |

**לא לעשות `threshold: 0`** — אפילו pixel shift של font rendering ייפול. ראה Pitfall ב-SKILL.md.
</step>

<step name="create_visual_test">
צור `e2e/visual.spec.ts`:

```typescript
import { test, expect } from './fixtures/auth.fixture'
import { LoginPage } from './pages/login.page'
import { DashboardPage } from './pages/dashboard.page'

test.describe('Visual regression', () => {
  // Use serial to ensure consistent state
  test.describe.configure({ mode: 'serial' })

  test('login page matches baseline', async ({ page }) => {
    const login = new LoginPage(page)
    await login.goto()

    // Wait for fonts to load (critical for stability)
    await page.evaluate(() => document.fonts.ready)
    // Wait for images
    await page.waitForLoadState('networkidle')

    await expect(page).toHaveScreenshot('login.png', {
      fullPage: true,
      // Mask dynamic content if any
      mask: [
        page.locator('[data-testid="captcha"]'),
      ],
    })
  })

  test('dashboard matches baseline', async ({ page }) => {
    const dashboard = new DashboardPage(page)
    await dashboard.goto()
    await dashboard.expectLoaded()

    await page.evaluate(() => document.fonts.ready)
    await page.waitForLoadState('networkidle')

    await expect(page).toHaveScreenshot('dashboard.png', {
      fullPage: true,
      // Hide timestamps / user-specific data
      mask: [
        page.getByTestId('last-login-time'),
        page.getByTestId('user-avatar'),
      ],
    })
  })

  test('signup page matches baseline', async ({ page }) => {
    await page.goto('/signup')
    await page.evaluate(() => document.fonts.ready)
    await page.waitForLoadState('networkidle')

    await expect(page).toHaveScreenshot('signup.png', {
      fullPage: true,
    })
  })
})
```

**למה `document.fonts.ready` + `networkidle` חשובים:**

| Wait | מה זה פותר |
|---|---|
| `document.fonts.ready` | web fonts נטענו לפני screenshot — אחרת baseline יהיה עם font fallback |
| `networkidle` | images + async content נטענו — אחרת baseline יהיה ריק |

בלי אלה, baselines משתנים בין הרצות → flaky tests.
</step>

<step name="generate_baselines">
ה-baselines נוצרים בריצה הראשונה. **רק ב-branch ייעודי.**

```bash
# 1. Create dedicated branch
git checkout -b chore/snapshot-baseline-v1

# 2. Generate baselines
npm run e2e:update-snapshots -- visual.spec.ts

# 3. Verify they look right
ls e2e/visual.spec.ts-snapshots/
# Expected: login.png, login.actual.png, login.diff.png, etc.

# 4. Open actual.png files to eyeball them
# Are the screenshots what you expect?

# 5. Commit
git add e2e/visual.spec.ts-snapshots/
git commit -m "chore: add visual regression baselines (v1)"

# 6. Merge to main with explicit label
gh pr create --label "visual:baseline" --title "Visual regression baseline v1"
```

**Anti-pattern:** `npm run e2e:update-snapshots && git add . && git commit -m "update"` — בלי review, baselines שגויים נכנסים ל-main.

**ה-baselines נשמרים ב-`e2e/visual.spec.ts-snapshots/`.** זה convention של Playwright. **לא** תיקייה בשם אחר.

**חובה להוסיף ל-`.gitignore`:**

```gitignore
# Don't ignore the snapshots themselves!
# They're committed for baseline comparison.

# But DO ignore the .actual.png and .diff.png files (regenerated on each run)
e2e/**/*.actual.png
e2e/**/*.diff.png
```

(Playwright מייצר אותן לבד. ה-baselines הם רק ה-`*chromium/*.png` בלי `actual` או `diff` בשם.)
</step>

<step name="handle_baseline_updates">
כשמשנים UI בכוונה (feature חדש, redesign), צריך לעדכן baselines:

```bash
# 1. Create dedicated branch
git checkout -b chore/snapshot-baseline-v2

# 2. Update only the relevant snapshot
npm run e2e:update-snapshots -- visual.spec.ts -g "dashboard matches baseline"

# 3. Review the diff (visual)
# Open the .diff.png files in e2e/visual.spec.ts-snapshots/chromium/

# 4. If looks correct, commit
git add e2e/visual.spec.ts-snapshots/
git commit -m "chore: update dashboard visual baseline for new widget"

# 5. PR with label
gh pr create --label "visual:baseline"
```

**Anti-patterns:**

- ❌ `update-snapshots` ב-PR רגיל — מסתיר שינויים לא רצויים
- ❌ `update-snapshots` בלי label — קשה לסקור אחר כך
- ❌ `update-snapshots` בלי `git diff` ויזואלי
- ✅ תמיד `update-snapshots -- -g "specific test name"`
- ✅ תמיד branch ייעודי + label
- ✅ תמיד eyeball את ה-diff.png

**מתי לא לעדכן baseline:**
- ההבדל הוא משהו שלא התכוונת לשנות (regression)
- ההבדל נראה שגוי (שכחת לעדכן CSS, נשבר עיצוב)
- ההבדל הוא באזור דינמי (timestamp, user data) — תוסיף `mask` במקום
</step>

<step name="run_and_verify">
הרץ את ה-visual tests:

```bash
npm run e2e:chromium -- visual.spec.ts
```

**הצלחה (baselines קיימים, אין שינוי):**

```
Running 3 tests using 1 worker
  ✓ visual.spec.ts (12s)
    ✓ login page matches baseline
    ✓ dashboard matches baseline
    ✓ signup page matches baseline
  3 passed (15s)
```

**כישלון (UI השתנה):**

```
Running 3 tests using 1 worker
  ✘ visual.spec.ts (12s)
    ✘ login page matches baseline
      Error: Screenshot comparison failed
      342 pixels (ratio 0.0021 of all image pixels) are different.
      ...
```

**מה לעשות:**
1. הרץ `npm run e2e:report`
2. פתח את ה-report
3. צפה ב-`Actual` vs `Expected` vs `Diff`
4. אם השינוי רצוי → עדכן baseline (ראה step למעלה)
5. אם לא רצוי → תקן את הקוד

**ה-baselines נשמרים per-browser** — `e2e/visual.spec.ts-snapshots/chromium/login.png`, `e2e/visual.spec.ts-snapshots/firefox/login.png`, וכו'. זה נכון — Firefox ו-Chromium מרנדרים אחרת, ו-baselines נפרדים מבטיחים cross-browser consistency.
</step>

</steps>

<output>
## Artifacts
- `e2e/visual.spec.ts` — 3-7 tests על critical screens
- `e2e/visual.spec.ts-snapshots/` — baselines (per browser)
- `playwright.config.ts` — `expect.toHaveScreenshot` config
- `.gitignore` — excludes `*.actual.png` + `*.diff.png`
- `package.json` — `e2e:update-snapshots` script (already added in setup)

## Verification
```bash
# 1. Run visual tests
npm run e2e:chromium -- visual.spec.ts
# Expected: 3+ pass

# 2. Intentionally break a baseline (sanity check)
# Edit dashboard page CSS, re-run
# Expected: visual.spec.ts fails with diff link

# 3. Restore CSS, re-run
# Expected: visual.spec.ts passes again

# 4. Update baseline properly
git checkout -b chore/snapshot-baseline-v2
npm run e2e:update-snapshots -- visual.spec.ts -g "dashboard"
git diff e2e/visual.spec.ts-snapshots/  # eyeball
git add . && git commit -m "chore: visual baseline v2"
```

**Storage:** baselines ב-git, `.actual.png` + `.diff.png` ב-`.gitignore`.
</output>

<acceptance-criteria>
- [ ] `e2e/visual.spec.ts` כולל 3-7 tests על critical screens
- [ ] `playwright.config.ts` כולל `expect.toHaveScreenshot` עם `maxDiffPixels: 100`
- [ ] כל test מחכה ל-`document.fonts.ready` + `networkidle`
- [ ] Dynamic content מוסתר עם `mask: [...]`
- [ ] Baselines קיימים ב-`e2e/visual.spec.ts-snapshots/`
- [ ] `.actual.png` + `.diff.png` ב-`.gitignore`
- [ ] תיעוד ב-PR עם label `visual:baseline` בכל עדכון
- [ ] לא מעל 7 screens (anti-pattern: כל page)
- [ ] לא מעל animation/loading states
</acceptance-criteria>

*Built with Skillsmith*
