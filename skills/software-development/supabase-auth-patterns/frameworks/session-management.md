<session_management>

## Purpose
How Supabase Auth sessions work: JWT access tokens, refresh tokens, session lifecycle, and the Next.js 15 `proxy.ts` pattern that keeps sessions alive. Without understanding this, you'll have random 401 errors and confused users.

## When this framework loads
- During any provider task — step "verify_session"
- When debugging "session expired" or "401 errors after 1 hour" issues
- When implementing logout, "remember me", or session timeout features

---

## § The Token Model

A Supabase session = 2 tokens:

| Token | Format | Lifetime | Purpose |
|---|---|---|---|
| **Access token** | JWT | ~1 hour (default) | Sent with every API request |
| **Refresh token** | Random string | Indefinite (rotated) | Used to get a new access token |

**How they work together:**

```
1. User signs in → Supabase returns (access_token, refresh_token)
2. Browser stores both in cookies (HTTP-only via @supabase/ssr)
3. Every API request sends access_token in Authorization header
4. When access_token expires (~1 hour):
   a. proxy.ts detects expiration
   b. Automatically calls /auth/v1/token?grant_type=refresh_token
   c. Gets new (access_token, refresh_token) pair
   d. Updates cookies
5. User stays signed in indefinitely
```

**The user never sees this.** `proxy.ts` handles it transparently.

---

## § The proxy.ts Refresh Pattern

The `proxy.ts` middleware (Next.js 15 convention) MUST call `supabase.auth.getUser()` on every request. This is what triggers the refresh.

```typescript
// proxy.ts
import { type NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(/* ... */)
  // ⚠️ DO NOT REMOVE THIS LINE
  // This call:
  // 1. Reads the current access token from cookies
  // 2. If expired, automatically uses refresh token to get a new one
  // 3. Updates the cookies with the new tokens
  const { data: { user } } = await supabase.auth.getUser()

  // ... your route protection logic ...

  return response
}
```

**Without this call, sessions don't refresh.** Users get 401 errors after 1 hour.

---

## § Three Ways to Read the User

### `getClaims()` — fastest, no network call
```typescript
const { data: { claims } } = await supabase.auth.getClaims()
// Returns: { sub: 'user-uuid', email: '...', role: 'authenticated', ... } or null

if (!claims) redirect('/login')
```

**When:** Route protection. "Is this user logged in?" Use this by default.

### `getUser()` — network call, fresh data
```typescript
const { data: { user } } = await supabase.auth.getUser()
// Returns: User object with id, email, user_metadata, app_metadata
// Makes a network call to Supabase Auth to get the latest user record.
```

**When:** You need the latest user data (e.g. updated email, new app_metadata). Costs ~50-100ms.

### `getSession()` — local only, no validation
```typescript
const { data: { session } } = await supabase.auth.getSession()
// Returns: { access_token, refresh_token, expires_at, user }
// No validation. Just reads from local storage.
```

**When:** You need the raw tokens to forward to another API. **Don't trust the user object from this call for auth decisions** — it's not validated.

**Rule of thumb:** Use `getClaims()` for auth checks, `getUser()` when you need fresh data, `getSession()` only when you need the tokens.

---

## § Session Lifecycle

A session ends when:

| Trigger | What happens |
|---|---|
| User clicks "Sign out" | `supabase.auth.signOut()` deletes session from DB and cookies |
| User changes password | All sessions terminated (security measure) |
| Time-box expires | If enabled in Dashboard → Auth → Sessions → "Time-box user sessions" |
| Inactivity timeout | If enabled in Dashboard → Auth → Sessions → "Inactivity timeout" |
| Single session per user | New sign-in kills old sessions (if enabled) |
| Refresh token reuse detected | If a refresh token is used outside the 10s reuse window, the session is terminated (anti-theft) |

**By default, sessions are infinite** (until user signs out or password changes).

---

## § Configuring Session Timeouts

Dashboard → **Authentication** → **Sessions**:

| Setting | Default | Recommended for... |
|---|---|---|
| **Time-box user sessions** | Disabled | Compliance apps (SOC 2, HIPAA) — force re-auth every X days |
| **Inactivity timeout** | Disabled | Banking / sensitive apps — log out after X minutes of no activity |
| **Single session per user** | Disabled (multiple allowed) | Apps where one device per user is expected (mobile) |

**Recommendation for most apps:** Leave defaults. Sessions should "just work" until the user signs out.

---

## § Refresh Token Reuse Detection

Supabase has a security feature: if a refresh token is used more than 10 seconds after its first use, the session is **terminated** (assumed stolen).

**Why this matters for the user:**

- If `proxy.ts` makes 2 concurrent requests, both might try to refresh simultaneously
- Without the 10s window, one of them would fail and log the user out
- The 10s window lets both succeed

**Don't disable this feature** unless you have a specific reason. It's a security net against refresh token theft.

**The exception:** SSR apps that legitimately need to refresh the same token on server + client within milliseconds. The 10s window handles this.

---

## § Sign Out Best Practices

### Sign out from a Server Action (recommended)
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

### Sign out from a Client Component
```typescript
'use client'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

export function SignOutButton() {
  const router = useRouter()
  const supabase = createClient()

  async function handleSignOut() {
    await supabase.auth.signOut()
    router.push('/login')
    router.refresh()  // Force re-fetch of server components
  }

  return <button onClick={handleSignOut}>Sign out</button>
}
```

**Always redirect to a public page after sign out.** Otherwise the user lands on a protected page that redirects them anyway (jarring UX).

---

## § Common Pitfalls

### "401 Unauthorized" after 1 hour
**Cause:** `proxy.ts` isn't refreshing the session.
**Fix:** Make sure `proxy.ts` exists at project root, contains the `getUser()` call, and runs on the right routes (check the `matcher` config).

### "Invalid Refresh Token: Already Used"
**Cause:** Refresh token reuse outside the 10s window, or refresh token was revoked.
**Fix:** User must sign in again. Don't try to handle this programmatically — just redirect to `/login`.

### Session works in one tab but not another
**Cause:** Cookies aren't shared between tabs (e.g. if you're using `localStorage` instead of cookies).
**Fix:** Use `@supabase/ssr` (cookies), NOT `@supabase/supabase-js` with localStorage default. See `frameworks/ssr-client-patterns.md`.

### "User is null" in Server Component, but logged in
**Cause:** Server Components don't refresh sessions — they read from the current cookie state.
**Fix:** Use `proxy.ts` to ensure cookies are fresh before the Server Component runs.

### Forgot to call `router.refresh()` after sign in/out
**Cause:** Server Components have cached the old auth state.
**Fix:** After sign-in or sign-out, call `router.refresh()` to invalidate the cache and re-fetch.

```typescript
// After sign in:
router.push('/dashboard')
router.refresh()  // ← Don't forget this

// After sign out:
router.push('/login')
router.refresh()
```

### "Both proxy.ts and middleware.ts exist"
**Cause:** Copied from an old tutorial.
**Fix:** Next.js 15 uses `proxy.ts` (and ignores `middleware.ts` if both exist). Delete `middleware.ts` to avoid confusion.

</session_management>
