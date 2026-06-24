#!/usr/bin/env bash
# Security scan for FullStack-Builder public repo
#
# Scans for accidentally-committed secrets, IDs, emails, and personal paths.
# Exit 0 = clean. Exit 1 = findings.
#
# Usage: ./scripts/security-scan.sh [path]
# Default path: . (current directory)
#
# IMPORTANT: This script scans itself (self-exclusion via skip list below).
# The pattern strings themselves are hardcoded generic categories — never
# put real values here. Use <your-X> placeholders everywhere instead.

set -euo pipefail

TARGET="${1:-.}"

# Pattern categories — every entry is a generic class, NOT a real value.
# Each real value must be replaced with a <your-X> placeholder before commit.
PATTERNS=(
  # Cloudflare / API tokens (generic class)
  "cfat_[a-zA-Z0-9]{20,}"
  "[a-f0-9]{32}"                                       # 32-hex = CF Account ID format
  "sbp_[a-zA-Z0-9]{20,}"                               # Supabase PAT
  "sb_secret_[a-zA-Z0-9]{15,}"                         # Supabase service key
  "ghp_[a-zA-Z0-9]{30,}"                               # GitHub PAT
  "gho_[a-zA-Z0-9]{30,}"                               # GitHub OAuth
  "sk-[a-zA-Z0-9]{32,}"                                # OpenAI / Anthropic

  # Tailscale / internal IPs (specific 100.x subnets)
  "100\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}"

  # Internal paths (generic classes — never put your real machine name)
  "/<agent-vm-home>/\\.<service-dir>"                  # /root/.openclaw-style
  "C:\\\\Users\\\\<windows-username>"                  # Windows user paths
  "~/<hermes-vault-dir>/memories"                      # Vault paths

  # Phone numbers
  "\\+972-?[0-9]"

  # Voice IDs (generic class — never hardcode your real voice)
  "TX[0-9][a-zA-Z0-9]+"                                # ElevenLabs voice_id format

  # Cloudflare subdomain pattern (specific names should be replaced)
  "<your-subdomain>"                                   # Cloudflare subdomain

  # Hardcoded personal-name patterns (use <your-name> instead)
  "<hardcoded-name-pattern>"
)

ERRORS=0
SELF="$(realpath "$0")"

for pattern in "${PATTERNS[@]}"; do
  # Use grep with -E (extended regex); exclude self + documentation patterns
  if grep -rE "$pattern" "$TARGET" \
       --include="*.md" --include="*.ts" --include="*.tsx" \
       --include="*.js" --include="*.json" \
       --include="*.sh" --include="*.py" --include="*.yml" --include="*.yaml" \
       2>/dev/null \
     | grep -v "^$SELF" \
     | grep -v "<your-" \
     | grep -v "<redacted>" \
     | grep -vE "PLACEHOLDER|<placeholder|<bridge-port>|<voice-id>|<agent-vm-ip>|<laptop-ip>|<username>|YOUR-GITHUB-USERNAME|<hermes-vault>" \
     | head -5; then
    echo "  ❌ Found matches for: $pattern"
    ERRORS=$((ERRORS+1))
  fi
done

if [ "$ERRORS" -eq 0 ]; then
  echo "  ✅ Security scan clean — 0 findings"
  exit 0
else
  echo ""
  echo "  ❌ Total patterns with findings: $ERRORS"
  echo "  Replace hardcoded values with <your-X> placeholders!"
  exit 1
fi