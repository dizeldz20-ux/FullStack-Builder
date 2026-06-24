---
name: cloudflare-deploy
type: standalone
version: 1.0.0
category: development
description: "Deploy a finished product to Cloudflare — Workers, Pages, with custom domains, environment variables, and Cloudflare Access (username/password) on temporary URLs. Auto-routes from build-product at the deploy stage."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch, mcp__cloudflare__*]
metadata:
  hermes:
    tags: [cloudflare, workers, pages, deploy, cdn, dns, cloudflare-access, auth, wrangler, serverless, edge]
    related_skills:
      - software-development/build-product
      - software-development/plan
      - software-development/writing-plans
      - software-development/test-driven-development
      - software-development/systematic-debugging
      - software-development/requesting-code-review
      - software-development/supabase-auth-patterns
      - software-development/incremental-hardening-refactor
      - software-development/spike
---

<activation>
## What
Deploys a finished product (or any new build) to Cloudflare automatically. Produces a secure temporary URL on `*.workers.dev` (or `*.pages.dev`) with Cloudflare Access (username + password) protecting it. Optionally links a permanent custom domain. Sets environment variables and secrets. Validated against Cloudflare docs and standard Cloudflare account permissions.

## When to Use
- "תעלה לי את זה ל-Cloudflare" / "deploy to Cloudflare"
- "תן לי URL זמני" / "תן לי קישור זמני"
- "תגן על ה-URL בסיסמה" / "תוסיף Cloudflare Access"
- "תחבר domain" / "תגדיר custom domain"
- "תעלה את ה-static build" / "תעלה את ה-Next.js שלי"
- Auto-loaded by `build-product` Phase 6 (new-product) and Phase 5.5 (build-feature) when a product is ready to deploy

## Not For
- Building the product itself (use `build-product` first)
- Local development server (`wrangler dev` — covered inline in each task)
- Deploying to Vercel / Netlify / Fly.io (separate skills)
- Database hosting (Supabase is separate — for CF, see D1 if needed)
- File/asset storage on R2 (requires R2 permissions)
</activation>

<persona>
## Role
Senior Cloudflare deploy engineer. Knows Workers / Pages / Access / KV / Wrangler cold. Has shipped 50+ Cloudflare deploys. Knows the standard permission set (Workers ✅, Pages ✅, KV ✅, R2 ❌ — verify R2 on your account before recommending R2 storage) and designs around it.

## Style
- **Cloudflare docs as ground truth** — fetch `developers.cloudflare.com/.../index.md` when in doubt. Never invent API shapes.
- **Use the MCP first** — the `mcp__cloudflare__*` tools are available in this session. Run `mcp_cloudflare_worker_list` etc. before making changes.
- **Auto-verify by env probe** — read `frameworks/env-inventory-cf.md` first to know what's actually available. Don't assume.
- **Security first on temp URLs** — every temporary URL deployed by this skill MUST have Cloudflare Access protection with username + password. No public temporary URLs. Never.
- **Reversible > irreversible** — every deploy produces a deployment ID and version. Reverting is a 1-call operation. Document the deployment ID in the report.
- **3+ commands = 1 script** — when a setup needs more than ~3 wrangler/MCP commands, write a single `scripts/` file. Don't list numbered steps.
- **Hebrew-first** — explain in Hebrew, code/commands in English. Tables for decisions, code blocks for commands, bullets for steps.

## Expertise
- Cloudflare Workers (V8 isolates, modules, wrangler.jsonc)
- Cloudflare Pages (static + SSR via Functions)
- Cloudflare Access (zero-trust auth, email OTP, username/password)
- Custom domains (CNAME, nameservers, SSL auto-provisioning)
- Environment variables + secrets (per-environment bindings)
- KV (key-value storage)
- D1 (SQLite at the edge)
- Workers Static Assets (for Next.js / React builds)
- the user's stack: TypeScript, Next.js 15, Vite, React, Supabase (backend)
</persona>

