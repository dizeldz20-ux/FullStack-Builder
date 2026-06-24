<env_vars_and_secrets_cf>

## Purpose
The non-negotiable rules for environment variables and secrets in Cloudflare Workers / Pages. Distinguishes between plain env vars (visible) and secrets (encrypted). Covers the target account permissions and the patterns for a typical TypeScript stack.

## When this framework loads
- During any deploy task → step "set_env_vars" / "set_secrets"
- When the user asks "how do I set X in Cloudflare"
- When auditing a deployed Worker for leaked secrets

---

## § The 3 types of config in Cloudflare

| Type | Visibility | Storage | When to use |
|---|---|---|---|
| **Plain env var** | Visible in Dashboard | Encrypted at rest, but displayed | Public URLs, feature flags |
| **Secret** | Encrypted, name visible only | Encrypted, never displayed | API keys, database URLs, service tokens |
| **Build-time var** | Baked into bundle | In the source code | `NEXT_PUBLIC_*`, `VITE_*` — public by design |

**The cardinal rule:** If it's public, plain env var or build-time. If it's sensitive, secret.

---

## § Plain env vars (set via wrangler.jsonc or MCP)

### Method 1: wrangler.jsonc `vars` block

```jsonc
{
  "vars": {
    "ENVIRONMENT": "production",
    "API_BASE_URL": "https://api.example.com",
    "FEATURE_FLAG_NEW_UI": "true"
  }
}
```

After editing, deploy again (`wrangler deploy`). Vars are updated.

### Method 2: MCP

```python
mcp_cloudflare_env_var_set(
  scriptName="<project-name>",
  key="ENVIRONMENT",
  value="production"
)

# Or bulk:
mcp_cloudflare_env_var_bulk_set(
  scriptName="<project-name>",
  vars={
    "ENVIRONMENT": "production",
    "API_BASE_URL": "https://api.example.com"
  }
)
```

