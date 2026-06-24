# Subagent Timeout Recovery — Quick Reference

Companion to the SKILL.md pitfall **"When `delegate_task` subagents time out, the work is partly on disk — verify state, don't restart."** This file is the **recipe** for the recovery flow, distilled from the 2026-06-24 session where 3 of 7 parallel subagents timed out while building skills.

## Decision tree

```
delegate_task timed out?
├─ Yes → Don't retry from scratch.
│
├─ Step 1: Inspect what's on disk
│  ├─ ls -la <target-dir>/
│  ├─ find <target-dir> -type f
│  └─ Compare against the original spec
│
├─ Step 2: Count the gap
│  ├─ 1-3 small files missing → Finish in parent (fast)
│  ├─ 4+ files missing OR inter-dependent → Send focused follow-up subagent
│  └─ Subagent made wrong design choices → Finish in parent (don't amplify damage)
│
└─ Step 3: After recovery, run the audit
   └─ <skill>/scripts/audit-skill.sh OR build-product/scripts/audit-skill.sh
```

## Inspect recipe (copy-paste)

```bash
# For a skill at ~/.hermes/skills/<category>/<skill-name>/
SKILL=~/.hermes/skills/software-development/<skill-name>

echo "=== Top-level ==="
ls -la "$SKILL/"

echo "=== All files ==="
find "$SKILL" -type f | sort

echo "=== Frontmatter check (must be ≥2 dashes) ==="
grep -c '^---$' "$SKILL/SKILL.md"

echo "=== Size summary ==="
du -sh "$SKILL"
```

## Follow-up subagent prompt template

```
Complete the `<skill-name>` skill at `<absolute-path>`. Previous subagent started but timed out.

CURRENT STATE (verified by parent):
- SKILL.md exists (<size>) — DO NOT MODIFY
- tasks/<existing-file>.md exists
- frameworks/ is EMPTY
- references/ is EMPTY

WHAT TO COMPLETE (focused, no scope creep):
1. Add <path-1> — <one-line description>
2. Add <path-2> — <one-line description>
...
N. Add <path-N> — <one-line description>

CONSTRAINTS:
- Do NOT modify existing files (except chmod +x on scripts)
- Do NOT touch any other skills
- Skip skillsmith — direct file creation
- Don't run audits — parent will do that
- Don't ask questions — proceed

Report at end: list of all <N> NEW files created with sizes.
```

## Anti-patterns (avoid these)

- ❌ Retrying the original `delegate_task` from scratch — discards partial work, re-runs slow parts
- ❌ Asking the user "what should I do?" — they don't know subagent progress; `find` does
- ❌ Letting a follow-up subagent keep the broad scope — it will time out again on the same wall
- ❌ Skipping the audit after recovery — partial work + 0 audit = silent bugs

## When this fires most often

| Pattern | Frequency | Why |
|---|---|---|
| Skillsmith init wizard | Common | Interactive wizard inside a 10-min budget |
| Skills with >8 files via subagent | Common | File generation × 7-8 = ~3-4 min; init + content blows past 10 min |
| Heavy MCP research | Occasional | Network latency stacks across many calls |
| Multi-file refactor | Occasional | Plan is fast; execution is slow |

## Stats from the 2026-06-24 session

- 7 skills, 7 `delegate_task` calls
- 3 timed out at 600s
- All 3 had 50-80% on disk when timed out
- 2 of 3 recovered in parent (1-3 missing files each)
- 1 of 3 recovered via follow-up subagent (api-contract-designer — needed 8 more files)
- Total recovery time: ~12 min for all 3 (vs ~30 min if we'd retried from scratch)

## Pitfall cross-reference

For the full pitfall with all context, see `SKILL.md` "Pitfall: When `delegate_task` subagents time out, the work is partly on disk — verify state, don't restart". This file is the **operational quick-reference**; the SKILL.md is the **rule with rationale**.

_footer: build-product/references/subagent-timeout-recovery.md · build-product v1.2.0_