# LiteStack

A meta-repository that bundles a backend (`liteend`) and a frontend (`litefront`)
template as git submodules, with shared documentation tuned for AI coding agents
doing full-stack work.

LiteStack itself does not run or build anything — each sub-project runs on its own.
This repo only carries coordination material: the root `AGENTS.md`, cross-project
docs, a task backlog, and an ideas backlog.

## Layout

```
LiteStack/
├── AGENTS.md        # entry point for agents: navigator + cross-project rules
├── CLAUDE.md        # pointer to AGENTS.md
├── liteend/         # submodule → github.com/uxname/liteend  (NestJS backend)
├── litefront/       # submodule → github.com/uxname/litefront (Vite/React frontend)
├── docs/            # architecture, GraphQL contract, OIDC, environment, glossary
├── tasks/           # full-stack task specs + TEMPLATE.md
├── ideas/           # idea backlog
└── scripts/setup.sh # one-time bootstrap
```

## Getting started

Clone with submodules:

```bash
git clone --recurse-submodules <this-repo-url>
cd LiteStack
bash scripts/setup.sh        # inits submodules + npm install in both
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

Then read **`AGENTS.md`** (and each sub-project's `AGENTS.md`) before working.

## Running the projects

Run them **separately**, each per its own `AGENTS.md`:

- **Backend** (`liteend/`): `docker-compose up -d db redis` → copy `.env.example` to `.env`
  → `npm run start:dev` (serves GraphQL at `http://localhost:4000/graphql`).
- **Frontend** (`litefront/`): copy `.env.example` to `.env` → `npm run start:dev`
  (serves at `http://localhost:3000`). Run `npm run gen` while the backend is up to
  sync GraphQL types.

See `docs/environment.md` for the full port map and required env vars.

## Updating the templates

Each submodule tracks its upstream. To pull template updates:

```bash
cd liteend && git pull origin master && cd ..
git add liteend && git commit -m "chore: bump liteend"
# same for litefront
```
