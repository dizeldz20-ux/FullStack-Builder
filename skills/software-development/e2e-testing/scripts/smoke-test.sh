#!/usr/bin/env bash
# ============================================================================
# smoke-test.sh — run Playwright smoke tests against local/staging app
# ----------------------------------------------------------------------------
# Usage:
#   ./scripts/smoke-test.sh                    # uses BASE_URL=http://localhost:3000
#   BASE_URL=https://staging.example.com ./scripts/smoke-test.sh
#   SMOKE_GREP=signup ./scripts/smoke-test.sh  # only tests matching "signup"
#   SMOKE_BROWSERS=chromium,firefox ./scripts/smoke-test.sh
#   SMOKE_RETRIES=2 ./scripts/smoke-test.sh
#
# Exit codes:
#   0   all smoke tests passed
#   1   one or more tests failed
#   2   environment not ready (deps missing, app unreachable, etc.)
# ----------------------------------------------------------------------------
# זהו skeleton — מתאים ל-CI ול-local. מתקין browsers פעם אחת, מריץ את
# ה-suite שמסומן ב-SMOKE_TAG (ברירת מחדל: @smoke), שומר report + traces.
# ============================================================================

set -euo pipefail

# ---------- Config (override via env) ---------------------------------------
BASE_URL="${BASE_URL:-http://localhost:3000}"
SMOKE_TAG="${SMOKE_TAG:-@smoke}"
SMOKE_BROWSERS="${SMOKE_BROWSERS:-chromium}"
SMOKE_RETRIES="${SMOKE_RETRIES:-0}"   # 0 in CI לפי flaky-test-strategies
SMOKE_WORKERS="${SMOKE_WORKERS:-1}"   # עולים ל-2 locally; ב-CI = shard index
REPORT_DIR="${REPORT_DIR:-playwright-report}"
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-test-results}"

# ---------- Helpers ----------------------------------------------------------
log()  { printf '\033[1;34m[smoke]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[smoke]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[smoke]\033[0m %s\n' "$*" >&2; exit "${2:-1}"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1" 2
}

# ---------- Preflight --------------------------------------------------------
require_cmd node
require_cmd npx

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "${NODE_MAJOR}" -lt 18 ]; then
  fail "Node 18+ required (found $(node --version))" 2
fi

# ודא שאנחנו בתוך פרויקט Node (יש package.json)
if [ ! -f "package.json" ]; then
  fail "package.json not found — run from project root" 2
fi

# ודא ש-Playwright מותקן
if ! node -e "require.resolve('@playwright/test')" >/dev/null 2>&1; then
  warn "@playwright/test not found in node_modules — installing..."
  npm install --save-dev @playwright/test
fi

# ודא שיש playwright.config
if [ ! -f "playwright.config.ts" ] && [ ! -f "playwright.config.js" ]; then
  warn "no playwright.config.{ts,js} found — using built-in defaults"
fi

# הורד browsers אם חסרים (idempotent — Playwright מדלג אם הכול מותקן)
log "ensuring browsers installed (${SMOKE_BROWSERS})..."
npx playwright install --with-deps "${SMOKE_BROWSERS}" >/dev/null

# ---------- Reachability check ----------------------------------------------
log "checking app reachability at ${BASE_URL}..."
if command -v curl >/dev/null 2>&1; then
  if ! curl --silent --fail --max-time 10 "${BASE_URL}" >/dev/null; then
    warn "app at ${BASE_URL} did not respond — make sure it is running"
    fail "unreachable: ${BASE_URL}" 2
  fi
elif command -v wget >/dev/null 2>&1; then
  if ! wget --quiet --spider --timeout=10 "${BASE_URL}"; then
    fail "unreachable: ${BASE_URL}" 2
  fi
else
  warn "no curl/wget — skipping reachability check"
fi

# ---------- Run smoke tests --------------------------------------------------
mkdir -p "${REPORT_DIR}" "${TEST_RESULTS_DIR}"

log "running Playwright smoke tests..."
log "  base URL : ${BASE_URL}"
log "  tag      : ${SMOKE_TAG}"
log "  browsers : ${SMOKE_BROWSERS}"
log "  retries  : ${SMOKE_RETRIES}"
log "  workers  : ${SMOKE_WORKERS}"

set +e
npx playwright test \
  --grep "${SMOKE_TAG}" \
  --project="${SMOKE_BROWSERS}" \
  --retries="${SMOKE_RETRIES}" \
  --workers="${SMOKE_WORKERS}" \
  --reporter=list,html,github \
  --output="${TEST_RESULTS_DIR}" \
  2>&1 | tee "${REPORT_DIR}/smoke.log"
EXIT_CODE=${?}
set -e

# ---------- Report -----------------------------------------------------------
if [ "${EXIT_CODE}" -eq 0 ]; then
  log "✅ smoke tests passed"
else
  fail "❌ smoke tests failed (exit ${EXIT_CODE}) — see ${REPORT_DIR}/smoke.log" 1
fi