# Audit — 2026-07-28

Eight dimensions run in parallel by subagents over `backend/`, `frontend/` and the
meta-repo, immediately after the dependency refresh of the same day: **bugs,
architecture, YAGNI, reinvention, performance, tests, docs, errors**.

Per-dimension working notes are not kept — this file is the record. Everything
below was verified against the code (path:line), not inferred. Items marked
**FIXED** landed in this session; the rest are open and prioritised.

Gates at the time of writing, all green: backend `task check` + `task test:cov`
(43.7% total, per-package floors), frontend `npm run verify:push` (252 unit,
13 E2E, Ladle build, gitleaks).

---

## Fixed in this session

Commits: `backend 2d85291, 4ce02c2` · `frontend d502c60, d165671` · meta (this one).

### Data loss — backups were silently unrestorable

| Where | Problem |
|---|---|
| `backend/internal/backup/backup.go` Restore | `psql` ran without `ON_ERROR_STOP=1`: a restore whose statements all failed still returned `nil` and logged `restore completed` over a half-restored database. |
| same, `runDump`/`ext` | `BACKUP_FORMAT=custom` dumped binary (`-F c`) into a `.sql` name while Restore only piped into `psql`; `pg_restore` existed nowhere but the package comment. Custom dumps now get `.dump`, skip the redundant external gzip (the format self-compresses) and restore through `pg_restore --exit-on-error`. |
| `backend/internal/config/config.go` LoadBackup | `BACKUP_ROTATION` was unvalidated: `0` deleted the dump created seconds earlier, a negative value sliced out of range and killed the backup goroutine. Now rejected at startup, together with any `BACKUP_FORMAT` Restore cannot read. |

### Gates that were configured but not running

- `backend/.golangci.yml` — `depguard` and `nolintlint` had settings blocks but were
  absent from `linters.enable`, so the layering guard and the "`//nolint` needs a
  reason" rule that `backend/AGENTS.md` promises did not exist. Enabling them
  surfaced exactly one stale suppression (`internal/logger/context.go`), removed:
  sloglint's no-global rule never covered that line.
- `frontend/playwright.config.ts` — `forbidOnly: !!process.env.CI` is permanently
  false with no CI, so one leftover `test.only` would shrink the whole E2E gate to
  a single test while `verify:push` still reported success. Now always on.

### Correctness

- `frontend/src/routes/account.tsx` — put an absolute `window.location.href` into
  the OIDC `returnTo` state, which `AppProviders` feeds to `history.replace()`.
  TanStack's `parseHref` treats the whole URL as the pathname, so signing in from
  a direct link to `/account` landed on a **404 with a correct address bar**.
  `HeaderControls` already did it right (`pathname + search`).
- Same effect awaited `signinRedirect` with no `catch`: an unreachable IdP left the
  user on `PageLoader` forever (Sentry saw it, the user did not).
- `frontend/src/shared/ui/ErrorFallback/ErrorFallback.tsx` + `app/bootstrap/GlobalErrorBoundary.tsx`
  — read `window.location` while rendering the fallback, inside the isomorphic tree
  (`defaultSsr: true`). The boundary threw `window is not defined` **from its own
  fallback**, turning a handled error into a bare `text/plain` 500.
- `backend/internal/profile/pubsub.go` — the `pump` goroutine had no `recover`,
  unlike the other three background goroutines: one bad event took the process
  down for every user.
- `backend/internal/middleware/ratelimit.go` — `Retry-After` was written as a Go
  duration (`"1m39s"`), unparseable per RFC 9110, so clients retried immediately.
  It also bypassed `httperr` (the only REST error in the app that did) and dropped
  the Redis error entirely, making "rate limiting is off" indistinguishable from
  "nobody hit a limit".

### Fallout of the same-day CORS_ORIGIN/WebSocket migration

gqlgen 0.17.94 dropped its gorilla adapter; the transport moved to
`coder/websocket` and, instead of reinstating the old allow-any-origin
`CheckOrigin`, now authorises handshakes against `CORS_ORIGIN`.

- `backend/internal/config/config.go` — `env` splits on `,` without trimming, so
  `CORS_ORIGIN=a, b` yielded `" b"`, matching nothing. Harmless for CORS before;
  now it silently kills subscriptions from that origin. Trimmed, empties dropped.
