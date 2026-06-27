#!/usr/bin/env bash
# security-scan-public.sh — Hardened public-repo secret/PII scanner
#
# Companion to scripts/security-scan.sh. That script does the broad
# pattern scan; this one runs the 19-pattern catalog from
# references/public-publish-scrub-catalog.md and triages findings
# (true positives vs documented false positives).
#
# Usage:
#   ./scripts/security-scan-public.sh                    # scan current dir
#   ./scripts/security-scan-public.sh /path/to/repo     # scan a path
#
# Exit code:
#   0 = clean (no real findings)
#   1 = real findings present (block publish)
#
# Self-excludes itself from the scan (so it doesn't flag its own regexes).

set -uo pipefail

# Self-exclusion
SELF="$(realpath "${BASH_SOURCE[0]}")"
SELF_NAME="$(basename "$SELF")"

# Target = argument or current dir
TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
  echo "❌ Target is not a directory: $TARGET" >&2
  exit 1
fi

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

total=0
fail=0

# Each check: label + pattern. The "allow" field is a regex of patterns
# that look like matches but are documented false positives.
check() {
  local label="$1"
  local pattern="$2"
  local allow="${3:-}"

  total=$((total+1))

  # Find matches, exclude self + false-positive patterns
  matches=$(grep -rIE "$pattern" \
    --include="*.md" --include="*.sh" --include="*.py" \
    --include="*.json" --include="*.yaml" --include="*.yml" \
    --exclude="$SELF_NAME" \
    "$TARGET" 2>/dev/null \
    | grep -vE "$allow" \
    | grep -vE "scripts/security-scan-public.sh|scan-100|<your-|<redacted>|<voice-id>|<agent-vm-ip>|<laptop-ip>|<placeholder|<bridge-port>|YOUR-GITHUB-USERNAME|<username>|33a64df5|00000000-0000|noreply@|privaterelay|sbp_<redacted>" \
    || true)

  count=$(echo "$matches" | grep -c . 2>/dev/null || echo 0)

  if [ "$count" = "0" ] || [ -z "$matches" ]; then
    echo -e "  ${GREEN}✅${NC} $label: 0"
  else
    echo -e "  ${RED}❌${NC} $label: $count"
    echo "$matches" | head -5 | sed 's/^/        /'
    fail=$((fail+count))
  fi
}

echo "═══════════════════════════════════════════════════════════"
echo " 100% PUBLIC-PUBLISH SECRET/PII SCAN"
echo " Target: $TARGET"
echo " Self-excluding: $SELF_NAME"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "─── PLACEHOLDER CHECKS ───"
echo "  (Patterns below check for hardcoded personal values."
echo "   Use <your-X> placeholders instead — see scrub catalog.)"
echo ""

# These checks look for SPECIFIC hardcoded values. The generic
# "<your-X>" pattern is always safe and is excluded from each check.
# If you are publishing a skill and these checks fire, you have leaked
# a real value somewhere — replace it with <your-X>.

check "Hardcoded personal name (the user etc)" '<your-name>'
check "Hardcoded GitHub username (in URLs)" 'github\.com/<your-github-username>'
check "Hardcoded email" '[a-zA-Z0-9._-]+@<your-email-domain>'
check "Hardcoded Tailscale IP" '<agent-vm-ip>\.[0-9]+\.[0-9]+\.[0-9]+'
check "Hardcoded bridge port" ':<bridge-port>\b'
check "Hardcoded VM path" '/<agent-vm-home>/\.<service>'
check "Hardcoded laptop path" 'C:\\Users\<windows-username>'
check "Hardcoded vault path" '~/<hermes-config-dir>/memories'
check "Hardcoded Supabase PAT prefix" 'sbp_[a-f0-9]{8,}' 'sbp_<redacted>'
check "Hardcoded GitHub PAT" 'ghp_[a-zA-Z0-9]{8,}'
check "Hardcoded OpenAI key" 'sk-[a-zA-Z0-9]{8,}'
check "Hardcoded Cloudflare Account ID" '[a-f0-9]{32}'
check "Hardcoded ElevenLabs voice ID" 'TX3[a-zA-Z0-9]+'
check "Hardcoded subdomain (specific name pattern)" '\b<specific-subdomain>\b' '<your-subdomain>|<subdomain-placeholder>'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " RESULT: $fail real findings"
echo "═══════════════════════════════════════════════════════════"

if [ "$fail" -eq 0 ]; then
  echo -e "${GREEN}✅ 100% CLEAN — safe to publish${NC}"
  exit 0
else
  echo -e "${RED}❌ NOT CLEAN — fix before commit${NC}"
  echo ""
  echo "Replace hardcoded values with <your-X> placeholders."
  echo "See https://github.com/<your-github-username>/FullStack-Builder/blob/main/skills/software-development/build-product/references/skill-publish-validation.md"
  exit 1
fi