---
prd_workflow: standard # blitz | standard
product_class: 'starter template for building products (boilerplate)' # product class, see "Product class recon"
blitz_round: 3
blitz_rounds_total: 10
standard_round: 5
standard_rounds_total: 7
---

# LiteStack

## Problem and goal

LiteStack is an existing, actively used full-stack template (backend
liteend-go + frontend litefront, with a coordination layer on top).

Goals, heaviest first:

1. **Fast start for a new product**: auth, quality gates (git hooks rather than
   a CI service — see ADR-0001), deploy and docs already assembled.
2. One standard across all projects: a single stack, easy switching.
3. Carrying accumulated best practices from project to project.
4. Showcase — passive: the repositories are public and readable on their own,
   no dedicated presentation work.

The first is the main one; the rest follow from it.

A recent audit found holes exactly where the author looks least often — tests
of real authentication, stripping secrets out of logs, the weight of the first
screen. That is **iteration 1 — hygiene**. A review of growth readiness showed
two walls: state held inside the process (files on disk, subscriptions in
memory) — that is **iteration 2 — scalability**: a core with no walls. A review
of security and standards found an open door (files with no gate) and missing
rules — that is **iteration 3 — security and standards**. The showcase review
added incidental tidying of the public repositories to the hygiene work. All
three iterations are hygienic: their effect is reduced risk, not a new feeling
at start-up.

## Users and scenarios

- The project author (you) — an active user who maintains and updates it, and
  runs all three iterations.
- A visitor to a product derived from the template — opens the first screen; the
  quality of that experience depends on what the template puts into the bundle
  (the assembled set of page code).
- An operator of a derived product — looks after the server; correct background
  processing, a core with no walls and closed doors decide whether the product
  survives growth and a customer's inspection.

## In scope

**Iteration 1 — hygiene:**

1. Tests for stripping secrets out of logs (`redactSensitive`) and a "coverage
   floor" for the logger package — the minimum share of covered code (60%) below
   which the backend gate fails.
2. Real tests of JWT verification (the signed sign-in token) on the backend:
   an expired token, a foreign issuer and a foreign audience are rejected; the
   tests run without mock authentication, and the keys come from a local set of
   test keys (JWKS); clock skew between servers is tolerated up to ±60 seconds.
3. Lazy loading of Sentry Session Replay (session recording for debugging): its
   code stays out of the initial bundle; when a session is sampled for recording,
   recording starts immediately, with no page reload. If the load fails (Sentry
   unreachable), the page works exactly as before. The one-off console command
   for analysing bundle composition goes into the documentation.
