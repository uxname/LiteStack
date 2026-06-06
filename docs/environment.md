# Environment & ports

Local development setup, port map, and key env vars across both sub-projects.

## Port map

| Service | Port | Project | Notes |
|---|---|---|---|
| Frontend (Vite dev) | `3000` | litefront | `PORT` / `VITE_BASE_URL` |
| Backend (NestJS/Fastify) | `4000` | liteend | `PORT`; GraphQL at `/graphql` |
| PostgreSQL | `5432` | liteend | `DATABASE_PORT` |
| Redis | `6379` | liteend | `REDIS_PORT` (Bull jobs) |
| DB admin (pgAdmin) | `5100` | liteend | `DB_ADMIN_PORT` |
| Redis admin | `5200` | liteend | `REDIS_ADMIN_PORT` |
| Prisma Studio | `5555` | liteend | `npm run db:studio` |

The backend's `CORS_ORIGIN` must include the frontend origin (`http://localhost:3000`) —
already set in `liteend/.env.example`.

## Backend (`liteend`) setup

```bash
cd liteend
cp .env.example .env            # then fill secrets / OIDC values
docker-compose up -d db redis   # start infra
npm install
npm run db:migrations:apply     # apply migrations + generate Prisma client
npm run start:dev               # http://localhost:4000  (GraphQL: /graphql)
```

Key env vars: `PORT`, `DATABASE_*`, `REDIS_*`, `CORS_ORIGIN`, `OIDC_AUDIENCE` + issuer/JWKS.
See `liteend/.env.example` for the full list.

## Frontend (`litefront`) setup

```bash
cd litefront
cp .env.example .env            # then fill OIDC + GraphQL URL
npm install
# backend must be running for type generation:
npm run gen                     # GraphQL codegen from live schema
npm run start:dev               # http://localhost:3000
```

Key env vars: `PORT`, `VITE_BASE_URL`, `VITE_GRAPHQL_API_URL`, `VITE_OIDC_*`,
`VITE_OIDC_API_RESOURCE`, `VITE_MOCK_AUTH`. See `litefront/.env.example`.

## Cross-project value contracts

These values must agree across the two `.env` files:

| Frontend | Backend | Meaning |
|---|---|---|
| `VITE_GRAPHQL_API_URL` = `http://localhost:4000/graphql` | `PORT` = `4000` | where the SPA reaches the API |
| `VITE_OIDC_API_RESOURCE` = `http://localhost:4000` | `OIDC_AUDIENCE` = `http://localhost:4000` | token `aud` match |
| `VITE_BASE_URL` = `http://localhost:3000` | `CORS_ORIGIN` includes `http://localhost:3000` | CORS allow |

> Ports/vars reflect the template `.env.example` files at submodule pin time. If a
> sub-project changes them, update this table.