- `backend/test/integration_test.go` — the only WS test dialled without an `Origin`
  header, so the new authorisation was untested. Pinned: allowed origin connects,
  foreign origin gets 403, absent Origin (non-browser) still connects.

### Drift between frontend and backend

- `frontend/src/features/profile/model/schema.ts` — form limits had drifted to
  80/500 against the backend's 100/1000 (`ProfileDisplayNameMaxLen`,
  `ProfileBioMaxLen`), while the docstring claimed to mirror "backend zod rules" —
  the backend is Go. Aligned, comment corrected, and the numbers restated in the
  two duplicated test files and the `en`/`ru` `validation_*` messages updated too.

### Coverage the gates should have been holding

- `backend/internal/auth` was **below its own 60% floor before this session**:
  commit `ce9f0b8` added shared bearer parsing without tests. Covered
  (`RequireAuth` 401 + user hand-off, mock-identity failure,
  `isProviderUnavailable`'s 503-vs-401 decision) rather than lowering the floor.
- `backend/internal/graph/resolver` gained input-validation tests (lengths, rune
  vs byte counting at the exact limit, non-`http(s)` avatar URLs); floor ratcheted
  90 → 94.
- `backend/internal/backup` 0% → 23%: `ext`/`rotate` boundaries, and that rotation
  never prunes across formats.
- `frontend/.ncurc.yml` added: `npm run update` (`npx ncu -u`) silently reverted
  the deliberate typescript-6 / graphql-16 / ncu-22 holds. Each hold now records
  its third-party cause and unblock condition.

### Meta scripts — every derived project was affected

- `scripts/rename-project.sh` listed `frontend/src/routes/protected/*`, which no
  longer exist (routes were flattened), and line 93 hid that as `skip (missing)`.
  Meanwhile `routes/account.tsx` (`"Profile | LiteFront"`),
  `widgets/Header/ui/index.test.tsx` and `pages/home/lib/copyInstallCommand.{ts,test.ts}`
  carried the brand and were **not** in any list — so a derived project shipped the
  template's brand *and* two failing tests. Lists rebuilt from actual occurrences.
- Same script renamed the theme key `litefront-theme` only in
  `features/theme/model/store.ts`, not in the pre-paint script in
  `routes/__root.tsx` — so after a rename the store wrote `<name>-theme` while the
  script read `litefront-theme`, restoring the exact FOUC that script prevents.
- `scripts/doctor.sh` — `getval`'s `grep` failure propagated through `pipefail`
  into `VAR="$(getval …)"` and `set -e` killed the checker mid-run: a missing key
  produced **no diagnostic at all**, the opposite of an env doctor's purpose.
  Reproduced in isolation, then fixed.

---

## Open — P1

1. **No layer of this system tests real authentication.** Backend
   `internal/auth/verifier.go` `Verify` (signature, issuer, audience, expiry) is at
   **0%**: every unit test builds `NewMiddleware(nil, …)` with `mockEnabled=true`,
   and `test/integration_test.go` sets `OIDC_MOCK_ENABLED=true`. On the frontend
   `tests/setup.ts` globally mocks `react-oidc-context`, `vitest.config.ts` excludes
   the real `oidc-client.ts` from coverage, and Playwright runs with
   `VITE_MOCK_AUTH=true`. Root cause on the backend: `Middleware.verifier` is the
   concrete `*Verifier` while the same file already defines a consumer-side
   `Profiles` interface for exactly this purpose. Fix: extract a `TokenVerifier`
   interface, then test issuer/audience/expiry rejection with a local JWKS.
2. **`redactSensitive` is at 0%** (`backend/internal/logger/logger.go`). The function
   that strips secrets from logs is untested and `internal/logger` has no coverage
   floor — broken redaction puts credentials in plaintext logs with nothing turning
   red.
3. **`/health` calls `runtime.ReadMemStats`, which stops the world**
   (`backend/internal/health/health.go`, and again in the `debug` resolver), on a
   **public** endpoint that Docker's HEALTHCHECK hits every 5s. Serve process
   metrics from a periodic sample, or drop them from the public payload.
4. **A non-production environment accepts any WebSocket origin.** With an empty
   `CORS_ORIGIN` the handshake falls back to `InsecureSkipVerify`, and the fail-fast
   that forbids an empty list triggers only on the exact string `production` — so a
   staging deployment silently accepts every origin. Either require the allowlist
   outside development too, or drop the permissive fallback and make dev set the
   value explicitly.
   *(The documentation half of this — `NODE_ENV` being documented nowhere despite
   gating all three production hardenings — was fixed later in the same session; see
   "Fixed" above.)*
5. **Sentry Session Replay ships to everyone**: ~122 KB gzip pulled into the root
   route's preload (`frontend/src/shared/lib/sentry/config.ts` +
   `client.tsx`) while `replaysSessionSampleRate` is 0.1 — wasted for 90% of
   sessions, on a first load of ~272 KB gzip JS. Load the replay integration lazily.

