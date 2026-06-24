#!/usr/bin/env bash
# audit-skill.sh — Detect drift across build-product's three sources of truth
#
# The skill's commands and phases live in THREE places:
#   1. SKILL.md <commands> table           (user-facing)
#   2. frameworks/route.sh case statement (auto-detect router)
#   3. frameworks/state-update.sh regex    (phase validator)
#
# Adding/editing a command in any one without updating the other two causes
# silent breakage. Run this script after any skill integration or edit.
#
# Usage:
#   ./scripts/audit-skill.sh
#
# Exit codes:
#   0  — green, no drift
#   1  — drift detected, see output
#   2  — script error (missing files, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"
ROUTE_SH="$SKILL_DIR/frameworks/route.sh"
STATE_UPDATE="$SKILL_DIR/frameworks/state-update.sh"

ERRORS=0

#─────────────────────────────────────────────────────────────
# 1. SKILL.md exists and is parseable
#─────────────────────────────────────────────────────────────
if [ ! -f "$SKILL_MD" ]; then
  echo "❌ SKILL.md not found at $SKILL_MD"
  exit 2
fi

#─────────────────────────────────────────────────────────────
# 2. Extract commands from SKILL.md <commands> table
#─────────────────────────────────────────────────────────────
# Pattern: | `/build-product <name>` | ... | @tasks/<file>.md |
# Match: capture the command name (after /build-product ) and the target file
SKILL_COMMANDS=$(grep -oE '\| `/build-product[[:space:]]+([^`]+)`[^|]*\|[[:space:]]*@tasks/[^|]+\.md[[:space:]]*\|' "$SKILL_MD" \
  | sed -E 's/.*`\/build-product[[:space:]]+([^`]+)`.*@tasks\/([^/.]+).*/\1|\2/' \
  | sort -u)
SKILL_NAMES=$(echo "$SKILL_COMMANDS" | cut -d'|' -f1)
SKILL_TASKS=$(echo "$SKILL_COMMANDS" | cut -d'|' -f2)

echo "═══════════════════════════════════════════════════════"
echo "  build-product skill audit"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "### Step 1: SKILL.md <commands> table"
if [ -z "$SKILL_COMMANDS" ]; then
  echo "  ⚠️  No commands found in <commands> table — regex may need updating"
  ERRORS=$((ERRORS+1))
else
  echo "$SKILL_COMMANDS" | while IFS='|' read -r cmd task; do
    task_file="$SKILL_DIR/tasks/${task}.md"
    if [ -f "$task_file" ]; then
      echo "  ✅ /build-product $cmd → @tasks/$task.md"
    else
      echo "  ❌ /build-product $cmd → @tasks/$task.md (FILE MISSING)"
    fi
  done
fi

#─────────────────────────────────────────────────────────────
# 3. Extract commands from route.sh
#─────────────────────────────────────────────────────────────
echo ""
echo "### Step 2: route.sh case statement"
if [ ! -f "$ROUTE_SH" ]; then
  echo "  ❌ route.sh not found at $ROUTE_SH"
  ERRORS=$((ERRORS+1))
else
  # Find: name) task="task-name" ;;
  ROUTE_TASK_MAP=$(grep -oE '^[[:space:]]*([a-z][a-z_-]*)[[:space:]]*\)[[:space:]]*task="[a-z-]+"' "$ROUTE_SH" \
    | sed -E 's/.*\b([a-z][a-z_-]*)\)[[:space:]]*task="([a-z-]+)".*/\1|\2/' \
    | sort -u)

  ROUTE_NAMES=$(echo "$ROUTE_TASK_MAP" | cut -d'|' -f1)

  # Find: name|phase|...) route_to "name" ;; — these are the phases handled
  ROUTE_AUTO_PHASES=$(grep -oE '^[[:space:]]*(new|paused|feature|shipped|stuck|ship|deploy|deploying|deployed|restart)\)[[:space:]]*\)[[:space:]]*route_to' "$ROUTE_SH" \
    | sed -E 's/.*\b([a-z]+)\).*/\1/' \
    | sort -u)

  if [ -z "$ROUTE_TASK_MAP" ]; then
    echo "  ⚠️  No task mappings found in route.sh"
    ERRORS=$((ERRORS+1))
  else
    echo "$ROUTE_TASK_MAP" | while IFS='|' read -r cmd task; do
      echo "  ✅ $cmd → $task"
    done
  fi

  echo ""
  echo "  Phases handled by route.sh auto-routing:"
  echo "$ROUTE_AUTO_PHASES" | sed 's/^/    /'
fi

#─────────────────────────────────────────────────────────────
# 4. Extract phases from state-update.sh regex
#─────────────────────────────────────────────────────────────
echo ""
echo "### Step 3: state-update.sh phase regex"
if [ ! -f "$STATE_UPDATE" ]; then
  echo "  ❌ state-update.sh not found at $STATE_UPDATE"
  ERRORS=$((ERRORS+1))
