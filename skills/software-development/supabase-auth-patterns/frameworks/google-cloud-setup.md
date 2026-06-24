<google_cloud_setup>

## Purpose
Step-by-step walkthrough for creating a Google OAuth Client ID and Client Secret for Sign in with Google, then configuring it in Supabase. This is the most common OAuth provider — required for almost every web product.

## When this framework loads
- During `tasks/setup-google-oauth.md` → step "create_oauth_credentials"
- When user wants to add a new Google OAuth client (e.g. for a second app/web property)

---

## § The 5-Minute Walkthrough

### Step 1: Create or select a Google Cloud project

1. Open [console.cloud.google.com](https://console.cloud.google.com/)
2. Top-left dropdown → **New Project** (or select existing)
3. Name it (e.g. "MyProduct Web") → **Create**
4. Wait for the project to provision (~30 seconds)

### Step 2: Configure OAuth Consent Screen

1. Left menu → **APIs & Services** → **OAuth consent screen**
2. Choose **User Type**:
   - **External** — for public apps (most common)
   - **Internal** — only if you're on Google Workspace and want to limit to your org
3. Fill in:
   - **App name**: your product name
   - **User support email**: your email
   - **App logo**: optional but recommended
   - **App domain**: your product URL
   - **Authorized domains**: `supabase.co` (for the OAuth callback to work)
   - **Developer contact**: your email
4. Click **Save and Continue**
5. **Scopes** step:
   - Click **Add or Remove Scopes**
   - Add: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`
   - Click **Update** → **Save and Continue**
6. **Test users** step (only if User Type = External and app is in "Testing" mode):
   - Add your own email + any testers
   - Click **Save and Continue**
7. **Summary** → **Back to Dashboard**

### Step 3: Create OAuth Client ID

1. Left menu → **APIs & Services** → **Credentials**
2. Top → **Create Credentials** → **OAuth client ID**
3. **Application type**: **Web application**
4. **Name**: something descriptive (e.g. "MyProduct Web Client")
5. **Authorized JavaScript origins** — click **Add URI** for each:
   ```
   http://localhost:3000         # dev (Next.js default)
   https://yourapp.com            # production
   ```
   *Match these to your actual URLs. Wrong origin = silent failure on sign-in.*
6. **Authorized redirect URIs** — click **Add URI** for each:
   ```
   http://127.0.0.1:54321/auth/v1/callback   # local Supabase (if using supabase CLI)
   https://<your-supabase-ref>.supabase.co/auth/v1/callback  # production
   ```
   **The Supabase redirect URL must be EXACTLY correct.** Copy it from Supabase Dashboard → Auth → Providers → Google → "Callback URL" field.
7. Click **Create**
8. **Modal appears with Client ID and Client Secret.** Copy both immediately. You can also download as JSON.

### Step 4: Configure in Supabase Dashboard

1. Open `https://supabase.com/dashboard/project/<your-ref>/auth/providers`
2. Click **Google** → toggle **Enable sign in with Google**
3. Paste:
   - **Client ID** (from step 3)
   - **Client Secret** (from step 3)
4. **Authorized Client IDs** (optional) — leave empty for now
5. Click **Save**

### Step 5: Add to redirect allow-list in Supabase

1. Supabase Dashboard → **Authentication** → **URL Configuration**
2. **Redirect URLs** — add your app's callback URL:
   ```
   http://localhost:3000/auth/callback
   https://yourapp.com/auth/callback
   ```
3. Click **Save**

---

## § Common Pitfalls

### "redirect_uri_mismatch" error
**Cause**: The redirect URL in Google Console doesn't EXACTLY match what Supabase sends.
**Fix**: Copy the URL from Supabase Dashboard → Auth → Providers → Google → Callback URL field. Paste into Google Console. Match the protocol (http vs https), domain, port, and path exactly.

### "This app isn't verified" warning
**Cause**: Your OAuth Consent Screen is in "Testing" mode.
**Fix for dev**: Click "Advanced" → "Go to <app> (unsafe)" — Google shows this to anyone not in the test users list.
**Fix for production**: Submit your app for verification. Takes 3-7 business days. Only required if you add sensitive/restricted scopes.

### Sign-in works locally but not in production
**Cause**: You forgot to add the production domain to Authorized JavaScript origins in Google Console.
**Fix**: Add `https://yourapp.com` to **Authorized JavaScript origins** in Google Console. Also add `https://<ref>.supabase.co/auth/v1/callback` to **Authorized redirect URIs**.

### "Access blocked: This app's request is invalid"
**Cause**: Scopes don't match between your app's request and what Google sees.
**Fix**: Make sure the OAuth Consent Screen has `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile` scopes enabled.

---

## § Multi-Platform Setup (iOS + Android + Web)

If you have separate iOS and Android clients, you create separate OAuth client IDs for each:

1. **Web**: Type "Web application" (this is what we created above)
2. **iOS**: Type "iOS" — needs Bundle ID
3. **Android**: Type "Android" — needs package name + SHA-1 fingerprint

Then in Supabase Dashboard → Auth → Providers → Google → "Authorized Client IDs", add them all comma-separated. The **first one must be the Web client ID** (per Supabase docs).

---

## § Verification Checklist

- [ ] Google Cloud project created
- [ ] OAuth Consent Screen configured with name + scopes
- [ ] OAuth Client ID created (Web application type)
- [ ] Authorized JavaScript origins include dev + prod URLs
- [ ] Authorized redirect URIs include Supabase callback URLs
- [ ] Client ID + Secret saved (in password manager)
- [ ] Supabase Dashboard → Google provider enabled
- [ ] Supabase Dashboard → URL Configuration has your app's callback URL

## § Time Estimate
- First time: 15-30 minutes (with verification)
- Repeated: 5-10 minutes

## § Costs
**Free** — Google OAuth has no per-user cost. Google's free tier allows 10,000 token verifications/month.

</google_cloud_setup>
