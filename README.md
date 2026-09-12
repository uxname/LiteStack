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

## Layout

```
LiteStack/
├── AGENTS.md        # entry point for agents: the meta-project model, cross-project rules
├── package.json     # meta tooling: LikeC4 CLI + lefthook, the likec4:*/scale:* scripts
├── lefthook.yml     # the meta-repo's own git hook (what it runs is explained in the file)
├── .gitmodules      # submodule URLs (template vs derived — .agents/OPERATING-MODE.md)
├── .agents/         # the cross-project instruction files AGENTS.md routes to
├── docs/            # TEAM.md (process), ENV-CONTRACT.md, DEPLOY.md, adr/, retro/, architecture/likec4/
├── scripts/         # setup.sh, doctor.sh, scale-check.sh, rename-project.sh
├── scale/           # local multi-copy stand: 2+2 copies behind one Caddy
├── backend/         # submodule → liteend-go (Go · chi · gqlgen · sqlc · goose)
├── frontend/        # submodule → litefront (Vite · React 19 · URQL)
└── .claude/skills/  # the four cross-project skills
```

## What you need

| tool | minimum | check |
|---|---|---|
| git | any | `git --version` |
| Docker Engine | 27.4 — why: `backend/.agents/OPERATIONS.md` | `docker --version` |
| Go | 1.27 | `go version` |
| Task | any (on Arch the binary is `go-task`) | `task --version` |
| Node | 24.15.0 | `node -v` |

`scripts/setup.sh` checks all five and names everything missing in one message.

## Getting started

```bash
git clone --recurse-submodules <this-repo-url>
cd LiteStack
scripts/setup.sh        # toolchain check, submodules, .env, deps (idempotent; --no-install)
```

## Running the projects (separately)

**All in Docker** — no Go, Node or Task: `cd backend && cp -n .env.example .env && docker compose up -d --build`,
then the same in `frontend/` with `docker compose up -d`. **From source**, one side at a time:

- **Backend** (`backend/`, liteend-go — Go): configure (`cp .env.example .env`, or export
  the variables) → `task start:dev` (brings up Docker db+redis+object store, runs goose
  migrations at startup, hot-reload; GraphQL at `:4000/graphql` + gqlgen playground).
  First-time full onboarding: `task setup`.
- **Frontend** (`frontend/`): configure the same way → `npm run start:dev` (serves at `:3000`).
  GraphQL types are already in the repo (`frontend/src/generated/`); `npm run gen` is only needed after editing `backend/internal/graph/schema.graphqls`.
- **Note on `PORT`**: it is the only variable name both sides use, so export it per side —
  it belongs to whichever app you are starting.
- **The multi-copy stand** (`scale/`): the product the way a server runs it with more than
  one copy of each side — `docker compose -f scale/docker-compose.yml up -d --wait`, then
  `scripts/scale-check.sh`. Read that script's header before you read anything into a green run.
- **Deploying** (local Docker all-in-one, Dokploy production, registry images, bare VPS,
  running more than one copy of each side): see [`docs/DEPLOY.md`](./docs/DEPLOY.md).

It worked when both answer: `http://localhost:3000` — the frontend page;
`http://localhost:4000/readyz` — a body starting `{"status":"ok"`. If not, `scripts/doctor.sh --reachable` checks both sides and GraphQL.

## Where to look next

| file | what it owns |
|---|---|
| [`AGENTS.md`](./AGENTS.md) | entry point for agents: the meta model, cross-project rules, skills |
| [`docs/TEAM.md`](./docs/TEAM.md) | how work gets done here |
| [`docs/ENV-CONTRACT.md`](./docs/ENV-CONTRACT.md) | every variable, and which values must agree across the two sides |
| [`docs/DEPLOY.md`](./docs/DEPLOY.md) | the deploy runbook |
| [`docs/adr/`](./docs/adr/) | the decisions this project already made, and why |
| [`lefthook.yml`](./lefthook.yml) | the meta-repo's gates: what runs on pre-commit is explained in the file itself |

## Two ways to use it

- **Template mode** — you're improving the LiteStack/LiteEnd/LiteFront templates.
  Submodules point at the canonical `uxname/*` upstreams.
- **Derived mode** — you're building a real product. Point the submodules at your own
  repos (any git host) and commit/push everything to your project. A derived project is a
  snapshot — it is **not** kept in sync with the upstream templates (they change too often,
  sometimes with breaking changes).

See [`.agents/OPERATING-MODE.md`](./.agents/OPERATING-MODE.md) for detection and the commit/push rules.

## Deriving a new project

See [`.agents/DERIVE.md`](./.agents/DERIVE.md). In short: create your own
repos on any git host, re-point the submodule URLs (`git config -f .gitmodules …` +
`git submodule sync`), set the meta-repo `origin`, and push.
