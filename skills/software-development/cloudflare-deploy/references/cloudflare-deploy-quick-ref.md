# Cloudflare Deploy — Quick Reference

Copy-paste commands for the most common Cloudflare deploy operations. All examples use the operator's Cloudflare API token (read from `<workspace>/memory/.secrets/cloudflare.token`).

---

## § Setup: load the token once per session

```bash
export CF_TOKEN=*** <workspace>/memory/.secrets/cloudflare.token)
export CF_ACCOUNT="<your-cloudflare-account-id>"
```

Or in Python:
```python
import os
token = open('<workspace>/memory/.secrets/cloudflare.token').read().strip()
account = '<your-cloudflare-account-id>'
```

---

## § Check account state

```bash
# Get account info
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT" | jq .

# List Workers
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts" | jq .

# List Pages projects
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/pages/projects" | jq .

# List KV namespaces
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/storage/kv/namespaces" | jq .

# List zones (custom domains)
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones" | jq .
```

---

## § First-time setup: workers.dev subdomain

```bash
# Check if set
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/subdomain"

# If 404, set it
curl -X PUT -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/subdomain" \
  --data '{"subdomain": "<chosen-name>"}'
# e.g. "<your-subdomain>" → *.<your-subdomain>.workers.dev
```

---

## § Deploy a Worker (via API)

```bash
PROJECT="my-app"
SCRIPT='export default { async fetch(request) { return new Response("Hello!"); } }'

curl -X PUT -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT" \
  -H "Content-Type: application/javascript" \
  --data "$SCRIPT"
```

**Via MCP:**
```python
mcp_cloudflare_worker_put(
  name="my-app",
  script="<Worker code>",
  compatibility_date="2026-06-01"
)
```

---

## § Deploy to Pages (via wrangler)

```bash
# Build first
npm run build  # → ./out or ./dist

# Deploy
CLOUDFLARE_API_TOKEN=$CF_TOKEN wrangler pages deploy ./out \
  --project-name=my-app \
  --branch=main \
  --commit-dirty=true
```

---

## § Set env vars

```bash
# Plain env var (visible in dashboard)
curl -X PUT -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT/env-vars" \
  --data '{"name":"ENVIRONMENT","value":"production","type":"plain_text"}'
```

**Via MCP:**
```python
mcp_cloudflare_env_var_set(
  scriptName="my-app",
  key="ENVIRONMENT",
  value="production"
)
```

---

## § Set secrets (encrypted)

```bash
# Non-interactive (pipe the value)
echo "*** wrangler secret put SUPABASE_SERVICE_ROLE_KEY

# Via API
curl -X PUT -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT/secrets" \
  --data '{"name":"SUPABASE_SERVICE_ROLE_KEY","type":"secret_text","secret":"***"'
```

**Via MCP:**
```python
mcp_cloudflare_secret_put(
  scriptName="my-app",
  secretName="SUPABASE_SERVICE_ROLE_KEY",
  secretValue="*** <workspace>/memory/.secrets/<filename> for sensitive values
```

---

## § List env vars / secrets

```bash
# Plain env vars (with values)
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT/env-vars" | jq .

# Secrets (names only, values are hidden)
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT/secrets" | jq .
```

---

## § Protect URL with Cloudflare Access

```bash
# 1. Create Application
APP_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/access/apps" \
  --data '{
    "name": "my-app-temp",
    "domain": "my-app.<your-subdomain>.workers.dev",
    "type": "self_hosted",
    "session_duration": "24h",
    "app_launcher_visible": false,
    "allowed_idps": []
  }')
APP_ID=$(echo "$APP_RESPONSE" | jq -r '.result.id')

# 2. Add Policy
curl -X POST -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/access/apps/$APP_ID/policies" \
  --data '{
    "name": "Allow the user",
    "decision": "allow",
    "include": [{"email": ["<your-email>"]}]
  }'

echo "App ID: $APP_ID"
```

---

## § Add custom domain

```bash
ZONE_ID="<zone-id-for-example.com>"

curl -X PUT -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT/domains" \
  --data "{\"hostname\":\"app.example.com\",\"zone_id\":\"$ZONE_ID\"}"
```

---

## § Rollback to a previous version

```bash
# List versions
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT/versions" | jq .

# Rollback
curl -X POST -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/workers/scripts/$PROJECT/rollback" \
  --data '{"version_id": "<version-id>"}'

# Or via MCP:
mcp_cloudflare_version_rollback(
  scriptName="my-app",
  versionId="<version-id>"
)
```

---

## § Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| 401 on `/user/tokens/verify` | Account-scoped token (normal) | Ignore, use account-level endpoints |
| 403 on `/r2/buckets` | Token lacks R2 permission | Rotate token with R2:Edit |
| 404 on `/workers/subdomain` | First Worker in account | Set subdomain (see above) |
| "Worker exceeded CPU time" | Long-running code | Optimize or upgrade plan |
| "Script too large" | Too many dependencies | Code-split, remove unused deps |

---

*For the full patterns and explanations, see `tasks/` and `frameworks/` in this skill.*

*Validated against Cloudflare docs and standard account permissions.*
