# Task: /build-product new — Start a brand-new product from scratch

<purpose>
Walk the user from "I want to build X" to a working repo with a first vertical slice. Routes to existing Hermes skills; does not re-invent their logic.
</purpose>

<user-story>
As a user with a product idea, I want a guided path from idea to deployed first slice, so that I can ship something working without re-inventing the build pipeline.
</user-story>

<when-to-use>
- "I want to build [app/site/tool]"
- "I'm starting a new repo from scratch"
- "I have an idea but no code yet"
</when-to-use>

<prerequisites>
- The user can describe the idea in 1-2 sentences (Hebrew or English)
- Working directory is known (current repo or new dir)
- No committed code yet for this product (or empty repo)
</prerequisites>

<references>
@../frameworks/loops.md (load whenever a phase might spin or produce uncertain output)
@../frameworks/routing-map.md (master decision tree)
@../frameworks/user-defaults.md (stack/security/language defaults)
</references>

<steps>

<step name="quick_orientation" priority="first">
Before invoking any other skill, answer these four questions yourself by reading the current repo and asking the user only the gap-fillers:

1. **Is there any code yet?** Run `ls` and `git log --oneline -10`. If empty / no commits → truly new.
2. **What stack does the user want?** Check `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`. If nothing exists, ask: web/desktop/CLI/mobile?
3. **What language does the user prefer for this build?** Default = TS/Node for web/desktop, Python for backend/data. Override only if the user says otherwise.
4. **Does this need a managed HTTPS backend?** Default = YES if any of: login, billing, mobile sync, multi-user, push notifications. NO = pure local-only product (a desktop product model).

If you can't answer one of these, ask the user ONE focused question. Do not ask four separate questions.
</step>

<step name="five_mandatory_questions">
**This step is non-skippable.** Before any plan, code, or scaffold is generated, the user must fill the 5-question template. This is the gate that prevents building the wrong product.

If the user's original request is shorter than 3 sentences, route to `amrita-architect` first (Loop 15) for ≤3 high-value clarification questions, then return here.

Ask the user to fill this template verbatim (in Hebrew or English):

```
## מה: [2-3 sentence description — what is being built]
## למי: [user / customer / internal / 3rd party]
## איפה: [web / desktop / API / WhatsApp / voice / mobile]
## הצלחה = [one checkable assertion that can be run + observed]
## בהיקף: [concrete list — what gets built]
## מחוץ להיקף: [concrete list — what does NOT get built]
```

**Rules:**
- If the user answers "I don't know" or "you decide" for any question, write an explicit assumption in the plan — do NOT silently swallow.
- The "הצלחה" (success criterion) MUST be runnable + observable. "It works" is not a criterion. "GET /health returns 200 with {ok: true}" is.
- The "מחוץ להיקף" list is enforced as a hard "do not do" — if a follow-up question tries to expand scope mid-build, stop and re-anchor to this list.
- Save the filled template to `.hermes/build-product/intake-5q.md` for reference.

**Wait for user to fill the template** before continuing.
</step>

<step name="hermes_config_validation">
If the project depends on any Hermes built-in provider (TTS, STT, MCP, plugin, personality) OR builds a non-gateway frontend on top of Hermes, route to `hermes-config-validation` BEFORE any code is written. This catches silently-ignored config keys and tools with no public HTTP endpoint.

Skip this step if the project does not touch Hermes built-ins.
</step>

<step name="spike_if_fuzzy">
Load `spike` skill ONLY if the idea is fuzzy. Goal: throwaway prototype to validate feasibility. Output: 1 paragraph verdict ("feasible / not feasible / needs more research") + 1 small artifact in `tmp/` or `.spike/`. Throw the artifact away.

Skip this step if the user says: "I know exactly what I want" or "this is just like X but for Y".
</step>

<step name="scaffold_project">
**Before writing any feature code**, run the right scaffold script. This is a 30-second step that produces a complete, bootable, linted, tested project skeleton.

**Pick by stack detection:**

| Stack signal | Script to run |
|---|---|
| `package.json` exists, or the project is TS/Node/Next/web | `bash $HERMES_HOME/skills/software-development/build-product/frameworks/scripts/scaffold-node.sh [project-name]` |
| `requirements.txt` / `pyproject.toml` exists, or the project is Python | `bash $HERMES_HOME/skills/software-development/build-product/frameworks/scripts/scaffold-python.sh [project-name]` |
| Other (Go, Rust, etc.) | Use that language's own scaffold — not in this skill's scope |

**After scaffold, verify with the smoke test (1 line):**
```bash
cd [project-name] && npm run dev  # Node
# OR
cd [project-name] && uvicorn src.main:app --reload  # Python
# Then:
curl http://localhost:3000/health  # Node (3000)
curl http://localhost:8000/health  # Python (8000)
```
</step>

<step name="pick_israeli_extensions">
**[vault-only]** — the Israeli-feature skills below live in the developer's local Hermes vault. If unavailable, skip this step (product will be built without Israeli-specific extensions).

**Only when the product targets Israeli users** (Hebrew UI, Israeli market, Israeli business workflows). Otherwise skip this step.

