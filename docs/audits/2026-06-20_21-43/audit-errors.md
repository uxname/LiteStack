# Audit Report: Error Handling & Resiliency — 2026-06-20 21:43

**Runtime:** Node.js / TypeScript. Гибридное приложение: клиент в браузере (React 19) + SSR-сервер на TanStack Start (Nitro node-server, запуск `node .output/server/index.mjs`). Пользовательская SSR-точка входа — `src/server.ts`.

**Baseline:** пустой (`docs/audit-baseline.yml` без принятых записей).

**Особенность оценки:** проверки process-level (ERR-04) и graceful shutdown (ERR-06) применяются к SSR-серверу. Сам HTTP-сервер генерируется Nitro (в `.output/`, не в исходниках), поэтому app-код не управляет жизненным циклом процесса напрямую — это учтено в статусах.

## Результаты

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| ERR-01 | Ошибки не проглатываются — catch-блоки обрабатывают или пробрасывают | ✅ PASS | High | Все catch-блоки восстанавливают или сообщают об ошибке: `useProfileForm.ts:55` показывает toast; `ErrorFallback.tsx:77` логирует в dev; `normalizeError.ts:6` возвращает fallback-Error; `LocaleSwitcher.tsx:19` отдаёт fallback-имя; `__root.tsx:39` — бутстрап темы (FOUC) с осознанным no-op. GraphQL-ошибки не теряются: `graphql-client.ts:18` ловит и шлёт в Sentry, бизнес-ошибки доступны через `result.error` (`useProfileForm.ts:77`). | — | — |
| ERR-02 | Внутренние детали не попадают в ответы | ✅ PASS | High | Stack trace показывается только в dev: `ErrorFallback.tsx:166` (`env.DEV &&`). Sentry чистит query-string из путей фреймов перед отправкой: `sentry/config.ts:35`. В prod пользователю видны только нормализованные `name`/`message`. | — | — |
| ERR-03 | Async handlers корректно пробрасывают исключения | ❌ FAIL 🟡 | Medium | `src/server.ts:23` — `const response = await handler(localizedRequest, ...)` внутри `paraglideMiddleware` без `try/catch`. Если SSR-рендер реджектится, ошибка уходит наверх в Nitro без app-уровневого перехвата/фолбэка; вдобавок `Set-Cookie` с локалью (`server.ts:35`) не будет выставлен на ошибочном ответе. Риск: непредсказуемый ответ при сбое рендера и потеря per-request обработки. | **1. Обернуть `await handler(...)` в `try/catch`: при ошибке логировать через Sentry и вернуть аккуратный 500-ответ (с сохранением логики `Set-Cookie`)** \\ 2. Положиться на встроенную обработку ошибок TanStack Start/Nitro и задокументировать это решение в комментарии у `server.ts:23` \\ 3. Вынести вызов `handler` в отдельную функцию с единым error-mapping и переиспользовать её | Нет |
| ERR-04 | Unhandled rejections и uncaught exceptions имеют process-level обработчики | 🔍 UNVERIFIED | Medium | Клиент: оконные обработчики есть — `GlobalErrorBoundary.tsx:16-17` слушает `unhandledrejection` и `error`, шлёт в Sentry. Сервер: в app-коде (`src/server.ts`, `src/router.tsx`, `src/client.tsx`) нет `process.on('unhandledRejection'/'uncaughtException')` (grep по `src/**` — 0 совпадений). HTTP-сервер генерируется Nitro в `.output/server/index.mjs` (вне исходников), его process-level поведение статически из репозитория не подтверждается. | — | — |
| ERR-05 | Внешние вызовы (HTTP-клиенты, DB) имеют явные таймауты | ❌ FAIL 🟠 | High | `features/profile/api/upload-avatar.ts:23` — `await fetch(\`${origin}/upload\`, { method: "POST", headers, body })` без таймаута и без AbortSignal. При зависшем/медленном backend запрос (загрузка файла, потенциально крупного) висит бесконечно: `uploading`-состояние (`useProfileForm.ts:51`) не сбрасывается, кнопка остаётся заблокированной. Несогласованность с GraphQL-клиентом, где таймаут задан: `graphql-client.ts:47` (`signal: AbortSignal.timeout(15000)`). | **1. Добавить таймаут через `AbortSignal.timeout(...)` в `fetch` (как в `graphql-client.ts:47`), напр. `signal: AbortSignal.timeout(30000)`** \\ 2. Использовать `AbortController` + `setTimeout`, чтобы дополнительно дать возможность отмены при размонтировании формы \\ 3. Завести единый обёртку-`fetch` с дефолтным таймаутом для всех REST-вызовов и использовать её здесь | Нет |
| ERR-06 | Graceful shutdown реализован — SIGTERM обрабатывается | 🔍 UNVERIFIED | Medium | В app-коде нет `process.on('SIGTERM'/'SIGINT')` (grep по `src/**` — 0 совпадений). Прод-сервер — сгенерированный Nitro-бандл (`Dockerfile` CMD `node .output/server/index.mjs`), его shutdown-логика лежит вне исходников и статически из репозитория не подтверждается. SSR-сервер stateless (нет своего DB-пула/долгих коннектов в app-коде), поэтому graceful drain менее критичен, но не верифицирован. | — | — |
| ERR-07 | Error responses консистентны по структуре | ✅ PASS | Medium | Приложение не отдаёт собственный API: GraphQL-ошибки обрабатываются единообразно через `errorExchange` (`graphql-client.ts:18`) и `result.error`; пользователю показывается единый компонент `ErrorFallback` (boundary в `__root.tsx:72` и `GlobalErrorBoundary.tsx:25`) и единый toast (`useProfileForm.ts:56,78`). REST-загрузка кидает обычный `Error` со статусом (`upload-avatar.ts:30`), ловится централизованно. Единственный собственный «ответ» — SSR HTML; его error-shape см. ERR-03. | — | — |
| ERR-08 | Retry-стратегии используют exponential backoff с jitter | ✅ PASS | High | `graphql-client.ts:35-42` — `retryExchange` с `initialDelayMs: 1000`, `maxDelayMs: 15000` (экспоненциальный рост с потолком), `randomDelay: true` (jitter), `maxNumberAttempts: 3` (ограничение попыток), `retryIf` только для `networkError` (бизнес-ошибки не ретраятся). Клиентский UI-ретрай в `ErrorFallback.tsx:42-43` также экспоненциальный (`1000 * 2 ** attempt`, потолок 30000). | — | — |
| ERR-09 | AbortSignal/CancellationToken пробрасывается во внешние вызовы [⚡ dynamic] | ❌ FAIL 🟡 | High | `upload-avatar.ts:23` — `fetch` без `signal`, отмена невозможна: запрос продолжается после ухода со страницы/размонтирования формы. Контраст с `graphql-client.ts:47`, где сигнал пробрасывается в `fetchOptions`. (По правилу для `[⚡ dynamic]` PASS не присваивается; здесь есть явное evidence отсутствия — FAIL.) | **1. Пробросить `AbortSignal.timeout(...)` в `fetch` (закрывает и ERR-05, и ERR-09 одним сигналом)** \\ 2. Создать `AbortController` в `useProfileForm` и вызывать `abort()` в cleanup-эффекте при размонтировании, передавая `controller.signal` в `uploadAvatar` \\ 3. Скомбинировать timeout-сигнал и unmount-сигнал через `AbortSignal.any([...])` | Нет |

