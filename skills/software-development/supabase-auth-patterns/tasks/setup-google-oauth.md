<purpose>
Set up Google OAuth sign-in for a Supabase-backed Next.js 15 product. Covers: Google Cloud Console setup, Supabase Dashboard configuration, Next.js 15 client code (3 patterns: Implicit / PKCE / One-Tap), and verification steps.
</purpose>

<user-story>
As a the user building a Supabase product, I want users to be able to sign in with one click using their Google account, so that signup is frictionless and I get verified emails for free.
</user-story>

<when-to-use>
- User explicitly asks "תוסיף Google sign-in" or "אני רוצה sign in with Google"
- A new Supabase project needs its first OAuth provider
- `build-product` routes here when `tasks/new-product.md` reaches the auth-setup stage
- The product is web-first (Next.js / React) — not iOS native
</when-to-use>

<context>
User-stack defaults: fall back to `build-product/frameworks/user-defaults.md` (Three Rules + stack preferences) when this skill's own defaults are absent.
</context>

<references>
@frameworks/google-cloud-setup.md (during step "create_oauth_credentials" — full Google Console walkthrough)
@frameworks/ssr-client-patterns.md (during step "wire_client_code" — the @supabase/ssr boilerplate)
@frameworks/env-vars-and-secrets.md (during step "configure_env" — NEXT_PUBLIC_ rules)
@frameworks/session-management.md (during step "verify_session" — JWT/refresh flow)
@frameworks/pitfall-catalog.md (load on demand if anything breaks)
@references/supabase-auth-quick-reference.md (code snippets to copy-paste)
</references>

<steps>

<step name="verify_prerequisites" priority="first">
Check the following before starting:

1. **Supabase project exists** with the URL and Publishable Key ready:
   ```bash
   ls -la .env.local
   grep -E "NEXT_PUBLIC_SUPABASE_(URL|PUBLISHABLE_KEY)" .env.local
   # Both must be set. If missing, redirect to /supabase-auth setup first.
   ```

2. **Next.js 15+** with App Router:
   ```bash
   cat package.json | jq '.dependencies.next, .devDependencies.next'
   # Must be >= 15.0.0
   ```

3. **`@supabase/ssr` installed**:
   ```bash
   cat package.json | jq '.["@supabase/ssr"]'
   # If missing: npm install @supabase/ssr @supabase/supabase-js
   ```

4. **`proxy.ts` exists** at project root (Next.js 15 convention):
   ```bash
   ls -la proxy.ts middleware.ts
   # proxy.ts MUST exist. middleware.ts is ignored if both exist.
   ```

If any of these fail, **stop and tell the user** what's missing. Do not proceed.
</step>

<step name="create_oauth_credentials">
Guide the user through Google Cloud Console. Full walkthrough in `@frameworks/google-cloud-setup.md`.

**Short version:**

1. Go to [console.cloud.google.com](https://console.cloud.google.com/) → Create/select project
2. **APIs & Services** → **OAuth consent screen**:
   - User Type: **External** (unless Google Workspace)
   - App name, support email
   - Scopes: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`
3. **Credentials** → **Create OAuth client ID**:
   - Application type: **Web application**
   - **Authorized JavaScript origins**:
     - `http://localhost:3000` (dev)
     - `https://yourapp.com` (prod)
   - **Authorized redirect URIs**:
     - Local Supabase: `http://127.0.0.1:54321/auth/v1/callback`
     - Production: `https://<your-supabase-ref>.supabase.co/auth/v1/callback`
4. **Save** the Client ID and Client Secret — you'll need them in step 3.

**Wait for the user to confirm he has both values before proceeding.**
</step>

<step name="configure_supabase">
Configure the Google provider in Supabase Dashboard.

1. Open: `https://supabase.com/dashboard/project/<your-ref>/auth/providers`
2. Click **Google** → toggle **Enable**
3. Fill in:
   - **Client ID**: (from step 2)
   - **Client Secret**: (from step 2)
4. **Authorized Client IDs** (optional): leave empty for now. Fill only if you have separate iOS/Android clients.
5. Click **Save**

**Verify it worked:**

```bash
# Get the Supabase ref from .env.local
SUPABASE_REF=$(grep NEXT_PUBLIC_SUPABASE_URL .env.local | sed -E 's|.*//([^.]+)\.supabase.co.*|\1|')

# Check provider is enabled (requires access token)
export SUPABASE_ACCESS_TOKEN=$(cat <workspace>/memory/.secrets/supabase.token)
supabase --project-ref "$SUPABASE_REF" inspect auth config 2>/dev/null | grep -A 2 "google\|external_google"
```

If the output shows `external_google_enabled: true`, we're good. If not, repeat step 3.
</step>

<step name="configure_env">
Add environment variables if not already present.

```bash
# .env.local — add (do NOT use NEXT_PUBLIC_ for the secret!):
# Already there from setup:
# NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
# NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...

# For Google One-Tap (optional — see framework step):
# NEXT_PUBLIC_GOOGLE_CLIENT_ID=<from-google-console>
```

**Rule:** Google Client Secret goes into Supabase Dashboard, NOT into .env.local. Only the Client ID is needed in env vars (for One-Tap, not standard OAuth).
</step>

<step name="wire_client_code">
Create the auth callback route and a sign-in button. Three patterns are available — pick based on use case.

### Pattern A: Implicit flow (simplest, browser-only)
```typescript
// app/(auth)/login/page.tsx
'use client'
import { createClient } from '@/lib/supabase/client'

export default function LoginPage() {
  async function signInWithGoogle() {
    const supabase = createClient()
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${window.location.origin}/auth/callback` }
    })
    if (error) console.error(error)
  }
  return <button onClick={signInWithGoogle}>Sign in with Google</button>
}
```

### Pattern B: PKCE flow (server-side, recommended for production)
```typescript
// app/auth/callback/route.ts
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const next = searchParams.get('next') ?? '/'

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}${next}`)
  }

  return NextResponse.redirect(`${origin}/auth/auth-code-error`)
}
```

