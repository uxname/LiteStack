# Audit: logging
## Контекст: runtime=node
## Coverage: LOG-01–08 — console.*, PII, secrets, request ID, structured logs, critical ops, log injection
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 LOG-005 — console.error в production-пути вместо Sentry
**Файл:** `src/server.ts:33`
**Проблема:** `console.error('SSR error:', err)` — в production ошибка SSR попадает только в stdout, не в APM/Sentry. Дублирует ERR-005.
**Рекомендация:** Заменить на `Sentry.captureException(err)` или другой production-логгер.
