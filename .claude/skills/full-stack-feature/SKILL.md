---
name: full-stack-feature
description: Order a feature that needs changes in both backend/ and frontend/ — e.g. a new GraphQL field shown in the UI. Writes the requirement first, then the prototype while there is one, then the backend, regenerates the frontend types, and builds the UI.
---

The user wants a feature touching **both** sides. This skill only decides the order; the
work itself follows each sub-project's own `AGENTS.md` and the `.agents/*.md` it routes to.

Why backend first, and the full ordering rule: [`.agents/CROSS-PROJECT.md`](../../../.agents/CROSS-PROJECT.md)
→ "The four seams", seam 1.

## The order

1. **Requirement.** Write or change the paragraph in `docs/src` (a `req` document) with
   the `docc` skill — `.agents/CROSS-PROJECT.md` → "Requirements". It is what every step
   below is checked against.
2. **Prototype**, while `protokit/` exists: the screen and the path with the `protokit`
   skill, tagged with the paragraph. Skip it when the product has removed the prototype.
3. **Backend.** `cd backend`, read `backend/AGENTS.md`, do the work, `task check` green.
   Schema change → edit `internal/graph/schema.graphqls` → `task gen` → resolver.
   Tag the code that carries the rule with a region (`docc:begin` … `docc:end`).
4. **Bring it up** so the schema is live: `task start:dev` (Docker db+redis+object store,
   migrations at startup, GraphQL on `localhost:4000/graphql`).
5. **Sync the contract** only if the schema changed: `cd ../frontend && npm run gen`.
   A failure here almost always means the backend is not up.
6. **Frontend.** Read `frontend/AGENTS.md`, follow its routing table, build the UI from
   `@generated/*`, tag the code that carries the rule, `npm run check` green.
7. **Check the links** from the meta root: `docc check --max-warnings 0` and
   nothing else — `docc check` also reports a requirement with no tag (DOC404); write
   each new hash and fingerprint by hand.
8. **Commit** with the meta **`/commit`** skill — submodules first, then the pointers.

