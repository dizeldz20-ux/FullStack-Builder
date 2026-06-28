# Reference: Loop-aware planning

Companion to the `plan` skill. Every plan implicitly defines
**loops** — when to ask the user again, when to re-verify, when
to escalate. The Forward Future Loop Library skill (installed at
`software-development/loop-library`) catalogs 45 published loops;
this reference is the bridge between writing a plan and designing
the loops that will execute it.

## The one-question test for any plan

Before saving a plan, ask: **"Is this a one-shot workflow or a
loop?"** Most plans are one-shot — write the tasks, ship, exit.
But a non-trivial subset are loops in disguise:

- "Plan the rollout of 10 features over 6 weeks" → loop with
  per-feature exit conditions
- "Plan the refactor of 30 files with regression-safe commits" →
  loop with bisect-friendly commits + smoke per change
- "Plan the migration of 50 users to the new auth flow" →
  loop with per-user verification + rollback rule

If the plan is a loop, the `plan` skill alone is not enough.
Use `software-development/loop-library` in **Design** or
**Adapt** mode to author the loop, then embed it in the plan.

## Mapping the existing `plan` pitfalls to loops

The `plan` skill already encodes several loop-shaped rules.
Naming them as loops makes the design intent explicit:

| `plan` pitfall | Equivalent loop shape | Library skill |
|---|---|---|
| "Plan before verification = fabrication" | **Plan Quality Loop** — verify before commit | `loop-library` Discover → Plan Quality (#35 in catalog) |
| "Ask first, look second" | **Meta-loop** — search returns the answer before asking | `plan/references/dont-ask-when-search-answers.md` (the 4-question decision checklist is itself a loop body) |
| "Multi-slice plans need per-slice approval" | **Builder-Reviewer Loop** per slice | `loop-library` Discover → Builder-Reviewer (#27) |
| "Measure first, plan second" | **Measure-Verify Loop** — observe before act | `plan/references/measure-first-plan-second.md` |
| "Hermes `tts` is not a public endpoint" | **Verification Loop** — confirm API exists before designing against it | `loop-library` Adapt pattern (no catalog entry; design interview) |

When the next `plan` invocation surfaces a new pitfall that is
inherently loop-shaped, the durable home for the pattern is in
`loop-library` — *not* as a plan pitfall. Promote the rule from
`plan/SKILL.md` to `loop-library/references/adapted-loops.md`
with a citation back to the originating plan session.

## When to invoke `loop-library` from inside `plan`

The decision tree:

1. **Is the deliverable a single plan file?** → No loop needed.
   `plan` skill alone is correct.
2. **Is the deliverable a plan + a recurring execution pattern?**
   → Use `plan` to write the file, then invoke `loop-library`
   `Design` mode to author the loop that will execute the plan.
3. **Is there an existing published loop that fits?** → Use
   `loop-library` `Find` mode first; only `Design` if no fit.
4. **Is the user asking to *audit* an existing loop in their
   system?** → Use `loop-library` `Audit` mode. This is the
   case the build-product skill triggers when you ask "where
   can I add loops?" (the loop-library discovers the build's
   existing implicit loops and surfaces them).

## Worked example: 2026-06-24 build-product v1.2

the user asked: "תיקח את כל מה שלמדנו על loop engineering, תבדוק
את הסופר סקיל שלנו, תראה היכן ניתן להכניס לולאות".

The agent's workflow was:

1. **Loaded `loop-library`** (installed from
   `Forward-Future/loop-library`).
2. **Ran `Audit` mode** on `build-product` (the umbrella skill
   that orchestrates the user's product builds). Audit
   surfaced 7 material weaknesses — every one was a missing or
   unbounded loop.
3. **Authored 7 new loops** in `build-product/frameworks/loops.md`,
   each adapted from a published loop in the catalog (or
   designed from scratch when no fit). Each loop has explicit
   trigger, body, stop condition, escalation, and anti-pattern.
4. **Added references** from each `build-product` task file to
   the new loops (one-line pointers, no logic changes).
5. **Smoke-tested the state machine** end-to-end (init → show
   → phase → shipped → show) to confirm nothing broke.

Lesson: **audit is the cheapest entry point into loop design.**
The user already had a working skill; the question "where can
I add loops?" maps cleanly to `loop-library` `Audit`. Design
was only needed for the loops that didn't fit any catalog
entry (Loop 5 self-loop detection, Loop 7 reflection).

## What this reference is NOT

- It is **not** a replacement for the `plan` skill's
  pitfalls. Those are stable rules that survive a session;
  loops are workflow patterns that get authored per project.
- It is **not** a substitute for `loop-library` itself. This
  reference is the bridge; `loop-library` is the catalog and
  the Design/Audit workflow.
- It is **not** an excuse to over-engineer every plan into a
  loop. Most plans are one-shot. The "is this a loop?" test
  above is the gate.

## Trigger phrases for the agent

When the user says any of these, invoke `loop-library` *in
addition to* (not instead of) `plan`:

- "תבדוק איפה אפשר להכניס לולאות" → `loop-library` Audit
- "תבנה לי loop שעושה X" → `loop-library` Design
- "יש לולאה מוכנה בשביל X?" → `loop-library` Find
- "תתאים לי loop שראיתי בקטלוג" → `loop-library` Adapt
- "הסקיל הזה לא עובד כמו שצריך, אולי חסרה לולאה" →
  `loop-library` Audit, then patch the skill with the new loop

When the user says any of these, use `plan` alone (no
`loop-library` needed):

- "תכתוב לי plan ל-X"
- "תתכנן את הארכיטקטורה"
- "איך אני בונה את Y?"
- "תן לי רשימת משימות"
