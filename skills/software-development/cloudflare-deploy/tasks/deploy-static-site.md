<purpose>
Deploy a finished static site (HTML, React, Vite, or `next export` build) to Cloudflare Pages. Gets a temporary URL on `*.pages.dev`, auto-protects it with Cloudflare Access, and returns the URL + credentials to the user.
</purpose>

<user-story>
As the user who just built a static site (or has a `next build` output), I want one command to upload it to Cloudflare, get a temp URL, and have it password-protected, so I can share it with a tester or a client in under 2 minutes.
</user-story>

<when-to-use>
- "תעלה את ה-static site שלי"
- "תעלה את ה-Vite build ל-Cloudflare"
- "תעלה את ה-React app שלי"
- After a `vite build` or `next build` (export mode) is done
- For SPAs that don't need server-side rendering

NOT for: full Next.js apps with server components / API routes (use `@tasks/deploy-nextjs-fullstack.md` instead).
</when-to-use>

<context>
@frameworks/env-inventory-cf.md (always first — confirm Pages is available)
</context>

<references>
@frameworks/pages-quickstart.md (during step "deploy_via_mcp")
@frameworks/env-vars-and-secrets-cf.md (during step "set_env_vars" — if the site needs API keys)
@frameworks/cloudflare-access-patterns.md (during step "protect_with_access")
@frameworks/deployment-security-checklist.md (always before final report)
@references/cloudflare-deploy-quick-ref.md
</references>

<steps>

<step name="verify_prerequisites" priority="first">
Confirm:
1. Build output exists (e.g. `dist/`, `build/`, `out/`)
2. The output is static (no `api/` or server components)
3. Pages is available in the user's account (read `env-inventory-cf.md`)

If build output is missing, **stop** and tell the user: "תריץ קודם `npm run build` ואחרי זה תגיד לי שזה מוכן."

If the build is server-rendered (Next.js with App Router, NOT static export), stop and route to `deploy-nextjs-fullstack.md`.
</step>

<step name="prepare_build">
The build directory must contain the final static output. Common patterns:

| Build tool | Output directory | Verify |
|---|---|---|
| Vite | `dist/` | `ls dist/index.html` |
| Create React App | `build/` | `ls build/index.html` |
| Next.js (static export) | `out/` | `ls out/index.html` |
| Astro (static) | `dist/` | `ls dist/index.html` |
| Plain HTML | `.` (the folder) | `ls index.html` |

If the build is a SPA (client-side routing), make sure the framework handles fallback to `index.html` for unknown routes. Cloudflare Pages has a `_redirects` file for this:

```bash
# SPA fallback: any unknown route → /index.html
cat > dist/_redirects << 'EOF'
/*    /index.html   200
EOF
```

For Next.js static export, this is handled by `output: 'export'` in `next.config.js`.
</step>

<step name="deploy_via_mcp">
Use the Cloudflare MCP to deploy via `mcp_cloudflare_worker_put` (which is actually used for both Workers and Pages, with `compatibility_date` in the bindings).

For Pages specifically, the recommended approach is to use the **Pages Direct Upload** API. The MCP exposes this via the `deploy` tool.

```typescript
// Pseudo-code for what the MCP does internally:
// 1. Create a Pages project (if not exists): POST /accounts/{id}/pages/projects
// 2. Upload the build directory: POST /accounts/{id}/pages/projects/{name}/deployments
// 3. The deployment is auto-published to the production branch
```

In the Hermes session, the deploy command is:
```python
# Via MCP — Hermes will call this for you:
mcp_cloudflare_worker_put(
  name="<project-name>",
  script="<built JS as string, or use worker_deploy with a file path>",
  compatibility_date="2026-06-01"
)
```

**For Pages specifically (not just Workers), the deploy needs more than a script** — it needs the entire build directory. The current MCP `worker_deploy` and `worker_put` are designed for single-script Workers. For Pages, use the **Pages Direct Upload** API endpoint.

