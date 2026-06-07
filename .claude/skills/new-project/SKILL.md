---
name: new-project
description: Create a NEW project (backend + frontend pair) from the LiteStack templates as a meta-repo with submodules, in DERIVED mode. Use when the user wants to start a brand-new product/app from LiteStack — "new project from the template", "scaffold a new app", "bootstrap a new LiteStack project". Produces the same meta+submodules shape as LiteStack, repointed at the team's own repos, renamed, installed, and wired. Replaces the removed kodu start/*-init pipeline.
---

The user wants to start a **new project** from LiteStack. The deliverable is a meta-repo with
`backend/` and `frontend/` submodules (the LiteStack shape) pointing at the **team's own**
repos (DERIVED mode), with the template identity renamed and the env contract satisfied.

This skill is the conductor. The mechanical steps are tested scripts at the meta root
(`scripts/rename-project.sh`, `scripts/setup.sh`, `scripts/doctor.sh`); the judgment steps
(creating remote repos, configuring Logto, confirming names) are yours to drive with the user.

## Step 0: Gather inputs (ask the user)

- **Project name** (machine): lowercase `[a-z0-9-]`, e.g. `acme-portal`. Used for npm package
  names, the docker network, the theme store key.
- **Display brand** (optional): human brand word, e.g. `Acme`. Default = Title-Cased name.
- **Git host + owner**: where the three repos will live (GitHub/GitLab org or user).
- **Target directory** for the new meta-repo checkout.

Confirm these before touching anything.

## Step 1: Create the three remote repos

The new project needs its own **meta**, **backend**, and **frontend** repos on the team's host.
Create them as empty repos (no README), via `gh`/`glab` if available, otherwise ask the user to
create them and paste the URLs. You need three URLs:

- `<meta-repo-url>`, `<backend-repo-url>`, `<frontend-repo-url>`.

Do not push anything yet.

## Step 2: Scaffold the meta-repo

Clone the canonical LiteStack meta with submodules into the target directory, then detach from
the upstream history so it becomes the team's own project:

```bash
git clone --recurse-submodules https://github.com/uxname/LiteStack <target-dir>
cd <target-dir>
rm -rf .git && git init        # drop template history; start the project's own
```

## Step 3: Repoint submodules + remotes to the team repos (DERIVED mode)

```bash
git config -f .gitmodules submodule.liteend.url   <backend-repo-url>
git config -f .gitmodules submodule.litefront.url <frontend-repo-url>
git submodule sync
( cd backend  && git remote set-url origin <backend-repo-url> )
( cd frontend && git remote set-url origin <frontend-repo-url> )
git remote add origin <meta-repo-url>
```

After this, `.gitmodules` URLs point at the team's repos → the project is in **DERIVED mode**
(see root `AGENTS.md` → Operating mode). All future pushes go to the team's repos, never to
`uxname/*`.

## Step 4: Rename the template identity

```bash
scripts/rename-project.sh --name <name> --display "<Brand>" --repo-owner <owner>
```

This rewrites `liteend`/`litefront`/`LiteFront` across package.json, docker-compose network,
the theme store key, the PWA manifest, page titles, and demo links. Run it BEFORE installing.

## Step 5: Install + environment

```bash
scripts/setup.sh        # submodules + binary fix + npm install + CodeGraph
cp backend/.env.example  backend/.env
cp frontend/.env.example frontend/.env
```

`.env.example` ships a **shared public dev Logto tenant** so auth works out of the box — fine
for first run. For a real product, register the team's own Logto tenant + API resource and swap
`OIDC_ISSUER`/`OIDC_JWKS_URI` (backend) and `VITE_OIDC_AUTHORITY`/`VITE_OIDC_CLIENT_ID`/
`VITE_OIDC_API_RESOURCE` (frontend). See `docs/ENV-CONTRACT.md`. For local-only dev you may set
backend `OIDC_MOCK_ENABLED=true` to bypass OIDC.

## Step 6: Verify the env contract

```bash
scripts/doctor.sh        # OIDC audience/tenant, CORS, GraphQL port, port collisions
```

Fix any mismatch before proceeding — these fail silently at runtime otherwise.

## Step 7: Bring up the backend, then sync the frontend contract

The frontend generates GraphQL types from the backend's **live** schema — backend must be up
first.

```bash
( cd backend && docker compose up -d db redis && npm run db:migrations:apply && npm run start:dev & )
# wait for it, then verify GraphQL actually answers (not just /health):
curl -s -X POST localhost:4000/graphql -H 'content-type: application/json' \
     -d '{"query":"{ __typename }"}'      # expect {"data":{"__typename":"Query"}}
scripts/doctor.sh --reachable               # confirms the endpoint before codegen
( cd frontend && npm run gen )              # generate types from the live schema
```

## Step 8: First commit + push (DERIVED mode)

Use the meta **`/commit`** skill — it commits each submodule, records the pointers, and pushes
to the team's repos (DERIVED mode). Confirm with the user before the first push.

## Step 9: Hand-off checklist

Report to the user:

- [ ] Three repos created and pushed (meta + backend + frontend).
- [ ] Identity renamed (`grep -rn 'liteend\|litefront'` finds only historical docs).
- [ ] `scripts/doctor.sh` passes.
- [ ] Backend runs; `/graphql` answers; frontend `npm run gen` succeeded.
- [ ] Logto: still on the shared dev tenant (swap before production).
- [ ] CodeGraph index built; agent restarted to load the MCP server.

## What NOT to do

- Never leave `.gitmodules` pointing at `uxname/*` for a real product (that's TEMPLATE mode —
  you would push the team's product into the public templates).
- Never run `npm run gen` before the backend `/graphql` endpoint answers.
- Never commit `.env` (secrets) — only `.env.example` is tracked.
