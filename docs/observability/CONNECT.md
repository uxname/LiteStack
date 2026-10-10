# Connect a derived project to the observability stack

The template ships none of this wiring on purpose ([ADR-0009](../adr/0009-shared-observability-stack.md)).
A derived project adds it here, step by step; stop after any step and what is done
already works. Paths are relative to the submodule named in each step.

Before you start: the stack is up ([STACK.md](./STACK.md)), and you have the frontend
and backend **DSNs** from GlitchTip, the Rybbit **site id** and **API key**, and a
collector on the product server.

| Step | Gives you | Code change |
|---|---|---|
| 1. Collector on the server | All logs, host and container metrics, the alerts | **none** |
| 2. Frontend errors | Browser + SSR exceptions in GlitchTip | **none** — set three variables |
| 3. Backend errors | Go exceptions in GlitchTip | small |
| 4. Backend traces and metrics | Request timing, slow spots, rates | medium |
| 5. Product analytics | Funnels, retention, replay in Rybbit | small |
| 6. The events list | A shared vocabulary for steps 5's events | one document |

## 1. Collector — no code change

[STACK.md § 5](./STACK.md#5-the-collector--one-on-every-product-server). The apps keep
writing JSON to stdout ([ADR-0004](../adr/0004-logs-are-the-diagnostic-surface.md)) and
the collector ships it. Nothing else is needed for logs.

## 2. Frontend errors — three variables

The template's Sentry SDK is already wired and sends errors only. On the frontend
container set:

| Variable | Value |
|---|---|
| `VITE_SENTRY_DSN` | The GlitchTip **frontend** project's DSN |
| `VITE_APP_ENV` | `production`, `staging`, … |
| `VITE_APP_VERSION` | The image tag |

For readable stacks, build with the source-map upload:
[DEPLOY.md → Source maps](../DEPLOY.md#source-maps-for-the-error-tracker). The CSP
already allows the DSN's origin.

## 3. Backend errors — `sentry-go`

1. `go get github.com/getsentry/sentry-go` and put the wiring in one new package
   (e.g. `internal/errtrack`) — place it in `.go-arch-lint.yml` as a common component,
   give it a floor in `.testcoverage.yml`, and keep `task deadcode` green.
2. Config (`internal/config`, the optional-variable pattern): `SENTRY_DSN` (empty =
   off) and `APP_ENV`. `NODE_ENV` stays what it is — the runtime mode, which only
   accepts `production` / `development` / `test`, so a staging server runs with
   `NODE_ENV=production`. `APP_ENV` names the *deployment* (`staging`, …) and defaults
   to `NODE_ENV` when empty. Add both to `.env.example` and the compose files.
3. **The release.** `internal/version.AppVersion` is a hard-coded `0.0.1` today; only
   `Commit` and `BuildTime` are injected at build. Inject `AppVersion` the same way
   (an `-X` ldflag in the Dockerfile, fed by a build arg set to `IMAGE_TAG`), or every
   backend event reports release `0.0.1`.
4. Init in `cmd/server/main.go` only when the DSN is set; `defer sentry.Flush(2*time.Second)`.
   `Environment: cfg.AppEnv`, `Release: version.AppVersion`,
   `SendDefaultPII: false`, and a `BeforeSend` that drops the query string from
   `event.Request.URL`, as the frontend's `scrubUrl` does. No `TracesSampleRate` —
   traces go to OpenObserve (step 4).
5. **One hub per request.** Wrap the router with `sentryhttp.New(sentryhttp.Options{}).Handle`
   (or clone the hub and `sentry.SetHubOnContext` in the `requestID` middleware), and
   always capture through `sentry.GetHubFromContext(ctx)`. Setting the user or a tag on
   the global hub lets concurrent requests overwrite each other's.
6. Capture at the four places every backend failure already passes through:

   | Where | Captures |
   |---|---|
   | `internal/graph/errors.go` — the error presenter, when `isInternal` | Internal GraphQL errors, *before* masking |
   | `internal/graph/handler.go` — `recoverPanic` | Resolver panics |
   | `internal/middleware/recover.go` — `Recoverer` | HTTP handler panics |
   | `internal/queue/queue.go` — `recoverer` and `errorHandler` | Job panics and failed jobs |

   Capture **in addition to** the existing log line, never instead of it: the line is
   what OpenObserve alerts on (ADR-0004: no sink may depend on configuration).
   Tag every event with `request_id` so GlitchTip → OpenObserve is one search.
7. The user: in `auth.userContext` (`internal/auth/middleware.go`) set the request
   hub's user to `Profile.OidcSub` — the same id the frontend reports — and add an
   `oidc_sub` attribute to the request logger next to the existing `user_id` (that one
   is the profile's database id, which no other tool knows). The WebSocket paths in
   `internal/graph/handler.go` call `auth.WithUser` directly and need the same lines.

**Check:** a resolver that panics on purpose (in a test or a throwaway branch) makes
an issue in the backend GlitchTip project with the `request_id` tag and your release.

## 4. Backend traces and metrics — OpenTelemetry

1. Dependencies: `go.opentelemetry.io/otel`, `otel/trace`, `otel/metric` and
   `contrib/instrumentation/net/http/otelhttp` are already in `go.mod` (indirect, pinned
   by the tools that pull them); `go get` the SDK and the two OTLP HTTP exporters
   (`otel/exporters/otlp/otlptrace/otlptracehttp`, `otel/exporters/otlp/otlpmetric/otlpmetrichttp`)
   at the same version, then `task tidy:check`.
2. Configure with the **standard** OTel variables — no custom config fields:
   `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318`,
   `OTEL_SERVICE_NAME=<product>-backend`,
   `OTEL_RESOURCE_ATTRIBUTES=deployment.environment=<APP_ENV>,service.version=<tag>`.
   The exporters fall back to `localhost:4318` when the endpoint is unset, so the code
   must check `OTEL_EXPORTER_OTLP_ENDPOINT` itself and skip the whole setup when it is
   empty — that keeps local development and tests free of export errors.
3. Instrument:
   - HTTP: wrap the router with `otelhttp.NewHandler` **outside** the `requestID`
     middleware in `internal/server/server.go`, and add `trace_id` to the
     request-scoped logger next to `request_id` (`middleware.ContextLogger`).
   - Database: an OTel pgx tracer combined with the existing `slowQueryTracer`
     (`internal/db/tracer.go`) — pgx takes one tracer, so wrap both in a small fan-out.
   - Jobs: asynq has no headers, so the trace context travels **in the payload**, next
     to `request_id` (`internal/queue/queue.go`, the same rule ADR-0004 set for it):
     inject a `traceparent` field when enqueuing, extract it in `jobLogger`.
   - Skip `/livez` and `/readyz` — the proxy polls them every few seconds.
4. Metrics worth having first: request rate / latency / status (otelhttp gives these),
   queue depth and retries, DB pool stats (`pgxpool.Stat()`).
5. The frontend propagates the trace into the API by setting `tracePropagationTargets`
   to the API origin in `src/shared/lib/sentry/config.ts` together with
   `browserTracingIntegration` and `tracesSampleRate: 0` — headers only, no spans sent
   to GlitchTip. The backend's CORS must then allow the `traceparent` and `baggage`
   request headers.

**Check:** OpenObserve → Traces shows `POST /graphql` with child spans for SQL; a log
line's `trace_id` opens the same trace.

## 5. Product analytics — Rybbit

**Browser.** Add two runtime keys, `VITE_RYBBIT_URL` and `VITE_RYBBIT_SITE_ID`, the way
every runtime key is added (`src/shared/config/env.ts` `runtimeShape`, its two tests,
both compose files, `.env.example`, [ENV-CONTRACT.md](../ENV-CONTRACT.md)). Then:

- Load the script once, client-side only, with the page's CSP nonce:
  `<script src="${VITE_RYBBIT_URL}/api/script.js" data-site-id="${VITE_RYBBIT_SITE_ID}" async>`.
  Skip it when either key is empty.
- CSP (`src/shared/config/csp.ts`): add the Rybbit origin to `script-src` and
  `connect-src`; if you turn session replay on, add `worker-src blob:` back.
- Identity, in `src/app/bootstrap/AuthObserver.tsx` next to the existing `setUser`:
  `window.rybbit?.identify(sub)` on sign-in, `window.rybbit?.clearUserId()` on sign-out
  — **only after the user agreed** to analytics (identify is personal data; without it
  Rybbit sets no cookies and needs no banner).
- Pass page URLs through `scrubUrl` (`src/shared/lib/sentry/scrub.ts`) when you send
  events by hand: `/callback?code=…` must never leave.
- Replay masking: Rybbit masks every input by default; put the `rr-mask` class on any
  other element whose text is private (profile data, emails).

**Server.** Business events an ad blocker must not drop — sign-up
(`profile.Service.create` in `internal/profile/service.go`; skip the mock user, and
expect the upsert race described there to fire it twice), profile update, upload — go
from the backend:

```bash
curl -X POST "$RYBBIT_URL/api/track" \
  -H "Authorization: Bearer $RYBBIT_API_KEY" -H "Content-Type: application/json" \
  -d '{"site_id":"1","type":"custom_event","event_name":"signed_up","pathname":"/","user_id":"<oidc sub>","properties":"{\"plan\":\"free\"}"}'
```

`properties` is a JSON **string** (max 2048 chars). Send it from a background job, not
the request path, so a slow Rybbit never slows a user. Config: `RYBBIT_URL`,
`RYBBIT_SITE_ID`, `RYBBIT_API_KEY` (a secret), all empty = off.

**Check:** Rybbit's realtime view shows your page view; the server event appears under
Events with the same user as the browser.

## 6. The events list — `docs/EVENTS.md` in the derived project

Analytics is only as good as its names. Before the first custom event, create
`docs/EVENTS.md` in the derived meta-repo and keep it the single owner of event names:

```markdown
| Event | Sent when | Properties | Sent by |
|---|---|---|---|
| `signed_up` | A profile is created for a new OIDC subject | `plan` | backend |
| `upload_completed` | `POST /upload` returned 201 | `count`, `bytes` | backend |
| `checkout_started` | The user opens the checkout page | — | browser |
```

Names are `object_verb` in past tense, snake_case, never renamed (rename = new event).
Funnels in Rybbit are built from these names, so an agent proposing a funnel reads this
file first.
