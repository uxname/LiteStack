---
date: 2026-06-20
topic: Audit of the TanStack Start SSR migration on frontend
area: frontend
tags: [fish-shell, grep, sentry, coverage, ssr-migration, observability]
---

## What went badly
- A `grep -rn "setUser" src/ --include=*.tsx` call failed with
  `(eval):1: no matches found: --include=*.tsx` — fish glob-expanded the bare
  `*.tsx` before grep saw it, so the command aborted and had to be re-run.
- The SSR migration (prior work, not this session) had silently dropped three
  Sentry effects (`setUser`, `captureException(auth.error)`,
  `addSilentRenewError`) when `main.tsx` was deleted. Every check stayed green —
  244 tests, ts:check, lint, build all passed — because the old `main.tsx` was
  in the Vitest coverage `exclude` list, so nothing measured that the logic
  vanished. Only a manual grep for `setUser` surfaced it.

## Root cause
- The shell here is **fish**, which expands unquoted globs in arguments itself;
  `--include=*.tsx` is not a file pattern fish can match in the cwd, so it errors
  instead of passing the literal through (bash would have passed it to grep).
- Coverage thresholds give false confidence: logic moved *out of* a
  coverage-excluded entry file (`src/main.tsx`, `src/app/providers/**`) leaves no
  coverage gap when it's dropped, so green tests do not prove the behavior
  survived the move.

## Rule — do this next time
- In fish, always quote glob arguments to grep/find: `grep -rn "x" src/ "--include=*.tsx"`
  or just `grep -rn "x" src/` and filter — never pass a bare `--include=*.tsx`.
- When migrating logic OUT of a coverage-excluded file (entry points,
  `src/app/providers/**`, `src/main.tsx`-style files), grep the old file's key
  symbols (`setUser`, event subscriptions, side-effect calls) against the new
  tree to confirm each one landed somewhere — coverage will not catch a silent
  drop here.
