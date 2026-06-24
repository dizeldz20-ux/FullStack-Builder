<open_questions_catalog>

# Open Questions Catalog

Common open questions that surface during PRD interviews. When an OQ from the interview matches a catalog entry, cross-reference it. This is the "what we don't know and should figure out" pre-seeded list.

## Purpose
Speed up the Open Questions surfacing step (Q10) by giving the skill a known list of typical gaps. When a Q-N answer is vague or missing, check the catalog before writing a fresh OQ.

---

## Authentication & Identity

### OQ-CAT-1: Authentication method
- **Context:** User said "users will log in" but didn't specify how.
- **Blocks:** Auth flow design, database schema (users table), security model
- **Suggested resolution:** Ask user explicitly. Options: email/password, magic link, OAuth (Google/GitHub), phone (OTP). Default to magic link for low-friction MVP.
- **Priority:** P0

### OQ-CAT-2: Multi-user vs single-user
- **Context:** User said "users" but didn't say if multiple users share data.
- **Blocks:** Data model (per-user vs shared), permission system
- **Suggested resolution:** Ask. If single-user → no auth needed at all for MVP.
- **Priority:** P0

### OQ-CAT-3: Account recovery
- **Context:** Auth exists. What happens when user forgets password?
- **Blocks:** Email service dependency, recovery flow
- **Suggested resolution:** For MVP → password reset via email. For no-email → in-app code or admin reset.
- **Priority:** P1

## Pricing & Monetization

### OQ-CAT-4: Pricing model
- **Context:** User said "people will pay" but not how.
- **Blocks:** Payment integration, billing logic, revenue projection
- **Suggested resolution:** Options — one-time, monthly subscription, usage-based, freemium. Ask. If unsure → start with free MVP, add paid later.
- **Priority:** P0

### OQ-CAT-5: Payment provider
- **Context:** Pricing decided. How to charge?
- **Blocks:** Integration scope, fee structure, international support
- **Suggested resolution:** Default = Stripe. For Israel: Stripe + Bit/PayBox for local. For mobile: Apple/Google IAP mandatory.
- **Priority:** P0

### OQ-CAT-6: Free tier
- **Context:** Pricing decided but no free tier mentioned.
- **Blocks:** Onboarding, conversion strategy
- **Suggested resolution:** Ask. Default = 14-day trial or limited free tier.
- **Priority:** P1

## Data & Privacy

### OQ-CAT-7: Data retention
- **Context:** User mentioned storing data. How long?
- **Blocks:** Storage cost, GDPR compliance, deletion flow
- **Suggested resolution:** Default = indefinitely until user deletes account. Document this in privacy policy.
- **Priority:** P1

### OQ-CAT-8: GDPR / Privacy compliance
- **Context:** User collects any personal data.
- **Blocks:** Legal exposure, data export/deletion features, cookie banner
- **Suggested resolution:** For Israeli users — Privacy Protection Law applies. Default = GDPR-style compliance (export + delete).
- **Priority:** P0 (if EU users) / P1 (if only Israel)

### OQ-CAT-9: Data export
- **Context:** User has data. Can users export it?
- **Blocks:** Export feature scope, data format
- **Suggested resolution:** Default = CSV / JSON export of user-owned data. Skip for MVP if user explicitly says no.
- **Priority:** P1

## Scale & Performance

### OQ-CAT-10: Expected user count (Year 1)
- **Context:** No mention of scale.
- **Blocks:** Hosting choice, database choice, caching strategy
- **Suggested resolution:** <1K users → serverless (Cloudflare Workers + D1). 1K-100K → managed (Supabase + Vercel). >100K → custom infra. Ask user.
- **Priority:** P0

### OQ-CAT-11: Latency / response time requirement
- **Context:** No SLA mentioned.
- **Blocks:** Architecture decisions, caching, CDN
- **Suggested resolution:** Default = <500ms p95. If user says "instant" → <200ms. Document in Technical Constraints.
- **Priority:** P1

### OQ-CAT-12: International / multi-language
- **Context:** Hebrew mentioned but unclear if multi-language.
- **Blocks:** i18n architecture, content pipeline
- **Suggested resolution:** For Israeli-only → Hebrew + English (RTL handling). For global → i18n from day 1 (expensive). Ask.
- **Priority:** P0

## Notifications & Communication

### OQ-CAT-13: Email notifications
- **Context:** User said "notify user" but didn't specify channel.
- **Blocks:** Email service integration, template design
- **Suggested resolution:** Default = transactional email (Resend / SendGrid). For Israel → consider SMS via Cellcom.
- **Priority:** P1

### OQ-CAT-14: Push notifications (mobile)
- **Context:** Mobile app mentioned.
- **Blocks:** FCM/APNS setup, permission UX
- **Suggested resolution:** For MVP → skip push, use email. Add push in V1.1.
- **Priority:** P2

### OQ-CAT-15: In-app real-time updates
- **Context:** User wants "live" data.
- **Blocks:** WebSocket / SSE architecture, scaling
- **Suggested resolution:** Default = polling every 30s. Real-time only if explicitly required.
- **Priority:** P1

