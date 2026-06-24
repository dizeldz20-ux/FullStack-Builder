<purpose>
Link a custom domain (e.g. `app.example.com`) to a deployed Cloudflare Worker or Pages project. Requires the domain to be added as a Cloudflare zone.
</purpose>

<user-story>
As the user who deployed a product on `*.workers.dev` and now wants to share it on a real domain, I want one command to link the domain, so the temp URL becomes the production URL.
</user-story>

<when-to-use>
- "תחבר domain"
- "תגדיר app.example.com"
- "תעבור לdomain האמיתי"
- "custom domain setup"
- When the user has bought a domain and added it to Cloudflare

NOT for: deploying to a domain that ISN'T on Cloudflare (use a CNAME in the DNS provider instead).
</when-to-use>

<context>
@frameworks/env-inventory-cf.md (confirm there's a zone for the domain)
</context>

<references>
@frameworks/custom-domains-and-routing.md
@frameworks/deployment-security-checklist.md
</references>

<steps>

<step name="verify_zone_exists">
1. The custom domain must be added as a Cloudflare zone
2. Check: `curl "https://api.cloudflare.com/client/v4/zones?name=<domain>" -H "Authorization: Bearer *** <workspace>/memory/.secrets/cloudflare.token)"`
3. Should return 1 result with a zone ID

**If no zone exists**, the user needs to:
1. Buy the domain (any registrar)
2. Add it to Cloudflare: [dash.cloudflare.com](https://dash.cloudflare.com) → Add Site
3. Update nameservers at the registrar to Cloudflare's nameservers
4. Wait for DNS propagation (up to 24h)

**This is a the user action, not a Hermes action. Stop and tell the user to do this.**
</step>

<step name="add_custom_domain_to_worker" priority="last">
Once the zone exists, link the custom domain to the Worker:

**For Workers:**

```bash
# API call
ZONE_ID="<zone-id>"
WORKER_NAME="<project-name>"
DOMAIN="app.example.com"

curl -X PUT "https://api.cloudflare.com/client/v4/accounts/<your-cloudflare-account-id>/workers/scripts/$WORKER_NAME/domains" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data "{\"hostname\":\"$DOMAIN\",\"zone_id\":\"$ZONE_ID\"}"
```

**For Pages:**

```bash
# Via wrangler CLI
wrangler pages domain add app.example.com --project-name=<project-name>
```

Cloudflare auto-provisions an SSL certificate for the custom domain (usually takes 1-5 minutes).
</step>

<step name="verify_dns_propagation">
After adding the custom domain, verify it's resolving:

```bash
# Check DNS
dig app.example.com
# Should resolve to the Worker's *.workers.dev URL or Cloudflare's edge

# Check SSL
curl -I https://app.example.com
# Should return 200 (or the Worker's response)
```

**If the domain doesn't resolve after 5 minutes:**
- Check the zone is set up correctly in Cloudflare Dashboard
- Check the nameservers are pointing to Cloudflare (use `whois app.example.com`)
- Wait longer — DNS propagation can take up to 24h
</step>

<step name="migrate_from_temp_url">
Once the custom domain works:

1. **Update Cloudflare Access** to protect the new domain (or move the existing Access Application)
2. **Tell all testers** about the new URL
3. **Keep the temp URL active** for at least 1 week (in case anyone has the old link bookmarked)
4. **Update documentation** (README, deployment record, etc.)

**To update Access for the new domain:**

```bash
# Update the existing Access Application
curl -X PATCH "https://api.cloudflare.com/client/v4/accounts/{id}/access/apps/$APP_ID" \
  -H "Authorization: Bearer *** -H "Content-Type: application/json" \
  --data '{"domain": "app.example.com"}'
```

Or create a new Access Application for the custom domain and delete the old one.
</step>

<step name="consider_https_only">
Cloudflare auto-issues SSL certificates for custom domains. By default, the domain is HTTPS-only. If the user needs HTTP access (rare), they can disable this in the Cloudflare Dashboard.

**Recommended:** keep HTTPS-only. Modern browsers all support it, and it prevents downgrade attacks.
</step>

</steps>

<output>
## Artifact
- A custom domain (e.g. `app.example.com`) that resolves to the deployed Worker/Pages
- HTTPS auto-provisioned by Cloudflare
- Cloudflare Access updated (or recreated) for the new domain

## Format
- Updated: Cloudflare DNS records (auto-created by Cloudflare)
- Updated: deployment record with the new URL
- Optional: Access Application moved to the new domain
</output>

<acceptance-criteria>
- [ ] Domain is a Cloudflare zone (nameservers pointing to Cloudflare)
- [ ] Custom domain added to the Worker / Pages project
- [ ] DNS resolves correctly (`dig <domain>` returns the right IP)
- [ ] HTTPS works (SSL certificate provisioned, browser shows valid cert)
- [ ] Cloudflare Access protection works on the custom domain
- [ ] Temp URL still works (or is explicitly disabled)
- [ ] the user received: new URL + SSL status + Access instructions
</acceptance-criteria>
