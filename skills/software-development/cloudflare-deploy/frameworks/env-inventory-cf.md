# Cloudflare Deploy — User's Account Inventory (validated 2026-06-24)

> **Read this first** in every cloudflare-deploy invocation. The user's account state determines what's possible.

## § Verified state (2026-06-24)

| Capability | Status | Evidence | Notes |
|---|---|---|---|
| Account exists | ✅ | `GET /accounts/<your-cloudflare-account-id>` → 200 | Name: "<your-cloudflare-email>'s Account", type: `standard`, created 2026-06-24 |
| Workers deploy | ✅ | `GET /accounts/.../workers/scripts` → 200 (empty list) | Can deploy, no scripts yet |
| Workers subdomain | ❌ → needs setup | `GET /accounts/.../workers/subdomain` → 404 | Will be set on first deploy |
| Pages | ✅ | `GET /accounts/.../pages/projects` → 200 (empty) | Can deploy static + SSR |
| KV namespaces | ✅ | `GET /accounts/.../storage/kv/namespaces` → 200 (empty) | Can create + use |
| R2 buckets | ❌ | `GET /accounts/.../r2/buckets` → 403 Forbidden | **Token lacks R2 permission** |
| DNS zones (custom domains) | ❌ | `GET /zones` → 200 (empty list) | No domains in the account yet |
| User-level verify | ⚠️ 401 | `GET /user/tokens/verify` → 401 | **Normal for account-scoped tokens** — ignore |
| Token format | `cfat_...` (53 bytes) | Read from `<workspace>/memory/.secrets/cloudflare.token` | File perms: 600 ✅ |

## § Implications for deploy tasks

1. **First deploy always sets the Workers subdomain.** The skill auto-handles this.
2. **No R2** — file hosting goes through Supabase Storage or in-bundle assets.
3. **No custom domains** — temp URLs are `*.workers.dev` / `*.pages.dev` only. When the user buys a domain, link it via `/cf-deploy domain`.
4. **Token is account-scoped** — 401 on `/user/...` is expected.

## § Token rotation (when needed)

If R2 or zones need to be added:

1. the user goes to [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Creates a new token with the additional permissions (R2:Edit, Zone:Read, etc.)
3. Saves to `<workspace>/memory/.secrets/cloudflare.token` (overwrites the existing one, keeps perms 600)
4. The MCP wrapper reloads it on the next call (no restart needed)

## § When to refresh this inventory

- After any token rotation
- When adding a new domain
- When subscribing to R2 / D1 / Durable Objects
- Once per quarter (Cloudflare adds new services frequently)

## § How to refresh

```python
import urllib.request, json
token = open('<workspace>/memory/.secrets/cloudflare.token').read().strip()
account = '<your-cloudflare-account-id>'
def call(path):
    req = urllib.request.Request(f"https://api.cloudflare.com/client/v4{path}", headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"error": str(e), "code": e.code}

print("account:", call(f"/accounts/{account}").get("result", {}).get("name"))
print("workers:", call(f"/accounts/{account}/workers/scripts").get("result_info", {}).get("count"))
print("pages:", call(f"/accounts/{account}/pages/projects").get("result_info", {}).get("count"))
print("kv:", call(f"/accounts/{account}/storage/kv/namespaces").get("result_info", {}).get("count"))
print("subdomain:", "set" if call(f"/accounts/{account}/workers/subdomain").get("success") else "NOT SET")
print("r2:", call(f"/accounts/{account}/r2/buckets").get("result_info", {}).get("count", "FORBIDDEN"))
print("zones:", call("/zones").get("result_info", {}).get("count"))
```

---

*This file is the source of truth for "what can the user's account do right now". Update after any state change.*
