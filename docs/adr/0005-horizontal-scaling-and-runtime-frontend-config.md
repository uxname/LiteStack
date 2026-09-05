# ADR 0005: Interchangeable copies on both sides, one frontend image for every environment

- **Date:** 2026-09-05
- **Status:** accepted

## Context

Until this session both halves of LiteStack silently assumed there was exactly **one**
copy of each running. Four facts stood in the way — the first three made a second copy
impossible rather than merely untested:

- The backend wrote uploaded files into a directory inside its own container and served
  them back from there, so a file written by copy A did not exist for copy B.
- Both production compose files claimed a **fixed host port**, so the second copy died on
  a port conflict before it ran a line of application code.
- The frontend's public values (`VITE_*`) were inlined into the bundle by Vite at build
  time. An image was therefore welded to the one environment it was built for, and the
  e2e suite rebuilt the bundle per environment — the test suite had adopted the very
  assumption it should have been catching.
- The backend's client-address middleware trusted a header the client writes, which is a
  security bug on one copy and a worse one on many. That half is recorded separately in
  [backend ADR-0002](../../backend/docs/adr/0002-object-storage-and-trusted-client-ip.md).

LiteStack is a template with no real traffic behind it, cloned into products whose hosting
is unknown. The decisions taken for this work therefore put portability above tuning for
any one host, and left the orchestrator (Kubernetes, Swarm, Nomad, plain compose)
explicitly **undecided** — so nothing here may depend on a feature only some hosting
products offer.

## Decision

**1. Both sides run as N identical copies behind one shared reverse proxy.** No copy may
hold state another copy cannot see: Postgres, Redis and the object store are external,
shared by every copy, and addressed through environment variables. No production compose
file claims a fixed host port — the proxy reaches the containers over a shared network.
`scale/` holds a compose stand that runs two copies of each side behind Caddy, and
`scripts/scale-check.sh` drives the scenarios that prove a copy is interchangeable with
its twin. It is run by hand, not by a gate — there is no CI here
([ADR-0001](./0001-no-ci-gates-live-in-git-hooks.md)).

**2. The frontend image is built once and configured by the container's environment.**
Nine public values — `VITE_OIDC_AUTHORITY`, `VITE_OIDC_CLIENT_ID`,
`VITE_OIDC_REDIRECT_URI`, `VITE_OIDC_SCOPE`, `VITE_GRAPHQL_API_URL`,
`VITE_OIDC_API_RESOURCE`, `VITE_BASE_URL`, `VITE_SENTRY_DSN`, `VITE_APP_VERSION` — are
read from the process environment when the server boots and handed to the browser through
one inline `<script>` in the server-rendered `<head>`. The payload is built by **picking
an explicit list of keys** (`runtimeShape` in `frontend/src/shared/config/env.ts`), never
by copying an object or walking `process.env`, so a value reaches the browser only when
someone adds its name to that list. A missing required variable kills the process **before
the port is bound**, naming the variable.

`VITE_MOCK_AUTH` deliberately stays a build-time value: it swaps the authentication
provider inside the bundle, and that must not be flippable on a running container.

## Alternatives

- **One shared network volume mounted into every copy** (for uploads) — the smallest
  change by far, and rejected: it needs a filesystem every copy can mount, which not every
  hosting product offers. With the orchestrator undecided, that is a bet on the host.
- **Fetching the config from the server (`GET /config.json`) instead of inlining it** —
  rejected: the values have to exist *before* the config module is first imported, and a
  fetch resolves after it. It also adds a request to every cold page load for data the
  server already had in hand while rendering the HTML.
- **Renaming the `VITE_*` variables**, now that most of them are no longer Vite build-time
  values — rejected as a cosmetic rename with real breakage behind it: those names are
  already written into the `.env` files of everyone who deployed the template, and
  `frontend/codegen.yml` reads `VITE_GRAPHQL_API_URL` by that exact name
  (`schema: ${VITE_GRAPHQL_API_URL}`).
- **Making `VITE_MOCK_AUTH` a runtime value too**, for symmetry — rejected: it would turn
  "authentication is mocked" into an environment variable on a production container.
- **A switch that falls back to the old build-time/local-disk behaviour** — rejected: a
  flag like that means two code paths forever, both of which have to keep working. The
  rollback for this change is `git revert`, not a runtime toggle.

## Consequences

- One image is promoted from staging to production unchanged. The flip side: you can no
  longer tell from an image *which* environment it is for. The server prints one
  `frontend_config_loaded` line at boot with the API URL, base URL and version — that line
  is how you tell, and it is why the boot check exists at all.
- **Adding a key to `runtimeShape` publishes it to the browser.** A test pins the exact
  set of nine keys and fails on *any* new one, secret-looking or not, because the review
  that catches this by eye is the one that stops happening in six months.
- **The runtime-config module is compiled twice, by two different bundlers, and the two
  copies do not behave the same.** In the built artifact there is one copy inside the
  server bundle (`.output/server/chunks/nitro/nitro.mjs`, produced by Nitro/rollup, where
  the environment read stays live) and another inside the application bundle
  (`.output/server/chunks/virtual/entry.mjs`, produced by Vite, where `import.meta.env.*`
  accesses are printed as literals). Nitro also bundles application code with
  `moduleSideEffects: false`, so a bare `import "./env"` in the startup plugin gets
  tree-shaken away — the startup check has silently vanished exactly that way once
  already. That is why the plugin *uses* the value it imports, and why the refuse-to-boot
  behaviour is pinned by an e2e scenario (`frontend/tests/e2e/runtime-config.spec.ts`)
  rather than by reading the source.
- Running N copies has an operational bill the template cannot pay for you, so it is
  written down in `docs/DEPLOY.md`: copies × `DB_POOL_MAX` must stay under the database's
  connection limit; `TRUSTED_PROXY_HOPS` must match the number of proxies actually in
  front of the app; and the network between the copies and the shared services can be slow
  or drop.
- The proof that copies are interchangeable is a stand someone has to start. Nothing runs
  it automatically, so a regression here is found the next time someone looks — the
  accepted cost of having no CI.