else
  STATE_PHASES=$(grep -oE 'PHASE =~ \^\([^)]+\)\$' "$STATE_UPDATE" \
    | head -1 \
    | sed -E 's/.*\(([^)]+)\).*/\1/' \
    | tr '|' '\n' \
    | sort -u)

  if [ -z "$STATE_PHASES" ]; then
    echo "  ⚠️  No phase regex found in state-update.sh — pattern may have changed"
    ERRORS=$((ERRORS+1))
  else
    echo "$STATE_PHASES" | sed 's/^/  - /'
  fi
fi

#─────────────────────────────────────────────────────────────
# 5. Cross-check: SKILL.md commands vs route.sh
#─────────────────────────────────────────────────────────────
echo ""
echo "### Step 4: Cross-check SKILL.md commands vs route.sh"
if [ -n "$SKILL_NAMES" ] && [ -n "$ROUTE_NAMES" ]; then
  MISSING_IN_ROUTE=$(comm -23 <(echo "$SKILL_NAMES") <(echo "$ROUTE_NAMES"))
  MISSING_IN_SKILL=$(comm -13 <(echo "$SKILL_NAMES") <(echo "$ROUTE_NAMES"))

  if [ -n "$MISSING_IN_ROUTE" ]; then
    echo "  ❌ Commands in SKILL.md but NOT in route.sh:"
    echo "$MISSING_IN_ROUTE" | sed 's/^/      - \//'
    ERRORS=$((ERRORS+1))
  fi
  if [ -n "$MISSING_IN_SKILL" ]; then
    echo "  ⚠️  Commands in route.sh but NOT in SKILL.md (may be aliases):"
    echo "$MISSING_IN_SKILL" | sed 's/^/      - /'
  fi
  if [ -z "$MISSING_IN_ROUTE" ] && [ -z "$MISSING_IN_SKILL" ]; then
    echo "  ✅ SKILL.md commands and route.sh commands match"
  fi
fi

#─────────────────────────────────────────────────────────────
# 6. Cross-check: route.sh phases vs state-update.sh phases
#─────────────────────────────────────────────────────────────
echo ""
echo "### Step 5: Cross-check route.sh phases vs state-update.sh phases"
if [ -n "$ROUTE_AUTO_PHASES" ] && [ -n "$STATE_PHASES" ]; then
  MISSING_IN_STATE=$(comm -23 <(echo "$ROUTE_AUTO_PHASES") <(echo "$STATE_PHASES"))
  MISSING_IN_ROUTE=$(comm -13 <(echo "$ROUTE_AUTO_PHASES") <(echo "$STATE_PHASES"))

  if [ -n "$MISSING_IN_STATE" ]; then
    echo "  ❌ Phases handled by route.sh but NOT accepted by state-update.sh:"
    echo "$MISSING_IN_STATE" | sed 's/^/      - /'
    ERRORS=$((ERRORS+1))
  fi
  if [ -n "$MISSING_IN_ROUTE" ]; then
    echo "  ⚠️  Phases accepted by state-update.sh but NOT routed by route.sh:"
    echo "$MISSING_IN_ROUTE" | sed 's/^/      - /'
  fi
  if [ -z "$MISSING_IN_STATE" ] && [ -z "$MISSING_IN_ROUTE" ]; then
    echo "  ✅ route.sh phases and state-update.sh phases match"
  fi
fi

#─────────────────────────────────────────────────────────────
# 7. Verify all @-references in SKILL.md resolve to real files
#─────────────────────────────────────────────────────────────
echo ""
echo "### Step 6: @-references in SKILL.md"
# Match: @tasks/<file>, @frameworks/<file>, @references/<file>
REFS=$(grep -oE '@(tasks|frameworks|references)/[a-zA-Z0-9_.-]+\.(md|sh)' "$SKILL_MD" \
  | sed -E 's/@//' \
  | sort -u)
for ref in $REFS; do
  if [ -f "$SKILL_DIR/$ref" ]; then
    echo "  ✅ @$ref"
  else
    echo "  ❌ @$ref (FILE MISSING)"
    ERRORS=$((ERRORS+1))
  fi
done

#─────────────────────────────────────────────────────────────
# Summary
#─────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
  echo "  ✅ AUDIT PASSED — no drift detected"
else
  echo "  ❌ AUDIT FAILED — $ERRORS issue(s) detected"
  echo ""
  echo "  Fix order:"
  echo "  1. Update route.sh to handle all SKILL.md commands"
  echo "  2. Update state-update.sh to accept all route.sh phases"
  echo "  3. Create any missing tasks/*.md files"
  echo "  4. Re-run this script until green"
fi
echo "═══════════════════════════════════════════════════════"
exit $ERRORS