## Open — P2

6. **The production image ignores the lockfile.** `frontend/Dockerfile:14` runs
   `npm install --legacy-peer-deps`, not `npm ci`, so the image may resolve a
   dependency tree that is not in `package-lock.json` and that no gate ever ran.
   `--legacy-peer-deps` additionally silences exactly the peer conflicts that keep
   `graphql` pinned at 16 — so the container can be built on the combination the
   local suite refuses. Switch to `npm ci` (with `--legacy-peer-deps` only if a real
   conflict demands it) and verify with `docker compose build`.
7. **SSR failures never reach Sentry.** `frontend/src/server.ts:33` logs the caught
   render error with `console.error` and returns a bare 500. `initSentry()` runs
   client-side only (`client.tsx`), so the one class of error that takes the whole
   page down is the one class that is invisible in production. There is also no
   `process.on('unhandledRejection')` on the server. Report it from the server
   handler (`@sentry/node`, or forward it into the client DSN).
8. **URQL client is rebuilt on every silent token renew.**
   `frontend/src/app/bootstrap/AppProviders.tsx` memoises on `auth.user?.access_token`,
   so each renew drops the whole graphcache, re-issues every query and tears down
   WS subscriptions. Keep one client and read the token per request.
9. **Layer rules permit what the docs forbid.** `backend/.go-arch-lint.yml` grants
   `transport → infrastructure`, so a resolver can run SQL straight past the domain
   (`depguard`'s `files` do not cover `internal/graph/**`), and `domain →
   infrastructure` is allowed and genuinely used. `sqlc.Profile` serves as the
   domain model and has leaked into the transport interface
   (`resolver.ProfileService`), which is why the rule cannot simply be tightened:
   it needs a real domain model plus mapping. `backend/AGENTS.md`'s "dependencies
   point inward" currently describes the opposite.
10. **`tsc --noEmit` ignores project references**, so `vite.config.ts`,
   `vitest.config.ts` and both Vite plugins — one of them the env-var startup
   validator — are typechecked by nothing, and `tsconfig.node.json` has no `strict`.
11. **`npm run check` runs `lint:fix` (write mode)**, so violations are mutated
   instead of failing, and lefthook never re-stages — committed code can differ
   from checked code.
12. **Upload timeout leaks.** `backend/internal/upload/service.go` `writeFile`
    returns on timeout while its `io.Copy` goroutine keeps writing to the
    already-removed file: goroutine, descriptor and up to 5 MiB of invisible disk
    per occurrence.
13. **`setup.sh` never creates `.env`** while `doctor.sh` silently falls back to
    `.env.example`, so the documented first run reports OK for a configuration the
    app does not read — and `frontend/src/app/vite-dotenv-checker.plugin.ts`
    `readFileSync`s `.env` unguarded, so that path fails with ENOENT.
14. **`gen:check` conflates two states.** It regenerates and then diffs the working
    tree, so a legitimate regeneration reads as "stale" until staged — which is why
    `task update` cannot succeed across a gqlgen bump without an intermediate
    `git add`. Diff against a temp dir instead.
15. **Coverage floors carry slack**, and the two metrics disagree — mind which one you
    quote. By **statements**, which is what the gate enforces: `internal/auth` 72.6%
    vs a floor of 60, `upload` 69.5/60, `profile` 67.3/60. By mean-per-function
    (`go tool cover -func`) the same packages read 89.1 / 76.5 / 77.8, so a floor
    argued from that number looks about twice as slack as it is. Separately,
    `middleware`, `server`, `logger` and `backup` have no floor at all, and `backup`'s
    `Restore`/`rotate` remain unvalidated against a live database.

## Open — P3

- Third copy of "get client IP" (`internal/upload/handler.go`, `middleware/ratelimit.go`,
  `middleware/realip.go`) re-parsing what `RealIP` already normalised.
  *(`realip.go` itself is deliberate — chi's is deprecated for IP spoofing, `f0d9b24`.)*
- `internal/backup/backup.go` shells out to `gzip`/`gunzip` with hand-wired pipes
  where `compress/gzip` would do; also orphans a `gzip` process per failed dump.
- `internal/upload/service.go` hand-rolls path containment with `filepath.Abs` +
  `strings.HasPrefix` (misses symlinks); Go 1.24+ has `os.OpenRoot`.
- Small stdlib wins: `slices.Contains` for role membership (`internal/auth/context.go`),
  `slices.SortFunc` for `sort.Slice`, `t.Format` for an 8-line `fmt.Sprintf` date path,
  `Object.hasOwn` in `vite-dotenv-checker.plugin.ts`.
- Dead or fictional code: `frontend/src/features/auth/model/types.ts` (describes a
  Zustand auth store that does not exist), 26 lines of PWA config behind a hardcoded
  `disable: true`, `PORT` validated from `import.meta.env.PORT` which Vite never
  populates, 7 manual `useMemo`/`useCallback` under an enabled React Compiler.
- `knip` and `steiger` report clean partly by configuration: `knip.json` ignores
  `shared/config/**` and `shared/lib/sentry/**` — where several of the findings above
  live — and `steiger.config.js` disables `fsd/insignificant-slice`.
- Six duplicated test pairs (`src/**` vs `tests/unit|component/**`) at differing
  strictness; `tests/setup.ts`'s `vi.stubGlobal("import.meta", …)` is inert so tests
  read the developer's real `.env`; `account-center.test.ts` computes its expectation
  from the same env var as the code; `agent-logs.spec.ts` wraps interactions in
  `.catch(() => {})` so it cannot fail when the controls it tests disappear.
- `frontend/todo.md`: 5 undated items, idle ~6 months, item 1 ("Sentry") already done.
- Documentation drift is tracked separately — it is being addressed in the same
  session's `AGENTS.md` restructuring.

---

## One finding was retracted

An initial claim that **steiger does not resolve `tsconfig` aliases** — and that
`lint:fsd` was therefore inert — was **wrong**. A probe placed in the real project
(`shared/lib` importing `@pages/home`) is caught as
`Forbidden import from higher layer "pages"`. The original experiment ran on a copy
of `src/` in a scratch directory with **no `tsconfig.json` beside it**, where the
alias is an unresolvable external package the rule rightly ignores. The silence was
a property of the sandbox, not the linter.

**Rule for future audits:** a linter that depends on project configuration
(steiger, biome, tsc, knip) must be probed inside the real project and cleaned up
afterwards — never on a detached copy of the tree. This is the second time an audit
here produced confidently wrong specifics (see `docs/retro/2026-06-20-audit-tests-tdd-gates.md`).

## Verified as sound

Worth recording so the next audit does not re-litigate them: N+1 is impossible in
this GraphQL schema (no list or nested object fields, so no dataloader is needed and
missing pagination is not a gap); WebSocket connections are not severed by the
server's read/write timeouts (`net/http` clears deadlines on hijack); there are no
SSR hydration mismatches (pre-paint theme script, cookie-first locale, logged-out
first paint); graceful shutdown uses `context.WithoutCancel` correctly; production
error masking, chi/asynq panic recovery, timeouts on every request-path dependency,
migrate's full-jitter backoff, URQL `retryExchange` and per-request
`AbortSignal.timeout` all hold; all three shell scripts use `set -euo pipefail` and
every `setup.sh` step is idempotent; no skipped or focused tests exist in either
project.
