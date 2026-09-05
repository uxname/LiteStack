# Env contract — backend ↔ frontend

The two submodules are wired together through environment variables that **must agree**.
Most mismatches surface at runtime (401s, CORS blocks, broken GraphQL codegen), but two cases
**fail fast at startup**: an empty `CORS_ORIGIN` in production (backend refuses to boot)
and any missing required `VITE_*` var (the frontend server refuses to boot, naming the
variable in the log). Both prod compose files fail even earlier — at
`docker compose config` time, naming the missing variable — so a half-configured host never
reaches a container. No `.env` is required for that; exported environment variables work.
`scripts/doctor.sh` checks these pairs automatically — run it after changing any value.
It also hard-checks `S3_PUBLIC_BASE_URL` on its own, because nothing else can: the app
only concatenates that prefix with an object key, so a wrong one yields a link that is
valid-looking and dead, and it is already stored in `profiles.avatar_url` by the time
anyone sees a broken image. The check requires an absolute `http(s)` URL on a host a
browser can actually resolve — a single-label host like `garage` is a container-network
name, right for `S3_ENDPOINT` and dead in a link — and, when the prefix carries a path,
that the path ends in the bucket name.

## Where the values come from

**`.env` is optional. A plain exported environment is a first-class, fully supported
setup** — every part of the stack works without a single `.env` file
([ADR-0006](./adr/0006-env-vars-are-the-config-source-env-file-optional.md)):

| Piece | How it reads the value |
|---|---|
| backend app (`task start:dev`, `go run`) | real environment; `backend/.env` loaded only if the file exists, and it never overrides an exported variable |
| frontend app (`npm run start:dev`, SSR container) | real environment; `frontend/.env` loaded the same way |
| both `docker-compose.yml` (dev) and `docker-compose.prod.yml` | explicit `environment:` mappings fed by interpolation — shell variables first, then a `.env` next to the file when it exists |
| `task db:migrate`, `npm run gen` | real environment, `.env` as a fallback |
| `scripts/doctor.sh` | exported variable first, then that side's `.env`; **never** `.env.example`, because a green check against a file nothing reads describes a configuration nothing runs with |

Two consequences worth knowing:

- **`PORT` is the one variable name both sides use**, so one shell cannot hold both
  values. Export it per side — it belongs to whichever app you are starting. `doctor.sh`
  therefore takes the frontend's port from `VITE_BASE_URL` (the origin the browser really
  uses) instead of from `PORT`.
- **The dev compose files fail at `docker compose config`**, naming the variable, when a
  required value is missing — the same guard the prod files use. Nothing starts
  half-configured.

## Must-match pairs

| Concern | Backend var | Frontend var | Rule | If mismatched |
|---|---|---|---|---|
| **OIDC audience** | `OIDC_AUDIENCE` | `VITE_OIDC_API_RESOURCE` | **Equal.** This is the `aud` claim of the access token the SPA sends. Mismatch → backend rejects every request (401). | Login "succeeds", then **401 on every API call**. |
| **OIDC tenant** | `OIDC_ISSUER` | `VITE_OIDC_AUTHORITY` | **Equal.** Both point at the same Logto tenant. (`OIDC_JWKS_URI` = `OIDC_ISSUER` + `/jwks`.) | Tokens issued by the wrong issuer → same wall of 401s; a wrong redirect URI instead fails inside Logto with `redirect_uri_mismatch`. |
| **CORS + WebSockets** | `CORS_ORIGIN` | `VITE_BASE_URL` | `CORS_ORIGIN` (comma-separated, entries trimmed on load) **must include** the frontend origin. It gates **both** HTTP CORS and the GraphQL **WebSocket handshake**, so a mismatch blocks `/graphql` + `/upload` in the browser **and** silently refuses subscriptions from that origin (403 on upgrade). An empty list allows any origin for **HTTP** (refused in production, but *not* on other environments — set it explicitly on staging); the **WebSocket** handshake is never allow-all — with an empty list only same-origin and Origin-less (non-browser) clients connect. | Browser blocks `/graphql` + `/upload` (CORS errors in console); subscriptions die with **403** on upgrade. The silent trap: outside production an empty backend list allows all origins, so a stack wired to the wrong database looks healthy while writing real users into it. Set `CORS_ORIGIN` explicitly in every environment, staging included, and check the `.env` on the host — the image tag cannot tell you which database it is pointed at. |
| **GraphQL endpoint** | `PORT` | `VITE_GRAPHQL_API_URL` | The frontend URL's port **must equal** the backend `PORT`, path `/graphql`. Mismatch → data fetching + codegen fail. Moving the backend's public domain is a variable change on the frontend and nothing else — set the new value and restart the container. | Every query/mutation **and codegen fail** with network errors against the wrong port/path. |
| **Port collision** | `PORT` (4000) | `PORT` (3000) | Backend and frontend ports **must differ** (and not collide with admin ports 5100/5200/5300/5432/6379). This only concerns local runs: `PORT` is the dev-server port on the host, and in the dev compose files it picks the **host** side of the mapping (the containers always listen on 4000 and 3000). Neither `docker-compose.prod.yml` publishes a host port at all, so nothing there can collide. | Host port mappings clash locally, or one app steals the other's traffic. |

