# ADR 0006: environment variables are the configuration source; `.env` is optional

- **Date:** 2026-09-05
- **Status:** accepted

## Context

Both apps already read plain environment variables: the backend calls `godotenv.Load()`
and ignores a missing file, the frontend's `configDotenv()` never overrides an exported
variable, and both prod compose files were built for hosts with no `.env` at all
(explicit `environment:` mappings, `env_file: required: false`).

Three pieces contradicted that, and each failed hard without the file:

- both **dev** `docker-compose.yml` files used `env_file: - .env`, so `docker compose`
  refused to render the file at all — before starting anything;
- `scripts/doctor.sh` read values only from files, reported a missing `.env` as a failure,
  and silently borrowed `.env.example` values for its diagnostics;
- `task compose:check` / `npm run compose:check` skipped dev-compose validation entirely
  on any machine without a `.env` ("requires .env by design").

Deployment targets that inject configuration as environment variables (Dokploy, CI
runners, `docker run -e`, systemd units, direnv shells) therefore could not run the dev
stack, and the one checker meant to catch configuration drift was blind to the way those
targets actually configure it.

## Decision

Configuration is read **from the environment**. A `.env` file is one optional way to put
values there and is never required: every compose file lists its variables explicitly and
loads `.env` only `required: false`, and `scripts/doctor.sh` resolves each value as
exported-variable-first, then that side's `.env`, and **never** from `.env.example`.

A missing value fails loudly and by name — `${VAR:?...}` at `docker compose config` time
in both dev and prod compose files, exactly the guards the app's own config declares
`required`.

## Alternatives

- **Keep `env_file: .env` in dev and document the file as mandatory** — lost: it is the
  status quo that blocks every env-var-only host, and it kept two different configuration
  models for the same two apps.
- **Drop `.env` support entirely** — lost: `.env` is the shortest path for a fresh clone,
  and removing it would break every existing checkout for no gain.
- **Give the dev compose working defaults for everything, so `up` needs no configuration**
  — lost: a stack that silently boots on invented credentials hides a misconfiguration
  until it reaches something real. Defaults are kept only where the app itself has one.

## Consequences

- One configuration model everywhere: dev and prod, container and host, read the same way.
- `compose:check` now validates **both** compose files hermetically on every machine, so a
  YAML or interpolation error in the dev file can no longer reach a commit.
- `PORT` is the price: it is the one variable name both sides use, so a single shell
  cannot hold both values and it must be exported per side. `doctor.sh` sidesteps this by
  taking the frontend's port from `VITE_BASE_URL`, the origin the browser actually uses.
- `doctor.sh` is stricter than it was: values it cannot find are reported unset instead of
  being filled in from `.env.example`. A `.env` that is missing a required variable — the
  usual result of pulling a template update — now fails the check instead of looking
  green while the app refuses to boot.
