---
name: full-stack-feature
description: Orchestrate a feature that spans both the backend (backend) and the frontend (frontend). Use this when a change needs work on both sides — e.g. "add a field to the API and show it in the UI", "new endpoint and a screen for it", "expose X in GraphQL and render it". Runs backend first, regenerates frontend types, then builds the UI. Delegates to each sub-project's own AGENTS.md instructions.
---

The user wants a feature touching **both** sides. This skill only decides the order; the
work itself follows each sub-project's own `AGENTS.md` and the `.agents/*.md` it routes to.

Why backend first, and the full ordering rule: [`.agents/CROSS-PROJECT.md`](../../../.agents/CROSS-PROJECT.md)
→ "The four seams", seam 1.

## The order

1. **Backend.** `cd backend`, read `backend/AGENTS.md`, do the work, `task check` green.
   Schema change → edit `internal/graph/schema.graphqls` → `task gen` → resolver.
2. **Bring it up** so the schema is live: `task start:dev` (Docker db+redis+object store,
   migrations at startup, GraphQL on `localhost:4000/graphql`).
3. **Sync the contract** only if the schema changed: `cd ../frontend && npm run gen`.
   A failure here almost always means the backend is not up.
4. **Frontend.** Read `frontend/AGENTS.md`, follow its routing table, build the UI from
   `@generated/*`, `npm run check` green.
5. **Commit** with the meta **`/commit`** skill — submodules first, then the pointers.

## What not to do

- Don't build the frontend against a schema that does not exist yet.
- Don't put feature code in the meta-repo; it only coordinates and records pointers.
- Don't commit submodule work as meta-repo blobs — commit inside each submodule.
