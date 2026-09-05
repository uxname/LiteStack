#!/usr/bin/env bash
#
# doctor.sh — verify the backend ↔ frontend env contract (docs/ENV-CONTRACT.md).
#
# Reads backend/.env and frontend/.env and checks the must-match pairs. A missing .env
# falls back to .env.example so the diagnostics still run, but is itself reported as a
# failure: the apps read only .env, so a green check against .env.example would describe
# a configuration nothing actually runs with. Exits non-zero if any hard check fails.
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
# Prints nothing when the key is absent — that is a normal outcome this script is
# built to report, so it must NOT be an error. Without the trailing `|| true`,
# grep's exit 1 propagates through `pipefail` into `VAR="$(getval …)"` and `set -e`
# kills the checker mid-run: a missing key produced no diagnostic at all, which is
# the opposite of what an env doctor is for.
getval() {
  grep -E "^[[:space:]]*$2=" "$1" 2>/dev/null | tail -1 \
    | sed -E "s/^[[:space:]]*$2=//; s/[[:space:]]+#.*$//; s/^['\"]//; s/['\"]$//; s/[[:space:]]*$//" \
    || true
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

# 0. The .env files must exist at all — the apps read only .env, never .env.example.
for side in backend frontend; do
  if [[ ! -f "$ROOT/$side/.env" ]]; then
    fail "$side/.env is missing (diagnostics below use .env.example, which the app does not read) — run: cp $side/.env.example $side/.env"
  fi
done

BE_PORT="$(getval "$BE_ENV" PORT)"
BE_AUD="$(getval "$BE_ENV" OIDC_AUDIENCE)"
BE_ISS="$(getval "$BE_ENV" OIDC_ISSUER)"
BE_CORS="$(getval "$BE_ENV" CORS_ORIGIN)"
BE_MOCK="$(getval "$BE_ENV" OIDC_MOCK_ENABLED)"

# With OIDC_MOCK_ENABLED=true the backend ignores its own OIDC_* vars entirely
# (docs/ENV-CONTRACT.md), so the two OIDC pairs are *expected* to diverge — the
# shipped .env.example files do exactly that. Reporting it as a hard failure
# trains people to ignore a red doctor, which is worse than no doctor at all.
if [[ "$BE_MOCK" == "true" ]]; then
  oidc() { warn "$1 — ignorable: backend runs in OIDC mock mode"; }
else
  oidc() { fail "$1"; }
fi

FE_PORT="$(getval "$FE_ENV" PORT)"
FE_BASE="$(getval "$FE_ENV" VITE_BASE_URL)"
FE_RES="$(getval "$FE_ENV" VITE_OIDC_API_RESOURCE)"
FE_AUTH="$(getval "$FE_ENV" VITE_OIDC_AUTHORITY)"
FE_GQL="$(getval "$FE_ENV" VITE_GRAPHQL_API_URL)"

# 1. OIDC audience
if [[ -n "$BE_AUD" && "$BE_AUD" == "$FE_RES" ]]; then
  pass "OIDC audience matches ($BE_AUD)"
else
  oidc "OIDC_AUDIENCE ($BE_AUD) != VITE_OIDC_API_RESOURCE ($FE_RES)"
fi

# 2. OIDC tenant
if [[ -n "$BE_ISS" && "$BE_ISS" == "$FE_AUTH" ]]; then
  pass "OIDC tenant matches ($BE_ISS)"
else
  oidc "OIDC_ISSUER ($BE_ISS) != VITE_OIDC_AUTHORITY ($FE_AUTH)"
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

# 7. Multi-copy stand (scale/) — pointers, not checks. Its config files are gated on
# commit (`npm run scale:validate`, wired in lefthook.yml) and the stand itself is
# started by hand, so there is nothing here for this script to verify.
echo
echo "Scale stand (scale/)"
echo "  validate its config: npm run scale:validate"
if [[ -f "$ROOT/scripts/scale-check.sh" ]]; then
  echo "  run the scenarios:   start the stand yourself, then scripts/scale-check.sh"
fi

echo
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED: $FAIL mismatch(es), $WARN warning(s). See docs/ENV-CONTRACT.md."
  exit 1
fi
echo "OK: env contract satisfied${WARN:+, $WARN warning(s)}."
