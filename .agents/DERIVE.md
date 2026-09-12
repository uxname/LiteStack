# Deriving a new project from LiteStack

To start a real product (switching to DERIVED mode), use the **`new-project` skill** —
it drives the whole flow on top of the tested `scripts/*.sh` backbone: scaffold →
repoint → rename → install → wire env → verify → first commit.

The mechanical core, if you do it by hand:

1. **Create your own repos** for the meta, backend and frontend on any git host (fork or
   push copies of the `uxname/*` templates). **Create all three as private repositories.**
   A derived product is your own code, not a template; making a repo public is a separate,
   deliberate decision you take later, not the default. You may keep the template as an
   `upstream` remote, but note we do not chase upstream changes.
2. **Re-point the submodules:**
   ```bash
   git config -f .gitmodules submodule.liteend-go.url <your-backend-repo-url>
   git config -f .gitmodules submodule.litefront.url  <your-frontend-repo-url>
   git submodule sync
   ```
3. **Set the meta-repo `origin`** to your meta repo and push.
4. **Rename the template identity:**
   ```bash
   scripts/rename-project.sh --name <name> --display "<Brand>" --repo-owner <owner> --dry-run
   scripts/rename-project.sh --name <name> --display "<Brand>" --repo-owner <owner>
   ```
   Always run `--dry-run` first and read it. After renaming, run both projects' gates
   **including the E2E suite**: three test files assert brand strings (two unit, one
   E2E), so a partial rename shows up as failing tests — one only in `verify:push`.
5. **Install and wire env:** `scripts/setup.sh`, then copy `.env.example` → `.env` in each
   submodule (the meta `setup.sh` does not create them) and confirm `scripts/doctor.sh`
   passes — see [../docs/ENV-CONTRACT.md](../docs/ENV-CONTRACT.md).
6. From here every commit and push targets **your** repos (see
   [OPERATING-MODE.md](./OPERATING-MODE.md)).

## What the rename covers, and what it can't

It renames the machine identity (frontend package name and lock, docker network, the
theme `localStorage` key in all three places), every frontend file carrying the brand
word — the list is searched, not kept by hand — and, with `--repo-owner`, the demo repo
references and the backend Go module path across `go.mod` and every backend `*.go`.

It does **not** touch the backend's own brand strings, which are UI text:
`internal/version/version.go` (`AppName`), the dev launcher and Swagger pages in
`internal/devtools/`, and the GraphQL playground title in `internal/graph/handler.go`.
Rename those by hand if the backend dev surfaces are user-visible in your product. Nor
your own code or README prose.

Three substitutions are anchored (machine name, brand word, repo owner), so grep once
more when you are done — it is cheap insurance:

```bash
grep -rn 'LiteFront\|litefront\|liteend' frontend backend \
  --exclude-dir={node_modules,.output,.nitro,dist,generated}
```