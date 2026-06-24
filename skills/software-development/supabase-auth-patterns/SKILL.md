---
name: supabase-auth-patterns
type: standalone
version: 1.0.0
category: development
description: "Wire Supabase Auth into a Next.js 15 product — Google OAuth, Apple OAuth, Email/Password, with RLS-protected tables and proper SSR session management. Battle-tested against Supabase docs and the user's production patterns."
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, WebSearch, WebFetch]
metadata:
  hermes:
    tags: [supabase, auth, oauth, google, apple, rls, nextjs, postgres, security, ssr, jwt]
    related_skills:
      - software-development/build-product
      - software-development/plan
      - software-development/writing-plans
      - software-development/test-driven-development
      - software-development/incremental-hardening-refactor
      - software-development/systematic-debugging
      - software-development/oauth-helper
      - software-development/desktop-product-managed-cloud-feature-work
      - software-development/hybrid-app-browser-storage-hardening
      - software-development/requesting-code-review
      - software-development/spike
---

<activation>
## What
Guides the user through wiring Supabase Auth into a Next.js 15 product: Email/Password + Google OAuth + Apple OAuth (optional), with Supabase Postgres + RLS, `@supabase/ssr` for server-side session management, and the Next.js 15 `proxy.ts` (replaces `middleware.ts`).

## When to Use
- "תוסיף לי auth לפרויקט"
- "אני רוצה Google sign-in + Email + אולי Apple"
- "יש לי Supabase project חדש ואני צריך לחבר אותו ל-Next.js"
- "ה-RLS שלי לא עובד / המשתמשים רואים מידע של אחרים"
- "ה-session נופל כל כמה זמן / 401 errors"
- "אני רוצה להוסיף Apple sign-in ל-iOS app"

## Not For
- Building a Supabase project from scratch (use Supabase CLI / Dashboard directly)
- Database schema design beyond RLS (use a general DB skill)
- Billing / subscription / Stripe integration (separate skill)
- Email-only auth without Supabase (use a different auth provider)
- Mobile-only OAuth on iOS/Android native (use platform-specific docs)
</activation>

<persona>
## Role
Senior Supabase Auth integration engineer. Knows the Supabase docs cold, has shipped Google + Apple + Email auth in production, debugged RLS policies at 2am, and learned the hard way about the Next.js 15 middleware → proxy.ts migration.

## Style
- **Supabase docs as ground truth** — when in doubt, fetch `r.jina.ai/https://supabase.com/docs/...` and verify. Never invent API shapes.
- **Code from real projects** — every code sample in this skill is either from Supabase official docs or from validated production patterns. No made-up examples.
- **RLS-first thinking** — every table gets `ENABLE ROW LEVEL SECURITY` + policies BEFORE the first SELECT. No "we'll add it later."
- **Defensive defaults** — `getClaims()` over `getUser()` for auth checks. Service Role Key NEVER in `NEXT_PUBLIC_*`. HTTP-only cookies via `@supabase/ssr`.
- **3+ commands = 1 script** — when a setup needs more than ~3 shell commands, write a single `scripts/` file. Don't list numbered steps.
- **Hebrew-first** — explain in Hebrew, code in English/code blocks. Tables for decisions, code blocks for commands, bullets for steps.
- **Apple costs money, plan for it** — $99/year Apple Developer account. Don't recommend Apple auth for a web-only MVP unless explicitly asked.

## Expertise
- Supabase Auth flows: Email/Password, Magic Link, OAuth (Google/Apple/GitHub/20+)
- `@supabase/supabase-js` + `@supabase/ssr` for Next.js 15 App Router
- RLS policies (SELECT / INSERT / UPDATE / DELETE) + helper functions (`auth.uid()`, `auth.jwt()`)
- Google Cloud Console OAuth setup + Authorized redirect URIs
- Apple Developer Program ($99/yr) + Services ID + `.p8` private key
- Session management: JWT, refresh tokens, `proxy.ts` session refresh
- RLS performance: `(SELECT auth.uid())` vs `auth.uid()`, index recommendations
- the user's stack: Next.js 15 (App Router), TypeScript, Postgres via Supabase
</persona>

<commands>
| Command | What it does | Routes To |
|---------|--------------|-----------|
| `/supabase-auth google` | Wire up Google OAuth only | @tasks/setup-google-oauth.md |
| `/supabase-auth apple` | Wire up Apple OAuth only (prereq: Apple Developer account) | @tasks/setup-apple-oauth.md |
| `/supabase-auth email` | Wire up Email + Password only | @tasks/wire-email-password.md |
| `/supabase-auth rls` | Add RLS policies to existing tables | @tasks/configure-rls-policies.md |
| `/supabase-auth` | Status check: which providers are enabled? | inline (reads `.env.local` + `supabase/config.toml`) |
</commands>

<routing>
## Always Load
Nothing — this skill is lightweight until a command is invoked.

## Load on Command
@tasks/setup-google-oauth.md (when user runs /supabase-auth google)
@tasks/setup-apple-oauth.md (when user runs /supabase-auth apple)
@tasks/wire-email-password.md (when user runs /supabase-auth email)
@tasks/configure-rls-policies.md (when user runs /supabase-auth rls)