### Method 3: API

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/{name}/env-vars" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"name":"ENVIRONMENT","value":"production","type":"plain_text"}'
```

**The values are stored encrypted at rest** (Cloudflare encrypts everything), but the values ARE visible in the Dashboard and via the list API. Don't put secrets here.

---

## § Secrets (set via wrangler secret put or MCP)

### Method 1: wrangler secret put (non-interactive)

```bash
# Pipe the value to avoid the interactive prompt
echo "*** wrangler secret put SUPABASE_SERVICE_ROLE_KEY
# (echo pipes the value into wrangler)
```

For multiple secrets, repeat.

### Method 2: MCP

```python
mcp_cloudflare_secret_put(
  scriptName="<project-name>",
  secretName="SUPABASE_SERVICE_ROLE_KEY",
  secretValue="*** <workspace>/memory/.secrets/<filename> for sensitive values
```

### Method 3: API

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/{name}/secrets" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"name":"SUPABASE_SERVICE_ROLE_KEY","type":"secret_text","secret":"***"'
```

**After setting a secret:** the Worker can read it via `env.SUPABASE_SERVICE_ROLE_KEY` (the name you set). The value is never displayed back.

---

## § Reading env vars in Worker code

```typescript
export interface Env {
  // Plain env vars
  ENVIRONMENT: string
  API_BASE_URL: string
  
  // Secrets
  SUPABASE_SERVICE_ROLE_KEY: string
  
  // KV bindings
  MY_KV: KVNamespace
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const envName = env.ENVIRONMENT  // "production"
    const dbKey = env.SUPABASE_SERVICE_ROLE_KEY  // decrypted at runtime
    
    return new Response(`Running in ${envName}`)
  }
}
```

For TypeScript, define the `Env` interface so the compiler knows what's available.

---

## § Build-time env vars (for Next.js / Vite)

These are baked into the bundle at build time. They're public by design (anyone can read them in the source).

**Next.js (only `NEXT_PUBLIC_*`):**

```bash
# Set when running npm run build
NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co \
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
npm run build
```

**Vite (only `VITE_*`):**

```bash
VITE_SUPABASE_URL=https://<ref>.supabase.co \
VITE_SUPABASE_ANON_KEY=sb_publishable_... \
npm run build
```

**Astro (only `PUBLIC_*`):**

```bash
PUBLIC_SUPABASE_URL=https://<ref>.supabase.co \
npm run build
```

**For Workers Static Assets (Next.js static export):** all env vars are build-time. There's no runtime env. The Service Role Key CANNOT be used in this mode (it would be in the public bundle).

**For OpenNext (Next.js with full SSR):** `NEXT_PUBLIC_*` are build-time, other vars are runtime secrets (set via `wrangler secret put`).

---

## § Anti-patterns (what NOT to do)

| ❌ Don't do this | Why | Fix |
|---|---|---|
| Put secret in `wrangler.jsonc` `vars` | Visible in git history forever | Use `wrangler secret put` |
| Put secret in `NEXT_PUBLIC_*` | In client bundle, anyone can read | Use `wrangler secret put` for non-`NEXT_PUBLIC_*` vars |
| Pass secret via `echo "secret"` in a shared script | Echo is in shell history | Load from file, unset after use |
| Log the secret after setting | Some logs persist forever | Don't log secrets, ever |
| Set production secret in the "Preview" scope (Pages) | Preview URLs are public | Use the "Production" scope |
| Use same secret for dev and prod | Dev secrets are easier to leak | Different secrets per environment |

---

## § Verification: which vars / secrets does this Worker have?

```python
# Plain vars
result = mcp_cloudflare_env_var_list(scriptName="<project-name>")
# Returns: [{name: "ENVIRONMENT", value: "production"}, ...]

# Secrets (names only, values are hidden)
# Via API:
curl -H "Authorization: Bearer *** "https://api.cloudflare.com/client/v4/accounts/{id}/workers/scripts/<name>/secrets"
# Returns: [{name: "SUPABASE_SERVICE_ROLE_KEY"}, ...]
```

**In the Worker code**, if you try to read an undefined var, you get `undefined` at runtime. Add validation:

```typescript
const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY
if (!supabaseKey) {
  throw new Error('SUPABASE_SERVICE_ROLE_KEY is not set')
}
```

---

## § Rotation (when a secret leaks)

1. Generate a new secret at the source (e.g. Supabase → Settings → API → Generate new secret)
2. Update the secret in Cloudflare: `wrangler secret put NAME` (overwrites)
3. The new value is active immediately
4. Update local references (`.env.local`, scripts, etc.)
5. Delete the old secret (if possible — depends on the source)
6. **Document the rotation** in the deployment record

**Don't rely on git history rewrites alone.** Once a secret is pushed, assume compromised.

---

## § stack-specific rules

### Next.js + Supabase + Cloudflare

| Variable | Where to set | Why |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Build-time (env in `npm run build`) | Public, used by client |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Build-time | Public, used by client |
| `SUPABASE_SERVICE_ROLE_KEY` | Runtime secret (wrangler secret) | Server-side only, bypasses RLS |
| `SUPABASE_ANON_KEY` | Build-time (only if `NEXT_PUBLIC_*`) or runtime | Same as publishable in 2025+ |
| `STRIPE_SECRET_KEY` | Runtime secret | Never expose |
| `STRIPE_PUBLIC_KEY` | Build-time (`NEXT_PUBLIC_STRIPE_PUBLIC_KEY`) | Public |
| `DATABASE_URL` (for D1 / Postgres) | Runtime secret | Server-side only |

### Worker (API only) + Supabase

| Variable | Where to set | Why |
|---|---|---|
| `SUPABASE_URL` | Plain env var | Not sensitive (URL only) |
| `SUPABASE_SERVICE_ROLE_KEY` | Runtime secret | Bypasses RLS, server-only |
| `SUPABASE_ANON_KEY` | Plain env var (if Worker needs to forward) | Public key |
| `WEBHOOK_SIGNING_SECRET` | Runtime secret | Server-side only |

---

## § When you need a secret that doesn't exist yet

The most common case: the user has a Supabase project but never created a Service Role Key, or it's lost.

**For Supabase:**
1. Dashboard → Settings → API → "Generate new secret key"
2. Save to `<workspace>/memory/.secrets/supabase.token` (overwrite the existing one, keep perms 600)
3. Set as Cloudflare secret via `wrangler secret put`

**For other services:** same pattern — create the key in the source service's dashboard, save to a secrets file, set as Cloudflare secret.

</env_vars_and_secrets_cf>
