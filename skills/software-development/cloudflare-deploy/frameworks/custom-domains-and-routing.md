<custom_domains_and_routing>

## Purpose
How to link a custom domain (e.g. `app.example.com`) to a Cloudflare Worker or Pages project. Covers DNS requirements, the API calls, SSL provisioning, and the common mistakes.

## When this framework loads
- During `tasks/link-custom-domain.md`
- When the user has a domain and wants to use it instead of `*.workers.dev`
- When migrating a temp URL to a production URL

---

## § Prerequisites

To link a custom domain, you need:

1. **The domain is added to Cloudflare as a zone** (nameservers pointing to Cloudflare)
2. **The Worker or Pages project exists** and is deployed
3. **DNS is not blocked** by the registrar (some require explicit approval)

If you don't have the domain in Cloudflare yet, **stop and tell the user to add it first**. This is a the user action, not a Hermes action.

---

## § How to add a domain to Cloudflare

1. Buy the domain at any registrar (Namecheap, Google Domains, Cloudflare Registrar, etc.)
2. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → "Add Site"
3. Enter the domain, select the plan (Free is fine for most uses)
4. Cloudflare scans for existing DNS records — review and import
5. Cloudflare gives you 2 nameservers (e.g. `aria.ns.cloudflare.com`, `sid.ns.cloudflare.com`)
6. Go to your registrar, change the nameservers to Cloudflare's
7. Wait for DNS propagation (up to 24h, usually 5-30 min)

**Once the nameservers are set**, Cloudflare manages all DNS for the domain. You can add records, set up Workers, etc.

---

## § Adding a custom domain to a Worker

### Option A: Via Cloudflare Dashboard (easiest)

1. Dashboard → Workers & Pages → click your Worker
2. Settings → Domains & Routes → Add → Custom Domain
3. Enter `app.example.com` (or `*.example.com` for a wildcard)
4. Click "Add Custom Domain"
5. Cloudflare auto-creates the DNS record and provisions SSL

**Wait 1-5 minutes** for SSL provisioning. The domain will start working.

### Option B: Via wrangler.jsonc

```jsonc
{
  "routes": [
    {
      "pattern": "app.example.com",
      "custom_domain": true
    }
  ]
}
```

Then `wrangler deploy`. Cloudflare handles the rest.

### Option C: Via API

```bash
ZONE_ID="<cloudflare-zone-id>"  # From `GET /zones?name=app.example.com`
WORKER_NAME="<project-name>"
DOMAIN="app.example.com"

curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/scripts/$WORKER_NAME/domains" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data "{\"hostname\":\"$DOMAIN\",\"zone_id\":\"$ZONE_ID\"}"
```

**Note:** the zone ID is for the **parent domain** (`example.com`), not the subdomain (`app.example.com`).

---

## § Adding a custom domain to Pages

### Option A: Via Cloudflare Dashboard

1. Dashboard → Workers & Pages → click your Pages project
2. Custom domains → Set up a domain
3. Enter `app.example.com`
4. If the zone is on Cloudflare, Cloudflare auto-creates the CNAME
5. If the zone is elsewhere, you'll need to add a CNAME record manually

### Option B: Via wrangler CLI

```bash
wrangler pages domain add app.example.com --project-name=<project-name>
```

### Option C: Manual CNAME (if zone is NOT on Cloudflare)

If the domain's nameservers are pointing to a different provider (e.g. the user only wants Pages to handle the subdomain, not the whole zone):

1. In the Pages dashboard, add `app.example.com` as a custom domain
2. Cloudflare will tell you: "Add this CNAME record at your DNS provider"
3. Go to your DNS provider (e.g. Namecheap)
4. Add a CNAME record:
   - Type: CNAME
   - Name: `app` (or `app.example.com` if your provider requires the full name)
   - Target: `<project-name>.pages.dev`
5. Wait for DNS propagation

---

## § SSL / HTTPS

Cloudflare auto-provisions SSL certificates for custom domains:

