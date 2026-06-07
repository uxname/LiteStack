# Env contract — backend ↔ frontend

The two submodules are wired together through environment variables that **must agree**.
A mismatch fails silently at runtime (401s, CORS blocks, broken GraphQL codegen) rather than
at startup. `scripts/doctor.sh` checks these automatically — run it after editing any `.env`.

Source of truth: `backend/.env` and `frontend/.env` (each falls back to its `.env.example`).

## Must-match pairs

| Concern | Backend var | Frontend var | Rule |
|---|---|---|---|
| **OIDC audience** | `OIDC_AUDIENCE` | `VITE_OIDC_API_RESOURCE` | **Equal.** This is the `aud` claim of the access token the SPA sends. Mismatch → backend rejects every request (401). |
| **OIDC tenant** | `OIDC_ISSUER` | `VITE_OIDC_AUTHORITY` | **Equal.** Both point at the same Logto tenant. (`OIDC_JWKS_URI` = `OIDC_ISSUER` + `/jwks`.) |
| **CORS** | `CORS_ORIGIN` | `VITE_BASE_URL` | `CORS_ORIGIN` (comma-separated) **must include** the frontend origin. Mismatch → browser blocks `/graphql` + `/upload`. |
| **GraphQL endpoint** | `PORT` | `VITE_GRAPHQL_API_URL` | The frontend URL's port **must equal** the backend `PORT`, path `/graphql`. Mismatch → data fetching + codegen fail. |
| **Port collision** | `PORT` (4000) | `PORT` (3000) | Backend and frontend dev ports **must differ** (and not collide with admin ports 5100/5200/5432/6379). |

## Bootstrap order (why it matters)

Frontend GraphQL codegen (`npm run gen`) reads the **live** schema from `VITE_GRAPHQL_API_URL`.
The backend must be running and reachable first, or codegen is skipped and generated types go
stale. Correct order for a fresh project:

1. Configure `backend/.env` and `frontend/.env` (copy from `.env.example`).
2. `scripts/doctor.sh` — confirm the pairs above agree.
3. Start the backend (`cd backend && docker compose up -d db redis && npm run db:migrations:apply && npm run start:dev`).
4. Verify GraphQL: `curl -s -X POST localhost:<BE_PORT>/graphql -H 'content-type: application/json' -d '{"query":"{ __typename }"}'`.
5. `cd frontend && npm run gen` (now the schema is reachable).

## OIDC / Logto note

`.env.example` ships a **shared public dev Logto tenant** (`https://auth.uxna.me/oidc`) so the
stack authenticates out of the box. These are public identifiers, not secrets. For a real
project, register your own Logto tenant + API resource and swap `OIDC_ISSUER` / `OIDC_JWKS_URI`
(backend) and `VITE_OIDC_AUTHORITY` / `VITE_OIDC_CLIENT_ID` / `VITE_OIDC_API_RESOURCE` (frontend).
To bypass OIDC entirely in local dev, set backend `OIDC_MOCK_ENABLED=true`.
