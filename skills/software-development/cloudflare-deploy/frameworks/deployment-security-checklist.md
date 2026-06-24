<deployment_security_checklist>

## Purpose
The pre-deploy + post-deploy security checklist for every Cloudflare deploy. Catches the most common issues: leaked secrets, unprotected URLs, missing RLS, exposed env vars.

## When this framework loads
- ALWAYS before the final report in any deploy task
- When the user asks "is my deploy secure?"
- During code review of any deploy-related diff

---

## § Pre-deploy checklist (run before `wrangler deploy` or MCP deploy)

### Secrets in source code

```bash
# Check the bundle / source for secrets
grep -rE "sb_secret_|sk_live_|sk_test_|ghp_|password|api[_-]?key" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.json" \
  --include="*.html" --include="*.css" \
  ./dist ./out ./build ./.next ./src 2>/dev/null

# Should return 0 results. If it returns anything, it's a leak.
```

### Service Role Key in public env

```bash
# Check wrangler.jsonc and build output for service role / secret keys
grep -E "sb_secret_|service.role|service_role" \
  wrangler.jsonc \
  ./out/_next/static/chunks/*.js 2>/dev/null  # For Next.js

# Should return 0 results
```

### NEXT_PUBLIC_* contains only public data

```bash
# Make sure no sensitive data is prefixed with NEXT_PUBLIC_
grep -rE "NEXT_PUBLIC_.*(SECRET|KEY|TOKEN|PASSWORD)" \
  --include="*.ts" --include="*.tsx" --include="*.js" \
  ./src ./app ./components 2>/dev/null

# Should return 0 results
```

### Build succeeds

```bash
npm run build 2>&1 | tail -20
# Should show "Compiled successfully" or similar — no errors
```

### Wrangler config is valid

```bash
wrangler deploy --dry-run 2>&1 | tail -20
# Should show "Dry run completed successfully" — no syntax errors
```

---

## § Post-deploy checklist (run after the deploy succeeds)

### URL is live and returns expected response

```bash
# Wait a few seconds for the deploy to propagate
sleep 5

# Test the URL
curl -I https://<project-name>.<subdomain>.workers.dev/
# Should return 200 (or the Worker's expected response code)

curl -s https://<project-name>.<subdomain>.workers.dev/ | head -50
# Should show the expected HTML / API response
```

### Cloudflare Access is protecting the URL

```bash
# Visit the URL in an incognito browser window
# OR check the response code for the auth screen

# The auth screen returns a specific HTML. Test:
curl -sI https://<project-name>.<subdomain>.workers.dev/ | head -5
# Should NOT return the app's HTML — should show Cloudflare Access branding
```

### Env vars are set correctly

```bash
# List plain vars
curl -H "Authorization: Bearer *** "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/<name>/env-vars"
# Verify the names match what the Worker code expects

# List secrets (names only)
curl -H "Authorization: Bearer *** "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/<name>/secrets"
# Verify the names match
```

### Worker logs show no errors

```bash
# Via wrangler CLI (live)
CLOUDFLARE_API_TOKEN=*** wrangler tail
# Or via MCP:
mcp_cloudflare_workers_analytics_search(...)
# Should show no unhandled exceptions
```

### If using Supabase: RLS is enabled

```sql
-- Run in Supabase Dashboard → SQL Editor
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND rowsecurity = false;
-- Should return 0 rows. If it returns anything, those tables are world-readable.
```

### If using Supabase: no Service Role Key in client code

```bash
# Check the deployed Worker / Pages output
grep -E "sb_secret_|service.role" \
  ./out/_next/static/chunks/*.js 2>/dev/null
# Should return 0 results
```

---

## § Common security issues (and their fixes)

| Issue | Symptom | Fix |
|---|---|---|
| Service Role Key in client bundle | `sb_secret_` visible in browser source | Move to `wrangler secret put`, not `NEXT_PUBLIC_*` |
| Unprotected temp URL | Anyone can access | Add Cloudflare Access |
| Missing RLS | Anon user can see all data | `ALTER TABLE x ENABLE ROW LEVEL SECURITY` |
| Plain text secret in wrangler.jsonc | Visible in git history | Use `wrangler secret put` instead |
| Unused env vars | Confusing, potential leak | Remove from `wrangler.jsonc` |
| Old deployment still running | New deploy doesn't take effect | Check `wrangler versions list`, rollback if needed |
| Worker exceeds memory limit | Random 500s | Optimize code, add caching |
| Worker exceeds CPU time limit | Random timeouts | Optimize, add caching, or upgrade plan |

---

## § The 5-question pre-deploy check

Before saying "deploy successful", answer YES to all 5:

1. **Secrets are encrypted, not in source code.** Yes / No
2. **Cloudflare Access protects the temp URL.** Yes / No / N/A (production with proper auth)
3. **The URL returns 200 and the expected content.** Yes / No
4. **Env vars are set, names match what the Worker expects.** Yes / No
5. **No errors in the Worker logs (first 60 seconds).** Yes / No

If any is No, **don't tell the user it's deployed.** Fix first.

---

## § What to send the user after a successful deploy

```text
✅ Deployed: <project-name>
🔗 URL: https://<project-name>.<subdomain>.workers.dev
🔒 Protected: Cloudflare Access (one-time PIN to <your-email>)
📧 Access email: <your-email>
🆔 Deployment ID: <uuid>
🆔 Access App ID: <uuid>
📋 Env vars: <count> plain + <count> secrets (names only)
⏰ Deployed: <timestamp>
🔄 To rollback: <command>

Test by visiting the URL, enter <your-email>, check inbox for PIN, see the app.
```

**Include rollback instructions.** The deployment should be reversible in 1 step:

```bash
# Rollback to the previous version
mcp_cloudflare_version_rollback(
  scriptName="<project-name>",
  versionId="<previous-version-id>"
)
```

**Or via wrangler:**
```bash
wrangler rollback <previous-version-id>
```

---

## § When to escalate (don't deploy, tell the user)

- The build fails with errors (don't deploy broken code)
- The Worker has unhandled exceptions in the logs (fix first, redeploy)
- The user's Supabase project doesn't have RLS (security incident waiting to happen)
- The custom domain SSL fails to provision for >24h
- The token permissions don't include Workers / Pages (the user needs to rotate the token)
- The deploy succeeds but the URL shows a different app (cache issue or wrong Worker)

</deployment_security_checklist>
