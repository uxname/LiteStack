#!/usr/bin/env bash
#
# scale-check.sh — drive the multi-copy scenarios against the stand in scale/.
#
# The stand (scale/docker-compose.yml) runs two copies of each side behind one
# Caddy. This script asks the only question that stand exists to answer: is any
# part of the product pinned to ONE copy? Every scenario therefore crosses the
# copies on purpose — write through A, read through B — and each check prints
# ok/not ok. Any failed check makes the exit code non-zero.
#
# The four scenarios below are the stand's half of C13 in the scaling work:
# data not pinned to a copy, rate limits keyed on an address a client cannot
# choose, the frontend not pinned to a copy, and a subscription crossing copies.
#
# Usage:
#   docker compose -f scale/docker-compose.yml up -d --wait   # start it first
#   scripts/scale-check.sh
#   docker compose -f scale/docker-compose.yml down -v
#
# It deliberately does NOT start the stand. Half of what this script is for is
# being run against a BROKEN stand ("stop one backend copy, the check must go
# red"), and a script that brings the stand up first would silently repair the
# very fault it was asked about.
#
# Two things it needs besides the stand: `docker`, because the rate-limit
# scenario needs two clients with different addresses and every request from
# this host arrives at Caddy from the same docker gateway address; and nothing
# else — no jq, no python, no websocket CLI (see ws_send below).
#
# It is not read-only. It uploads a 1x1 PNG and writes the stand's single mock
# profile (avatarUrl, bio). That is what "the data is not pinned to a copy"
# means; `down -v` wipes it. THE STAND RUNS WITH MOCK AUTH — see scale/.env.example.
#
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^#//; s/^ //'
  exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAND="$ROOT/scale"

# port <VAR> <default>: the host port the stand publishes, resolved the way
# `docker compose` resolves it — shell environment first, then scale/.env, then
# the default baked into the compose file. Reading the file matters: someone who
# moved a port in scale/.env would otherwise get a script probing the old one and
# reporting the stand as down.
port() {
  local v="${!1:-}"
  if [[ -z "$v" && -f "$STAND/.env" ]]; then
    v="$(grep -E "^[[:space:]]*$1=" "$STAND/.env" 2>/dev/null | tail -1 \
      | sed -E "s/^[[:space:]]*$1=//; s/[[:space:]]+#.*$//; s/^['\"]//; s/['\"]$//; s/[[:space:]]*$//" || true)"
  fi
  echo "${v:-$2}"
}
PUBLIC="http://localhost:$(port SCALE_HTTP_PORT 8080)"
BE_A="http://localhost:$(port SCALE_BACKEND_A_PORT 8081)"
BE_B="http://localhost:$(port SCALE_BACKEND_B_PORT 8082)"
FE_A="http://localhost:$(port SCALE_FRONTEND_A_PORT 8083)"
FE_B="http://localhost:$(port SCALE_FRONTEND_B_PORT 8084)"
BE_B_HOST_PORT="$(port SCALE_BACKEND_B_PORT 8082)"

# The docker network scale/docker-compose.yml pins by name, so the rate-limit
# clients can attach to the stand without knowing its project directory.
NET=litestack-scale-net
# Alpine + curl, the client the stand's own comments suggest. Overridable for an
# offline machine that has a different curl image cached.
CLIENT_IMAGE="${SCALE_CLIENT_IMAGE:-curlimages/curl:8.22.0}"

# The stand runs with OIDC_MOCK_ENABLED=true and `x-mock-sub` picks the user.
# This exact value is the backend's own MockSub: any OTHER value falls through
# to FindOrCreateMockUser, which re-normalises the mock user's avatar in memory
# on every request — so the avatarUrl written by scenario 1 would never be read
# back, no matter how well the copies share their database.
SUB=mock-oidc-sub
TIMEOUT=20

FAIL=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

