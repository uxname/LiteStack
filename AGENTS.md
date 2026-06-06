# AGENTS.md — LiteStack (meta-repo)

LiteStack is a **meta-repository** that bundles a backend and a frontend template
as git submodules, plus shared documentation for AI agents doing full-stack work.
This repo holds **only coordination material** (this file, `docs/`, `tasks/`,
`ideas/`). It does **not** run, build, or duplicate the sub-projects.

## 🔴 START HERE (mandatory first step)

Before touching any code, read the `AGENTS.md` of the relevant sub-project(s):

- **`liteend/AGENTS.md`** — backend rules, commands, conventions
- **`litefront/AGENTS.md`** — frontend rules, commands, conventions

Those files are the source of truth for each side. This root file only covers what
spans **both** projects. When a sub-project's `AGENTS.md` and this file disagree on
something inside that sub-project, the sub-project wins.

## Project map

| Submodule | Role | Stack | Dev port | Read this |
|---|---|---|---|---|
| `liteend/` | Backend / API | NestJS · Prisma · PostgreSQL · Redis/Bull · Apollo GraphQL · OIDC | `4000` (`/graphql`) | `liteend/AGENTS.md` |
| `litefront/` | Frontend / SPA | Vite · React 19 · TanStack Router · URQL · Zustand · Tailwind v4 · daisyUI · OIDC | `3000` | `litefront/AGENTS.md` |

Upstream templates: `liteend` → `uxname/liteend`, `litefront` → `uxname/litefront`.

## Which project for which task

- **API, data, DB schema/migrations, business logic, background jobs, GraphQL types** → `liteend`
- **UI, routing, client state, styling, forms, GraphQL queries/mutations consumption** → `litefront`
- **Full-stack feature** → both, **start with `liteend`** (define the schema/resolver first),
  then regenerate and consume types in `litefront`. See `docs/graphql-contract.md`.

## Git topology (critical — do not get this wrong)

Each submodule is a **separate git repository**:

- Code changes inside `liteend/` are committed **in the `liteend` repo** (its own history/upstream).
- Code changes inside `litefront/` are committed **in the `litefront` repo**.
- The **LiteStack meta-repo** commits only: (a) updated submodule pointers after you
  commit in a submodule, and (b) its own meta files (`docs/`, `tasks/`, `ideas/`, this file).

Typical flow when you change a submodule:
1. `cd liteend` (or `litefront`), make changes, commit there.
2. `cd ..` (meta-repo root) — `git add liteend` records the new pointer, then commit the meta-repo.

Never commit sub-project source changes directly as meta-repo blobs; always commit inside the submodule.

## Back ↔ front connection

- **GraphQL contract** — the frontend generates its TypeScript types from the backend's
  live GraphQL schema. Backend must be running for `npm run gen` on the frontend.
  Full flow: `docs/graphql-contract.md`.
- **Auth** — both share one external OIDC provider (Logto). The token `aud` must match
  between front and back. Details: `docs/auth-oidc.md`.
- **Architecture & ports** — `docs/architecture.md`, `docs/environment.md`.

## Shared conventions

- Package manager: **npm** in both.
- Quality gate: run **`npm run check`** inside each sub-project before declaring work done.
  Never run `lint` + `ts:check` separately — that skips knip/steiger/biome-fix and breaks
  the lefthook pre-commit hook. (Rule stated in both sub-AGENTS.md.)
- Both use **Biome**, but configs **differ**: `liteend` uses **single** quotes, `litefront`
  uses **double** quotes. Never copy formatting config or code style across the boundary —
  let each project's Biome decide.
- Run the projects **separately**, each per its own `AGENTS.md` (no root orchestration here).
  Backend needs `docker-compose up -d db redis` first; frontend needs `.env` from `.env.example`.

## Where things live

- `docs/` — cross-project docs: `architecture.md`, `graphql-contract.md`, `auth-oidc.md`, `environment.md`, `glossary.md`
- `tasks/` — full-stack task specs; `tasks/TEMPLATE.md` is the checklist to copy
- `ideas/` — free-form backlog of ideas (one file per idea)
- `scripts/setup.sh` — one-time bootstrap (init submodules + `npm install` in both)
