# LiteStack

A full-stack **boilerplate** — in the same spirit as LiteEnd and LiteFront — that bundles
a backend (`liteend`) and a frontend (`litefront`) as git submodules, plus a thin
coordination layer (`AGENTS.md`) tuned for AI coding agents doing full-stack work.

LiteStack is a starting point, not a standalone product. It runs nothing itself — each
sub-project runs on its own. It carries no project content (no docs/tasks/ideas) so you
can manage that however you like (your own task manager, bmad-method, etc.).

## Layout

```
LiteStack/
├── AGENTS.md         # entry point: navigator, cross-project rules, two-mode git model
├── CLAUDE.md         # pointer to AGENTS.md
├── liteend/          # submodule → github.com/uxname/liteend  (NestJS backend)
├── litefront/        # submodule → github.com/uxname/litefront (Vite/React frontend)
└── scripts/setup.sh  # one-time bootstrap
```

## Two ways to use it

- **Template mode** — you're improving the LiteStack/LiteEnd/LiteFront templates
  themselves. Submodules point at the canonical `uxname/*` upstreams.
- **Derived mode** — you're building a real product on top. Fork the three repos,
  re-point the submodules to your own repos, and commit/push everything to your project.

See `AGENTS.md` → **Operating mode** for detection and the commit/push rules.

## Getting started

```bash
git clone --recurse-submodules <this-repo-url>
cd LiteStack
bash scripts/setup.sh          # inits submodules + npm install in both, fixes binary attrs
```

Already cloned without submodules?

```bash
git submodule update --init --recursive
```

Then read **`AGENTS.md`** (and each sub-project's `AGENTS.md`) before working.

## Running the projects (separately)

- **Backend** (`liteend/`): `docker-compose up -d db redis` → `cp .env.example .env`
  → `npm run db:migrations:apply` → `npm run start:dev` (GraphQL at `:4000/graphql`).
- **Frontend** (`litefront/`): `cp .env.example .env` → `npm run gen` (backend must be up)
  → `npm run start:dev` (serves at `:3000`).

Cross-project value contracts (must agree across the two `.env` files):

| Frontend | Backend | Meaning |
|---|---|---|
| `VITE_GRAPHQL_API_URL` = `…:4000/graphql` | `PORT` = `4000` | where the SPA reaches the API |
| `VITE_OIDC_API_RESOURCE` = `…:4000` | `OIDC_AUDIENCE` = `…:4000` | token `aud` match |
| `VITE_BASE_URL` = `…:3000` | `CORS_ORIGIN` includes `…:3000` | CORS allow |

## Updating templates

Each submodule tracks its upstream. To pull template updates in template mode:

```bash
cd liteend && git pull origin master && cd ..
git add liteend && git commit -m "chore: bump liteend"
# same for litefront
```

In derived mode, pull from your `upstream` remote and merge into your fork.
