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

## Retention & scaling

Retros accumulate. To keep the read-before-coding step cheap:

- The reader (root `AGENTS.md` → START HERE) already **deduplicates rules** across all files,
  so volume degrades gracefully — never delete a retro just to shorten the list.
- When a rule has become a permanent convention, **promote it into `AGENTS.md`** (the relevant
  sub-project's, or the root) and note in the retro that it was promoted. Promoted rules no
  longer need to be re-derived each session.
- A retro is **superseded**, not deleted, when its lesson is wrong or obsolete — append a short
  note at the top pointing to what replaced it. Keep the historical record.

## What does NOT go here

- Things already captured by the code, git history, or `AGENTS.md`.
- Generic advice unrelated to a mistake that actually happened this session.
- Anything secret (`.env`, tokens, credentials).
