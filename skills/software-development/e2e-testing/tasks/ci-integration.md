<purpose>
לחבר את Playwright E2E tests ל-CI: GitHub Actions (matrix browsers, sharding, artifact upload) או GitLab CI (docker-in-docker, cache, artifacts). המטרה: tests רצים בכל PR ב-7-10 דקות ומעלים artifacts של failures ל-inspection.
</purpose>

<user-story>
As a the user שמעלה PRs כל יום, אני רוצה ש-E2E tests ירוצו אוטומטית בכל PR, ידווחו על failures עם screenshots + traces, ולא יעברו את ה-10 דקות timeout, so that אני יכול לסמוך על "CI ירוק = safe to merge".
</user-story>

<when-to-use>
- User אומר "תחבר את הטסטים ל-GitHub Actions"
- User אומר "תוסיף E2E ל-GitLab CI"
- אחרי `setup` + `smoke` — בלי CI, הטסטים לא באמת קיימים
- מעבר מ-travis/circleci ל-GH Actions / GitLab
- Entry point routes here via `/e2e-testing ci`
</when-to-use>

<context>
@tasks/setup-playwright.md (חובה — config חייב להיות קיים)
@tasks/write-smoke-tests.md (חובה — חייבים להיות tests)
</context>

<references>
@frameworks/ci-patterns.md (matrix browsers, sharding, secrets, storage)
@frameworks/auth-in-tests.md (service role keys, test DB URLs)
</references>

<steps>

<step name="detect_ci_provider" priority="first">
בדוק באיזה CI הפרויקט:

```bash
ls -la .github/workflows/ 2>/dev/null
ls -la .gitlab-ci.yml 2>/dev/null
ls -la .circleci/config.yml 2>/dev/null
ls -la .travis.yml 2>/dev/null
```

| קיים | מה לעשות |
|---|---|
| `.github/workflows/*` | צור/עדכן `playwright.yml` |
| `.gitlab-ci.yml` | הוסף `e2e:` job |
| `.circleci/config.yml` | הוסף job — ראה `@frameworks/ci-patterns.md` |
| `.travis.yml` | הוסף `npm run e2e` stage |
| כלום | צור `.github/workflows/playwright.yml` (default) |

**שאל את the user:** GitHub Actions (default) או GitLab CI?
</step>

<step name="gather_secrets">
לפני יצירת ה-workflow, צריך:

**חובה ב-CI secrets:**

| Secret | שימוש | דוגמה |
|---|---|---|
| `BASE_URL` | URL של האפליקציה ב-staging | `https://staging.example.com` |
| `SUPABASE_URL` | אם Supabase — admin operations | `https://xxx.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | confirm email אוטומטי | `sb_secret_...` |
| `MAILOSAUR_API_KEY` | אם Mailosaur — fetch verification email | `xxx` |
| `MAILOSAUR_SERVER_ID` | Mailosaur inbox | `xxx` |
| `TEST_USER_EMAIL` | user קבוע ל-storage state | `e2e@example.com` |
| `TEST_USER_PASSWORD` | password ל-user | `xxx` |

**חשוב — secrets לא ב-`vars`, רק ב-`secrets`:**

```yaml
env:
  BASE_URL: ${{ secrets.STAGING_URL }}  # ← secret, not var
  CI: true
```

**הסבר:** GitHub Actions `vars` גלוי לכל ה-collaborators. secrets מוצפן.

**שאל את the user:** איזה auth provider, ואיזה testing email service.
</step>

<step name="create_github_actions_workflow">
צור `.github/workflows/playwright.yml`:

```yaml
name: Playwright E2E

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

