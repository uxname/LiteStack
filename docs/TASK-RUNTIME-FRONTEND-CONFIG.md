# TASK — Runtime frontend config: build once, deploy many

Status: PROPOSED (not started). Suggested flow: run through the full devsolo
cycle when picked up.

## Problem

Vite inlines `import.meta.env.VITE_*` into the bundle at BUILD time, so one
frontend image fits exactly one environment. In the build-server → registry →
run-server flow this means:

- every environment needs its own rebuild and its own tag (`prod-v…`,
  `staging-v…`) — the opposite of the classic build-once-deploy-many pipeline;
- a tag built with the wrong environment's `.env` boots GREEN and silently
  points users at the wrong backend (the worst failure mode found in review);
- rotating a domain invalidates every already-built image.

## Goal

One frontend artifact promoted dev → staging → prod; environment supplied
only as RUNTIME env of the container. No rebuild to move between
environments; mis-tagging becomes impossible by construction.

## Approach sketch

- The SSR server (Nitro) already runs Node: expose `GET /config.json`
  (nitroV2Plugin `handlers`) returning the environment-specific values read
  from `process.env` at request/boot time.
- Server-side rendering reads the same values directly from `process.env`
  (no fetch, no flash). The browser client fetches `/config.json` once at
  bootstrap and caches it in the existing config layer
  (`src/shared/config/env.ts` is the single choke point today).
- Container env plumbing already exists: prod compose passes env via
  `environment:` mappings / `.env`; nothing to change in Docker or compose.
- Migrate consumers off `import.meta.env.VITE_*` (grep is small: shared/config
  is the choke point by design).

## Scope

- `frontend/src/shared/config/**`, bootstrap wiring for the client fetch,
  e2e updates (assert behavior under two different env sets WITHOUT rebuild).
- Docs: DEPLOY.md doctrine section ("one image = one environment" becomes
  "one image, many environments"), ENV-CONTRACT.md rows for the migrated
  vars, LikeC4 diagram text.
- Out of scope: backend, registry/CI tooling, PWA/service-worker strategy.

## Exit criteria

1. A single image starts correctly into two different environments by changing
   only container environment variables (proven by an automated check).
2. Full gates green on both sides; new config layer covered by tests per
   frontend coverage floors.
3. DEPLOY.md / ENV-CONTRACT.md / LikeC4 updated in the same change.

## Known trade-offs to decide during design

- Which values stay build-time (true constants) vs become runtime.
- Client fetch latency on first paint vs inline-bootstrapping config into the
  SSR HTML payload.
- Public values only: the endpoint must never expose server-side secrets.
