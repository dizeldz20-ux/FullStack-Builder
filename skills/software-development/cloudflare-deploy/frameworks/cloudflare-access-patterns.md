<cloudflare_access_patterns>

## Purpose
How to use Cloudflare Access (Zero Trust) to protect temporary URLs. Covers the auth methods, the policy structure, the API calls, and the common mistakes.

## When this framework loads
- During `tasks/protect-with-cloudflare-access.md` (always)
- When the user has a temp URL that needs auth
- Before any deploy that produces a public URL

---

## § What is Cloudflare Access?

Cloudflare Access is a zero-trust auth layer that sits in front of any URL on Cloudflare's network. It works with:
- Workers
- Pages
- Any Cloudflare-protected website (not just Workers/Pages)

**The value:** A URL like `https://my-app.<your-subdomain>.workers.dev` is publicly accessible by default. With Cloudflare Access, anyone visiting the URL sees an auth screen first. Only authorized identities (emails, service tokens, etc.) can proceed.

**Free tier:** unlimited users, unlimited applications. (Paid tier adds SSO, advanced policies, etc.)

**This is what the user needs for temp URLs** — share the link with a tester, they enter their email, get a PIN code, and they see the app. No public exposure.

---

## § Auth methods (5 options)

| Method | When to use | Setup |
|---|---|---|
| **One-time PIN** (built-in) | Quick demos, low-stakes sharing | Zero setup, sends PIN to email |
| **Google / Apple / GitHub OAuth** | Apps with these IdPs | Configure OAuth client in Cloudflare |
| **SAML / OIDC** | Enterprise apps | Configure IdP in Cloudflare |
| **Service token** | Machine-to-machine (curl, scripts) | Generate client_id + client_secret |
| **Email domain allow** | Whole-team access | Add `*@company.com` to the policy |

**For the user's temp URLs (default):** one-time PIN. Zero setup, works immediately.

**For machine-to-machine APIs:** service token. the user can call the API with headers.

---

## § The 3-part structure

Cloudflare Access protection requires:

1. **An Application** — defines what URL is protected
2. **A Policy** — defines who can access
3. **An Identity Provider** — defines how they authenticate (built-in PIN, Google, etc.)

You can have multiple policies on one application (e.g. "Allow the user's email" AND "Allow service token X").

---

## § Recipe: One-time PIN protection (most common)

### Step 1: Create the Application

```bash
# Replace these
ACCOUNT_ID="<your-cloudflare-account-id>"
TOKEN=*** <workspace>/memory/.secrets/cloudflare.token)
APP_NAME="my-product-temp"
DOMAIN="my-product.<your-subdomain>.workers.dev"  # The deployed URL hostname, no protocol

curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"$APP_NAME\",
    \"domain\": \"$DOMAIN\",
    \"type\": \"self_hosted\",
    \"session_duration\": \"24h\",
    \"app_launcher_visible\": false,
    \"allowed_idps\": []
  }"
```

**Response:** JSON with an `id` (UUID) — save it as the Access Application ID.

**Notes:**
- `session_duration`: how long the auth is valid (24h is good for temp URLs)
- `app_launcher_visible: false`: don't show it in Cloudflare's app launcher (it's a temp URL, not a permanent app)
- `allowed_idps: []`: empty means use the built-in one-time PIN

### Step 2: Add a Policy

```bash
APP_ID="<from step 1>"
USER_EMAIL="<your-email>"

curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps/$APP_ID/policies" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"Allow the user\",
    \"decision\": \"allow\",
    \"include\": [
      {\"email\": [\"$USER_EMAIL\"]}
    ],
    \"require\": [],
    \"exclude\": []
  }"
```

**Notes:**
- `decision: "allow"` — explicitly allow
- `include.email` — list of emails that can access (use multiple for multiple users)
- For more users, add more emails: `{"email": ["user1@example.com", "user2@example.com"]}`

### Step 3: Test

1. Open the URL in an incognito browser window
2. Expect to see a Cloudflare Access auth screen (looks like Cloudflare's brand)
3. Enter the user's email
4. Check the inbox for a 6-digit PIN
5. Enter the PIN
6. See the actual app

**If you don't see the auth screen:** the `domain` in the application doesn't match the actual URL. Verify it exactly.

---

## § Recipe: Service token (machine-to-machine)

### Step 1: Create the Service Token

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/service-tokens" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"name": "my-api-caller"}'
```

**Response:** includes `client_id` and `client_secret`. **Save these — they won't be shown again.**

### Step 2: Create the Application (same as before)

Use the same recipe as one-time PIN, but skip the policy for now.

### Step 3: Add a Policy that allows the Service Token

```bash
SERVICE_TOKEN_ID="<from step 1>"

curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps/$APP_ID/policies" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"name\": \"Allow service token\",
    \"decision\": \"allow\",
    \"include\": [
      {\"service_token\": {\"uuid\": \"$SERVICE_TOKEN_ID\"}}
    ]
  }"
```

### Step 4: Use the Token

```bash
CLIENT_ID="<from step 1>"
CLIENT_SECRET="<from step 1>"

curl -H "CF-Access-Client-Id: $CLIENT_ID" \
     -H "CF-Access-Client-Secret: $CLIENT_SECRET" \
     https://<worker>.workers.dev/api
```

**Anti-pattern:** Don't put the service token credentials in a public repo. They're effectively a password.

---

## § Recipe: Multiple users (team access)

For multiple users, add multiple emails to the policy:

```bash
"include": [
  {"email": ["<your-email>", "tester1@example.com", "tester2@example.com"]}
]
```

Or allow a whole email domain:

```bash
"include": [
  {"email_domain": ["example.com"]}
]
```

Anyone with an email at `example.com` can access. Useful for team access.

---

## § Common pitfalls

### "No identity providers configured"
- Cause: The application requires a specific IdP but none is set up
- Fix: Use `allowed_idps: []` (empty array = use built-in one-time PIN)

### "Access denied" even with the right email
- Cause: Policy is `deny` instead of `allow`, or the email doesn't match
- Fix: Check the policy's `decision` and `include` array

### "Email never arrives"
- Cause: Email is in spam, or the email provider is blocking Cloudflare
- Fix: Check spam folder, add `noreply@cloudflare.com` to contacts, try a different email

### The protected URL is still accessible without auth
- Cause: The application's `domain` doesn't match the actual URL exactly
- Fix: Re-create the application with the exact hostname (no protocol, no path)

### Service token doesn't work
- Cause: Token revoked, or wrong headers
- Fix: Verify the token is still active in Dashboard, check both `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers

### I want to allow Google login
- Cause: Need to configure Google as an IdP
- Fix: More complex — see [Cloudflare docs on IdP setup](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/). Usually overkill for a temp URL.

---

## § To remove protection (when going to production)

1. **Cloudflare Dashboard** → Zero Trust → Access → Applications
2. Find the application by name
3. Click "Delete"
4. The URL is now publicly accessible again

For a cleaner workflow: don't use Cloudflare Access for production. Use the app's own auth (Supabase, Clerk, etc.). Cloudflare Access is for temp URLs and internal tools.

---

## § Verification checklist

- [ ] Application created with correct domain
- [ ] Policy allows at least one identity
- [ ] Visiting the URL without auth shows the auth screen
- [ ] Logging in with the correct email + PIN works
- [ ] Logging in with a different email is rejected
- [ ] Access Application ID is documented
- [ ] Service token credentials (if used) are saved securely (not in chat / git)

</cloudflare_access_patterns>
