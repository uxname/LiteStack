# ADR 0008: dev pages may fetch from our own origin and jsdelivr, nothing else

- **Date:** 2026-09-20
- **Status:** accepted

## Context

The backend's dev pages (`/dev`, `/playground`, `/docs`, `/openapi.yaml`) run under a
relaxed CSP so they can load CDN assets. `connect-src` there used to be `'self' https:`,
which allows a fetch to any host on the internet.

The API reference on `/docs` is Scalar (`@scalar/api-reference`, pinned). On load — before
anyone clicks anything — the bundle calls its own registry at `api.scalar.com`
(`/vector/registry/curated` and `/vector/registry/search`). Version 1.69.2 exposes no
option to switch that off: `proxyUrl: ''` only stops `proxy.scalar.com`, and
`withDefaultFonts: false` only stops `fonts.scalar.com`. The call is inside the bundle.

These pages sit behind basic auth on a developer's machine, so the leak is small — the fact
that someone opened the page, and an empty search query. It is still an outbound call
nobody asked for, made by third-party code, from a page that is supposed to be internal.

## Decision

`devCSP` sets `connect-src 'self' https://cdn.jsdelivr.net`. Dev pages may fetch from our
own origin and from the CDN that serves their bundles; everything else is blocked by the
browser. `TestDevCSP_ConnectSrcIsNotOpenToEveryHTTPSHost` fails if the blanket `https:`
comes back.

## Alternatives

- **Leave `'self' https:`** — every opened reference page keeps telling a third party it was
  opened. Rejected: the cost of blocking is near zero.
- **Configure Scalar not to call its registry** — no such option in the pinned version, and
  an option added later would still be the bundle's promise, not ours.
- **Drop Scalar** — the API reference itself was asked for; the registry call is not part of it.

## Consequences

- The browser console on `/docs` shows two CSP violations for `api.scalar.com` on every
  load. **This is the policy working, not a bug.** Do not "fix" the console by widening
  `connect-src`.
- Scalar's "Ask AI" button talks to the same host and will not work. Its local search does.
- The GraphQL playground is unaffected: it fetches `/graphql` on our own origin.
- A dev page that genuinely needs another host must have that host named in `devCSP`, which
  is a visible, reviewable change rather than a silent one.
- The bundle itself is pinned twice: by exact version, and by an SRI hash on the script tag
  (`scalarSRI` in `internal/devtools/devtools.go`). Bumping the version without recomputing
  the hash gives a blank page; the test message says how to recompute it. `connect-src`
  governs where the page may talk, SRI governs what it may run — neither replaces the other.