Based on the brief from `five_mandatory_questions`, decide which Israeli-feature skills to wire in:

| Brief signal | Skill to load | When to use it |
|---|---|---|
| Product needs voice/IVR (call center, hotline, voicemail triage) | `hebrew-voice-bot-builder` | During `execute_first_slice` — implement IVR alongside auth flow |
| Product needs WhatsApp as a channel (orders, support, alerts) | `greenapi-whatsapp-bot-builder` | During `execute_first_slice` — wire WhatsApp webhook alongside the first API route |
| Product automates Israeli business ops (invoicing, scraping banks, scheduling) | `n8n-hebrew-workflows` | After MVP — design the workflow triggers and hand off to n8n |
| Deploys will land during Israeli business hours | `shabbat-aware-scheduler` | Wire into `deploy-to-cloudflare` task via the `shabbat_deploy_check` step |
| Landing page or marketing for Israeli audience | `creative/popular-web-designs` + `creative/hyperframes` | During `marketing_assets` step in `ship.md` |

**Document the picks** in `.hermes/build-product/state.md` under a new section `## Israeli extensions`:
```markdown
## Israeli extensions
- [x] hebrew-voice-bot-builder — call-center hotline for the main product
- [ ] greenapi-whatsapp-bot-builder — deferred to v1.5
- [x] shabbat-aware-scheduler — wired into deploy
```

Do NOT load a skill "just because it exists". Each pick must trace back to a concrete brief signal.
</step>
If the health endpoint does not return 200, **stop and fix the scaffold before writing any feature code.** A broken scaffold is the #1 cause of "I can't get it running" 30 minutes into a build.
</step>

<step name="product_brief">
Load `plan` skill in plan-mode. Goal: produce `.hermes/plans/YYYY-MM-DD_<slug>.md` with:

```markdown
# Product Brief: [name]

**Goal:** [one sentence — what user can now do]
**For:** [persona — who is this for]
**Out of scope:** [3-5 things explicitly NOT in v1]

## v1 vertical slices (in priority order)
1. [Slice A — smallest user-visible value]
2. [Slice B — extends A]
3. [Slice C — extends B]

## Stack decision
- Frontend: [Next.js / Electron+Vite+React / CLI / etc.]
- Backend: [managed HTTPS / local-only / none]
- DB: [managed Postgres / SQLite / none]
- Auth: [Neon Auth / Clerk / Supabase / none]
- Hosting: [Vercel + managed backend / VPS / Docker host]

## Open questions for the user
- [blocking question 1]
- [blocking question 2]
```

**Wait for user approval** of the brief before continuing.
</step>

<step name="architecture_and_first_slice_plan">
Load `writing-plans`. After plan is written, see `@../frameworks/loops.md` Loop 1 (Plan Quality) for the auto-validation step.

Take the approved brief and produce a bite-sized implementation plan for **the FIRST vertical slice only** (not all slices). Each task = 2-5 min of focused work. Include exact file paths and test commands. See `writing-plans` SKILL.md for the format.

This is the first plan; later plans will be created per-slice as the build progresses. Do NOT pre-plan all slices at once — that violates vertical-slice discipline.

**Wait for user approval** of the first-slice plan before continuing.
</step>

<step name="execute_first_slice">
Load `subagent-driven-development`. See `@../frameworks/loops.md` Loop 2 (Builder-Reviewer) for the per-task reviewer subagent pattern.

Execute the plan task-by-task via fresh subagents with 2-stage review. See `subagent-driven-development` SKILL.md for the loop.

**Hard rules during execution:**
- Tests FIRST (RED-GREEN-REFACTOR via `test-driven-development` skill) for any behavior change
- One subagent per task; no parallel edits to the same file area
- After every 3-5 tasks: run the full repo test/build command before continuing
- Commit after every GREEN step (per `writing-plans` format)
- If a task fails twice → STOP, do not loop forever → switch to `stuck-recover.md`
</step>

<step name="auth_and_rls_setup">
**Skill to load:** `supabase-auth-patterns` (only if the product needs user accounts).

**When this phase is required:**
- Product brief says "users can sign up", "save to user account", "multi-user"
- Stack decision includes Supabase, Clerk, Neon Auth, or any managed auth provider
- The first vertical slice exposes ANY user-specific data (even read-only)

**If product is local-only / single-user / no auth:** skip this entire phase.

**What to do:**
1. Load `supabase-auth-patterns` skill
2. Run `/supabase-auth email` first (always — simplest)
3. Run `/supabase-auth google` (90% of products)
4. Run `/supabase-auth apple` ONLY if iOS native app or regulatory requirement
5. Run `/supabase-auth rls` — **CRITICAL: do this before the first user can sign up**
6. Verify the RLS auto-enable trigger is installed
7. Test with a non-authenticated client that protected tables return empty

**Hard rule:** RLS must be enabled BEFORE `review_and_smoke` — never ship a Supabase table to production without RLS. The `supabase-auth-patterns` skill's `tasks/configure-rls-policies.md` opens with an audit of all unprotected tables.

