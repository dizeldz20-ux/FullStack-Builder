#!/usr/bin/env bash
# build-product-route.sh — Auto-detect what the user wants and route to the right task
#
# Usage:
#   ./build-product-route.sh           # auto-detect from state + user input
#   ./build-product-route.sh show      # show state and suggested route
#   ./build-product-route.sh new       # force new-product
#   ./build-product-route.sh feature   # force build-feature
#   ./build-product-route.sh stuck     # force stuck-recover
#   ./build-product-route.sh ship      # force ship
#   ./build-product-route.sh deploy    # force deploy-to-cloudflare
#
# Detection logic:
#   1. Read .hermes/build-product/state.md (if exists)
#   2. Combine current phase + the user's recent input
#   3. Map to task
#   4. Print the route + execute if confirmed

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASKS_DIR="$SKILL_DIR/tasks"
FRAMEWORKS_DIR="$SKILL_DIR/frameworks"
STATE_FILE=".hermes/build-product/state.md"
STATE_INIT="$FRAMEWORKS_DIR/state-init.sh"
STATE_UPD="$FRAMEWORKS_DIR/state-update.sh"

#═══════════════════════════════════════════════════════
# HELP
#═══════════════════════════════════════════════════════
show_help() {
  cat << 'EOF'
build-product-route.sh — Auto-detect build phase and route to task

USAGE:
  ./build-product-route.sh              # auto-detect
  ./build-product-route.sh show         # show state + suggestion
  ./build-product-route.sh new          # force new-product task
  ./build-product-route.sh feature      # force build-feature task
  ./build-product-route.sh stuck        # force stuck-recover task
  ./build-product-route.sh ship         # force ship task

AUTO-DETECT INPUTS (in priority order):
  1. CLI argument (forces route)
  2. /build-product state (reads .hermes/build-product/state.md)
  3. Recent git activity in current dir
  4. Existing repo (has code?) vs empty

OUTPUT:
  Routes to: tasks/<phase>.md
EOF
}

#═══════════════════════════════════════════════════════
# DETECT
#═══════════════════════════════════════════════════════
detect_phase() {
  local current_phase=""
  local has_state="no"
  local has_code="no"

  # 1. Has state file?
  if [ -f "$STATE_FILE" ]; then
    has_state="yes"
    current_phase=$(grep -A1 '^## Phase' "$STATE_FILE" 2>/dev/null | tail -1 | tr -d '[:space:]')
  fi

  # 2. Has code? (.git, src/, package.json, etc.)
  if [ -d ".git" ] || [ -d "src" ] || [ -f "package.json" ] || [ -f "requirements.txt" ]; then
    has_code="yes"
  fi

  echo "state=$has_state phase=$current_phase code=$has_code"
}

#═══════════════════════════════════════════════════════
# ROUTE
#═══════════════════════════════════════════════════════
route_to() {
  local task="$1"
  # Map short names to full task names
  case "$task" in
    new) task="new-product" ;;
    feature) task="build-feature" ;;
    stuck) task="stuck-recover" ;;
    ship) task="ship" ;;
    deploy) task="deploy-to-cloudflare" ;;
  esac

  local task_file="$TASKS_DIR/$task.md"

  if [ ! -f "$task_file" ]; then
    echo "❌ Task file not found: $task_file"
    exit 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  → ROUTING TO: tasks/$task.md"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  cat "$task_file"
}

#═══════════════════════════════════════════════════════
# MAIN
#═══════════════════════════════════════════════════════
ACTION="${1:-auto}"

case "$ACTION" in
  help|--help|-h)
    show_help
    exit 0
    ;;

  show)
    echo "═══════════════════════════════════════════════════════"
    echo "  Build Product — State Snapshot"
    echo "═══════════════════════════════════════════════════════"
    detect_phase
    echo ""
    if [ -x "$STATE_UPD" ]; then
      "$STATE_UPD" show 2>/dev/null || echo "(no state file yet)"
    fi
    echo ""
    echo "Suggested route:"
    if [ ! -f "$STATE_FILE" ]; then
      echo "  → tasks/new-product.md  (no state yet)"
    else
      current=$(grep -A1 '^## Phase' "$STATE_FILE" | tail -1 | tr -d '[:space:]')
      case "$current" in
        new|paused)
          echo "  → tasks/new-product.md  (continuing new build)"
          ;;
        feature)
          echo "  → tasks/build-feature.md  (in feature mode)"
          ;;
        stuck)
          echo "  → tasks/stuck-recover.md  (in recovery)"
          ;;
        ship)
          echo "  → tasks/ship.md  (in pre-ship)"
          ;;
        shipped)
          echo "  → tasks/build-feature.md  (next slice, or new-product if pivoting)"
          ;;
        deploy|deploying|deployed)
          echo "  → tasks/deploy-to-cloudflare.md  (deploying / already deployed)"
          ;;
        *)
          echo "  → tasks/new-product.md  (unknown phase, default)"
          ;;
      esac
    fi
    ;;

  new|feature|stuck|ship|deploy)
    route_to "$ACTION"
    ;;

  auto|"")
    if [ ! -f "$STATE_FILE" ]; then
      echo "📋 No state file. Recommending: tasks/new-product.md"
      echo "   (Will auto-create state on first invocation)"
      route_to "new"
    else
      current=$(grep -A1 '^## Phase' "$STATE_FILE" | tail -1 | tr -d '[:space:]')
      case "$current" in
        new|paused)
          route_to "new"
          ;;
        feature|shipped)
          route_to "feature"
          ;;
        stuck)
          route_to "stuck"
          ;;
        ship)
          route_to "ship"
          ;;
        deploy|deploying|deployed)
          route_to "deploy"
          ;;
        *)
          echo "⚠️  Unknown phase '$current'. Defaulting to new-product."
          route_to "new"
          ;;
      esac
    fi
    ;;

  *)
    echo "❌ Unknown action: $ACTION"
    echo ""
    show_help
    exit 1
    ;;
esac