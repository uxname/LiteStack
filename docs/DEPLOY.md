# Deploy runbook — backend + frontend

One page for every way this template gets deployed. Commands below are verified
against `backend/Taskfile.yml`, `backend/docker-compose*.yml`,
`frontend/docker-compose*.yml` and `frontend/package.json`.

## How this template deploys

- **No CI, by design.** Every gate lives in the submodules' git hooks
  (`task check` / `npm run check`, plus the push-time test suites). Nothing runs
  on a server after you push — deploying is always an explicit action.
- **Images are plain `docker build`s**, wrapped as `task docker:build` (backend)
  and `npm run docker:build` (frontend).
- **One image runs in every environment — on both sides.** Each server reads its
  configuration from the container's environment when it starts, so an image tag
  names *the code* and nothing else: promote the same tag from dev to staging to
  production and change only the variables around it.
  - The frontend's public values (`VITE_OIDC_*`, `VITE_GRAPHQL_API_URL`,
    `VITE_BASE_URL`, `VITE_SENTRY_DSN`, `VITE_APP_VERSION`) are read at boot by
    `frontend/src/shared/config/env.ts`, which is the single list of them.
  - Four frontend values belong to the **build** instead, on purpose:
    `VITE_MOCK_AUTH` (fake logins must not be switchable on a running container)
    and `VITE_SENTRY_ORG` / `VITE_SENTRY_PROJECT` / `VITE_SENTRY_AUTH_TOKEN`
    (they only upload source maps while building, and the token is a real secret
    that must never reach a container). Set those in the build environment.
- **Neither production compose publishes a host port.** Both join an *external*
  network the reverse proxy already runs on, named by `PROXY_NETWORK`
  (default `dokploy-network`), and the proxy reaches the container directly —
  port 4000 on the backend, 3000 on the frontend. A published host port would
  let only one copy of each side exist per machine.
