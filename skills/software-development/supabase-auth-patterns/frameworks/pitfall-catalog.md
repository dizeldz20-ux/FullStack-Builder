<pitfall_catalog>

## Purpose
The 10 most common Supabase Auth mistakes, with symptoms, root causes, and fixes. Each one is a real bug the user has shipped or seen shipped. Load this framework whenever something "weird" happens during auth.

## When this framework loads
- During any provider task — when something breaks
- During code review of auth code
- When onboarding a new dev to a Supabase project

---

## § 1. Missing RLS = World-Readable Data

**Symptom:** A user can see data from other users via the API.

**Root cause:** Forgot `ALTER TABLE <name> ENABLE ROW LEVEL SECURITY`.

**Fix:**
```sql
-- 1. Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 2. Add policies (see frameworks/rls-pattern-catalog.md)
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

-- 3. Install auto-enable trigger (so this never happens again)
-- See frameworks/rls-pattern-catalog.md → "Auto-Enable RLS Trigger"
```

**Why it's #1:** No warning, no error. The table is fully accessible to anyone with the publishable key. The bug ships to production silently.

---

## § 2. Service Role Key in NEXT_PUBLIC_

**Symptom:** Any user can read/write any row in any table.

**Root cause:** Someone prefixed the secret key with `NEXT_PUBLIC_`, putting it in the client bundle.

**Fix:**
```bash
# 1. Rotate the secret in Supabase Dashboard immediately
# 2. Update env vars (no NEXT_PUBLIC_ prefix on the secret):
echo "SUPABASE_SECRET_KEY=sb_secret_..." >> .env.local
# NOT: NEXT_PUBLIC_SUPABASE_SECRET_KEY=...

# 3. Add pre-commit hook (see frameworks/env-vars-and-secrets.md → "Pre-Commit Check")
```

**Why it's #2:** The leak might be in the git history, in a CI log, or in a screenshot. Once leaked, assume compromised.

---

## § 3. proxy.ts Missing or Broken

**Symptom:** 401 errors after ~1 hour, or sessions never persist.