# Cancel in-progress runs for the same branch
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    timeout-minutes: 15
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        shard: [1/4, 2/4, 3/4, 4/4]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright Browsers
        run: npx playwright install --with-deps

      - name: Generate storage state (once)
        env:
          BASE_URL: ${{ secrets.STAGING_URL }}
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: npx playwright test --project=setup

      - name: Run Playwright tests
        env:
          BASE_URL: ${{ secrets.STAGING_URL }}
          CI: true
        run: npx playwright test --shard=${{ matrix.shard }}

      - name: Upload Playwright Report
        uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with:
          name: playwright-report-${{ matrix.shard }}
          path: playwright-report/
          retention-days: 7

      - name: Upload Test Results
        uses: actions/upload-artifact@v4
        if: ${{ failure() }}
        with:
          name: test-results-${{ matrix.shard }}
          path: test-results/
          retention-days: 3

      - name: Annotate PR with failures
        if: failure() && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const path = require('path');
            const resultsDir = 'test-results';
            if (!fs.existsSync(resultsDir)) return;

            const failedTests = [];
            for (const testDir of fs.readdirSync(resultsDir)) {
              const errorFile = path.join(resultsDir, testDir, 'error-context.md');
              if (fs.existsSync(errorFile)) {
                failedTests.push(fs.readFileSync(errorFile, 'utf8'));
              }
            }

            if (failedTests.length > 0) {
              const body = '## ❌ E2E Tests Failed\n\n' +
                failedTests.map(t => '<details><summary>Test failure</summary>\n\n```\n' + t + '\n```\n</details>').join('\n');
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body
              });
            }
```

**הסבר ההגדרות החשובות:**

| Setting | Value | למה |
|---|---|---|
| `concurrency.cancel-in-progress` | `true` | ריצה חדשה באותו branch מבטלת ריצה קודמת — חוסך CI minutes |
| `timeout-minutes` | `15` | hard cap, מונע תלייה |
| `fail-fast` | `false` | shards רצים עד הסוף גם אם shard אחד נכשל |
| `matrix.shard` | `1/4..4/4` | 4 shards = ריצה מקבילית |
| `node-version` | `'20'` | LTS, Playwright תואם |
| `cache: 'npm'` | — | cache `node_modules` בין ריצות — חוסך 1-2 דקות |
| `npx playwright install` | `--with-deps` | גם browsers, גם system libs |
| `if: ${{ !cancelled() }}` | — | מעלה report גם בכישלון (לא רק success) |
| `if: ${{ failure() }}` | — | מעלה test-results רק בכישלון |
| `retention-days: 7` | — | report נשמר 7 ימים (מספיק לדיבאג, לא נצבר) |
</step>

<step name="add_workflow_to_gitignore_alternatives">
ודא ש-`.gitignore` תקין:

```gitignore
# Playwright
.auth/
playwright-report/
test-results/
blob-report/
playwright/.cache/

