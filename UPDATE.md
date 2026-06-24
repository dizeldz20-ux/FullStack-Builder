# Update Log — FullStack-Builder

This document explains what changed between releases. The README still describes the high-level "what is this" — this file documents "what's new since last release" so users updating from an older version know what to expect.

---

## v1.4.0 (2026-06-25) — Israeli + Marketing + Comms

### 🎉 What's new in v1.4.0

Added 6 new skills for Israeli market + production marketing:

| Skill | Purpose |
|-------|---------|
| `shabbat-aware-scheduler` | Block deploys during Shabbat/Yom Tov |
| `hebrew-voice-bot-builder` | Hebrew IVR/voice bots |
| `n8n-hebrew-workflows` | n8n 2.0 with Israeli APIs |
| `greenapi-whatsapp-bot-builder` | Green API WhatsApp bot |
| `creative/popular-web-designs` | 54 production design systems |
| `creative/hyperframes` | HTML→video compositions |

### Changed

- `deploy-to-cloudflare.md` — added `shabbat_deploy_check`
- `ship.md` — added `marketing_assets` step
- `new-product.md` — added `pick_israeli_extensions` step
- Loop count: 14 → 19 (added Loop 18: Israeli Deploy Window, Loop 19: Marketing Asset Build)

---

## v1.2.1 (2026-06-24) — Major update (historical)

### 🎉 What's new

#### 7 new skills added (in v1.2.1)

The original 4-skill release covered infrastructure (Cloudflare, Supabase) and process (build-product, product-build-blueprint). This update fills the rest of the end-to-end product lifecycle:

| New skill | What it does | When to load |
|-----------|--------------|--------------|
| `prd-generator` | 10-question interview → full PRD with Goals, User Stories, Acceptance Criteria, Edge Cases, Open Questions | Before any non-trivial build |
| `api-contract-designer` | User Stories → OpenAPI 3.1 / GraphQL SDL + Zod schemas + generated TS types | After PRD, before code |
| `e2e-testing` | Playwright smoke tests + visual regression + CI integration | After features are built |
| `analytics-monitoring` | Sentry (errors) + PostHog (analytics) + uptime + cost alerts | After first deploy |
| `privacy-tos-generator` | Privacy Policy + ToS + Cookie banner + DPA templates (with legal disclaimer) | Before launch, before any data collection |
| `pricing-monetization` | Pricing model selection + Stripe subscriptions + metered billing + paywall UX | When deciding how to charge |
| `customer-support-templates` | Welcome email + onboarding sequence + churn-prevention emails + FAQ | When you have users |

#### build-product upgraded to v1.2.1

- **Loop count: 7 → 14**. Added 7 new feedback loops that wrap each of the 7 new skills. Each loop has explicit trigger, body, stop condition, max iterations, and the anti-pattern it prevents.
- **Related skills: 27 → 34**. The 7 new skills are wired into the orchestrator's routing.
- **Three-Rule mandate**: added a section at the top of `frameworks/user-defaults.md` that enforces (1) search before asking, (2) know which machine you're on, (3) confirm understanding before non-trivial work. These are generic rules — adapt the search paths to your environment.
- **CHANGELOG**: added version history file.

#### Loop Coverage Matrix

`build-product/frameworks/loops.md` now ends with a table that maps every skill → which loops apply. Useful when adding a new skill and wondering "which loops should I enable?".

### 📁 File counts

| Skill | Before | After | Change |
|-------|--------|-------|--------|
| build-product | 11 files | 13 files (+CHANGELOG) | +2 |
| prd-generator | (new) | 8 files | +8 |
| api-contract-designer | (new) | 10 files | +10 |
| e2e-testing | (new) | 11 files | +11 |
| analytics-monitoring | (new) | 8 files | +8 |
| privacy-tos-generator | (new) | 7 files | +7 |
| pricing-monetization | (new) | 7 files | +7 |
| customer-support-templates | (new) | 6 files | +6 |
| ui-design-system | (new in repo) | 11 files | +11 |
| **Total** | ~50 files | **131 files** | **+81** |

### 🔧 What to do when updating from v1.0.x

If you installed an earlier version:

1. **Pull latest** (or re-clone the repo).
2. **Re-copy the skills** you want into your Hermes skills directory:
   ```bash
   cp -r FullStack-Builder/skills/software-development/build-product ~/.hermes/skills/software-development/
   # ...same for any other skills you want
   ```
3. **Update skill references** — if you have any custom skills that referenced `<name>-defaults.md` (an older name pattern), they need to be updated to `user-defaults.md`. The file was renamed to be generic (no personal names).
4. **Review the Three-Rule mandate** in `user-defaults.md` — adapt the search paths to match your actual file layout. The rules are generic; the paths are placeholders.
5. **Check the security scan** — run `scripts/security-scan.sh` on your project to make sure no secrets leaked. The repo is scrubbed of account IDs, emails, and personal paths, but your local project might still have them.

### 🔒 Security notes

- The public repo contains **no** Cloudflare account IDs, no personal emails, no internal paths. All such values are placeholders like `<your-cloudflare-account-id>` or `<workspace>`.
- The repo contains a `scripts/security-scan.sh` that catches accidental leaks of these patterns. Run it before any PR.
- A feedback-loop pattern is used throughout to ensure every loop has bounded retries, explicit stop conditions, and documented anti-patterns. Read `build-product/frameworks/loops.md` for the 14-loop catalog.

### 🧪 Verified

All 15 skills in this repo pass `scripts/security-scan.sh` (0 findings) and `scripts/audit-skill.sh` (frontmatter closed, all cross-references resolve). Tested on Linux with Hermes Agent.

### 📝 License

Still MIT. Use freely, modify freely, sell if you want.

---

## v1.0.0 (2026-06-23) — Initial release

4 skills:
- `build-product` (orchestrator, 27 related skills, 7 loops)
- `supabase-auth-patterns` (OAuth + RLS)
- `cloudflare-deploy` (Workers/Pages/Access)
- `product-build-blueprint` (Hebrew, lightweight)
- `ui-design-system` (Layout/Theme/Animation)

License: MIT. README, CONTRIBUTING, security-scan in CI.
