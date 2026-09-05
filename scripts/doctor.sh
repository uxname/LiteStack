#!/usr/bin/env bash
#
# doctor.sh — verify the backend ↔ frontend env contract (docs/ENV-CONTRACT.md).
#
# Reads each value the way the apps read it: an exported environment variable
# first, then that side's .env when the file exists. A .env is OPTIONAL — a
# fully exported environment is a supported setup (docs/ENV-CONTRACT.md), and
# both are checked here with the same strictness. A value found in neither place
# is reported as unset, never borrowed from .env.example: a green check against
# a file nothing reads would describe a configuration nothing runs with.
#
# Because an env-var-only setup gives each side its OWN environment, run this
# where both are visible — or from a shell that exports both sides' variables.
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

# fileval <file> <KEY>: value of KEY in an .env file, last wins, quotes + inline
# comments stripped. Prints nothing when the file or the key is absent — that is
# a normal outcome this script is built to report, so it must NOT be an error.
# Without the trailing `|| true`, grep's exit 1 propagates through `pipefail`
# into `VAR="$(fileval …)"` and `set -e` kills the checker mid-run: a missing key
# produced no diagnostic at all, which is the opposite of what an env doctor is
# for.
fileval() {
  [[ -f "$1" ]] || return 0
  grep -E "^[[:space:]]*$2=" "$1" 2>/dev/null | tail -1 \
    | sed -E "s/^[[:space:]]*$2=//; s/[[:space:]]+#.*$//; s/^['\"]//; s/['\"]$//; s/[[:space:]]*$//" \
    || true
}

# val <side> <KEY>: the value that side's app would actually see, and where it
# came from (in SRC, for the report).
#
# The frontend's PORT is the one name both sides use, so it can never be told
# apart in a shared environment. It is not read from there at all: the
# frontend's origin is VITE_BASE_URL — the address the browser really uses, and
# the one CORS is checked against — so its port is taken from that.
val() {
  local side="$1" key="$2" v=""
  if [[ "$side" == frontend && "$key" == PORT ]]; then
    v="${VITE_BASE_URL:-}"
    v="${v##*:}"; v="${v%%/*}"
    [[ "$v" =~ ^[0-9]+$ ]] || v=""
  else
    v="${!key:-}"
  fi
  if [[ -n "$v" ]]; then SRC=environment; echo "$v"; return; fi

  v="$(fileval "$ROOT/$side/.env" "$key")"
  if [[ -n "$v" ]]; then SRC="$side/.env"; echo "$v"; return; fi

  SRC=unset
}

# Where each side's configuration comes from, so the report is never ambiguous
# about which values it just checked.
srcline() {
  local side="$1" envs=0 files=0 k out=""
  shift
  for k in "$@"; do
    val "$side" "$k" >/dev/null
    case "$SRC" in
      environment) envs=$((envs + 1)) ;;
      */.env)      files=$((files + 1)) ;;
    esac
  done
  if [[ "$envs" -gt 0 ]]; then out="environment ($envs)"; fi
  if [[ "$files" -gt 0 ]]; then out="${out:+$out + }$side/.env ($files)"; fi
  printf '  %-10s %s\n' "$side:" "${out:-nothing configured}"
  [[ -n "$out" ]]
}

FAIL=0
WARN=0
pass()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
warn()  { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }

# The contract keys, per side — also what the source report below counts.
BE_KEYS=(PORT CORS_ORIGIN OIDC_ISSUER OIDC_AUDIENCE OIDC_MOCK_ENABLED S3_PUBLIC_BASE_URL S3_BUCKET)
FE_KEYS=(PORT VITE_BASE_URL VITE_OIDC_AUTHORITY VITE_OIDC_API_RESOURCE VITE_GRAPHQL_API_URL)

echo "Env contract check"
echo "  each value: exported environment first, then <side>/.env (optional)"
srcline backend  "${BE_KEYS[@]}" ||
  fail "backend: nothing configured — export its variables, or run: cp backend/.env.example backend/.env"
srcline frontend "${FE_KEYS[@]}" ||
  fail "frontend: nothing configured — export its variables, or run: cp frontend/.env.example frontend/.env"
echo

BE_PORT="$(val backend PORT)"
BE_AUD="$(val backend OIDC_AUDIENCE)"
BE_ISS="$(val backend OIDC_ISSUER)"
BE_CORS="$(val backend CORS_ORIGIN)"
BE_MOCK="$(val backend OIDC_MOCK_ENABLED)"

# Storage: two addresses on purpose. S3_ENDPOINT is where the APP connects (inside
# the container network); S3_PUBLIC_BASE_URL is the prefix the BROWSER resolves, and
# it is stored verbatim in profiles.avatar_url — a typo here is permanent, so it is
# worth a hard check rather than a discovery by a user looking at a broken image.
BE_S3_PUBLIC="$(val backend S3_PUBLIC_BASE_URL)"
BE_S3_BUCKET="$(val backend S3_BUCKET)"
# Same default as internal/config: an unset S3_BUCKET means "uploads".
BE_S3_BUCKET="${BE_S3_BUCKET:-uploads}"

FE_PORT="$(val frontend PORT)"
FE_BASE="$(val frontend VITE_BASE_URL)"
FE_RES="$(val frontend VITE_OIDC_API_RESOURCE)"
FE_AUTH="$(val frontend VITE_OIDC_AUTHORITY)"
FE_GQL="$(val frontend VITE_GRAPHQL_API_URL)"

# With OIDC_MOCK_ENABLED=true the backend ignores its own OIDC_* vars entirely
# (docs/ENV-CONTRACT.md), so the two OIDC pairs are *expected* to diverge — the
# shipped .env.example files do exactly that. Reporting it as a hard failure
# trains people to ignore a red doctor, which is worse than no doctor at all.
if [[ "$BE_MOCK" == "true" ]]; then
  oidc() { warn "$1 — ignorable: backend runs in OIDC mock mode"; }
else
  oidc() { fail "$1"; }
fi

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

  # (b) The prefix has to ADDRESS the bucket, and there are two ways to do it:
  #   host-addressed  http://localhost:3902            — the dev Garage picks the
  #                   bucket from the Host header, so the prefix carries no path
  #                   at all and the whole path IS the object key;
  #   path-addressed  https://files.example.com/uploads — a proxy or path-style S3
  #                   endpoint, where the bucket is the last path segment.
  # So a path-less prefix is correct as it stands. A prefix that HAS a path must
  # end with the bucket: any other path is prepended to every object key and 404s
  # every upload — the classic typo. A trailing slash is tolerated (the app trims one).
  s3_after_scheme="${BE_S3_PUBLIC%/}"
  s3_after_scheme="${s3_after_scheme#*://}"
  # Empty unless the prefix carries a path, i.e. unless it is more than host[:port].
  s3_path=""
  if [[ "$s3_after_scheme" == */* ]]; then s3_path="${s3_after_scheme#*/}"; fi
  if [[ -z "$s3_path" ]]; then
    pass "S3_PUBLIC_BASE_URL addresses the bucket by host (no path prefix)"
  elif [[ "/$s3_path" == */"$BE_S3_BUCKET" ]]; then
    pass "S3_PUBLIC_BASE_URL path ends with the bucket name ($BE_S3_BUCKET)"
  else
    fail "S3_PUBLIC_BASE_URL ($BE_S3_PUBLIC) has a path that does not end with the bucket '$BE_S3_BUCKET' — that path is prepended to every object key and file links would 404"
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
