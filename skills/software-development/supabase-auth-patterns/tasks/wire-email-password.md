<purpose>
Set up Email + Password authentication for a Supabase-backed Next.js 15 product. Covers signup, login, password reset, email confirmation flow, and security best practices.
</purpose>

<user-story>
As a the user building a Supabase product, I want users to be able to sign up and sign in with email + password, so that the app works for users who don't want social login (or are in regions where Google/Apple aren't trusted).
</user-story>

<when-to-use>
- User explicitly asks "תוסיף email + password" or "רק Email/Password"
- Starting point for any auth — every Supabase project has Email enabled by default
- Want password reset / email confirmation flows
- This is the **easiest** auth method — start here, add OAuth later if needed
</when-to-use>

<context>
None — this task is self-contained.
</context>

<references>
@frameworks/ssr-client-patterns.md (during step "wire_client_code" — @supabase/ssr + proxy.ts)
@frameworks/env-vars-and-secrets.md (during step "configure_env")
@frameworks/session-management.md (during step "verify_session")
@frameworks/pitfall-catalog.md (load on demand if anything breaks)
@references/supabase-auth-quick-reference.md (most common ops as copy-paste)
</references>

<steps>

<step name="verify_prerequisites" priority="first">
Email auth is enabled by default in every Supabase project. Verify:

1. **Supabase project exists** with URL + Publishable Key in `.env.local`
2. **`@supabase/ssr` installed**: `cat package.json | jq '.["@supabase/ssr"]'`
3. **`proxy.ts` exists** at project root

If any fail, route to the full setup first.
</step>

<step name="configure_email_settings">
Configure email auth in Supabase Dashboard.

1. Open: `https://supabase.com/dashboard/project/<your-ref>/auth/providers`
2. **Email** provider — usually already enabled. Click to expand.
3. **Settings to review**:
   - **Confirm email**: ON (recommended) / OFF (skip for development only)
   - **Secure email change**: ON (recommended)
   - **Minimum password length**: 6 (default) — consider raising to 8+
   - **Custom email templates**: optional, but recommended for branding

4. **Email Confirmation Flow** (if Confirm email = ON):
   - When user signs up, Supabase sends an email with a confirmation link
   - User clicks → redirected to your app's `redirectTo` URL with a `code` param
   - Your app calls `supabase.auth.exchangeCodeForSession(code)` to finalize

5. **SMTP** (optional): Default uses Supabase's SMTP. For production, configure your own (SendGrid, Resend, AWS SES).

**For local development**, Supabase's InBucket catches all emails at `http://127.0.0.1:54324` (if running locally).
</step>

<step name="configure_env">
No additional env vars needed for basic Email auth. All config is in Supabase Dashboard.

If you want to customize the "from" address or use custom SMTP, add:

```bash
# .env.local (only if customizing SMTP via Supabase SMTP settings):
# (No env vars needed for default Supabase SMTP)
```
</step>

<step name="wire_signup">
Create the signup page with form + handler.

```typescript
// app/(auth)/signup/page.tsx
'use client'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { useState } from 'react'

export default function SignupPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')
  const router = useRouter()
  const supabase = createClient()

  async function handleSignup(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
        data: { full_name: '' }  // can be set later in profile
      }
    })
    if (error) {
      setMessage(error.message)
      setLoading(false)
      return
    }

    if (data.session) {
      // Auto-confirm is OFF, but session was created (unusual)
      router.push('/dashboard')
    } else {
      // Auto-confirm is ON — show "check your email" message
      setMessage('Check your email for a confirmation link!')
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSignup}>
      <input type="email" value={email} onChange={e => setEmail(e.target.value)} required />
      <input type="password" value={password} onChange={e => setPassword(e.target.value)} required minLength={6} />
      <button type="submit" disabled={loading}>Sign up</button>
      {message && <p>{message}</p>}
    </form>
  )
}
```
</step>

<step name="wire_login">
Create the login page.

```typescript
// app/(auth)/login/page.tsx
'use client'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { useState } from 'react'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const router = useRouter()
  const supabase = createClient()

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError('')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      setError(error.message)
      setLoading(false)
      return
    }
    router.push('/dashboard')
    router.refresh()  // Important: forces re-fetch of server components
  }

  return (
    <form onSubmit={handleLogin}>
      <input type="email" value={email} onChange={e => setEmail(e.target.value)} required />
      <input type="password" value={password} onChange={e => setPassword(e.target.value)} required />
      <button type="submit" disabled={loading}>Sign in</button>
      {error && <p style={{color: 'red'}}>{error}</p>}
    </form>
  )
}
```
</step>

