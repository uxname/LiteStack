# Env contract — backend ↔ frontend

The two submodules are wired together through environment variables that **must agree**.
Most mismatches surface at runtime (401s, CORS blocks, broken GraphQL codegen), but two cases
now **fail fast at startup**: an empty `CORS_ORIGIN` in production (backend refuses to boot)
and any missing required `VITE_*` var (frontend throws on its first render); the prod
compose files fail the same way at deploy time, naming the missing variable — no `.env`
required, exported environment variables work. `scripts/doctor.sh`
checks these pairs automatically — run it after editing any `.env`.

Source of truth: `backend/.env` and `frontend/.env`. A missing `.env` makes
`scripts/doctor.sh` fall back to that side's `.env.example` for the diagnostics, but the
missing file itself is reported as a failure — the apps read only `.env`.

## Must-match pairs

| Concern | Backend var | Frontend var | Rule | If mismatched |
|---|---|---|---|---|
| **OIDC audience** | `OIDC_AUDIENCE` | `VITE_OIDC_API_RESOURCE` | **Equal.** This is the `aud` claim of the access token the SPA sends. Mismatch → backend rejects every request (401). | Login "succeeds", then **401 on every API call**. |
| **OIDC tenant** | `OIDC_ISSUER` | `VITE_OIDC_AUTHORITY` | **Equal.** Both point at the same Logto tenant. (`OIDC_JWKS_URI` = `OIDC_ISSUER` + `/jwks`.) | Tokens issued by the wrong issuer → same wall of 401s; a wrong redirect URI instead fails inside Logto with `redirect_uri_mismatch`. |
| **CORS + WebSockets** | `CORS_ORIGIN` | `VITE_BASE_URL` | `CORS_ORIGIN` (comma-separated, entries trimmed on load) **must include** the frontend origin. It gates **both** HTTP CORS and the GraphQL **WebSocket handshake**, so a mismatch blocks `/graphql` + `/upload` in the browser **and** silently refuses subscriptions from that origin (403 on upgrade). An empty list allows any origin for **HTTP** (refused in production, but *not* on other environments — set it explicitly on staging); the **WebSocket** handshake is never allow-all — with an empty list only same-origin and Origin-less (non-browser) clients connect. | Browser blocks `/graphql` + `/upload` (CORS errors in console); subscriptions die with **403** on upgrade. The silent trap: outside production an empty backend list allows all origins, so a wrong-environment stack looks healthy while writing real users into the WRONG database — tag images per environment (`docs/DEPLOY.md`). |
| **GraphQL endpoint** | `PORT` | `VITE_GRAPHQL_API_URL` | The frontend URL's port **must equal** the backend `PORT`, path `/graphql`. Mismatch → data fetching + codegen fail. | Every query/mutation **and codegen fail** with network errors against the wrong port/path. Rotating the backend's public domain also invalidates every already-built frontend image (the old origin is baked into their bundle) — rebuild and redeploy the frontend as part of the rotation. |
| **Port collision** | `PORT` (4000) | `PORT` (3000) | Backend and frontend ports **must differ** (and not collide with admin ports 5100/5200/5300/5432/6379). Frontend `PORT` is the dev-server port locally; under Docker it only picks the **host** side of the mapping — the container always listens on 3000. Under `docker-compose.prod.yml` the backend's `PORT` works the same way (the container always listens on 4000). | Host port mappings clash or one app steals the other's traffic. |

## Bootstrap order (why it matters)

Frontend GraphQL codegen (`npm run gen`) reads the **live** schema from `VITE_GRAPHQL_API_URL`.
The backend must be running and reachable first, or codegen is skipped and generated types go
stale. Correct order for a fresh project:

1. Configure `backend/.env` and `frontend/.env` (copy from `.env.example`).
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
