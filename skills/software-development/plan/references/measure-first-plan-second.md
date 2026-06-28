# Measure first, plan second (worked example)

## Session: June 2026, Agentic OS performance audit

**The user's report:** "I keep hitting performance issues with the tabs."

**The wrong plan (the agent's first instinct, before measuring):**

> "Step 1: refactor `setInterval` calls in `hermes/page.tsx`,
> `hermes-local/page.tsx`, `[vault-runner]/page.tsx` to use
> `usePollWhileVisible`.
> Step 2: replace `Promise.all` with `Promise.allSettled` in
> `vitals/route.ts`, `hermesLocal.ts`, `hermesMcp.ts`.
> Step 3: instrument 8 empty `catch {}` blocks in `agentRoom.ts`.
> Step 4: fix `safePrompt.ts` regex that strips ASCII.
> Step 5: add timing headers in the API route layer.
> ~10 file changes across 4 subsystems."

This plan was plausible. It was also *the wrong plan*. The agent
was pattern-matching to a 13-June session (the one captured in
`requesting-code-review` and in the user's standing memory) where
exactly these issues were real. But that was 3 days earlier. The
codebase had moved on.

**The measurement (30 seconds, before any plan):**

```bash
LAPTOP="http://[agent-vm-ip]:3001"
for path in / /pipeline /room /projects /chat /missions /kanban; do
  total=0
  for i in 1 2 3; do
    t=$(curl -s -m 30 -o /dev/null -w "%{time_total}" "$LAPTOP$path" 2>/dev/null)
    total=$(echo "$total + $t" | bc)
  done
  avg=$(echo "scale=3; $total / 3" | bc)
  size=$(curl -s -m 30 -o /dev/null -w "%{size_download}" "$LAPTOP$path" 2>/dev/null)
  echo "  $path -> avg ${avg}s, size ${size} bytes"
done
```

**Output:**

| Route | avg (s) | size (B) | Status |
|---|---|---|---|
| `/` | 6.455 | 109,850 | 🔴 outlier |
| `/chat` | 4.395 | 83,743 | 🔴 outlier |
| `/kanban` | 2.893 | 66,493 | 🟡 slow |
| `/room` | 1.144 | 70,590 | 🟢 fine |
| `/missions` | 1.012 | 71,187 | 🟢 fine |
| `/projects` | 0.897 | 65,806 | 🟢 fine |
| `/pipeline` | 0.746 | 68,562 | 🟢 fine |

**The right plan (after measuring):**

> Focus on `/` (6.5s) and `/chat` (4.4s). The other 5 routes are
> within noise. Do not touch the 4 files in the original plan —
> they are in routes that are already fast. Investigate what's
> special about `/` and `/chat`: SSR cost? Initial-bundle size?
> Render blocking?

**The delta:**

- **Plan size:** 10 file changes → 2 file investigations
- **Plan correctness:** aimed at "the 4 files I remember from
  last time" → aimed at "the 2 files the live data points at"
- **User's experience:** the bigger plan would have closed 4 PRs
  that didn't move the perceived metric and left the actual slow
  pages slow. The smaller plan identifies the real hot path in
  step 1.

## The rule, restated

**For any "this is slow / wrong / broken" task, the first slice
of the plan is measurement, not fix.** The deliverable of the
first slice is *observed numbers* and *ranked hypotheses*, not
a fix.

If the user says "just fix it," push back gently: "give me 30
seconds to measure first, then I'll know where to aim." One round
of measurement costs less than one wrong fix. The user has, in
past sessions, agreed to this every time it was proposed.

## Why this pitfall is adjacent to "plan before verification"

The existing `plan` skill has a pitfall called "plan before
verification = fabrication." That one is about *file shape*
(assuming `shape/route.ts` doesn't exist when it does). This
one is about *performance shape* (assuming the slow pages are
A, B, C when they're X, Y).

Both failures share the same root: a confident plan based on
recollection instead of observation. The fix is the same:
observe first, then plan. The *mechanics* differ — fabrication
is `grep`, `read_file`; this one is `time curl`, `console.time`,
heap snapshots.
