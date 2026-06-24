# State Schema — Build Product State File

Defines the structure of `.hermes/build-product/state.md` — the persistent build state that survives between sessions, commands, and context compactions.

<references>
@../SKILL.md (build-product entry point)
@state-template.md (the actual file to copy)
@state-init.sh (script to create the file)
</references>

---

## Why this exists

the user's builds span multiple sessions. Without persistent state:
- "איפה היינו?" requires re-reading recent chat history
- Each new session re-discovers the same context (waste)
- Context compaction loses the build thread
- "What's shipped?" requires manual git archeology

The state file is the **single source of truth** for "where is this build right now". Every task ends by updating it. Every new session starts by reading it.

---

## File location

**Primary:** `<repo-root>/.hermes/build-product/state.md`
**Fallback:** `~/.hermes/build-product/<repo-slug>.md` if the repo refuses `.hermes/` (e.g. public repo)

`repo-slug` = the directory name of the repo, lowercased, kebab-case.

---

## Schema (v1)

```yaml
---
build_product_version: 1
repo: <string>                 # e.g. "desktop-product"
repo_path: <absolute path>     # e.g. "~/projects/<my-product>"
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
last_session_id: <string>      # Hermes session ID if available
---

# Build State: <repo>

## Phase
<new | feature | stuck | ship | paused | shipped>

## What's shipped
- [list of vertical slices that are green + verified]

## Last vertical slice
- Branch: <branch-name>
- Commits: <sha1..sha2>
- Verified: <what was tested — unit + smoke>
- Shipped-at: <YYYY-MM-DD>

## Current focus
<one sentence — what we're trying to do RIGHT NOW>

## Next vertical slice (if known)
<one sentence — what's next, or "not yet defined">

## Blockers
- <blocker 1, if any>
- <blocker 2, if any>

## Stuck-recovery log
- YYYY-MM-DD: <what was stuck> → <root cause> → <fix> → <preventive rule>

## Reusable learnings
- <insight 1> (when it applies)
- <insight 2>

## Stack snapshot
- Frontend: <e.g. Next.js 15, React 19>
- Backend: <e.g. FastAPI 0.115, Python 3.12>
- DB: <e.g. Neon Postgres 16>
- Auth: <e.g. Neon Auth>
- Hosting: <e.g. VPS + Docker>
```

---

## Phase semantics

| Phase | Meaning | Allowed transitions |
|-------|---------|---------------------|
| `new` | Fresh product, slice #1 in progress | `shipped` (if first slice complete) → `feature` (if adding more) → `paused` → `stuck` |
| `feature` | Adding vertical slices | `shipped` (each slice) → `paused` → `stuck` |
| `stuck` | Build-product-stuck invoked, recovery in progress | `new` / `feature` (after recovery) → `shipped` (if recovery led to a clean slice) |
| `ship` | Pre-ship review, smoke, deploy in progress | `shipped` (success) → `feature` (if more coming) → `stuck` (if smoke failed) |
| `paused` | context paused (operator requested stop, or context died mid-build) | `new` / `feature` / `stuck` (on resume) |
| `shipped` | All done for now; product/feature is live | `feature` (if adding more) → `paused` |

**Invariant:** `shipped` → `new` or `shipped` → `feature` requires a NEW slice. Never silently roll back.

---

## Reading the state (on every invocation)

```bash
# Quick check
test -f .hermes/build-product/state.md && cat .hermes/build-product/state.md || echo "no state"

# Just the phase
grep -E "^## Phase" -A1 .hermes/build-product/state.md | tail -1

# Just the focus
sed -n '/^## Current focus/,/^## /p' .hermes/build-product/state.md | head -2 | tail -1
```

If state doesn't exist → fresh build → `new` phase → route to `tasks/new-product.md`.

---

## Writing the state (after every phase change)

Rules:
- Update `last_updated` to today
- Add a one-line entry to "Reusable learnings" if anything new emerged
- Append to "Stuck-recovery log" if recovery happened
- Do NOT touch "What's shipped" unless a slice is genuinely shipped (verified end-to-end)

Use `state-update.sh` (provided) to avoid schema drift.

---

## Anti-patterns

| Don't | Why |
|-------|-----|
| Mark `shipped` without a smoke test result | False confidence |
| Update `What's shipped` with "almost done" entries | Pollutes the record |
| Reuse a single state.md across repos | Cross-contamination |
| Edit `Phase` without updating `Current focus` | Inconsistent state |
| Forget `last_updated` | Loses freshness signal |
| Add secrets to state.md | State is often in git |

---

## When to create a state file

| Trigger | Create with |
|---------|-------------|
| `/build-product new` starts | `state-init.sh new <repo-slug>` |
| `/build-product feature` on existing repo | `state-init.sh feature <repo-slug>` |
| Mid-build recovery | `state-update.sh phase stuck` + add to log |
| Resuming paused build | Read existing, update `last_session_id` |
| First-time discovery in a fresh repo | `state-init.sh` (interactive) |

The script auto-fills the template; you only fill in the open-ended sections.