# Past-Build Examples — Real slices from prior build sessions

These are real vertical slices that the user (and Hermes) have shipped. Each shows the full anatomy: idea → plan → execute → review → ship. Use these as templates for new builds.

<references>
@../SKILL.md (build-product entry point)
@../../plan/SKILL.md
@../../writing-plans/SKILL.md
@../../subagent-driven-development/SKILL.md
</references>

---

## Example 1: a voice product — Clean rebuild plan

**Source:** `~/.config/hermes/plans/<my-agent>-clean.md` (<date>)
**Repo:** `~/projects/workspace/<my-agent>`
**Stack:** Hebrew voice agent (ElevenLabs a voice + Deepgram STT) + React+Vite+Tailwind frontend
**Slice count:** 5 phases in original plan, executed as 3 vertical slices

### Phase 0 — Discover (spike)
**Trigger:** "I want to verify the the voice agent still works before touching anything"
**Skill used:** `spike` + `cavecrew-investigator` (auto, prompt #1)
**Output:** Real inventory table of what's in the repo

| What | Where | Status |
|------|-------|--------|
| Backend config (TTS, STT, personality) | `<agent-product-repo>/config/hermes-config.yaml` | ✅ Clean |
| Smoke tests | `<agent-product-repo>/scripts/` | ✅ 8/9 pass |
| Web UI existing (React+Vite+Tailwind) | `<my-product>-hermes-agent/frontend/` | ⚠️ Untouched |
| Backend Node/Express existing | `<my-product>-hermes-agent/backend/` | ⚠️ 86 files, untouched |

### Phase 1 — Plan (kickoff with 5 principles)
**Trigger:** "Plan a voice product rebuild"
**Skill used:** `plan` (plan-mode, no execution)
**Output:** `<my-agent>-clean.md` with the 5 principles:

> **Principles baked in:**
> 1. **No custom code** — config + smoke tests only. Agent defined in `config.yaml`, not Python.
> 2. **Liam = Hebrew male voice** (`<voice-id>`), `eleven_v3` model.
> 3. **Web UI must talk to Hermes `text_to_speech` tool** — not ElevenLabs direct.
> 4. **No ElevenLabs live/conversational agent** — `text_to_speech` is the right path.
> 5. **Approval before push** — no push without explicit "yes" from the user.

### Phase 2 — Execute first vertical slice ("Verify backend still works")
**Plan:** Run smoke tests, fix the 1 failing test, document
**Skill used:** `subagent-driven-development` with `cavecrew-investigator` for code mapping
**Outcome:** Smoke 9/9 green, ready for slice #2

### Phase 3 — Execute second vertical slice ("Pick UI path: rebuild vs reuse")
**Plan:** Check existing `<my-product>-hermes-agent` — does it run? What's missing?
**Skill used:** `subagent-driven-development` with bounded scope
**Outcome:** Existing UI works, reuse it instead of rebuilding

### Phase 4 — Ship
**Skill used:** `ship.md` task — pre-flight checks + smoke + the user approves

### What this slice teaches us
- **Spike-first** when repo state is unknown
- **5 principles** before plan (the user's preference)
- **"Try reuse before rebuild"** — saves hours
- **Existing tools** > new code

---

## Example 2: a specific product — Performance audit + targeted fix

**Source:** `~/.config/hermes/plans/performance-audit-plan-v1.md` (2026-06-16)
**Repo:** `~/projects/workspace/<my-app>`
**Stack:** Next.js 15, React 19, TypeScript
**Slice count:** Single audit slice + targeted fix

### Phase 0 — Discover with empirical data
**Trigger:** "Why are tabs slow?"
**Skill used:** `cavecrew-investigator` for code archeology
**Output:** Empirical timing table

| Path | Avg time | HTML size | Status |
|------|----------|-----------|--------|
| `/` | **6.455s** | 109,850 B | 🔴 Outlier |
| `/chat` | **4.395s** | 83,743 B | 🔴 Outlier |
| `/kanban` | 2.893s | 66,493 B | 🟡 Slow |
| `/room` | 1.144s | 70,590 B | 🟢 OK |
| `/missions` | 1.012s | 71,187 B | 🟢 OK |
| `/projects` | 0.897s | 65,806 B | 🟢 OK |
| `/pipeline` | 0.746s | 68,562 B | 🟢 OK |

**Insight:** Problem is focused on 2 pages (`/`, `/chat`), not "everything is slow".

### Phase 1 — Plan with explicit history
**Trigger:** "Plan the perf fix"
**Skill used:** `writing-plans`
**Key feature:** Plan explicitly lists "what was fixed in the past" so the user doesn't re-fix what's already fixed:

```
1. setInterval without visibilitychange check (FIXED with usePollWhileVisible)
2. Promise.all without catch (FIXED with allSettled)
3. Empty catch blocks (FIXED with console.warn + typed errors)
4. Regex stripped ASCII chars (FIXED in safePrompt.ts)
```

**Critical instruction:** "Before investigating — check if these fixes still exist, or someone reverted them"

### Phase 2 — Execute (targeted)
**Plan:** Investigate ONLY `/` and `/chat` paths. Don't refactor everything.
**Skill used:** `subagent-driven-development` with narrow scope

### Phase 3 — Verify by negation
**Skill used:** `incremental-hardening-refactor` pattern
**Check both present AND absent:**
- New fix present? `grep "newFix"`
- Old bug absent? `grep "oldPattern"` (should return 0)

### What this slice teaches us
- **Empirical data first** — measure before assuming
- **Localized problem** — don't boil the ocean
- **History check** — what was already fixed
- **Verify by negation** — present + absent, not just present

---

## Example 3: a specific product — Pipeline shape+build fix

**Source:** `~/.config/hermes/plans/pipeline-shape-fix-plan-v2.md` (2026-06-16)
**Repo:** `~/projects/workspace/<my-app>`
**Stack:** Next.js + filesystem-backed "Vault" markdown items
**Slice count:** Single feature slice (create 2 new routes)

### Phase 0 — Discover with verified facts
**Skill used:** `cavecrew-investigator`
**Output:** "Verified facts (don't change!)" table — exact paths, exact APIs, exact formats

| Parameter | Real value | How verified |
|-----------|-----------|--------------|
| antigravity CLI | `<your-cli-path>/agy` | `where agy` |
| fcc API | `http://127.0.0.1:8082` | `/health` with valid API key returns 200 |
| fcc auth | `x-api-key` header (not Authorization Bearer) | `fcc.ts:30+` |
| Vault root | `<vault-root>/AgentMemory/` | file search |
| Pipeline items path | `<vault-root>/Pipeline/items/<slug>.md` | found 8 files |

### Phase 1 — Plan with bite-sized tasks
Each task = 2-5 minutes:
- Task 1: Create `src/lib/pipeline/itemStore.ts` (shared code)
- Task 2: Create `src/app/api/pipeline/shape/route.ts`
- Task 3: Create `src/app/api/pipeline/build/route.ts`
- Task 4: Update Vault format docs
- Task 5: Verify in laptop browser

### Phase 2 — Execute via subagents
**Skill used:** `subagent-driven-development`
**Each task:** own subagent, 2-stage review, commit after green

### Phase 3 — Ship via local smoke
Open browser → see new items in Drawer → verify they show

### What this slice teaches us
- **Verify facts** — never assume paths, versions, auth schemes
- **Shared code first** — extract before duplicate
- **One commit per task** — bisect-friendly
- **Local smoke** — actually use it, not just unit tests

---

## Example 4: a desktop product — Hosting architecture docs consistency

**Source:** Session `<session-id>` (anonymized date)
**Repo:** `~/projects/workspace/<my-product>`
**Slice:** "Clarify that Vercel is optional, desktop is local-first, DB access goes through managed backend"

### The pattern: docs-only slice

When the slice is **docs/clarification** (not code):

1. **Cavecrew-investigator** finds all contradictory docs (`docs/*.md` + `README.md`)
2. **Update each file** with consistent language
3. **Update test** (`tests/test_hosting_architecture_docs.py`) to assert the new invariant
4. **Run focused test** — verify pass
5. **Run docs sanity check** — no stale contradictory wording
6. **Report** what changed, file list, line numbers, verification commands

### Files modified
- `README.md`
- `docs/mvp.md`
- `docs/app.md`
- `docs/desktop.md`
- `docs/hosting-architecture-decision.md`
- `docs/vercel-temporary-deploy-plan.md`
- `tests/test_hosting_architecture_docs.py`

### Verification
```bash
python -m pytest tests/test_hosting_architecture_docs.py
# 2 passed in 0.04s
```

### What this slice teaches us
- **Docs are code** — assert invariants with tests
- **Slice can be docs-only** — no need to touch runtime
- **Sanity check** — grep for stale wording fragments
- **File list + line numbers** — the user can verify quickly

---

## Cross-cutting patterns (all examples)

### 1. Always start with empirical data
- Read git log
- Read existing tests
- Read AGENTS.md
- **Cavecrew-investigator** before any plan

### 2. Plans include "history" and "facts"
- "What was fixed before" (avoid duplicate work)
- "Verified facts (don't change)" (avoid wrong assumptions)
- These sections are **non-negotiable**

### 3. Bite-sized tasks with exact paths
- 2-5 minutes per task
- Exact file paths
- Exact verification commands
- Commit per task

### 4. Smoke test before ship
- Not "tests pass" — actual real interaction
- Browser for web apps
- Real user flow for voice/desktop
- Verified evidence (screenshot, transcript, log)

### 5. the user approves irreversible moves
- Push requires explicit "yes"
- Deploy requires explicit "go"
- Production DB write requires explicit "ship it"
- Reversible auto-proceeds with note

---

## How to use these examples

When starting a new build:

1. **Skim the example closest to your domain** (web app → Example 2/3, voice → Example 1, docs → Example 4)
2. **Copy the phase structure** but adapt to your stack
3. **Run `state-init.sh` first** to create the state file
4. **Run the route.sh** to confirm auto-detection picks the right starting task
5. **Follow the discipline** — empirical data first, plan second, execute third, smoke before ship

When stuck:

1. **Re-read the example that matches your stuck mode** (Loop → Example 3's bite-sized tasks; Blob → Example 4's scope discipline; Magic → Example 2's verify-by-negation)
2. **Apply the matching escape** from `stuck-patterns.md`
3. **Update `state-update.sh log`** with the recovery

---

## Meta-pattern: when to write a new example

Add a new example here whenever:
- A vertical slice ships successfully that took > 1 hour
- The slice taught a non-obvious lesson (e.g. "verify by negation")
- The slice demonstrates a pattern not covered by existing examples

Format:
```markdown
## Example N: [Product] — [Slice name]

**Source:** [plan path or session ID]
**Repo:** [path]
**Stack:** [key tech]
**Slice count:** [number]

### Phase 0 — Discover
**Trigger:** "[the operator's request in plain language]"
**Skill used:** [which skills]
**Output:** [what was found]

### Phase 1 — Plan
...

### What this slice teaches us
- [lesson 1]
- [lesson 2]
```