### Pattern C: Google One-Tap (best UX, advanced)
See @frameworks/ssr-client-patterns.md → "Google One-Tap" section.

**For most products, start with Pattern A. Upgrade to B for production. Use C only if you have analytics showing login friction.**

**Wait for the user to choose a pattern before continuing.**
</step>

<step name="create_auth_pages">
Create login + signup pages with both Email/Password and Google options.

```typescript
// app/(auth)/layout.tsx — split layout, public
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen flex items-center justify-center">{children}</div>
}

// app/(auth)/login/page.tsx
// app/(auth)/signup/page.tsx
// Both contain: <GoogleSignInButton /> + <EmailPasswordForm />
```

**Acceptance:** Both pages render, "Sign in with Google" button is visible.
</step>

<step name="verify_session">
Verify the session is properly created and accessible from the server.

1. **Run the dev server**: `npm run dev`
2. **Sign in with Google** in the browser
3. **Check cookies**: DevTools → Application → Cookies → look for `sb-<ref>-auth-token`
4. **Add a debug page** (temporary):
   ```typescript
   // app/debug/session/page.tsx
   import { createClient } from '@/lib/supabase/server'

   export default async function DebugSession() {
     const supabase = await createClient()
     const { data: { user } } = await supabase.auth.getUser()
     return <pre>{JSON.stringify(user, null, 2)}</pre>
   }
   ```
5. **Navigate to `/debug/session`** — should show the Google user object with `email`, `user_metadata.full_name`, `app_metadata.provider: "google"`

**Delete the debug page** before committing.

If the page shows `null`, the session isn't being set. Check:
- `proxy.ts` is in the root, not in `app/`
- Browser cookies are not blocked
- `redirectTo` URL matches a value in Supabase Dashboard → Auth → URL Configuration
</step>

<step name="add_logout">
Add sign-out. Standard pattern:

```typescript
// app/(auth)/actions.ts
'use server'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export async function signOut() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect('/login')
}

// In a header component:
import { signOut } from '@/app/(auth)/actions'
;<form action={signOut}><button>Sign out</button></form>
```
</step>

<step name="final_verification">
End-to-end test:
- [ ] `npm run build` succeeds without type errors
- [ ] `npm run dev` works
- [ ] Sign in with Google succeeds
- [ ] Session cookie is set (DevTools check)
- [ ] Protected route (`/dashboard`) is accessible after login
- [ ] Sign out clears the cookie and redirects to `/login`
- [ ] No `SUPABASE_SECRET_KEY` in client code (grep check)

**If any fail, route to `tasks/configure-rls-policies.md` next (Google sign-in by itself doesn't need RLS, but the first protected table does).**
</step>

</steps>

<output>
## Artifact
Google OAuth sign-in is wired up. the user can now sign in with Google from any page that includes the sign-in button.

## Format
- New files: `app/(auth)/login/page.tsx`, `app/(auth)/signup/page.tsx`, `app/auth/callback/route.ts`, `app/(auth)/actions.ts`
- Updated files: `.env.local` (added NEXT_PUBLIC_GOOGLE_CLIENT_ID if using One-Tap)
- Unchanged: `lib/supabase/client.ts`, `lib/supabase/server.ts`, `proxy.ts` (these are from the SSR setup, not this task)

## Location
Standard Next.js 15 App Router structure under `app/`.
</output>

<acceptance-criteria>
- [ ] Google Cloud Console OAuth client created (Web application type)
- [ ] Authorized redirect URIs include both local and production Supabase callbacks
- [ ] Supabase Dashboard → Auth → Google provider enabled with Client ID + Secret
- [ ] `redirectTo` URL is in Supabase's allow list
- [ ] Sign-in flow works end-to-end (click button → Google consent → redirect back → session in cookies)
- [ ] `proxy.ts` refreshes session on every request (test: leave browser idle for 1 hour, session still works)
- [ ] Protected routes (e.g. `/dashboard`) redirect to `/login` when unauthenticated
- [ ] No errors in browser console during sign-in flow
- [ ] No `SUPABASE_SECRET_KEY` or `sb_secret_` in client-bundled code
</acceptance-criteria>
