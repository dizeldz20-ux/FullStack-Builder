<ssr_client_patterns>

## Purpose
The @supabase/ssr + Next.js 15 App Router boilerplate. Three files every Supabase Next.js project needs: `client.ts` (browser), `server.ts` (RSC + Server Actions), and `proxy.ts` (middleware). Without these, you'll have session refresh bugs and 401 errors.

## When this framework loads
- During any provider task (Google / Apple / Email) — step "wire_client_code"
- When a new Supabase Next.js project is being scaffolded
- When migrating from `@supabase/auth-helpers-nextjs` (deprecated) to `@supabase/ssr`

---

## § The Three Files

### File 1: `lib/supabase/client.ts` (browser client)

```typescript
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
  )
}
```

**Used in:** `'use client'` components. Has direct access to cookies via the browser.

---

### File 2: `lib/supabase/server.ts` (server client — RSC, Server Actions, Route Handlers)

```typescript
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // The `setAll` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        }
      }
    }
  )
}
```

**Used in:** Server Components, Server Actions, Route Handlers. Has access to cookies via Next.js's `cookies()` API.

**The `try/catch` is important:** Server Components can't set cookies (read-only). The `proxy.ts` middleware handles the actual cookie write.

---

### File 3: `proxy.ts` (root, NOT in `app/`) — replaces `middleware.ts`

```typescript
// proxy.ts (at the root of your Next.js project, same level as package.json)
import { type NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({
    request: {
      headers: request.headers
    }
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({
            request: {
              headers: request.headers
            }
          })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        }
      }
    }
  )

  // CRITICAL: This call refreshes the session if needed.
  // Don't remove it, or sessions won't be refreshed.
  const { data: { user } } = await supabase.auth.getUser()

  // Optional: protect routes
  if (!user && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return response
}

export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - images (svg, png, jpg, jpeg, gif, webp)
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'
  ]
}
```

**Critical points:**
- File is `proxy.ts` (Next.js 15 convention), not `middleware.ts` (legacy)
- Located at project root, NOT in `app/`
- The `getUser()` call is what refreshes the session
- `matcher` excludes static files for performance

---

## § Reading the Current User

### `getClaims()` — fastest, recommended for auth checks
```typescript
// app/dashboard/page.tsx
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function Dashboard() {
  const supabase = await createClient()
  const { data: { claims } } = await supabase.auth.getClaims()

  if (!claims) redirect('/login')

  return <div>Welcome {claims.email}</div>
}
```

**No network call.** Reads from JWT locally. Use for "is this user logged in?" checks.

### `getUser()` — network call, use when you need fresh data
```typescript
const { data: { user } } = await supabase.auth.getUser()
// Returns: { id, email, user_metadata, app_metadata, ... }
```

**Makes a network call to Supabase Auth.** Use when you need the latest user data (e.g. updated email, custom claims from app_metadata).

### `getSession()` — local only, use for tokens
```typescript
const { data: { session } } = await supabase.auth.getSession()
// Returns: { access_token, refresh_token, expires_at, user }
```

**No validation.** Just reads from local storage. Only use when you need the raw tokens (e.g. to forward to another API).

---

## § The Three OAuth Patterns

### Pattern A: Implicit Flow (browser-only, simplest)

```typescript
// app/(auth)/login/page.tsx
'use client'
import { createClient } from '@/lib/supabase/client'

export default function LoginPage() {
  async function signInWithProvider(provider: 'google' | 'apple' | 'github') {
    const supabase = createClient()
    await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${window.location.origin}/auth/callback`
      }
    })
  }

  return (
    <>
      <button onClick={() => signInWithProvider('google')}>Sign in with Google</button>
      <button onClick={() => signInWithProvider('apple')}>Sign in with Apple</button>
    </>
  )
}
```

**Good for:** Quick prototypes, simple web apps. Session is stored in cookies automatically.

### Pattern B: PKCE Flow (server-side, recommended for production)

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

    if (!error) {
      return NextResponse.redirect(`${origin}${next}`)
    }
  }

  return NextResponse.redirect(`${origin}/auth/auth-code-error')
}
```

**Good for:** Production. More secure (PKCE), handles edge cases better.

### Pattern C: Google One-Tap (best UX, more setup)

```typescript
// components/GoogleOneTap.tsx
'use client'
import Script from 'next/script'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function GoogleOneTap() {
  const router = useRouter()

  return (
    <Script
      src="https://accounts.google.com/gsi/client"
      onReady={() => {
        const supabase = createClient()
        ;(window as any).google.accounts.id.initialize({
          client_id: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID!,
          callback: async (response: any) => {
            const { error } = await supabase.auth.signInWithIdToken({
              provider: 'google',
              token: response.credential
            })
            if (!error) router.push('/dashboard')
          },
          use_fedcm_for_prompt: true  // Required for Chrome's 3rd-party cookies removal
        })
        ;(window as any).google.accounts.id.prompt()
      }}
    />
  )
}
```

**Good for:** Highest conversion (one-click sign-in). Requires NEXT_PUBLIC_GOOGLE_CLIENT_ID in env. More complex setup.

---

## § Sign Out

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
```

Use in a form:
```typescript
<form action={signOut}>
  <button type="submit">Sign out</button>
</form>
```

---

## § Common Pitfalls

### "Cookies should be set in middleware or Server Actions"
**Cause:** You're trying to set cookies from a Server Component.
**Fix:** Use Server Actions or Route Handlers (not Server Components) for auth operations. The `proxy.ts` middleware refreshes the session.

### 401 errors after 1 hour
**Cause:** Session expired and the `proxy.ts` isn't refreshing it.
**Fix:** Make sure `proxy.ts` is at the project root (not in `app/`) and contains the `getUser()` call.

### Session works in dev but breaks in production
**Cause:** Missing env vars in production deployment.
**Fix**: Add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` to your hosting platform (Vercel, Netlify, etc.).

### `window is not defined` in Server Component
**Cause:** You imported the browser client into a Server Component.
**Fix:** Use `lib/supabase/server.ts` in Server Components, `lib/supabase/client.ts` only in Client Components.

</ssr_client_patterns>
