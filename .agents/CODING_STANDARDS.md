# Coding standards — what holds in all three repos

How anything that lands in a repo is written. Each sub-project's `AGENTS.md` and
`.agents/*.md` refine these for its stack, and win on conflict inside that sub-project.

## Tests, coverage floors and logs

Each side owns its rules, so a submodule used on its own still carries them:
[backend/.agents/CODING_STANDARDS.md](../backend/.agents/CODING_STANDARDS.md) and
[frontend/.agents/CODING_STANDARDS.md](../frontend/.agents/CODING_STANDARDS.md).
What spans both: logs are the diagnostic surface
([ADR-0004](../docs/adr/0004-logs-are-the-diagnostic-surface.md)), and the backend's
request id (`request_id` in logs, `extensions.requestId` to the client) joins the two
sides' logs — seam 4 in [CROSS-PROJECT.md](./CROSS-PROJECT.md).

## Commit messages

Conventional Commits, all lower case: `type(scope): summary` — `docs(adr):`,
`chore(submodules):`, `fix(scripts):`, `feat(likec4):`. The scope is the area you
touched; drop it only when the change is genuinely global.
