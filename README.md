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
  they only change where you commit/push. See [`.agents/OPERATING-MODE.md`](./.agents/OPERATING-MODE.md).

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
├── package.json               # meta tooling: LikeC4 CLI + lefthook (devDeps), likec4:*/scale:* scripts
├── lefthook.yml               # the meta-repo's own git hook (see "Meta-repo git hook")
├── .agents/                   # cross-project instruction files AGENTS.md routes to
├── docs/                      # deploy runbook, env contract, ADRs, the LikeC4 model
├── scripts/                   # setup.sh, doctor.sh (env contract), scale-check.sh
├── scale/                     # local multi-copy stand: 2+2 copies behind one Caddy
├── backend/                   # submodule → liteend-go (Go · chi · gqlgen · sqlc · goose)
├── frontend/                  # submodule → litefront (Vite · React 19 · URQL)
└── .claude/skills/            # the four cross-project skills
```

**Instructions vs skills.** Each project has one entry point — `AGENTS.md` — holding the
rules you must not break plus a routing table into topic files under its own `.agents/`
directory, so an agent reads only the file its task needs. Both submodules follow that
shape and ship **no** skills of their own.

Skills are reserved for genuinely cross-project orchestration and live in
`.claude/skills/`, visible from the meta root in both Claude Code and opencode:
`full-stack-feature`, `commit`, `retro`, `new-project`. See [`AGENTS.md`](./AGENTS.md) →
Skills.

## Two ways to use it

- **Template mode** — you're improving the LiteStack/LiteEnd/LiteFront templates.
  Submodules point at the canonical `uxname/*` upstreams.
- **Derived mode** — you're building a real product. Point the submodules at your own
  repos (any git host) and commit/push everything to your project. A derived project is a
  snapshot — it is **not** kept in sync with the upstream templates (they change too often,
  sometimes with breaking changes).

See [`.agents/OPERATING-MODE.md`](./.agents/OPERATING-MODE.md) for detection and the commit/push rules.

## Getting started

```bash
git clone --recurse-submodules <this-repo-url>
cd LiteStack
scripts/setup.sh        # submodules + binary fix + npm install (idempotent)
```

`scripts/setup.sh` runs every step below in one shot (re-runnable). Flag: `--no-install`.
The manual equivalents follow if you prefer to run them piecemeal.

Already cloned without submodules?

```bash
git submodule update --init --recursive
```

Then install dependencies in each sub-project — **the two stacks differ, the backend has
no `package.json`**:

```bash
( cd backend  && task setup )    # Go deps + git hooks + codegen + local db/redis
( cd frontend && npm install )   # npm deps + git hooks (via postinstall)
npm install                      # meta root: LikeC4 CLI + this repo's own git hook
```

Then configure both sides and verify the contract. `.env` is **optional** — exported
environment variables work everywhere, `.env.example` lists every variable either way
([docs/ENV-CONTRACT.md](./docs/ENV-CONTRACT.md)). The copy-a-file route is the shortest:

```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
scripts/doctor.sh
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

- **Backend** (`backend/`, liteend-go — Go): configure (`cp .env.example .env`, or export
  the variables) → `task start:dev` (brings up Docker db+redis, runs goose migrations at
  startup, hot-reload; GraphQL at `:4000/graphql` + gqlgen playground). First-time full
  onboarding: `task setup`.
- **Frontend** (`frontend/`): configure the same way → `npm run gen` (backend must be up)
  → `npm run start:dev` (serves at `:3000`).
- **Note on `PORT`**: it is the only variable name both sides use, so export it per side —
  it belongs to whichever app you are starting.
- **Deploying** (local Docker all-in-one, Dokploy production, registry images, bare VPS,
  running more than one copy of each side): see [`docs/DEPLOY.md`](./docs/DEPLOY.md).

Cross-project value contracts (must agree across the two sides' configurations):

| Frontend | Backend | Meaning |
|---|---|---|
| `VITE_GRAPHQL_API_URL` = `…:4000/graphql` | `PORT` = `4000` | where the SPA reaches the API |
| `VITE_OIDC_API_RESOURCE` = `…:4000` | `OIDC_AUDIENCE` = `…:4000` | token `aud` match |
| `VITE_BASE_URL` = `…:3000` | `CORS_ORIGIN` includes `…:3000` | CORS allow |

## Meta-repo git hook

The meta-repo has a `pre-commit` hook of its own, alongside the submodules'. It is
installed by `npm install` at the meta root — the `prepare` script runs
`lefthook install`, and `scripts/setup.sh` already does that for you. A clone that
skipped the install simply has no hook, exactly as in `backend/` and `frontend/`.

It runs one thing, `npm run scale:validate`, which syntax-checks the stand below:
`docker compose config -q` on `scale/docker-compose.yml` and `caddy validate` on
`scale/Caddyfile`. Each check skips itself when its binary is missing, and neither
starts anything — a commit hook has no business waiting on containers. There is no
CI behind it (see [`docs/adr/0001-no-ci-gates-live-in-git-hooks.md`](./docs/adr/0001-no-ci-gates-live-in-git-hooks.md)),
so don't commit with `--no-verify`.

## The multi-copy stand (`scale/`)

`scale/` runs the whole product the way a server runs it with more than one copy of
each side: **two backends, two frontends, one Caddy in front of them**, and the state
they share (Postgres, Redis, and a Garage object store). It exists to answer one
question — is any part of the product pinned to a single copy? — and
`scripts/scale-check.sh` drives four scenarios through it: a file uploaded via one
backend read back through the other, rate limits keyed on an address the client
cannot choose, the page served by either frontend, and a subscription published on
one copy arriving at a client on the other.

```bash
docker compose -f scale/docker-compose.yml up -d --wait   # builds both sides from this checkout
scripts/scale-check.sh                                    # prints ok / not ok per check
docker compose -f scale/docker-compose.yml down -v
```

Four things to know before you read anything into a green run:

- **You start it by hand.** The git hook only checks its config files. Bringing the
  stand up takes minutes on the first run (a Go build plus an npm ci and a Vite
  build) — far too slow for a commit.
- **It needs Docker Engine 27.4 or newer.** The Garage initializer mounts the Garage
  binary straight out of its image (`type: image`, added in 27.4), which is the only
  way to run that CLI: the image is built `FROM scratch` and has no shell.
- **It is not a model of production.** It runs with `NODE_ENV=development` and mock
  authentication, because the backend refuses to boot with mock auth in production
  and `curl` cannot complete a real OIDC login. Never copy this stand, or that flag,
  onto a shared host. Its *shape* — no host ports on the app containers, everything
  through the proxy — is the part worth copying.
- **It writes data.** It uploads a file and edits the stand's mock profile;
  `down -v` wipes all of it.

## Deriving a new project

See [`.agents/DERIVE.md`](./.agents/DERIVE.md). In short: create your own
repos on any git host, re-point the submodule URLs (`git config -f .gitmodules …` +
`git submodule sync`), set the meta-repo `origin`, and push.
