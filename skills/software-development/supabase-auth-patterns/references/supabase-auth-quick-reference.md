<supabase_auth_quick_reference>

# Supabase Auth — Quick Reference

Copy-paste code snippets for the most common Supabase Auth operations. All examples use Next.js 15 + `@supabase/ssr` + `proxy.ts`.

---

## § Sign Up (Email + Password)

```typescript
const { data, error } = await supabase.auth.signUp({
  email,
  password,
  options: {
    emailRedirectTo: `${window.location.origin}/auth/callback`,
    data: { full_name: 'the user' }  // goes to user_metadata
  }
})
```

## § Sign In (Email + Password)

```typescript
const { data, error } = await supabase.auth.signInWithPassword({ email, password })
```

## § Sign In (OAuth — Google / Apple / GitHub)

```typescript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google',  // or 'apple', 'github', 'azure', etc.
  options: { redirectTo: `${window.location.origin}/auth/callback` }
})
```

## § Sign In (Magic Link)

```typescript
const { data, error } = await supabase.auth.signInWithOtp({
  email,
  options: { emailRedirectTo: `${window.location.origin}/auth/callback` }
})
```

## § Sign Out

```typescript
await supabase.auth.signOut()
```

## § Password Reset Request

```typescript
const { error } = await supabase.auth.resetPasswordForEmail(email, {
  redirectTo: `${window.location.origin}/auth/callback?next=/update-password`
})
```

## § Update Password (after reset link)

```typescript
const { error } = await supabase.auth.updateUser({ password: newPassword })
```

## § OAuth Callback Handler (PKCE)

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

## § Read Current User (Server Component)

```typescript
// Recommended: getClaims() (no network call)
const { data: { claims } } = await supabase.auth.getClaims()
if (!claims) redirect('/login')

// When you need fresh data: getUser() (network call)
const { data: { user } } = await supabase.auth.getUser()
```

## § Get Session (for tokens)

```typescript
const { data: { session } } = await supabase.auth.getSession()
const accessToken = session?.access_token
```

## § Update User Metadata

```typescript
// User-editable metadata (raw_user_meta_data)
const { data, error } = await supabase.auth.updateUser({
  data: { full_name: 'New Name' }
})
```

## § Listen to Auth State Changes (Client)

```typescript
const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN') console.log('signed in', session)
  if (event === 'SIGNED_OUT') console.log('signed out')
  if (event === 'TOKEN_REFRESHED') console.log('token refreshed')
  if (event === 'PASSWORD_RECOVERY') console.log('password recovery mode')
})

// Don't forget to unsubscribe:
subscription.unsubscribe()
```

## § Insert User Row (First Sign-In)

```typescript
// After sign-in, create a row in your users table
const { data: { user } } = await supabase.auth.getUser()
if (user) {
  await supabase.from('users').upsert({
    id: user.id,
    email: user.email,
    full_name: user.user_metadata?.full_name || '',
    avatar_url: user.user_metadata?.avatar_url || ''
  })
}
```

## § Service Role (Admin Operations — Server Only)

```typescript
// lib/supabase/admin.ts
import { createClient } from '@supabase/supabase-js'

export const createAdminClient = () => createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SECRET_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
)

// Use only in Server Actions / Route Handlers:
const admin = createAdminClient()
await admin.auth.admin.createUser({ email, password, email_confirm: true })
```

## § RLS Policy: User Owns Row

```sql
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);
```

## § RLS Policy: User Owns via Foreign Key

```sql
CREATE POLICY "Users can view own interactions" ON interactions
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
```

## § RLS Policy: Public Read, Authenticated Write

```sql
CREATE POLICY "Anyone can view posts" ON posts
  FOR SELECT TO anon, authenticated
  USING (published = true);
-- No INSERT/UPDATE/DELETE policies = blocked
```

---

*For the full patterns and explanations, see `tasks/` and `frameworks/` in this skill.*

*Validated 2026-06-24 against Supabase docs.*
