# FullStack Builder

> A suite of **34 Hermes skills** across **11 categories** for end-to-end product building — from idea to deployed, monitored, monetized, and supported production app.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hermes](https://img.shields.io/badge/Hermes-skill-blueviolet)](https://hermes.nousresearch.com)
[![Skillsmith](https://img.shields.io/badge/Skillsmith-compliant-green)](https://github.com/smith-horn/skillsmith)
[![Version](https://img.shields.io/badge/version-v1.5.0-blue)](UPDATE.md)

## What is this?

**FullStack Builder** is a collection of **34 skills** across **11 categories** for [Hermes](https://hermes.nousresearch.com) that work together to take you from a product idea to a deployed, monitored, monetized, and supported production app. Updated regularly; see [UPDATE.md](UPDATE.md) for changelog.

### Skills by lifecycle phase

| Phase | Skill | Purpose |
|-------|-------|---------|
| **Discovery** | `competitor-product-research-to-build` (built into `build-product`) | Market scan, competitor analysis |
| **Spec** | `prd-generator` *(new in v1.2.1)* | 10-question interview → full PRD |
| **Design** | `ui-design-system` | Layout → Theme → Animation → Implementation |
| **API** | `api-contract-designer` *(new in v1.2.1)* | OpenAPI/GraphQL + Zod + TS types |
| **Auth** | `supabase-auth-patterns` | Google + Apple + Email auth with RLS |
| **Build** | `build-product` (orchestrator, 14 loops) | End-to-end pipeline with TDD + subagents |
| **Lightweight** | `product-build-blueprint` | Hebrew, 7-step flow for small projects |
| **Test** | `e2e-testing` *(new in v1.2.1)* | Playwright smoke + visual regression |
| **Deploy** | `cloudflare-deploy` | Workers/Pages/Access with temp URLs |
| **Legal** | `privacy-tos-generator` *(new in v1.2.1)* | Privacy/ToS/Cookie/DPA templates |
| **Monitor** | `analytics-monitoring` *(new in v1.2.1)* | Sentry + PostHog + uptime + cost alerts |
| **Monetize** | `pricing-monetization` *(new in v1.2.1)* | Pricing models + Stripe + paywall |
| **Support** | `customer-support-templates` *(new in v1.2.1)* | Welcome/onboarding/churn/FAQ |

### Additional skills (v1.5.0)

Beyond the 13 core lifecycle skills, v1.5.0 adds **21 more skills** across 9 additional categories:

| Category | Skill | Purpose |
|----------|-------|---------|
| **Cavecrew** | `cavecrew-builder` | Surgical 1-2 file edit subagent |
| **Cavecrew** | `cavecrew-investigator` | Read-only code locator subagent |
| **Cavecrew** | `cavecrew-reviewer` | Diff/branch/file reviewer subagent |
| **Creative** | `creative/hyperframes` | HTML-based video compositions |
| **Creative** | `creative/popular-web-designs` | 54 production design systems |
| **Creative** | `creative/sketch` | Throwaway HTML mockups |
| **Design** | `design/` | UI design system skills |
| **DevOps** | `devops/` | Deployment & infrastructure skills |
| **Dogfood** | `dogfood` | Exploratory QA of web apps |
| **Israeli** | `greenapi-whatsapp-bot-builder` | Green API WhatsApp bot |
| **Israeli** | `n8n-hebrew-workflows` | n8n 2.0 with Israeli APIs |
| **Israeli** | `shabbat-aware-scheduler` | Block deploys during Shabbat/Yom Tov |
| **Dev** | `software-development/html-structured-extract` | Extract rows from HTML pages |
| **Dev** | `software-development/node-inspect-debugger` | Node.js `--inspect` debugging |
| **Dev** | `software-development/oauth-helper` | OAuth login automation |
| **Dev** | `software-development/python-debugpy` | Python debugpy (DAP) |
| **Dev** | `software-development/requesting-code-review` | Pre-commit review automation |
| **Dev** | `software-development/spike` | Throwaway experiments |
| **Dev** | `software-development/subagent-driven-development` | Plans via delegate_task subagents |
| **Dev** | `software-development/systematic-debugging` | 4-phase root cause debugging |
| **Dev** | `software-development/test-driven-development` | TDD: RED-GREEN-REFACTOR |
| **Dev** | `software-development/writing-plans` | Bite-sized implementation plans |

**Total**: 34 skills across 11 categories (13 core + 21 additional).

## Installation

### One-command install (recommended)

```bash
# Clone directly into the Hermes skills root (skills become auto-discoverable)
# Note: a category prefix (software-development/, design/, devops/, dogfood/) is required.
git clone https://github.com/dizeldz20-ux/FullStack-Builder.git /tmp/fsb && \
  cp -r /tmp/fsb/skills/* ~/.hermes/skills/

# Or install individual skills
mkdir -p ~/.hermes/skills/software-development
cp -r FullStack-Builder/skills/software-development/build-product ~/.hermes/skills/software-development/
```

### Manual install (pick specific skills)

Copy whichever skill(s) you need from `skills/` into your `~/.hermes/skills/` directory, preserving the category structure:

```
skills/
├── software-development/
│   ├── build-product/
│   ├── supabase-auth-patterns/
│   ├── cloudflare-deploy/
│   └── product-build-blueprint/
└── design/
    └── ui-design-system/
```

## Quick start

```bash
# Inside Hermes:
/build-product new
# → Walks you through all 5 phases:
# 1. Product discovery
# 2. Architecture + plan
# 3. Build (with TDD + subagents)
# 4. Smoke test
# 5. Auto-deploy to Cloudflare (with secure temp URL)
```

For a quick script or bot:

```bash
/blueprint new
# → 7 simple steps (no state machine, no TDD strict)
```

For UI design:

```bash
/ui-design full
# → 4 phases: wireframe → theme → animation → implementation
```

## How the skills work together

```
build-product (orchestrator)
│
├── product-build-blueprint    (for small/simple projects)
│
├── ui-design-system           (load BEFORE any UI work)
│
├── supabase-auth-patterns     (when the product needs users)
│
└── cloudflare-deploy           (auto-deploys after build)
```

Each skill is **standalone** (you can use any one independently) but they're **designed to compose**.

## Philosophy

- **Vertical slices over horizontal layers** — one user-visible capability end-to-end before the next
- **TDD strict, but only for the orchestrator** — `product-build-blueprint` is for fast one-offs
- **Plan before code** — wireframe → theme → animation → implementation, in that order
- **No secrets in chat** — credentials always go to `~/.config/<service>/<file>` with `chmod 600`
- **Every temp URL gets Cloudflare Access** — `*.workers.dev` URLs are public by default
- **3+ commands = 1 script** — never list numbered steps when a script can do it

## Documentation

Each skill has its own README in its folder:

- [`skills/software-development/build-product/SKILL.md`](skills/software-development/build-product/SKILL.md)
- [`skills/software-development/product-build-blueprint/SKILL.md`](skills/software-development/product-build-blueprint/SKILL.md)
- [`skills/software-development/supabase-auth-patterns/SKILL.md`](skills/software-development/supabase-auth-patterns/SKILL.md)
- [`skills/software-development/cloudflare-deploy/SKILL.md`](skills/software-development/cloudflare-deploy/SKILL.md)
- [`skills/design/ui-design-system/SKILL.md`](skills/design/ui-design-system/SKILL.md)

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). TL;DR: open an issue before sending a PR, follow the skillsmith spec, and test against a real Hermes install.

## Credits

Built by [dizeldz20-ux](https://github.com/dizeldz20-ux) with Hermes Agent. Inspired by:
- [skillsmith](https://github.com/smith-horn/skillsmith) — skill-writing convention
- the agent's `super-builder` and `superdesign` — original 7-step and 4-phase flows (anonymized; the original is a peer agent's design)
- Supabase, Cloudflare, Next.js — the stack these skills target
