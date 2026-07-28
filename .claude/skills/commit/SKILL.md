---
name: commit
description: Commit changes across the LiteStack meta-repo and its submodules. Use this when the user asks to commit, save changes to git, or "commit this" while working at the LiteStack root. It commits inside each changed submodule first, then records the updated submodule pointers in the meta-repo, and pushes according to the operating mode (template vs derived).
---

The user wants to commit work done across LiteStack. Because `backend/` and `frontend/`
are **separate git repositories** (submodules), a meta-level commit is a few ordered steps,
not one `git commit`. Get the order right or the meta-repo will point at commits that were
never pushed.

## Step 0: Write the session retrospective (mandatory)

Before anything else, run the **`/retro` skill** to record what went badly this session into
`docs/retro/`. This is the project's mistake-memory that future agents read before touching
code (root `AGENTS.md` → START HERE). Skip the file write **only** if the session was
genuinely clean — but always run the skill so that judgement is made deliberately, not by
omission. The retro file is a meta-repo file; it gets staged and committed in Step 4–5 below.

## Step 1: Detect the operating mode

Read root `AGENTS.md` → Operating mode. In short:

```bash
git config -f .gitmodules submodule.liteend-go.url
git config -f .gitmodules submodule.litefront.url
```

- URLs point at canonical `uxname/*` → **TEMPLATE mode** (push submodules to upstream).
- URLs point at your own repos → **DERIVED mode** (push submodules to your repos).

If you are unsure which mode applies or whether you should push, ask the user in plain
language before pushing.

## Step 2: See what changed and where

```bash
git status                  # at meta root: shows which submodules are dirty + meta files
git submodule status
```

## Step 3: Commit inside each changed submodule

For **each** submodule that has changes (`backend` and/or `frontend`):

```bash
cd <submodule>
# Run that project's own gate FIRST, from its AGENTS.md:
#   backend  → task check      (and task test:cov before pushing)
#   frontend → npm run check   (verify:push runs on pre-push)
git add -A && git commit       # conventional commits; the pre-commit hook re-runs the gate
git push                       # push to the submodule's remote (per the detected mode)
cd ..
```

Do not skip the submodule's pre-commit / pre-push hooks. Never use `--no-verify` —
there is no CI behind them.

> Check the **exit status** of each gate, not the tail of its output. A
> `task check | tail` reports success even when the task failed.

## Step 4: Record the updated pointers in the meta-repo

```bash
git add backend frontend       # stage the new submodule commit pointers
git add -A                     # also stage any changed meta files (AGENTS.md, docs/retro/, etc.)
git status                     # review — never stage secrets (.env, credentials)
```

## Step 5: Commit the meta-repo

Conventional commits format:

```
<type>(<scope>): <short description>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. For meta-repo commits the scope
is usually the area (`agents`, `submodules`, `docs`) or omitted. Example:

```
chore(submodules): bump backend + frontend for user-avatar feature
```

```bash
git commit -m "<your message>"
```

## Step 6: Push the meta-repo (if it has a remote)

```bash
git push
```

In TEMPLATE mode push to the canonical meta repo (needs access). In DERIVED mode push to
your own meta repo. If there is no remote yet, say so and stop.

## What NOT to do

- Never push a derived project's submodule changes to the `uxname/*` upstreams.
- Never commit the meta-repo pointer before the submodule commit is pushed — the pointer
  would reference a commit nobody else can fetch.
- Never skip hooks with `--no-verify`.
- Never `git add` unreviewed files that may contain secrets (`.env`, keys, credentials).
