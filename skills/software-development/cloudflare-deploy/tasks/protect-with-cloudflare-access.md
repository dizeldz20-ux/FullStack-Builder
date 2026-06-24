<purpose>
Add Cloudflare Access protection (username + password, or one-time PIN) to a deployed Worker or Pages URL. Prevents public access to temporary URLs.
</purpose>

<user-story>
As the user who has a temp URL on `*.workers.dev` or `*.pages.dev`, I want one command to add a password / one-time PIN protection, so I can safely share the link with a client or tester without exposing the data to the public internet.
</user-story>

<when-to-use>
- "תוסיף סיסמה ל-URL"
- "תגן על ה-URL"
- "תוסיף Cloudflare Access"
- "תעשה את זה private"
- After ANY deploy (this is non-negotiable for temp URLs)

NOT for: production URLs with proper auth already (Supabase, Clerk, etc.) — Access adds a layer, doesn't replace.
</when-to-use>

<context>
@frameworks/env-inventory-cf.md (confirm the Worker/Pages project exists)
</context>

<references>
@frameworks/cloudflare-access-patterns.md (full pattern reference)
@frameworks/deployment-security-checklist.md
</references>

<steps>

<step name="verify_target_exists">
1. Confirm the URL is deployed (read it from `.hermes/cf-deploy/` or ask the user)
2. Confirm the Worker / Pages project exists: `mcp_cloudflare_worker_list` or `mcp_cloudflare_r2_list_buckets`... wait, that's R2. Use the Workers MCP.
3. Confirm Cloudflare Access is available (it should be, on all Cloudflare accounts including free tier)

If the URL isn't deployed, stop and route to `deploy-static-site.md` or `deploy-nextjs-fullstack.md` first.
</step>

<step name="choose_auth_method">
Cloudflare Access supports several auth methods. Choose based on the use case:

| Method | When to use | Setup |
|---|---|---|
| **One-time PIN** (built-in) | Quick demos, low-stakes sharing | Zero setup, sends PIN to email |
| **Email + password** | Custom login, no Google/Apple | Requires custom IdP setup |
| **Google / Apple / GitHub** | OAuth-based, easier for users | Configure OAuth client |
| **Service token** | Machine-to-machine (curl, scripts) | No UI, client_id + client_secret |
| **Allow specific email** | Personal use, only the user | Just add the email to a policy |

**For the user's temp URLs (default):** one-time PIN. Zero setup, works immediately, the user gets a PIN in their email.

**For machine-to-machine APIs:** service token. the user can call the API with `CF-Access-Client-Id` + `CF-Access-Client-Secret` headers.

**For Google/Apple/GitHub:** would require OAuth setup, usually overkill for a temp URL.
</step>

<step name="create_access_application">
**Via the Cloudflare API:**

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/access/apps" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{
    "name": "<project-name>-temp-protection",
    "domain": "<deployed-url-hostname>",
    "type": "self_hosted",
    "session_duration": "24h",
    "app_launcher_visible": false,
    "allowed_idps": [],  # Empty = use built-in one-time PIN
    "policies": []
  }'
```

The response includes an `id` (UUID) — save it as the Access Application ID.

**Domain to protect:** the URL without `https://` prefix. E.g. `my-product.<your-subdomain>.workers.dev`.

**For Pages:** the domain is `<hash>.<project-name>.pages.dev`.
</step>

<step name="add_policy" priority="last">
The Application is created but no one can access it without a policy. Add at least one:

**Option A: Allow the user's email (one-time PIN)**

```bash
APP_ID="<from previous step>"

curl -X POST "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/access/apps/$APP_ID/policies" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{
    "name": "Allow the user",
    "decision": "allow",
    "include": [
      {
        "email": ["<your-email>"]  # Replace with the operator's email
      }
    ],
    "require": [],
    "exclude": []
  }'
```

When the user visits the URL, he gets a one-time PIN sent to his email. He enters it, sees the site.

**Option B: Allow service token (machine-to-machine)**

```bash
# 1. Create a service token
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{id}/access/service-tokens" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"name": "the user API caller"}'

# Response includes client_id and client_secret — save these
# 2. Add a policy that allows this service token
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{id}/access/apps/$APP_ID/policies" \
  --data '{
    "name": "Allow service token",
    "decision": "allow",
    "include": [{"service_token": {"uuid": "<token-uuid>"}}]
  }'
```

the user uses the token:
```bash
curl -H "CF-Access-Client-Id: <id>" -H "CF-Access-Client-Secret: <secret>" \
     https://<project>.workers.dev/api
```

**For multiple users:** add multiple emails to the `include` array, or use `email_domain` to allow all emails from a specific domain.
</step>

<step name="verify_protection">
1. Visit the URL in an incognito browser window
2. Expect to see the Cloudflare Access auth screen (NOT the actual app)
3. Enter the email → get a PIN code in the inbox
4. Enter the PIN code → see the actual app
5. Test in a different browser / device to make sure the policy is enforced everywhere

**Common issues:**

| Symptom | Cause | Fix |
|---|---|---|
| Site loads without auth | App not linked to Access | Check the `domain` field matches exactly |
| "No identity providers configured" | No IdP set up | Built-in one-time PIN should be enabled by default; if not, contact Cloudflare support |
| Email never arrives | Email typo in policy | Check the `include` array |
| "Access denied" after entering PIN | Policy is `deny` instead of `allow` | Change decision to `allow` |
</step>

<step name="document_protection">
Save the protection details to the deployment record:

```markdown
# Cloudflare Access Protection — <project-name>

## Application
- **ID**: <uuid>
- **Name**: <project-name>-temp-protection
- **Domain**: <deployed-url-hostname>
- **Created**: <timestamp>

## Policy
- **Name**: "Allow the user"
- **Decision**: allow
- **Includes**: 
  - <your-email> (one-time PIN)

## Access method for the user
- **Method**: One-time PIN via email
- **Email**: <your-email>
- **PIN valid for**: 1 hour after request

## To remove protection (when going to production)
1. Cloudflare Dashboard → Zero Trust → Access → Applications
2. Find the application by name
3. Click "Delete"
```

The Access Application ID is critical — save it for future updates (e.g. adding more allowed emails).
</step>

</steps>

<output>
## Artifact
- A Cloudflare Access Application protecting the temp URL
- One or more policies controlling who can access
- Documented protection record

## Format
- Updated: `.hermes/cf-deploy/<project-name>-<timestamp>.md` with Access Application ID
- The Cloudflare Dashboard shows the application under Zero Trust → Access → Applications
</output>

<acceptance-criteria>
- [ ] Cloudflare Access Application created
- [ ] Policy allows at least one identity (email or service token)
- [ ] Visiting the URL without auth shows the auth screen
- [ ] Logging in with the correct email + PIN shows the app
- [ ] Logging in with a different email is rejected
- [ ] Access Application ID is documented
- [ ] the user received: URL + the email to use for the PIN + clear instructions
</acceptance-criteria>