- **Neither app keeps state of its own.** Uploads go to object storage,
  authentication is a bearer token the client carries, cache and jobs live in the
  shared Redis. So the copies differ by container name and nothing else — see
  [Running more than one copy](#running-more-than-one-copy).

Why the shape is this and not another:
[ADR-0005](./adr/0005-horizontal-scaling-and-runtime-frontend-config.md), and on
the backend side `backend/docs/adr/0002-object-storage-and-trusted-client-ip.md`.

## Local development

Two equivalent paths per side — pick one.

**Backend** (`backend/`):

```bash
cp .env.example .env
docker compose up -d      # all-in-one: app + Postgres + Redis + Garage + admin dashboards
```

The dev compose is the whole environment: Postgres, Redis, a
[Garage](https://garagehq.deuxfleurs.fr) object store for uploaded files, and
pgweb / RedisInsight / Asynqmon behind a Caddy Basic-Auth proxy
(`ADMIN_USER`/`ADMIN_PASSWORD`, host ports
`DB_STUDIO_PORT`/`REDIS_STUDIO_PORT`/`ASYNQMON_PORT`). Garage sets itself up on
the first `up` — a `garage-init` container writes the cluster layout, the access
key and the bucket — so there is no manual step after `up`.

> **Requires Docker Engine 27.4 or newer.** `garage-init` mounts the Garage
> binary straight out of the Garage image (`type: image`, added in 27.4), which
> is the only way to run its CLI: that image is built `FROM scratch` and contains
> no shell. On an older Engine the `up` fails on that mount.

For code work prefer hot-reload: `task start:dev` (brings up db+redis in Docker,
runs the server locally with wgo). First clone: `task setup`. Neither of those
starts the object store, so add `docker compose up -d garage garage-init` when
you want `POST /upload` to work — the app boots without it and only fails when a
file is actually uploaded.

**Frontend** (`frontend/`):

```bash
cp .env.example .env
docker compose up -d      # SSR container; PORT picks the HOST port, container listens on 3000
```

or the dev server: `npm run gen` (backend must be running) → `npm run start:dev`.

> **What `npm run gen` needs.** It reads the live schema from the address in
> `VITE_GRAPHQL_API_URL`, so it needs two things: that **variable present in the
> environment**, and the backend **reachable** at it. The `.env` file is just the
> usual way to supply the variable (`npm run gen` loads it), not a requirement of
> its own — `VITE_GRAPHQL_API_URL=… npm run gen` works the same. When the
> variable is missing, the address collapses to the string `undefined` and
> codegen fails with `Failed to load schema from undefined` — a message that
> never says "variable", so check the variable before you suspect the backend.

`frontend/.env` is for local development only. It is excluded from the Docker
build context (`.dockerignore`), so it can never end up inside an image.

After editing any `.env`, run `scripts/doctor.sh` from the meta root to verify
the cross-project pairs (see [ENV-CONTRACT.md](./ENV-CONTRACT.md)).

## Health probes — which URL to point what at

The backend answers two different questions at two URLs, and they are not
interchangeable. Point each consumer at the right one.

| URL | Answers | Touches | Point at it |
|---|---|---|---|
| `GET /livez` (backend) | "Is this process running?" | nothing external | The **orchestrator's restart probe**. Already the image's `HEALTHCHECK` (`server -healthcheck`) — do not override it. |
| `GET /readyz` (backend) | "Can this copy serve traffic right now?" | Postgres, Redis, its own heap; 503 when one is unusable | The **reverse proxy's** traffic gate, so a copy with a broken dependency is skipped instead of being restarted. |
| `GET /health` (backend) | same as `/readyz` | same as `/readyz` | An alias, kept so existing monitoring keeps working. New configuration should name `/readyz`. |
| `GET /health.txt` (frontend) | "Is the SSR server up?" | nothing | Both the image `HEALTHCHECK` and the proxy. It is a static file, so probing it costs no page render. |

The split matters the moment there is more than one copy: every orchestrator
answers a failed **liveness** probe by killing the container. If liveness pinged
the database, one database blip would restart the entire fleet at once, instead
of briefly draining traffic away from it.

## Running more than one copy

Both production composes are already shaped for it — no host port, no volume, no
per-copy state — so raising the count is one flag:

```bash
cd backend  && docker compose -f docker-compose.prod.yml up -d --scale app=3
cd frontend && docker compose -f docker-compose.prod.yml up -d --scale app=2
```

The reverse proxy on `PROXY_NETWORK` load-balances across the copies by service
name; gate its traffic on `/readyz` (backend) and `/health.txt` (frontend).
Under Dokploy the same thing is the Application's *replicas* setting.

Three things to get right before you raise the number. Each one fails quietly if
you don't — the stack keeps answering, just wrongly.

### 1. The copies are not on one machine

A copy may sit on a different host from the database, the Redis, the object
storage and the other copies. Every call between them is a call over the network,
and a call over the network is slow sometimes and fails outright sometimes — the
same call between two processes on one machine is neither. So set timeouts and
expect retries on anything crossing a container boundary, and read a slow request
as a network question first. `db_query_slow` lines, and `/readyz` flapping on one
copy but not another, are the usual first symptom (see
`backend/docs/DEBUGGING.md`).

### 2. Copies share the database's connection limit

`DB_POOL_MAX` (default 10) is the pool size of **one** copy. The sizing rule,
written the same way in `backend/.env.example`, `internal/config/config.go` and
`internal/db/pool.go`:

> replicas x `DB_POOL_MAX` must stay below the Postgres `max_connections` limit
> (default 100)

Leave room under it for migrations, `psql` sessions and the dashboards. Cross the
limit and new connections are refused: copies fail readiness in turn while each
one, on its own, looks perfectly healthy.

### 3. `TRUSTED_PROXY_HOPS` must equal the number of proxies you actually run

The client's address is taken from `X-Forwarded-For` counting
`TRUSTED_PROXY_HOPS` entries **from the right**, because each proxy appends to
the header and only the rightmost entries were written by a proxy rather than by
the caller. That address is the rate limiter's key.

The default of `1` is one proxy — your own Caddy, Traefik or nginx. **Two is a
realistic number**: a cloud load balancer or CDN in front of your own proxy adds
a hop, and so does a corporate egress proxy. `0` means there is no proxy at all,
and then both `X-Forwarded-For` and `X-Real-IP` are ignored entirely, since
nobody but the caller could have written them.

Both mistakes are silent — nothing logs, nothing 500s:

- **Too high.** The caller can pad the header with addresses of its own until the
  count reaches back into the part it wrote, so it picks its own rate-limit key
  and gets a fresh bucket per forged value. This is the dangerous direction: it
  gives the limit away.
- **Too low.** You end up reading an address one of your own proxies wrote about
  another proxy, which is the same value for everyone. Every client on the
  internet then shares a single bucket, and normal traffic starts hitting 429.

Count the proxies between the internet and the container and set the number to
that.

## Production — recommended path: Dokploy

[Dokploy](https://dokploy.com) is a self-hosted PaaS; one server runs the panel,
Traefik, and your containers. Recommended shape:

1. **Databases as Dokploy native services.** Create a **PostgreSQL** service and
   a **Redis** service in your Dokploy project, and configure an **S3
   destination** plus a backup schedule on the Postgres service. Do not run
   production databases from the app compose.
2. **Object storage for uploads.** The backend needs an S3-compatible bucket that
   every copy can reach and the browser can download from: a managed one (AWS S3,
   Cloudflare R2, Backblaze B2, …) or a Garage/MinIO you run yourself. The
   production compose deliberately does **not** contain one — storage is an
   external service, exactly like Postgres and Redis.
3. **Backend as a Dokploy Application.** Either build type *Dockerfile* pointed
   at the backend repo (Dokploy builds `backend/Dockerfile` on deploy), or
   provider *Docker image* pulling a prebuilt `liteend` image from your registry
   (see the registry flow below). Set the runtime env in Dokploy:
   `DATABASE_*` and `REDIS_*` pointing at the two Dokploy services (use their
   internal hostnames), the `S3_*` set from step 2, plus `NODE_ENV=production`,
   `CORS_ORIGIN` (the frontend origin), and the `OIDC_*` set. Attach a domain;
   Traefik terminates TLS.
4. **Frontend as a Dokploy Application.** Build type *Dockerfile* on the frontend
   repo, or provider *Docker image* for a prebuilt `litefront` tag — the same tag
   works for every environment. Set that environment's public values as runtime
   variables: `VITE_OIDC_AUTHORITY`, `VITE_OIDC_CLIENT_ID`,
   `VITE_OIDC_REDIRECT_URI`, `VITE_OIDC_SCOPE` and `VITE_GRAPHQL_API_URL` are
   required; `VITE_OIDC_API_RESOURCE`, `VITE_BASE_URL`, `VITE_SENTRY_DSN` and
   `VITE_APP_VERSION` are optional. Miss a required one and the server refuses to
   start, naming it in the log.
5. **Env checklist:** every must-match pair lives in
   [ENV-CONTRACT.md](./ENV-CONTRACT.md). Run through it before the first deploy.

## Registry flow — build on one machine, run on another

Conventions (both sides): `IMAGE_REGISTRY` is a prefix **with a trailing
slash**, `IMAGE_TAG` defaults to `latest`. Any registry works: GitHub
(`ghcr.io/acme/`), a Docker Hub namespace (`docker.io/acme/`), or self-hosted
(`registry.acme.com:5000/acme/`); empty means Docker Hub top-level. Private
registry? `docker login` on the BUILD host before pushing and on the RUN host
before pulling (pulling public images needs no login).

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

On the target host (compose reads the same two variables from `.env`; the same
tag is the right one for every environment):

```bash
cd backend
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

cd ../frontend
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

or point a Dokploy Application's *Docker image* provider at the pushed image.
Both `docker-compose.prod.yml` files have **no `build:` on purpose** — a failed
pull fails the deploy instead of silently rebuilding from whatever source sits
on the host. Building and running on the **same** machine (no registry) is
simply `task docker:build && docker compose -f docker-compose.prod.yml up -d`
(backend) or `npm run docker:build && docker compose -f docker-compose.prod.yml
up -d` (frontend).

**Registry-flow rules (both sides):**

- **Always `pull` before `up -d`.** If the tag was not re-pushed, pull returns
  the same digest and `up -d` recreates nothing — a green-looking deploy that
  ships last week's image. Verify what actually runs:
  `docker compose -f docker-compose.prod.yml images`.
- **Tag the code, not the environment** (`v1.2.0`, a commit sha). One tag is
  meant to run everywhere, so promoting to production means pointing production
  at the tag staging already proved. **Avoid a floating `latest`:** two hosts
  pulling `latest` a week apart run different code and neither can say which, and
  rolling back needs an immutable tag to roll back *to*.
- **Roll back** by re-upping the previous tag (shell vars override `.env`):
  `IMAGE_TAG=v1.1.0 docker compose -f docker-compose.prod.yml pull &&
  IMAGE_TAG=v1.1.0 docker compose -f docker-compose.prod.yml up -d`.
  Backend caveat: migrations are forward-only (embedded goose has no down
  path), so rolling the image back does NOT roll the schema back.
- **Point every environment at its own database.** Outside production an empty
  backend `CORS_ORIGIN` allows every origin, so a stack wired to the wrong
  database looks completely healthy while recording real users into it. The
  `.env` on the host is what decides this — check it, not the image tag.
- **Config on the run host.** Both prod composes read a `.env` next to the
  compose file OR plain exported variables, and both fail loudly at
  `docker compose config` time, naming the missing variable, instead of booting
  half-configured.

## Production without Dokploy (bare VPS)

Both sides run behind one reverse proxy of your own (Caddy, Traefik, nginx). It
owns TLS and the public ports; the app containers publish nothing.

1. **Create the proxy network once** and run the proxy on it:

   ```bash
   docker network create dokploy-network     # any name; set PROXY_NETWORK to match
   ```

2. **Backend:** `backend/docker-compose.prod.yml` runs the **app only** — no
   database, no Redis, no object storage on purpose. Provide your own and point
   `DATABASE_*`, `REDIS_*` and `S3_*` at them through `.env` or exported
   variables. Mind name resolution: a service name from a *neighboring* compose
   project (e.g. `db`) only resolves if both projects share a network — otherwise
   use the host's address.
3. **Frontend:** `frontend/docker-compose.prod.yml` runs this environment's
   variables against any `litefront` tag. To run the source in this checkout
   instead, `frontend/docker-compose.yml` has `pull_policy: build` and rebuilds
   on every `up`.
4. **Point the proxy at the container names** on that network, `app:4000` and
   `app:3000`, and health-gate them on `/readyz` and `/health.txt`. With several
   copies, Docker's DNS returns every copy's address for the service name.

`scale/` in this repo is a working example of exactly this shape — two copies of
each side behind one Caddy — and its `Caddyfile` is a fine starting point for
your own. Read it as a wiring reference only: it runs with
`NODE_ENV=development` and mock authentication on purpose, so it is **not** a
model for a production posture.

## Where uploaded files live

Uploads go to S3-compatible object storage — the one place every copy can reach.
Two addresses configure it, and they are almost never the same value:

- `S3_ENDPOINT` — the storage as **the app** sees it, from inside the network.
- `S3_PUBLIC_BASE_URL` — the prefix of the link **the browser** follows from
  outside. It **includes the bucket name** as the browser sees it. A file's URL
  is this value plus `/` plus the object key, and that URL is what the backend
  stores in the database and returns.

Plus `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_BUCKET` (default `uploads`)
and `S3_USE_SSL` (`true` only when `S3_ENDPOINT` is https).

Links are public and permanent: the bucket is readable, and a file's name is a
UUID, so the URL is unguessable but not access-controlled. Do not put anything
in there that must be authorized to read. Back the bucket up with your storage
provider's own tooling; the app never keeps a second copy.

## Backups

The database is one `pg_dump` away — schedule it with cron:

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

Migrations run themselves when the backend starts, under a Postgres advisory
lock, so several copies booting at once against an empty database queue up
behind one another instead of racing.