## Integrations

### OQ-CAT-16: Third-party API dependencies
- **Context:** Product needs external data (e.g., weather, stocks, social).
- **Blocks:** API key acquisition, rate limits, cost, fallbacks
- **Suggested resolution:** List every external API. For each: provider, auth, rate limit, fallback when down.
- **Priority:** P0

### OQ-CAT-17: Webhooks / outbound integrations
- **Context:** User wants to send data to other systems.
- **Blocks:** Webhook infrastructure, retry logic
- **Suggested resolution:** Default = simple webhook with HMAC signature. Add retry queue if user says "must be reliable".
- **Priority:** P1

## Hosting & Operations

### OQ-CAT-18: Deployment target
- **Context:** No hosting decision.
- **Blocks:** CI/CD, infra-as-code
- **Suggested resolution:** For web → Cloudflare Pages + Workers (default for Hermes workflow). For backend → Fly.io or Railway. For mobile → App Store / Play Store.
- **Priority:** P0

### OQ-CAT-19: CI/CD pipeline
- **Context:** User wants continuous deployment.
- **Blocks:** GitHub Actions config, secrets management
- **Suggested resolution:** Default = GitHub Actions with auto-deploy on main. Manual approval for prod.
- **Priority:** P1

### OQ-CAT-20: Monitoring & error tracking
- **Context:** No mention of observability.
- **Blocks:** Production debugging, alerting
- **Suggested resolution:** Default = Sentry for errors, basic uptime check. Skip analytics for MVP unless explicitly needed.
- **Priority:** P1

## UX & Design

### OQ-CAT-21: Mobile vs web vs both
- **Context:** Unclear platform.
- **Blocks:** Tech stack, design system, deployment
- **Suggested resolution:** Default = web only for MVP. Add PWA if mobile-feel needed. Native only if explicitly required.
- **Priority:** P0

### OQ-CAT-22: Accessibility (a11y)
- **Context:** No mention of a11y requirements.
- **Blocks:** Component choices, QA scope
- **Suggested resolution:** Default = basic WCAG AA (keyboard nav, contrast, alt text). Full a11y = P1.
- **Priority:** P1

### OQ-CAT-23: RTL / Hebrew UI
- **Context:** Hebrew users.
- **Blocks:** CSS direction handling, font choice, layout testing
- **Suggested resolution:** Use `dir="rtl"` + Hebrew-friendly font (Heebo, Rubik, Assistant). Test on Hebrew content from day 1.
- **Priority:** P0 (if Hebrew)

## Legal & Compliance

### OQ-CAT-24: Terms of Service / Privacy Policy
- **Context:** Public-facing product.
- **Blocks:** Legal exposure, app store approval
- **Suggested resolution:** Use a template (e.g., Termly). Have lawyer review if handling sensitive data.
- **Priority:** P0 (public launch) / P1 (MVP)

### OQ-CAT-25: Israeli regulations
- **Context:** Operating in Israel.
- **Blocks:** Privacy law compliance, accessibility law (Israel 5568)
- **Suggested resolution:** Privacy Protection Law + Accessibility Law apply. Default to GDPR-style compliance.
- **Priority:** P0

## Scope & Timeline

### OQ-CAT-26: MVP deadline
- **Context:** User said "soon" / "asap" but no date.
- **Blocks:** Feature prioritization, build-product planning
- **Suggested resolution:** Ask for hard date. If flexible → "ship when 1-2 core flows work end-to-end".
- **Priority:** P0

### OQ-CAT-27: Solo vs team
- **Context:** User didn't say who else is building.
- **Blocks:** Workflow (CI, code review), documentation needs
- **Suggested resolution:** Solo → leaner docs, no PR review. Team → add review step, ADRs, onboarding doc.
- **Priority:** P1

### OQ-CAT-28: Post-MVP support
- **Context:** No mention of maintenance.
- **Blocks:** Hosting cost, support commitment
- **Suggested resolution:** Default = "ship and iterate, support via email for first 30 days". If commercial → add SLA.
- **Priority:** P2

---

## How to Use This Catalog

When a Q-N answer is vague or missing:

1. **Scan this catalog** for matching topic.
2. **Reference the OQ-CAT-N** in the PRD's Open Questions section.
3. **Customize the resolution** to the specific product (don't copy-paste the default verbatim).

Format in the PRD:

```markdown
### OQ-3: Authentication method (cf. OQ-CAT-1)
- **Context:** User mentioned "users will log in" without specifying method
- **Blocks:** Auth flow, users table, security model
- **Suggested resolution:** [customize — e.g., "Email magic link via Resend. No password."]
- **Priority:** P0
```

If a new gap is found that's NOT in the catalog → still write an OQ, just don't add a CAT reference.

</open_questions_catalog>

---

*Framework maintained by prd-generator skill · Built with Skillsmith*
<!-- skillsmith_version: 1.0.0 -->
