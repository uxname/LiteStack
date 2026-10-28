# ADR 0011: product requirements live in docc and bind the prototype and the code

- **Date:** 2026-10-28
- **Status:** accepted

## Context

The template had no product requirements: meta ADR-0007 retired `PRD.md` because a
requirements document written ahead of the code drifts from it, and nothing checked the
two against each other. A derived product still starts the same way every time:
describe it, try it on a prototype, then build it.

Two tools now make the link mechanical:

- **docc** keeps documentation as JSON in `docs/src`. Every paragraph has a permanent
  code (`^k7f2`). A `docc:` tag in code names the paragraphs it implements, each with
  the version hash it was checked against, and carries a fingerprint (`~xxxx`) of its
  own lines. A changed paragraph fails every tag that points to it (DOC209); changed
  code fails its own tag (DOC402). Neither rule can be switched off, and no command
  confirms links in bulk.
- **protokit** is a clickable prototype that runs in the browser against a simulated
  server, with the same tags on its screens and rules.

docc 0.5.0 listed code files with `git ls-files` in the project root, which returns a
submodule as one entry with no files in it. It also passed a Git hook's environment
(`GIT_DIR`, `GIT_INDEX_FILE`) on to its own `git` calls, so run from a submodule's hook
it read the submodule's repository instead of the project's. Both are fixed in docc
itself (`trace.rs` `list()` asks each submodule's own git; every `git` call clears the
variables `git rev-parse --local-env-vars` names).

Measured with the fixed docc: a `trace.scan` mask that matches nothing is no error;
indentation and trailing spaces inside a region leave its fingerprint alone; a new
blank line or code moved onto other lines changes it.

## Decision

**Where the documents are.** `docc.json` and `docs/src` sit at the meta root.
Documents of a requirement kind (a schema with `x-docc-covered`, `docs/schemas/req.json`)
hold what the product must do; every other kind (`page.json`) holds notes.

**How code is linked.** In the backend and the frontend a requirement is linked at its
entry points (resolvers and services, validations, routes and feature hooks)
by **regions**, `docc:begin <targets>` … `docc:end`, around the code that carries the
rule. No Go or TypeScript file gets a whole-file tag, and nothing inside a region is a
word `scripts/rename-project.sh` rewrites, so deriving a product breaks no fingerprint.
`schema.graphqls` and the sqlc queries (`db/queries/*.sql`) carry no tag: gqlgen and
sqlc copy their text, comments next to a query included, into generated code, so a tag
there would land in a generated file and every new hash would need a regeneration. The
Go code that resolves the field or runs the query carries it instead.
Migrations carry no tag either: an applied migration is history, and editing it to
follow a changed requirement would not change a database it already ran on. The code
that uses what a migration created carries the tag.
A value that lives only in JSON (the list of languages in `project.inlang`) is tagged
where the code reads it, since JSON takes no comments.

