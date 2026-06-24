# Task: /build-product ship — Pre-ship review, smoke, commit, deploy

<purpose>
Final gate before a feature or product goes to production. Enforces code review + smoke test + commit + deploy with verification. Does NOT skip steps even if the user says "just ship it".
</purpose>

<user-story>
As the user with a "done" feature, I want a pre-ship gate that catches secrets, missing tests, and unreviewed code, so that I can ship to production without waking up to a 2am page.
</user-story>

<when-to-use>
- "תשחרר" / "ship it" / "אני רוצה לפרודקשן"
- Feature is "done" in code; needs pre-production verification
- About to merge to main / deploy to production
</when-to-use>

<prerequisites>
- Feature complete + all tests green in dev
- Working build artifact exists
- Target environment is known (staging URL, prod URL, Electron build target, etc.)
</prerequisites>

<references>
@../frameworks/routing-map.md
@../frameworks/loops.md (Loops 4 + 7 — pre-ship quality + reflection)
@../frameworks/user-defaults.md (security/secrets checks)
@requesting-code-review (load on demand — code review pass)
@incremental-hardening-refactor (load on demand — if shipping requires hardening)
</references>

<steps>

<step name="preflight_deployment_checklist" priority="first">
**The 4-item pre-deploy checklist. All 4 must be ✅ before declaring a build "shipped":**

1. **README.md** — exists, contains:
   - "מה זה עושה (2 שורות)" — what it does
   - "איך מתחילים (3-5 פקודות)" — how to start
   - "מה ה-API (אם יש)" — API surface
   - "איך להתקין מחדש" — how to reinstall

2. **.env.example** — exists, contains ALL required env vars with placeholder values. NO real secrets. Check:
   ```bash
   test -f .env.example || echo "❌ .env.example missing"
   grep -E "^(OPENAI|SUPABASE|GITHUB|STRIPE|CLOUDFLARE|ANY_OTHER_KEY)=" .env.example || echo "⚠️  no provider keys listed"
   ```

3. **Health endpoint** — `GET /health` returns 200 with `{"ok": true, ...}`. Verify against the deployed URL:
   ```bash
   curl -fsS https://[staging-or-prod-url]/health | jq .  # should return ok:true
   ```

4. **Smoke test passes** — both `e2e-testing` (Loop 3 + Loop 10) AND `dogfood` (Loop 17) both pass against the deployed URL.

**If any of the 4 is missing, the skill refuses to ship — block, not warn.**
</step>

<step name="preflight_no_secrets">
```bash
grep -rE "(api[_-]?key|password|secret|token).*=.*['\"][a-zA-Z0-9]{16,}" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" .
```

If matches → STOP. Move secrets to env vars / secret manager. See `user-defaults.md` for the secrets rule.
</step>

<step name="preflight_no_debug_code">
```bash
grep -rnE "console\.log\(|debugger|TODO:|FIXME:" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ apps/
```

If matches in production-bound code → STOP. Remove or convert to proper logging.
</step>

<step name="preflight_no_untracked_files">
```bash
git status --short
```

If untracked source files → STOP. Either commit them or `.gitignore` them.
</step>

<step name="preflight_tests_pass">
Run the project's test command (from `package.json` / `pytest` / etc.). Must be GREEN.

If ANY of `preflight_*` steps FAIL → route to `stuck-recover.md` (classification: "לא יודע מה לעשות" → scope cut).
</step>

<step name="code_review">
Load `requesting-code-review`. See `@../frameworks/loops.md` Loop 4 (Pre-Ship Quality) for the bounded-review loop on CRITICAL findings.

Apply the code-review skill to the branch/diff being shipped. Address every CRITICAL finding before proceeding. MAJOR findings → ask the user, do not silently fix. MINOR findings → file as follow-ups, do not block ship.
</step>

<step name="build_artifact">
Run the production build command:
- Web/Next.js: `npm run build` (or `pnpm build`)
- Electron: `npm run dist:win` / `npm run dist:mac`
- Python backend: `pip install -e .` + verify entry point
- CLI: package via the project's chosen method

Verify the artifact actually exists (file size > 0, opens if applicable).
</step>

<step name="deploy_to_staging">
If the product has a managed HTTPS backend → deploy to staging FIRST.
- Web: push to staging branch / Vercel preview
- Backend: deploy to staging service
- Desktop: package, then test on a clean VM
</step>

