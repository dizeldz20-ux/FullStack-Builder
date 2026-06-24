<purpose>
Deploy a single Cloudflare Worker script (API endpoint, backend, edge function) to the user's account. Gets a temp URL on `*.workers.dev`, auto-protects with Cloudflare Access, sets env vars + secrets.
</purpose>

<user-story>
As the user who has a single Worker script (TypeScript or JavaScript) that needs to run as an API, I want one command to deploy it to Cloudflare, get a temp URL, and have it password-protected, so I can integrate it with a frontend or test it with curl.
</user-story>

<when-to-use>
- "תעלה לי API/Worker"
- "תפרוס את ה-edge function"
- "deploy this Worker"
- Single-file or small Workers projects (not full Next.js)
- Edge APIs, middleware, scheduled jobs, webhooks

NOT for: full Next.js apps (use `deploy-nextjs-fullstack.md`), static sites (use `deploy-static-site.md`).
</when-to-use>

<context>
@frameworks/env-inventory-cf.md
</context>

<references>
@frameworks/workers-quickstart.md (during step "create_wrangler_config")
@frameworks/env-vars-and-secrets-cf.md (during step "set_secrets")
@frameworks/cloudflare-access-patterns.md (during step "protect_with_access")
@frameworks/deployment-security-checklist.md (always before final report)
@references/cloudflare-deploy-quick-ref.md
</references>

<steps>

<step name="verify_prerequisites">
1. Worker source code exists (e.g. `src/index.ts` or `worker.js`)
2. Project is a Wrangler project (has `wrangler.jsonc` or `wrangler.toml` OR is a single `.js` file ready to deploy)
3. Workers is available in the user's account (read env-inventory-cf.md)

If source is missing, stop and ask the user to share the Worker code or build a single-file Worker inline.
</step>

<step name="ensure_wrangler_config">
The Worker needs a `wrangler.jsonc` (or `wrangler.toml`) at the project root. Minimum required fields:

```jsonc
{
  "name": "<project-name-kebab-case>",
  "main": "src/index.ts",
  "compatibility_date": "2026-06-01",
  "compatibility_flags": ["nodejs_compat"]
}
```

**Naming convention:** `<project-slug>` — kebab-case, no spaces, must be unique within the Cloudflare account.

If the project doesn't have one, **create it from the source file's location** (Herme will do this).
</step>

<step name="first_deploy_subdomain_setup">
**If this is the first Worker in the account**, the `workers.dev` subdomain doesn't exist yet. Set it up:

```bash
# Set the subdomain (one-time, per account)
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/workers/subdomain" \
  -H "Authorization: Bearer *** <workspace>/memory/.secrets/cloudflare.token)" \
  -H "Content-Type: application/json" \
  --data '{"subdomain": "<chosen-subdomain>"}'
```

The chosen subdomain becomes the prefix for all `*.workers.dev` URLs. Choose something short and meaningful, e.g. `<your-subdomain>` (sounds like a name, hard to forget) or `<your-project>-prod` (more business-like).

**If subdomain already exists**, skip this step.
</step>

<step name="deploy_via_mcp" priority="last">
The MCP `mcp_cloudflare_worker_put` is the cleanest path:

```python
mcp_cloudflare_worker_put(
  name="<project-name>",
  script="<full Worker code as a string>",
  compatibility_date="2026-06-01"
)
```

The script is the **complete** Worker source — `export default { async fetch(request, env, ctx) { ... } }`. If it's a multi-file Worker, bundle it first with `wrangler deploy --dry-run --outdir=dist/` and pass the bundled output.

**Alternative via wrangler CLI:**

```bash
cd /path/to/worker-project
CLOUDFLARE_API_TOKEN=$(cat <workspace>/memory/.secrets/cloudflare.token) wrangler deploy
```

wrangler outputs the deployed URL like `https://<project-name>.<subdomain>.workers.dev`.
</step>

<step name="set_secrets" priority="last">
Workers can have both **plain env vars** and **secrets**. Use secrets for sensitive data.

**Plain env vars** go in `wrangler.jsonc`:
```jsonc
{
  "vars": {
    "PUBLIC_API_URL": "https://api.example.com",
    "ENVIRONMENT": "production"
  }
}
```

**Secrets** are set via CLI/MCP and stored encrypted:

