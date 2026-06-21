---
date: 2026-06-21
topic: Applying audit fixes + verifying the Docker prod build
area: cross
tags: [docker, dockerignore, vite, ssr, env, health, verification]
---

## What went badly
- The frontend production image returned HTTP 500 on every request: `Error: Missing required environment variables: VITE_OIDC_AUTHORITY, ...`. Adding `.env`/`.env.*` to the frontend `.dockerignore` (an earlier "secrets" hardening) starved the in-image `npm run build:vite` of the `VITE_*` vars, so Vite inlined them as `undefined`. `env.ts` (now a hard `throw`) then failed on every SSR render.
- `task check`, `task test:all`, `npm run check`, `npm run test:all` and even the Playwright e2e build all PASSED while the Docker image was broken — none of them exercises the actual `docker compose` production image, and they build with `.env` present in the repo.
- A stale dev server from a previous session (an old `server` binary on `:4099` + a `/tmp/wgo_*` from days earlier) held the port, so the first `start:dev` check got a misleading `/health 200` from the *old* code while the new server logged `bind: address already in use`.

## Root cause
- A backend-style hardening (`.env` is read at runtime there, so excluding it from the image is correct) was copy-pasted to the frontend, where Vite reads `VITE_*` at **build time** and the multi-stage runtime image never contains `.env` anyway. Wrong altitude: the rule didn't fit the build model.
- "Tests/lint pass" was treated as "ship-ready" without running the one artifact that actually differs — the production container.
- Didn't check for leftover processes before trusting a health probe on a fixed port.

## Rule — do this next time
- When changing `.dockerignore`, build-time env handling, or the Dockerfile of a **Vite/SSR** app, verify by actually running `docker compose up --build` and hitting the container — local `build`/`check`/e2e all pass with `.env` present and will not catch a starved image.
- Never add `.env` to a **frontend** Vite app's `.dockerignore`: `VITE_*` are public, needed at build time, and absent from the multi-stage runtime image regardless. (`.env` exclusion is a backend-only pattern.)
- Before trusting a `/health` or port probe in `start:dev`, run `ss -ltnp | grep :<port>` and kill stale `server`/`wgo`/`vite` leftovers first — a 200 from an old process masks a broken new build.
