# Coding standards — what holds in all three repos

How anything that lands in a repo is written. Each sub-project's `AGENTS.md` and
`.agents/*.md` refine these for its stack, and win on conflict inside that sub-project.

## Tests and coverage floors

Coverage floors gate pushes on both sides: `backend/.testcoverage.yml` (one per package)
and `frontend/vitest.config.ts`. In every change:

- **New code ships with its tests** — tests that check behaviour, not ones written to
  touch lines.
- **Run the coverage task before you finish** (`task test:cov` / `npm run test:cov`), and
  when the measured numbers rose, **raise the floors to just under them in the same
  change** — a point or two of headroom, no more. A floor left below the real number is
  a hole new untested code can slip through.
- A floor only goes up: when one blocks you, write the missing test.
- A new backend package arrives with its own floor in `.testcoverage.yml`.

How each side tests: `backend/.agents/TESTING.md`, `frontend/.agents/TESTING.md`.

## Logs — a failure is findable

Why: [ADR-0004](../docs/adr/0004-logs-are-the-diagnostic-surface.md).

- The level is the severity: `ERROR` for what the system did wrong (5xx, internal GraphQL
  errors, failed jobs or queries, a crashed render), `WARN` for what the caller did wrong.
- Every failure path leaves exactly one line, at `WARN` or above.
- The backend's request id (`request_id` in logs, `extensions.requestId` to the client)
  joins the two sides' logs and survives the trip both ways — seam 4 in
  [CROSS-PROJECT.md](./CROSS-PROJECT.md).

## Commit messages

Conventional Commits, all lower case: `type(scope): summary` — `docs(adr):`,
`chore(submodules):`, `fix(scripts):`, `feat(likec4):`. The scope is the area you
touched; drop it only when the change is genuinely global.
