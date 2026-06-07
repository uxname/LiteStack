#!/usr/bin/env bash
#
# doctor.sh — verify the backend ↔ frontend env contract (docs/ENV-CONTRACT.md).
#
# Reads backend/.env and frontend/.env (each falling back to its .env.example) and checks
# the must-match pairs. Exits non-zero if any hard check fails.
#
# Usage:
#   scripts/doctor.sh [--reachable]
#     --reachable   Also probe the GraphQL endpoint (POST { __typename }); needed before
#                   `npm run gen`. A failed probe is a WARNING, not an error (backend may be
#                   intentionally down).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE=0
[[ "${1:-}" == "--reachable" ]] && PROBE=1

# envfile <dir>: echo the dir's .env, or .env.example if .env is absent.
envfile() {
  if [[ -f "$ROOT/$1/.env" ]]; then echo "$ROOT/$1/.env"; else echo "$ROOT/$1/.env.example"; fi
}
BE_ENV="$(envfile backend)"
FE_ENV="$(envfile frontend)"

# getval <file> <KEY>: value of KEY, last wins, quotes + inline comments stripped.
getval() {
  grep -E "^[[:space:]]*$2=" "$1" 2>/dev/null | tail -1 \
    | sed -E "s/^[[:space:]]*$2=//; s/[[:space:]]+#.*$//; s/^['\"]//; s/['\"]$//; s/[[:space:]]*$//"
}

FAIL=0
WARN=0
pass()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
warn()  { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }

echo "Env contract check"
echo "  backend env:  ${BE_ENV#"$ROOT"/}"
echo "  frontend env: ${FE_ENV#"$ROOT"/}"
echo

BE_PORT="$(getval "$BE_ENV" PORT)"
BE_AUD="$(getval "$BE_ENV" OIDC_AUDIENCE)"
BE_ISS="$(getval "$BE_ENV" OIDC_ISSUER)"
BE_CORS="$(getval "$BE_ENV" CORS_ORIGIN)"

FE_PORT="$(getval "$FE_ENV" PORT)"
FE_BASE="$(getval "$FE_ENV" VITE_BASE_URL)"
FE_RES="$(getval "$FE_ENV" VITE_OIDC_API_RESOURCE)"
FE_AUTH="$(getval "$FE_ENV" VITE_OIDC_AUTHORITY)"
FE_GQL="$(getval "$FE_ENV" VITE_GRAPHQL_API_URL)"

# 1. OIDC audience
if [[ -n "$BE_AUD" && "$BE_AUD" == "$FE_RES" ]]; then
  pass "OIDC audience matches ($BE_AUD)"
else
  fail "OIDC_AUDIENCE ($BE_AUD) != VITE_OIDC_API_RESOURCE ($FE_RES)"
fi

# 2. OIDC tenant
if [[ -n "$BE_ISS" && "$BE_ISS" == "$FE_AUTH" ]]; then
  pass "OIDC tenant matches ($BE_ISS)"
else
  fail "OIDC_ISSUER ($BE_ISS) != VITE_OIDC_AUTHORITY ($FE_AUTH)"
fi

# 3. CORS includes frontend origin
if [[ -n "$FE_BASE" && ",$BE_CORS," == *",$FE_BASE,"* ]]; then
  pass "CORS_ORIGIN includes frontend origin ($FE_BASE)"
else
  fail "CORS_ORIGIN ($BE_CORS) does not include VITE_BASE_URL ($FE_BASE)"
fi

# 4. GraphQL URL port == backend PORT
if [[ -n "$BE_PORT" && "$FE_GQL" == *":$BE_PORT/graphql"* ]]; then
  pass "VITE_GRAPHQL_API_URL targets backend port $BE_PORT"
else
  fail "VITE_GRAPHQL_API_URL ($FE_GQL) does not target backend PORT ($BE_PORT) at /graphql"
fi

# 5. Port collision
if [[ -n "$BE_PORT" && -n "$FE_PORT" && "$BE_PORT" != "$FE_PORT" ]]; then
  pass "frontend ($FE_PORT) and backend ($BE_PORT) ports differ"
else
  fail "frontend and backend PORT collide ($FE_PORT / $BE_PORT)"
fi

# 6. (optional) GraphQL reachability — pre-codegen probe
if [[ "$PROBE" == 1 ]]; then
  if command -v curl >/dev/null 2>&1; then
    if curl -fs -m 5 -X POST "$FE_GQL" -H 'content-type: application/json' \
         -d '{"query":"{ __typename }"}' 2>/dev/null | grep -q '__typename'; then
      pass "GraphQL endpoint reachable ($FE_GQL)"
    else
      warn "GraphQL endpoint not reachable ($FE_GQL) — start the backend before 'npm run gen'"
    fi
  else
    warn "curl not found — skipped reachability probe"
  fi
fi

echo
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED: $FAIL mismatch(es), $WARN warning(s). See docs/ENV-CONTRACT.md."
  exit 1
fi
echo "OK: env contract satisfied${WARN:+, $WARN warning(s)}."
