<purpose>
Set environment variables and secrets on a deployed Cloudflare Worker or Pages project. Distinguishes between plain env vars (visible in dashboard) and secrets (encrypted, never displayed).
</purpose>

<user-story>
As the user who has a deployed Worker that needs API keys, database URLs, or other config, I want one command to set all env vars and secrets correctly, so the Worker has what it needs without me exposing sensitive values in the code.
</user-story>

<when-to-use>
- "תגדיר env vars"
- "תוסיף secret"
- "אני צריך להגדיר DATABASE_URL"
- After any deploy that needs runtime config
- Before any production deploy (rotate test keys to production keys)

NOT for: build-time env vars (those are set when running `npm run build` for Next.js).
</when-to-use>

<context>
None
</context>

<references>
@frameworks/env-vars-and-secrets-cf.md (full reference)
@../supabase-auth-patterns/frameworks/env-vars-and-secrets.md (for Supabase-specific rules)
</references>

<steps>

<step name="identify_what_to_set">
Ask the user (or read from the project) which env vars / secrets to set. Group them:

**Plain env vars (public, no encryption needed):**
- Public API URLs
- Public keys (publishable keys, OAuth client IDs)
- Feature flags
- Environment name (production / staging / dev)

**Secrets (sensitive, encrypted):**
- API keys (private/secret keys, not publishable)
- Database connection strings
- Service tokens
- Webhook signing secrets
- OAuth client secrets

**The rule:** If it's in `NEXT_PUBLIC_*` for a Next.js app, or a public URL, it's plain. Everything else is a secret.
</step>

<step name="set_plain_env_vars" priority="last">
For Workers, use `mcp_cloudflare_env_var_set` or the API:

```python
# Via MCP:
mcp_cloudflare_env_var_set(
  scriptName="<project-name>",
  key="ENVIRONMENT",
  value="production"
)
```

**Bulk set (multiple at once):**

```python
mcp_cloudflare_env_var_bulk_set(
  scriptName="<project-name>",
  vars={
    "ENVIRONMENT": "production",
    "API_BASE_URL": "https://api.example.com",
    "FEATURE_FLAG_NEW_UI": "true"
  }
)
```

**Via the API directly:**

```bash
# Single var
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/workers/scripts/<name>/env-vars" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"name":"ENVIRONMENT","value":"production","type":"plain_text"}'

# Or use wrangler.jsonc `vars` block:
# {
#   "vars": {
#     "ENVIRONMENT": "production",
#     "API_BASE_URL": "https://api.example.com"
#   }
# }
```

Plain vars are **visible** in the Cloudflare Dashboard. Don't put secrets here.
</step>

<step name="set_secrets" priority="last">
Secrets are encrypted at rest and never displayed in the dashboard or CLI.

**Via wrangler CLI (non-interactive):**

```bash
# Pipe the value to avoid the interactive prompt
echo "*** wrangler secret put SUPABASE_SECRET_KEY
# (The `echo` is the value, pipe sends it to wrangler)
```

**Via the Cloudflare API:**

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/workers/scripts/<name>/secrets" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"name":"SUPABASE_SECRET_KEY","type":"secret_text","secret":"***"'
```

**Via MCP (when available):**

```python
mcp_cloudflare_secret_put(
  scriptName="<project-name>",
  secretName="SUPABASE_SECRET_KEY",
  secretValue="*** <workspace>/memory/.secrets/<filename> if you want to load from a file
```

**Anti-patterns:**

| ❌ Don't do this | Why |
|---|---|
| Put secret in `wrangler.jsonc` `vars` block | It's committed to git, visible to anyone with repo access |
| Put secret in `NEXT_PUBLIC_*` | It's in the client bundle, visible to anyone who visits the site |
| Pass secret via `echo` in a public script | Echo is in shell history, visible to anyone on the system |
| Log the secret after setting | Some logging systems persist logs forever |

**Best practice:** load the secret from a file at the time of deploy, never let the value appear in chat / scripts / logs:

```bash
# At deploy time:
SECRET=$(cat <workspace>/memory/.secrets/supabase.token)
echo "$SECRET" | wrangler secret put SUPABASE_SERVICE_ROLE_KEY
unset SECRET  # Clear from shell
```
</step>

<step name="verify_env_vars">
Confirm the vars are set (without showing the secret values):

```python
# Via MCP:
result = mcp_cloudflare_env_var_list(scriptName="<project-name>")
# Returns: [{name: "ENVIRONMENT", value: "production"}, ...]
# Secrets are NOT in this list (only plain vars)

# To list secrets (names only, values are hidden):
# Via API:
curl -H "Authorization: Bearer *** "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/<name>/secrets"
# Returns: [{name: "SUPABASE_SECRET_KEY"}, ...]
```

**In the Worker code**, access them via the `env` parameter:

```typescript
export default {
  async fetch(request: Request, env: Env) {
    const dbUrl = env.SUPABASE_URL  // plain var
    const secret = env.SUPABASE_SECRET_KEY  // secret
    // ...
  }
}
```
</step>

<step name="rotate_secrets" priority="last">
If a secret was leaked or you need to rotate:

1. Set the new secret (same command as setting, it overwrites)
2. The new value is active immediately for new requests
3. **Existing requests in flight may still use the old value briefly** (Workers handle this gracefully)
4. Delete the old secret (if the API supports it):

```bash
# Via API
curl -X DELETE "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/<name>/secrets/<secret-name>" \
  -H "Authorization: Bearer *** <workspace>/memory/.secrets/cloudflare.token)"
```

5. Update any local references (`.env.local` in the project, etc.)
6. Document the rotation in the deployment record

**When to rotate:**
- Secret was committed to git by accident
- Secret was shared in a chat / log
- An employee / contractor with access left
- Every 90 days for high-value secrets (Supabase, Stripe, etc.)
- After any security incident
</step>

</steps>

<output>
## Artifact
- A Worker / Pages project with all required env vars and secrets set
- Documented in the deployment record

## Format
- Updated: Cloudflare Dashboard → Workers & Pages → <project> → Settings → Variables
- Updated: `.hermes/cf-deploy/<project-name>-<timestamp>.md` with the env var list (names only, not values)
</output>

<acceptance-criteria>
- [ ] All required env vars are set (names match what the Worker code expects)
- [ ] All required secrets are set (encrypted, not visible in dashboard)
- [ ] No secrets in plain env vars
- [ ] No secrets in `NEXT_PUBLIC_*` env vars
- [ ] No secrets in `wrangler.jsonc` (unless using `vars` for public-only data)
- [ ] Worker can read all vars via `env.VAR_NAME` (verified by testing the deployed Worker)
- [ ] Deployment record updated with var names (not values)
- [ ] Local `.env.local` is NOT updated (production values differ from local)
</acceptance-criteria>
