# AGENTS.md — LiteStack

## What is LiteStack (read this first)

LiteStack is a **full-stack boilerplate** — a starting point, in the same spirit as
LiteEnd and LiteFront. It is **not a runnable product**. It bundles two real projects as
git submodules and adds a thin coordination layer on top:

- **`backend/`** — the **backend** project (its own repo). All server code lives here.
- **`frontend/`** — the **frontend** project (its own repo). All browser code lives here.
- **LiteStack** (this repo, the "meta-project") — owns **no application code**. It only
  coordinates: it tells the agent which project to touch, how the two connect, and how to
  commit across them.

### What a "meta-project" means — where does each change go?

Think of three boxes. Put each change in the right box:

| You are changing… | Go to | Why |
|---|---|---|
| API, database, business logic, background jobs, server-side GraphQL | **`backend/`** | Backend owns all server behavior |
| UI, pages, routing, client state, styling, GraphQL the browser sends | **`frontend/`** | Frontend owns everything in the browser |
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

### 0. Read the retrospectives — learn from past mistakes

Before touching any code, **read every `docs/retro/*.md`**. These are the accumulated
records of what went wrong in past sessions, each ending in a one-line **rule**. Reading
them first is how you avoid repeating mistakes the project already paid for.

**Do this in a separate thread so it does not bloat your working context.** Spawn a
subagent (Task / Agent tool) with this instruction:

> Read every file in `docs/retro/*.md` (skip `README.md` and `TEMPLATE.md`). Return ONLY a
> deduplicated, compact list of the **Rule — do this next time** lines, grouped by `area`
> (backend / frontend / meta / cross). No file dumps, no narrative — just the rules.

Apply the returned rules to the work you're about to do. If `docs/retro/` has no retro files
yet, there is nothing to read — continue.

### 1. Read the relevant AGENTS.md

Then read the `AGENTS.md` of the sub-project(s) you'll change:

- **`backend/AGENTS.md`** — backend rules, commands, conventions
- **`frontend/AGENTS.md`** — frontend rules, commands, conventions

Those are the source of truth for each side. This root file only covers what spans
**both** projects. On any conflict inside a sub-project, the sub-project's `AGENTS.md` wins.

### End of session — write a retrospective before committing

At the end of a work session, **before committing**, run the **`/retro` skill** to record
what went badly into `docs/retro/` (the `/commit` skill runs this automatically as its first
step). This is what keeps the loop closed: today's mistakes become tomorrow's rules.

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

1. Change code inside `backend/` and/or `frontend/` → commit **and push** in each
   submodule to its canonical upstream. (Needs write access to those upstreams.)
2. In the meta-repo: `git add backend frontend` to record new submodule pointers, then
   commit (and push if the meta-repo has a remote).

Use this mode **only** when the goal is to improve the boilerplate, not to build a product.

### DERIVED mode — building a real product on top of LiteStack

The submodules (and the meta-repo) point at **your own** repositories. Everything goes
into your project:

1. Change code inside `backend/` and/or `frontend/` → commit **and push** in each
   submodule to **its own remote** (your backend/frontend repo).
2. In the meta-repo: `git add backend frontend`, commit, push to **your** meta repo.

Never push a derived project's changes to the `uxname/*` upstreams.

> A derived project is a **snapshot fork**. We do **not** keep it in sync with the
> upstream templates: LiteEnd and LiteFront change often, sometimes with breaking changes,
> so chasing upstream is more pain than value. Take the snapshot and own it.

## Git topology (applies to both modes)

Each submodule is a **separate git repository** with its own history and remote(s):

- Code changes inside `backend/` are committed **in the `backend` repo**.
- Code changes inside `frontend/` are committed **in the `frontend` repo**.
- The meta-repo commits only: (a) updated submodule pointers, (b) its own files
  (`AGENTS.md`, `README.md`, `.agents/`).

Flow per change: `cd backend` → edit → commit (+push) → `cd ..` → `git add backend` →
commit (+push) the meta-repo. (The `commit` meta-skill automates this — see below.)

## Project map

| Submodule | Role | Stack | Dev port | Read |
|---|---|---|---|---|
| `backend/` | Backend / API | NestJS · Prisma · PostgreSQL · Redis/BullMQ · **Mercurius** GraphQL (code-first) · OIDC | `4000` (`/graphql`, IDE Altair at `/altair`) | `backend/AGENTS.md` |
| `frontend/` | Frontend / SPA | Vite · React 19 · TanStack Router · URQL · Zustand · Tailwind v4 · daisyUI · OIDC | `3000` | `frontend/AGENTS.md` |

