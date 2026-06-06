# Auth — shared OIDC (Logto)

Both sub-projects authenticate against **one external OIDC provider (Logto)**. LiteStack
does not host an identity provider; you point both projects at the same Logto instance.

## How it works

1. **Frontend** (`litefront`) uses `react-oidc-context` to run the OAuth 2.0 / OIDC
   Authorization Code flow against Logto. After login it holds an **access token**.
2. The access token is requested for a specific **API resource** so its `aud` claim
   matches what the backend expects. This is the key cross-project contract:

   | Side | Variable | Value (template default) |
   |---|---|---|
   | frontend | `VITE_OIDC_API_RESOURCE` | `http://localhost:4000` |
   | backend | `OIDC_AUDIENCE` | `http://localhost:4000` |

   These **must be equal**, otherwise the backend rejects the token (`aud` mismatch).

3. **Frontend** attaches the access token as a `Bearer` header on GraphQL requests.
4. **Backend** (`liteend`) validates the token: issuer (`ISSUER`), signature (`JWKS`),
   and audience (`OIDC_AUDIENCE`). Valid → request proceeds to resolvers.

## Required env vars

**Frontend** (`litefront/.env`):
- `VITE_OIDC_AUTHORITY` — Logto OIDC issuer URL
- `VITE_OIDC_CLIENT_ID`
- `VITE_OIDC_REDIRECT_URI` — e.g. `http://localhost:3000/callback`
- `VITE_OIDC_SCOPE` — e.g. `openid profile offline_access`
- `VITE_OIDC_API_RESOURCE` — must match backend `OIDC_AUDIENCE`
- `VITE_GRAPHQL_API_URL` — `http://localhost:4000/graphql`

**Backend** (`liteend/.env`):
- `OIDC_AUDIENCE` — the Logto API resource identifier (must match frontend resource)
- issuer / JWKS settings (see `liteend/.env.example` OIDC section)

## Setup checklist

- [ ] Register the SPA client in Logto Console (redirect URI = frontend callback).
- [ ] Register the API resource in Logto Console (indicator = `http://localhost:4000`).
- [ ] Set the matching values in both `.env` files.
- [ ] Frontend dev/mock: `VITE_MOCK_AUTH` can bypass real auth during local UI work.

> Exact issuer/JWKS variable names live in `liteend/.env.example`; consult it when wiring
> a real Logto instance.
