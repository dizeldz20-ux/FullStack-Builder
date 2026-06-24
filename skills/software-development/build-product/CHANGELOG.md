# Changelog — build-product

All notable changes to this skill are documented here. Format: [Semantic Versioning](https://semver.org/).

## [1.4.0] — 2026-06-25

### Added — 6 new skills wired into the pipeline (Israeli + Marketing + Comms)

After auditing skills in the upstream skills registry, 6 were identified as critical for products targeting the Israeli market or needing production-grade marketing assets.

| Skill | Purpose | Pipeline phase |
|-------|---------|----------------|
| `shabbat-aware-scheduler` | Block deploys that would land during Shabbat or Yom Tov; resume after Havdalah | Phase 7 (Deploy gate) |
| `hebrew-voice-bot-builder` | Hebrew IVR / voice bots for Israeli businesses (Whisper he-IL, Twilio +972) | Phase 3-4 (Voice feature impl) |
| `n8n-hebrew-workflows` | n8n 2.0 automation with Israeli APIs (Morning / Green Invoice, Cardcom, Tranzila) | Phase 5.5 (Automation handoff) |
| `greenapi-whatsapp-bot-builder` | One-shot Green API WhatsApp bot builder (menu + button routing) | Phase 3-4 (WhatsApp feature) |
| `creative/popular-web-designs` | 54 production design systems (Stripe, Linear, Vercel) as HTML/CSS templates | Phase 2.5 (UI reference) |
| `creative/hyperframes` | HTML→video compositions for marketing (hero demo, social card, captioned video) | Phase 6 (Polish & Showcase) |

### Added — 2 new feedback loops (Loop 18, 19)

| Loop | Skill(s) | What it catches |
|------|----------|-----------------|
| **Loop 18: Israeli Deploy Window** | `shabbat-aware-scheduler` | Deploys that would land during Shabbat/Yom Tov (Friday 5pm in summer = sundown = users hit by failed deploys at kabbalat shabbat) |
| **Loop 19: Marketing Asset Build** | `hyperframes` + `popular-web-designs` | Launches with no hero video / no social card / no design reference — bare GitHub link syndrome |

### Added — Israeli Extensions step in `new-product.md`

After the scaffold and before architecture planning, a new `pick_israeli_extensions` step asks: based on the 5-question brief, which of the 6 new skills trace to a concrete signal? Each pick is documented in `.hermes/build-product/state.md` under `## Israeli extensions`. No "load it just because" — every pick must trace back to a brief signal.

### Changed — `deploy-to-cloudflare.md` and `ship.md` extended

- `deploy-to-cloudflare.md` — added `shabbat_deploy_check` step that invokes `shabbat-aware-scheduler` before any deploy; blocks the build during Shabbat/Yom Tov with a clear "Next safe window" message; supports `--force-deploy-shabbat` override (logged in state.md).
- `ship.md` — added `marketing_assets` step that picks a `popular-web-designs` reference, renders the hero demo / social card via `hyperframes`, smoke-tests the MP4 with `ffprobe`, and writes `marketing/README.md`.

### Compatibility notes

- All 6 new skills already existed in the published skills library — no installation needed.
- `shabbat-aware-scheduler` depends on HebCal API (`https://www.hebcal.com/`) — works online, cached offline.
- `hyperframes` requires `node`, `ffmpeg`, `npx` on PATH.
- `greenapi-whatsapp-bot-builder` needs Green API credentials at `~/.config/greenapi/credentials` (never paste in chat).

### Audit

Skillsmith 100% compliant (62/62 checks pass on source). 0 personal references, 0 secrets in source. Ready for public mirror sync.

---

## [1.3.0] — 2026-06-24

### Added — 4 new skills wired into the pipeline (Phase 0 + Pre-Ship)

After auditing skills in the upstream registry and a peer agent's curated skills, 4 skills were identified as critical to close the intake → ship gap. Each fills a phase that build-product previously handled too loosely or via implicit agent reasoning.

| Skill | Purpose | Pipeline phase |
|-------|---------|----------------|
| `amrita-architect` | Turn vague ideas (≤2 sentences) into execution-ready specs via ≤3 clarification questions | Phase 0 (Intake) |
| `hermes-config-validation` | Validate Hermes config keys + endpoints + API keys against the actual installed source, not docs | Phase 0.5 (Hermes setup) |
| (built-in) | Discover, audit, design bounded feedback loops | Cross-cutting (Loop engineering) |
| `dogfood` | Exploratory QA against the public URL — finds real bugs the smoke tests miss | Phase 5.5 (Pre-Ship QA) |

### Added — 3 new feedback loops (Loop 15, 16, 17)

| Loop | Skill | What it catches |
|------|-------|-----------------|
| **Loop 15: Idea Refinement** | amrita-architect | Builds that start from a too-vague spec and end up wrong |
| **Loop 16: Hermes Config Validation** | hermes-config-validation | Silently-ignored config keys + tools with no public HTTP endpoint |
| **Loop 17: Dogfood Pre-Ship** | dogfood | Real-world bugs (silent JS errors, visual regressions, accessibility) that deterministic smoke tests miss |

### Added — 5 mandatory questions before any build (borrowed from a peer agent's super-builder pattern)

`tasks/new-product.md` Phase 0.2 now has a non-skippable gate: the user must fill a 5-question template (מה / למי / איפה / הצלחה / בהיקף+מחוץ להיקף) before any plan, code, or scaffold is generated. Prevents building the wrong product.

### Added — 2 scaffold scripts (borrowed from a peer agent's super-builder pattern)

`frameworks/scripts/scaffold-node.sh` and `frameworks/scripts/scaffold-python.sh` now live in the skill. They produce a complete, bootable, linted, tested project skeleton in 30 seconds. `tasks/new-product.md` Phase 1A.5 routes to the right one based on stack detection.

### Added — Deployment checklist (4-item, blocking) (borrowed from a peer agent's super-builder pattern)

`tasks/ship.md` Phase 0.0 enforces 4 items before declaring a build "shipped": (1) README.md with 4 sections, (2) `.env.example` with all keys, (3) `GET /health` returns 200, (4) `e2e-testing` + `dogfood` smoke tests pass. If any is missing, the skill **blocks** the ship — does not warn.

### Changed

- `related_skills` extended from 34 → 38 entries (added amrita, hermes-config, dogfood).
- `frameworks/loops.md` grew from 632 → 790 lines (+25%). Loop Coverage Matrix expanded.
- 3 new pitfalls added to `SKILL.md`: "5 mandatory questions", "2 scaffold scripts", "Deployment checklist".
- Version bumped 1.2.1 → 1.3.0 (minor: additive, no breaking changes to existing flows).

## [1.2.1] — 2026-06-24

### Added — 7 new feedback loops for the new skills (loop engineering)

After adding 7 new skills in v1.2.0, each had failure modes that the existing 7 loops didn't cover. Added 7 new loops (one per skill, mostly) to `frameworks/loops.md`. Total loops now: **14** (7 original + 7 new).

| Loop | Skill it covers | What it catches |
|------|----------------|-----------------|
| **Loop 8: PRD Completeness** | `prd-generator` | PRDs that look complete but have hidden gaps |
| **Loop 9: Contract-Code Drift** | `api-contract-designer` | Generated types that don't compile or Zod schemas that don't match |
| **Loop 10: Flaky Test Quarantine** | `e2e-testing` | Flaky tests that mask race conditions (alternative to "retry until pass" or "delete the test") |
| **Loop 11: Cost Guardrail** | `analytics-monitoring` | Runaway OpenAI/Cloudflare/Supabase spend |
| **Loop 12: Legal Disclaimer** | `privacy-tos-generator` | Accidentally removing "not legal advice" disclaimer |
| **Loop 13: Stripe Webhook Health** | `pricing-monetization` | Silent webhook failures (Stripe retries 3 days then gives up) |
| **Loop 14: Onboarding Activation** | `customer-support-templates` | Users who signed up but never activated (highest-ROI intervention point) |

### Added — Loop Coverage Matrix

A table at the bottom of `loops.md` mapping each skill → which loops apply. Makes it easy to see if a new skill has loop coverage.

### Changed

- Version bumped 1.2.0 → 1.2.1 (patch: additive, no breaking changes).
- `frameworks/loops.md` grew from 338 → 632 lines (+87%).

## [1.2.0] — 2026-06-24

### Added — 7 new skills wired into the pipeline

To close gaps in the product lifecycle that were previously manual or skipped, 7 new skills were built and integrated. Each fills a phase that was previously manual or skipped.

| Skill | Purpose | Pipeline phase |
|-------|---------|----------------|
| `prd-generator` | 10-question interview → full PRD | Phase 2 (Spec) |
| `api-contract-designer` | User Stories → OpenAPI 3.1 / GraphQL SDL + Zod + TS types | Phase 3 (Design) |
| `e2e-testing` | Playwright smoke tests + visual regression + CI | Phase 5 (Test) |
| `analytics-monitoring` | Sentry + PostHog + uptime + cost alerts | Phase 7 (Monitor) |
| `privacy-tos-generator` | Privacy Policy + ToS + Cookie banner + DPA (legal templates with disclaimer) | Phase 0.5 (Legal) |
| `pricing-monetization` | Pricing model selection + Stripe + paywall UX | Phase 6 (Monetize) |
| `customer-support-templates` | Welcome + onboarding + churn-prevention emails + FAQ | Phase 8 (Support) |

### Changed

- `related_skills` extended from 27 → 34 entries.
- Version bumped 1.1.0 → 1.2.0 (minor: additive, no breaking changes).

## [1.1.0] — 2026-06-24

### Added — The Three Rules

Operators were repeating the same questions every session. Added **three non-negotiable rules** at the top of `frameworks/user-defaults.md`, in Hebrew-first voice with hard-coded search paths so future-Hermes doesn't have to re-derive them:

- **Rule 1: Search before you ask** — search order: `<agent-host-layout>.md` → `MEMORY.md` → `AGENTS.md` → `SOUL.md` → `USER.md` → `TOOLS.md` → `<agent-config>` → `<secrets-file>` keys. Only ask the user if all return nothing.
- **Rule 2: Know which machine you're on** — server vs laptop — confirm via hostname + pwd. Confirm via `hostname` + `pwd` before any file op on a path not written this session.
- **Rule 3: Confirm understanding before non-trivial work** — restate the request in one sentence ("If I understand correctly: X. Right?") for any task that isn't a single-step lookup or one-line change.

### Added — Cross-references

- `<agent-host-layout>.md` added to `user-defaults.md` `<references>` block so the loader picks it up automatically.

### Changed

- Version bumped 1.0.1 → 1.1.0 (minor: added rules, no breaking changes to existing flows).

## [1.0.1] — 2026-06-24

### Fixed

- Closed unclosed YAML frontmatter in `SKILL.md` (was missing closing `---`).

## [1.0.0] — 2026-06-24

### Added

- Initial orchestrator skill.
- 9 phases (intake → research → spec → design → plan → build → review → ship → publish).
- State machine via `frameworks/route.sh` + `frameworks/state-update.sh`.
- 27 related_skills wired in.
- `scripts/audit-skill.sh` for structural validation.
