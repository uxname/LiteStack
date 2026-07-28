# Deriving a new project from LiteStack

To start a real product (switching to DERIVED mode), use the **`new-project` skill** —
it drives the whole flow on top of the tested `scripts/*.sh` backbone: scaffold →
repoint → rename → install → wire env → verify → first commit.

The mechanical core, if you do it by hand:

1. **Create your own repos** for the meta, backend and frontend on any git host (fork or
   push copies of the `uxname/*` templates). You may keep the template as an `upstream`
   remote, but note we do not chase upstream changes.
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
   Always run `--dry-run` first and read it. The script edits a **fixed list** of files,
   so a brand string in a file it doesn't know about survives the rename. If the dry run
   prints `skip (missing)`, the list has drifted from the tree — fix the list, don't
   ignore the line. After renaming, run both projects' gates: two test files assert
   brand strings, so a partial rename shows up as failing tests.
5. **Install and wire env:** `scripts/setup.sh`, then copy `.env.example` → `.env` in each
   submodule (the meta `setup.sh` does not create them) and confirm `scripts/doctor.sh`
   passes — see [../docs/ENV-CONTRACT.md](../docs/ENV-CONTRACT.md).
6. From here every commit and push targets **your** repos (see
   [OPERATING-MODE.md](./OPERATING-MODE.md)).

## What the rename covers, and what it can't

It renames the machine identity (package name, docker network, the theme
`localStorage` key **in both places it appears**), the brand shown in the UI and page
titles, and — with `--repo-owner` — the demo repo references including the install
command the landing page copies.

It does **not** touch: your own new code, the backend's Go module path, README prose, or
anything added after the list was last updated. Grep for the old brand once more when
you are done.
