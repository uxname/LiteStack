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

### Step 1: Backend (inside `backend/`)

```bash
cd backend
```

Read `backend/AGENTS.md`, then use its skills as appropriate:

- New module? → `new-module`
- DB change? → `prisma-change` (edit schema → migrate → regen client → update services)
- New/changed GraphQL type? → `add-graphql-type`
- Background job? → `add-queue-job`
- Implement the behavior TDD → `implement-feature-tdd`
- Tests → `add-tests` / `add-e2e-test`
- Quality gate → `check` (or `npm run check`)

Finish the backend side completely and make sure `npm run check` passes.

### Step 2: Start the backend so the schema is live

```bash
# in backend/ (separate terminal)
docker-compose up -d db redis     # if not already running
npm run start:dev                 # GraphQL live at http://localhost:4000/graphql
```

The backend MUST be running for the next step.

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