- **Universal SSL** (free): auto-issued, valid for the domain + 1 level of subdomains
- **Advanced Certificate Manager** (paid): wildcard certs, custom validity, more control

**For 90% of the user's products:** Universal SSL is enough. It's automatic and free.

**SSL provisioning time:** usually 1-5 minutes after the custom domain is added. Can take up to 24h in rare cases.

**To check SSL status:**
1. Dashboard → Workers & Pages → your project → Settings → Domains & Routes
2. Each custom domain shows the SSL status

If SSL fails to provision, check:
- The nameservers are pointing to Cloudflare (use `whois app.example.com`)
- The zone is active (not paused)
- There's no conflicting CAA record at the DNS provider

---

## § Wildcard subdomains

To handle all subdomains (e.g. `*.app.example.com` → same Worker), add a wildcard:

**Via Dashboard:** Workers & Pages → your Worker → Custom domains → Add → `*.app.example.com`

**Via wrangler.jsonc:**
```jsonc
{
  "routes": [
    {
      "pattern": "*.app.example.com/*",
      "custom_domain": true
    }
  ]
}
```

**Wildcard requires a paid Cloudflare plan** (Advanced Certificate Manager or Business+).

For most cases, you only need specific subdomains (not wildcards), which work on the free plan.

---

## § Migrating from temp URL to custom domain

When the temp URL is `my-product.<your-subdomain>.workers.dev` and the custom domain is `app.example.com`:

### Step 1: Add the custom domain (as above)

### Step 2: Update Cloudflare Access (if used)

```bash
# Get the current Access App ID for the temp URL
# Either delete the old app and create a new one for the custom domain
# Or PATCH the existing app to use the new domain

curl -X PATCH "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps/$APP_ID" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"domain": "app.example.com"}'
```

### Step 3: Notify users

- Update README, docs, deployment record
- Tell testers: "the new URL is `app.example.com`, the old `my-product.<your-subdomain>.workers.dev` still works for a week"
- After 1 week, you can delete the old Worker (or keep it as a redirect)

### Step 4: Optional — redirect the old URL to the new one

Add a redirect Worker:

```typescript
// old-url-redirect worker
export default {
  async fetch(request) {
    const newUrl = request.url.replace(
      'my-product.<your-subdomain>.workers.dev',
      'app.example.com'
    )
    return Response.redirect(newUrl, 301)
  }
}
```

Deploy this as a new Worker with the old Worker's name, then delete the old Worker.

---

## § Common pitfalls

### "Custom domain not found"
- Cause: Zone doesn't exist or nameservers not pointing to Cloudflare
- Fix: Add the zone in Dashboard, wait for nameserver propagation

### SSL certificate pending for hours
- Cause: Sometimes Cloudflare takes longer for less common TLDs or wildcard certs
- Fix: Wait up to 24h. If still pending, check the zone is active

### "DNS record conflicts"
- Cause: A record already exists for that hostname
- Fix: Delete the conflicting record first, then add the custom domain

### Old temp URL still in use
- Cause: You didn't tell users the URL changed
- Fix: Send a notification, keep the old URL active for 1-2 weeks

### Wildcard subdomain doesn't work
- Cause: Free plan doesn't support wildcard SSL
- Fix: Upgrade to a paid plan OR add specific subdomains instead of a wildcard

### Page shows old content (browser cache)
- Cause: Browser cached the old URL response
- Fix: Hard refresh (Cmd+Shift+R), or test in incognito

---

## § Verification checklist

- [ ] Domain is a Cloudflare zone (nameservers pointing to Cloudflare)
- [ ] Zone is active (not paused)
- [ ] Custom domain added to Worker / Pages project
- [ ] DNS resolves correctly (`dig app.example.com`)
- [ ] SSL certificate provisioned (browser shows valid cert)
- [ ] HTTPS works (`curl -I https://app.example.com` returns 200)
- [ ] Cloudflare Access protection works on the custom domain (if used)
- [ ] Old temp URL behavior decided (keep active / delete / redirect)

</custom_domains_and_routing>
