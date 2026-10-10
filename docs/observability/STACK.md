# The shared observability server — deploy and run it

One server, set up once, serves every product. This page takes it from an empty
machine to alerts arriving in Telegram. Each step ends with a check you can run.

Versions below were current on 2026-10-10. Pin exact tags (never `latest`) and bump them
deliberately, re-checking the memory budget after each bump.

## 0. What you need

- A machine with **8 GB RAM**, 4 vCPU, 80 GB+ SSD, x86_64 (or ARMv8.2-A+ — ClickHouse
  needs it). Not the machine your products run on: if a product server dies, this one
  must still be up to tell you so.
- [Dokploy](https://docs.dokploy.com) installed on it, and one DNS name per tool:
  `o2.example.com`, `glitchtip.example.com`, `rybbit.example.com`. Dokploy's Traefik
  issues the TLS certificates; every tool must be served over **HTTPS** (Rybbit's
  sign-in does not work over plain http).
- A Telegram bot (create it with `@BotFather`, `/newbot`) and the chat id that should
  receive alerts (`@userinfobot` tells you yours; a group id starts with `-100`).

## 1. Memory budget

The three tools fit in 8 GB only with explicit limits. Set `mem_limit` on every service
when you deploy it (Dokploy: edit the template's compose before the first deploy).

| Service | Limit | Note |
|---|---|---|
| OpenObserve | 1.5 GB | Caches scale to the container limit (read from the cgroup) |
| GlitchTip `web` + `worker` | 512 MB each | Vendor minimum 256 MB all-in-one |
| GlitchTip Postgres + Valkey | 512 MB + 128 MB | |
| Rybbit ClickHouse | 1.5 GB | Respects the container limit; see the low-memory file below |
| Rybbit Postgres + Redis | 256 MB + 128 MB | |
| Rybbit backend + client | 512 MB + 256 MB | |
| **Sum** | **~5.8 GB** | Leaves ~2 GB for Dokploy itself (its Postgres, Redis, Traefik) and the OS |

These are starting points, not measurements. Watch `docker stats` for the first week
and move the limits; an OOM-killed container (`docker inspect <c> | grep OOMKilled`)
means its limit is too low, not that the server is too small.

## 2. OpenObserve — logs, metrics, traces, alerts

Dokploy → Create Service → Template → **OpenObserve**. Then, before deploying:

- **Image:** the template pins `v0.70.0`, which is old. Set
  `public.ecr.aws/zinclabs/openobserve:v1.0.4` (the stable release on 2026-10-10).
- **Environment** (add to the template's three):

  ```env
  ZO_WEB_URL=https://o2.example.com          # alert messages link back here
  ZO_COMPACT_DATA_RETENTION_DAYS=14          # default is 3650; minimum 3
  ZO_TELEMETRY=false
  ZO_MMDB_DISABLE_DOWNLOAD=true              # skips the GeoIP db (~140 MB of RAM)
  ZO_MEM_TABLE_MAX_SIZE=256                  # MB
  ZO_MEMORY_CACHE_DATAFUSION_MAX_SIZE=512    # MB, query memory
  ZO_MAX_FILE_SIZE_IN_MEMORY=128             # MB
  ```

- **Domain:** port `5080`, HTTPS. Do not expose `5081` (gRPC); product servers send
  OTLP over HTTPS to `5080` through Traefik.
- Storage is the local volume (`/data`); S3 is only needed for a multi-node cluster.

**Check:** sign in at `https://o2.example.com` with `ZO_ROOT_USER_EMAIL` /
`ZO_ROOT_USER_PASSWORD`. Every product gets its own **organization** (Settings →
Organizations) — `default` is fine for the first one.

## 3. GlitchTip — errors

Dokploy → Template → **Glitchtip** (6.1.0). Fix three things in its compose **before
the first deploy**:

1. **Postgres volume.** The template runs `postgres:18` with `pg-data:/var/lib/postgresql/data`;
   Postgres 18 refuses to start with a mount there. Change it to
   `pg-data:/var/lib/postgresql`.
2. **Email.** `EMAIL_URL: consolemail://` is written into the compose itself, so an env
   var cannot override it. Replace it with your SMTP URL
   (`smtp+tls://user:password@smtp.example.com:587`, special characters URL-encoded) —
   or leave it if nobody needs invitation or password-reset mail.
3. **Add to the shared environment block:**

   ```env
   ENABLE_USER_REGISTRATION=False     # after you create the first (admin) account
   GLITCHTIP_ENABLE_LOGS=False        # logs belong to OpenObserve (default is True)
   GLITCHTIP_RETENTION_DAYS=90
   GLITCHTIP_ENABLE_MCP=True          # optional: the MCP endpoint for agents
   ```

   Deploy once with registration still on, create your account, then set it to `False`
   and redeploy.

The `uploads` volume holds uploaded source maps; web and worker must share it (the
template already mounts it on both) and it must be backed up.

**Check:** open `https://glitchtip.example.com`, create an organization and one
**project per app side** (`<product>-frontend`, `<product>-backend`). Each project's
settings page shows its **DSN** — that is the value `VITE_SENTRY_DSN` and the backend's
`SENTRY_DSN` take. A test event from the DSN `https://<key>@glitchtip.example.com/<id>`
must make an issue appear:

```bash
curl -X POST "https://glitchtip.example.com/api/<id>/store/?sentry_version=7&sentry_key=<key>" \
  -H 'Content-Type: application/json' -d '{"message":"hello from the runbook","level":"error"}'
```

## 4. Rybbit — product analytics

Dokploy → Template → **Rybbit**. Before deploying:

- **Images:** the template pins `v2.7.0`. Use **v2.8.0 or newer** for both
  `rybbit-backend` and `rybbit-client` — the MCP endpoint first ships in 2.8.0. Check
  the [releases](https://github.com/rybbit-io/rybbit/releases) and pin one tag.
- **Environment:** set `BASE_URL=https://rybbit.example.com` (the template writes
  `http://`, which breaks sign-in), `DISABLE_TELEMETRY=true`, and after you create the
  first account `DISABLE_SIGNUP=true` (redeploy).
- **ClickHouse on little memory** — the template mounts the folder
  `../files/clickhouse_config` as ClickHouse's `/etc/clickhouse-server/config.d`. Add
  one more file mount in Dokploy (the service → Advanced → Mounts → File mount) with
  the path `./clickhouse_config/low_memory.xml`, so it lands in the same folder:

  ```xml
  <!-- ./clickhouse_config/low_memory.xml -->
  <clickhouse>
      <max_server_memory_usage_to_ram_ratio>0.8</max_server_memory_usage_to_ram_ratio>
      <mark_cache_size>268435456</mark_cache_size>
      <max_concurrent_queries>20</max_concurrent_queries>
  </clickhouse>
  ```

  The template's `user_logging.xml` holds *profile* settings, which ClickHouse reads only
  from `users.d`; in `config.d` it has no effect. Harmless — the `logging_rules.xml` next
  to it already switches the query logs off.

**Check:** sign in at `https://rybbit.example.com`, add a **site** per product (its
domain) and note the **site id** — [CONNECT.md](./CONNECT.md) needs it. In site
settings turn on *Track SPA navigation* and, if you want it, *Session replay*. Leave
*Capture errors* **off** — errors belong to GlitchTip. Leave *Track IP Address*
off — it is not GDPR-compliant.

## 5. The collector — one on every product server

Everything a product server knows reaches OpenObserve through one OpenTelemetry
Collector. Deploy it on **each product server** as a Dokploy Compose service.

**5.1. Let Docker put the service name on each log line.** Container log files do not
carry the container's name. In `/etc/docker/daemon.json` on the product server:

```json
{ "log-opts": { "labels-regex": "^com\\.docker\\.(compose\\.service|swarm\\.service\\.name)$" } }
```

Restart Docker. Only containers created afterwards get the label — redeploy the apps.

**5.2. `config.yaml`:**

```yaml
extensions:
  file_storage: { directory: /var/lib/otelcol, create_directory: true }   # read positions survive restarts
receivers:
  otlp:                                            # traces + metrics from the backend
    protocols: { grpc: { endpoint: 0.0.0.0:4317 }, http: { endpoint: 0.0.0.0:4318 } }
  file_log:                                        # every container's stdout
    include: [/var/lib/docker/containers/*/*-json.log]
    include_file_path: true
    storage: file_storage
    operators:
      - type: container
        format: docker
        add_metadata_from_filepath: false          # Kubernetes-only; errors on Docker paths
      - type: move
        if: 'attributes.attrs != nil and attributes.attrs["com.docker.compose.service"] != nil'
        from: attributes.attrs["com.docker.compose.service"]
        to: resource["service.name"]
      - type: move                                 # Dokploy Applications run as Swarm services
        if: 'attributes.attrs != nil and attributes.attrs["com.docker.swarm.service.name"] != nil'
        from: attributes.attrs["com.docker.swarm.service.name"]
        to: resource["service.name"]
      - type: json_parser                          # the apps' JSON lines → fields
        if: 'body matches "^\\s*\\{"'
        parse_from: body
        parse_to: attributes
        severity: { parse_from: attributes.level }
  hostmetrics:
    root_path: /hostfs
    collection_interval: 30s
    scrapers:
      cpu: {}
      load: {}
      disk: {}
      network: {}
      memory: { metrics: { system.memory.utilization: { enabled: true } } }          # off by default;
      filesystem: { metrics: { system.filesystem.utilization: { enabled: true } } }  # the alerts use them
  docker_stats: { endpoint: unix:///var/run/docker.sock, collection_interval: 30s }
processors:
  memory_limiter: { check_interval: 1s, limit_mib: 400, spike_limit_mib: 80 }
  resource: { attributes: [{ key: host.name, value: "${env:HOST_NAME}", action: upsert }] }
  batch: {}
exporters:
  otlphttp/logs:                                   # logs land in the "docker" stream
    endpoint: https://o2.example.com/api/default   # /api/<organization>, no trailing slash
    headers: { Authorization: "Basic ${env:O2_AUTH}", stream-name: docker }
  otlphttp:
    endpoint: https://o2.example.com/api/default
    headers: { Authorization: "Basic ${env:O2_AUTH}" }
service:
  extensions: [file_storage]
  pipelines:
    logs:    { receivers: [file_log, otlp], processors: [memory_limiter, resource, batch], exporters: [otlphttp/logs] }
    metrics: { receivers: [hostmetrics, docker_stats, otlp], processors: [memory_limiter, resource, batch], exporters: [otlphttp] }
    traces:  { receivers: [otlp], processors: [memory_limiter, resource, batch], exporters: [otlphttp] }
```

**5.3. The compose service:**

```yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.162.0
    user: "0"            # Docker's log directories and socket are root-only
    command: ["--config=/etc/otelcol-contrib/config.yaml"]
    environment:
      HOST_NAME: prod-1                       # this server's name in every signal
      O2_AUTH: ${O2_AUTH}                     # base64 of "<email>:<password or token>"
    volumes:
      - ./config.yaml:/etc/otelcol-contrib/config.yaml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /:/hostfs:ro
      - otel-state:/var/lib/otelcol
    mem_limit: 512m
    networks: [proxy]                         # the backend reaches it as otel-collector:4318
networks:
  proxy: { external: true, name: dokploy-network }
volumes:
  otel-state:
```

`O2_AUTH` is `echo -n 'email:password' | base64` for an OpenObserve user or service
account of that organization. Keep it in Dokploy's environment, never in a repo.

**Check:** run `docker run --rm -v ./config.yaml:/c.yaml otel/opentelemetry-collector-contrib:0.162.0 validate --config=/c.yaml`
before the first deploy. After it, OpenObserve → Logs → stream `docker` shows lines
from the app containers with `service_name` filled (dots in field names become
underscores), and Metrics shows `system_*` and `container_*` series.

## 6. Alerts → Telegram

All alerts are defined in OpenObserve, plus Dokploy's own deploy notices. Backend and
SSR errors need no GlitchTip alert: each one is also an `ERROR` log line, which alerts
below. **Browser errors are the exception** — they never reach a server log. For an
instant notice of those, turn on a GlitchTip project alert on the frontend project
(Project settings → Project Alerts, by email; needs SMTP from step 3). Without it,
browser errors are seen at triage time, not as they happen.

**6.1. Destination.** OpenObserve has no native Telegram target; use a webhook.
Management → Templates → new **Web Hook** template:

```json
{"chat_id": "-1001234567890", "text": "🔴 {alert_name} ({stream_name}): {alert_count} hits\n{rows:5}\n{alert_url}"}
```

Management → Destinations → new destination: URL
`https://api.telegram.org/bot<BOT_TOKEN>/sendMessage`, method POST, header
`Content-Type: application/json`, the template above.

**6.2. The minimum rule set.** Alerts → Add alert → Scheduled → SQL, on stream `docker`.
Field names follow the apps' log lines (`level`, `msg`, `status`, `service_name`).

| Alert | SQL (`WHERE` part) | Period / threshold |
|---|---|---|
| Any system-fault line | `level = 'ERROR'` | 5 min, ≥ 1 |
| Burst of server errors | `msg = 'http_request' AND status >= 500` | 5 min, ≥ 10 |
| Failed background job | `msg = 'job_failed'` | 15 min, ≥ 1 |
| Slow queries piling up | `msg = 'db_query_slow'` | 15 min, ≥ 20 |
| A service went silent | `service_name = '<backend>'` | 15 min, **< 1** |
| Disk filling up | metrics stream `system_filesystem_utilization`, value > 0.9 | 15 min |
| Memory exhausted | metrics stream `system_memory_utilization`, state `used`, value > 0.9 | 15 min |

Start with these; add one only when an incident shows a gap. A rule that fires daily
and is ignored is worse than no rule.

**6.3. Dokploy.** Settings → Notifications → Telegram (bot token + chat id) → enable
*App build error*, *App deploy*, *Database backup*, *Docker cleanup*. Dokploy also has
CPU / memory thresholds under Monitoring; its docs mark that screen as Cloud-only, so on
a self-hosted Dokploy rely on the two metrics alerts above.

**Check:** OpenObserve's destination has a *Test* button; Dokploy's notification too.
Both must deliver a message before you trust them.

## 7. Backups and upgrades

- **Back up:** GlitchTip's Postgres (Dokploy → the compose service → Backups, to an S3
  destination) and its `uploads` volume; Rybbit's Postgres (sites, users, funnels) and
  `clickhouse_data` (the events). OpenObserve's `/data` holds 14 days of telemetry —
  back it up only if losing that window matters to you.
- **Restore drill** once after setup: restore GlitchTip's Postgres into a scratch
  service and open one issue. An untested backup is a hope.
- **Upgrade:** one tool at a time. Read its release notes, bump the pinned tag, redeploy,
  run that tool's *Check* above, then update the versions in this file.

## 8. Adding a product

1. OpenObserve: an organization for it (or reuse `default`), and a user or service
   account whose credentials become that product's `O2_AUTH`.
2. GlitchTip: two projects (frontend, backend) → two DSNs.
3. Rybbit: a site → site id; an API key (Settings → Account → API Keys) for server-side
   events.
4. Product server: the collector from step 5, pointed at the product's organization.
   One collector exports to one organization, so two products sharing a server share
   that server's organization too (tell them apart by `service_name`).
5. Copy the alert rules from step 6 into the new organization.
6. Wire the code: [CONNECT.md](./CONNECT.md).
