# Deploy runbook — backend + frontend

One page for every way this template gets deployed. Commands below are verified
against `backend/Taskfile.yml`, `backend/docker-compose*.yml`,
`frontend/docker-compose.yml` and `frontend/package.json`.

## How this template deploys

- **No CI, by design.** Every gate lives in the submodules' git hooks
  (`task check` / `npm run check`, plus the push-time test suites). Nothing runs
  on a server after you push — deploying is always an explicit action.
- **Images are plain `docker build`s**, wrapped as `task docker:build` (backend)
  and `npm run docker:build` (frontend).
- **One frontend image = one environment.** Vite inlines every `VITE_*` value
  into the JS bundle at **build** time, so the image is baked for exactly the
  environment whose `.env` was present at build. You cannot re-point a built
  frontend image at another backend — rebuild instead. The backend image is
  environment-agnostic (all config is runtime env).

## Local development

Two equivalent paths per side — pick one.

**Backend** (`backend/`):

```bash
cp .env.example .env
docker compose up -d      # all-in-one: app + Postgres + Redis + admin dashboards
```

The dev compose also starts pgweb, RedisInsight and Asynqmon behind a Caddy
Basic-Auth proxy (`ADMIN_USER`/`ADMIN_PASSWORD`, host ports
`DB_STUDIO_PORT`/`REDIS_STUDIO_PORT`/`ASYNQMON_PORT`). For code work prefer
hot-reload: `task start:dev` (brings up only db+redis in Docker, runs the server
locally with wgo). First clone: `task setup`.

**Frontend** (`frontend/`):

```bash
cp .env.example .env
docker compose up -d      # SSR container; PORT picks the HOST port, container listens on 3000
```

or the dev server: `npm run gen` (backend must be running) → `npm run start:dev`.

After editing any `.env`, run `scripts/doctor.sh` from the meta root to verify
the cross-project pairs (see [ENV-CONTRACT.md](./ENV-CONTRACT.md)).

## Production — recommended path: Dokploy