WORK="$(mktemp -d)"
CLIENTS=()
cleanup() {
  [[ ${#CLIENTS[@]} -gt 0 ]] && docker rm -f "${CLIENTS[@]}" >/dev/null 2>&1
  rm -rf "$WORK"
  return 0
}
trap cleanup EXIT

# status <outfile> <curl args…>: response body into outfile, status code on
# stdout. A curl that never got an answer prints 000 (its own write-out) instead
# of killing the run under `set -e` — an unreachable copy is a result this script
# reports, not a crash.
status() {
  local out="$1" code
  shift
  code="$(curl -sS -m "$TIMEOUT" -o "$out" -w '%{http_code}' "$@" 2>>"$WORK/curl.err" || true)"
  echo "${code:-000}"
}

# gql <base-url> <json>: POST a GraphQL operation to one copy, body on stdout.
gql() {
  curl -sS -m "$TIMEOUT" -X POST "$1/graphql" \
    -H 'content-type: application/json' -H "x-mock-sub: $SUB" -d "$2" 2>>"$WORK/curl.err" || true
}

# field <name>: value of a top-level JSON string field, read off the raw body.
# Deliberately not jq: this script's only hard dependencies are the ones the
# stand already imposes, and the two shapes it reads are fixed.
# `sed -n 1p` rather than `head -1`: head closes the pipe on its first line, and
# the SIGPIPE that gives the first sed would fail the pipeline under pipefail.
field() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | sed -n 1p; }

echo "Scale stand check"
echo "  public entry: $PUBLIC   backends: $BE_A $BE_B   frontends: $FE_A $FE_B"
echo

# ---------------------------------------------------------------------------
# 0. Both copies of both sides answer. Everything below crosses the copies, so a
#    stand that is only half up would report four unrelated failures instead of
#    the one fact that explains them.
# ---------------------------------------------------------------------------
echo "Stand"
for tool in curl docker; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool not found — this script needs it"
done
probe() { # probe <label> <url>
  local code
  code="$(status /dev/null "$2")"
  if [[ "$code" == 200 ]]; then pass "$1 answers ($2)"; else fail "$1 is down: $2 returned $code"; fi
}
probe "backend copy A" "$BE_A/readyz"
probe "backend copy B" "$BE_B/readyz"
probe "frontend copy A" "$FE_A/health.txt"
probe "frontend copy B" "$FE_B/health.txt"
probe "public entry" "$PUBLIC/livez"
if [[ "$FAIL" -gt 0 ]]; then
  echo
  echo "FAILED: the stand is not fully up — start it with:"
  echo "  docker compose -f scale/docker-compose.yml up -d --wait"
  exit 1
fi
echo

# ---------------------------------------------------------------------------
# 1. Data is not pinned to a copy: upload through A, download the absolute link
#    it returns, and read the profile carrying that link through B.
#
#    The download does not go through either copy — after the app dropped its
#    GET /uploads route the link points at the object store (through Caddy), so
#    "read the file back through copy B" is not a question that exists any more.
# ---------------------------------------------------------------------------
echo "1. Uploads and profile data cross the copies"
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' \
  | base64 -d >"$WORK/pixel.png"
code="$(status "$WORK/upload.json" -X POST "$BE_A/upload" -H "x-mock-sub: $SUB" \
  -F "file=@$WORK/pixel.png;type=image/png")"
LINK="$(field path <"$WORK/upload.json")"
if [[ "$code" == 201 && -n "$LINK" ]]; then
  pass "copy A accepted the upload ($LINK)"
else
  fail "copy A refused the upload: HTTP $code $(head -c 200 "$WORK/upload.json")"
fi

if [[ "$LINK" == "$PUBLIC/uploads/"* ]]; then
  pass "the link is absolute and points at the object store, not at a copy"
else
  fail "the link is not an absolute object-store URL under $PUBLIC/uploads/: '$LINK'"
fi

if [[ -n "$LINK" ]]; then
  code="$(status "$WORK/downloaded.png" "$LINK")"
  if [[ "$code" == 200 ]] && cmp -s "$WORK/pixel.png" "$WORK/downloaded.png"; then
    pass "the link serves back the exact bytes that were uploaded"
  else
    fail "downloading the link returned HTTP $code and $(wc -c <"$WORK/downloaded.png") bytes, expected 200 and the $(wc -c <"$WORK/pixel.png") uploaded ones"
  fi

  gql "$BE_A" "{\"query\":\"mutation(\$u:URL){updateProfile(input:{avatarUrl:\$u}){avatarUrl}}\",\"variables\":{\"u\":\"$LINK\"}}" \
    >"$WORK/update.json"
  if [[ "$(field avatarUrl <"$WORK/update.json")" == "$LINK" ]]; then
    pass "copy A stored the link on the profile"
  else
    fail "copy A did not store the link: $(head -c 200 "$WORK/update.json")"
  fi

  gql "$BE_B" '{"query":"{me{avatarUrl}}"}' >"$WORK/me.json"
  if [[ "$(field avatarUrl <"$WORK/me.json")" == "$LINK" ]]; then
    pass "copy B reads back the profile written through copy A"
  else
    fail "copy B returned a different profile: $(head -c 200 "$WORK/me.json")"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 2. Rate limits are keyed by the real client, not by a header the client wrote.
#
#    Two clients, not one: every curl from this host reaches Caddy as the same
#    docker gateway address and would share one bucket. They also have to be
#    alive AT THE SAME TIME — docker hands a fresh container the address the
#    previous one just released, so two sequential `docker run`s are one client
#    wearing two hats.
#
#    The requests go to /livez through the load-balanced entry: no auth, no body,
#    and answered by BOTH copies in turn — which is also why exhausting the
#    bucket proves the limiter is shared (it lives in Redis) rather than per-copy.
# ---------------------------------------------------------------------------
echo "2. Rate limits key on the address Caddy vouches for"
BURST=20
DRAIN=110 # 10 over the 100/minute limit, so the last few must be refused
FORGED=203.0.113.7

start_client() { # start_client <name>
  docker rm -f "$1" >/dev/null 2>&1 || true
  if docker run -d --rm --name "$1" --network "$NET" --entrypoint sh "$CLIENT_IMAGE" \
    -c 'sleep 300' >/dev/null 2>>"$WORK/docker.err"; then
    CLIENTS+=("$1")
    return 0
  fi
  return 1
}

if ! start_client scale-check-client-1 || ! start_client scale-check-client-2; then
  fail "could not start the two clients on $NET from $CLIENT_IMAGE: $(tail -1 "$WORK/docker.err")"
else
  # One exec, both bursts: the bucket refills at one request per 0.6s, so the
  # forged burst has to follow the drain with no process start-up in between.
  # Together they take well under a second.
  docker exec scale-check-client-1 sh -c "
    curl -s -o /dev/null -w '%{http_code}\n' 'http://caddy:8080/livez?[1-$DRAIN]'
    echo forged
    curl -s -o /dev/null -w '%{http_code}\n' -H 'X-Forwarded-For: $FORGED' 'http://caddy:8080/livez?[1-$BURST]'
  " >"$WORK/client1.txt" 2>>"$WORK/docker.err" || true
  docker exec scale-check-client-2 sh -c \
    "curl -s -o /dev/null -w '%{http_code}\n' 'http://caddy:8080/livez?[1-$BURST]'" \
    >"$WORK/client2.txt" 2>>"$WORK/docker.err" || true

  drained="$(sed -n "1,${DRAIN}p" "$WORK/client1.txt" | grep -c '^429$' || true)"
  allowed="$(sed -n "1,${DRAIN}p" "$WORK/client1.txt" | grep -c '^200$' || true)"
  forged_denied="$(sed -n "/^forged$/,\$p" "$WORK/client1.txt" | grep -c '^429$' || true)"
  second_allowed="$(grep -c '^200$' "$WORK/client2.txt" || true)"

  # Only the refusals are asserted, never "exactly 100 got through": docker hands
  # these containers addresses it has handed out before, so a run started seconds
  # after the previous one inherits a partly-spent bucket. That changes how many
  # requests fit, not whether the limit exists.
  if [[ "$drained" -gt 0 ]]; then
    pass "client 1 ran out of bucket after $allowed requests ($drained of $DRAIN refused)"
  else
    fail "client 1 was never rate-limited: all $allowed of $DRAIN allowed — the limiter is off"
  fi

  # The negative half, and the only check here that can tell a fixed backend from
  # a vulnerable one. A backend that believes the client's own X-Forwarded-For
  # entry hands this burst a brand-new bucket and lets all $BURST through; one
  # that reads the entry Caddy appended keeps the forger in the bucket it just
  # emptied. The threshold is not $BURST because the bucket does refill while the
  # burst runs — but never fast enough to allow more than a handful.
  if [[ "$forged_denied" -ge $((BURST * 3 / 4)) ]]; then
    pass "a forged X-Forwarded-For bought no second bucket ($forged_denied of $BURST still refused)"
  else
    fail "forging X-Forwarded-For: $FORGED bought a fresh bucket — only $forged_denied of $BURST refused; the backend is reading the client's own entry (check TRUSTED_PROXY_HOPS)"
  fi

  # The positive half. One bucket for both clients would be the bucket client 1
  # just emptied, so this burst would come back refused; the same three-quarters
  # threshold as above keeps a recycled address from failing an honest stand.
  if [[ "$second_allowed" -ge $((BURST * 3 / 4)) ]]; then
    pass "client 2 has a bucket of its own ($second_allowed of $BURST allowed while client 1 is blocked)"
  else
    fail "client 2 was refused too ($second_allowed of $BURST allowed) — the two clients share one bucket"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 3. The frontend is not pinned to a copy: the same page, the same locale and
#    the same bundle from either copy.
#
#    Every grep over a rendered page needs -a. The SSR HTML carries bytes GNU
#    grep reads as binary, and without -a it prints NOTHING and still exits 0 —
#    a check that passes on an empty answer.
# ---------------------------------------------------------------------------
echo "3. The frontend serves the same page from either copy"
code="$(status "$WORK/first.html" -D "$WORK/first.headers" -H 'Accept-Language: ru' "$FE_A/")"
if [[ "$code" == 200 ]] && grep -aq 'PARAGLIDE_LOCALE=ru' "$WORK/first.headers"; then
  pass "copy A rendered a page for a ru client and issued PARAGLIDE_LOCALE=ru"
else
  fail "copy A did not issue a ru locale cookie: HTTP $code, $(grep -ai '^set-cookie' "$WORK/first.headers" | tr -d '\r' || echo 'no Set-Cookie')"
fi

a_code="$(status "$WORK/a.html" -H 'Cookie: PARAGLIDE_LOCALE=ru' "$FE_A/")"
b_code="$(status "$WORK/b.html" -D "$WORK/b.headers" -H 'Cookie: PARAGLIDE_LOCALE=ru' "$FE_B/")"
a_lang="$(grep -ao '<html lang="[a-z-]*"' "$WORK/a.html" | head -1 || true)"
b_lang="$(grep -ao '<html lang="[a-z-]*"' "$WORK/b.html" | head -1 || true)"
if [[ "$a_code" == 200 && "$b_code" == 200 && "$a_lang" == '<html lang="ru"' && "$b_lang" == "$a_lang" ]]; then
  pass "the cookie survives the switch: both copies render ru (A $a_code, B $b_code)"
else
  fail "the copies disagree about the locale cookie: A HTTP $a_code ${a_lang:-no <html>}, B HTTP $b_code ${b_lang:-no <html>}"
fi

if grep -aiq '^set-cookie' "$WORK/b.headers"; then
  fail "copy B re-issued a locale cookie instead of honouring the one it was sent: $(grep -ai '^set-cookie' "$WORK/b.headers" | tr -d '\r')"
else
  pass "copy B honoured the cookie rather than re-issuing one"
fi

# A browser hydrating a page from one copy against the bundle of another is the
# multi-copy way to break hydration, and it is the part curl can see: same asset
# hashes means the same build, and the same rendered locale means no en/ru
# mismatch. Client-side hydration itself is the frontend e2e suite's job.
# `|| true` on both: a page with no assets at all is the loudest possible answer
# here, and it must reach the check below rather than end the run through
# grep's exit 1.
grep -ao '/assets/[A-Za-z0-9_.-]*' "$WORK/a.html" | sort -u >"$WORK/a.assets" || true
grep -ao '/assets/[A-Za-z0-9_.-]*' "$WORK/b.html" | sort -u >"$WORK/b.assets" || true
if [[ -s "$WORK/a.assets" ]] && cmp -s "$WORK/a.assets" "$WORK/b.assets"; then
  pass "both copies reference the same $(wc -l <"$WORK/a.assets" | tr -d ' ') built assets — nothing for hydration to mismatch"
else
  fail "the copies serve different bundles (hydration would break on a copy switch): $(diff "$WORK/a.assets" "$WORK/b.assets" | tr '\n' ' ' | head -c 200)"
fi
echo

# ---------------------------------------------------------------------------
# 4. A subscription opened on one copy receives what another copy published —
#    the events travel through Redis, not through the process that served the
#    socket.
#
#    The client is written by hand because there is no websocket in curl's
#    command line and this repository is not getting a websocket dependency for
#    one check. A client frame must be masked (RFC 6455 §5.3) but the mask key
#    may be zero, and payload XOR 0 is the payload — so a frame is a 6-byte
#    header and the text. Server frames are unmasked, so reading is a grep over
#    the raw stream.
# ---------------------------------------------------------------------------
echo "4. Subscriptions cross the copies"
NONCE="scale-check-$$-$RANDOM"
if ! exec 3<>"/dev/tcp/127.0.0.1/$BE_B_HOST_PORT"; then
  fail "could not open a socket to backend copy B on port $BE_B_HOST_PORT"
else
  printf 'GET /graphql HTTP/1.1\r\nHost: 127.0.0.1:%s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: graphql-transport-ws\r\n\r\n' \
    "$BE_B_HOST_PORT" >&3
  cat <&3 >"$WORK/ws.raw" &
  READER=$!

  ws_send() { # one text frame, zero mask; payloads here are far under the 126-byte header break
    if [[ ${#1} -ge 126 ]]; then
      fail "websocket payload too long for the short-frame header: ${#1} bytes"
      return
    fi
    printf '\x81' >&3
    printf "\\x$(printf %02x $((0x80 | ${#1})))\\x00\\x00\\x00\\x00" >&3
    printf '%s' "$1" >&3
  }
  # await <pattern> <deciseconds>
  await() {
    local i
    for ((i = 0; i < $2; i++)); do
      grep -aq "$1" "$WORK/ws.raw" && return 0
      sleep 0.1
    done
    return 1
  }

  ws_send "{\"type\":\"connection_init\",\"payload\":{\"x-mock-sub\":\"$SUB\"}}"
  if await connection_ack 50; then
    pass "copy B accepted a graphql-transport-ws connection"
    ws_send '{"id":"1","type":"subscribe","payload":{"query":"subscription{profileUpdated{bio}}"}}'
    # The resolver subscribes to Redis when this message lands; publishing before
    # that would be a race this script would report as a broken product.
    sleep 1
    gql "$BE_A" "{\"query\":\"mutation(\$b:String){updateProfile(input:{bio:\$b}){bio}}\",\"variables\":{\"b\":\"$NONCE\"}}" \
      >"$WORK/publish.json"
    if [[ "$(field bio <"$WORK/publish.json")" != "$NONCE" ]]; then
      fail "copy A did not publish the update: $(head -c 200 "$WORK/publish.json")"
    elif await "$NONCE" 100; then
      pass "the event published through copy A arrived on the socket held by copy B"
    else
      fail "the event published through copy A never reached copy B within 10s (subscriptions are pinned to the publishing copy)"
    fi
  else
    fail "copy B never acknowledged the websocket connection: $(tr -d '\0' <"$WORK/ws.raw" | tail -c 120 | tr '\r\n' '  ')"
  fi

  kill "$READER" 2>/dev/null || true
  wait "$READER" 2>/dev/null || true
  exec 3>&-
fi

echo
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED: $FAIL check(s) above. The stand runs the product exactly as more than one"
  echo "copy of it runs in production, so a red line here is a fault in the product."
  exit 1
fi
echo "OK: all four scenarios pass — neither side is pinned to a copy."
