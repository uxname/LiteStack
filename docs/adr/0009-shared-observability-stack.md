# ADR 0009: One shared observability stack — OpenObserve, GlitchTip, Rybbit — documented here, wired in derived projects

- **Date:** 2026-10-10
- **Status:** accepted

## Context

[ADR-0004](./0004-logs-are-the-diagnostic-surface.md) made logs the only diagnostic surface
and left metrics and tracing as an upgrade path. Products built from LiteStack now need
more: people and AI agents must see what broke in the code, how the running system
behaves, and how users move through the product — and be alerted without watching.

Constraints:

- The whole stack must run on **one server of 8 GB RAM or less**, shared by every product.
- Self-hosted PostHog needs 16 GB and more; Rybbit (ClickHouse + Postgres) needs 2–4 GB,
  OpenObserve 1–2 GB at a small log volume, GlitchTip about 1.5 GB.
- OpenObserve's open-source edition has no issue workflow for errors, and its source-map
  support and MCP server are Enterprise-only.
- GlitchTip accepts the Sentry SDK protocol only, has no alerting on arbitrary
  conditions, and cannot send to Telegram without a bridge.
- The frontend template already ships the Sentry SDK, with three defects: every built
  image reports `environment: production`, the Docker build emits no source maps, and
  Session Replay is recorded although GlitchTip cannot ingest it.

## Decision

Every product reports to one shared stack, and each question has exactly one tool:

| Question | Tool |
|---|---|
| What broke in the code (frontend and backend)? | **GlitchTip** — grouped issues, stacks, releases |
| What is the system doing? Logs of every container, metrics, traces, **all alerts** | **OpenObserve** (open-source edition), fed by an OpenTelemetry Collector on each product server |
| How do users move through the product? | **Rybbit** — funnels, retention, journeys, session replay |
| Did the deploy work, is the host overloaded? | **Dokploy** |

Alerts go to Telegram from OpenObserve and Dokploy. Backend and SSR errors need no
GlitchTip alert: each is also a `level=ERROR` log line (ADR-0004), which OpenObserve
alerts on. Browser errors never reach a server log, so they are the one case for a
GlitchTip alert (by email) on the frontend project.

The template carries **documentation, not integration**: `docs/observability/` describes
how to deploy the stack and how a derived project connects to it. SDKs, tracing and
product events are added in the derived project. The one exception is the Sentry SDK the
frontend already ships, which is fixed in place: a runtime `VITE_APP_ENV` key sets the
environment (extending the runtime keys listed in
[ADR-0005](./0005-horizontal-scaling-and-runtime-frontend-config.md)), the build uploads
hidden source maps when given a token and a `VITE_SENTRY_URL`, and Session Replay and
browser tracing are removed.

Agents and people read the stack the same way: through each tool's API or CLI. MCP
servers are an optional convenience where they are free.

## Alternatives

- **Self-hosted PostHog** — the best product analytics with feature flags and
  experiments, but it does not fit in 8 GB.
- **PostHog Cloud** — fits, but user data leaves our servers.
- **OpenObserve alone (with its RUM)** — one system, but no issue lifecycle for errors,
  no ready-made funnels for people, and source maps only with an Enterprise licence.
- **GlitchTip and Rybbit without OpenObserve** — lighter, but no alerts on arbitrary
  conditions and no logs from containers without an SDK (Postgres, Redis, Traefik).
- **Grafana stack (Loki, Prometheus, Tempo, Grafana)** — the industry default, but four
  services to run instead of one.
- **Integration code in the template, switched off by empty variables** — every derived
  project would get it for free, but the template would grow three SDKs most small
  projects never turn on.

## Consequences

- A derived project gets errors, system telemetry and product analytics by following
  `docs/observability/CONNECT.md`; the template itself stays as light as before.
- The stack is one server to keep alive, back up and upgrade. If it is down, products
  keep working but are blind.
- Memory is tight: ClickHouse and OpenObserve need explicit limits, and the budget in
  `docs/observability/STACK.md` must be kept current when a component is upgraded.
- Errors appear in two places on purpose — as a log line (alert) and as a GlitchTip issue
  (triage). Turning on logs or traces in GlitchTip would make that three; it stays off.
- Frontend source maps upload from `npm run build` as a debug-ID artifact bundle, which
  GlitchTip 6.1 accepts and resolves (checked end to end). The Docker build takes the
  upload token as a build-stage arg: the pushed image is clean, but the token stays in
  the build machine's local cache. A BuildKit secret would avoid that and was rejected
  because the image must also build with Docker's classic builder (no buildx).
- No feature flags, A/B experiments or in-app surveys. Adding them later means another
  tool (for example PostHog Cloud) and a new ADR.
