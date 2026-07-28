# Operating mode & git topology — decide this BEFORE committing

LiteStack is used in one of two modes. **They differ only in where you commit and
push.** This is git-host agnostic — the repos can live anywhere, not only GitHub.

## How to detect

```bash
git config -f .gitmodules submodule.liteend-go.url
git config -f .gitmodules submodule.litefront.url
```

The canonical boilerplate upstreams are `uxname/liteend-go` and `uxname/litefront`
(currently on `github.com/uxname/*`).

- URLs still point at the canonical `uxname/*` upstreams → **TEMPLATE mode**.
- URLs point anywhere else (your own repos) → **DERIVED mode**.

## TEMPLATE mode — improving the boilerplate itself

You are evolving the LiteStack / LiteEnd / LiteFront templates, and a change may
touch all three repos:

1. Change code inside `backend/` and/or `frontend/` → commit **and push** in each
   submodule to its canonical upstream (needs write access there).
2. In the meta-repo: `git add backend frontend` to record the new submodule pointers,
   then commit (and push if the meta-repo has a remote).

Use this mode **only** to improve the boilerplate, never to build a product.

## DERIVED mode — building a real product on top of LiteStack

The submodules (and the meta-repo) point at **your own** repositories:

1. Change code inside `backend/` and/or `frontend/` → commit **and push** in each
   submodule to **its own** remote.
2. In the meta-repo: `git add backend frontend`, commit, push to **your** meta repo.

Never push a derived project's changes to the `uxname/*` upstreams.

> A derived project is a **snapshot fork**. We do **not** keep it in sync with the
> upstream templates: LiteEnd and LiteFront change often, sometimes with breaking
> changes, so chasing upstream costs more than it returns. Take the snapshot and own it.

## Git topology (both modes)

Each submodule is a **separate git repository** with its own history and remotes:

- Code changes inside `backend/` are committed **in the backend repo**.
- Code changes inside `frontend/` are committed **in the frontend repo**.
- The meta-repo commits only (a) updated submodule pointers and (b) its own files
  (`AGENTS.md`, `.agents/`, `README.md`, `docs/`, `scripts/`, `.claude/`).

Flow per change: `cd backend` → edit → run its gate → commit (+push) → `cd ..` →
`git add backend` → commit (+push) the meta-repo. The **`commit` skill** automates
this, retrospective included.

**Never put application code in the meta-project.** If you are writing a resolver, a
component or a migration, you are in the wrong directory.

## Two traps worth knowing

- **Treat the git index as untrusted after subagents run.** Agents that were told only
  to write files have staged and deleted things before. Run `git status` in all three
  repos afterwards, `git reset` anything you did not stage, then stage deliberately.
- **Check a gate's exit status, not the tail of its output.** `task check | tail` prints
  a happy-looking ending even when the task failed.
