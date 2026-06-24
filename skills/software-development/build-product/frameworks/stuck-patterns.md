# Stuck Patterns — Common ways builds get stuck and how to escape

Load this when `/build-product stuck` is invoked, to recognize the pattern quickly.

<references>
@../tasks/stuck-recover.md (the parent task)
@../../systematic-debugging/SKILL.md (for technical bugs)
</references>

---

## The 7 stuck patterns

### 1. **The Loop** — same task attempted 3+ times, no progress
**Symptoms:** "I keep getting the same error" / "tried that already" / "still failing"

**Root cause:** Usually missing root cause investigation (skipped Phase 1 of `systematic-debugging`)

**Escape:**
- STOP all attempts
- Read the actual error message (don't paraphrase)
- Trace one level deeper than you think is needed
- Find the SMALLEST input that reproduces
- Load `systematic-debugging` → Phase 1 first

---

### 2. **The Blob** — plan grew to 50+ tasks, can't start
**Symptoms:** "I don't know where to start" / "this is huge" / "where do I begin"

**Root cause:** Scope not sliced vertically. Horizontal planning.

**Escape:**
- Apply the **half-slice rule** — cut scope in half
- Then the **quarter-slice rule** — cut again
- Find the smallest user-visible value (often 1-line change)
- Throw away the rest of the plan; rebuild from the half-slice only

---

### 3. **The Rabbit Hole** — deep into one technical detail, lost the thread
**Symptoms:** "I've been in this file for 2 hours" / "wait, what was I building?"

**Root cause:** No checkpoint. Lost the connection between code and product.

**Escape:**
- STOP editing
- Re-read `.hermes/build-product/state.md` (if exists)
- Ask: "what was the user-visible capability I was trying to add?"
- If you can't answer in one sentence → escalate to `stuck-recover.md` Phase 1

---

### 4. **The Magic** — "I think I fixed it" without verification
**Symptoms:** Tests still failing but commit was made / code "looks right"

**Root cause:** Skipped RED-GREEN-REFACTOR. Wrote code without watching test fail.

**Escape:**
- Revert the unverified commit
- Write the failing test FIRST (RED)
- Watch it fail (critical — proves test is real)
- Write minimal code to pass (GREEN)
- Refactor while green

---

### 5. **The Sprawl** — "let me also refactor X while I'm in here"
**Symptoms:** Commit touches 15 files / "while I was at it..."

**Root cause:** Scope creep during execution. Lost focus on vertical slice.

**Escape:**
- Revert all out-of-scope edits
- Create a separate feature branch for the refactor
- Get back to the original vertical slice
- File the refactor as a follow-up, do not do it now

---

### 6. **The Approval Trap** — "I'll just push and see what happens"
**Symptoms:** PR was pushed without review / "I can always revert"

**Root cause:** Skipped the user-sovereignty gate. Production-impacting move without the user's approval.

**Escape:**
- Revert the push if possible
- If not reversible: write a `revert-plan.md` documenting recovery steps
- Future: ALL production-impacting moves require explicit "go" from the user first
- Add the rule to project memory: "no auto-deploy on shared infra"

---

### 7. **The Fake Green** — tests pass but product doesn't work
**Symptoms:** "All tests pass!" but smoke test fails / user reports bug immediately

**Root cause:** Tests coupled to implementation, not behavior. Skipped real-user smoke.

**Escape:**
- Throw away the "passing" tests
- Write a smoke test FIRST (a real user interaction, not a unit)
- Run the smoke test (must fail in RED)
- Now write unit tests that exercise the smoke flow
- Verify: smoke green + unit green

---

## Quick classifier

If you see 2+ of these, the pattern is clear — apply the matching escape:

| Pattern | Visible signals |
|---------|-----------------|
| Loop | Same error 3+ times, "tried that" |
| Blob | 50+ task plan, "where to start" |
| Rabbit Hole | 2+ hours in one file, lost context |
| Magic | Commit + tests still failing |
| Sprawl | 15+ file commit, "while I was at it" |
| Approval Trap | Pushed without review |
| Fake Green | Tests pass but smoke fails |

---

## Universal escape: when nothing else works

If you're stuck and the pattern doesn't match any of the above, do this:

1. **Save everything.** `git stash` or commit WIP with `[wip]` prefix.
2. **Tell the user.** One sentence: "I'm stuck on X. The closest I've gotten is Y. The blocker is Z. Help?"
3. **Walk away for 15 minutes.** Not optional. Step away from the screen.
4. **Come back and re-read the original goal.** "What was I building and for whom?"
5. **Start over with the smallest possible piece.** Often the cleanest path is a fresh commit with just the minimum.

This is **not failure**. This is the fastest path to shipping.

---

## Worked example — recognizing and escaping "The Loop"

A real example of `The Loop` pattern, from a build that was stuck for 90 minutes:

**Symptoms observed:**
- 4 consecutive `npm run dev` attempts with the same `MODULE_NOT_FOUND` error
- Each attempt: same fix attempt (clear `.next/`, reinstall)
- User frustration: "I've tried that three times already"
- Time-on-task: 90 minutes

**What the agent did (wrong):**
```bash
# Attempt 1: clear .next
rm -rf .next && npm run dev
# → MODULE_NOT_FOUND: 'stripe' (different error this time, but still failing)

# Attempt 2: reinstall
rm -rf node_modules && npm install && npm run dev
# → MODULE_NOT_FOUND: 'stripe' (same error)

# Attempt 3: install stripe explicitly
npm install stripe && npm run dev
# → MODULE_NOT_FOUND: '@supabase/ssr' (different module)

# Attempt 4: install all missing modules
npm install stripe @supabase/ssr && npm run dev
# → MODULE_NOT_FOUND: 'next-auth' (yet another)
```

**What the agent should have done (right) — escape from The Loop:**

```bash
# Step 1: STOP. Re-read the actual error in detail.
# Look at the FULL stack trace, not just the first line.

# Step 2: Discover ALL missing modules at once
cat package.json | jq -r '.dependencies, .devDependencies | keys[]' > /tmp/expected.txt
ls node_modules/ | sort > /tmp/actual.txt
diff /tmp/expected.txt /tmp/actual.txt
# → Reveals 12 missing modules, not 1

# Step 3: Install all at once
npm install  # not a partial install — the package-lock.json is the source of truth

# Step 4: Verify with a smoke test (per Loop 3)
curl http://localhost:3000/health
# → 200 ✅
```

**Why this works:**
- Stop guessing which module is missing; ask the package manager.
- One full `npm install` from a clean `package-lock.json` resolves all transitive deps correctly.
- The "Missing X" errors were a cascade — fixing the first one revealed the next.

**Preventive rule for next time:**
- "If the same `MODULE_NOT_FOUND` error class appears 2+ times, run a clean install from `package-lock.json`, not partial installs."

This rule is reusable across any Node project with dependency issues — append to project memory as a candidate skill.