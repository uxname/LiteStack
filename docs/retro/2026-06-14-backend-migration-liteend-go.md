---
date: 2026-06-14
topic: Migrate the backend submodule from NestJS liteend to Go liteend-go
area: meta
tags: [submodule, migration, skills, rename, grep]
---

## What went badly
- After repointing the `backend` submodule (logical name `liteend` → `liteend-go`) and
  rewriting the obvious docs, stale references to the OLD submodule name and stack survived
  in non-obvious meta files: `submodule.liteend.url` in `.claude/skills/commit/SKILL.md`
  (the operating-mode detection snippet) and `NestJS · Prisma · Mercurius` + `npm run
  db:migrations:apply` in root `README.md`. They were only caught by a final repo-wide grep,
  not while editing the files I expected to touch.
- First instinct for the meta-CI fix was to keep a single `[backend, frontend]` matrix; that
  is wrong once the two submodules use different stacks (Go `task` vs npm) — the job steps
  diverge, so the matrix had to be split into two jobs.

## Root cause
- The submodule's logical name is embedded in `git config -f .gitmodules submodule.<NAME>.url`
  lookups scattered across skills and docs, not just in AGENTS.md. Editing "the files about
  the backend" misses these because they live in cross-cutting skills/README.
- A CI matrix encodes the assumption that every matrix entry runs the same steps. Swapping one
  entry to a different toolchain breaks that assumption silently (the job just runs the wrong
  commands) rather than failing loudly.

## Rule — do this next time
- When renaming a submodule or swapping its stack, run a repo-wide grep for BOTH the old
  logical name and old stack tokens BEFORE declaring done — e.g.
  `grep -rniE 'submodule\.<oldname>\.url|<OldStack>' AGENTS.md README.md docs .github scripts .claude/skills`.
  Treat the `.claude/skills/*` and `README.md` as first-class targets, not afterthoughts.
- When two CI matrix entries no longer share a toolchain, split them into separate jobs with
  their own steps — never force divergent stacks through one matrix body.