# Don't ignore baselines
!e2e/**/*.snap.png
!e2e/**/*-snap.png
```

**ה-baselines של visual regression** (`*chromium/*.png` ב-`visual.spec.ts-snapshots/`) **כן** committed.
**ה-`*.actual.png` ו-`*.diff.png` לא** committed.
</step>

<step name="verify_ci_locally">
לפני push, בדוק מקומית ש-CI יעבוד:

```bash
# 1. Simulate CI environment
CI=true BASE_URL=https://staging.example.com npx playwright test

# 2. Check that storage state generation works
CI=true BASE_URL=https://staging.example.com npx playwright test --project=setup

# 3. Run a single shard
CI=true BASE_URL=https://staging.example.com npx playwright test --shard=1/4

# 4. Check artifacts
ls playwright-report/
ls test-results/
```

**אם הכל עובד מקומית — push ו-watch:**

```bash
git add .github/workflows/playwright.yml
git commit -m "ci: add Playwright E2E workflow"
git push
```

**אחרי push:**
1. עבור ל-`https://github.com/<user>/<repo>/actions`
2. ראה את הריצה
3. אם נכשל → לחץ על ה-shard שנכשל → Download artifact → `playwright-report-1-4.zip`
4. פתח את `index.html` בתוך ה-zip → ראה את ה-failure עם screenshot + trace
</step>

<step name="create_gitlab_ci_yml">
אם הפרויקט על GitLab, צור `.gitlab-ci.yml`:

```yaml
stages:
  - test

variables:
  BASE_URL: $STAGING_URL
  CI: "true"

e2e:
  stage: test
  image: mcr.microsoft.com/playwright:v1.49.0-noble
  parallel: 4
  timeout: 15 minutes

  services:
    - name: docker:dind
      alias: docker

  before_script:
    - npm ci --cache=.npm --prefer-offline

  script:
    - npx playwright install --with-deps
    - npx playwright test --shard=${CI_NODE_INDEX}/${CI_NODE_TOTAL}

  artifacts:
    when: always
    paths:
      - playwright-report/
    reports:
      junit: playwright-report/results.xml
    expire_in: 7 days
    name: "playwright-report-${CI_NODE_INDEX}-${CI_NODE_TOTAL}"

  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - .npm/
      - node_modules/
      - ~/.cache/ms-playwright/
```

**הסבר:**

| Setting | Value | למה |
|---|---|---|
| `image` | `mcr.microsoft.com/playwright:...` | Playwright Docker image — browsers + deps מותקנים |
| `parallel: 4` | — | 4 מכונות במקביל |
| `CI_NODE_INDEX` | env auto | GitLab מזין 1..4 |
| `services: docker:dind` | — | רק אם צריך DB container |
| `artifacts.when: always` | — | גם בכישלון |
| `expire_in: 7 days` | — | תואם GH Actions retention |
| `reports.junit: ...` | — | GitLab UI מציג תוצאות ב-MR view |

**חסרון:** ה-image הרשמי של Playwright (~2GB) גדול. אלטרנטיבה: `image: node:20` + `npx playwright install --with-deps`.
</step>

<step name="add_status_badge">
הוסף status badge ל-`README.md`:

**GitHub Actions:**

```markdown
[![Playwright E2E](https://github.com/<user>/<repo>/actions/workflows/playwright.yml/badge.svg)](https://github.com/<user>/<repo>/actions/workflows/playwright.yml)
```

**GitLab CI:**

```markdown
[![E2E](https://gitlab.com/<user>/<repo>/badges/main/pipeline.svg)](https://gitlab.com/<user>/<repo>/-/pipelines)
```

**למה חשוב:** the user רואה בעמוד אחד אם ה-CI ירוק. אם אדום — יש בעיה.
</step>

</steps>

<output>
## Artifacts
- `.github/workflows/playwright.yml` — GitHub Actions workflow (4 shards, 15min timeout, artifacts)
- `.gitlab-ci.yml` — alternative: GitLab CI עם parallel matrix
- `.gitignore` — excludes test artifacts, keeps baselines
- `README.md` — status badge

## Verification
```bash
# 1. Workflow file exists
ls -la .github/workflows/playwright.yml

# 2. YAML valid
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/playwright.yml').read())"

# 3. Required secrets configured (manual)
# GitHub: Settings → Secrets and variables → Actions
# GitLab: Settings → CI/CD → Variables (type: masked)

# 4. Push and watch
git add .github/workflows/playwright.yml
git commit -m "ci: add Playwright E2E workflow"
git push

# 5. In repo Actions tab, verify all 4 shards complete in 7-10 min
```
</output>

<acceptance-criteria>
- [ ] `.github/workflows/playwright.yml` קיים (או `.gitlab-ci.yml`)
- [ ] Matrix עם 4 shards (או parallel: 4)
- [ ] `timeout-minutes: 15` (או `timeout: 15 minutes`)
- [ ] `concurrency.cancel-in-progress: true` (GH Actions)
- [ ] `npm ci` עם cache
- [ ] `npx playwright install --with-deps` כל ריצה
- [ ] Storage state נוצר ב-`--project=setup` לפני shards
- [ ] Artifacts: `playwright-report/` + `test-results/` בכישלון
- [ ] Secrets מוגדרים ב-CI (לא ב-`vars`)
- [ ] Status badge ב-README
- [ ] CI רץ ב-7-10 דקות (לא יותר)
</acceptance-criteria>

*Built with Skillsmith*