Infra ports (backend): PostgreSQL `5432`, Redis `6379`, pgAdmin `5100`, Redis admin
`5200`, Prisma Studio `5555`.

## Which project for which task

- **API, data, DB schema/migrations, business logic, jobs, server GraphQL types** → `backend`
- **UI, routing, client state, styling, GraphQL operations the browser sends** → `frontend`
- **Full-stack feature** → both, **start with `backend`** (define schema/resolver first),
  then regenerate and consume types in `frontend`. Use the `full-stack-feature` skill.

## Back ↔ front seams (cross-project rules)

- **GraphQL types are generated, not hand-written (on the frontend).** The frontend runs
  `npm run gen` against the backend's **live** schema at `VITE_GRAPHQL_API_URL` (default
  `http://localhost:4000/graphql`). **The backend must be running** or `gen` fails. So for
  a full-stack change: edit backend schema → start backend → `npm run gen` in `frontend`
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
- Both use **Biome** but with **different** configs: `backend` = single quotes,
  `frontend` = double quotes. Never copy formatting/style config across the boundary.
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
`be-*` (backend → `backend`) and `fe-*` (frontend → `frontend`). A wrapper is ~5 lines: it
tells the agent to `cd` into the submodule and follow the real `SKILL.md` there. Result:
open the LiteStack root in either tool and **every** skill is discoverable, collision-free
(`be-commit`/`fe-commit`/`commit` are distinct), with zero workflow drift.

> Invoke `be-<name>` / `fe-<name>` from the meta root; the wrapper hands off to the real
> skill inside the submodule. If your cwd is already inside a submodule (opencode), you can
> use the un-prefixed skill directly.

### Backend skills — invoke as `be-<name>` (real workflow in `backend/.agents/skills/`)
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

### Frontend skills — invoke as `fe-<name>` (real workflow in `frontend/.agents/skills/`)
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
| `retro` | Write a session retrospective to `docs/retro/` — what went badly, root cause, and the rule to avoid repeating it. Runs automatically as the first step of `commit`. |
| `new-project` | Bootstrap a brand-new product as a meta+submodules pair in DERIVED mode: scaffold → repoint submodules to the team's repos → rename identity → install → wire env → first commit. Orchestrates the `scripts/*.sh` backbone. |

First-time setup of an existing clone is `scripts/setup.sh` (see `README.md`). Team process —
repo model, branch/PR flow, CI, agent parity — is in `docs/TEAM.md`.

## Creating & updating skills (IMPORTANT — unusual structure)

LiteStack uses a **thin-client** model for skills:

- **The real skill = the source of truth, lives in the sub-project** (`backend/.agents/skills/`
  or `frontend/.agents/skills/`). It holds the full workflow.
- **The meta-repo holds only a thin client** — a tiny `be-*`/`fe-*` **wrapper** in
  `.claude/skills/` that points to the real skill. It carries **no workflow logic**, just
  enough metadata to be discoverable + a `cd` + "read the real file" instruction.

When the user asks to **create, update, rename, or delete** a skill, follow these rules.

### 1. Decide where the skill belongs

- Backend-specific (NestJS/Prisma/GraphQL-server/jobs/…) → **`backend`**, wrapper prefix `be-`.
- Frontend-specific (UI/FSD/routing/state/codegen-client/…) → **`frontend`**, wrapper prefix `fe-`.
- Genuinely cross-project (orchestrates both, or pure meta git/submodule work) → lives
  **directly in the meta `.claude/skills/`** as a real skill with **no wrapper** (like
  `full-stack-feature` and `commit`).

### 2. Create a sub-project skill (the common case)

1. Write the real skill in the submodule: `<project>/.agents/skills/<name>/SKILL.md`.
   Follow **that project's** skill conventions (see its `AGENTS.md`; e.g. skill content
   must be English). This is where ALL the workflow text goes.
2. Add the thin wrapper in the meta-repo: `.claude/skills/<prefix><name>/SKILL.md` using the
   template below. Copy the real skill's `description` **verbatim** (including its trigger
   phrases) so auto-activation fires; prefix the name with `be-`/`fe-`.
3. Commit: the real skill is committed **inside the submodule** (its own repo); the wrapper
   is committed **in the meta-repo**. Use the meta `commit` skill — it handles both layers.

### 3. Wrapper template (the thin client)