<step name="real_user_smoke_test">
Open the product in its real environment. Verify the user's happy path actually works:
- Login (if applicable) → main screen → core action → expected output
- For voice products: real conversation test (not just unit tests on transcript)
- For desktop apps: launch from cold start, perform the core action, quit cleanly
- For web apps: `browser_navigate` to staging URL, perform the flow, `browser_vision` to confirm visual state

**If smoke fails → STOP → `stuck-recover.md`. Do not deploy broken code.**
</step>

<step name="user_approves_ship">
**Mandatory gate.** Show the user:
- Branch / build hash being deployed
- List of commits in this release
- Smoke test result (screenshot or transcript)
- Any MAJOR review findings still open

**Wait for the user to say "go" / "שחרר" / "כן".**
</step>

<step name="deploy_to_production">
Trigger the production deploy via the project's chosen mechanism:
- Git merge to main (if auto-deploy)
- Manual deploy via hosting platform CLI
- Electron signed package upload
- etc.
</step>

<step name="post_deploy_verification">
Within 5 minutes of deploy:
- Curl the production health endpoint
- Open the production URL in a browser
- Run one user flow end-to-end
- Check error rates / logs for spikes

If ANY anomaly → STOP → `stuck-recover.md`.
</step>

<step name="tag_release">
```bash
git tag -a v1.X.Y -m "ship: [one-line summary]"
git push origin v1.X.Y
```
</step>

<step name="marketing_assets">
**Loop 19 — Marketing Asset Build.** Before announcing the launch, make sure the repo has marketing assets. Skip this step only when the user explicitly says "internal only" or "no marketing".

1. **Pick the reference design** — invoke `popular-web-designs` and choose one of the 54 production design systems that matches the product's audience (e.g. Stripe for SaaS, Linear for productivity, Vercel for dev tools). Save the rendered template to `marketing/landing-template.html`.
2. **Build video assets with hyperframes** — write an HTML composition per asset (hero demo 30-60s, social card 1200×630, explainer). Render to MP4 via `hyperframes`. Output directory: `marketing/assets/<name>/`.
3. **Smoke test** — `ffprobe marketing/assets/hero/demo.mp4` must show a valid duration. Open the landing template in a browser and verify it renders without console errors.
4. **Document in marketing/README.md** — list each asset, its purpose, and where it's used (landing page, tweet, Product Hunt).

```bash
# Render the hero demo
hyperframes compose marketing/compositions/hero.html --output marketing/assets/hero/demo.mp4

# Smoke test
ffprobe marketing/assets/hero/demo.mp4 2>&1 | grep Duration
```
</step>

<step name="update_state_file">
Update `.hermes/build-product/state.md`:
```markdown
## Last shipped
- YYYY-MM-DD: v1.X.Y — [one sentence summary]
- Verified: [smoke test result]
- Open follow-ups: [list of MAJOR review items + intentional TODOs]
```
</step>

<step name="report_to_user">
Send a 5-line summary:
1. What shipped
2. Where it lives (URL / build artifact / version)
3. Smoke test result
4. Open follow-ups
5. Next suggested action
</step>

<step name="reflection_loop">
See `@../frameworks/loops.md` Loop 7 (Build Reflection). After the user confirms ship, spawn one reflection subagent to extract 3 reusable lessons from the session. The user approves which lessons get persisted to Skill Candidates or project memory.
</step>

</steps>

<output>
A shipped production deployment:
- All 4 deployment checklist items ✅ (README, .env.example, /health, smoke + dogfood pass)
- No secrets in code
- No debug code
- All tests green
- Code reviewed (requesting-code-review skill or peer)
- Merged to main
- Deployed to production
- `.hermes/build-product/state.md` updated with `shipped: true`
</output>

<acceptance-criteria>
- [ ] Deployment checklist (`preflight_deployment_checklist`) all 4 items pass
- [ ] No secrets in code (`preflight_no_secrets`)
- [ ] No debug code in production-bound code (`preflight_no_debug_code`)
- [ ] No untracked files (`preflight_no_untracked_files`)
- [ ] All tests green (`preflight_tests_pass`)
- [ ] `e2e-testing` smoke tests pass (Loop 3 + Loop 10)
- [ ] `dogfood` exploratory QA passes (Loop 17)
- [ ] Code reviewed (requesting-code-review OR peer)
- [ ] Loop 4 (Pre-Ship Quality) ran and returned OK
- [ ] Loop 7 (Reflection) ran after the ship — lessons captured
- [ ] User approved the final deploy
- [ ] `state.md` updated with `shipped: true`
</acceptance-criteria>
