# AGENTS.md — LiteStack

## What is LiteStack (read this first)

LiteStack is a **full-stack boilerplate** — a starting point, in the same spirit as
LiteEnd and LiteFront. It is **not a runnable product**. It bundles two real projects as
git submodules and adds a thin coordination layer on top:

- **`liteend/`** — the **backend** project (its own repo). All server code lives here.
- **`litefront/`** — the **frontend** project (its own repo). All browser code lives here.
- **LiteStack** (this repo, the "meta-project") — owns **no application code**. It only
  coordinates: it tells the agent which project to touch, how the two connect, and how to
  commit across them.

### What a "meta-project" means — where does each change go?

Think of three boxes. Put each change in the right box:

| You are changing… | Go to | Why |
|---|---|---|
| API, database, business logic, background jobs, server-side GraphQL | **`liteend/`** | Backend owns all server behavior |
| UI, pages, routing, client state, styling, GraphQL the browser sends | **`litefront/`** | Frontend owns everything in the browser |
| How the two fit together, this guide, cross-project skills, submodule pointers | **LiteStack root** | The meta-project only coordinates |

Rule of thumb: **never put application code in the meta-project.** If you're writing a
resolver, a component, a migration — you're in the wrong folder; go into a submodule.

## How to talk to the user

- **Use the user's language.** Reply in whatever language the user writes to you in
  (Russian → Russian, English → English). Match them.
- **Explain simply, like to a junior developer.** Short sentences. Define jargon the first
  time you use it. Prefer concrete steps and examples over abstract description. When you
  make a decision, say what you did and why in one plain line.

## 🔴 START HERE (mandatory first step)

Before touching any code, read the `AGENTS.md` of the sub-project(s) you'll change:

- **`liteend/AGENTS.md`** — backend rules, commands, conventions
- **`litefront/AGENTS.md`** — frontend rules, commands, conventions

Those are the source of truth for each side. This root file only covers what spans
**both** projects. On any conflict inside a sub-project, the sub-project's `AGENTS.md` wins.

## 🟠 Operating mode — decide this BEFORE committing

LiteStack is used in one of two modes. **They differ only in where you commit and push.**
Detect the mode from the git remotes, then follow the matching rule. (This is git-host
agnostic — your repos can live on any host, not only GitHub.)

### How to detect

```bash
# submodule remotes
git config -f .gitmodules submodule.liteend.url
git config -f .gitmodules submodule.litefront.url
```

The **canonical boilerplate upstreams** are `uxname/liteend` and `uxname/litefront`
(currently hosted at `github.com/uxname/*`).

- **Submodule URLs still point at the canonical `uxname/*` upstreams → TEMPLATE mode.**
- **Submodule URLs point anywhere else (your own repos) → DERIVED mode.**

### TEMPLATE mode — improving the boilerplate itself

You are evolving the LiteStack / LiteEnd / LiteFront templates. A change may touch all three:

1. Change code inside `liteend/` and/or `litefront/` → commit **and push** in each
   submodule to its canonical upstream. (Needs write access to those upstreams.)
2. In the meta-repo: `git add liteend litefront` to record new submodule pointers, then
   commit (and push if the meta-repo has a remote).

Use this mode **only** when the goal is to improve the boilerplate, not to build a product.

### DERIVED mode — building a real product on top of LiteStack

The submodules (and the meta-repo) point at **your own** repositories. Everything goes
into your project:

1. Change code inside `liteend/` and/or `litefront/` → commit **and push** in each
   submodule to **its own remote** (your backend/frontend repo).
2. In the meta-repo: `git add liteend litefront`, commit, push to **your** meta repo.

Never push a derived project's changes to the `uxname/*` upstreams.

> A derived project is a **snapshot fork**. We do **not** keep it in sync with the
> upstream templates: LiteEnd and LiteFront change often, sometimes with breaking changes,
> so chasing upstream is more pain than value. Take the snapshot and own it.

## Git topology (applies to both modes)

Each submodule is a **separate git repository** with its own history and remote(s):

- Code changes inside `liteend/` are committed **in the `liteend` repo**.
- Code changes inside `litefront/` are committed **in the `litefront` repo**.
- The meta-repo commits only: (a) updated submodule pointers, (b) its own files
  (`AGENTS.md`, `README.md`, `.agents/`).

Flow per change: `cd liteend` → edit → commit (+push) → `cd ..` → `git add liteend` →
commit (+push) the meta-repo. (The `commit` meta-skill automates this — see below.)

## Project map

| Submodule | Role | Stack | Dev port | Read |
|---|---|---|---|---|
| `liteend/` | Backend / API | NestJS · Prisma · PostgreSQL · Redis/BullMQ · **Mercurius** GraphQL (code-first) · OIDC | `4000` (`/graphql`, IDE Altair at `/altair`) | `liteend/AGENTS.md` |
| `litefront/` | Frontend / SPA | Vite · React 19 · TanStack Router · URQL · Zustand · Tailwind v4 · daisyUI · OIDC | `3000` | `litefront/AGENTS.md` |

Infra ports (backend): PostgreSQL `5432`, Redis `6379`, pgAdmin `5100`, Redis admin
`5200`, Prisma Studio `5555`.

## Which project for which task

- **API, data, DB schema/migrations, business logic, jobs, server GraphQL types** → `liteend`
- **UI, routing, client state, styling, GraphQL operations the browser sends** → `litefront`
- **Full-stack feature** → both, **start with `liteend`** (define schema/resolver first),
  then regenerate and consume types in `litefront`. Use the `full-stack-feature` skill.

