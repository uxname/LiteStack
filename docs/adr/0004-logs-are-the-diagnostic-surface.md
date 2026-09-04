# ADR 0004: Logs are the only diagnostic surface, so a failure must be findable in them

- **Date:** 2026-09-04
- **Status:** accepted

## Context

There is no CI ([ADR-0001](./0001-no-ci-gates-live-in-git-hooks.md)), no metrics
backend, no tracing, and no log aggregator in this template. When something breaks in a
deployed LiteStack project, the evidence is `docker compose logs` and nothing else.

An audit of the two sides found that evidence missing in the exact places it was needed:

- A panicking HTTP request produced `panic_recovered` and **no** access-log line at all
  (the recoverer wrapped the access logger, so the panic unwound past it) — a 500 with
  no record of which URL caused it.
- Every request was logged at `INFO`, 5xx included, so `level=ERROR` — the filter this
  repo's own runbook recommends — selected nothing.
- GraphQL errors were logged only when they were internal **and** the build was
  production. `FORBIDDEN`, `BAD_USER_INPUT` and validation failures were logged nowhere,
  and GraphQL always answers HTTP 200, so the access log could not see them either.
- Background jobs and slow SQL had no link back to the request that caused them.
- On the frontend, every error path went through `captureException`, which is a **no-op**
  when no Sentry DSN was baked in at build time. An image built without a DSN reported
  nothing, anywhere. React render errors were not reported even with one.

## Decision

Everything that fails leaves a line, and that line is findable. Concretely, on both
sides:

1. **The level is the severity.** `ERROR` = the system's fault (5xx, internal GraphQL
   error, failed job, failed query, crashed render). `WARN` = the caller's fault (4xx,
   `UNAUTHENTICATED`, `FORBIDDEN`, `BAD_USER_INPUT`, a slow query). `INFO` = routine.
   `level=ERROR` is therefore an incident feed, not a category of message.
2. **One line per failure, with the original message.** Text masked for the client
   (production internal errors) is written to the log *before* it is masked.
3. **Everything is correlatable.** The backend's `request_id` is on every request-scoped
   line, travels into background jobs through the task payload, comes back to the client
   as `extensions.requestId`, and is shown to the user in the error screen.
4. **No error sink may be conditional on configuration.** Sentry is an *additional*
   copy; the console/stdout line always happens (`logError` on the frontend).

`msg` is a short stable slug (`http_request`, `graphql_error`, `job_failed`,
`db_query_slow`, `ssr_render_failed`, …) so a log is grepped by event, not by prose.

## Alternatives

- **Ship metrics and tracing (Prometheus + OpenTelemetry).** Answers "how often" and
  "where did the time go" far better than logs — and costs a collector, a backend and a
  dashboard the template cannot assume. Left as a documented upgrade path in
  `backend/docs/DEBUGGING.md`.
- **Rely on Sentry for the frontend.** It is optional by design (no DSN, no reports) and
  build-time-baked, so it cannot be the only copy. It stays as the second one.
- **Log every SQL query and every GraphQL variable.** The fastest way to make a log
  unreadable, and the fastest way to leak PII. Only slow/failed queries are logged, never
  their arguments; mutation variables are dropped wholesale.
- **Leave the frontend log to the e2e harness** (`npm run test:e2e:logs`). It needs a
  browser and a repo checkout — it cannot see a production incident.

## Consequences

- A failure can be taken from a user's screenshot to the server's account of it with one
  id, without reproducing it.
- The log is noisier: slow queries, all GraphQL errors and every 4xx now produce lines.
  The level split is what keeps that readable — grep `ERROR` first, widen to `WARN`.
- Middleware order is now load-bearing on the backend: `RequestLogger` **must** wrap
  `Recoverer`. A test in `internal/server/server_test.go` pins it, because the failure
  mode is silent — everything still works, the evidence just disappears.
- Every payload type in `internal/queue` must keep a `request_id` field; asynq has no
  headers, so correlation rides in the payload or not at all.
- Frontend code may not call `captureException` directly; `logError` is the sink. Nothing
  enforces this mechanically — it is a review rule, recorded in `frontend/AGENTS.md`.
- We still cannot answer "how many" or "how often" without adding metrics. That is the
  cost knowingly accepted here.
