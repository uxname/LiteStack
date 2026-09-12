---
name: new-project
description: Create a NEW project (backend + frontend pair) from the LiteStack templates as a meta-repo with submodules, in DERIVED mode. Use when the user wants to start a brand-new product/app from LiteStack — "new project from the template", "scaffold a new app", "bootstrap a new LiteStack project". Produces the same meta+submodules shape as LiteStack, repointed at the team's own repos, renamed, installed, and wired. Replaces the removed kodu start/*-init pipeline.
---

The deliverable is a meta-repo with `backend/` and `frontend/` submodules pointing at the
**team's own** repos (DERIVED mode), renamed off the template identity and running. The
mechanics are written down already — [`.agents/DERIVE.md`](../../../.agents/DERIVE.md) for
repointing and renaming, [`docs/ENV-CONTRACT.md`](../../../docs/ENV-CONTRACT.md) for the env
pairs. This skill covers only the parts that need a human.

## Ask first

- **Project name** (machine): lowercase `[a-z0-9-]`, e.g. `acme-portal` — it becomes npm
  package names, the docker network and the theme store key.
- **Display brand** (optional; default = Title-Cased name).
- **Git host + owner** for the three repos, and the **target directory**.

## Then, in order

1. **Create three empty remote repos** (meta, backend, frontend) on the team's host — via
   `gh`/`glab`, or ask the user for the URLs. Push nothing yet.
2. **Scaffold**: `git clone --recurse-submodules https://github.com/uxname/LiteStack <dir>`,
   then `rm -rf .git && git init` inside it — the project starts its own history.
3. **Repoint** submodules and remotes at the three URLs, per `.agents/DERIVE.md`. When
   `.gitmodules` no longer points at `uxname/*`, the project is in DERIVED mode
   (`.agents/OPERATING-MODE.md`) and nothing will ever push to the templates again.
4. **Rename**:
   `scripts/rename-project.sh --name <name> --display "<Brand>" --repo-owner <owner>` —
   before installing, because it rewrites the Go module path and package names.
5. **Install and verify**: `scripts/setup.sh` — one command; it checks the toolchain, writes
   both `.env` files and runs `scripts/doctor.sh`. Fix any contract mismatch it reports;
   these fail silently at runtime otherwise.
6. **Run it**: `cd backend && task start:dev`, `cd frontend && npm run start:dev`. It worked
   when `http://localhost:3000` and `http://localhost:4000/readyz` both answer.
7. **Commit and push** with the meta **`/commit`** skill. Confirm with the user first — this
   is the project's first push.

## Auth, and the one thing to say at hand-off

Local dev runs with `OIDC_MOCK_ENABLED=true` against a shared public dev Logto tenant. Real
auth means `OIDC_MOCK_ENABLED=false` and the backend's `OIDC_ISSUER`/`OIDC_JWKS_URI`/
`OIDC_AUDIENCE` matching the frontend's `VITE_OIDC_AUTHORITY`/`VITE_OIDC_API_RESOURCE` —
same tenant, same API resource. Tell the user it must be swapped before production.

## Never

- Leave `.gitmodules` pointing at `uxname/*` for a real product — that pushes the team's
  product into the public templates.
- Commit a `.env`. Only `.env.example` is tracked.
