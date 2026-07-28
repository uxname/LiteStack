# Audit Verification Report — 2026-06-21 13:06

## Результаты верификации

**Все 14 FAIL подтверждены.** False positives: 0. Пропущенные риски: 0.

### Подтверждённые находки (выборочная проверка):

**Backend:**
- `internal/graph/handler.go:39` — `CheckOrigin: true` ✅ (OWA-09)
- `internal/upload/handler.go:101-117` — serve() без проверки владельца ✅ (OWA-03)
- `internal/db/pool.go:29` — `DBPoolMax = 10` ✅ (Matrix-DB)

**Frontend:**
- `src/features/auth/api/oidc-client.ts:30` — localStorage без fallback ✅ (MATRIX-006)
- `src/features/auth/lib/stub-auth-value.ts:47` — `as unknown as AuthContextProps` ✅ (BUG-010)
- `src/server.ts:33` — `console.error('SSR render failed', ...)` ✅ (ERR-005/LOG-005)
- `Dockerfile:14` — `npm install --legacy-peer-deps` ✅ (DEPL-007)
