# Audit Report: Logging Best Practices — 2026-06-20 21:43

**Проект:** frontend (LiteStack)
**Runtime:** браузер (React 19 / TanStack Start) + SSR
**Куда уходят логи:** Sentry (`@sentry/react`), `console.*` только в dev-режиме

> Невыполненной работы по исправлениям нет. Осталась одна проверка, которую нельзя подтвердить статически.

## Требует ручной проверки

| Check ID | Проверка | Доказательство |
|----------|----------|----------------|
| LOG-04 | Запросы трассируются (Request ID или correlation ID сквозной) | Включён `Sentry.browserTracingIntegration()` (`config.ts:18`) — даёт trace-id внутри Sentry. Но сквозного correlation-ID между фронтом и бэкендом (например, заголовок `X-Request-Id` в `fetchOptions.headers`, `graphql-client.ts:45-48`) не добавляется. Подтвердить отсутствие пробрасывания ID в бэкенд по коду фронта нельзя без анализа всей цепочки — нет ни одного места, где такой заголовок ставится. **Остаток:** при необходимости сквозной трассировки фронт→бэк добавить проброс correlation-ID в `fetchOptions.headers`. |
