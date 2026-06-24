# Task: /build-product deploy — Auto-deploy to Cloudflare with secure temp URL

<purpose>
Auto-deploy a finished product to Cloudflare after the smoke test passes. Produces a secure temporary URL on `*.workers.dev` (or `*.pages.dev`), protects it with Cloudflare Access (username + password), sets environment variables + secrets, and returns the URL + credentials to the user. This is the default final step of every `/build-product new` and `/build-product feature`.
</purpose>

<user-story>
As a user who just finished building a product, I want one command (`/build-product deploy`) to push it to Cloudflare, get a temp URL, and have it password-protected, so that I can share a working demo with a client or tester in under 2 minutes — without me doing any manual Cloudflare work.
</user-story>

<when-to-use>
- "תעלה לי את זה ל-Cloudflare" / "deploy to Cloudflare"
- "תן לי URL זמני" / "תן לי קישור זמני"
- After `/build-product new` Phase 4 (smoke) passes successfully
- After `/build-product feature` Phase 4 (smoke) passes successfully
- After `/build-product ship` completes
- Auto-runs as **Phase 5.5 of build-feature** and **Phase 6 of new-product** (unless the user says "skip deploy")

NOT for: products that aren't meant to be deployed (CLI tools, libraries)
</when-to-use>

<context>
@../frameworks/user-defaults.md (Cloudflare deployment defaults)
@../frameworks/env-inventory-cf.md (what the user's account can do)
</context>

<references>
@software-development/cloudflare-deploy/SKILL.md (the full deployment skill)
@software-development/cloudflare-deploy/tasks/deploy-static-site.md (static sites)
@software-development/cloudflare-deploy/tasks/deploy-worker-script.md (single Worker)
@software-development/cloudflare-deploy/tasks/deploy-nextjs-fullstack.md (Next.js 15)
@software-development/cloudflare-deploy/tasks/protect-with-cloudflare-access.md (Access protection)
@software-development/cloudflare-deploy/frameworks/deployment-security-checklist.md
</references>

<steps>

<step name="decide_deployability" priority="first">
**Quick check:**
1. Is the product a web app, API, or static site? → Yes → deploy to Cloudflare
2. Is it a CLI tool, library, or desktop-only? → Yes → skip this task (note in state.md "not deployable")
3. Is the product already deployed elsewhere (Vercel, Fly.io, etc.)? → Yes → skip, ask the user if they want to migrate

**For 90% of products** (Next.js 15, React, Vite, Workers): **deploy to Cloudflare**.

If unclear, **ask the user** with one focused question: "תעלה לי את זה ל-Cloudflare?" vs "זה לא מוצר לפרודקשן".
</step>

<step name="shabbat_deploy_check">
**Loop 18 — Israeli Deploy Window.** Before running the deploy task, check that the current time is not inside Shabbat or a Yom Tov window.

```bash
# Load the shabbat-aware-scheduler skill and run a pre-deploy check
. $(hermes skill load shabbat-aware-scheduler --as-bash)
safe_window=$(shabbat-check-next-window --json | jq -r '.next_safe_window_unix')
now=$(date +%s)

if [[ "$now" -lt "$safe_window" ]]; then
  echo "⏸️ Deploy deferred — Shabbat/Yom Tov in effect."
  echo "Next safe window: $(date -d @$safe_window '+%A %H:%M')"
  echo "Resume /build-product deploy after this time, or override with --force-deploy-shabbat."
  # Write the safe window to state for resume later
  echo "deploy_safe_after=$safe_window" >> .hermes/build-product/state.md
  exit 0
fi
```

If the user wants to override (e.g. emergency hotfix during a chag), document the override in state.md:
```bash
echo "deploy_shabbat_override=$(date +%s) — user accepted responsibility" >> .hermes/build-product/state.md
```

**Skip this step** when the product is targeting users outside Israel, or when the user explicitly opts out of Shabbat-aware deploys.
</step>

<step name="choose_deploy_pattern">
Based on the product type, choose:

| Product type | Route to | Why |
|---|---|---|
| Static HTML / Vite / CRA / Astro / static Next.js | `@cloudflare-deploy/tasks/deploy-static-site.md` | Pages hosts static with no extra config |
| Single Worker script (API, edge function) | `@cloudflare-deploy/tasks/deploy-worker-script.md` | Workers is the right primitive |
| **Next.js 15 (App Router, full-stack)** | `@cloudflare-deploy/tasks/deploy-nextjs-fullstack.md` | Most common pattern — Workers + Static Assets |
| Other framework (SvelteKit, Nuxt, Remix) | Use the framework's Cloudflare adapter | Out of scope for this task |

**For Next.js 15 (default for most products)**: route to `deploy-nextjs-fullstack.md`. This is the most common path.
</step>

<step name="run_deploy_task">
The chosen `tasks/deploy-*.md` handles:
1. Verifying prerequisites
2. Setting up `wrangler.jsonc` (if not present)
3. Building the project (if static export)
4. Setting up the Workers subdomain (first deploy only)
5. Deploying via MCP or wrangler
6. Setting env vars + secrets
7. Verifying the URL works

**Auto-trigger:** the build-product state machine's `phase: shipped` should auto-route to `/build-product deploy` unless the user explicitly says "skip deploy" or "local only".
</step>

<step name="protect_with_cloudflare_access">
**Every temporary URL must be protected with Cloudflare Access** before the user sees it. A `*.workers.dev` URL is publicly accessible to anyone on the internet the moment you deploy.

Route to `@cloudflare-deploy/tasks/protect-with-cloudflare-access.md`. This handles:
1. Creating the Access Application
2. Adding a Policy (allow the user's email + one-time PIN, or service token for APIs)
3. Verifying the protection works
4. Documenting the Access App ID

**Hard rule:** don't send the URL until the Access Application is created and verified.
</step>

<step name="configure_env_vars_and_secrets">
If the product needs env vars (Supabase URL, API keys, etc.):

1. **Public env vars** (build-time `NEXT_PUBLIC_*`): set during `npm run build`, baked into the bundle
2. **Runtime env vars** (plain): set via `mcp_cloudflare_env_var_set` or `wrangler vars`
3. **Secrets** (encrypted): set via `mcp_cloudflare_secret_put` or `echo "..." | wrangler secret put`

For Supabase products: read `@supabase-auth-patterns/frameworks/env-vars-and-secrets.md` for the specific rules (Service Role Key goes in runtime secret, not `NEXT_PUBLIC_*`).
</step>

<step name="verify_deployment">
Run the deployment security checklist from `@cloudflare-deploy/frameworks/deployment-security-checklist.md`. All 5 questions must be YES:

1. Secrets are encrypted, not in source code
2. Cloudflare Access protects the temp URL
3. URL returns 200 and the expected content
4. Env vars are set, names match what the Worker expects
5. No errors in the Worker logs (first 60 seconds)

If any is NO, **fix and re-deploy** before reporting to the user.
</step>

<step name="send_deploy_report">
The deploy result is a single message with everything the user needs:

```text
✅ Deployed: <project-name>
🔗 URL: https://<project-name>.<subdomain>.workers.dev
🔒 Protected: Cloudflare Access (one-time PIN to <user's-email>)
📧 Access email: <user's-email>
🆔 Deployment ID: <uuid>
🆔 Access App ID: <uuid>
📋 Env vars: <N> plain + <M> secrets (names only)
⏰ Deployed: <ISO timestamp>
🔄 To rollback: <wrangler rollback command>

**To test:**
1. Visit the URL above
2. Enter your email (<user's-email>)
3. Check your inbox for a 6-digit PIN
4. Enter the PIN
5. You should see the app

Tell me if anything's wrong and I'll fix + redeploy.
```

**Save this report** to `.hermes/cf-deploy/<project-name>-<timestamp>.md` so future deploys have a record.
</step>

<step name="update_build_state">
After a successful deploy, update `.hermes/build-product/state.md`:

```markdown
## Last deployment
- URL: https://<project-name>.<subdomain>.workers.dev
- Deployed: <timestamp>
- Deployment ID: <uuid>
- Access App ID: <uuid>
- Rollback command: <command>
```

This way, if the user asks "what's deployed right now?" the state file has the answer.
</step>

</steps>

<output>
A running deployment of the product:
- A secure temporary URL on `*.workers.dev` or `*.pages.dev`
- Username + password for Cloudflare Access protection
- Environment variables + secrets configured
- Health endpoint returns 200 at the temp URL
- A `DEPLOY.md` with the URL, credentials, and rollback instructions
</output>

<acceptance-criteria>
- [ ] Product builds clean (`npm run build` / `uv build`)
- [ ] No secrets in code (Check 0.1 of ship.md)
- [ ] `.env.example` exists with all keys
- [ ] Health endpoint exists in the build artifact
- [ ] Wrangler config (or equivalent) is in the repo
- [ ] Deploy command returns a URL within 3 minutes
- [ ] `curl https://<temp-url>/health` returns 200
- [ ] Username + password are returned to the user (NEVER stored in chat)
- [ ] `DEPLOY.md` is written with rollback instructions
- [ ] If deploy fails, Loop 6 retries up to 3 times before surfacing the error
</acceptance-criteria>