## Back ↔ front seams (cross-project rules)

- **GraphQL types are generated, not hand-written (on the frontend).** The frontend runs
  `npm run gen` against the backend's **live** schema at `VITE_GRAPHQL_API_URL` (default
  `http://localhost:4000/graphql`). **The backend must be running** or `gen` fails. So for
  a full-stack change: edit backend schema → start backend → `npm run gen` in `litefront`
  → build UI from `@generated/*`. (Note: the backend itself is code-first Mercurius; its
  GraphQL types are hand-written and do not auto-sync with Prisma.)
- **Auth is one shared OIDC provider (Logto).** Token audience must match across sides:
  frontend `VITE_OIDC_API_RESOURCE` == backend `OIDC_AUDIENCE` (default
  `http://localhost:4000`). Mismatch → backend rejects the token.
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

## Skills — catalog and how to use them

**Where skills are discovered.** Both opencode and Claude Code auto-load skills from
`.claude/skills/` at the project root. opencode additionally walks **up** to the current
git-worktree root, so when your cwd is inside a submodule it also auto-loads that
submodule's own `<project>/.agents/skills/`. Claude Code does **not** read `.agents/skills/`
at all. Neither tool recurses **down** into submodules from the meta root.

**How LiteStack bridges this.** The real skill workflows live in each sub-project (next to
the code they run — that is the single source of truth, no duplicated logic). The meta-repo
adds, in `.claude/skills/`, a thin **wrapper** for each sub-project skill, namespaced
`be-*` (backend → `liteend`) and `fe-*` (frontend → `litefront`). A wrapper is ~5 lines: it
tells the agent to `cd` into the submodule and follow the real `SKILL.md` there. Result:
open the LiteStack root in either tool and **every** skill is discoverable, collision-free
(`be-commit`/`fe-commit`/`commit` are distinct), with zero workflow drift.

> Invoke `be-<name>` / `fe-<name>` from the meta root; the wrapper hands off to the real
> skill inside the submodule. If your cwd is already inside a submodule (opencode), you can
> use the un-prefixed skill directly.

### Backend skills — invoke as `be-<name>` (real workflow in `liteend/.agents/skills/`)
| Skill | Use it to… |
|---|---|
| `implement-feature-tdd` | Implement any new backend feature strictly TDD |
| `new-module` | Scaffold a new NestJS business module |
| `add-graphql-type` | Add a GraphQL ObjectType/InputType/Enum (code-first Mercurius) |
| `prisma-change` | Edit Prisma schema → migrate → regen client → update services |
| `add-queue-job` | Add a BullMQ job (processor, producer, module, tests) |
| `add-tests` | Unit tests for a service/resolver/controller (Vitest) |
| `add-e2e-test` | E2E test for a controller/resolver (Fastify inject) |
| `check` | Run full quality pipeline (TS + Biome + Knip) and fix issues |
| `commit` | Commit backend changes (runs check, conventional commits) |
| `update-deps` | Update/upgrade npm dependencies |

### Frontend skills — invoke as `fe-<name>` (real workflow in `litefront/.agents/skills/`)
| Skill | Use it to… |
|---|---|
| `new-fsd-slice` | Scaffold a new FSD slice (feature/entity/widget/shared) |
| `new-page` | Add a new page / route |
| `new-component` | Add a reusable component to `shared/ui` |
| `new-store` | Add a Zustand store / client state |
| `add-gql` | Add a GraphQL query/mutation/subscription (+ codegen) |
| `add-auth-guard` | Protect a route / add OIDC auth to a page |
| `add-translation` | Add i18n strings (Paraglide JS) |
| `add-story` | Add a Ladle story for a component |
| `analyze-bundle` | Analyze/reduce bundle size |
| `write-tests` | Write unit/component/E2E tests (Vitest/Playwright) |
| `quality-fix` | Fix lint/TS/Biome errors, unblock the pre-commit hook |
| `refactor-fsd` | Move code between FSD layers / rename a slice |
| `remove-fsd-module` | Delete a component/slice, clean up unused files |
| `commit` | Commit frontend changes (runs check, conventional commits) |
| `update-deps` | Update/upgrade npm dependencies |

> Both projects have their own `commit` and `update-deps`; at the meta root they are
> `be-commit`/`fe-commit` and `be-update-deps`/`fe-update-deps`. To commit across the whole
> stack use the meta-level `commit` skill instead (see below).

### Meta skills (`.claude/skills/`) — true cross-project, no submodule home
| Skill | Use it to… |
|---|---|
| `full-stack-feature` | Orchestrate a feature across both sides: backend first → start backend → `npm run gen` on frontend → UI. Delegates to the sub-project skills in order. |
| `commit` | Commit at the meta level: commit inside each changed submodule, record updated pointers in the meta-repo, push per the operating mode (template vs derived). |

One-time operations (deriving a new project, first-time setup) are described in `README.md`,
not as skills.

## Deriving a new project from LiteStack

To start a real product (switch to DERIVED mode):

1. Create your own repos for the meta, backend, and frontend on **any git host**
   (fork/copy the `uxname/*` templates, or push fresh copies). Optionally keep the
   canonical template as an `upstream` remote — but note we do not chase upstream changes.
2. Re-point the submodules to your repos:
   ```bash
   git config -f .gitmodules submodule.liteend.url   <your-backend-repo-url>
   git config -f .gitmodules submodule.litefront.url <your-frontend-repo-url>
   git submodule sync
   ```
3. Set the meta-repo `origin` to your meta repo and push.
4. From here, all commits/pushes target your repos (DERIVED mode rules above).
