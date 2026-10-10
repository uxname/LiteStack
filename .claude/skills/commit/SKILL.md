---
name: commit
description: Commit changes across the LiteStack meta-repo and its submodules. Use when the user asks to commit or push from the LiteStack root. It commits inside each changed submodule first, then records the updated submodule pointers in the meta-repo, and pushes according to the operating mode (template vs derived).
---

The user wants to commit work done across LiteStack. Because `backend/` and `frontend/`
are **separate git repositories** (submodules), a meta-level commit is a few ordered steps,
not one `git commit`. Get the order right or the meta-repo will point at commits that were
never pushed.

## Step 0: Write a retrospective — only if the session earned one

Run the **`/retro` skill** only if something actually went wrong: a command failed, a
change had to be rolled back, or the approach changed mid-way. A one-file documentation
fix does not need one. Whether its file is staged in Step 4 depends on the mode — the
retro skill's Step 4 decides.

## Step 1: Detect the operating mode

Read root `.agents/OPERATING-MODE.md`. In short:

```bash
git config -f .gitmodules submodule.liteend-go.url
git config -f .gitmodules submodule.litefront.url
```

- URLs point at canonical `uxname/*` → **TEMPLATE mode** (push submodules to upstream).
- URLs point at your own repos → **DERIVED mode** (push submodules to your repos — every
  push goes to the team's remotes; the `uxname/*` upstreams receive only template work).

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
git status                     # review what is there before staging
git add <file>...              # stage by name, as in Step 4
git commit                     # conventional commits; the pre-commit hook re-runs the gate
git push                       # push to the submodule's remote (per the detected mode)
cd ..
```

Every commit and push runs the hooks in full — they are the only gate, there is no CI
behind them (`--no-verify` is never an option).

> Check the **exit status** of each gate, not the tail of its output. A
> `task check | tail` reports success even when the task failed.

## Step 4: Record the updated pointers in the meta-repo

```bash
git status                     # review — never stage secrets (.env, credentials)
git add backend frontend       # stage the new submodule commit pointers
git add <file>...              # stage changed meta files by name (AGENTS.md, docs/retro/, etc.)
```

Stage by name, not `git add -A`: after subagents run, the index may hold changes nobody
asked for (root `AGENTS.md` → Guardrail).

## Step 5: Commit the meta-repo

Format: [`.agents/CODING_STANDARDS.md` → Commit messages](../../../.agents/CODING_STANDARDS.md).
Example:

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

