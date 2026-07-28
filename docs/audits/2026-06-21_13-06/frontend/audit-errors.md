# Audit: errors
## Контекст: runtime=node
## Coverage: ERR-01–09 — ignored errors, stacktrace, async handlers, unhandled rejections, timeouts, graceful shutdown, retry
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 ERR-005 — SSR ошибка не логируется в Sentry
**Файл:** `src/server.ts:33`
**Проблема:** При ошибке SSR выводится `console.error`, но ошибка не отправляется в Sentry/production-мониторинг: `console.error('SSR error:', err)` — production мониторинг теряет критическую точку отказа.
**Рекомендация:** Добавить `*Sentry.captureException(err)` или подключить интеграцию с выбранным APM.
