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
   ignore the line. After renaming, run both projects' gates **including the E2E suite**:
   three test files assert brand strings (two unit, one E2E), so a partial rename shows up
   as failing tests — and one of them only fails in `verify:push`.
5. **Install and wire env:** `scripts/setup.sh`, then copy `.env.example` → `.env` in each
   submodule (the meta `setup.sh` does not create them) and confirm `scripts/doctor.sh`
   passes — see [../docs/ENV-CONTRACT.md](../docs/ENV-CONTRACT.md).
6. From here every commit and push targets **your** repos (see
   [OPERATING-MODE.md](./OPERATING-MODE.md)).

## What the rename covers, and what it can't

It renames:

- the machine identity — frontend package name, docker network, and the theme
  `localStorage` key in **all three** places it appears (the store, the pre-paint script
  in `__root.tsx`, and the screenshot harness that seeds it);
- the brand shown in the UI and in page titles — including the **three test files** that
  assert those strings, so a complete rename leaves the gates green;
- with `--repo-owner`: the demo repo references and the install command the landing page
  copies, **and** the backend's Go module path
  (`github.com/uxname/liteend-go` → `github.com/<owner>/<name>`) across `go.mod` and
  every backend `*.go` import — about 40 files.

It does **not** touch: your own new code, README/docs prose, or anything added after the
file lists in the script were last updated. Grep for the old brand once more when you are
done:

```bash
grep -rn 'LiteFront\|litefront\|liteend' frontend/src frontend/tests backend --exclude-dir=node_modules
```
