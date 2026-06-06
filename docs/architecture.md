# Architecture

How the two sub-projects fit together at runtime.

```
                         ┌─────────────────────────┐
                         │   OIDC provider (Logto)  │  ← external, shared
                         │   issues access tokens   │
                         └────────────┬────────────┘
                                      │ login / token (aud = http://localhost:4000)
                                      │
   ┌──────────────────────┐  GraphQL over HTTP   ┌──────────────────────────┐
   │  litefront (SPA)      │  ───────────────────▶│  liteend (API)           │
   │  Vite · React 19      │  :4000/graphql       │  NestJS · Apollo         │
   │  URQL client          │◀─────────────────────│  Fastify                 │
   │  http://localhost:3000│   Bearer access token │  http://localhost:4000   │
   └──────────────────────┘                       └────────────┬─────────────┘
                                                                │
                                            ┌───────────────────┼───────────────────┐
                                            │                   │                   │
                                    ┌───────▼──────┐   ┌─────────▼────────┐  ┌───────▼───────┐
                                    │ PostgreSQL   │   │ Redis + Bull     │  │ Prisma ORM    │
                                    │ :5432        │   │ :6379 (jobs)     │  │ (schema/migr.) │
                                    └──────────────┘   └──────────────────┘  └───────────────┘
```

## Request path

1. Browser loads the SPA from `litefront` (Vite dev server on `:3000`).
2. User authenticates against the external **OIDC provider (Logto)**; the SPA receives an
   access token whose `aud` is registered as `http://localhost:4000`.
3. The SPA's URQL client sends GraphQL operations to `liteend` at `:4000/graphql`,
   attaching the access token as a `Bearer` header.
4. `liteend` validates the token (issuer/JWKS/audience), runs resolvers → services →
   Prisma → PostgreSQL, and uses Redis/Bull for caching and background jobs.

## Build-time contract

The SPA's TypeScript GraphQL types are **generated** from `liteend`'s live schema, not
hand-written. The backend must be running for the frontend's `npm run gen` to succeed.
See [`graphql-contract.md`](./graphql-contract.md).

## Notes

- The two projects are deployed and run independently; nothing in LiteStack orchestrates them.
- CORS on the backend allows the SPA origin (`http://localhost:3000`) — see `liteend/.env.example` (`CORS_ORIGIN`).
- Full port map and env vars: [`environment.md`](./environment.md).