## Load on Demand (from inside the active task)
@frameworks/google-cloud-setup.md (during Google task — step-by-step console walkthrough)
@frameworks/apple-developer-setup.md (during Apple task — App ID + Services ID + .p8)
@frameworks/ssr-client-patterns.md (during any provider task — @supabase/ssr + proxy.ts boilerplate)
@frameworks/rls-pattern-catalog.md (during RLS task — copy-paste policy templates)
@frameworks/env-vars-and-secrets.md (during any task — env var setup + security rules)
@frameworks/session-management.md (during any task — JWT/refresh/session gotchas)
@frameworks/pitfall-catalog.md (during any task — 10 common mistakes with fixes)
@references/supabase-auth-quick-reference.md (code snippets for the most common ops)
@references/research-fetch-recipe.md (when the agent needs to read MORE Supabase docs than what's already cached in `frameworks/` — uses `r.jina.ai/<url>` to bypass Vercel anti-bot)

## Auto-routing
Read `.env.local` to detect which env vars exist. If `NEXT_PUBLIC_SUPABASE_URL` is missing, suggest running `supabase init` or creating a new project first.
</routing>

<greeting>
Supabase Auth Patterns loaded.

| Command | When |
|---------|------|
| `/supabase-auth google` | "תוסיף לי Google sign-in" |
| `/supabase-auth apple` | "אני רוצה גם Apple" (צריך Apple Developer $99/yr) |
| `/supabase-auth email` | "רק Email/Password" |
| `/supabase-auth rls` | "תוסיף RLS policies לטבלאות" |
| `/supabase-auth` | Status check |

*Default mode:* Email + Google (90% of products). Add Apple only if iOS native app or regulatory requirement.

*Validated 2026-06-24 against Supabase docs + production patterns. Stack: Next.js 15 + @supabase/ssr.*
</greeting>

## Pitfall: Always enable RLS BEFORE the first SELECT goes to production

A Supabase table without `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` is **world-readable** through the auto-generated API. There's no warning, no 404, no nothing — it just works, and every user can see every other user's data. This is the single most common security incident in Supabase products.

**The non-negotiable order (2026-06-24, validated against Supabase docs and the user's production patterns):**

1. Create table
2. **`ALTER TABLE <name> ENABLE ROW LEVEL SECURITY`** — immediate
3. **Create policies** for every role that needs access (`anon`, `authenticated`, `service_role`)
4. **Test** with a non-authenticated client to confirm `SELECT` returns empty
5. **Then** wire the app to it

**Anti-pattern: "we'll add RLS in production"** — the team forgets, a malicious actor scrapes user emails, and the user gets a security incident report at 3am. This skill's `tasks/configure-rls-policies.md` always opens with the RLS check.

**The auto-enable RLS trigger (recommended in `supabase/migrations/0000_rls.sql`):**

```sql
-- the user: copy this into your first migration. Runs once per database.
CREATE OR REPLACE FUNCTION rls_auto_enable()
RETURNS EVENT_TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog AS $$
DECLARE cmd record;
BEGIN
  FOR cmd IN
    SELECT * FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
      AND schema_name = 'public'
  LOOP
    EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
  END LOOP;
END; $$;

CREATE EVENT TRIGGER ensure_rls
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION rls_auto_enable();
```

**Symptom you're violating the rule:** A table created yesterday doesn't have RLS, the team says "we'll add it next sprint", the API has been live for 5 hours with 200 users, and `auth.users` is now in the wild.

## Pitfall: Never put SUPABASE_SECRET_KEY in NEXT_PUBLIC_*

The Service Role Key (now called `sb_secret_...` since 2025) **bypasses all RLS**. If it lands in the browser bundle, every user's browser can read/write every row in every table. There's no "encryption at rest" that protects you from this — the key is right there in the JS.

**The rule (2026-06-24, validated against Supabase docs):**

| Variable | Prefix | Where it's safe |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `NEXT_PUBLIC_` | ✅ Client + Server |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `NEXT_PUBLIC_` | ✅ Client + Server (replaces `ANON_KEY`) |
| `SUPABASE_SECRET_KEY` | (no prefix) | ⚠️ **Server only** — never in browser code |

**The check:**

```bash
# In your repo, before every commit:
grep -r "SUPABASE_SECRET_KEY" --include="*.ts" --include="*.tsx" --include="*.js" .
grep -r "sb_secret_" --include="*.ts" --include="*.tsx" --include="*.js" .
# Both should return 0 results in client-runnable code paths.
```

**Anti-pattern: "I'll just import it from a server util"** — one careless `import { secret } from './server'` in a `'use client'` file, and it's in the bundle. The grep above catches it. The build itself doesn't.

## Pitfall: Next.js 15 uses `proxy.ts`, not `middleware.ts`

In Next.js 15, the file convention for middleware has changed from `middleware.ts` (root) to `proxy.ts` (root). Both still work, but new Supabase docs and templates now use `proxy.ts`. If you copy-paste from an older tutorial, you'll have a working middleware that doesn't refresh sessions — leading to "401 errors after 1 hour" bugs.

**The check:**

```bash
# If both files exist, Next.js uses proxy.ts and ignores middleware.ts:
ls -la proxy.ts middleware.ts
```

**The pattern (from Supabase official docs, 2026-06-24):**

```typescript
// proxy.ts (root, NOT inside app/)
import { type NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        }
      }
    }
  )

  // Critical: this call refreshes the session if needed
  const { data: { user } } = await supabase.auth.getUser()

  if (!user && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return response
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'
  ]
}
```
