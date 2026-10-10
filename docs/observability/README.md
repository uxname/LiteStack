# Observability — one shared stack, three tools

Every product built from LiteStack reports to **one shared observability server**. Each
question has exactly one tool, so a person or an agent always knows where to look.
Why this shape and not another: [ADR-0009](../adr/0009-shared-observability-stack.md).

| Question | Tool | What goes in |
|---|---|---|
| **What broke in the code?** | **GlitchTip** | Exceptions from the browser, SSR and the Go backend — grouped into issues with stack, release and a resolved / regressed status |
| **What is the system doing?** | **OpenObserve** | Logs of every container (app, Postgres, Redis, Traefik), host and container metrics, traces, and **every alert** |
| **How do users move through the product?** | **Rybbit** | Page views, product events, funnels, retention, user journeys, session replay |
| **Did the deploy work? Is the host overloaded?** | **Dokploy** | Build and deploy history, CPU / RAM / disk per container |

Rule of thumb: GlitchTip answers *"what broke in the code"*, OpenObserve answers *"what is
happening to the system"*. A backend error shows up in both on purpose — as an `ERROR`
log line in OpenObserve (that is what alerts) and as an issue in GlitchTip (that is what
gets triaged and closed).

## The template ships documentation, not wiring

The LiteStack template stays light: it carries these documents and the frontend's
existing Sentry SDK (errors only, pointed at GlitchTip by `VITE_SENTRY_DSN`). Everything
else — the backend SDK, OpenTelemetry, product events — is added **in the derived
project** by following [CONNECT.md](./CONNECT.md). A small project can stop at any step:
logs and alerts alone already need no code change.

## How data flows

```
 product server (Dokploy)                         observability server (≤ 8 GB, Dokploy)
 ┌──────────────────────────────────────┐         ┌──────────────────────────────┐
 │ backend ─┬─ stdout JSON logs ──┐     │         │                              │
 │          ├─ OTLP traces/metrics┤     │         │  OpenObserve  ◄── alerts ──► Telegram
 │ frontend ┤  (SSR stdout logs) ─┤     │  OTLP   │                              │
 │ Postgres, Redis, Traefik logs ─┼─► OTel Collector ───►                         │
 │ host + container metrics ──────┘     │         │                              │
 │                                      │         │                              │
 │ backend + SSR ── Sentry SDK ─────────┼────────►│  GlitchTip                   │
 │ backend ── server-side events ───────┼────────►│  Rybbit                      │
 └──────────────────────────────────────┘         └──────────────────────────────┘
 browser ── Sentry SDK (errors) ─────────────────►  GlitchTip
 browser ── Rybbit script (views, events, replay) ►  Rybbit
 Dokploy ── deploy failures, CPU/RAM thresholds ─►  Telegram
```

The collector is the only thing installed on a product server. The apps keep writing
JSON to stdout ([ADR-0004](../adr/0004-logs-are-the-diagnostic-surface.md)); the
collector reads it from Docker, so logs reach OpenObserve without any code change.

**OpenTelemetry** (OTel) is the open standard the collector and the backend speak for
logs, metrics and traces. Nothing in the products depends on OpenObserve itself:
replacing it means changing one exporter address in the collector.

## One set of names across all three tools

A finding is only useful when it can be followed from one tool into the next. Every
signal carries the same four fields:

| Field | Value | Where it is set |
|---|---|---|
| `environment` | `production`, `staging`, `development` | Frontend `VITE_APP_ENV`; backend `APP_ENV` ([CONNECT.md](./CONNECT.md)) |
| `release` | The image tag, e.g. `1.4.0` | Frontend `VITE_APP_VERSION`; backend `internal/version.AppVersion`, injected at build ([CONNECT.md § 3](./CONNECT.md#3-backend-errors--sentry-go)) |
| user | The OIDC `sub` claim — the one id every tool can know | Frontend `setUser({ id: sub })` (already wired); backend from `Profile.OidcSub`, also logged as `oidc_sub`. The logs' existing `user_id` is the database id, known only to the backend |
| `request_id` / `trace_id` | Per request | Backend sets `request_id` today; OTel adds `trace_id` next to it |

With these, "errors in GlitchTip after release 1.4.0" → "the same `request_id` in
OpenObserve logs" → "what that user did in Rybbit's session replay" is three lookups,
not an investigation.

## Where to look

| I want to know… | Tool | How |
|---|---|---|
| Which errors are new since the last release | GlitchTip | Issues filtered by release — [AGENT-ACCESS.md](./AGENT-ACCESS.md#what-broke-after-release-x) |
| What happened around one failed request | OpenObserve | SQL on logs by `request_id` |
| Why a page or query is slow | OpenObserve | Traces, then `db_query_slow` lines |
| Whether the host is running out of memory or disk | OpenObserve / Dokploy | Host metrics; Dokploy monitoring |
| Where users drop out of a flow | Rybbit | Funnels |
| What a user did right before an error | Rybbit | Session replay for that user |
| Whether a deploy succeeded | Dokploy | Deployments tab, or the Telegram notice |

## The documents

| File | Read it to… |
|---|---|
| [STACK.md](./STACK.md) | Deploy and run the shared server: memory budget, the three Dokploy templates, the collector on each product server, alerts to Telegram, backups, upgrades, adding a project |
| [CONNECT.md](./CONNECT.md) | Connect a derived project: the backend and frontend code points, environment variables, the product events list |
| [AGENT-ACCESS.md](./AGENT-ACCESS.md) | Read the data as an agent or a person: API and CLI recipes, read-only tokens, optional MCP servers, triage scenarios |

Out of scope today: external uptime checks from a third location, feature flags and A/B
experiments, LLM monitoring. Each would be a new decision (ADR) when it is needed.
