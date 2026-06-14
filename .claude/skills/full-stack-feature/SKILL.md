---
name: full-stack-feature
description: Orchestrate a feature that spans both the backend (backend) and the frontend (frontend). Use this when a change needs work on both sides — e.g. "add a field to the API and show it in the UI", "new endpoint and a screen for it", "expose X in GraphQL and render it". Runs backend first, regenerates frontend types, then builds the UI. Delegates to each sub-project's own skills.
---

The user wants a feature that touches **both** the backend and the frontend. This skill is
the conductor: it decides the order, runs the backend side first, syncs the GraphQL
contract, then runs the frontend side. It does not contain backend/frontend logic itself —
it **delegates to the sub-project skills**, which must be used inside each submodule.

## Golden rule: backend first

The frontend generates its GraphQL types from the backend's **live** schema. If the schema
doesn't exist yet, the frontend can't be built correctly. So always: **backend → contract
sync → frontend**.

## Process

### Step 0: Confirm scope and mode

- Restate the feature in one sentence and confirm both sides are needed.
- Check the operating mode (see root `AGENTS.md` → Operating mode). It determines where you
  commit and push at the end.

### Step 1: Backend (inside `backend/` — Go, liteend-go)

```bash
cd backend
```

**Read `backend/AGENTS.md` first — it is the source of truth for the Go workflow.** The
backend has no `be-*` meta skills; follow its own conventions. The common moves:

- New/changed GraphQL field → edit `internal/graph/schema.graphqls` (give every type, field,
  enum value, input a `"description"`) → `task gen` → implement the resolver stub in
  `internal/graph/resolver/`.
- DB query → add it to `db/queries/*.sql` with a `-- name:` annotation → `task gen` → use
  `database.Queries.<Name>`.
- Schema/column change → `task migration:create name=...` (goose, forward-only, embedded).
- Background job → define a task type + handler in `internal/queue`, register it in the mux.
- New REST route → add it in `mountRoutes` (`internal/app/app.go`) AND document it in
  `internal/devtools/openapi.yaml` (a route-sync test enforces this).

Finish the backend side completely and make sure **`task check`** passes (Docker-free:
codegen-freshness, build, lint, vuln, format, tidy, secrets).

### Step 2: Start the backend so the schema is live

```bash
# in backend/ (separate terminal)
task start:dev                    # brings up Docker db+redis, runs migrations (goose,
                                  # programmatic), GraphQL live at localhost:4000/graphql
```

The backend MUST be running for the next step. (Migrations run automatically at startup —
no separate apply step.)

### Step 3: Sync the GraphQL contract (inside `frontend/`)

```bash
cd ../frontend
npm run gen                       # regenerate types from the live backend schema
```

If `gen` fails, the backend is probably not running or the schema has an error — fix that
before continuing.

### Step 4: Frontend (inside `frontend/`)

Read `frontend/AGENTS.md`, then use its skills as appropriate:

- New GraphQL operation? → `add-gql`
- New page/route? → `new-page`
- New slice/feature/entity/widget? → `new-fsd-slice`
- Reusable component? → `new-component`
- Client state? → `new-store`
- Protected route? → `add-auth-guard`
- User-facing text? → `add-translation`
- Tests → `write-tests`
- Quality gate → `quality-fix` (or `npm run check`)

Build the UI from the generated types (`@generated/*`). Make sure `npm run check` passes.

### Step 5: Commit everything

Use the meta-level **`commit`** skill. It commits inside each changed submodule, records the
updated submodule pointers in the meta-repo, and pushes according to the operating mode.

## What NOT to do

- Do not build the frontend against a schema that doesn't exist yet — backend first.
- Do not run `npm run gen` while the backend is down.
- Do not put any feature code in the meta-repo — it only coordinates and records pointers.
- Do not commit the backend and frontend as meta-repo blobs — commit inside each submodule.
