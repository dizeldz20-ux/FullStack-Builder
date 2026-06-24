<purpose>
Set up Apple OAuth sign-in for a Supabase-backed Next.js 15 product. Covers: Apple Developer Console setup (App ID + Services ID + .p8 private key), Supabase Dashboard configuration, Next.js 15 client code, and the Apple-specific quirks (first-sign-in name, hidden email relay).
</purpose>

<user-story>
As a the user building a Supabase product, I want users to be able to sign in with their Apple ID, so that I can ship an iOS app or comply with App Store guidelines (which require Apple sign-in when other social providers are offered).
</user-story>

<when-to-use>
- User explicitly asks "תוסיף Apple sign-in" or "Sign in with Apple"
- Product has an iOS native app (App Store requires it if you offer Google/Facebook)
- Compliance requirement (some markets/regulations require Apple sign-in)
- DO NOT use this for a web-only MVP — it costs $99/year and adds complexity for marginal value
</when-to-use>

<context>
None — this task is self-contained.
</context>

<references>
@frameworks/apple-developer-setup.md (during step "create_apple_credentials" — full Apple Developer walkthrough)
@frameworks/ssr-client-patterns.md (during step "wire_client_code" — @supabase/ssr + proxy.ts)
@frameworks/env-vars-and-secrets.md (during step "configure_env")
@frameworks/session-management.md (during step "verify_session" + Apple first-sign-in quirk)
@frameworks/pitfall-catalog.md (load on demand if anything breaks)
@references/supabase-auth-quick-reference.md
</references>

<steps>

<step name="verify_prerequisites" priority="first">
**Three things must be true before starting:**