**Acceptance:**
- [ ] At least Email/Password works end-to-end
- [ ] Google sign-in works (if enabled)
- [ ] Apple sign-in works (if enabled)
- [ ] RLS enabled on every public table
- [ ] Tested: anon role gets 0 rows from protected tables
- [ ] Tested: authenticated role gets only own data
- [ ] `proxy.ts` exists at project root (Next.js 15) or `middleware.ts` (Next.js ≤14)
- [ ] `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in env, but `SUPABASE_SECRET_KEY` is server-only
</step>

<step name="review_and_smoke">
Load `requesting-code-review` (for the diff), then smoke test on a real artifact. See `@../frameworks/loops.md` Loop 3 (Smoke Retry) for retry-on-fail semantics and Loop 4 (Pre-Ship Quality) for CRITICAL-finding handling.

**Sub-step A: Code review**
Load `requesting-code-review` skill. Run it on the branch with all first-slice commits. Apply any CRITICAL fixes immediately.

**For auth-related changes specifically:** also run the `supabase-auth-patterns/frameworks/pitfall-catalog.md` against the diff. The 10 pitfalls cover ~80% of common auth bugs.

**Sub-step B: Smoke test**
Open the product (browser / run the binary / curl the endpoint). Verify the first vertical slice actually works end-to-end with a real user interaction. No "tests pass" without "I tried it and it worked".

**If product is local-only (a desktop product model):** spawn Electron app, hit the local API, paste some text, verify cleanup.
**If product is web/managed:** deploy to staging first, curl `/health`, run the user flow in `browser_navigate` + `browser_vision`.

**If auth was set up in `auth_and_rls_setup`:** smoke test MUST include:
- [ ] Sign up with email → confirmation email → sign in
- [ ] Sign in with Google (if enabled)
- [ ] Sign in with Apple (if enabled)
- [ ] Sign out clears cookies
- [ ] Protected route blocks unauthenticated users
- [ ] User can only see their own data (RLS verification)
</step>

<step name="decide_next_step">
After slice #1 is shipped + verified, ask the user:

| Choice | Route to |
|--------|----------|
| "תוסיף slice #2" | `build-feature.md` task |
| "[user-directive] stop — resume tomorrow" | Save state to `.hermes/build-product/state.md` and exit |
| "יש בעיה / אני תקוע" | `stuck-recover.md` task |
| "תשחרר את זה לפרודקשן" | `ship.md` task |
| "תעלה לי את זה ל-Cloudflare" (default) | `deploy-to-cloudflare.md` task |

**Default next step after ship is verified:** auto-route to `/build-product deploy` unless the user says "skip deploy" or "local only". The deploy task creates a secure temp URL on Cloudflare Workers with Cloudflare Access protection (username + password) and sends the user the URL + credentials. This is what makes "I just built a thing" → "I have a working demo URL" in 2 minutes.

**Wait for user choice** before continuing.
</step>

<step name="auto_deploy_cloudflare">
**If the product is deployable** (web app, API, static site) **and the user hasn't said "skip deploy"** → auto-route to `@tasks/deploy-to-cloudflare.md` (the source of truth for the deploy flow). That task handles:

- Detecting the product type (Next.js 15 → `cloudflare-deploy/tasks/deploy-nextjs-fullstack`; static → `deploy-static-site`; single Worker → `deploy-worker-script`)
- Building the project, deploying to Cloudflare, configuring env vars + secrets
- **Cloudflare Access protection** (one-time PIN via email — NON-NEGOTIABLE for temp URLs)
- Sending the user the report (URL + access email + deployment ID + rollback command)

**If the product is a CLI tool, library, or desktop-only app** → skip this step. Note in state.md "not deployable".

**For full details on the deploy flow, see `@tasks/deploy-to-cloudflare.md`.**
</step>

</steps>

<output>
A working repo with the first vertical slice shipped + deployed:
- `package.json` / `pyproject.toml` (created by scaffold script)
- `src/index.ts` or `src/main.py` (or feature equivalent)
- Health endpoint at `/health`
- README.md with 4 sections (from ship.md `preflight_deployment_checklist`)
- `.env.example` with all required keys
- One working test (smoke test passes)
- One `git commit` on main
- Optional: deployed to Cloudflare with a temp URL
</output>

<acceptance-criteria>
- [ ] The 5-question template was filled (מה / למי / איפה / הצלחה / בהיקף+מחוץ)
- [ ] Vague ideas routed through amrita-architect first (Loop 15)
- [ ] Hermes config validated if project uses built-in providers (Loop 16)
- [ ] Stack chosen (web / desktop / API / mobile)
- [ ] Scaffold script ran successfully (Node or Python)
- [ ] `curl /health` returns 200 on the scaffolded project
- [ ] First vertical slice defined and built (TDD: test first, code second)
- [ ] `git commit` made
- [ ] `.hermes/build-product/state.md` initialized with the current slice
- [ ] Optional: Cloudflare deploy with temp URL
- [ ] Optional: dogfooded against the deployed URL (Loop 17)
</acceptance-criteria>
