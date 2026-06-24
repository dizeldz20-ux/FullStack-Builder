# Loop Coverage Matrix Honesty — Why a "✅" Row Is Only ✅ If the Related Skill Implements the Body

The Loop Coverage Matrix in `frameworks/loops.md` looks authoritative. It's a table with skill names in one column and "✅" in the next. Easy to read. Easy to mistake for ground truth.

It is not ground truth. A row in the matrix is "✅" only if the **related skill** (the skill the row references) has its own loop body, trigger, stop conditions, escalation, and anti-pattern — matching the structure in `loops.md`. If the related skill exists but doesn't have that section, the row is "❌ (planned)" even though the table says "✅".

## The trap (validated 2026-06-24, build-product v1.3.0 expansion)

When expanding the Loop Coverage Matrix to 17 rows (7 original + 7 added in v1.2.0 + 3 added in v1.3.0), the natural workflow was:

1. Write the new loop in `frameworks/loops.md` (the contract).
2. Add a row to the matrix pointing to the related skill.
3. Mark it ✅.

But step 3 is wrong. The contract is in `loops.md`. The **implementation** is in the related skill (`dogfood` for Loop 17, `amrita-architect` for Loop 15, etc.). If the related skill doesn't have a corresponding loop body, the agent that loads the related skill has no idea when to start the loop, when to stop, what to escalate, or what anti-pattern to avoid.

**Concrete example:** v1.3.0 added "Loop 17: Dogfood Pre-Ship" in `loops.md` and a matrix row "dogfood | Loop 17 | ✅". But the `dogfood` skill (at that time) had no loop body — just a workflow. The matrix said ✅; the related skill had no implementation. An agent loading `dogfood` would run the workflow, not the loop. The "✅" was a self-deception.

## The rule (validated 2026-06-24)

A row in the Loop Coverage Matrix is "✅" if and only if **all four** are true:

1. The loop body exists in `frameworks/loops.md` (the contract).
2. The related skill has a corresponding loop section with the same number and name.
3. The related skill's loop body has: trigger, body, stop condition, max iterations, escalation, anti-pattern.
4. The related skill's `<routing>` or `<commands>` references the loop explicitly (so an agent loading the skill sees it).

If any of 1-4 fails, the row should be:

- **❌ (planned)** — contract exists, implementation pending
- **🔧 (in-progress)** — related skill has a stub
- **✅ (full)** — all four conditions met

## The audit recipe

Run this before declaring a coverage row complete:

```bash
# For each matrix row, verify the related skill contains a matching loop body
for skill_loop in "prd-generator:Loop 8" "e2e-testing:Loop 10" "dogfood:Loop 17"; do
  skill="${skill_loop%:*}"
  loop="${skill_loop#*:}"

  # Find the skill in the standard locations
  for base in "$HOME/.hermes/skills/software-development" "$HOME/.hermes/skills"; do
    [ -d "$base/$skill" ] && skill_path="$base/$skill" && break
  done

  if [ -z "$skill_path" ]; then
    echo "  ❌ $skill: skill not found in any standard location"
    continue
  fi

  # Check 1: loop body in the related skill
  found=$(grep -rE "$loop" "$skill_path" 2>/dev/null | wc -l)
  if [ "$found" -eq 0 ]; then
    echo "  ❌ $skill: missing $loop body (matrix says ✅ but skill has no reference)"
  else
    # Check 2: trigger/stop/escalation/anti-pattern present
    structure=$(grep -lE "(Trigger|Stop when|Max iterations|Escalate|Anti-pattern)" "$skill_path/SKILL.md" "$skill_path/frameworks/"*.md 2>/dev/null | wc -l)
    if [ "$structure" -gt 0 ]; then
      echo "  ✅ $skill: $loop body + structure present"
    else
      echo "  🔧 $skill: $loop referenced but no trigger/stop structure — partial"
    fi
  fi
done
```

Output goes to the `ship` task's preflight. If any row is "❌" with "matrix says ✅", downgrade the matrix row to "❌ (planned)" and either implement the loop or remove the matrix row entirely.

## Why this matters beyond the matrix

The Loop Coverage Matrix is a **user-facing claim** — when a user sees "Loop 17: Dogfood Pre-Ship ✅" they trust the loop is real. A matrix that overstates coverage trains the user to disbelieve the matrix, which trains the user to disbelieve *all* of build-product's claims about loop coverage. That's a much worse failure mode than a smaller matrix with honest coverage.

Honest small matrix > dishonest large matrix.

## Connection to other pitfalls in this skill

- `Pitfall: If a finding is "technically partial but works", it's still a finding` — same principle: don't downgrade a finding just because the code "works in practice"
- `Pitfall: Audit the skill every 2-3 integrations` — the matrix audit is one of the things to audit; the skill-structure audit is another