## Frontend: read at boot vs fixed at build

The frontend server reads its public values from **the container's environment when
it starts** (`frontend/src/shared/config/env.ts` holds the one list of them), so one
image runs in any environment.

| Variable | Required? | Note |
|---|---|---|
| `VITE_OIDC_AUTHORITY` | **yes** | Server refuses to boot without it, and names it in the log. |
| `VITE_OIDC_CLIENT_ID` | **yes** | |
| `VITE_OIDC_REDIRECT_URI` | **yes** | This environment's `/callback` URL. |
| `VITE_OIDC_SCOPE` | **yes** | e.g. `openid profile offline_access`. |
| `VITE_GRAPHQL_API_URL` | **yes** | |
| `VITE_OIDC_API_RESOURCE`, `VITE_BASE_URL`, `VITE_SENTRY_DSN`, `VITE_APP_VERSION` | no | Empty is a valid, working value. |

Every variable in that table is delivered to the browser. Never put a secret in one.

Four values are settings of the **build** instead, and belong in the build
environment: `VITE_MOCK_AUTH` (fake logins must not be switchable on a running
container) and `VITE_SENTRY_ORG` / `VITE_SENTRY_PROJECT` /
`VITE_SENTRY_AUTH_TOKEN` (they upload source maps while building; the token is a
real secret and must never reach a container).

## Per-copy variables (when you run more than one)

These are not backend↔frontend pairs — they are values that must match the shape
of the deployment. The full walkthrough is in [DEPLOY.md](./DEPLOY.md#running-more-than-one-copy).

| Variable | Side | Rule |
|---|---|---|
| `DB_POOL_MAX` (default 10) | backend | Pool size of **one** copy. Sizing rule: replicas x `DB_POOL_MAX` must stay below the Postgres `max_connections` limit (default 100), leaving room for migrations, `psql` sessions and the dashboards. Over the limit, copies start failing readiness while each looks healthy on its own. |
| `TRUSTED_PROXY_HOPS` (default 1) | backend | The number of reverse proxies actually in front of the app. The client address — the rate limiter's key — is taken that many entries from the **right** of `X-Forwarded-For`. Too high hands the caller its own key; too low puts every client in one bucket. `0` = no proxy, both forwarding headers ignored. |
| `S3_ENDPOINT` / `S3_PUBLIC_BASE_URL` | backend | Two different addresses of the same storage: the first as the **app** sees it from inside the network, the second as the **browser** resolves it from outside, bucket name included. A file's URL is the second value plus `/` plus the object key. |
| `PROXY_NETWORK` (default `dokploy-network`) | both | Name of the existing external Docker network the reverse proxy runs on. Both prod composes join it instead of publishing a host port. |

## Bootstrap order (why it matters)

Frontend GraphQL codegen (`npm run gen`) reads the **live** schema from `VITE_GRAPHQL_API_URL`,
so it needs two things: that **variable present in its environment**, and the backend
**reachable** at that address. The `.env` file is only the usual way to supply the variable
(`npm run gen` loads it) — `VITE_GRAPHQL_API_URL=… npm run gen` works just as well. With the
variable unset, the address collapses to the string `undefined` and codegen fails with
`Failed to load schema from undefined` — a message that never says "variable", so check the
variable before you suspect the backend. Correct order for a fresh project:

1. Configure both sides — export the variables, or copy each `.env.example` to `.env`
   (`.env.example` is the documented list of every variable, either way).
2. `scripts/doctor.sh` — confirm the pairs above agree.
3. Start the backend (`cd backend && task start:dev` — brings up Docker db+redis, runs goose
   migrations automatically at startup, then serves with hot-reload).
4. Verify GraphQL: `curl -s -X POST localhost:<BE_PORT>/graphql -H 'content-type: application/json' -d '{"query":"{ __typename }"}'`.
5. `cd frontend && npm run gen` (now the schema is reachable).

## OIDC / Logto note

The two `.env.example` defaults intentionally **diverge**, so the must-match pairs above only
hold once you pick a mode:

- **Backend (liteend-go) ships `OIDC_MOCK_ENABLED=true`** — local dev bypasses OIDC entirely
  (hardcoded user with ADMIN+USER roles; mock header `x-mock-sub: <id>`). In mock mode the
  backend's `OIDC_ISSUER`/`OIDC_AUDIENCE` are unused, so `doctor.sh`'s OIDC checks against the
  frontend will report a mismatch you can ignore.
- **Frontend `.env.example` ships the shared public dev Logto tenant** (`https://auth.uxna.me/oidc`).
  These are public identifiers, not secrets.

To run **real OIDC** end-to-end: set backend `OIDC_MOCK_ENABLED=false` and make the backend's
`OIDC_ISSUER`/`OIDC_JWKS_URI`/`OIDC_AUDIENCE` match the frontend's
`VITE_OIDC_AUTHORITY`/`VITE_OIDC_API_RESOURCE` (the pairs above) — point both at the same Logto
tenant + API resource. For a real project, register your own tenant and swap all of them.