4. A line in the template documentation about session-recording privacy: visitor
   input is masked (Sentry's default is not turned off), while retention and
   access to the recordings are decided by the derived product's operator through
   their own Sentry plan.
5. Incidental tidying of the public repositories: a secret scan (gitleaks) in all
   three repositories — the backend has no such hook; the year and name
   placeholders in the frontend LICENSE filled in; DERIVE.md stating that a new
   product is created private.

**Iteration 2 — scalability ("a core with no walls"):**

6. Upload storage — S3-compatible storage on a single path: Garage (a lightweight
   S3 store) in the local Docker development stack, any S3-compatible service in
   production. Serving files stays behind the API — the storage is not public.
   The frontend upload-and-download sample moves to signed links in the same
   pass, so the template stays working end to end.
7. GraphQL event subscriptions — over a shared Redis (pub/sub — publish-subscribe)
   instead of in-process channels. The semantics are notifications: a subscriber
   that was disconnected at the moment of the event gets fresh data on refetch.
8. A pagination rule in the backend documentation: every list in the schema uses
   cursor pagination only (stable pages under inserts), with a short query
   example. No demo list in the schema.
9. A readiness run: two API instances actually running against a shared Postgres,
   Redis and Garage. The same pass updates the env contract and doctor.sh for the
   new variables, and DEPLOY.md gains a "next limits" section (one database host,
   one Redis, vertical growth). The frontend SSR (server-side page rendering) is
   not part of the run: it is stateless per the deploy documentation — there is
   nothing to check there.

**Iteration 3 — security and standards:**

10. File visibility mode — an environment variable. The default is **private**:
   downloads only through short-lived signed links issued by the API; a request
   without sign-in is refused; link lifetime is set by a neighbouring variable
   (in minutes). **Public** mode is a deliberate choice by the derived product's
   operator for galleries and landing pages: served without sign-in. Files inside
   the product are shared behind the gate. Both variables (mode and link
   lifetime) go into the env contract and the doctor.sh check in the same pass.
11. An automated test of the door: in private mode a file request without
    authentication is refused — an open door will not come back silently under
    any future refactor.
12. A security checklist to run before taking a product to production, embedded
    directly in the deploy steps of DEPLOY.md: sign-in, files, secrets, bucket
    backup (the object-storage container), limits, environment.

## Later

- An end-to-end (E2E) sign-in test through a real identity provider (IdP) on the
  frontend — heavier without CI.
- An automated check of the full first-run cycle from a clean clone — it becomes
  worth having with frequent starts or with other users.

## Out of scope

- An active showcase: demo deployments, marketing, presentation material. The
  repositories are public and readable on their own — that is enough.
- Pulling upstream template updates into products already derived: a derived
  project is a one-time snapshot of the templates and lives its own life (the
  decision is recorded in OPERATING-MODE.md).
- Back-porting the improvements of these iterations into products already
  derived: they knowingly stay on the older code.
- Fixing the integrity of the checks themselves (lint auto-fixing instead of
  failing, type checking of the Vite configs, coverage floors for the middleware
  and server packages): the current state is accepted as final.
- From fault tolerance: database sharding, multiple regions, Kubernetes, a CDN,
  an in-house load-testing setup. Readiness for growth is not the same thing as
  surviving an infrastructure outage.
- Organisations and teams in the data model: a single user by design; no
  "for later" scaffolding is built.
- Binding signed links to a user or an IP: a short lifetime plus non-public
  storage already closes bulk harvesting of files.

## Key stories

1. As the project author I want the gate to catch broken secret-stripping in the
   logs, so that other people's passwords do not leak into plain-text logs
   unnoticed.
2. As the project author I want real JWT verification tests, so that a hole in
   the issuer or expiry check does not ride into every future product.
3. As a visitor to a derived product I want a fast first screen, so that I do not
   download ~122 KB of session-recording plumbing that one session in ten needs.
4. As a visitor to a derived product I want my input kept out of the session
   recording in the clear, so that what I type stays private.
5. As the project author I want a second API instance to come up with no code
   changes, so that growing load does not mean rewriting the core.
6. As an operator of a derived product I want subscriptions to work with any
   number of instances, so that events reach visitors regardless of which
   instance they landed on.
7. As the project author I want one rule for lists, so that every derived product
   paginates the same way instead of inventing its own.
8. As an operator of a derived product I want to switch files to public mode with
   one setting, so that launching a simple product such as a landing page does
   not require the full sign-in machinery.
9. As the project author I want an automated test of the closed door, so that a
   safe default cannot silently open again.
10. As an operator of a derived product I want the checklist right inside the
    deploy steps, so that I can ship to production without forgetting a door.
11. As the project author I want the public repositories to carry no security
    gaps and no sloppiness, so that a casual reader sees a tidy project.
12. As a visitor to a derived product I want to get files through links the
    product gives me, so that downloading works with any number of servers.

## Acceptance criteria

1. Deliberately break `redactSensitive` → the backend gate fails; the 60% logger
   coverage floor is in place and enforced.
2. A test feeds an expired token, a token from a foreign issuer and one with a
   foreign audience → all three are rejected; a token expired within the ±60
   second tolerance is accepted, beyond it rejected; the tests run without mock
   authentication.
3. Analysis of the built bundle: no replay code in the entry point; a sampled
   session starts recording immediately; with the network to Sentry blocked, the
   first screen works as before. The analysis console command is written down in
   the documentation.
4. The template documentation states the privacy rule: visitor input is masked,
   and retention of and access to recordings are decided by the derived product's
   operator through their Sentry plan.
5. A manual check on a fresh clone: setup.sh and doctor.sh both succeed — the
   `.env` configuration being read is the real one, not the example.
6. Readiness run: two API instances work against a shared Postgres, Redis and
   Garage — a file uploaded through one instance downloads through the other; a
   subscription attached to one instance receives an event published on the
   other. Upload and download through the frontend sample work over signed links
   against both instances.
7. The backend documentation carries the cursor-pagination rule with an example;
   ENV-CONTRACT lists the storage variables and doctor.sh checks them; DEPLOY.md
   has the "next limits" section.
8. Switching the visibility mode: in private mode (the default) a file request
   without sign-in is refused, a signed link works and expires according to its
   variable; in public mode the same file opens without sign-in. Both variables
   are present in ENV-CONTRACT and checked by doctor.sh.
9. The door test is green: an unauthenticated request for a file in private mode
   is refused.
10. The deploy steps in DEPLOY.md contain the embedded security checklist:
    sign-in, files, secrets, bucket backup, limits, environment.
11. gitleaks is wired into the hooks of all three repositories; the frontend
    LICENSE has no placeholders; DERIVE.md carries the private-by-default rule
    for derived products.

## Data

The template itself stores no product data. Its artefacts are: the configuration
in `.env` (contract — docs/ENV-CONTRACT.md; it shows up in acceptance as the
manual run of setup.sh and doctor.sh), application logs, uploaded files (after
iteration 2 — in S3-compatible storage, with visibility per the mode from
iteration 3), and session recordings held by Sentry, a third party; their rule is
in "In scope": input is masked, retention and access are the derived product's
decision. The iterations add no new kinds of data — what changes is where files
live and the rules for reaching them.

## Success metrics

Deliberately none (the decision and its reason are in "Decisions").

## Constraints and risks

- The project has no CI on principle — no solution may require introducing one.
- Work spans three repositories at once (the meta-repo plus two submodules);
  changes have to be made in step.
- Replay drifting back into the initial bundle on a future Sentry update is not
  guarded automatically — the next audit catches it.
- A leaked signed link works until its lifetime expires: the risk is accepted,
  the lifetime is minutes.

## Decisions and what was rejected

- The PRD is written in English, like everything else in the repositories: the
  English-only rule (root AGENTS.md, rule 3) covers docs, and a single file in
  another language is exactly the kind of exception nobody remembers. This
  reverses the earlier decision to keep it in Russian for the author's thinking
  speed (reversed 2026-09-05).
- Dependency freshness stays manual, done by the author: starts are rare, and
  automation (bots, a calendar) does not pay for itself.
- An automated first-run check is deferred: the manual one is run when needed.
- Documentation drift is caught by a periodic audit, not by automatically
  checking the commands and links inside the docs.
- Of the two testing themes, real authentication was chosen over the integrity of
  the checks themselves: it closes the more expensive risk.
- The main goal is a fast start; one standard, best practices and the showcase
  follow from it.
- The iterations are done without pain being felt: the risks from the audit are
  real even though nothing hurts right now.
- No metrics are introduced: for iterations this size the acceptance criteria are
  enough.
- The boundary of the sign-in tests is the token-verification module on the
  backend only; the teaching stub for sign-in (OIDC, the sign-in protocol) on the
  frontend stays a development mode.
- Session-recording privacy is fixed by a line in the docs rather than by a
  settings check: Sentry's default masking is sufficient.
- The "replay outside the bundle" check is a one-off proof plus a command in the
  documentation; no permanent automated check is set up, and the audit catches a
  regression.
- Scalability readiness is defined as "a core with no walls": all state outside
  the process, a second instance with no code changes.
- File storage is S3-compatible on a single path (Garage in dev, any S3 in
  production) rather than two modes, "disk or S3": one code path is cheaper than
  branching.
- Files are served through the API rather than straight from storage: it is
  simpler, and the storage is never published to the internet. A signed link
  points at an API endpoint, not into the bucket: the storage stays fully closed.
- Subscriptions use Redis pub/sub (publish-subscribe) with notification
  semantics; no delivery guarantee is built: "if an event must not be lost, that
  is the job of the Asynq task queue, not of a subscription" (the rule goes into
  the documentation).
