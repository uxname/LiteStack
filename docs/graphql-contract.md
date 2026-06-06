# GraphQL contract (back ↔ front type sync)

The frontend does **not** hand-write GraphQL types. It generates them from the backend's
**live** GraphQL schema using GraphQL Code Generator. This document describes the manual
flow — there is no automation layer in LiteStack; you run the steps yourself.

## The flow

1. **Change the schema in `liteend`.**
   Add/modify a resolver, entity, or input. The backend builds its GraphQL schema from
   code (NestJS code-first / Apollo). Follow `liteend/AGENTS.md` (thin resolvers, fat
   services, `nestjs-zod` validation).

2. **Run the backend so the schema is live.**
   ```bash
   cd liteend
   docker-compose up -d db redis      # infra
   npm run start:dev                  # GraphQL served at http://localhost:4000/graphql
   ```

3. **Regenerate types on the frontend.**
   ```bash
   cd litefront
   npm run gen                        # GraphQL Code Generator
   ```
   - `gen` reads the frontend's operation documents in `src/graphql/**/*.graphql`.
   - It introspects the **live** backend schema via `VITE_GRAPHQL_API_URL`
     (defaults to `http://localhost:4000/graphql` in `.env.example`).
   - Output lands in `src/generated/graphql.tsx` (generated — never edit by hand).
   - ⚠️ If the backend is **not running**, `gen` fails — it needs the live endpoint.

4. **Consume the generated types in the UI.**
   Import hooks/types from `@generated/*` and build the feature in `litefront`
   (Feature-Sliced Design, URQL).

## Direction rule

For a full-stack feature, always go **backend first**: define the schema/resolver, run
the backend, then `npm run gen`, then build the UI. Writing frontend operations against a
schema that doesn't exist yet means `gen` can't validate them.

## Where to look

- Frontend operations: `litefront/src/graphql/**/*.graphql`
- Generated output: `litefront/src/generated/graphql.tsx`
- codegen config + `gen` script: `litefront` (`codegen` config file + `package.json`)
- Backend GraphQL endpoint: `http://localhost:4000/graphql`

> Verify the exact codegen config path and schema source in `litefront` if they change;
> this doc reflects the template at submodule pin time.
