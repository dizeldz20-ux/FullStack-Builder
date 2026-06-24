# Routing Map — Which skill when

Master decision tree for the `build-product` orchestrator. Load this whenever you need to choose which skill to invoke next.

<references>
Master decision tree — see `@routing-map.md` for the canonical version
@../SKILL.md (the build-product entry point)
@../frameworks/loops.md (7 quality feedback loops — Loop 1 plan-quality, Loop 2 builder-reviewer, Loop 3 smoke-retry, Loop 4 pre-ship quality, Loop 5 self-loop detection, Loop 6 deploy-retry, Loop 7 reflection)
# Loop engineering is handled by build-product's 7 internal loops (see loops.md). No external loop library needed for the standard build pipeline.
@../../plan/SKILL.md
@../../writing-plans/SKILL.md
@../../subagent-driven-development/SKILL.md
@../../test-driven-development/SKILL.md
@../../systematic-debugging/SKILL.md
@../../incremental-hardening-refactor/SKILL.md
@../../requesting-code-review/SKILL.md
@../../spike/SKILL.md
@../../cavecrew-investigator/SKILL.md
@../../cavecrew-builder/SKILL.md
@../../cavecrew-reviewer/SKILL.md
</references>

---

## By question

### "I want to build something new from scratch"
→ `/build-product new` → `tasks/new-product.md`
→ which routes through: `spike` (maybe) → `plan` → `writing-plans` → `subagent-driven-development` → `requesting-code-review`

### "I want to add a feature to an existing repo"
→ `/build-product feature` → `tasks/build-feature.md`
→ which routes through: `cavecrew-investigator` (always) → `writing-plans` → `subagent-driven-development` → `requesting-code-review`

### "I'm stuck mid-build"
→ `/build-product stuck` → `tasks/stuck-recover.md`
→ which routes through: `systematic-debugging` (if technical) OR `spike` (if scope unclear) OR half-slice rule (if plan too big)

### "I want to ship to production"
→ `/build-product ship` → `tasks/ship.md`
→ which routes through: `requesting-code-review` (always) + smoke test (always) + the user approval (always)

---

## By sub-skill

### When to use `plan` (plan-mode, no execution)
- "תכנן לי את X" / "plan X for me"
- "I want to think about X without coding yet"
- Kickoff of a new product/feature where the user wants a doc first
- Read-only mode — saves `.hermes/plans/`

### When to use `writing-plans`
- After `plan` mode produces a brief
- When you have clear scope but need bite-sized tasks
- Output is markdown plan consumed by `subagent-driven-development`
- **Every task must have exact file paths and a commit step**

### When to use `subagent-driven-development`
- Plan is ready, need to execute it
- Tasks are mostly independent (no shared files being edited in parallel)
- Fresh subagent per task prevents state confusion
- 2-stage review catches spec + quality issues

### When to use `test-driven-development`
- **Every** behavior change in `subagent-driven-development`
- RED first (write the failing test)
- GREEN next (minimal code to pass)
- REFACTOR last (clean up while green)
- If you didn't watch the test fail, you don't know if it tests the right thing

### When to use `systematic-debugging`
- Any technical bug, test failure, broken behavior
- 4 phases: investigate → pattern → hypothesis → fix
- **NEVER skip Phase 1** (root cause investigation)

### When to use `incremental-hardening-refactor`
- Touching auth/secrets/session code
- Refactoring a working repo with regression risk
- Multi-step migration with bisect-friendly commits
- Use the "Classify findings" pattern before touching code
- Use "Verify by negation" after every patch

### When to use `requesting-code-review`
- Before commit (any non-trivial diff)
- Before merge to main
- Before ship
- "מה אתה חושב על הקוד הזה?"

### When to use `spike`
- Idea is fuzzy, need to feel it out
- Comparing two tech approaches (A vs B in code, not just docs)
- Throwaway prototype — explicitly disposable

### When to use `cavecrew-investigator`
- Read-only archeology of a code area
- "מה המצב בפועל ב-[area]?"
- Always before editing legacy code
- Fast, isolated, returns a table
- **build-product auto-dispatches** this in build-feature Phase 0 and stuck-recover Phase 1B with pre-built prompts (see `cavecrew-prompts.md`)

### When to use `cavecrew-builder`
- 1-2 file surgical edit (typo fix, single-function change)
- Tight scope, isolated work
- Faster than `subagent-driven-development` for trivial patches
- **build-product auto-dispatches** this via prompt #5 in `cavecrew-prompts.md`

### When to use `cavecrew-reviewer`
- Review a diff / branch / file
- One-line findings
- Lighter weight than `requesting-code-review` (which is pre-ship)
- **build-product auto-dispatches** this via prompt #6 in `cavecrew-prompts.md`

### Loop engineering (built-in)
- build-product ships with 7 internal loops that cover the standard build pipeline (see `loops.md`).
- For novel scenarios where the 7 internal loops don't fit, see `loops.md` → "Designing a new loop" section for the design template.
- For auditing build-product itself, use the `reviewing-skills` skill.
- The skill is the meta-loop library — build-product/loops.md already references 7 of its 45 published loops.
- `creative/sketch` — throwaway mockup comparison
- `creative/ruby-design-triad` — a peer agent's design operating mode
- `creative/impeccable` — design taste / anti-slop UI
- `creative/emil-design-eng` — UI polish philosophy
- `imagegen-frontend-web` — premium web image direction

### When to use product/competitor research
- `creative/competitive-product-research-to-build` — before committing to build
- `last30days` — what people are saying about a topic right now

### When to use a desktop product / a voice product / specific product skills
- `desktop-product-*` — for a desktop product (desktop dictation) work
- `<my-product>-*` — for a specific live voice product
- `<product-prefix>-*` — for a specific product (e.g. a specific product (Next.js based))
- Each is scoped to one product; don't cross-use

---

## Anti-routing: when NOT to load a skill

| Don't load | Why |
|------------|-----|
| `plan` mid-build | Plan is for kickoff, not for re-orienting during execution |
| `spike` after scope is clear | Spike is for fuzzy ideas, not for "make sure once more" |
| `subagent-driven-development` for a 1-file typo | Use `cavecrew-builder` instead |
| `systematic-debugging` for "I don't know what to do" | That's `stuck-recover.md`, not debug |
| `incremental-hardening-refactor` for a greenfield build | Hardening is for live codebases |
| `requesting-code-review` for a 3-line patch | Waste of review overhead |
| `creative/impeccable` if the user didn't ask for design | Don't redesign unprompted |

---

## Decision tree (text)

```
the user says: "I want to build X"
  → Is the idea clear?
      → No: load `spike`
      → Yes: continue
  → Is there existing code for this product?
      → No: `/build-product new` → plan → writing-plans → subagent-driven-development
      → Yes: `/build-product feature` → cavecrew-investigator → writing-plans → subagent-driven-development
  → During execution, a task fails twice
      → STOP → `/build-product stuck` → classify mode → systematic-debugging OR scope-cut
  → All tasks complete, tests green
      → `/build-product ship` → requesting-code-review → smoke → the user approves → deploy
```