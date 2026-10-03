See [AGENTS.md](./AGENTS.md) — it is the single entry point for this meta-repo.
Then read `backend/AGENTS.md` and `frontend/AGENTS.md` for the sub-projects.

## Coverage floors only go up

Both sub-projects gate pushes on coverage floors (`frontend/vitest.config.ts`,
`backend/.testcoverage.yml`). In every change:

- **New code ships with its tests** — tests that check behaviour, not ones written
  to touch lines.
- **Run the coverage task before you finish**, and when the measured numbers rose,
  **raise the floors to just under them in the same change** (a point or two of
  headroom, no more). A floor left below the real number is a hole new untested
  code can slip through.
- **Never lower a floor** to get green — write the missing test.
- A new backend package arrives with its own floor in `.testcoverage.yml`.
