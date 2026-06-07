# docs/retro — session retrospectives

Each file here is the retrospective of **one work session**: what went **badly**, why, and
the **rule** that prevents repeating it. This folder is the project's accumulated memory of
mistakes — future agents read it *before* touching code so they don't relive them.

## Lifecycle

1. **Before any change** — the agent reads every `docs/retro/*.md` (in a separate
   thread/subagent, see root `AGENTS.md` → START HERE) and applies the distilled rules.
2. **At the end of a session, before committing** — the agent writes a new retro file
   (the `/retro` meta-skill, also invoked automatically as the first step of `/commit`).

## File naming

```
docs/retro/YYYY-MM-DD-<short-slug>.md
```

Example: `docs/retro/2026-06-07-prisma-migration-rollback.md`. Use the real date
(`date +%F`). The slug is the session's main topic.

## Format

Use [`TEMPLATE.md`](./TEMPLATE.md) verbatim. Hard rules so the reader subagent can scan fast:

- Frontmatter `date`, `topic`, `tags`, `area` (one of `backend` / `frontend` / `meta` /
  `cross`) is **mandatory** — the reader filters by `area` and `tags`.
- Record **only what went wrong** and the lesson. Successes don't belong here.
- Every problem needs a **rule** (imperative, one line) — that is what future agents act on.
- One concrete fact per bullet. No narrative, no fluff.

## What does NOT go here

- Things already captured by the code, git history, or `AGENTS.md`.
- Generic advice unrelated to a mistake that actually happened this session.
- Anything secret (`.env`, tokens, credentials).
