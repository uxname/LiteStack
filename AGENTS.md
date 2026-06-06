# AGENTS.md — LiteStack

LiteStack is a **full-stack boilerplate**, in the same spirit as LiteEnd and LiteFront.
It is not a standalone product — it is a starting point. It bundles a backend
(`liteend`) and a frontend (`litefront`) as git submodules and adds this thin
coordination layer so an AI agent can work across both sides correctly.

This repo intentionally carries **no project content** (no docs/ideas/tasks scaffolding) —
the team building on top of LiteStack manages that in its own tools (task manager,
bmad-method, etc.).

## 🔴 START HERE (mandatory first step)

Before touching any code, read the `AGENTS.md` of the sub-project(s) you'll change:

- **`liteend/AGENTS.md`** — backend rules, commands, conventions
- **`litefront/AGENTS.md`** — frontend rules, commands, conventions

Those are the source of truth for each side. This root file only covers what spans
**both** projects + the git/commit model. On any conflict inside a sub-project, the
sub-project's `AGENTS.md` wins.

## 🟠 Operating mode — decide this BEFORE committing

LiteStack runs in one of two modes. **They differ only in where you commit/push.**
Detect the mode from the git remotes, then follow the matching rule.

### How to detect

```bash
# meta-repo remote (may be unset if not pushed yet)
git remote get-url origin 2>/dev/null
# submodule remotes
git config -f .gitmodules submodule.liteend.url
git config -f .gitmodules submodule.litefront.url
```

Canonical upstreams of the boilerplate:
- `liteend`  → `https://github.com/uxname/liteend`
- `litefront` → `https://github.com/uxname/litefront`

**If the submodule URLs point at `uxname/liteend` and `uxname/litefront`
→ TEMPLATE mode.** Otherwise **→ DERIVED mode.**

### TEMPLATE mode — improving the boilerplate itself

You are developing the LiteStack/LiteEnd/LiteFront trio as templates.
A code change may touch all three:

1. Change code inside `liteend/` and/or `litefront/` → commit **and push** in each
   submodule to its canonical upstream (`uxname/*`). Requires upstream write access.
2. In the meta-repo: `git add liteend litefront` to record the new submodule pointers,
   then commit (and push, if the LiteStack template repo has a remote).

Use this mode only when the intent is to evolve the boilerplate, not to build a product.

### DERIVED mode — building a real project on top of LiteStack

The submodules (and the meta-repo) point at **your own** repositories (forks/new repos),
not at `uxname/*`. All work goes into your project:

1. Change code inside `liteend/` and/or `litefront/` → commit **and push** in each
   submodule to **its own remote** (your backend/frontend repo).
2. In the meta-repo: `git add liteend litefront`, commit, and push to **your** meta repo.

Never push a derived project's changes to the `uxname/*` upstreams.

> If you forked but the submodules still point at `uxname/*`, you are mis-configured —
> re-point them first (see **Deriving a new project** below), or the mode detection and
> push targets will be wrong.

## Git topology (applies to both modes)

Each submodule is a **separate git repository** with its own history and remote(s):

- Code changes inside `liteend/` are committed **in the `liteend` repo**.
- Code changes inside `litefront/` are committed **in the `litefront` repo**.
- The meta-repo commits only: (a) updated submodule pointers, (b) its own files
  (this `AGENTS.md`, `README.md`, `scripts/`).

Flow per change: `cd liteend` → edit → commit (+push) → `cd ..` → `git add liteend` →
commit (+push) the meta-repo.

## Project map

| Submodule | Role | Stack | Dev port | Read |
|---|---|---|---|---|
| `liteend/` | Backend / API | NestJS · Prisma · PostgreSQL · Redis/Bull · Apollo GraphQL · OIDC | `4000` (`/graphql`) | `liteend/AGENTS.md` |
| `litefront/` | Frontend / SPA | Vite · React 19 · TanStack Router · URQL · Zustand · Tailwind v4 · daisyUI · OIDC | `3000` | `litefront/AGENTS.md` |

Infra ports (backend): PostgreSQL `5432`, Redis `6379`, pgAdmin `5100`, Redis admin
`5200`, Prisma Studio `5555`.

## Which project for which task

- **API, data, DB schema/migrations, business logic, jobs, GraphQL types** → `liteend`
- **UI, routing, client state, styling, GraphQL query/mutation use** → `litefront`
- **Full-stack feature** → both, **start with `liteend`** (define schema/resolver first),
  then regenerate and consume types in `litefront`.

## Back ↔ front seams (the cross-project rules)

- **GraphQL types are generated, not hand-written.** The frontend runs `npm run gen`
  (GraphQL Code Generator) against the backend's **live** schema at
  `VITE_GRAPHQL_API_URL` (default `http://localhost:4000/graphql`). **The backend must
  be running** or `gen` fails. So for a full-stack change: edit backend schema → start
  backend → `npm run gen` in `litefront` → build UI from `@generated/*`.
- **Auth is one shared OIDC provider (Logto).** The token audience must match across
  sides: frontend `VITE_OIDC_API_RESOURCE` == backend `OIDC_AUDIENCE`
  (default `http://localhost:4000`). Mismatch → backend rejects the token.
- **CORS** — backend `CORS_ORIGIN` must include the SPA origin (`http://localhost:3000`).

## Shared conventions

- Package manager: **npm** in both.
- Quality gate: run **`npm run check`** inside each sub-project before declaring done.
  Never run `lint` + `ts:check` separately — that skips knip/steiger/biome-fix and breaks
  the lefthook pre-commit hook.
- Both use **Biome** but with **different** configs: `liteend` = single quotes,
  `litefront` = double quotes. Never copy formatting/style config across the boundary.
- Run the projects **separately**, each per its own `AGENTS.md`. There is no root
  orchestration. Backend needs `docker-compose up -d db redis` + `.env`; frontend needs `.env`.

## Deriving a new project from LiteStack

To start a real product (DERIVED mode):

1. Create your own repos for the meta, backend, and frontend (fork `uxname/*` or
   `gh repo create`, keeping `uxname/*` as an `upstream` remote to pull template updates).
2. Re-point the submodules to your repos:
   ```bash
   git config -f .gitmodules submodule.liteend.url   <your-backend-repo-url>
   git config -f .gitmodules submodule.litefront.url <your-frontend-repo-url>
   git submodule sync
   ```
3. Set the meta-repo `origin` to your meta repo and push.
4. From here, all commits/pushes target your repos (DERIVED mode rules above).
