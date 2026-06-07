# LiteStack

## TL;DR

- LiteStack is a **full-stack boilerplate**: a backend (`backend`) + a frontend
  (`frontend`) wired together as git submodules, plus an `AGENTS.md` that tells AI agents
  how to work across both.
- It is a **starting point, not a runnable product**. The meta-repo holds no app code.
- **Agents:** read [`AGENTS.md`](./AGENTS.md) first, then each sub-project's `AGENTS.md`.
- **Clone:** `git clone --recurse-submodules <url>` (or `git submodule update --init --recursive`).
- **Run the two projects separately** — backend on `:4000`, frontend on `:3000`.
- **Two modes:** *template* (improving the boilerplate) vs *derived* (your real product) —
  they only change where you commit/push. See `AGENTS.md` → Operating mode.

---

A full-stack **boilerplate** — in the same spirit as LiteEnd and LiteFront — that bundles
a backend (`backend`) and a frontend (`frontend`) as git submodules, with a thin
coordination layer (`AGENTS.md` + cross-project skills) tuned for AI coding agents.

LiteStack runs nothing itself; each sub-project runs on its own. It carries no project
content (no docs/tasks/ideas) so you can manage that however you like (your own task
manager, bmad-method, etc.).

## Layout

```
LiteStack/
├── AGENTS.md                  # entry point: meta-project model, cross-project rules, two-mode git
├── CLAUDE.md                  # pointer to AGENTS.md
├── backend/                   # submodule → backend  (NestJS · Prisma · Mercurius GraphQL)
├── frontend/                 # submodule → frontend (Vite · React 19 · URQL)
└── .claude/skills/            # meta-skills + be-*/fe-* wrappers to the sub-project skills
```

**Skills:** each sub-project keeps its own skills (in `<project>/.agents/skills/`). The
meta-repo adds thin `be-*`/`fe-*` wrappers in `.claude/skills/` that delegate into the
submodules, so opening the LiteStack root surfaces every skill in both opencode and Claude
Code. Plus two true cross-project skills: `full-stack-feature` and `commit`. See
`AGENTS.md` → Skills.

## Two ways to use it

- **Template mode** — you're improving the LiteStack/LiteEnd/LiteFront templates.
  Submodules point at the canonical `uxname/*` upstreams.
- **Derived mode** — you're building a real product. Point the submodules at your own
  repos (any git host) and commit/push everything to your project. A derived project is a
  snapshot — it is **not** kept in sync with the upstream templates (they change too often,
  sometimes with breaking changes).

See `AGENTS.md` → **Operating mode** for detection and the commit/push rules.

## Getting started

```bash
git clone --recurse-submodules <this-repo-url>
cd LiteStack
```

Already cloned without submodules?

```bash
git submodule update --init --recursive
```

Then install dependencies in each sub-project:

```bash
( cd backend   && npm install )
( cd frontend && npm install )
```

### One-time fix: binary file attributes

The upstream `frontend` marks some binary files (e.g. `.github/logo.png`) as text with
`eol=lf` in its `.gitattributes`, so git corrupts them on checkout and the submodule shows
as "modified". Override this locally (per clone — not committed) so the submodule stays
clean:

```bash
cd frontend
printf '%s\n' '*.png binary' '*.jpg binary' '*.gif binary' '*.ico binary' '*.webp binary' \
  >> "$(git rev-parse --absolute-git-dir)/info/attributes"
git checkout -- .          # restore the corrupted binaries
cd ..
```

Then read **`AGENTS.md`** (and each sub-project's `AGENTS.md`) before working.

## Running the projects (separately)

- **Backend** (`backend/`): `docker-compose up -d db redis` → `cp .env.example .env`
  → `npm run db:migrations:apply` → `npm run start:dev` (GraphQL at `:4000/graphql`,
  Altair IDE at `:4000/altair`).
- **Frontend** (`frontend/`): `cp .env.example .env` → `npm run gen` (backend must be up)
  → `npm run start:dev` (serves at `:3000`).

Cross-project value contracts (must agree across the two `.env` files):

| Frontend | Backend | Meaning |
|---|---|---|
| `VITE_GRAPHQL_API_URL` = `…:4000/graphql` | `PORT` = `4000` | where the SPA reaches the API |
| `VITE_OIDC_API_RESOURCE` = `…:4000` | `OIDC_AUDIENCE` = `…:4000` | token `aud` match |
| `VITE_BASE_URL` = `…:3000` | `CORS_ORIGIN` includes `…:3000` | CORS allow |

## Deriving a new project

See `AGENTS.md` → **Deriving a new project from LiteStack**. In short: create your own
repos on any git host, re-point the submodule URLs (`git config -f .gitmodules …` +
`git submodule sync`), set the meta-repo `origin`, and push.
