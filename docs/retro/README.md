# docs/retro — session retrospectives

One file per work session: what went **badly**, why, and the **rule** that prevents
repeating it. Future agents read this folder before touching code. Write one at the end
of a session, before committing — the `/retro` skill does it.

**This folder is empty in the template on purpose.** LiteStack ships no retros of its own:
a derived project starts with a clean memory and fills this folder with *its* mistakes. An
empty folder here is the expected state, not a gap to fix.

## File naming

`docs/retro/YYYY-MM-DD-<short-slug>.md` — the real date (`date +%F`), slug = the session's
main topic. Example: `2026-06-07-prisma-migration-rollback.md`.

## Format

Use [`TEMPLATE.md`](./TEMPLATE.md) verbatim. Frontmatter `date`, `topic`, `tags`, `area`
(`backend`/`frontend`/`meta`/`cross`) is **mandatory**. Record only what went wrong; every
problem gets a one-line imperative rule; one fact per bullet.

## When there are many of them

Read them in a separate thread so they do not bloat the working context — give a subagent
this instruction: *read every `docs/retro/*.md` (skip `README.md` and `TEMPLATE.md`) and
return ONLY a deduplicated, compact list of the "Rule — do this next time" lines, grouped
by area (backend / frontend / meta / cross); no file dumps, no narrative.*