```markdown
---
name: <prefix><name>                # be-<name> for backend, fe-<name> for frontend
description: "[<project>] <verbatim copy of the real skill's description + its trigger phrases>"
---

Thin pointer to a skill that lives in the **`<project>`** submodule. The real workflow
stays there (next to the code it operates on); this wrapper only makes it discoverable
from the LiteStack root in both opencode and Claude Code.

## Do this
1. `cd <project>`
2. Read and follow `.agents/skills/<name>/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.
```

(`<project>` = `backend` or `frontend`; `<prefix>` = `be-` or `fe-`.)

### 4. Update / rename / delete

- **Update behavior** → edit the real `SKILL.md` **in the submodule only**. The wrapper does
  not change (it just points). Touch the wrapper **only** if the skill's `name`, `description`,
  or trigger phrases changed — then mirror that into the wrapper so activation still matches.
- **Rename** → rename both the submodule skill dir and its `<prefix>`-wrapper dir; keep
  `name:` in sync in both files.
- **Delete** → remove the submodule skill dir **and** its wrapper dir.
- **Golden rule:** never copy the workflow body into the wrapper. One source of truth, in the
  submodule. The wrapper stays ~10 lines forever. This is what keeps the two from drifting.

## Deriving a new project from LiteStack

To start a real product (switch to DERIVED mode), use the **`new-project` skill** — it drives
the whole flow (scaffold → repoint → rename → install → wire env → verify → first commit) on
top of the tested `scripts/*.sh` backbone. The mechanical core, if you do it by hand:

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
4. Rename the template identity: `scripts/rename-project.sh --name <name> --display "<Brand>"`.
5. Install + wire env: `scripts/setup.sh`, then copy `.env.example` → `.env` in each submodule
   and confirm `scripts/doctor.sh` passes (see `docs/ENV-CONTRACT.md`).
6. From here, all commits/pushes target your repos (DERIVED mode rules above).

<!-- CODEGRAPH_START -->
## CodeGraph

This project has a CodeGraph MCP server (`codegraph_*` tools) configured. CodeGraph is a tree-sitter-parsed knowledge graph of every symbol, edge, and file. Reads are sub-millisecond and return structural information grep cannot.

### When to prefer codegraph over native search

Use codegraph for **structural** questions — what calls what, what would break, where is X defined, what is X's signature. Use native grep/read only for **literal text** queries (string contents, comments, log messages) or after you already have a specific file open.

| Question | Tool |
|---|---|
| "Where is X defined?" / "Find symbol named X" | `codegraph_search` |
| "What calls function Y?" | `codegraph_callers` |
| "What does Y call?" | `codegraph_callees` |
| "How does X reach/become Y? / trace the flow from X to Y" | `codegraph_trace` (one call = the whole path, incl. callback/React/JSX dynamic hops) |
| "What would break if I changed Z?" | `codegraph_impact` |
| "Show me Y's signature / source / docstring" | `codegraph_node` |
| "Give me focused context for a task/area" | `codegraph_context` |
| "See several related symbols' source at once" | `codegraph_explore` |
| "What files exist under path/" | `codegraph_files` |
| "Is the index healthy?" | `codegraph_status` |

### Rules of thumb

- **Answer directly — don't delegate exploration.** For "how does X work" / architecture questions, answer with 2-3 codegraph calls: `codegraph_context` first, then ONE `codegraph_explore` for the source of the symbols it surfaces. For a specific **flow** ("how does X reach Y") start with `codegraph_trace` from→to — one call returns the whole path with dynamic hops bridged — then ONE `codegraph_explore` for the bodies; don't rebuild the path with `codegraph_search` + `codegraph_callers`. Codegraph IS the pre-built index, so spawning a separate file-reading sub-task/agent — or running a grep + read loop — repeats work codegraph already did and costs more for the same answer.
- **Trust codegraph results.** They come from a full AST parse. Do NOT re-verify them with grep — that's slower, less accurate, and wastes context.
- **Don't grep first** when looking up a symbol by name. `codegraph_search` is faster and returns kind + location + signature in one call.
- **Don't chain `codegraph_search` + `codegraph_node`** when you just want context — `codegraph_context` is one call.
- **Don't loop `codegraph_node` over many symbols** — one `codegraph_explore` call returns several symbols' source grouped in a single capped call, while each separate node/Read call re-reads the whole context and costs far more.
- **Index lag**: the file watcher debounces ~500ms behind writes; don't re-query immediately after editing a file in the same turn.

### If `.codegraph/` doesn't exist

The MCP server returns "not initialized." Ask the user: *"I notice this project doesn't have CodeGraph initialized. Want me to run `codegraph init -i` to build the index?"*
<!-- CODEGRAPH_END -->