If the MCP doesn't support Pages Direct Upload natively, the fallback is:

```bash
# Install wrangler locally (already on the machine via the MCP wrapper dependencies)
npm install -g wrangler

# Login with the token (non-interactive)
CLOUDFLARE_API_TOKEN=$(cat <workspace>/memory/.secrets/cloudflare.token) wrangler login

# Deploy
cd /path/to/project
wrangler pages deploy dist --project-name <project-name> --branch main --commit-dirty=true
```

**Wait for the deploy to complete** — wrangler outputs the URL like `https://<hash>.<project-name>.pages.dev`.
</step>

<step name="set_env_vars" priority="last">
If the site needs env vars (e.g. public Supabase URL, public Stripe key, public analytics ID), set them on the Pages project.

For Vite, the convention is `VITE_*` prefix. For Create React App, `REACT_APP_*`. For Astro, `PUBLIC_*`.

```bash
# For each public env var:
wrangler pages secret put PUBLIC_SUPABASE_URL --project-name <project-name>
# (Enter the value when prompted — wrangler doesn't show it back)
```

**For the Hermes session**, use the MCP `mcp_cloudflare_env_var_set` if the project is a Worker. For Pages, use the wrangler CLI as above (or the Cloudflare Dashboard).

**Anti-pattern:** Hardcoding env vars in the build before upload. They're frozen in the bundle and can't be changed without redeploying.
</step>

<step name="protect_with_access" priority="last">
**NON-NEGOTIABLE. Every temp URL must be protected.**

Follow the full recipe in `@frameworks/cloudflare-access-patterns.md`. Short version:

1. Create an Access Application pointing to the deployed URL
2. Add a Policy: Allow the user's email (or one-time PIN)
3. Test: visit the URL, get the OTP screen, log in, see the site

**Output: a Cloudflare Access Application ID** (UUID). Save it for future updates.
</step>

<step name="final_verification">
End-to-end check:
- [ ] Build uploaded successfully
- [ ] URL is live (HTTP 200, not 404)
- [ ] Cloudflare Access protection is active (visiting the URL shows the auth screen, not the site)
- [ ] Login with the credentials works (sees the site)
- [ ] All public env vars are set (site can call Supabase / etc.)
- [ ] No secrets in the build bundle (grep for `sb_secret_`, API keys, etc.)
- [ ] the user has the URL + credentials

**Then report to the user:**

```text
✅ Deployed: <project-name>
🔗 URL: https://<hash>.<project-name>.pages.dev
🔒 Protected: Cloudflare Access (one-time PIN)
📧 Access email: <your-email>
🆔 Deployment ID: <uuid>
🆔 Access Application ID: <uuid>
⏰ Valid until: <when the user should rotate>
```

**Plus a one-time PIN link (e.g. https://<project>.pages.dev) for testing.**
</step>

</steps>

<output>
## Artifact
- A live static site at `https://<hash>.<project-name>.pages.dev`
- Protected by Cloudflare Access
- Documented deployment record (URL + Access App ID + credentials)

## Format
- New: deployment metadata file at `.hermes/cf-deploy/<project-name>-<timestamp>.md`
- Updated: `package.json` adds `wrangler` if not present

## Location
- Build output: existing `dist/` / `build/` / `out/`
- Deployment: Cloudflare Pages dashboard → Workers & Pages
</output>

<acceptance-criteria>
- [ ] Build output uploaded (success status from wrangler/MCP)
- [ ] URL returns 200 (site is live)
- [ ] Cloudflare Access application created
- [ ] Access policy allows the user's email
- [ ] Visiting the URL without auth shows the Access screen
- [ ] Logging in with the correct email + OTP shows the site
- [ ] No secrets in the build bundle (grep passed)
- [ ] All public env vars configured
- [ ] the user received: URL + access email + deployment ID
</acceptance-criteria>