**Root cause:** No `proxy.ts` (or it's in the wrong place), or it doesn't call `getUser()`.

**Fix:**
```bash
# Check if proxy.ts exists at project root:
ls -la proxy.ts middleware.ts
# Should have proxy.ts. Delete middleware.ts if both exist.
```

```typescript
// proxy.ts (at project root, NOT in app/)
import { type NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(/* ... */)

  // ⚠️ THIS LINE IS WHAT REFRESHES THE SESSION
  const { data: { user } } = await supabase.auth.getUser()

  // Optional route protection:
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

**Why it's #3:** Next.js 15 changed the convention from `middleware.ts` to `proxy.ts`. Old tutorials use the wrong file.

---

## § 4. Auth.uid() Without Subquery (Slow)

**Symptom:** Queries are slow (100ms+), especially on large tables.

**Root cause:** `auth.uid()` is called for every row, instead of once.

**Fix:**
```sql
-- ❌ Slow: called for every row
CREATE POLICY "Users can view own data" ON interactions
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- ✅ Fast: called once, cached
CREATE POLICY "Users can view own data" ON interactions
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ✅✅ Also: add an index
CREATE INDEX interactions_user_id_idx ON interactions(user_id);
```

**Why it's #4:** Works correctly, just slowly. Easy to miss in dev, painful in production.

---

## § 5. Using Old Variable Names

**Symptom:** "Invalid API key" or env var is `undefined` at runtime.

**Root cause:** Using `ANON_KEY` (old name) instead of `PUBLISHABLE_KEY` (2025+ name).

**Fix:**
```bash
# ❌ Old (≤2025)
NEXT_PUBLIC_SUPABASE_ANON_KEY=...

# ✅ New (2025+)
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

**Note:** The old names still work in Supabase Dashboard, but for new code use the new names.

**Why it's #5:** LLM training data has the old names. Copied code is often wrong.

---

## § 6. Session Refresh Race Conditions

**Symptom:** "Invalid Refresh Token: Already Used" errors.

**Root cause:** Multiple parallel requests refresh the session at the same time.

**Fix:** Supabase has a 10-second reuse window for refresh tokens. As long as your `proxy.ts` is the only place refreshing sessions, this should rarely happen.

**If it still happens:**
- Don't try to handle it programmatically — just redirect to `/login`
- The user re-authenticates and gets a fresh session

```typescript
// In your auth error handler:
if (error.message.includes('refresh_token') || error.status === 401) {
  redirect('/login')
}
```

**Why it's #6:** Concurrent requests are normal in SPAs. The 10s window usually saves you, but not always.

---

## § 7. Forgetting to Call router.refresh()

**Symptom:** After sign-in, server components still show "not logged in" content.

**Root cause:** Next.js caches server component results. After auth state changes, you need to invalidate the cache.

**Fix:**
```typescript
// After sign in:
async function handleSignIn() {
  await supabase.auth.signInWithPassword({ email, password })
  router.push('/dashboard')
  router.refresh()  // ← Don't forget this
}

// After sign out:
async function handleSignOut() {
  await supabase.auth.signOut()
  router.push('/login')
  router.refresh()
}
```

**Why it's #7:** Works fine in dev (where caching is disabled), breaks in production. Confusing to debug.

---

## § 8. Apple First-Sign-In Name Loss

**Symptom:** User's `full_name` is null after signing in with Apple.

**Root cause:** Apple only sends the name on the **first sign-in**. If you don't save it immediately, you never get it.

**Fix:**
```typescript
// app/auth/callback/route.ts
if (code) {
  const supabase = await createClient()
  const { error } = await supabase.auth.exchangeCodeForSession(code)

  if (!error) {
    const { data: { user } } = await supabase.auth.getUser()

    // First sign-in: Apple sends name in user_metadata, but ONLY this once
    if (user?.user_metadata?.full_name && !user.app_metadata?.name_captured) {
      // Save to your users table
      await supabase.from('users').upsert({
        id: user.id,
        full_name: user.user_metadata.full_name
      })

      // Mark as captured so we don't try again
      await supabase.auth.updateAppMetadata({ name_captured: true })
    }

    return NextResponse.redirect(`${origin}${next}`)
  }
}
```

**Why it's #8:** Apple doesn't have a "get user name later" API. You get one shot. If you miss it, the user's name is gone forever (for that Apple ID).

---

## § 9. Email Confirmation Not Handled

**Symptom:** User signs up, never receives the "confirm email" email, can't sign in.

**Root cause:** "Confirm email" is ON in Supabase Dashboard (default), but the app doesn't explain this to the user.

**Fix:**
```typescript
// In your signup handler:
if (data.session) {
  // Auto-confirm is OFF, but session was created (unusual)
  router.push('/dashboard')
} else {
  // Auto-confirm is ON — show "check your email" message
  setMessage('Check your email for a confirmation link!')
}
```

**Or:** Disable "Confirm email" in Dashboard (Supabase → Auth → Providers → Email) for apps that don't need email verification.

**Why it's #9:** Most users don't check spam folders. If they don't get the email, they're locked out.

---

## § 10. Forgot to Add Callback URL to Supabase Allow List

**Symptom:** OAuth sign-in works, but the redirect back to your app fails with "redirect_uri not allowed" or "Invalid redirect URL".

**Root cause:** Forgot to add your app's callback URL to Supabase Dashboard → Auth → URL Configuration.

**Fix:**
1. Supabase Dashboard → **Authentication** → **URL Configuration**
2. **Redirect URLs** → Add:
   ```
   http://localhost:3000/auth/callback
   https://yourapp.com/auth/callback
   ```
3. Click **Save**

**Why it's #10:** Easy to miss because Google/Apple config (separate) works, but Supabase's own allow-list (for the final redirect) is forgotten.

---

## § How to Use This Catalog

When debugging an auth issue:
1. Check the symptoms against the 10 entries
2. Read the root cause to confirm
3. Apply the fix
4. If the issue isn't here, fetch the relevant Supabase docs: `r.jina.ai/https://supabase.com/docs/guides/auth/...`

**For issues not in this catalog:**
- Fetch the Supabase docs (URLs in the skill's frontmatter)
- Check the Supabase Discord: [discord.supabase.com](https://discord.supabase.com/)
- Check the actual code in the operator's repo for context

</pitfall_catalog>