<step name="wire_password_reset">
Create the password reset flow.

**Request reset link:**
```typescript
// app/(auth)/reset-password/page.tsx
'use client'
import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'

export default function ResetPasswordPage() {
  const [email, setEmail] = useState('')
  const [message, setMessage] = useState('')
  const supabase = createClient()

  async function handleReset(e: React.FormEvent) {
    e.preventDefault()
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/update-password`
    })
    if (error) {
      setMessage(error.message)
    } else {
      setMessage('Check your email for the reset link')
    }
  }

  return (
    <form onSubmit={handleReset}>
      <input type="email" value={email} onChange={e => setEmail(e.target.value)} required />
      <button type="submit">Send reset link</button>
      {message && <p>{message}</p>}
    </form>
  )
}
```

**Set new password (after clicking the email link):**
```typescript
// app/(auth)/update-password/page.tsx
'use client'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { useState, useEffect } from 'react'

export default function UpdatePasswordPage() {
  const [password, setPassword] = useState('')
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    // Check if user is in recovery mode (came from email link)
    supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') {
        // User is in recovery mode — show the form
      }
    })
  }, [])

  async function handleUpdate(e: React.FormEvent) {
    e.preventDefault()
    const { error } = await supabase.auth.updateUser({ password })
    if (error) {
      alert(error.message)
    } else {
      router.push('/dashboard')
    }
  }

  return (
    <form onSubmit={handleUpdate}>
      <input type="password" value={password} onChange={e => setPassword(e.target.value)} required minLength={6} />
      <button type="submit">Update password</button>
    </form>
  )
}
```
</step>

<step name="wire_email_confirmation">
If Confirm email is ON (recommended), you need the callback to handle the confirmation code.

```typescript
// app/auth/callback/route.ts — same as Google/Apple, no provider-specific code
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

**In your email template** (Supabase Dashboard → Auth → Email Templates → Confirm signup), set the redirect URL to:
```
{{ .SiteURL }}/auth/callback
```

Supabase automatically fills in `{{ .ConfirmationURL }}` with the correct callback URL.
</step>

<step name="add_logout">
Same as Google/Apple:

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
</step>

<step name="rate_limit_awareness">
Supabase has built-in rate limits. Document for the user:

- **Signups**: 30 per hour per IP (configurable in Dashboard)
- **Sign-ins**: 30 per hour per email
- **Password resets**: 4 per hour per email

If users hit these limits, they get 429 errors. For higher limits, request via Supabase support.
</step>

<step name="final_verification">
- [ ] `signUp` creates a new user in `auth.users` table
- [ ] If Confirm email is ON, signup shows "check your email" message
- [ ] If Confirm email is OFF, signup auto-creates session
- [ ] Clicking the email link redirects to `/auth/callback` and creates a session
- [ ] `signInWithPassword` works for confirmed users
- [ ] `resetPasswordForEmail` sends a reset link
- [ ] Clicking the reset link goes to `/update-password` and allows setting new password
- [ ] `signOut` clears cookies and redirects
- [ ] Wrong password shows error, doesn't create session
- [ ] `proxy.ts` refreshes session on every request
</step>

</steps>

<output>
## Artifact
Email/Password auth is wired up. Users can sign up, sign in, reset their password, and sign out. Email confirmation flow works (if enabled).

## Format
- New files: `app/(auth)/signup/page.tsx`, `app/(auth)/login/page.tsx`, `app/(auth)/reset-password/page.tsx`, `app/(auth)/update-password/page.tsx`
- New: `app/(auth)/actions.ts` (signOut Server Action)
- No new env vars needed (Email auth works out of the box)

## Location
Standard Next.js 15 App Router structure. Email config is in Supabase Dashboard (templates, SMTP, rate limits).
</output>

<acceptance-criteria>
- [ ] Signup creates user in `auth.users`
- [ ] Email confirmation flow works (if Confirm email = ON)
- [ ] Login with correct password succeeds
- [ ] Login with wrong password shows error, no session created
- [ ] Password reset email is sent
- [ ] Password reset link allows setting new password
- [ ] SignOut clears session cookie
- [ ] Rate limits are documented
- [ ] Email templates are customized for branding (recommended)
- [ ] `proxy.ts` refreshes session correctly
</acceptance-criteria>
