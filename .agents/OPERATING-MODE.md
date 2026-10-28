# Operating mode & git topology — decide this BEFORE committing

LiteStack is used in one of two modes. **They differ only in where you commit and
push.** This is git-host agnostic — the repos can live anywhere, not only GitHub.

## How to detect

```bash
git config -f .gitmodules submodule.liteend-go.url
git config -f .gitmodules submodule.litefront.url
git config -f .gitmodules submodule.protokit.url   # empty once the prototype is removed
```

The canonical boilerplate upstreams are `uxname/liteend-go`, `uxname/litefront` and
`uxname/protokit` (currently on `github.com/uxname/*`).

- URLs still point at the canonical `uxname/*` upstreams → **TEMPLATE mode**.
- URLs point anywhere else (your own repos) → **DERIVED mode**.

## TEMPLATE mode — improving the boilerplate itself

You are evolving the LiteStack / LiteEnd / LiteFront templates, and a change may
touch all three repos:

1. Change code inside `backend/`, `frontend/` and/or `protokit/` → commit **and push** in
   each submodule to its canonical upstream (needs write access there).
2. In the meta-repo: `git add` the changed submodules to record the new pointers, then
   commit (and push if the meta-repo has a remote).

Use this mode **only** to improve the boilerplate, never to build a product.

## DERIVED mode — building a real product on top of LiteStack

The submodules (and the meta-repo) point at **your own** repositories:

1. Change code inside `backend/`, `frontend/` and/or `protokit/` → commit **and push** in
   each submodule to **its own** remote.
2. In the meta-repo: `git add` the changed submodules, commit, push to **your** meta repo.

### Removing the prototype

The prototype (`protokit/`) is there while it pays for itself (meta ADR-0011). When the
product no longer needs it — keeping it in line with the product costs more than it
returns — remove it in one meta commit:

```bash
git submodule deinit -f protokit && git rm protokit && git commit -m "Remove the prototype"
```

Nothing else changes: `docc.json`'s `protokit/...` masks then match nothing, the scripts
skip a missing prototype, and the meta's instructions never link to it. A requirement
whose only tag was in the prototype now fails `scripts/check-coverage.mjs`: tag it in the
product (or delete the paragraph) in the same commit. Its history stays in the
prototype's own repository.

Never push a derived project's changes to the `uxname/*` upstreams.

> A derived project is a **snapshot fork**. We do **not** keep it in sync with the
> upstream templates: LiteEnd and LiteFront change often, sometimes with breaking
> changes, so chasing upstream costs more than it returns. Take the snapshot and own it.

## Git topology (both modes)

Each submodule is a **separate git repository** with its own history and remotes:

- Code changes inside `backend/` are committed **in the backend repo**.
- Code changes inside `frontend/` are committed **in the frontend repo**.
- Prototype changes inside `protokit/` are committed **in the prototype repo**.
- The meta-repo commits only (a) updated submodule pointers and (b) its own files
  (`AGENTS.md`, `.agents/`, `README.md`, `docs/`, `scripts/`, `.claude/`).

Flow per change: `cd backend` → edit → run its gate → commit (+push) → `cd ..` →
`git add backend` → commit (+push) the meta-repo. The **`commit` skill** automates
this, retrospective included.