1. **Apple Developer Account** — $99/year. Verify at [developer.apple.com/account](https://developer.apple.com/account):
   ```bash
   # If you don't have one, the task is BLOCKED. Tell the user:
   # "Apple OAuth requires an Apple Developer account ($99/yr). Confirm you have one, or skip this task and use Email/Google only."
   ```

2. **Supabase project already configured** (this task assumes Google or Email is already wired):
   ```bash
   grep -E "NEXT_PUBLIC_SUPABASE_(URL|PUBLISHABLE_KEY)" .env.local
   ```

3. **A Services ID reverse domain** — you need to own/control a domain. For local dev, `127.0.0.1` works. For production, you need `yourapp.com` registered.

If any of these fail, **stop and tell the user**. Apple is the most expensive and complex provider — don't proceed without confirmation.
</step>

<step name="create_apple_credentials">
Full walkthrough in `@frameworks/apple-developer-setup.md`. Short version:

1. [developer.apple.com/account/resources](https://developer.apple.com/account/resources) → **Identifiers**:
   - **App ID** (e.g. `com.<your-company>.myapp`):
     - Capabilities: ✅ **Sign in with Apple**
     - ⚠️ Leave **Server-to-Server Notification** blank (Supabase doesn't support it)
   - **Services ID** (e.g. `com.<your-company>.myapp.web`):
     - Web Domain: `<your-supabase-ref>.supabase.co` (prod), `127.0.0.1:54321` (local)
     - Return URL: `https://<your-supabase-ref>.supabase.co/auth/v1/callback`

2. **Keys** → Create new key:
   - ✅ Sign in with Apple
   - Select the App ID
   - **Download the .p8 file** — you can only download it once. Save it to a secure path.
   - Note the **Key ID** (10 chars)

3. Find your **Team ID**: top-right of Apple Developer Console (10 chars).

**Wait for the user to provide:** Services ID, Team ID, Key ID, and the .p8 file path.
</step>

<step name="configure_supabase">
Configure Apple provider in Supabase Dashboard.

1. Open: `https://supabase.com/dashboard/project/<your-ref>/auth/providers`
2. Click **Apple** → toggle **Enable**
3. Fill in:
   - **Client ID** = Services ID (e.g. `com.<your-company>.myapp.web`)
   - **Team ID** = (10 chars)
   - **Key ID** = (10 chars)
   - **Secret Key** = entire contents of the `.p8` file (starts with `-----BEGIN PRIVATE KEY-----`)
4. Click **Save**

**Verify it worked:**

```bash
export SUPABASE_ACCESS_TOKEN=$(cat <workspace>/memory/.secrets/supabase.token)
supabase --project-ref "$SUPABASE_REF" inspect auth config 2>/dev/null | grep -A 2 "apple\|external_apple"
# Should show external_apple_enabled: true
```
</step>

<step name="wire_client_code">
The code is **identical to Google** — Supabase handles the provider routing. Just change `'google'` to `'apple'`:

```typescript
// app/(auth)/login/page.tsx
async function signInWithApple() {
  const supabase = createClient()
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'apple',
    options: { redirectTo: `${window.location.origin}/auth/callback` }
  })
  if (error) console.error(error)
}

// app/auth/callback/route.ts — SAME as Google, no changes needed
```

That's it. The Apple-specific logic is all in the .p8 + Supabase Dashboard.
</step>

<step name="handle_first_signin_name" priority="last">
**CRITICAL Apple quirk:** Apple only sends the user's `full_name` on the **first sign-in**. If you don't save it immediately, you'll never get it.

```typescript
// app/auth/callback/route.ts — add this after exchangeCodeForSession
if (code) {
  const supabase = await createClient()
  const { data, error } = await supabase.auth.exchangeCodeForSession(code)

  if (!error) {
    const { data: { user } } = await supabase.auth.getUser()

    // First sign-in: Apple sends name in user_metadata, but ONLY this once
    if (user?.user_metadata?.full_name) {
      // Save to your users table:
      await supabase.from('users').upsert({
        id: user.id,
        email: user.email,
        full_name: user.user_metadata.full_name
      })
    }

    return NextResponse.redirect(`${origin}${next}`)
  }
}
```

**Without this step, your users will have `null` names forever.**
</step>

<step name="handle_hidden_email">
Apple offers "Hide My Email" — users get a relay like `xyz@privaterelay.appleid.com`. Supabase stores the **real** email in `auth.users.email`, but the user sees the relay. This is fine for most apps. Document it in your privacy policy.

If you need the real email (e.g. for transactional emails that won't reach relay), tell users to disable "Hide My Email" during onboarding, or use the `email` field from `user.email` directly.
</step>

<step name="verify_session">
Test the flow:

1. `npm run dev`
2. Open `http://localhost:3000/login` (or your dev URL)
3. Click "Sign in with Apple"
4. Apple consent screen → Face ID / passcode → redirect back
5. Check DevTools → Application → Cookies → `sb-<ref>-auth-token` exists
6. Check `/debug/session` (temporary) — should show Apple user with `app_metadata.provider: "apple"`

**Common failures:**

| Symptom | Cause | Fix |
|---|---|---|
| "invalid_client" | Wrong Client ID or Team ID | Re-check Apple Developer Console |
| Redirect loop | Return URL mismatch | Verify exactly `https://<ref>.supabase.co/auth/v1/callback` |
| Empty user_metadata on second sign-in | Expected — Apple only sends name once | Already handled in step "handle_first_signin_name" |
</step>

<step name="final_verification">
- [ ] Apple Developer account active ($99/yr paid)
- [ ] App ID created with Sign in with Apple capability
- [ ] Services ID created with correct Web Domain + Return URL
- [ ] Private key (.p8) generated and stored securely
- [ ] Supabase Dashboard → Apple provider enabled with all 4 fields
- [ ] Sign-in flow works in browser
- [ ] First sign-in saves full_name to users table
- [ ] Subsequent sign-ins don't re-prompt for name (expected)
- [ ] `proxy.ts` refreshes session
- [ ] No errors in browser console

**If iOS app planned:** Also need to add the Sign in with Apple capability in Xcode, configure the App ID, and use native `AuthenticationServices` API (not the web OAuth flow). This task covers web only.
</step>

</steps>

<output>
## Artifact
Apple OAuth sign-in is wired up. Users can sign in with Apple from web. First sign-in saves the user's name (the only time Apple sends it).

## Format
- Updated: `app/auth/callback/route.ts` (added first-sign-in name capture)
- New: Apple sign-in button in login page (same code pattern as Google, just `provider: 'apple'`)
- No new env vars needed (all Apple config lives in Supabase Dashboard)

## Location
Standard Next.js 15 App Router structure. Apple config is split between:
- Apple Developer Console (App ID, Services ID, .p8)
- Supabase Dashboard (Client ID, Team ID, Key ID, Secret)
</output>

<acceptance-criteria>
- [ ] Apple Developer account active and verified
- [ ] App ID + Services ID + .p8 key created in Apple Developer Console
- [ ] Supabase Dashboard Apple provider configured with all 4 fields
- [ ] `redirectTo` URL matches Apple Developer Services ID Return URL
- [ ] First sign-in captures `full_name` and saves to users table
- [ ] Subsequent sign-ins don't re-prompt for name (correct behavior)
- [ ] "Hide My Email" relay emails work (or documented limitation)
- [ ] No errors in browser console during sign-in
- [ ] Protected routes accessible after sign-in
</acceptance-criteria>
