# Task: /build-product feature — Add one feature to an existing repo

<purpose>
Add a single vertical-slice feature into an existing repo. Routes to existing Hermes skills; preserves the working state of the existing code.
</purpose>

<user-story>
As the user with an existing repo, I want a single feature added end-to-end, so that I can ship one more capability without disrupting the rest of the system.
</user-story>

<when-to-use>
- "תוסיף [feature] ל[project] הזה"
- "I want feature X in this repo"
- "extend this product with Y"
- After `/build-product new` has shipped slice #1
</when-to-use>

<prerequisites>
- Existing repo with working tests + recent green commit
- The user can describe the feature in 1-2 sentences
- Stack already chosen (read `package.json` / `requirements.txt` / etc.)
</prerequisites>

<references>
@../frameworks/routing-map.md
@../frameworks/loops.md (load when a phase might spin)
@../frameworks/user-defaults.md
@../frameworks/cavecrew-prompts.md (load on demand — pre-built prompts for cavecrew invocations)
@cavecrew-investigator (auto-invoked in Phase 0)
@incremental-hardening-refactor (load if the change touches shared/auth/secrets code)
</references>

<steps>

<step name="orient_with_cavecrew_investigator" priority="first">
Before invoking any other skill, **automatically dispatch a `cavecrew-investigator` subagent** with this prompt:

```text
You are investigating the code area I'm about to touch for a new feature.

Repo: <repo-path>
Stack: <detected-from-package.json-or-requirements.txt>
Recent commits: <git log --oneline -10>
AGENTS.md (if exists): <path-or-none>

INVESTIGATE:
1. Map the code area this feature will touch (top 10 file:line entries)
2. List 3-5 risky branches or legacy paths that look dangerous to modify
3. Identify existing tests in this area (file paths only)
4. Note any project-specific conventions in AGENTS.md or README

OUTPUT FORMAT (caveman-compressed, file:line only):
Defs: <path:line> — <symbol> — <note>
Refs: <path:line> — <symbol> — <note>
Tests: <path:line> — <symbol> — <note>
Risky: <path:line> — <symbol> — <note>

DO NOT propose fixes. DO NOT edit. Investigate only.
```

If the area is non-trivial (>20 candidate files), **auto-spawn a second cavecrew-investigator in parallel** with a focused sub-query (e.g. "trace data flow from API endpoint to DB").

After the investigator returns, read project-specific rules in this order (if they exist):
1. `AGENTS.md` (project-specific rules)
2. `README.md` (architecture overview)
3. Last 5 commits (`git log --oneline -5`)
4. Any `.cursor/rules` or `.claude/rules` files

Then find tests in the area the investigator flagged and read them to learn:
- Testing framework (Jest / Vitest / pytest)
- Test style (unit / integration / e2e)
- Setup/teardown patterns

**Do NOT skip archeology.** This is the #1 cause of "stuck mid-build" — touching code without understanding its current path.

Wait for the cavecrew-investigator to return before continuing.
</step>

<step name="lock_scope">
Ask the user to confirm the scope with these 4 questions:

| Question | Why it matters |
|----------|---------------|
| What's the **smallest** end-to-end version of this feature? | To enforce vertical-slice discipline |
| What's explicitly **out of scope** for this slice? | Prevents scope creep mid-implementation |
| Are there **risky areas** this touches (auth, secrets, DB schema, API contracts)? | Determines if `incremental-hardening-refactor` skill applies. **For auth specifically:** load `supabase-auth-patterns` and run the relevant task before adding the feature. |
| **Reversibility** — is this a 1-commit revertable change, or multi-commit migration? | Sets the granularity of checkpoints |

**Wait for user answers.** Do not proceed without them.

Then write the answers into a 5-line scope note. Save to `.hermes/build-product/feature-<slug>-scope.md`.
</step>

<step name="plan_with_writing_plans">
Load `writing-plans` skill. Produce a bite-sized plan with these specifics:

- Every task = 2-5 min focused work
- Every task has a `Files:` section with exact paths
- Every behavior-changing task starts with **RED test first**
- Every task ends with `Step 5: Commit` (with suggested commit message)
- Risky tasks (auth, secrets, schema) include a **revert plan** in the task body

If the feature touches secrets/auth/DB schema, ALSO load `incremental-hardening-refactor` and follow its "Classify findings before fixing" + "Verify by negation" patterns — adapted to feature-add (not refactor) context.

**If the feature adds new user-specific data (a new table, a new column with user_id, a new protected route):**

