# State Template — Copy this to `.hermes/build-product/state.md` and fill in

Load this when initializing state for a new build, or when updating state after a slice ships. This is the **canonical shape** of `.hermes/build-product/state.md`.

<references>
@state-schema.md (machine-readable schema — what fields exist + types)
@../tasks/new-product.md (creates the initial state in Phase 0.1)
@../tasks/build-feature.md (updates the state at the end of every slice)
@../tasks/ship.md (updates the state with the last shipped release)
</references>

---

## The template (copy from here)

```markdown
---
build_product_version: 1
repo: <repo-slug>
repo_path: <absolute path>
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
last_session_id: <session-id-if-known>
---

# Build State: <repo name>

## Phase
new

## What's shipped
- (none yet)

## Last vertical slice
- Branch: —
- Commits: —
- Verified: —
- Shipped-at: —

## Current focus
<one sentence — what we're trying to do RIGHT NOW>

## Next vertical slice (if known)
<not yet defined>

## Blockers
- (none)

## Stuck-recovery log
- YYYY-MM-DD: <what was stuck> → <root cause> → <fix> → <preventive rule>

## Reusable learnings
- (none yet — add after first slice ships)

## Stack snapshot
- Frontend: <e.g. Next.js 15>
- Backend: <e.g. FastAPI>
- DB: <e.g. Neon Postgres>
- Auth: <e.g. Neon Auth>
- Hosting: <e.g. managed VPS + Docker>
```

---

## Example — filled state for a real product

```markdown
---
build_product_version: 1
repo: <my-agent>
repo_path: ~/projects/<my-agent>
created: 2026-06-12
last_updated: 2026-06-23
---

# Build State: a voice product Agent

## Phase
shipped

## What's shipped
- v0.1: ElevenLabs TTS integration (Hebrew, Liam voice)
- v0.2: Twilio inbound webhook handler
- v0.3: Conversation memory (Redis)
- v0.4: Live transcript pane (WebSocket)

## Last vertical slice
- Branch: feature/v0.4-transcript-pane
- Commits: a1b2c3d..f4g5h6i (12 commits)
- Verified: smoke test in production, 50ms latency
- Shipped-at: 2026-06-22 14:30 UTC

## Current focus
v0.5: Add admin dashboard for conversation history (queue: design brief first)

## Next vertical slice (if known)
- v0.5: Admin dashboard
- v0.6: Multi-language support (en, ar, ru)
- v0.7: Voice cloning (ElevenLabs voice design)

## Blockers
- (none)

## Stuck-recovery log
- 2026-06-15: ElevenLabs streaming timeout after 30s → root cause: missing `keepalive` ping → fix: add ping every 10s → preventive rule: "always set keepalive on long-lived streams"

## Reusable learnings
- Hebrew TTS needs `eleven_v3` model (not v2) for natural prosody
- Twilio media streams require TwiML Bin webhook URL (not function)

## Stack snapshot
- Frontend: Next.js 15
- Backend: Node.js + Express
- DB: Supabase Postgres
- Auth: Twilio (phone number verification)
- Hosting: Cloudflare Workers + R2
```

---

## How this file relates to other state files

| File | Where | Purpose | When to write |
|------|-------|---------|---------------|
| **state.md** (this template, filled) | `.hermes/build-product/` | Current build state — the only state file the orchestrator reads at runtime | After every phase transition |
| **state-schema.md** | `frameworks/` | Machine-readable schema of state.md (what fields + types) | Reference only, never edit at runtime |
| **CHANGELOG.md** | skill root | Skill version history (1.0.0 → 1.2.1) | On skill version bump |
| **stuck-recovery log** | inside state.md | One-line per stuck-recovery event (root cause + fix + preventive rule) | Inside state.md §"Stuck-recovery log" |
| **state.json** (if exists) | `.hermes/build-product/` | Optional machine-readable mirror of state.md for scripts | Auto-updated by `state-update.sh` |

The orchestrator reads `state.md` (markdown) at the start of every command. Scripts (`route.sh`, `state-update.sh`) operate on the same file.