# Task: /build-product stuck — Recover from being stuck mid-build

<purpose>
Detect and recover when the build is stuck in a loop, blocked on something unclear, or the user says "I'm stuck / תקוע / WTF / this doesn't work / why isn't this working". Forces a route to the right diagnostic skill — does not attempt random fixes.
</purpose>

<user-story>
As a user with a stuck build, I want a fast route to the right diagnostic skill, so that I can unblock the build in 5-10 minutes instead of going in circles for an hour.
</user-story>

<when-to-use>
- User says "אני תקוע" / "WTF" / "this doesn't work" / "why is this broken"
- Same blocker has been attempted 3+ times with no progress
- Build has been spinning on the same task for 15+ minutes
- "I'm going in circles"
- After `/build-product new` or `/build-product feature` has stalled mid-execution
</when-to-use>

<prerequisites>
- Some prior context exists (commits, attempted fixes, or task list)
- The user can describe the symptom in 1-2 sentences
</prerequisites>

<references>
@../frameworks/routing-map.md
@../frameworks/loops.md (Loop 5 self-loop detection applies here)
@../frameworks/stuck-patterns.md (load on demand — common stuck modes)
@cavecrew-investigator (load on demand — read-only archeology)
@systematic-debugging (load on demand — for technical bugs)
</references>

<steps>

<step name="stop_and_classify" priority="first">
**Do NOT try any fix yet.** The Iron Law of debugging applies here too: random fixes waste time and create new bugs.

**See `@../frameworks/loops.md` Loop 5 (Self-Loop Detection)** — if the same blocker has been attempted 5+ times, this is the explicit signal that the orchestrator is in a loop, not just the user's stuck feeling.

Classify the stuck mode by asking the user ONE question:

> "מה יותר מתאר את מה שקורה?"
> 1. **תקלה טכנית** — "יש שגיאה / test נופל / build נשבר / API לא עונה"
> 2. **לא יודע מה לעשות** — "אני לא יודע מה הצעד הבא / התוכנית לא ברורה"
> 3. **לא יודע מה לבנות** — "אני לא יודע מה המוצר באמת צריך / הscope לא ברור"
> 4. **נתקע בתוכנית** — "התוכנית גדולה מדי / אין לי זמן / הצעד הבא מפחיד"

**Wait for user answer.** Then route based on it:
- (1) → load `systematic-debugging` skill → 4-phase root cause
- (2) → continue to `unclear_next_step` step below
- (3) → load `spike` skill (small throwaway to re-validate the idea)
- (4) → continue to `stuck_on_plan` step below
</step>

<step name="unclear_next_step">
If the user knows what to build but not what to do next:

**Sub-step A: Re-read the state**
Read `.hermes/build-product/state.md` (if exists). What's the last shipped slice? What's the last attempted task?

**Sub-step B: Spawn a code archaeologist (AUTO)**
**Automatically dispatch a `cavecrew-investigator` subagent** with this prompt:

```text
You are investigating why a build is stuck.

Repo: <repo-path>
Last shipped slice: <from state.md>
Last attempted task: <from state.md or recent git log>
Stuck duration: <how long>

INVESTIGATE:
1. What is the ACTUAL state of the code right now? (file:line table)
2. What was last attempted? (git log -10 + recent uncommitted changes)
3. Are there any error messages, test failures, or broken imports?
4. What does the "current path" look like vs what the user thinks is happening?

OUTPUT FORMAT (caveman-compressed):
Reality: <one paragraph — what's actually true>
Recent: <last 3 commits>
Failed: <last test failures or errors if any>
Path: <step-by-step of what code currently does in the stuck area>

DO NOT propose fixes. Investigate only.
```

**Sub-step C: Re-anchor with the user**
Present the reality check. Ask:
- "האם זה מה שאתה חושב שקורה?"
- "מה הצעד הכי קטן שאתה כן יודע איך לעשות?"
- "האם לחתוך scope של ה-slice הזה לחצי?"

**Wait for user answer.**

Then, based on the user's answer, pick ONE small concrete next action. Do not pick a 5-step plan — pick ONE thing. Execute it. If it works, pick the next.
</step>

<step name="stuck_on_plan">
If the plan is too big or the user is overwhelmed:

**Sub-step A: Force a scope cut**
Apply the **half-slice rule**: take the current scope and cut it in half. Can the smallest possible user-visible value be a 1-line change? If yes, do that first.

**Sub-step B: Throwaway prototype**
If the cut isn't obvious, load `spike` skill. Build a 20-line throwaway to feel out the smallest possible version. Throw it away after.

**Sub-step C: Restart from scratch (last resort)**
If even the half-slice is unclear, ask the user:
> "אם היית צריך לשלוח את זה למשתמש אחד בעולם מחר בבוקר — מה היית בונה?"

**Wait for user answer.**

Build THAT. Throw away the rest of the plan.
</step>

<step name="mandatory_debugging_loop">
If `unclear_next_step` / `stuck_on_plan` don't resolve, OR if the stuck mode is (1) from `stop_and_classify`, load `systematic-debugging` skill and follow it strictly:

```
Phase 1: Root cause investigation (READ, don't fix)
Phase 2: Pattern analysis (what's the smallest input that reproduces?)
Phase 3: Hypothesis testing (one variable at a time)
Phase 4: Implementation (smallest fix that addresses root cause)
```

**Never skip Phase 1.** "I think I know what's wrong" is not Phase 1.
</step>

<step name="re_anchor_and_exit">
After recovery (whatever path worked), update `.hermes/build-product/state.md`:

```markdown
## Stuck-recovery log
- YYYY-MM-DD: [what was the stuck mode]
- Root cause: [one sentence]
- Fix: [one sentence]
- Preventive rule for next time: [one bullet — append to project memory if reusable]
```

If the preventive rule is reusable across products, append it to the user's project memory as a candidate skill.
</step>

</steps>

<output>
A recovered build that can continue:
- Root cause identified (not guessed)
- One concrete next action proposed
- `state.md` updated with the blocker + recovery
- Either: unblocked, or a precise user input request that unblocks
</output>

<acceptance-criteria>
- [ ] Symptom described in 1-2 sentences
- [ ] `state.md` re-read to understand current phase + blocker
- [ ] Last 5 actions in the build log reviewed
- [ ] Root cause identified (not guessed)
- [ ] Route picked from the diagnostic tree (build / env / spec / dep)
- [ ] One concrete next action proposed
- [ ] If multiple paths, the user picks (not the agent)
- [ ] `state.md` updated with the new focus
- [ ] If still stuck after 15 min → escalate to `systematic-debugging`
</acceptance-criteria>
