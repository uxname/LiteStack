---
date: 2026-08-13
topic: DevOps overhaul — compose split, registry vars, non-root, backup-subsystem removal
area: cross
tags: [docker, compose, gates, workflow, lint]
---

## What went badly
- A backgrounded `task check` reported "completed (exit code 0)" while the gate had
  actually FAILED (`bodyclose: 3` → `task: Failed to run task "lint": exit status 1`).
  The wrapper `bash -lc 'task check > log; echo "EXIT=$?"'` ends with `echo`, so the
  wrapper's own exit is always 0.
- A subagent's new `internal/graph/handler_test.go` leaked `*http.Response` bodies.
  Its `go build`/`go test`/`go vet` validation was green; only golangci's `bodyclose`
  (run later, centrally) caught it — the agent had been told to skip `task check` to
  avoid racing a concurrent agent in the same repo.
- A Workflow script passed stage-1 results to the stage-2 agent as
  `${'${JSON.stringify(x)}'}` — the agent received the literal string
  `${JSON.stringify(x)}` instead of the data. Recovered only because the prompt also
  said "verify everything against the files on disk".
- The first version of `docker-compose.prod.yml` kept a `build:` fallback: a failed
  registry pull silently rebuilt from the host's source tree and tagged it with the
  registry name (exit 0). Same class: the fixed `litefront:latest` tag let `up -d`
  reuse another environment's baked bundle. Both shipped and were caught only by the
  adversarial-review pass actually exercising the failure paths.

## Root cause
- Judging a gate by the wrapper's exit code instead of the gate's own status marker
  inside the log (a new variant of the known "piped output" false-green).
- Splitting one repo between concurrent agents forces per-package validation, and
  `go vet`/`go test` do not cover golangci-only analyzers — nobody re-ran the full
  gate before believing the diff was clean until the central pass.
- Writing `${...}` escapes by analogy with compose-variable escaping, without checking
  what the built prompt actually contained.
- Compose semantics (`image:`+`build:` interplay, pull-failure fallback, tag reuse-if-
  present) were designed from memory; only the happy path was tested before review.

## Rule — do this next time
- Background a gate as `cmd > log 2>&1; echo "EXIT=$?" >> log` and read that marker
  from the log; the wrapper command's exit code is always meaningless.
- After parallel agents finish in one repo, run that repo's FULL gate centrally before
  trusting the diff — agent-level `go build`/`go test`/`go vet` never covers
  golangci-only analyzers (bodyclose, depguard, …).
- In a Workflow script, interpolate context with plain `${expr}` inside the template
  literal (escape only compose-style `\${VAR}` meant to stay literal), and check the
  persisted script file for the literal `${` before launching stage 2.
- For deploy artifacts, test the failure paths, not the happy path: a prod compose
  file must not contain `build:` (failed pull must fail the deploy), and any fixed
  image tag + `up -d` silently reuses whatever last claimed the tag.