**What must be linked.** Every block of a requirement document has at least one tag,
in the prototype or in the product (docc's DOC404, docc 0.7). Notes need none. Any
tag that exists is binding, a tag on a note included.

**The prototype.** protokit is a third submodule, `protokit/`, pointing at
`uxname/protokit`. While it exists the documents, the prototype and the product are
bound together. It is removed whenever the developer decides it no longer pays for
itself, with one command — `git submodule deinit -f protokit && git rm protokit` and a
meta commit — and everything else keeps working: the meta's instructions never link to
it, the scripts skip it when it is absent, and the LikeC4 model does not include it
(it is a development tool, not part of the running system).

**Gates.** Each submodule's `lefthook.yml` gets a second pre-commit command: when
`../docc.json` exists, `docc check <its folder>` runs from the meta root — the whole
project is read, the report keeps that repository's files, and a change of its own that
leaves a requirement without its last tag fails it (docc compares with the repository's
last commit). The meta's pre-commit runs the full `docc check`. A submodule used on its
own has no `../docc.json` and skips the check.

## Alternatives

- **One repository instead of submodules** — lost: it undoes meta ADR-0002 and the
  template/derived split for one tool's limitation; fixing the tool was smaller.
- **A `docc.json` in each submodule pointing at `../docs`** — lost: docc rejects paths
  outside the project root, and it would split one set of documents into three views.
- **A meta script that copies the submodules for docc to read** — lost: extra code,
  and a copy that can disagree with the code it stands for.
- **Requirements move through stages (designed in the prototype, then built in the
  product, then dropped from the prototype)** — lost: per-requirement state, a
  closing procedure and rules for redesigns, to solve what removing the prototype
  solves in one command.
- **Every requirement linked in both the prototype and the product** — lost: a new
  feature could not be committed until it was built twice, and the template's
  existing features would need prototyping first.
- **Coverage on every paragraph** — lost: notes have no code to point at.

## Consequences

- **A changed requirement cannot land half-done.** A meta commit that changes a
  paragraph fails until every tag pointing to it — prototype, backend, frontend — has
  been read and given the new hash. The order is: bring every working tree in line,
  then commit protokit, backend, frontend, and the meta last.
- **Each repository answers for its own files.** An unfinished edit in the frontend does
  not block a backend commit; the meta's full check is where everything must agree.
  A tag removed in a submodule is caught by that submodule's own commit; a new
  requirement nobody has tagged yet is caught by the meta's.
- **One parser.** Coverage is a docc rule (DOC404) over docc's own tag scan, so it
  cannot disagree with what DOC209 and DOC402 check; protokit's `check-sync.mjs` keeps
  only what is the prototype's (a `Req` without a tag, an untagged screen).
- **Formatters can cost a review.** A formatter that rewraps lines or adds a blank line
  inside a region raises DOC402, and an agent rewrites the fingerprint after checking
  the code still matches.
- **The prototype is never maintained for its own sake.** Its cost stops the moment it
  is removed; the documents and the product carry on alone.
- **protokit's `main` is not self-contained.** It ships the smallest prototype that
  runs — a home page and a sign-in page tied to LiteStack's sign-in paragraphs — and
  needs a parent with `docc.json` to pass its checks.
- **docc is a required tool**, 0.7.0 or newer; `scripts/setup.sh` checks it, and
  `scripts/doctor.sh` checks the prototype's hooks while the prototype exists.
- **protokit keeps no CI.** With no documents of its own it has nothing to check alone;
  its `lefthook.yml` runs the checks when it sits in a LiteStack clone.

### The template's scope, carried over from ADR-0007

This ADR supersedes meta ADR-0007. The template's own scope is still decided in ADRs; what
changes is that a derived product's requirements now have a home, `docs/src`, checked
against the code. ADR-0007's scope stands, restated here so it has a current home; two of
its points are gone — there is no issue tracker, so the backlog it named is gone (its
items were finished or dropped), and the file-access change it described as planned is
done (backend ADR-0003).

Goals, heaviest first — the first is the point, the rest follow from it:

1. **A fast start for a new product**: auth, quality gates, deploy and docs already
   assembled — and now its requirements, a prototype and the links between them.
2. One standard across all projects: a single stack, easy switching.
3. Carrying accumulated best practices from project to project.
4. Showcase, passive only: the repositories are public and readable on their own.

What the template deliberately does not do:

- **No active showcase** — no demo deployments, no marketing, no presentation
  material. Public and readable is the whole of it. The prototype is not deployed
  anywhere either.
- **A single user by design** — no organisation or team scaffolding is built, and no
  "for later" hooks for it. Adding teams is a real change when it is needed.
- **No success metrics** — acceptance criteria are enough at this size.
- **Signed links are not bound to a user or an IP** — a short lifetime is the whole
  defence against bulk harvesting; per-user or per-IP binding is not built.
- **No fault tolerance** — database sharding, multiple regions, a CDN and an in-house
  load-testing rig are all out. Cluster orchestration is left to the deploy target
  (meta ADR-0005). Readiness for growth is not the same thing as surviving an
  infrastructure outage.
- **The checks are accepted as they are** — the frontend gate auto-fixes lint rather
  than failing, the Vite configs are untyped, and coverage floors cover only some
  packages. Tightening them is not pursued.
- **No pull of upstream template updates into derived products, and no back-porting**
  — a derived project is a one-time snapshot (`.agents/OPERATING-MODE.md`) and
  knowingly stays on the older code.

This ADR also amends meta ADR-0001 (a submodule now has two pre-commit commands, the
second only inside the meta) and meta ADR-0002 (three submodules while the prototype
exists). The working rules for agents are in `.agents/CROSS-PROJECT.md` → "Requirements".
