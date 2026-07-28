# Full Audit Report — 2026-06-21 13:06

**Тип:** Полный аудит (18 направлений × 2 проекта)
**Стек:** Go (backend) + Node/TypeScript (frontend)
**Сессия:** `docs/audits/2026-06-21_13-06/`

---

## Компонент: Backend (Аутентификация / API / GraphQL)

| Check ID | Проверка | Статус | Доказательство | Решение |
|----------|----------|--------|----------------|---------|
| OWA-09 | WebSocket CheckOrigin | ❌ FAIL 🟠 | `internal/graph/handler.go:39` | Ограничить origin: `CheckOrigin: func(r *http.Request) bool { return r.Header.Get("Origin") == "https://domain.com" }` |
| OWA-03 | File upload без проверки владельца (IDOR) | ❌ FAIL 🟠 | `internal/upload/handler.go:101-117` | Добавить `file.UserID != ctx.UserID { return ErrForbidden }` |
| Matrix-A1 | WebSocket без origin (дубль OWA-09) | ❌ FAIL 🟠 | `internal/graph/handler.go:39` | См. OWA-09 |
| Matrix-DB | Пул соединений 10 — узкое место | ❌ FAIL 🟠 | `internal/db/pool.go:29` | Увеличить poolMax до 25-50 или сделать configurable через env |
| VAL-02 | Нет maxLength на строковых GraphQL полях | ❌ FAIL 🟡🟢 | `internal/graph/schema.graphqls` | Добавить `@maxLength` для строковых полей мутаций |
| DOC-02 | Не все env в .env.example | ❌ FAIL 🟡🟢 | `internal/config/config.go` | Синхронизировать .env.example с config.go |
| DEP-12 | Не проверена read-only root FS | ❌ FAIL 🟡🟢 | `Dockerfile` | Добавить `securityContext.readOnlyRootFilesystem` |
| Matrix-UP | Upload без проверки ownership | ❌ FAIL 🟡🟢 | `internal/upload/handler.go:101-117` | Добавить проверку владельца |

## Компонент: Frontend (Auth / SSR / API / Docker)

| Check ID | Проверка | Статус | Доказательство | Решение |
|----------|----------|--------|----------------|---------|
| MATRIX-006 | OIDC localStorage без fallback | ❌ FAIL 🟠 | `src/features/auth/api/oidc-client.ts:30` | Добавить try/catch с fallback на in-memory store |
| BUG-010 | Type assertion bypass | ❌ FAIL 🟡🟢 | `src/features/auth/lib/stub-auth-value.ts:47` | Создать корректный объект вместо `as unknown as` |
| ERR-005 / LOG-005 | SSR error не в Sentry | ❌ FAIL 🟡🟢 | `src/server.ts:33` | Заменить console.error на `Sentry.captureException(err)` |
| DEPL-007 | npm install вместо npm ci | ❌ FAIL 🟡🟢 | `Dockerfile:14` | Использовать `npm ci`, разобраться с peer deps |
| PERF-012 | React compiler без явной проверки | ❌ FAIL 🟡🟢 | `vite.config.ts:105-107` | Убедиться в стабильности плагина для production |

---

## Сводка

| Компонент | ❌ FAIL 🟠 | ❌ FAIL 🟡🟢 | Итого FAIL |
|-----------|-----------|------------|------------|
| **Backend** | 4 | 4 | **8** |
| **Frontend** | 1 | 4 | **5** |
| **ИТОГО** | **5** | **8** | **13** |

---

## Разбор FAIL 🟠

### 🟠 [OWA-09 + Matrix-A1] — WebSocket без origin
**Файл:** `backend/internal/graph/handler.go:39`
`CheckOrigin: func(_ *http.Request) bool { return true }`
**Решение:** Разрешить только доверенный домен. Защита от Cross-Site WebSocket Hijacking.

### 🟠 [OWA-03 + Matrix-UP] — File upload без проверки владельца
**Файл:** `backend/internal/upload/handler.go:101-117`
`http.ServeFile(w, r, fullPath)` без `file.UserID == ctx.UserID`
**Решение:** Добавить проверку `if file.UserID != ctx.UserID { return ErrForbidden }`

### 🟠 [Matrix-DB] — Пул соединений БД
**Файл:** `backend/internal/db/pool.go:29`
`config.DBPoolMax = 10` (constants.go:61)
**Решение:** Увеличить до 25-50 или вынести в env.

### 🟠 [MATRIX-006] — OIDC localStorage
**Файл:** `frontend/src/features/auth/api/oidc-client.ts:30`
`WebStorageStateStore({ store: window.localStorage })` — упадёт в incognito/Safari
**Решение:** try/catch с fallback на in-memory store.

---

## Топ-3 что исправить в первую очередь
1. **🟠** `backend/internal/graph/handler.go:39` — ограничить WebSocket origin
2. **🟠** `frontend/src/features/auth/api/oidc-client.ts:30` — fallback для localStorage
3. **🟠** `backend/internal/upload/handler.go:101-117` — проверка владельца файла

## Файлы сессии
```
docs/audits/2026-06-21_13-06/
├── backend/
│   ├── audit-owasp.md       (2 FAIL 🟠)
│   ├── audit-validation.md  (1 FAIL 🟡🟢)
│   ├── audit-docs.md        (1 FAIL 🟡🟢)
│   ├── audit-deployment.md  (1 FAIL 🟡🟢)
│   └── audit-matrix.md      (2 🟠 + 1 🟡🟢)
├── frontend/
│   ├── audit-bugs.md        (1 FAIL 🟡🟢)
│   ├── audit-errors.md      (1 FAIL 🟡🟢)
│   ├── audit-logging.md     (1 FAIL 🟡🟢)
│   ├── audit-performance.md (1 FAIL 🟡🟢)
│   ├── audit-deployment.md  (1 FAIL 🟡🟢)
│   └── audit-matrix.md      (1 FAIL 🟠)
├── audit-verify.md
└── audit-report.md
```
