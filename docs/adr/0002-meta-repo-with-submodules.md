# ADR 0002: A meta-repo with two submodules, not a monorepo

- **Date:** 2026-09-04
- **Status:** accepted

## Context

The backend (`liteend-go`) and the frontend (`litefront`) are usable on their own: each is
a standalone template with its own repository, its own gates and its own release life.
LiteStack exists to bundle them and describe the seams — it owns no application code.

Deriving a product means repointing the two submodule URLs at the team's own repos
(`.agents/DERIVE.md`), which is also how TEMPLATE mode is told apart from DERIVED mode
(`.agents/OPERATING-MODE.md`): the submodule URLs *are* the mode switch.

## Decision

The meta-repo carries `backend/` and `frontend/` as git submodules and records their
pointers. Application code never lands in the meta-repo; it only coordinates — the seams,
the cross-project skills, the operating mode.

## Alternatives

- **Monorepo with two packages** — one clone, one history, atomic cross-cutting commits.
  Rejected: the two sides would stop being independently usable templates, and deriving a
  product would mean carrying the other side's history whether you use it or not.
- **Three unrelated repos, no meta** — nothing would own the seams (codegen contract, auth
  audience, CORS/WebSockets, the env contract), and they are exactly what breaks.
- **Vendoring one side into the other** — makes one side a second-class citizen and
  duplicates the gate setup.

## Consequences

- Each side can be adopted alone, and a derived product swaps both remotes without
  rewriting history.
- **A cross-cutting change is three commits and several PRs** (`docs/TEAM.md`), and the
  submodule pointers must be recorded in the meta-repo or the change is invisible to
  anyone who clones. `PRD.md` accepts this risk explicitly; the `commit` skill exists to
  make the sequence mechanical.
- A stale pointer looks like "the fix didn't work" on someone else's clone — the most
  common confusion this topology creates.
- Tooling has to be submodule-aware: after any subagent run, treat the git index in all
  three repos as untrusted (root `AGENTS.md`).
