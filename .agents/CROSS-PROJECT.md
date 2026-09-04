# Back ↔ front seams and shared conventions

The only rules that genuinely span both projects. Anything one-sided belongs in that
sub-project's own `AGENTS.md`.

## Project map

| Submodule | Role | Stack | Dev port |
|---|---|---|---|
| `backend/` | API (**liteend-go**) | Go · chi · **gqlgen** GraphQL (schema-first) · sqlc · pgx · PostgreSQL · Redis · Asynq · goose · OIDC | `4000` (`/graphql` + playground) |
| `frontend/` | SPA/SSR (**litefront**) | Vite · React 19 · TanStack Start · URQL · Zustand · Tailwind v4 · daisyUI · Paraglide | `3000` |

Backend infra ports: PostgreSQL `5432`, Redis `6379`, pgweb `5100`, RedisInsight
`5200`, Asynqmon `5300` — all dashboards sit behind a Basic-Auth proxy.

## Which project for which task

- API, data, DB schema/migrations, business logic, jobs, server GraphQL types →
  **`backend`**
- UI, routing, client state, styling, GraphQL operations the browser sends →
  **`frontend`**
- A full-stack feature → **both, backend first** (define the schema and resolver, then
  regenerate and consume the types). Use the `full-stack-feature` skill.

## The four seams

### 1. GraphQL types are generated from the live backend

The frontend runs `npm run gen` against the backend's **running** schema at
`VITE_GRAPHQL_API_URL` (default `http://localhost:4000/graphql`). **The backend must be
up or `gen` fails.**

Order for a full-stack change: edit `backend/internal/graph/schema.graphqls` (gqlgen is
schema-first — that file is the source of truth) → `task gen` in the backend → start the
backend → `npm run gen` in the frontend → build the UI from `@generated/*`.

> The frontend holds some dependencies back precisely because they break this seam —
> see `frontend/.ncurc.yml` before "fixing" an outdated package.

### 2. Auth is one shared OIDC provider

Token audience must match across sides: frontend `VITE_OIDC_API_RESOURCE` **==**
backend `OIDC_AUDIENCE`. A mismatch means the backend rejects every token. Local dev can
bypass OIDC with backend `OIDC_MOCK_ENABLED=true` and frontend `VITE_MOCK_AUTH=true` —
neither may ship enabled.

### 3. `CORS_ORIGIN` gates HTTP **and** WebSockets

The backend's `CORS_ORIGIN` must include the SPA origin (`http://localhost:3000`).
Since gqlgen moved to the `coder/websocket` adapter, that same list authorizes the
**WebSocket handshake**, so a wrong or whitespace-damaged entry no longer just breaks
CORS — it silently refuses subscriptions from that origin. Entries are trimmed on load;
an empty list means "any origin", which the backend refuses in production but *not* on
other non-production environments.

The must-match pairs are documented in [../docs/ENV-CONTRACT.md](../docs/ENV-CONTRACT.md)
and checked mechanically by `scripts/doctor.sh`.

### 4. `requestId` is the correlation key between the two logs

The backend generates a request id per request, stamps it on **every** log line of that
request (including the background jobs it enqueues), and returns it to the client on
every GraphQL error as `extensions.requestId`.

The frontend must carry it through, and does: `errorExchange` keeps it in the error
report (it whitelists `requestId` and `code` out of `extensions` — the rest is dropped
because it can leak server detail), and `ErrorFallback` shows it to the user under
**Details → Request**. That is what lets a user-reported failure be answered from the
server log:

```sh
docker compose logs --no-log-prefix app | jq -c 'select(.request_id=="<ID>")'
```

Break either half and the two logs stop joining: the backend's story of a failure and
the user's report of it become two unrelated facts. Why it is built this way, and what
is deliberately *not* built: [meta ADR-0004](../docs/adr/0004-logs-are-the-diagnostic-surface.md).
Reading the logs: `backend/docs/DEBUGGING.md`, `frontend/.agents/OBSERVABILITY.md`.

## Shared conventions

- **Build tools differ by stack**: backend = Go + `task` (Taskfile); frontend = npm.
  Don't assume npm on the backend — it has no `package.json`.
- **One gate per side**: `task check` inside `backend/`, `npm run check` inside
  `frontend/`. Run the right one before declaring done. On the frontend never run `lint`
  and `ts:check` separately (that skips knip, steiger, trio and Biome's fixes).
- **TDD on both sides, machine-enforced.** Frontend: every `shared/ui` component is a
  story+test trio, plus coverage floors. Backend: per-package coverage floors.
  **There is no CI** — every gate lives in the submodules' git hooks, so `--no-verify`
  bypasses all of it. Don't. Ratchet floors up, never down. Details:
  `frontend/.agents/TESTING.md`, `backend/.agents/TESTING.md`.
- **English-only in the repo.** Code, comments, identifiers, commit messages and docs
  are English. (Chatting with the user follows the user's language.)
- **The log level means severity, on both sides.** `ERROR` is reserved for what the
  system did wrong (5xx, internal GraphQL errors, failed jobs/queries, a crashed
  render); a client fault is `WARN`. Every failure path leaves exactly one line, and
  never at `INFO` — see [meta ADR-0004](../docs/adr/0004-logs-are-the-diagnostic-surface.md).
- **Formatters must not be shared**: backend = gofumpt + golangci-lint; frontend =
  Biome (double quotes). Never copy formatting or lint config across the boundary.
- **Run the projects separately**, each per its own `AGENTS.md`; there is no root
  orchestration. Backend: `cd backend && task start:dev` (brings up Docker db+redis,
  runs migrations, hot reload). Both need their own `.env`.
- **Values copied between a config and a doc always drift.** Prefer pointing at the file
  that owns the number (coverage floors, field limits, tool versions) over restating it.
