<apple_developer_setup>

## Purpose
Step-by-step walkthrough for Apple Sign in setup: App ID, Services ID, .p8 private key, Team ID, Key ID. **The most expensive and complex provider** ($99/year). Required for iOS apps that offer other social logins (App Store policy).

## When this framework loads
- During `tasks/setup-apple-oauth.md` → step "create_apple_credentials"
- When the user has confirmed they have an Apple Developer account and want to proceed

---

## § Prerequisites (BLOCKING)

| Prerequisite | Cost | If missing |
|---|---|---|
| **Apple Developer Account** | $99/year | **STOP.** Do not proceed. Tell the user to enroll at [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/). Approval takes 24-48 hours. |
| **Owned domain** (for production) | Domain registration | For production Services ID, Apple verifies domain ownership via DNS TXT record. For local dev only, `127.0.0.1` works. |
| **Reverse domain naming** decided | Free | e.g. `com.<your-company>.myapp` for App ID, `com.<your-company>.myapp.web` for Services ID |

**If any of these are missing, do not start this task. The setup will fail in non-obvious ways and waste hours.**

---

## § The Setup (when prerequisites are met)

### Step 1: Sign in to Apple Developer Console

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Sign in with the Apple ID that has the Developer Program enrollment
3. Note the **Team ID** in the top-right corner (10-character alphanumeric, e.g. `ABCDE12345`). **Save this — you'll need it for Supabase.**

### Step 2: Create an App ID

1. Go to **Certificates, Identifiers & Profiles**
2. Left sidebar → **Identifiers** (click the filter icon and select "App IDs" if not visible)
3. Click the **+** button (top right) to register a new identifier
4. Select **App IDs** → **Continue**
5. **Platform**: iOS, macOS, or **Web** (depends on your use case)
   - For web OAuth (most common with Supabase): choose **Web**
6. **Description**: a human-readable name (e.g. "MyProduct Web")
7. **Bundle ID** (App ID Prefix + Bundle ID): reverse domain, e.g. `com.<your-company>.myapp`
   - ⚠️ This is **permanent** — can't change later
8. **Capabilities** — scroll down and check ✅ **Sign in with Apple**
9. Click **Continue** → **Register**

**Important:** In the App ID capabilities, **leave "Server-to-Server Notification" empty** — Supabase doesn't support it yet.

### Step 3: Create a Services ID (for web OAuth)

1. Still in **Identifiers**, click **+** again
2. Select **Services IDs** → **Continue**
3. **Description**: e.g. "MyProduct Web Services"
4. **Identifier**: reverse domain + `.web` or `.services`, e.g. `com.<your-company>.myapp.web`
5. Click **Continue** → **Register**
6. Click on the newly created Services ID to edit it
7. **Sign in with Apple** section → click **Configure**
8. **Primary App ID**: select the App ID you created in Step 2
9. **Web Domain Configuration**:
   - **Domains and Subdomains**: add one per line:
     ```
     <your-supabase-ref>.supabase.co    # production
     ```
     (For local dev, you don't add `127.0.0.1` here — it's handled separately)
   - **Return URLs**: add one per line:
     ```
     https://<your-supabase-ref>.supabase.co/auth/v1/callback
     ```
10. Click **Save** → **Continue** → **Save**

**The Return URL must match EXACTLY what Supabase sends.** Get the exact URL from Supabase Dashboard → Auth → Providers → Apple → Callback URL field.

### Step 4: Create a Private Key (.p8)

1. Left sidebar → **Keys** (under "Certificates, Identifiers & Profiles")
2. Click the **+** button to register a new key
3. **Key Name**: e.g. "MyProduct Sign in with Apple Key"
4. **Capabilities** → check ✅ **Sign in with Apple**
5. Click **Configure** (next to the checkbox)
6. **Primary App ID**: select the App ID from Step 2
7. Click **Save** → **Continue** → **Register**
8. **CRITICAL: Download the .p8 file NOW.** Apple only lets you download it once. If you lose it, you must revoke and create a new key.
9. Save the .p8 file to a secure path. **Recommended:** `~/.config/apple/<key-id>.p8` with `chmod 600`.
10. Note the **Key ID** (10 characters, e.g. `XYZ1234567`)

**You now have everything Apple needs:**
- Team ID (Step 1)
- Services ID (Step 3)
- Key ID (Step 4)
- .p8 file contents (Step 4)

---

## § Configure in Supabase Dashboard

1. Open `https://supabase.com/dashboard/project/<your-ref>/auth/providers`
2. Click **Apple** → toggle **Enable**
3. Fill in:
   - **Client ID**: the Services ID (e.g. `com.<your-company>.myapp.web`)
   - **Account ID** (Team ID): the 10-char Team ID from Step 1
   - **Key ID**: the 10-char Key ID from Step 4
   - **Secret Key**: open the .p8 file, copy the **entire contents** (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines)
4. Click **Save**

---

## § First-Sign-In Name Capture (CRITICAL)

Apple only sends the user's name on the **first sign-in**. If you don't save it, you'll never get it. The code is in `tasks/setup-apple-oauth.md` → step "handle_first_signin_name".

---

## § Common Pitfalls

### "invalid_client" error
**Cause**: Wrong Client ID, Team ID, or Key ID in Supabase Dashboard.
**Fix**: Triple-check all 3 values. Re-copy from Apple Developer Console.

### "redirect_uri_mismatch" error
**Cause**: Return URL in Apple Services ID doesn't match what Supabase sends.
**Fix**: Verify EXACT match. `https://<ref>.supabase.co/auth/v1/callback` — protocol, domain, port, path.

### ".p8 file is not a valid private key"
**Cause**: You pasted a different key file, or the file is corrupted.
**Fix**: Re-download the .p8 from Apple (you can't — you must revoke and recreate). If you lost it, create a new key in Step 4.

### User's name is `null` after first sign-in
**Cause**: You didn't capture `user_metadata.full_name` immediately.
**Fix**: Add the first-sign-in handler from `tasks/setup-apple-oauth.md` step "handle_first_signin_name".

### "Hide My Email" relay issues
**Cause**: User chose to hide their email. Apple generates a relay like `xyz@privaterelay.appleid.com`.
**Fix**: This is expected. Supabase stores the **real** email in `auth.users.email`. The user sees the relay. Document this in your privacy policy.

### iOS App Store rejection: "Sign in with Apple missing"
**Cause**: Your iOS app offers Google or Facebook sign-in but not Apple.
**Fix**: Apple requires Apple sign-in when any other social login is offered. Use AuthenticationServices framework (not web OAuth) for iOS native. This task covers web only.

---

## § Verification Checklist

- [ ] Apple Developer account active and verified
- [ ] App ID created with Sign in with Apple capability
- [ ] Services ID created with correct Web Domain + Return URL
- [ ] Private key (.p8) downloaded and stored securely (chmod 600)
- [ ] Team ID, Key ID, Services ID, .p8 contents all saved
- [ ] Supabase Dashboard → Apple provider enabled with all 4 fields
- [ ] First sign-in captures `full_name` and saves to users table
- [ ] Sign-in works in browser

## § Time Estimate
- First time: 30-60 minutes (including account verification)
- Repeated: 15-20 minutes (if you already have App ID and Services ID)

## § Costs
- **Apple Developer Program: $99/year** (mandatory)
- App operations: free

</apple_developer_setup>
