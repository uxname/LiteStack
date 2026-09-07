# ADR 0007: the template's scope lives in ADRs; the PRD is retired

- **Date:** 2026-09-07
- **Status:** accepted

## Context

`PRD.md` was written to drive three "hygiene" iterations over an already-existing
template (hygiene, scalability, security-and-standards). It reached round 5 of a
planned 7 in its `/prd` edit→commit→critic cycle and was then translated to English.

Two things then became true:

- **The iterations stalled.** A completeness audit across all three repositories
  (session `LiteStack-85l`, 2026-09-07) found roughly nine of the twelve in-scope
  items unfinished — the substantive testing and file-access work was never done,
  only pieces landed opportunistically next to other changes. No iteration could be
  marked complete.
- **The document became a drift source.** A product requirements doc describes work
  that has not happened yet; once the template exists, its present-tense claims
  outrun the code. Every documentation audit since has filed a task for exactly this
  (`LiteStack-47e`, `-52h`, `-7rw`), and keeping the `/prd` ceremony alive for a
  document nobody builds from is pure overhead.

Most of the PRD's durable decisions were already recorded in ADRs 0001–0006, in
`.agents/CROSS-PROJECT.md` (English-only), `.agents/DERIVE.md` (derived products are
private by default) and `.agents/OPERATING-MODE.md` (a derived project is a one-time
snapshot). What had no other home was the template's scope: its goal hierarchy and
the list of things it deliberately does not do.

## Decision

`PRD.md` is removed; its last version is the commit right before this ADR, and the
full text stays in git history. The scope it uniquely held is recorded below.
Unfinished iteration work moves to the tracker as a backlog epic, `LiteStack-v23`
(priority 3 — it may never be finished, and that is accepted). Documentation drift is
caught by a periodic audit, on no calendar. A future scope decision is written as an
ADR here, not as a revived requirements document; the PRD's edit→commit→critic
process is retired with it.

### What the template is for

Goals, heaviest first — the first is the point, the rest follow from it:

1. **A fast start for a new product**: auth, quality gates, deploy and docs already
   assembled.
2. One standard across all projects: a single stack, easy switching.
3. Carrying accumulated best practices from project to project.
4. Showcase, passive only: the repositories are public and readable on their own.

Three people are in view: the template author (maintains it), a visitor to a derived
product (meets the first screen), and an operator of a derived product (runs the
server).

### What the template deliberately does not do

- **No active showcase** — no demo deployments, no marketing, no presentation
  material. Public and readable is the whole of it.
- **A single user by design** — no organisation or team scaffolding is built, and no
  "for later" hooks for it. Adding teams is a real change when it is needed.
- **No success metrics** — for iterations this size the acceptance criteria are
  enough.
- **Signed links are not bound to a user or an IP** — when signed-link serving
  arrives (see below), a short lifetime is the whole defence against bulk
  harvesting; per-user or per-IP binding is not built.
- **No fault tolerance** — database sharding, multiple regions, a CDN and an
  in-house load-testing rig are all out. Cluster orchestration is left to the deploy
  target, not solved here (meta ADR-0005). Readiness for growth (state outside the
  process, a second instance with no code change — meta ADR-0005) is not the same
  thing as surviving an infrastructure outage.
- **The checks are accepted as they are** — the frontend gate auto-fixes lint
  rather than failing, the Vite configs are untyped, and coverage floors cover only
  some packages. Tightening them is not pursued.
- **No pull of upstream template updates into derived products, and no back-porting**
  of these improvements into products already derived — a derived project is a
  one-time snapshot (`.agents/OPERATING-MODE.md`) and knowingly stays on the older
  code.

### The file-access model is a planned change, not the current state

Today an uploaded file is served straight from a public bucket: the URL kept in the
database is permanent and needs no token ([backend
ADR-0002](../../backend/docs/adr/0002-object-storage-and-trusted-client-ip.md),
decision 1; the `model.c4` arrow "downloads uploaded files DIRECTLY"). The model the PRD intended —
private by default, served *through the API* over short-lived signed links, an
opt-in public mode behind one environment variable, and the old public path removed
— is backlog `LiteStack-v23.5` and `-v23.7`. Backend ADR-0002 and the `model.c4`
download arrow are superseded when that work lands, not before.

## Alternatives

- **Keep the PRD and finish the iterations (its own plan)** — lost: the iterations
  had already stalled, and a post-build requirements document keeps generating drift
  regardless of whether the work behind it gets done.
- **Split the residue across several new ADRs** (showcase, single user, metrics, file
  access…) — lost: those decisions share one context — what this template is — and
  four or five near-empty records fragment it for no gain.
- **Let git history hold everything, add nothing** — lost: the goal hierarchy and the
  "does not do" list are read often enough that they need a current home, not a
  `git blame` archaeology dig.

## Consequences

- The template's scope is now answered in one place, next to the other decisions,
  and in the present tense.
- The unfinished iteration work is visible in the tracker with a per-item acceptance
  criterion, at a priority that says "when there is time". If it is never done, the
  record still explains what was intended and why.
- Changing scope now costs one ADR and one critic pass, the same as any other
  architectural decision — no separate requirements process to keep in sync.
- Anyone who wants the original iteration detail, the key stories, or the full
  decision log reads the PRD in git history — it is not lost, only moved out of the
  working set.
- Three PRD decisions are kept only in git history because the code already went the
  other way: GraphQL introspection is **disabled** in production (the PRD wanted it
  open), and dependency updates run through `renovate.json` (the PRD wanted them
  manual). The third — "a subscription carries no delivery guarantee; a
  must-not-lose event is the Asynq queue's job" — was a documentation rule that was
  never written down; it is backlog `LiteStack-v23.12`.
