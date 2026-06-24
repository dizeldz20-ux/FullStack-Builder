<env_vars_and_secrets>

## Purpose
The non-negotiable rules for Supabase env vars in Next.js 15. The Service Role Key can bypass all RLS — putting it in a public env var is a P0 security incident. This framework is the rulebook.

## When this framework loads
- During any provider task — step "configure_env"
- When adding a new env var to a Supabase project
- When auditing a repo for leaked secrets

---

## § The Three Variables

| Variable | Value format | Prefix | Where safe | What it does |
|---|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://<ref>.supabase.co` | `NEXT_PUBLIC_` | Client + Server | The project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_...` | `NEXT_PUBLIC_` | Client + Server | The "anon" key — respects RLS |
| `SUPABASE_SECRET_KEY` | `sb_secret_...` | (no prefix) | **Server ONLY** | The "service role" key — **bypasses RLS** |

**Rule of thumb:** If you can see it in DevTools after build, the variable is public. Anything starting with `sb_secret_` should NEVER be public.

---

## § .env.local Template

```bash
# .env.local (NEVER commit this to git)

# Public — safe for client bundle
NEXT_PUBLIC_SUPABASE_URL=https://<your-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxx

# Server only — RLS bypasses
SUPABASE_SECRET_KEY=sb_secret_xxxxxxxxxxxx

# Optional: Google One-Tap (client-side)
# NEXT_PUBLIC_GOOGLE_CLIENT_ID=xxxxxxxxxxxx.apps.googleusercontent.com
```

**.gitignore must include:**
```gitignore
.env
.env.local
.env.*.local
```

---

## § The Three Supabase Key Types (2025+ Naming)

Supabase changed naming in 2025. Both old and new names are accepted.

| Old name (≤2025) | New name (2025+) | When to use |
|---|---|---|
| `ANON_KEY` | `PUBLISHABLE_KEY` | Client + server. **Always safe with RLS enabled.** |
| `SERVICE_ROLE_KEY` | `SECRET_KEY` | Server only. Bypasses RLS. **Never expose.** |
| (n/a) | `LEGACY_JWT_SECRET` | Optional. For symmetric signing (not recommended for new projects). |

**For new projects (2026), use the new names:** `sb_publishable_...` and `sb_secret_...`.

**For old projects, the old names still work** (`anon` and `service_role` roles are the same in Postgres).

---

## § Where to Use Each Key

### `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (safe everywhere)

```typescript
// lib/supabase/client.ts (browser)
import { createBrowserClient } from '@supabase/ssr'
export const createClient = () => createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!  // ✅ Safe
)

// lib/supabase/server.ts (RSC, Server Actions, Route Handlers)
import { createServerClient } from '@supabase/ssr'
// Same key, but in server context. ✅ Safe.
```

### `SUPABASE_SECRET_KEY` (server only, never in `NEXT_PUBLIC_*`)

```typescript
// lib/supabase/admin.ts (server-only — used for admin tasks like user creation)
import { createClient } from '@supabase/supabase-js'

export const createAdminClient = () => createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SECRET_KEY!,  // ✅ Safe (no NEXT_PUBLIC_ prefix)
  { auth: { autoRefreshToken: false, persistSession: false } }
)
```

**Use cases for the secret key (server-side only):**
- Creating users programmatically (admin invite)
- Running migrations
- Bulk data operations that bypass RLS
- Server-side cron jobs

**Anti-patterns (NEVER do this):**

```typescript
// ❌ FAILS — env var name doesn't exist
const secret = process.env.NEXT_PUBLIC_SUPABASE_SECRET_KEY

// ❌ FAILS — env var name is wrong
const secret = process.env.NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY

// ❌ FAILS — exposes to client
const secret = process.env.NEXT_PUBLIC_SUPABASE_SECRET  // user adds NEXT_PUBLIC_ by mistake
```

---

## § The Pre-Commit Check

Add this to a pre-commit hook or run manually:

```bash
#!/bin/bash
# scripts/check-secrets.sh (run before git commit)

echo "🔍 Checking for leaked Supabase secret keys..."

# Search for any reference to secret/service_role keys in client-bundled code
LEAKS=$(grep -rE "SUPABASE_SECRET_KEY|SUPABASE_SERVICE_ROLE_KEY|sb_secret_|service_role" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  app/ components/ lib/ 2>/dev/null \
  | grep -v "SUPABASE_SECRET_KEY[^\"']*[\"']" \
  | grep -v "^Binary" \
  | head -20)

if [ -n "$LEAKS" ]; then
  echo "❌ POSSIBLE SECRET LEAK:"
  echo "$LEAKS"
  exit 1
fi

# Check for NEXT_PUBLIC_ version of secret
PUBLIC_LEAKS=$(grep -rE "NEXT_PUBLIC_SUPABASE.*SECRET|NEXT_PUBLIC_SUPABASE.*SERVICE" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  . 2>/dev/null)

if [ -n "$PUBLIC_LEAKS" ]; then
  echo "❌ SECRET KEY MARKED AS PUBLIC:"
  echo "$PUBLIC_LEAKS"
  exit 1
fi

echo "✅ No secret leaks found"
exit 0
```

**Run before every commit:**
```bash
chmod +x scripts/check-secrets.sh
./scripts/check-secrets.sh
```

---

## § Local Development vs Production

### Local (`.env.local`)
```bash
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321   # if using supabase CLI
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
SUPABASE_SECRET_KEY=sb_secret_...
```

### Vercel / Netlify / etc.
Add the same 3 variables in the dashboard. **Do NOT prefix `SUPABASE_SECRET_KEY` with `NEXT_PUBLIC_`.**

### CI/CD (GitHub Actions, etc.)
Add as repository secrets. Reference as `secrets.SUPABASE_SECRET_KEY`.

---

## § Revoking a Leaked Key

If you accidentally commit a secret to git:

1. **Rotate immediately** in Supabase Dashboard → Settings → API → "Generate new secret key"
2. **Update** all env vars (local, Vercel, etc.) with the new key
3. **Purge from git history** with `git filter-repo` (BFG is faster)
4. **Audit logs** in Supabase for any unauthorized access (Dashboard → Logs → API)
5. **Notify users** if PII was potentially exposed (depends on jurisdiction)

**Don't rely on git history rewrites alone.** Once a secret is pushed, assume it's compromised.

---

## § Common Pitfalls

### Prefix typo
```bash
# ❌ Common mistake
NEXT_PUBLIC_SUPABASE_ANON_KEY=...   # Old name, doesn't work in 2025+ Supabase
SUPABASE_ANON_KEY=...                # No NEXT_PUBLIC_, not accessible to client
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=...  # ✅ Correct
```

### .env committed to git
```bash
# Check if .env is tracked:
git ls-files | grep "\.env$"

# If yes, remove from tracking (keeps the file):
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit -m "stop tracking .env"
```

### "Invalid API key" error
**Cause:** Wrong key in env var, or mixing publishable/secret.
**Fix:** Verify the value matches what's in Supabase Dashboard → Settings → API.

### Secret key in server logs
```typescript
// ❌ Logging the client = logging the secret
console.log('Supabase client:', supabase)

// ✅ Never log the client or its config
console.log('Auth operation completed')
```

</env_vars_and_secrets>
