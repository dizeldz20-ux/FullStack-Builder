#!/usr/bin/env bash
# state-update.sh — Quickly update state.md fields without touching the rest
# Usage:
#   ./state-update.sh phase <new|feature|stuck|ship|paused|shipped>
#   ./state-update.sh focus "<one sentence>"
#   ./state-update.sh shipped <slice-name>
#   ./state-update.sh blocker "<description>"
#   ./state-update.sh unblocker "<description>"
#   ./state-update.sh learn "<insight>"
#   ./state-update.sh log "<stuck> → <cause> → <fix> → <preventive>"
#   ./state-update.sh slice "<name>" <branch> <sha1>..<sha2> "<verified>"
#   ./state-update.sh show   # print current state summary

set -euo pipefail

STATE_FILE=".hermes/build-product/state.md"

if [ ! -f "$STATE_FILE" ]; then
  echo "❌ No state file at $STATE_FILE"
  echo "Run state-init.sh first."
  exit 1
fi

ACTION="${1:-show}"
TODAY="$(date -u +%Y-%m-%d)"

case "$ACTION" in
  phase)
    PHASE="$2"
    if [[ ! "$PHASE" =~ ^(new|feature|stuck|ship|paused|shipped|deploy|deploying|deployed)$ ]]; then
      echo "❌ Invalid phase: $PHASE (must be: new|feature|stuck|ship|paused|shipped|deploy|deploying|deployed)"
      exit 1
    fi
    # Update Phase section
    python3 -c "
import re
with open('$STATE_FILE') as f: content = f.read()
content = re.sub(r'^## Phase\n.*$', '## Phase\n$PHASE', content, count=1, flags=re.MULTILINE)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
    # Update last_updated
    python3 -c "
import re
with open('$STATE_FILE') as f: content = f.read()
content = re.sub(r'^last_updated: .*$', 'last_updated: $TODAY', content, count=1, flags=re.MULTILINE)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
    echo "✅ Phase → $PHASE"
    ;;

  focus)
    FOCUS="$2"
    python3 << PYEOF
with open('$STATE_FILE') as f: content = f.read()
import re
# Match from "## Current focus\n" to right before the next "\n## "
content = re.sub(
    r'(## Current focus\n).*?(?=\n## )',
    r'\1$FOCUS\n',
    content,
    count=1,
    flags=re.DOTALL
)
with open('$STATE_FILE', 'w') as f: f.write(content)
PYEOF
    echo "✅ Focus → $FOCUS"
    ;;

  shipped)
    SLICE="$2"
    python3 -c "
with open('$STATE_FILE') as f: content = f.read()
import re
m = re.search(r\"## What's shipped\n(.*?)(?=\n## |\Z)\", content, re.DOTALL)
section = m.group(1) if m else '\n- (none yet)'
if '$SLICE' not in section:
    if '(none yet)' in section:
        new = f'- $SLICE (shipped $TODAY)'
    else:
        new = section.rstrip() + f'\n- $SLICE (shipped $TODAY)'
    content = re.sub(r\"## What's shipped\n.*?(?=\n## |\Z)\", \"## What's shipped\n\" + new + '\n\n', content, count=1, flags=re.DOTALL)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
    echo "✅ Shipped → $SLICE"
    ;;

  blocker)
    BLOCKER="$2"
    python3 -c "
with open('$STATE_FILE') as f: content = f.read()
import re
m = re.search(r'## Blockers\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
section = m.group(1) if m else '\n- (none)'
# Check if current is placeholder
if '(none)' in section:
    new = f'- $BLOCKER'
else:
    new = section.rstrip() + f'\n- $BLOCKER'
content = re.sub(r'## Blockers\n.*?(?=\n## |\Z)', '## Blockers\n' + new + '\n\n', content, count=1, flags=re.DOTALL)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
    echo "✅ Blocker added → $BLOCKER"
    ;;

  unblocker)
    RESOLVED="$2"
    python3 -c "
with open('$STATE_FILE') as f: content = f.read()
import re
content = re.sub(r'(## Blockers\n).*?(?=\n## )', lambda m: m.group(1) + '- (none)\n\n', content, count=1, flags=re.DOTALL)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
    echo "✅ Blocker cleared (was: $RESOLVED)"
    ;;

  learn)
    INSIGHT="$2"
    python3 -c "
with open('$STATE_FILE') as f: content = f.read()
import re
m = re.search(r'## Reusable learnings\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
section = m.group(1) if m else '\n- (none yet)'
if '(none yet' in section:
    new = f'- $INSIGHT'
else:
    new = section.rstrip() + f'\n- $INSIGHT'
content = re.sub(r'## Reusable learnings\n.*?(?=\n## |\Z)', '## Reusable learnings\n' + new + '\n\n', content, count=1, flags=re.DOTALL)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
    echo "✅ Learning added → $INSIGHT"
    ;;

  log)
    ENTRY="$2"
    python3 -c "
with open('$STATE_FILE') as f: content = f.read()
import re
m = re.search(r'## Stuck-recovery log\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
section = m.group(1) if m else '\n- (none yet)'
if '(none yet' in section:
    new = f'- $TODAY: $ENTRY'
else:
    new = section.rstrip() + f'\n- $TODAY: $ENTRY'
content = re.sub(r'## Stuck-recovery log\n.*?(?=\n## |\Z)', '## Stuck-recovery log\n' + new + '\n\n', content, count=1, flags=re.DOTALL)
with open('$STATE_FILE', 'w') as f: f.write(content)
"
    echo "✅ Log entry added"
    ;;

  slice)
    NAME="$2"
    BRANCH="$3"
    COMMITS="$4"
    VERIFIED="$5"
    python3 << PYEOF
with open('$STATE_FILE') as f: content = f.read()
import re
new_section = f'''- Branch: $BRANCH
- Commits: $COMMITS
- Verified: $VERIFIED
- Shipped-at: $TODAY'''
# Replace ONLY the Last vertical slice section
pattern = r'## Last vertical slice\n.*?(?=\n## |\Z)'
content = re.sub(pattern, '## Last vertical slice\n' + new_section + '\n\n', content, count=1, flags=re.DOTALL)
with open('$STATE_FILE', 'w') as f: f.write(content)
PYEOF
    echo "✅ Last slice → $NAME"
    ;;

  show)
    REPO=$(grep '^repo:' $STATE_FILE | head -1 | awk '{print $2}')
    PHASE=$(grep -A1 '^## Phase' $STATE_FILE | tail -1)
    FOCUS=$(grep -A1 '^## Current focus' $STATE_FILE | tail -1)
    BLOCKERS=$(grep -A1 '^## Blockers' $STATE_FILE | tail -1)
    UPDATED=$(grep '^last_updated:' $STATE_FILE | cut -d' ' -f2)
    echo "═══════════════════════════════════════"
    echo "  Build State: $REPO"
    echo "═══════════════════════════════════════"
    echo "  Phase:    $PHASE"
    echo "  Focus:    $FOCUS"
    echo "  Blocker:  $BLOCKERS"
    echo "  Updated:  $UPDATED"
    echo "═══════════════════════════════════════"
    ;;

  *)
    echo "Usage:"
    echo "  $0 phase <phase>"
    echo "  $0 focus \"<text>\""
    echo "  $0 shipped <slice>"
    echo "  $0 blocker \"<text>\""
    echo "  $0 unblocker \"<text>\""
    echo "  $0 learn \"<text>\""
    echo "  $0 log \"<text>\""
    echo "  $0 slice <name> <branch> <sha1..sha2> \"<verified>\""
    echo "  $0 show"
    exit 1
    ;;
esac