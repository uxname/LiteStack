---
date: 2026-06-20
topic: Audit-driven test coverage, simplification & machine-enforced TDD gates across both submodules
area: cross
tags: [testing, tdd, coverage, go-test-coverage, go-arch-lint, ladle, stylelint, workflow-agents, ci]
---

## What went badly
- Workflow subagents ran `git add` even though their prompts said "run no git commands".
  This staged everything — including junk (`.ladle/` build artifacts as `AD` entries) — so
  the index was not trustworthy and had to be audited and partially reset before committing.
- Running Ladle (`storybook:build` / `ladle`) to "verify stories" generated `.ladle/styles.css`
  and a stray `frontend/tmp/.../ladle-build/` tree. `npm run check` then FAILED on stylelint
  (`rule-empty-line-before`, `rgba`→`rgb`) because the lint glob `**/*.{css,scss}` matched
  those artifacts — a gate that had passed minutes earlier suddenly broke for an unrelated reason.
- The backend Phase-3 "JSON cache helper" refactor (making `internal/profile` import
  `internal/redis`) failed `task arch`: `Dependency domain --> infrastructure not allowed`.
  Had to be fully reverted.
- Setting backend per-package coverage floors cost several probe iterations: `go-test-coverage`
  `override` rules silently did nothing at first because the path was written as the full
  import path (`^github.com/uxname/liteend-go/internal/queue$`).
- Two of the initial audit Explore agents reported confidently wrong specifics: middleware
  files "700–1500 lines" (actually 28–60) and deps "outdated, upgrade Vitest to 6.x"
  (4.1.8 was current for this timeline). Acting on those would have produced bogus changes.

## Root cause
- Subagent prompts said "no git" but the agents did not honour it, and the orchestrator did
  not assume that — the index was trusted instead of verified.
- `.stylelintignore` / `.gitignore` covered `dist/`, `coverage/`, `storybook-build/` but NOT
  Ladle's auto-generated `.ladle/` dir (which contains a `styles.css`). A latent gate gap that
  only bites once someone runs Ladle.
- The `domain` layer is deliberately decoupled from `infrastructure` via interfaces
  (`profile.Cache` is satisfied structurally by `redis.Client`); `.go-arch-lint.yml` forbids
  `domain → infrastructure`. The refactor traded that dependency-inversion for a marginal DRY win.
- `go-test-coverage` matches `override.path` against the MODULE-RELATIVE package path
  (`internal/queue`), not the full import path — and only evaluates per-package thresholds when
  `threshold.package > 0` OR at least one package-`override` is present. `exclude.paths` (which
  use the full path) do NOT apply to the per-package check.
- Explore/agent output about file sizes and dependency versions is not ground truth.

## Rule — do this next time
- When spawning workflow agents that only write files, treat the git index as untrusted:
  after they finish, run `git status` and unstage anything they staged (`git reset`), then
  stage deliberately yourself. Better: tell agents to write files only and never to run
  `git`, `npm run check`, `test:cov`, or build/serve commands (`ladle`, `storybook:build`).
- Keep build-tool artifact dirs out of BOTH `.gitignore` and `.stylelintignore` —
  specifically `.ladle/` and `tmp/` for the frontend (Ladle regenerates `.ladle/styles.css`
  on every serve/build). If a gate that just passed starts failing, check for stray artifacts
  before debugging "real" code.
- Before any refactor that adds a cross-package import on the backend, check
  `.go-arch-lint.yml` allowed deps. `domain` may NOT import `infrastructure` — keep domain
  decoupled via its own narrow interfaces; do not import `internal/redis`, `internal/db`, etc.
- In `backend/.testcoverage.yml`, write `override.path` as the MODULE-RELATIVE package path
  (`^internal/queue$`), never the full import path. Per-package overrides activate the
  per-package gate on their own; `exclude.paths` does not cover them.
- Verify agent-reported specifics (file line counts, dependency versions, "X is outdated")
  directly with `wc -l` / the manifest before acting — audit-agent claims are frequently wrong.
