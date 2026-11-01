# ADR 0012: dependency updates are manual; GitHub only alerts

- **Date:** 2026-11-01
- **Status:** accepted

## Context

`renovate.json` sat in the meta-repo, `backend/` and `frontend/` (ADR-0007 says
"dependency updates run through `renovate.json`"), but the Renovate app was never
installed: by November 2026 every repo had drifted — 36 outdated npm packages in
`frontend/`, ~230 Go modules, Docker digests months old — and the Node 24 the hooks ran
on missed the October 2026 security release. There is no CI (ADR-0001) and template
changes go straight to `master`, so a bot's pull requests would each have to be checked
out and gated by hand anyway. Every Docker image is pinned by digest, which only a bot
or a person ever moves.

## Decision

Nobody bumps dependencies automatically. A person (or an agent) updates them on purpose:
`task update` in `backend/`, `npm run update` or `npx ncu -u <pkg>` in `frontend/` (holds
with their reason live in `frontend/.ncurc.yml`), the same `ncu` in
`protokit/prototype/`, and every `image:` / `FROM` digest refreshed with
`docker buildx imagetools inspect <image>:<tag>` (the multi-arch index digest, never a
single-platform one). GitHub Dependabot **alerts** — notifications only, no pull
requests — are on in all four repos and say when that is urgent. Node is enforced by
`devEngines` (`onFail: error`) in each `package.json`, so `npm install` and every
`npm run`, the hooks included, refuse a Node older than the floor.

## Alternatives

- **Install the Renovate app.** It opens PRs, but with no CI each PR is a manual checkout
  plus a full local gate — the same work as a manual sweep, spread over dozens of PRs.
- **Drop the digests and pin tags only.** Rebuilds would pick up base-image patches by
  themselves, but two builds of one commit could differ and a re-pushed tag would go
  unnoticed.
- **Nothing instead of Renovate.** Leaves no signal at all; the October 2026 Node CVEs were
  found by accident.

## Consequences

- Freshness costs a deliberate sweep; Dependabot alerts cover npm and Go lockfiles but
  not Node itself or Docker images — watch the Node security releases page and refresh
  digests on every sweep.
- Raising the Node floor means editing `devEngines`, `engines`, the Dockerfiles and
  `scripts/setup.sh` together.
- The sentence about Renovate in ADR-0007 no longer holds; this record replaces it.
