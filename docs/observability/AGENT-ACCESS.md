# Reading the stack — for agents and people

Everything below works the same for an AI agent and for a person at a terminal: plain
HTTP APIs and one CLI. MCP servers are an optional convenience at the end.

## Credentials

Keep every token in your shell environment, a password manager or the agent's secret
store — **never in a repository**. One credential per consumer, so one can be revoked
without touching the others.

| Tool | Credential | Where to create it | Read-only? |
|---|---|---|---|
| OpenObserve | Service account (email + token) | IAM → Service Accounts | **No** — read-only roles are Enterprise-only. Give agents their own account and rotate it |
| GlitchTip | Auth token, scopes `event:read` + `project:read` | Profile → Auth Tokens | Yes |
| Rybbit | API key | Settings → Account → API Keys | No — a key acts as its user for the whole organization |
| Dokploy | API key | Settings → Profile → API/CLI | No |

```bash
export O2_URL=https://o2.example.com O2_ORG=default O2_USER=agent@example.com O2_TOKEN=…
export GT_URL=https://glitchtip.example.com GT_ORG=<org-slug> GT_TOKEN=…
export RY_URL=https://rybbit.example.com RY_SITE=1 RY_KEY=…
export DOKPLOY_URL=https://dokploy.example.com DOKPLOY_KEY=…
```

## OpenObserve — SQL over logs, metrics, traces

One endpoint; `type` is `logs`, `metrics` or `traces`; times are **microseconds**.

```bash
o2() {  # usage: o2 "<sql>" [minutes back, default 60] [logs|metrics|traces, default logs]
  local now; now=$(date +%s%6N)
  curl -su "$O2_USER:$O2_TOKEN" -H 'Content-Type: application/json' \
    "$O2_URL/api/$O2_ORG/_search?type=${3:-logs}" \
    -d "$(jq -n --arg sql "$1" --argjson s $((now - ${2:-60}*60000000)) --argjson e "$now" \
      '{query:{sql:$sql,start_time:$s,end_time:$e,from:0,size:100}}')"
}
o2 "SELECT _timestamp, service_name, msg, request_id FROM docker WHERE level='ERROR' ORDER BY _timestamp DESC"
```

Log fields are the apps' own (`level`, `msg`, `request_id`, `status`, `path`,
`duration_ms`, `user_id` — the database id — and, once CONNECT.md § 3 is done,
`oidc_sub`, the id GlitchTip and Rybbit use) plus `service_name` and `host_name`; dots in names become
underscores. The backend's event slugs are listed in `backend/docs/DEBUGGING.md`.

## GlitchTip — issues

```bash
gt() { curl -s -H "Authorization: Bearer $GT_TOKEN" "$GT_URL/api/0/$1"; }
gt "projects/$GT_ORG/<project>/issues/?query=is:unresolved"        # newest first
gt "issues/<issue_id>/events/latest/"                              # stack, tags, request_id
```

The query takes `is:unresolved`, `level:error`, `release:1.4.0`, `environment:production`,
free text. The CLI does the same and more: `curl -fsSL https://glitchtip.com/install.sh | sh`,
then `glitchtip-cli --url "$GT_URL" login` and `glitchtip-cli issues list`.
API reference: `<GT_URL>/api/docs`.

## Rybbit — product numbers (API in beta)

```bash
ry() { curl -s -H "Authorization: Bearer $RY_KEY" "$RY_URL/api/sites/$RY_SITE/$1"; }
ry "overview?start_date=2026-10-01&end_date=2026-10-07&time_zone=UTC"
ry "metric?parameter=pathname&start_date=2026-10-01&end_date=2026-10-07"   # top pages
ry "retention"
ry "events"
curl -s -X POST -H "Authorization: Bearer $RY_KEY" -H 'Content-Type: application/json' \
  "$RY_URL/api/sites/$RY_SITE/funnels/analyze" -d '{ …steps… }'
```

Event names come from the product's `docs/EVENTS.md` ([CONNECT.md § 6](./CONNECT.md#6-the-events-list--docseventsmd-in-the-derived-project)).
The beta API may change between versions: check the API Playground in Rybbit's sidebar
when a path stops answering.

## Dokploy — deploys and the host

```bash
curl -s -H "x-api-key: $DOKPLOY_KEY" "$DOKPLOY_URL/api/project.all"
```

Paths are `/api/<router>.<action>`; the full list is in Dokploy's Swagger UI
(`/swagger`, admins only).

## Triage scenarios

### What broke after release X

1. GlitchTip: `gt "projects/$GT_ORG/<project>/issues/?query=is:unresolved%20release:<X>"` — the new issues.
2. Latest event of each → its `request_id`.
3. OpenObserve: `WHERE request_id = '<id>'` — everything the backend logged for that
   request, across services.

### Why it is slow

1. OpenObserve: `SELECT path, approx_percentile_cont(duration_ms, 0.95) AS p95, count(*) FROM docker WHERE msg='http_request' GROUP BY path ORDER BY p95 DESC`.
2. `msg = 'db_query_slow'` in the same window; with step 4 of CONNECT.md, open the trace.

### Where users drop out

1. Rybbit: analyze the funnel built from `docs/EVENTS.md` events.
2. For the worst step, session replays of users who stopped there; GlitchTip errors with
   the same user (OIDC `sub`) in the same window.

### Is the system healthy right now

1. OpenObserve: `level='ERROR'` in the last 15 minutes, grouped by `service_name, msg`.
2. Metrics (`o2 "…" 15 metrics`): `system_memory_utilization`, `system_filesystem_utilization`, `container_*`.
3. Dokploy: last deployment status per application.

A finding goes into the issue tracker with its evidence — the query, the ids, the
time window — so a person can repeat it.

## Optional: MCP servers

Same data, exposed as tools to an MCP-capable agent. Free where listed; nothing above
depends on them.

| Tool | Endpoint | Auth | Note |
|---|---|---|---|
| GlitchTip | `<GT_URL>/mcp` | OAuth, or `Authorization: Bearer <token>` | Needs `GLITCHTIP_ENABLE_MCP=True` ([STACK.md § 3](./STACK.md#3-glitchtip--errors)) |
| Rybbit | `<RY_URL>/api/mcp` | OAuth, or `Authorization: Bearer <key>` | Rybbit 2.8.0 or newer |
| Dokploy | the Dokploy MCP server | API key | |
| OpenObserve | — | — | Enterprise-only; use the SQL API above |

```bash
claude mcp add --transport http glitchtip "$GT_URL/mcp"
claude mcp add --transport http rybbit "$RY_URL/api/mcp" --header "Authorization: Bearer $RY_KEY"
```
