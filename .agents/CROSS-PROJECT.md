# Back ↔ front seams and shared conventions

The only rules that genuinely span both projects. Anything one-sided belongs in that
sub-project's own `AGENTS.md`.

## Project map

| Submodule | Role | Stack | Dev port |
|---|---|---|---|
| `backend/` | API (**liteend-go**) | Go · chi · **gqlgen** GraphQL (schema-first) · sqlc · pgx · PostgreSQL · Redis · Asynq · goose · OIDC | `4000` (`/graphql` + playground) |
| `frontend/` | SPA/SSR (**litefront**) | Vite · React 19 · TanStack Start · URQL · Zustand · Tailwind v4 · shadcn/ui · Paraglide | `3000` |
| `protokit/` | the prototype (**protokit**), until a product removes it | Vite · React 19 · urql + graphql-js on a simulated server in the browser | `5173` (the prototype's dev server, in `protokit/prototype`) |

Backend infra ports: PostgreSQL `5432`, Redis `6379`, pgweb `5100`, RedisInsight
`5200`, Asynqmon `5300`, Garage Web UI `5400` — all dashboards sit behind a
Basic-Auth proxy.

## Which project for which task

- API, data, DB schema/migrations, business logic, jobs, server GraphQL types →
  **`backend`**
- UI, routing, client state, styling, GraphQL operations the browser sends →
  **`frontend`**
- What the product must do → **`docs/src`** first (a requirement paragraph), then the
  prototype while there is one, then the code that carries it.
- A full-stack feature → **both, backend first** (define the schema and resolver, then
  regenerate and consume the types). Use the `full-stack-feature` skill.

## Requirements

The product's requirements are docc documents in `docs/src`; [meta
ADR-0011](../docs/adr/0011-requirements-in-docc-bind-prototype-and-code.md) records why and
how. What an agent does with them:

- **A requirement is a paragraph of a `req` document.** Each one has at least one
  `docc:` tag in the prototype or the product (`scripts/check-coverage.mjs`). A note — a
  `page` document — needs none; a tag on one still binds.
- **Tag a region, at the entry point.** `// docc:begin <id>#^<code>` … `// docc:end`
  around the code that carries the rule: a resolver or service, a validation, a route or
  feature hook. Never a whole Go or TypeScript file, and never a region holding a word
  `scripts/rename-project.sh` rewrites (the Go module path, `LiteFront`,
  `litefront-theme`): deriving a product would break its fingerprint. Not
  `schema.graphqls`: gqlgen copies it into generated code. JSON files take no comments,
  so a value that lives only in JSON is tagged where the code reads it.
- **Hashes and fingerprints are written by hand, one place at a time**, after reading
  both sides — never by a script over many files. A new tag gets its values from the
  DOC209/DOC402 hint.
- **Everything in line, then commit.** `docc check` in any repo's hook reads the whole
  project, so an edited paragraph blocks commits everywhere until every tag on it is
  updated. Order: edit every working tree, then commit protokit, backend, frontend, and
  the meta last.

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

How code, tests, log lines and commit messages are written:
[CODING_STANDARDS.md](./CODING_STANDARDS.md). What else spans both sides:

- **Build tools differ by stack**: backend = Go + `task` (Taskfile); frontend = npm.
  Don't assume npm on the backend — it has no `package.json`.
- **Formatters must not be shared**: backend = gofumpt + golangci-lint; frontend =
  Biome (double quotes). Never copy formatting or lint config across the boundary.
- **Run the projects separately**, each per its own `AGENTS.md`; there is no root
  orchestration. Backend: `cd backend && task start:dev` (brings up Docker
  db+redis+object store, runs migrations, hot reload). Both need their own `.env`.
- **Every shared value has exactly one owner file.** Every other file — document,
  config, compose file, code comment — points at it instead of restating it. This is
  not a Markdown rule: a number copied into a compose comment drifts exactly as fast.
  Owners:

  | Fact | Owner |
  |---|---|
  | The value of an env var | that side's `.env.example` (elsewhere: the name only, never the value) |
  | Which values must agree across the two sides | [`docs/ENV-CONTRACT.md`](../docs/ENV-CONTRACT.md) |
  | `DB_POOL_MAX`, `TRUSTED_PROXY_HOPS`, `PROXY_NETWORK`, `S3_*` — what they mean and how to size them | [`backend/.agents/OPERATIONS.md`](../backend/.agents/OPERATIONS.md) |
  | That there is no CI, and what runs instead | [`docs/adr/0001`](../docs/adr/0001-no-ci-gates-live-in-git-hooks.md) for the decision, [`docs/TEAM.md`](../docs/TEAM.md) for the gate table. The `--no-verify` warnings in the gate files are not copies: they sit where someone reads them |
  | What the meta-repo pre-commit hook runs | [`lefthook.yml`](../lefthook.yml) |
  | What the product must do | `docs/src` (docc), checked by `docc check` and `scripts/check-coverage.mjs` |
  | Deploy order and targets | [`docs/DEPLOY.md`](../docs/DEPLOY.md) |
  | Toolchain requirements and minimum versions | the root [`README.md`](../README.md) |
  | A subscription is not a delivery guarantee | [`backend/.agents/ARCHITECTURE.md`](../backend/.agents/ARCHITECTURE.md) |
  | The observability stack — which tool answers what, how it is deployed, how a project connects | [`docs/observability/`](../docs/observability/README.md), decision in [`docs/adr/0009`](../docs/adr/0009-shared-observability-stack.md) |
  | Who may read an uploaded file, and for how long | [`backend ADR-0003`](../backend/docs/adr/0003-files-are-private-and-served-through-signed-links.md) for the decision, [`docs/ENV-CONTRACT.md`](../docs/ENV-CONTRACT.md) for `FILE_VISIBILITY` + `FILE_LINK_TTL_MINUTES` |

  `S3_PUBLIC_BASE_URL` did not go away when files became private — it became the prefix a
  signed link is built from, which is why its checks in `scripts/doctor.sh` got stricter
  rather than disappearing.
