---
name: new-project
description: Create a new product (backend + frontend pair) from the LiteStack templates — a meta-repo with submodules in DERIVED mode, repointed at the team's own repos, renamed, installed and running. Use when the user wants to start a new project or app from LiteStack.
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
2. **Scaffold**: `git clone --recurse-submodules https://github.com/uxname/LiteStack <dir>`.
   Keep the history: do not run `rm -rf .git` or `git init`. The submodules store their
   data in `.git/modules`, so deleting `.git` leaves `backend/` and `frontend/` broken. A
   derived project is a copy of the templates with their history
   (`.agents/DERIVE.md`: "fork / push copies").
3. **Repoint** at the three URLs, per `.agents/DERIVE.md`:
   ```bash
   cd <dir>
   git remote set-url origin <meta-url>
   git config -f .gitmodules submodule.liteend-go.url <backend-url>
   git config -f .gitmodules submodule.litefront.url  <frontend-url>
   git submodule sync        # also rewrites `origin` inside both submodules
   git add .gitmodules && git commit -m "chore(submodules): point at own repos"
   ```
   The clone leaves both submodules on a detached HEAD, so give each a branch before the
   first commit: `git -C backend switch -c master`, same for `frontend`.
   If the team's host or rules want the default branch `main`, name it so now: `git branch -m master main`
   in the meta repo, and `switch -c main` instead of `master` in each submodule.
   When `.gitmodules` no longer points at `uxname/*`, the project is in DERIVED mode
   (`.agents/OPERATING-MODE.md`) and nothing will ever push to the templates again.
   Done when both submodule URLs and all three `origin` remotes point at the team's
   repos (`git remote -v`, `git -C backend remote -v`, `git -C frontend remote -v`) — a
   real product left on `uxname/*` pushes into the public templates.
4. **Rename**:
   `scripts/rename-project.sh --name <name> --display "<Brand>" --repo-owner <owner>` —
   before installing, because it rewrites the Go module path and package names.
5. **Install and verify**: `scripts/setup.sh` — one command; it checks the toolchain, writes
   both `.env` files and runs `scripts/doctor.sh`. Fix any contract mismatch it reports;
   these fail silently at runtime otherwise.
6. **Run it**: `cd backend && task start:dev`, `cd frontend && npm run start:dev`. It worked
   when `http://localhost:3000` and `http://localhost:4000/readyz` both answer.
7. **Commit and push** with the meta **`/commit`** skill. Confirm with the user first — this
   is the project's first push. Submodules go first, the meta repo last: its commit points at
   submodule commits that must already exist on their remotes.

## Auth, and the one thing to say at hand-off

Local dev runs with `OIDC_MOCK_ENABLED=true` against a shared public dev Logto tenant. Real
auth means `OIDC_MOCK_ENABLED=false` and the backend's `OIDC_ISSUER`/`OIDC_JWKS_URI`/
`OIDC_AUDIENCE` matching the frontend's `VITE_OIDC_AUTHORITY`/`VITE_OIDC_API_RESOURCE` —
same tenant, same API resource. Tell the user it must be swapped before production.

