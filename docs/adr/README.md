# docs/adr — architecture decision records

An ADR records **one decision that is expensive to reverse**, together with the reason it
was made. Rules live in `AGENTS.md`; this folder answers the question rules never do —
*why is it like this?*

Without it, a decision survives only as a rule ("there is no CI"), and a rule without a
reason is the thing someone "fixes" six months later.

## When to write one

Write an ADR when a choice is **structural and hard to undo**: the topology of the repos,
where a layer's boundary runs, which protocol the two sides speak, a security posture that
looks like a bug to a newcomer, a deliberate omission (something a reasonable reader would
expect to find and won't).

Do **not** write one for: naming, formatting, a library swap with no ripple, anything a
lint rule already enforces, or a decision that is cheap to revisit. Those belong in
`AGENTS.md` or in the sub-project's `.agents/*.md`.

Rule of thumb: if a future agent could break it by "improving" the code, it needs an ADR.

## Lifecycle

1. **Decide** — during planning, when an architectural fork appears and you pick a side.
2. **Record** — same session, before the code lands. Use [`TEMPLATE.md`](./TEMPLATE.md)
   verbatim.
3. **Read** — before touching the area. Agents read ADRs during recon; a decision recorded
   here is binding, and an implementation that ignores it is a defect, not a preference.
4. **Supersede, never edit** — a decision that changes gets a *new* ADR; the old one stays
   and its status becomes `superseded by ADR-NNNN`. Deleting history hides the reason the
   old choice was made, which is the whole point of the file.

## Naming

```
docs/adr/NNNN-short-slug.md
```

Four digits, monotonic, never reused: `0004-postgres-single-instance.md`. The number is
the address — other documents cite `ADR-0004`, so it must stay stable.

## Scope — and where sub-project decisions live

Records are kept **where the decision applies**, the same way `CLAUDE.md` points at
`AGENTS.md` instead of copying it. This folder holds only what spans both sides or the
repo topology itself; a decision that lives inside one sub-project is recorded in that
sub-project, next to the code it constrains, and stays with it when that repo is used on
its own.

| Decisions about… | Recorded in |
|---|---|
| repo topology, the CI/gates model, cross-side process and seams | this folder |
| the backend: language, layering, protocols, deliberate omissions | [backend/docs/adr/](../../backend/docs/adr/) |
| the frontend: rendering, state, styling, build-time contracts | `frontend/docs/adr/` — no decisions recorded yet; create it with the first one |

**Numbers are local to each repo**, so `ADR-0001` is ambiguous on its own: cite decisions
as `meta ADR-0001`, `backend ADR-0001`. A sub-project ADR that the other side must obey is
worth one line here too — a link, never a copy, because a copy is what drifts.

Written in **English**, like everything else in the repo. (`PRD.md` is the one deliberate
exception — see the decisions section there.)
