# Task: <short title>

**Goal:** <what outcome, in one or two sentences>

**Affects:** [ ] liteend  [ ] litefront

**Context / links:** <issue, idea file, design notes>

---

## Full-stack checklist

> Skip the backend section for frontend-only tasks (and vice versa).
> For full-stack features: **backend first**, then sync types, then UI.

### Backend (`liteend`)
- [ ] Update schema / resolver / service (thin resolver, fat service, `nestjs-zod` validation)
- [ ] DB change? create + apply migration (`npm run db:migrations:create` → `:apply`)
- [ ] Write tests first (TDD): services → unit, resolvers/controllers → e2e
- [ ] `npm run check` passes
- [ ] Start backend so the schema is live: `npm run start:dev` (`:4000/graphql`)
- [ ] Commit **inside** `liteend`

### Contract sync
- [ ] Backend running → in `litefront`: `npm run gen` (regenerate GraphQL types)

### Frontend (`litefront`)
- [ ] Add/adjust GraphQL operations in `src/graphql/**/*.graphql`
- [ ] Build UI (FSD layers; consume `@generated/*` types; URQL)
- [ ] Routes changed? `npm run gen:routes`
- [ ] Write tests (Vitest unit/component; Playwright e2e if needed)
- [ ] `npm run check` passes
- [ ] Commit **inside** `litefront`

### Meta-repo
- [ ] `git add liteend litefront` to record updated submodule pointers
- [ ] Commit the meta-repo (pointers + any updated docs/tasks)

---

## Notes
<decisions, gotchas, follow-ups>