## Сводка

- 🔴 Critical: 0
- 🟠 High: 1 — ERR-05 (`upload-avatar.ts:23`, fetch без таймаута)
- 🟡 Medium: 3 — ERR-03 (`server.ts:23`, SSR-handler без try/catch), ERR-09 (`upload-avatar.ts:23`, без AbortSignal)
  - (ERR-03 и ERR-09 — Medium; ERR-05 — единственный High)
- 🔍 UNVERIFIED: 2 — ERR-04, ERR-06 (process-level/graceful shutdown лежат в сгенерированном Nitro-сервере вне исходников)
- ✅ PASS: 4 — ERR-01, ERR-02, ERR-07, ERR-08

Только ERR-05 (🟠 High) требует обязательного решения. ERR-03 и ERR-09 (🟡) — желательны, но не блокирующие. Все три High/Medium FAIL фактически замыкаются на один файл — `src/features/profile/api/upload-avatar.ts` (таймаут + AbortSignal) и `src/server.ts` (try/catch вокруг SSR-рендера).

## Audit Coverage

Проверено: src/shared/api/graphql-client.ts, src/app/providers/** (GlobalErrorBoundary, AuthObserver, AppProviders), src/shared/ui/ErrorFallback/** (ErrorFallback, normalizeError, detectErrorCategory, errorConfig), src/shared/lib/sentry/**, src/features/auth/** (oidc-client, account-center, Neutral/Mock providers, types), src/features/profile/** (upload-avatar, useProfileForm, ProfileForm, schema), src/features/locale/ui/LocaleSwitcher.tsx, src/server.ts, src/client.tsx, src/router.tsx, src/routes/__root.tsx, src/shared/config/env.ts, Dockerfile.

Пропущено: tests (*.test.ts/tsx), stories (*.stories.tsx), сгенерированный код (src/generated/**), build-плагины (src/app/*.plugin.ts), сгенерированный Nitro-сервер (.output/** — вне исходников).

Файлов проверено: ~22 | Пропущено: ~неприменимо (тесты/генерация/сборка)
