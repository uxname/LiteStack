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
#                   `npm run gen`, and the public storage prefix. A failed probe is a
#                   WARNING, not an error (the service may be intentionally down).
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

# Storage: two addresses on purpose. S3_ENDPOINT is where the APP connects (inside
# the container network); S3_PUBLIC_BASE_URL is the prefix the BROWSER resolves, and
# it is stored verbatim in profiles.avatar_url — a typo here is permanent, so it is
# worth a hard check rather than a discovery by a user looking at a broken image.
BE_S3_PUBLIC="$(getval "$BE_ENV" S3_PUBLIC_BASE_URL)"
BE_S3_BUCKET="$(getval "$BE_ENV" S3_BUCKET)"
# Same default as internal/config: an unset S3_BUCKET means "uploads".
BE_S3_BUCKET="${BE_S3_BUCKET:-uploads}"

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

# 6. S3_PUBLIC_BASE_URL — the one value nothing else can catch.
# The app only concatenates it with an object key, so a wrong prefix produces a link
# that is syntactically fine and dead, and the link is already in the database by the
# time anyone notices. Three things are mechanically checkable, and all three are the
# mistakes people actually make.
if [[ -z "$BE_S3_PUBLIC" ]]; then
  fail "S3_PUBLIC_BASE_URL is not set — the backend refuses to start without it (see backend/.env.example)"
else
  # (a) Absolute URL. A bare host ("localhost:3900/uploads") makes a relative link.
  if [[ "$BE_S3_PUBLIC" =~ ^https?://[^/]+ ]]; then
    pass "S3_PUBLIC_BASE_URL is an absolute URL ($BE_S3_PUBLIC)"
  else
    fail "S3_PUBLIC_BASE_URL ($BE_S3_PUBLIC) must start with http:// or https:// — the browser resolves it as-is"
  fi

  # (b) It must END with the bucket name: a file URL is this prefix + "/" + object key,
  # and the bucket is part of the prefix. Dropping it is the classic typo, and it 404s
  # every upload. A trailing slash is tolerated — the app trims one.
  s3_path="${BE_S3_PUBLIC%/}"
  if [[ "$s3_path" == */"$BE_S3_BUCKET" ]]; then
    pass "S3_PUBLIC_BASE_URL ends with the bucket name ($BE_S3_BUCKET)"
  else
    fail "S3_PUBLIC_BASE_URL ($BE_S3_PUBLIC) does not end with the bucket '$BE_S3_BUCKET' — file links would 404"
  fi

  # (c) The host has to be resolvable BY A BROWSER. A single-label name is a
  # container-network name (garage, minio, s3): correct in S3_ENDPOINT, dead in a link.
  s3_hostport="${BE_S3_PUBLIC#*://}"
  s3_host="${s3_hostport%%/*}"
  s3_host="${s3_host%%:*}"
  if [[ "$s3_host" == *.* || "$s3_host" == localhost ]]; then
    pass "S3_PUBLIC_BASE_URL host is browser-resolvable ($s3_host)"
  else
    fail "S3_PUBLIC_BASE_URL host '$s3_host' has no dot — that is a container-network name; a browser cannot resolve it. Use the address your users reach (a domain, or localhost for local work)"
  fi
fi

# 7. (optional) Reachability — pre-codegen GraphQL probe, plus the storage prefix
if [[ "$PROBE" == 1 ]]; then
  if command -v curl >/dev/null 2>&1; then
    if curl -fs -m 5 -X POST "$FE_GQL" -H 'content-type: application/json' \
         -d '{"query":"{ __typename }"}' 2>/dev/null | grep -q '__typename'; then
      pass "GraphQL endpoint reachable ($FE_GQL)"
    else
      warn "GraphQL endpoint not reachable ($FE_GQL) — start the backend before 'npm run gen'"
    fi
    # Any HTTP answer is a pass: the storage may reject a listing of the bucket root
    # (403/404) while serving objects under it perfectly. What this catches is a host
    # that answers nothing — a typo, or a name only the container network knows.
    if [[ -n "$BE_S3_PUBLIC" ]]; then
      if curl -s -o /dev/null -m 5 "$BE_S3_PUBLIC" 2>/dev/null; then
        pass "storage answers at S3_PUBLIC_BASE_URL ($BE_S3_PUBLIC)"
      else
        warn "nothing answers at S3_PUBLIC_BASE_URL ($BE_S3_PUBLIC) — start it with 'docker compose up -d garage garage-init' in backend/, or fix the host"
      fi
    fi
  else
    warn "curl not found — skipped reachability probe"
  fi
fi

# 8. Multi-copy stand (scale/) — pointers, not checks. Its config files are gated on
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