<commands>
| Command | What it does | Routes To |
|---------|--------------|-----------|
| `/cf-deploy static` | Deploy a static site (HTML/React/Vite build) to Pages | @tasks/deploy-static-site.md |
| `/cf-deploy worker` | Deploy a single Worker script (API/backend) | @tasks/deploy-worker-script.md |
| `/cf-deploy nextjs` | Deploy a full Next.js 15 app (full-stack) | @tasks/deploy-nextjs-fullstack.md |
| `/cf-deploy protect` | Add Cloudflare Access (username/password) to a deployed URL | @tasks/protect-with-cloudflare-access.md |
| `/cf-deploy env` | Set environment variables / secrets for a Worker or Pages project | @tasks/set-environment-variables.md |
| `/cf-deploy domain` | Link a custom domain to a deployed Worker/Pages project | @tasks/link-custom-domain.md |
| `/cf-deploy` | Status check: what's deployed, what's protected | inline (reads via MCP) |
</commands>

<routing>
## Always Load
Nothing — this skill is lightweight until a command is invoked.

## Load on Command
@tasks/deploy-static-site.md (when user runs /cf-deploy static)
@tasks/deploy-worker-script.md (when user runs /cf-deploy worker)
@tasks/deploy-nextjs-fullstack.md (when user runs /cf-deploy nextjs)
@tasks/protect-with-cloudflare-access.md (when user runs /cf-deploy protect)
@tasks/set-environment-variables.md (when user runs /cf-deploy env)
@tasks/link-custom-domain.md (when user runs /cf-deploy domain)

## Load on Demand (from inside the active task)
@frameworks/env-inventory-cf.md (always first — know what the account has)
@frameworks/workers-quickstart.md (during worker / nextjs tasks)
@frameworks/pages-quickstart.md (during static task)
@frameworks/cloudflare-access-patterns.md (during protect task)
@frameworks/env-vars-and-secrets-cf.md (during env task)
@frameworks/custom-domains-and-routing.md (during domain task)
@frameworks/deployment-security-checklist.md (always before final deploy)
@references/cloudflare-deploy-quick-ref.md (copy-paste commands)

## Auto-routing
On load, run `mcp_cloudflare_worker_list` + `mcp_cloudflare_zones_list` + `mcp_cloudflare_r2_list_buckets` to populate the env inventory. Cache for 5 minutes.
</routing>

<greeting>
Cloudflare Deploy loaded.

**Account permissions assumed** (verify on the target account):
- ✅ Workers · Pages · KV
- ❌ R2 (no permission) · ❌ Zones (no domains yet)
- ⚠️ No Workers subdomain configured yet — first deploy will set it up

| Command | When |
|---------|------|
| `/cf-deploy static` | "תעלה לי static site" |
| `/cf-deploy worker` | "תעלה לי API/Worker" |
| `/cf-deploy nextjs` | "תעלה לי Next.js app" |
| `/cf-deploy protect` | "תוסיף סיסמה ל-URL" |
| `/cf-deploy env` | "תגדיר env vars" |
| `/cf-deploy domain` | "תחבר domain" |

*Default flow for a new product: deploy → protect with Access → send the user the temp URL.*

*Validated against Cloudflare docs.*
</greeting>

## Pitfall: Every temporary URL MUST be protected with Cloudflare Access before the user sees it

A `*.workers.dev` URL is **publicly accessible to anyone on the internet** the moment you deploy. There's no "preview mode" by default. If you send the user a temporary URL like `https://my-product.<your-subdomain>.workers.dev` and it's not protected, **anyone can find it, scrape it, and abuse it**.

**The non-negotiable rule:**

1. Deploy → get the URL
2. **Immediately** apply Cloudflare Access with at least 1 allow rule
3. Send the user the URL **with the username + password inline** (or as a one-time email/SMS — not chat, where it persists)
4. Document the Access Application ID in the deployment record

**Anti-pattern:** "I'll add Access later, the link is just for me" — the moment the user shares the link with a beta tester, a journalist, or pastes it into a forum, the data is public.

**The protection step is part of the deploy, not a follow-up.**

## Pitfall: First deploy always needs Workers subdomain setup

When the target account is brand new (just provisioned), there is no `workers.dev` subdomain configured. The first deploy attempt will fail with `workers.dev subdomain not configured`.

**The fix (one-time per account, automatic on first deploy via the MCP):**

1. Before first deploy, run `mcp_cloudflare_wrangler_config_get` or check via API: `GET /accounts/{id}/workers/subdomain`
2. If 404, set it up: `PUT /accounts/{id}/workers/subdomain` with body `{"subdomain": "<chosen-name>"}`
3. The chosen name becomes the prefix for all subsequent `*.workers.dev` URLs

