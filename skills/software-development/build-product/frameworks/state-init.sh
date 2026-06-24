#!/usr/bin/env bash
# state-init.sh — Create a fresh state.md for a build-product session
# Usage: ./state-init.sh [phase] [repo-slug] [repo-path]

set -euo pipefail

PHASE="${1:-new}"
REPO_SLUG="${2:-$(basename "$PWD")}"
REPO_PATH="${3:-$PWD}"
TODAY="$(date -u +%Y-%m-%d)"

# Sanitize repo-slug to kebab-case
REPO_SLUG=$(echo "$REPO_SLUG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')

STATE_DIR=".hermes/build-product"
STATE_FILE="$STATE_DIR/state.md"

if [ -f "$STATE_FILE" ]; then
  echo "⚠️  $STATE_FILE already exists. Refusing to overwrite."
  echo "Use state-update.sh to modify, or delete the file first."
  exit 1
fi

mkdir -p "$STATE_DIR"

# Read template
TEMPLATE="$(dirname "$0")/state-template.md"
if [ ! -f "$TEMPLATE" ]; then
  echo "❌ Template not found at $TEMPLATE"
  exit 1
fi

# Fill template — only replace placeholder lines, don't duplicate
sed -e "s|<repo-slug>|$REPO_SLUG|g" \
    -e "s|<absolute path>|$REPO_PATH|g" \
    -e "s|<YYYY-MM-DD>|$TODAY|g" \
    -e "s|<repo name>|$REPO_SLUG|g" \
    "$TEMPLATE" > "$STATE_FILE"

# Phase is already 'new' in template; if different phase was passed, use python
if [ "$PHASE" != "new" ]; then
  python3 -c "
import re
with open('$STATE_FILE') as f: content = f.read()
content = re.sub(r'^## Phase\n.*$', '## Phase\n$PHASE', content, count=1, flags=re.MULTILINE)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
fi

echo "✅ Created $STATE_FILE"
echo "   Phase: $PHASE"
echo "   Repo: $REPO_SLUG"
echo "   Path: $REPO_PATH"
echo ""
echo "Next: edit 'Current focus' and 'Stack snapshot' sections."