```bash
# Non-interactive secret set
echo "*** wrangler secret put SUPABASE_SECRET_KEY
# (The echo pipes the value into wrangler, which prompts for it interactively normally)
```

**Via MCP** (when supported):
```python
# Future MCP API — check what's available in this session
mcp_cloudflare_secret_put(
  scriptName="<project-name>",
  secretName="SUPABASE_SECRET_KEY",
  secretValue="*** If the MCP doesn't expose a direct secret-set tool, use the Cloudflare API:
```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/{name}/secrets" \
  -H "Authorization: Bearer *** <workspace>/memory/.secrets/cloudflare.token)" \
  -H "Content-Type: application/json" \
  --data '{"name":"SUPABASE_SECRET_KEY","type":"secret_text","secret":"***"'
```

Wait for the deploy to complete before setting secrets (some APIs require the Worker to exist first).
</step>

<step name="set_env_vars" priority="last">
For plain (non-secret) env vars, use `mcp_cloudflare_env_var_set`:

```python
mcp_cloudflare_env_var_set(
  scriptName="<project-name>",
  key="ENVIRONMENT",
  value="production"
)
```

Or via the API:
```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/{name}/env-vars" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"name":"ENVIRONMENT","value":"production","type":"plain_text"}'
```
</step>

<step name="verify_deployment">
1. `curl https://<project-name>.<subdomain>.workers.dev/health` (or any endpoint)
2. Expect 200 (or whatever the Worker returns)
3. Check `mcp_cloudflare_version_list` to confirm the deploy version is the latest
4. Check `mcp_cloudflare_workers_analytics_search` for traffic (should show 0 for a fresh deploy)

If the Worker throws an error, check:
- The MCP `worker_get` to see the deployed code
- `wrangler tail` (live logs) via wrangler CLI for stack traces
- Env vars / secrets are correctly set
</step>

<step name="protect_with_access" priority="last">
**NON-NEGOTIABLE.** Follow `@frameworks/cloudflare-access-patterns.md` to add Access protection.

**For API Workers specifically** (not just user-facing apps), you can use a **service token** instead of email OTP. This way the user can call the API from another service with a `CF-Access-Client-Id` + `CF-Access-Client-Secret` header.

```python
# In the Access Application config, add a Service Token:
# - Give it a name (e.g. "the user's API caller")
# - Get the client_id and client_secret
# - the user uses them as:
#   curl -H "CF-Access-Client-Id: <id>" -H "CF-Access-Client-Secret: <secret>" \
#        https://<worker>.workers.dev/api
```

Choose based on the use case:
- **User-facing app** → email OTP
- **Machine-to-machine API** → service token
- **Both** → both policies (additive)
</step>

<step name="final_verification">
- [ ] Worker code deployed successfully
- [ ] URL returns 200 (or expected response) for a test request
- [ ] All env vars set (verify with `wrangler secret list` or MCP)
- [ ] All secrets set (sensitive data only in encrypted form)
- [ ] Cloudflare Access protection active (URL shows auth screen or rejects without service token)
- [ ] No secrets in plain env vars (grep for `sb_secret_`, API keys, etc.)
- [ ] the user received: URL + access method (email or service token) + deployment ID
</step>

</steps>

<output>
## Artifact
- A live Worker at `https://<project-name>.<subdomain>.workers.dev`
- Protected by Cloudflare Access (email OTP or service token)
- All env vars and secrets configured
- Documented deployment record

## Format
- New: `wrangler.jsonc` (if not present)
- Updated: `wrangler.jsonc` with `vars` block (if env vars added)
- Deployment record at `.hermes/cf-deploy/<project-name>-<timestamp>.md`
</output>

<acceptance-criteria>
- [ ] Worker source code is valid (no TypeScript errors, no missing imports)
- [ ] `wrangler deploy` (or MCP equivalent) returned success
- [ ] URL returns 200 to a curl test
- [ ] No runtime errors in worker logs
- [ ] All env vars accessible in the Worker via `env.VAR_NAME`
- [ ] All secrets accessible in the Worker via `env.SECRET_NAME` (without exposing values)
- [ ] Cloudflare Access application created with appropriate policy
- [ ] Access-protected URL rejects unauthenticated requests (or shows OTP screen)
- [ ] the user received URL + access credentials + deployment ID
</acceptance-criteria>