- Pagination is a rule in the documentation rather than a demo list in the
  schema: zero sample code.
- Migrating files already sitting on local disk is not done: there is no
  production data, the start is clean.
- ENV-CONTRACT and doctor.sh are updated in the same pass as any new environment
  variables (storage, file visibility mode, link lifetime): otherwise the
  settings go missing silently on someone else's host.
- Postgres and Redis stay single instances: readiness for horizontal growth is
  not the same as surviving an infrastructure outage.
- The upload feature stays in the template: it is a working sample for derived
  products.
- The hygiene item "leak on a file-write timeout" is dropped: writing files by
  hand disappears with the move to S3 — check it during that work; if iteration 2
  does not happen, bring the item back.
- File access: private mode by default through signed links; after being
  challenged, a public mode behind one variable was added — a fast start for
  lightweight products matters more than an unbreakable default, and turning
  security off stays a conscious act in the settings.
- The old public path for serving files is removed: access is only through signed
  links (private) or through public mode.
- GraphQL introspection and the interactive tooling stay open in production: the
  schema holds no secrets and openness makes integration easier — the project
  author's decision, made after a recommendation to close them.
- A single user by design: no organisation scaffolding is built; the path to
  adding teams lives only here in the PRD, and the docs are left alone.
- No map of "escape routes" from the template's hard decisions is drawn up.
- The showcase was rewritten as passive: no audience is defined and no
  presentation happens; being public and readable is a principle, not a work
  item. READMEs are updated alongside the iterations, and the doc audit catches
  drift.
