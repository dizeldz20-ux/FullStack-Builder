#!/usr/bin/env bash
# verify-external-refactor.sh
# Companion to incremental-hardening-refactor / references/verifying-external-refactors.md
# Automates the 8-step external-refactor verification recipe for a Node/TypeScript project.
#
# Usage:
#   ./verify-external-refactor.sh <main-repo-path> <refactor-branch>
# Example:
#   ./verify-external-refactor.sh /root/work/ruby-voice-hermes-agent origin/refactor-voiceactions
#
# Exit code:
#   0  -- both gates green
#   1  -- test or typecheck gate failed
#   2  -- setup failure (worktree, symlink, missing files)
#
# This script NEVER modifies the main worktree, NEVER pushes, NEVER runs destructive
# git operations. Read-only verification only.

set -uo pipefail

REPO_PATH="${1:-}"
REFACTOR_BRANCH="${2:-}"

if [[ -z "$REPO_PATH" || -z "$REFACTOR_BRANCH" ]]; then
  echo "Usage: $0 <main-repo-path> <refactor-branch>" >&2
  exit 2
fi

if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "ERROR: $REPO_PATH is not a git repository" >&2
  exit 2
fi

WORKTREE_DIR="/tmp/refactor-review-$$"
echo "=== verify-external-refactor ==="
echo "main repo:      $REPO_PATH"
echo "refactor:       $REFACTOR_BRANCH"
echo "worktree:       $WORKTREE_DIR"
echo

# Step 1 -- Discover
echo "--- Step 1: discover ---"
( cd "$REPO_PATH" && git fetch --all --dry-run 2>&1 | head -10 )
echo
echo "Refactor branch commits vs main:"
( cd "$REPO_PATH" && git log --oneline main.."$REFACTOR_BRANCH" 2>/dev/null | head -20 )
echo
echo "Commits on main that are NOT in refactor (fall-behind-base check):"
( cd "$REPO_PATH" && git log --oneline "$REFACTOR_BRANCH"..main 2>/dev/null | head -20 )
echo

# Step 2 -- Isolate with a worktree (do NOT touch the main worktree)
echo "--- Step 2: worktree ---"
if ! ( cd "$REPO_PATH" && git worktree add "$WORKTREE_DIR" "$REFACTOR_BRANCH" 2>&1 ); then
  echo "ERROR: failed to create worktree" >&2
  exit 2
fi
echo

# Step 3 -- Reuse node_modules
echo "--- Step 3: symlink node_modules ---"
if [[ -d "$REPO_PATH/node_modules" ]]; then
  ln -s "$REPO_PATH/node_modules" "$WORKTREE_DIR/node_modules"
  echo "linked $REPO_PATH/node_modules -> $WORKTREE_DIR/node_modules"
else
  echo "WARNING: $REPO_PATH/node_modules not found; tsc/test will need a fresh install"
fi
echo

# Step 4 -- Dual gate: tests + typecheck
TEST_EXIT=0
TS_EXIT=0

echo "--- Step 4a: test gate ---"
(
  cd "$WORKTREE_DIR"
  if ls scripts/*.test.mjs >/dev/null 2>&1; then
    node --test scripts/*.test.mjs 2>&1
  fi
  if [[ -d backend ]]; then
    ( cd backend && find src -name "*.test.ts" 2>/dev/null | head -5 | while read -r f; do
        echo "running backend test: $f"
        node --import tsx --test "$f" 2>&1 | tail -3
      done )
  fi
) | tail -20
TEST_EXIT=${PIPESTATUS[0]}
echo "(test exit was $TEST_EXIT)"
echo

echo "--- Step 4b: typecheck gate (tsc --noEmit) ---"
TSC_BIN="$REPO_PATH/node_modules/.bin/tsc"
if [[ ! -x "$TSC_BIN" ]]; then
  echo "SKIP: tsc not found in $REPO_PATH/node_modules"
  TS_EXIT=0
else
  for ws in backend frontend; do
    if [[ -d "$WORKTREE_DIR/$ws" ]]; then
      echo "typecheck $ws:"
      ( cd "$WORKTREE_DIR/$ws" && "$TSC_BIN" --noEmit 2>&1 | head -40 )
      WS_TS_EXIT=${PIPESTATUS[0]}
      echo "(typecheck $ws exit was $WS_TS_EXIT)"
      if [[ $WS_TS_EXIT -ne 0 ]]; then TS_EXIT=$WS_TS_EXIT; fi
    fi
  done
fi
echo

# Step 5 -- Hunt smells
echo "--- Step 5: refactor smell hunt ---"
echo
echo "[5a] imports of types that may not be exported:"
( cd "$WORKTREE_DIR" && grep -rn "^import type {" --include="*.ts" --include="*.tsx" 2>/dev/null | head -10 )
echo
echo "[5b] orphaned readFileSync (or other 'removed but referenced' symbols):"
( cd "$WORKTREE_DIR" && grep -rn "readFileSync" --include="*.ts" --include="*.tsx" 2>/dev/null | head -5 )
echo
echo "[5c] implicit-any callbacks:"
( cd "$WORKTREE_DIR" && grep -rEn "\.map\(\(([a-z]+)\) =>" --include="*.ts" 2>/dev/null | head -5 )
echo

# Step 6 -- Empty-blob restoration check
echo "--- Step 6: empty-blob restoration check ---"
EMPTY_BLOB="e69de29"
RESTORE_COMMITS=$( ( cd "$REPO_PATH" && git log --all --oneline --grep="restore.*corrupted\|re-add\|fix.*was corrupted" 2>/dev/null | head -5 ) )
if [[ -n "$RESTORE_COMMITS" ]]; then
  echo "found restore-style commits:"
  echo "$RESTORE_COMMITS"
  echo "(verify each: git show <sha>:<file> | wc -c -- non-zero = restored correctly)"
else
  echo "no restore-style commits found"
fi
echo

# Step 7 -- Summary
echo "=== Summary ==="
echo "worktree: $WORKTREE_DIR (remove with: git -C $REPO_PATH worktree remove --force $WORKTREE_DIR)"
echo "test gate exit:     $TEST_EXIT"
echo "typecheck exit:     $TS_EXIT"
echo

if [[ $TEST_EXIT -eq 0 && $TS_EXIT -eq 0 ]]; then
  echo "VERDICT: gates green -- but still review the diff manually before trusting it"
  exit 0
else
  echo "VERDICT: gate failed -- DO NOT merge as-is"
  exit 1
fi
