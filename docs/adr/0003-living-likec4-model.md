# ADR 0003: The LikeC4 model is updated in the same change as the architecture

- **Date:** 2026-09-04
- **Status:** accepted

## Context

`docs/architecture/likec4/model.c4` describes how the two sides fit together. Architecture
diagrams rot faster than any other document: they are written once, drift quietly, and then
mislead precisely the reader who trusted them — a new agent with no other map.

`PRD.md` records the decision as taken and priced: the schemas are living documents,
updated in the same pass as the architectural change, and that cost is acceptable.

## Decision

An architectural change and its model update ship **together**, in the same session and
the same commit range. `npm run likec4:validate` must pass, and the model must describe
what the code actually does — not what it was supposed to do.

## Alternatives

- **Regenerate the diagram from code** — nothing generates a *useful* C4 model; the value
  is in the boundaries and the intent, which are not in the source.
- **Refresh it periodically (audit sweep)** — that is how documentation drift is handled
  elsewhere here (`PRD.md`), but a stale architecture map is more expensive than a stale
  README: it is read first and trusted most.
- **Drop the model** — leaves the seams undocumented in a project whose entire job is to
  describe seams.

## Consequences

- Any change to boundaries, protocols or components carries a small documentation tax in
  the same session. Accepted knowingly.
- A validation pass that reports `✓ Valid (0 files)` proves nothing — it is what an empty
  or missing directory also prints. Check that files were actually parsed.
- The model is a review surface: a reviewer who cannot map the diff onto the model has
  found either an undocumented change or an unintended one.
