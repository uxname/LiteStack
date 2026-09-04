# ADR 0001: No CI — the quality gates live in the submodules' git hooks

- **Date:** 2026-09-04
- **Status:** accepted

## Context

LiteStack is a boilerplate maintained by a single author and cloned into private derived
products on arbitrary git hosts. `PRD.md` states the constraint directly: the project
deliberately has no CI, and no solution may require one to appear.

The quality bar is not low, though: `backend/` runs `task check` (lint, arch-lint,
gitleaks, tests) and `frontend/` runs `npm run check` (Biome, tsc, knip, steiger, the
`shared/ui` trio check), both with machine-enforced per-package coverage floors. Something
has to run them, and it cannot be a hosted pipeline.

## Decision

Every gate runs locally, in each submodule's git hooks (`lefthook.yml`), on commit and on
push. There is exactly **one gate command per side** — `task check` in `backend/`,
`npm run check` in `frontend/` — and it is the same command a human runs by hand.

## Alternatives

- **GitHub Actions on every push** — ties the template to one host; derived products live
  on private hosts of the team's choice, and a workflow file that only works on GitHub is
  dead weight everywhere else.
- **Server-side hooks** — requires a host that allows them; same coupling, less visibility.
- **Trust the author to run checks manually** — the failure mode is silent and arrives as
  a broken clone for someone else.

## Consequences

- The gate is fast and offline, and it runs before the mistake reaches history rather than
  after — no red-build ping-pong.
- **`--no-verify` has nothing behind it.** Skipping the hook skips the entire guarantee,
  which is why every `AGENTS.md` repeats the prohibition. This is the accepted cost.
- Nothing enforces the gate on a machine that never installed the hooks: `npm install`
  (frontend) and `task` setup (backend) are what install them, so a fresh clone that
  skipped setup is unprotected. `scripts/doctor.sh` is the check for that.
- Commit-history discipline is deliberately **not** required (`PRD.md`): quality comes from
  the gates, not from how the commits are shaped.
- Adding CI later is not blocked — but it must not become the only place a gate runs, or
  the local guarantee degrades into a formality.