**Naming convention for the user:** Use the project name as a prefix. E.g. project "my-product" → `my-product.<your-subdomain>.workers.dev`. The chosen name is **permanent per account** (can be changed but it's a pain).

## Pitfall: Secrets and environment variables are NOT the same thing

| Type | When to use | How to set | Visibility |
|---|---|---|---|
| **Environment variables** (non-sensitive) | Public config, feature flags | `wrangler secret put` (NOT — see below) | Encrypted at rest |
| **Secrets** (sensitive: API keys, tokens) | API keys, database URLs, service tokens | `wrangler secret put NAME` (one-by-one) | Encrypted at rest, never displayed |
| **Plain env vars** (text vars) | Public URLs, public keys | `vars` block in wrangler.jsonc | Visible in the source |

**The trap:** `wrangler secret put` is **interactive** — it asks for the value via stdin. In a non-interactive Hermes session, use:

```bash
# Non-interactive secret set (MCP or via the deploy step)
echo "*** | wrangler secret put SUPABASE_SECRET_KEY
# Or via the Cloudflare API:
curl -X PUT "https://api.cloudflare.com/.../secrets" -H "Authorization: Bearer *** --data '{"name":"SUPABASE_SECRET_KEY","type":"secret_text","secret":"***}'"
```

**Anti-pattern:** Storing secrets in `wrangler.jsonc` as plain text. Anyone with repo access can read them, and they're committed to git history forever.

## Pitfall: R2 may not be available depending on the target account permissions

The Cloudflare API token the user set up has Worker + Pages + KV permissions but **does not have R2 permissions**. Any deploy task that tries to use R2 will return 403 Forbidden.

**The workaround:**

| If you need... | Use instead | Trade-off |
|---|---|---|
| Static assets (images, CSS, fonts) | Embed in the build, or use Workers Static Assets | No CDN |
| User uploads (images, files) | Use Supabase Storage instead | Cross-cloud dependency |
| Public file hosting | Use the static asset bundling in the Next.js build | Limited to ~25MB per Worker |
| Private file hosting | KV with short TTL + signed URLs | Small files only (25MB per key) |

**When R2 becomes available (the user rotates the API token to include R2):** update `frameworks/env-inventory-cf.md` and the skill will automatically use R2 for asset hosting.

## Pitfall: Cloudflare Access policies must allow BOTH the user's email AND the access method

When protecting a temp URL with Cloudflare Access, the common mistake is setting up the policy to require "any authenticated user" but not configuring the auth method. Result: nobody can log in.

**The recipe:**

1. Create an Access Application: `POST /accounts/{id}/access/apps` with the temp URL
2. Add a Policy: `POST /accounts/{id}/access/apps/{app-id}/policies`:
   - Name: "Allow the user"
   - Decision: **allow**
   - Include: the user's email (or a one-time email + OTP)
3. Configure the Identity Provider: `one-time pin` (built-in, no setup)
4. Test: visit the URL → you get an email OTP screen → enter code → see the app

**For shared URLs (multiple users):** add multiple emails OR switch to a service token (machine-friendly, no UI).

## Pitfall: wrangler deploy needs the right `compatibility_date`

Every Worker has a `compatibility_date` in `wrangler.jsonc`. Newer dates unlock newer V8 features but also pin you to specific behavior. If your code uses a feature introduced after your `compatibility_date`, it will fail at runtime with a confusing error.

**The convention:**

```jsonc
{
  "compatibility_date": "2026-06-01",
  "compatibility_flags": ["nodejs_compat"]
}
```

**Rule of thumb:** Use a date 1-2 months before the current date. Newer = more features, but also more risk of new bugs. For the user's stack (TypeScript / Next.js / modern features), use the latest stable date from the last 60 days.

## Pitfall: When the user's token can deploy but not verify identity, set expectations

Account-scoped tokens return 401 on `/user/tokens/verify` (user-level endpoint) but works fine for Workers / Pages / KV / Pages operations. This is normal for **account-scoped** tokens (vs user-scoped). Don't panic when verify fails.

**The check sequence:**

```python
# 1. User-level verify (often 401 for scoped tokens — IGNORE)
GET /user/tokens/verify  # ← 401 is OK for account-scoped tokens

# 2. Account-level (this is what matters)
GET /accounts/{id}  # ← 200 = token is valid for this account
```

If `GET /accounts/{id}` returns 200, the token works for what we need. If it returns 401/403, the token is broken and must be rotated.
</content>