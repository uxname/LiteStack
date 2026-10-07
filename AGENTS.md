# AGENTS.md — LiteStack (meta-repo)

LiteStack is a full-stack boilerplate: two projects as git submodules — `backend/`
(liteend-go) and `frontend/` (litefront), each its own repo — plus this thin layer that
only **coordinates** them. Application code always lives in a submodule: a resolver, a
component or a migration at this root means you are in the wrong folder.

## Every task

1. **Lessons first.** If `docs/retro/` holds dated files, read their "Rule" lines before
   touching code ([how](./docs/retro/README.md)).
2. **Go to the box that owns the change** (table below) and read that sub-project's
   `AGENTS.md`; it routes on to its `.agents/*.md`. Inside a sub-project, its rules win
   over this file.
3. **Write to the standard.** Code, tests, log lines and commit messages follow
   [.agents/CODING_STANDARDS.md](./.agents/CODING_STANDARDS.md). Everything committed is
   English, whatever language the chat is in.
4. **A structural decision gets an ADR the same session**, before the code lands —
   criteria in [docs/adr/README.md](./docs/adr/README.md). Before changing an area, read
   the ADRs that cover it.
5. **Done means the gate is green by exit status**, never by the tail of its output:
   `task check` in `backend/`, `npm run check` in `frontend/`, the hook in
   [lefthook.yml](./lefthook.yml) here. There is no CI
   ([ADR-0001](./docs/adr/0001-no-ci-gates-live-in-git-hooks.md)): the hooks are the only
   gate, so every commit and push runs them in full.

## Where to go

| Your task | Go to |
|---|---|
| API, database, business logic, jobs, server-side GraphQL | [backend/AGENTS.md](./backend/AGENTS.md) |
| UI, routing, client state, styling, GraphQL the browser sends | [frontend/AGENTS.md](./frontend/AGENTS.md) |
| A feature on both sides | backend first — the `full-stack-feature` skill |
| A back ↔ front **seam** (codegen, auth audience, CORS + WebSockets, `requestId`), or who owns a shared value | [.agents/CROSS-PROJECT.md](./.agents/CROSS-PROJECT.md) |
| An **env var** both sides must agree on | [docs/ENV-CONTRACT.md](./docs/ENV-CONTRACT.md) |
| **Commit or push**: template vs derived mode decides the remote | the `commit` skill; rules in [.agents/OPERATING-MODE.md](./.agents/OPERATING-MODE.md) |
| **Derive** a real product from the template | [.agents/DERIVE.md](./.agents/DERIVE.md) |
| A change to boundaries, protocols or components — the **architecture model** moves in the same change | `docs/architecture/likec4/` ([ADR-0003](./docs/adr/0003-living-likec4-model.md)) |
| **Deploy**: local Docker, Dokploy, registry images | [docs/DEPLOY.md](./docs/DEPLOY.md) |
| **First-time setup** of a clone, toolchain | [README.md](./README.md) → "Getting started" |
| **See** what the frontend does at runtime (you have no browser) | [frontend/.agents/OBSERVABILITY.md](./frontend/.agents/OBSERVABILITY.md) |
| **Triage** a failure from the logs | [backend/docs/DEBUGGING.md](./backend/docs/DEBUGGING.md), then the row above |
| **Team process**, or adding agent guidance or a skill | [docs/TEAM.md](./docs/TEAM.md) |

## Guardrail

After subagents run, the git index is untrusted — agents told only to write files have
staged and deleted things before. `git status` in all three repos, `git reset` what you
did not stage, then stage deliberately.

## Talking to the user

Explain as to a junior developer: short sentences, jargon defined on first use, concrete
steps. Each decision gets one plain line — what you did and why.