| Trigger | Load this skill | Run this command |
|---|---|---|
| Adding a new Supabase table | `supabase-auth-patterns` | `/supabase-auth rls` — **before** writing the first SELECT |
| Adding a new auth provider (Google/Apple) | `supabase-auth-patterns` | `/supabase-auth google` or `/supabase-auth apple` |
| Adding email signup to a product that had no auth | `supabase-auth-patterns` | `/supabase-auth email` first, then `/supabase-auth rls` |
| Touching `proxy.ts` / `middleware.ts` / session logic | `supabase-auth-patterns` | Read `frameworks/ssr-client-patterns.md` + `frameworks/session-management.md` |
| Reviewing an auth-touching diff | `supabase-auth-patterns` | Read `frameworks/pitfall-catalog.md` (10 common mistakes) |

**Hard rule:** Any new Supabase table without RLS = P0 security incident. `/supabase-auth rls` is non-negotiable before that table's first SELECT in production.

**Wait for user approval** of the plan before continuing to execute.
</step>

<step name="execute_subagent_loop">
Load `subagent-driven-development`. See `@../frameworks/loops.md` Loop 2 (Builder-Reviewer) for the per-task reviewer subagent pattern.

Standard loop:
- One subagent per task
- Fresh context per task (no accumulated state confusion)
- 2-stage review: spec compliance → code quality
- Commit after each GREEN task

**Hard rules:**
- Never edit files outside the scope note from `lock_scope`
- If a task seems to require touching out-of-scope code → STOP, ask the user, do not proceed silently
- If a test fails twice on the same task → STOP, route to `stuck-recover`
- After every 3-5 tasks, run the full test suite + a smoke test of the existing untouched flows (regression check)
</step>

<step name="review_and_verify">
Load `requesting-code-review` + (if applicable) the product-specific verification skill from `related_skills`. See `@../frameworks/loops.md` Loop 4 (Pre-Ship Quality) for CRITICAL-finding handling.

For each:
- Run code review via `requesting-code-review` → apply CRITICAL fixes
- Smoke test the new feature end-to-end (real interaction, not just unit tests)
- Smoke test ONE existing flow to confirm no regression
</step>

<step name="update_state_and_close">
Save the new state to `.hermes/build-product/state.md`:

```markdown
# Build Product State — [repo name]
Updated: YYYY-MM-DD

## What's shipped
- [slice 1, slice 2, ...]

## Last vertical slice
- Branch: [name]
- Commits: [sha1..sha2]
- Verified: [what was tested]

## Next vertical slice (if known)
- [next feature to add]

## Last deployment (if any)
- URL: https://[project].[subdomain].workers.dev
- Deployed: [timestamp]
- Deployment ID: [uuid]
- Access App ID: [uuid]
- Rollback: [command]

## Known risks / open issues
- [anything the user should know about]
```

Commit the state file. Report to the user: what shipped, what's next, any blockers.
</step>

<step name="auto_deploy_cloudflare">
**If the feature needs to go live** (not local-only, not a refactor) **and the user hasn't said "skip deploy"** → auto-route to `@tasks/deploy-to-cloudflare.md` (the source of truth for the deploy flow).

**Typical time:** 2-5 minutes (the project is already set up; this is just `wrangler deploy` + verify Access).

**Skip if:**
- The feature is local-only (UI change, refactor, no new env vars)
- The user says "skip deploy" or "local only"
- The repo is a library or CLI tool

**For full details on the deploy flow, see `@tasks/deploy-to-cloudflare.md`.**
</step>

</steps>

<output>
A working feature added to the existing repo:
- New code follows the repo's existing style + patterns
- New tests added (or existing tests updated)
- Smoke test still passes against the new code
- `git commit` made with a clear message
- `.hermes/build-product/state.md` updated with the new slice
</output>

<acceptance-criteria>
- [ ] Feature described in 1-2 sentences by the user
- [ ] At most 3 follow-up questions asked (5 if Loop 15 routed through amrita-architect)
- [ ] Stack detected from existing repo
- [ ] Scaffold check skipped (repo already has one)
- [ ] Hermes config validated if project uses built-in providers (Loop 16)
- [ ] TDD vertical slice — smallest user-visible change
- [ ] `npm test` / `pytest` green
- [ ] `curl /health` returns 200 (if API server)
- [ ] Dogfooded against the deployed URL (Loop 17)
- [ ] `git commit` made
- [ ] `.hermes/build-product/state.md` updated
</acceptance-criteria>