[Dokploy](https://dokploy.com) is a self-hosted PaaS; one server runs the panel,
Traefik, and your containers. Recommended shape:

1. **Databases as Dokploy native services.** Create a **PostgreSQL** service and
   a **Redis** service in your Dokploy project. Their built-in backup/restore
   replaces the backup tool this template used to ship (it was removed) —
   configure an **S3 destination** in Dokploy and attach a backup schedule to
   the Postgres service. Do not run production databases from the app compose.
2. **Backend as a Dokploy Application.** Either build type *Dockerfile* pointed
   at the backend repo (Dokploy builds `backend/Dockerfile` on deploy), or
   provider *Docker image* pulling a prebuilt `liteend` image from your registry
   (see the registry flow below). Set the runtime env in Dokploy:
   `DATABASE_HOST`/`DATABASE_PORT`/`DATABASE_USER`/`DATABASE_PASSWORD`/`DATABASE_NAME`
   and `REDIS_HOST`/`REDIS_PORT`/`REDIS_PASSWORD` pointing at the two Dokploy
   services (use their internal hostnames), plus `NODE_ENV=production`,
   `CORS_ORIGIN` (the frontend origin), and the `OIDC_*` set. Attach a domain;
   Traefik terminates TLS. Add a persistent volume mount for `/app/data/uploads`.
3. **Frontend as a Dokploy Application, built AT DEPLOY TIME.** Build type
   *Dockerfile* on the frontend repo, with that environment's `VITE_*` variables
   set in Dokploy so the build bakes them in (see "one image = one environment"
   above). A staging and a production frontend are two Applications with two
   different `VITE_*` sets — never one shared image.
4. **Env checklist:** every must-match pair lives in
   [ENV-CONTRACT.md](./ENV-CONTRACT.md). Run through it before the first deploy.

## Registry flow — build on one machine, run on another

Conventions (both sides): `IMAGE_REGISTRY` is a prefix **with a trailing
slash** (e.g. `ghcr.io/acme/`), `IMAGE_TAG` defaults to `latest`.

```bash
# Backend — produces <IMAGE_REGISTRY>liteend:<IMAGE_TAG>
cd backend
IMAGE_REGISTRY=ghcr.io/acme/ IMAGE_TAG=v1.2.0 task docker:build
IMAGE_REGISTRY=ghcr.io/acme/ IMAGE_TAG=v1.2.0 task docker:push

# Frontend — produces <IMAGE_REGISTRY>litefront:<IMAGE_TAG>
cd frontend
IMAGE_REGISTRY=ghcr.io/acme/ IMAGE_TAG=v1.2.0 npm run docker:build
IMAGE_REGISTRY=ghcr.io/acme/ IMAGE_TAG=v1.2.0 npm run docker:push
```

On the target host (compose reads the same two variables from `.env`):

```bash
cd backend
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

or point a Dokploy Application's *Docker image* provider at the pushed image.
`docker-compose.prod.yml` has **no `build:` on purpose** — a failed pull fails
the deploy instead of silently rebuilding from whatever source sits on the
host. Building and running on the **same** machine (no registry) is simply:
`task docker:build && docker compose -f docker-compose.prod.yml up -d`.

**Frontend caveat, again:** a prebuilt frontend image carries its `VITE_*`
values, so pushing one to a registry only makes sense **per environment**
(e.g. `litefront:prod-v1.2.0` built with the production `.env`).

## Production without Dokploy (bare VPS)

- **Backend:** `backend/docker-compose.prod.yml` runs the **app only** — no
  database services on purpose. Provide your own Postgres and Redis (any
  compose project or a managed service) and point `DATABASE_HOST`/`REDIS_HOST`
  (+ ports/credentials) at them in `.env`. Mind the network: the prod compose
  creates its own default network, so a service name from a *neighboring*
  compose project (e.g. `db`) does not resolve — either join both projects to
  one shared external network (same mechanism as the commented dokploy-network
  block inside the file) or point `DATABASE_HOST` at the host itself. The app
  publishes on `127.0.0.1:$PORT` only — put your reverse proxy (TLS) in front,
  or use the Dokploy/Traefik network variant commented inside the file.
- **Frontend:** build the image on the target host (so its `VITE_*` match) and
  run it with `frontend/docker-compose.yml` — its `pull_policy: build` rebuilds
  on every `up`, so the running bundle always matches the checkout's `.env`. To
  run that environment's **prebuilt** image instead, pull it with plain docker
  (`pull_policy: build` makes `docker compose pull` skip this service):
  `docker pull "${IMAGE_REGISTRY}litefront:${IMAGE_TAG}"`, then
  `docker compose up -d --no-build`. The app publishes on `127.0.0.1:$PORT`
  only — same reverse-proxy rule as the backend.
- **Backups** are one `pg_dump` away — schedule it with cron:

```bash
# Backup (custom format, self-compressing). PGPASSWORD + discrete flags, not a
# postgres:// URI: a password with #, @, / or spaces breaks the URI form.
PGPASSWORD="$DATABASE_PASSWORD" pg_dump \
  -h "$DATABASE_HOST" -p "$DATABASE_PORT" -U "$DATABASE_USER" -d "$DATABASE_NAME" \
  -F c -f "backup-$(date +%F).dump"

# Restore
PGPASSWORD="$DATABASE_PASSWORD" pg_restore --clean --if-exists --exit-on-error \
  -h "$DATABASE_HOST" -p "$DATABASE_PORT" -U "$DATABASE_USER" -d "$DATABASE_NAME" \
  backup-2026-08-13.dump
```

- **Uploads persistence:** user uploads live in the named volume `uploads`
  (mounted at `/app/data/uploads`). It survives redeploys and
  `docker compose down`, but `down -v` destroys it — include the volume in your
  backup routine if uploads matter.