- The language of the public repositories is English-only: uniformity for tools
  and for casual readers.
- The LikeC4 diagrams are living: they are updated in the same pass as an
  architectural change; the cost is acceptable.
- Derived products are created private by default (a line in DERIVE.md);
  publishing is a conscious act.
- No discipline is required of the commit history: the gates are what guarantee
  quality.
- The incidental-tidying criterion is accepted as part of iteration 1 despite
  sitting at the end of the criteria list: the criteria are not grouped by
  iteration.
- The production checklist is embedded in the deploy steps rather than kept as a
  separate document: it gets walked through on the way, otherwise nobody opens it.
- Order of work: iterations 1 → 2 → 3; each is accepted against its own criteria,
  including the manual setup.sh/doctor.sh check on a fresh clone.
- The manual fresh-clone check (setup.sh and doctor.sh) is not a new feature but
  an acceptance procedure for the existing `.env` contract (see "Data"), so it
  lives outside "In scope".
- The two-instance API readiness run is the opposite — part of iteration 2's
  scope: it proves the new storage and subscription contracts rather than
  something that already exists.

## Document lifecycle

- Topics come from the audit cycle: a PRD review (at minimum before every product
  start) and targeted audits of code and docs — the next iteration is added right
  here. There is no calendar rhythm. Besides audits, topics also come from
  emergency security fixes and from "Later" items under their recorded conditions.
- Audits are run by the author and by subagents by specialisation; periodically
  also by a clean auditor agent with no project history: earlier conclusions are
  withheld from it until it has made its own findings.
- A completed iteration is marked with a "— completed [date]" line next to its
  heading.
- An iteration once started is not interrupted: a new topic joins the queue. The
  exception is an emergency security fix (a known vulnerability, a CVE in a
  dependency): it is done immediately and does not count as a queued topic.
- When a new topic starts, the previous one is folded up: compressed lines remain
  in "Decisions", while the full text lives on in the git history.
- "Later" items return to scope under the conditions recorded with them; no
  separate triggers are assigned to them.
- Changes to this document go through the same process: edit → commit → a fresh
  critic's eye. There are no free-hand edits.

## Open questions

None — the known gaps are either closed or knowingly deferred, with a record in
"Decisions" and "Later".
