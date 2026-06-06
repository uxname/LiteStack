# Glossary

Shared terms used across both sub-projects, so agents read them the same way.

| Term | Meaning |
|---|---|
| **LiteStack** | This meta-repo: the two submodules + shared docs. Runs nothing itself. |
| **liteend** | The backend submodule (NestJS API). Upstream: `uxname/liteend`. |
| **litefront** | The frontend submodule (Vite/React SPA). Upstream: `uxname/litefront`. |
| **Submodule** | A nested git repo pinned to a specific commit. Has its own history/remote. |
| **Submodule pointer** | The commit SHA the meta-repo records for a submodule. Committed in the meta-repo. |
| **GraphQL contract** | The schema agreement between back and front; front generates types from it. |
| **codegen / `npm run gen`** | Frontend GraphQL Code Generator; reads live backend schema → `src/generated/graphql.tsx`. |
| **Quality gate / `npm run check`** | The full lint+type+dead-code check each project runs before commit (via lefthook). |
| **OIDC / Logto** | The external identity provider both projects authenticate against. |
| **`aud` (audience)** | Token claim that must match backend `OIDC_AUDIENCE` ↔ frontend `VITE_OIDC_API_RESOURCE`. |
| **FSD (Feature-Sliced Design)** | The frontend's architecture (layers: shared/entities/features/widgets/pages/app); enforced by Steiger. |
| **Resolver / Service** | Backend split: thin resolvers (GraphQL I/O) over fat services (business logic + Prisma). |
| **Prisma** | The backend ORM; owns DB schema and migrations. |
| **Bull / Redis** | Backend background job queue. |
| **URQL** | The frontend GraphQL client. |
| **Biome** | Formatter/linter used in both — but with **different** configs (single vs double quotes). |
