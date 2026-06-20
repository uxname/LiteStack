# Full Audit Report — 2026-06-20 21:43

**Объект:** фронтенд (`frontend/`)
**Стек:** React 19 + TypeScript, TanStack Start (SSR), urql + graphcache, zustand, react-hook-form + zod, OIDC (Logto), Sentry, Feature-Sliced Design.
**Baseline:** пустой (`accepted: []`) — принятых рисков нет.
**Покрытие:** 16 направлений (15 аудитов + матрица + верификация + мета-контроль). 109 файлов `.ts/.tsx`.
**Критические пути:** OIDC-аутентификация (`features/auth`, `routes/callback.tsx`), профиль + загрузка аватара (`features/profile`), GraphQL-клиент с инъекцией токена (`shared/api/graphql-client.ts`), SSR-обработчик (`server.ts`).

> 🔴 Critical-проблем не обнаружено. Большинство значимых находок сходятся к **4 корневым причинам** (см. ниже) — их устранение закрывает сразу несколько строк отчёта.

---

## Компоненты системы

1. **Аутентификация (OIDC):** `features/auth/**`, `routes/callback.tsx`, `app/providers/Auth*`
2. **Профиль + загрузка аватара:** `features/profile/**`, `pages/account/**`
3. **GraphQL/API слой:** `shared/api/**`, `graphql/**`, `generated/**`
4. **SSR / роутинг:** `server.ts`, `start.ts`, `router.tsx`, `routes/**`, `app/providers/**`
5. **Наблюдаемость (Sentry/логи):** `shared/lib/sentry/**`, `app/providers/AuthObserver.tsx`
6. **UI-kit / виджеты:** `shared/ui/**`, `widgets/**`, `entities/**`
7. **Конфиг / развёртывание:** `shared/config/**`, `Dockerfile`, `docker-compose.yml`, `.dockerignore`

---

## Корневые причины (закрывают несколько находок сразу)

| # | Корневая причина | Файл | Закрывает |
|---|------------------|------|-----------|
| RC-1 | Загрузка аватара через `fetch` без таймаута и `AbortSignal` | `features/profile/api/upload-avatar.ts:23` | ERR-05 🟠, ERR-09, CON-06, VAL-08, API-03, X1 (matrix) |
| RC-2 | Проверка обязательных env-переменных обёрнута в `if (env.DEV)` — в проде не падает | `shared/config/env.ts:45` | BUG-03 🟠, межкомпонентный риск (matrix) |
| RC-3 | Sentry Session Replay c `maskAllText:false` + отправка PII через `setUser` | `shared/lib/sentry/config.ts:19-22`, `AuthObserver.tsx:43-47` | LOG-02 🟠, LOG-03 🟠 |
| RC-4 | Нет CSP/HSTS, при этом access-токен в `localStorage` | `vite.config.ts:71-79` | OWA-05 🟠 |

---

## Компонент: Профиль + загрузка аватара

| Check ID | Проверка | Статус | Доказательство | Решение | Исправлено |
|----------|----------|--------|----------------|---------|------------|
| ERR-05 | Внешние вызовы имеют таймаут | ❌ FAIL 🟠 | `features/profile/api/upload-avatar.ts:23` — `fetch('/upload')` без таймаута; при зависшем бэкенде запрос висит, флаг `uploading` не сбрасывается, форма блокируется | **1. Добавить `signal: AbortSignal.timeout(30000)` в fetch** \\ 2. Обернуть в Promise.race с таймаут-промисом \\ 3. Прокинуть внешний AbortController из компонента | Нет |
| ERR-09 | AbortSignal пробрасывается во внешние вызовы | ❌ FAIL 🟡 | `upload-avatar.ts:23` — тот же fetch без `signal`, отмену сделать нельзя | (грань RC-1) | Нет |
| CON-06 | Фоновые операции отменяемы | ❌ FAIL 🟡 | `upload-avatar.ts:23` — без отмены `setValue("avatarUrl", url)` может записать stale-URL после ухода со страницы | (грань RC-1) | Нет |
| VAL-08 | Загрузка файлов: MIME/размер проверяются | ❌ FAIL 🟡 | `useProfileForm.ts:47-54` — файл уходит в upload без проверки `file.size`/`file.type`; `accept="image/*"` лишь подсказка | Проверять size+MIME на клиенте перед отправкой (граница доверия — серверный `/upload`) | Нет |
| API-03 | Error responses машиночитаемы | ❌ FAIL 🟡 | `upload-avatar.ts:27-29` — читается только `response.status`, тело `{statusCode,message}` игнорируется → один общий тост на все ошибки | Разобрать JSON-тело ошибки и показать причину | Нет |
| TST-04 | Критические пути покрыты тестами | ❌ FAIL 🟡 | `upload-avatar.ts:29-37` и `useProfileForm.ts:55-59,77-80` — ветки ошибок (throw, toast.error) не покрыты юнитами | Добавить тесты на ветки сбоя загрузки/мутации | Нет |
| BUG-09 / BUG-01 | Дата в UTC / безопасное преобразование | ❌ FAIL 🟡 | `pages/account/lib/account.ts:89` — `new Date(String(createdAt)).toLocaleDateString()`: зависит от таймзоны/локали, нет guard на `Invalid Date` | Форматировать через UTC + guard на валидность даты | Нет |
| BUG-05 | Exhaustive handling enum/union | ❌ FAIL 🟡 | `detectErrorCategory.ts`, `account.ts:92` (`roleLabel`: всё кроме `ADMIN` молча → user) — нет `never`-проверки | Добавить exhaustive `switch` с `never`-веткой | Нет |

## Компонент: Аутентификация / Конфиг

| Check ID | Проверка | Статус | Доказательство | Решение | Исправлено |
|----------|----------|--------|----------------|---------|------------|
| BUG-03 | Null-safety | ❌ FAIL 🟠 | `account-center.ts:39`, `upload-avatar.ts:19` — `new URL(env.VITE_*)` без guard; `env.ts:45-52` проверяет required-переменные только в `if (env.DEV)` и лишь пишет `console.error`. В проде пустая переменная → `TypeError` ломает построение URL | **1. Валидировать required env всегда (zod) и падать при старте** \\ 2. Guard перед `new URL` с фолбэком \\ 3. Перенести проверку из `if(DEV)` в безусловную | Нет |
| CON-05 | Идемпотентность обработчиков | 🔍 UNVERIFIED | `routes/callback.tsx` рисует спиннер; обмен code→token делегирован `react-oidc-context`, статически не подтверждается | — | — |

## Компонент: Наблюдаемость (Sentry / логи)

| Check ID | Проверка | Статус | Доказательство | Решение | Исправлено |
|----------|----------|--------|----------------|---------|------------|
| LOG-02 | PII не логируется | ❌ FAIL 🟠 | `AuthObserver.tsx:43-47` шлёт `email`+`username` в `setUser`; усугублено `replayIntegration({maskAllText:false, blockAllMedia:false})` (`config.ts:19-22`) — записывается весь видимый текст | **1. Включить `maskAllText:true` в replay** \\ 2. Убрать email/username из `setUser`, оставить только `id` \\ 3. Настроить `beforeSend`-скраббинг PII | Нет |
| LOG-03 | Секреты/токены не в логах | ❌ FAIL 🟠 | Незамаскированный replay может захватить токены из DOM; `graphql-client.ts:24` логирует весь массив `graphQLErrors` (вкл. возможные `extensions`) | Тот же фикс replay (RC-3) + фильтровать `graphQLErrors` перед отправкой | Нет |
| LOG-04 | Сквозная трассировка | 🔍 UNVERIFIED | Sentry даёт internal trace-id, но сквозной correlation-ID фронт→бэк не пробрасывается | — | — |

## Компонент: Безопасность HTTP (заголовки)

| Check ID | Проверка | Статус | Доказательство | Решение | Исправлено |
|----------|----------|--------|----------------|---------|------------|
| OWA-05 | Безопасная конфигурация (CORS, security headers) | ❌ FAIL 🟠 | `vite.config.ts:71-79` — Nitro отдаёт только `X-Frame-Options`+`X-Content-Type-Options`; нет CSP/HSTS/Referrer-Policy, а access-токен лежит в `localStorage` → любой XSS читает токен | **1. Добавить строгий CSP (nonce/hash для инлайн-скрипта темы) + HSTS** \\ 2. Перенести токен из localStorage в memory/httpOnly-cookie \\ 3. Добавить Referrer-Policy + Permissions-Policy | Нет |
| OWA-03 | Resource ownership / IDOR | 🔍 UNVERIFIED | Фронт шлёт только «свои» запросы (`me`, `updateProfile` без чужого ID); ownership — зона бэкенда | — | — |

## Компонент: SSR / роутинг

| Check ID | Проверка | Статус | Доказательство | Решение | Исправлено |
|----------|----------|--------|----------------|---------|------------|
| ERR-03 | Async handlers пробрасывают исключения | ❌ FAIL 🟡 | `server.ts:23` — `await handler(...)` внутри `paraglideMiddleware` без `try/catch`; реджект SSR-рендера уходит в Nitro без app-фолбэка, теряется `Set-Cookie` локали | Обернуть рендер в try/catch с фолбэк-ответом | Нет |
| CON-03 | Нет shared mutable state на уровне модуля | ❌ FAIL 🟡 | `app/providers/router-instance.ts:8` — `let router` синглтон; пишется только на клиенте под guard, cross-request утечки на SSR нет (риск теоретический) | Оставить (браузер однопоточен) или инкапсулировать в фабрику | Нет |
| ERR-04 / ERR-06 | Process-level handlers / graceful shutdown | 🔍 UNVERIFIED | На клиенте window-handlers есть (`GlobalErrorBoundary.tsx:16-17`); прод-сервер — сгенерированный Nitro-бандл вне репозитория | — | — |

## Компонент: Конфиг / развёртывание

| Check ID | Проверка | Статус | Доказательство | Решение | Исправлено |
|----------|----------|--------|----------------|---------|------------|
| DEP-11 | Ограничения ресурсов контейнера | ❌ FAIL 🟠 | `docker-compose.yml` — нет лимитов CPU/памяти для сервиса `app`; утечка в SSR-процессе исчерпает ресурсы хоста | **1. Задать `deploy.resources.limits` (cpus/memory)** \\ 2. Через `mem_limit`/`cpus` (compose v2) \\ 3. Лимиты на уровне оркестратора (k8s) | Нет |
| DEP-10 | npm ci вместо npm install | ❌ FAIL 🟡 | `Dockerfile:14` — `npm install --legacy-peer-deps` при наличии `package-lock.json` → недетерминированная сборка | Заменить на `npm ci` | Нет |
| DEP-04 / SEC | `.env` исключён из build-контекста | ❌ FAIL 🟡 | `.dockerignore` не содержит `.env`, а `Dockerfile` делает `COPY . ./` → локальный `.env` попадает в build-слой (сейчас только публичные `VITE_*`, секретов нет) | Добавить `.env` в `.dockerignore` | Нет |
| DEP-05 | HEALTHCHECK в Dockerfile | ❌ FAIL 🟡 | HEALTHCHECK есть только в `docker-compose.yml`, теряется вне compose | Перенести/продублировать в Dockerfile | Нет |
| DEP-01 | Pinned versions образов | ❌ FAIL 🟡 | `Dockerfile` — `node:lts-alpine` (плавающий тег), версия не запиннена | Запиннить до `node:22.x.x-alpine` + digest | Нет |
| DEP-12 | Read-only root filesystem | ❌ FAIL 🟡 | `read_only: true` в compose не проверен/не задан | Проверить запуск с `read_only:true` + tmpfs | Нет |
| SEC-04 | `.env.example` без реальных данных | ❌ FAIL 🟡 | `.env.example:13-14` — реальные значения dev-тенанта (`VITE_OIDC_AUTHORITY`, `VITE_OIDC_CLIENT_ID`); намеренно публичные PKCE-идентификаторы, не секрет | Оставить с комментарием либо заменить плейсхолдерами | Нет |

## Компонент: Качество кода (Tests / Architecture / Naming / YAGNI / Performance)

| Check ID | Проверка | Статус | Доказательство | Решение | Исправлено |
|----------|----------|--------|----------------|---------|------------|
| TST-02 | Coverage gate в CI | ❌ FAIL 🟡 | Пороги заданы (`vitest.config.ts:26-31`), но настоящего CI нет (`.github/workflows` отсутствует); проверка только в pre-push, обходится `--no-verify` | Добавить CI-пайплайн с coverage-гейтом | Нет |
| TST-05 | Изоляция тестов | ❌ FAIL 🟡 | `tests/setup.ts:37-58` — глобальные моки без `restoreMocks`/`clearMocks` в `vitest.config.ts`; изоляция держится на ручных `vi.clearAllMocks()` | Включить `clearMocks/restoreMocks: true` | Нет |
| ARC-03 | Нет circular dependencies | ❌ FAIL 🟢 | 2 безопасных цикла: type-only внутри profile (`ProfileForm↔useProfileForm`) и сгенерированный `routeTree.gen.ts↔router.tsx`. Межслайсовых рантайм-циклов нет; `steiger` — без замечаний | Вынести `ProfileFormProps` в `model` (опционально) | Нет |
| NAM-05 | Magic numbers заменены константами | ❌ FAIL 🟢 | `server.ts:37` (`Max-Age=31536000`), `graphql-client.ts:37-47` (дублируется `15000`) | Вынести в именованные константы | Нет |
| YAGNI-02 | Нет dead code | ❌ FAIL 🟢 | `package.json:75` — `@graphql-codegen/typescript` не используется (плагин намеренно убран из `codegen.yml`) | `npm rm @graphql-codegen/typescript` | Нет |
| PER-08 | Нет утечек через timers | ❌ FAIL 🟢 | `ErrorFallback.tsx:56,76` — два `setTimeout` без очистки (одноразовые, короткие, утечки нет — best-practice) | Сохранять id в ref и чистить в cleanup | Нет |

> Полностью чистые направления: **Architecture** (FSD-дисциплина образцовая, `steiger` без замечаний), **Naming** (кроме NAM-05), **Performance** (кроме PER-08), **YAGNI** (кроме YAGNI-02). Детали — в соответствующих файлах сессии.

---

## Сводка

| Компонент | 🔴 | 🟠 | 🟡🟢 | UNVERIFIED | Итого FAIL |
|-----------|----|----|------|-----------|------------|
| Профиль + загрузка аватара | 0 | 1 | 6 | 0 | 7 |
| Аутентификация / конфиг | 0 | 1 | 0 | 1 | 1 |
| Наблюдаемость (Sentry) | 0 | 2 | 0 | 1 | 2 |
| Безопасность HTTP | 0 | 1 | 0 | 1 | 1 |
| SSR / роутинг | 0 | 0 | 2 | 2 | 2 |
| Конфиг / развёртывание | 0 | 1 | 6 | 0 | 7 |
| Качество кода | 0 | 0 | 6 | 0 | 6 |
| **ИТОГО** | **0** | **6** | **20** | **5** | **26** |

*Примечание: грани RC-1 (ERR-09/CON-06/VAL-08/API-03) учтены в строках, но восходят к одному фиксу.*

---

## Критические риски (🔴)

🔴 Critical-проблем не обнаружено.

## Приоритет исправления (🟠 High — 6 находок, 4 корневых причины)

1. **RC-1 — таймаут/отмена загрузки аватара** (`upload-avatar.ts:23`) → ERR-05. Один `AbortSignal.timeout(30000)` закрывает 5 строк отчёта.
2. **RC-2 — валидация env в проде** (`env.ts:45`) → BUG-03. Сейчас отсутствие `VITE_GRAPHQL_API_URL` в проде молча ломает весь сетевой слой.
3. **RC-3 — Sentry replay + PII** (`config.ts:19-22`, `AuthObserver.tsx:43-47`) → LOG-02, LOG-03. `maskAllText:true` + чистка `setUser`.
4. **RC-4 — CSP/HSTS при токене в localStorage** (`vite.config.ts:71`) → OWA-05.
5. **DEP-11 — лимиты ресурсов контейнера** (`docker-compose.yml`).

---

## Верификация и мета-контроль

- **`audit-verify`:** подтверждено ~28 находок FAIL по реальному коду, false-positives — 0, пропущенных критических рисков — 0. Качество доказательной базы высокое.
- **`audit-meta`:** оценка качества аудита — высокая; покрытие полное, выдуманных находок нет, статусы (PASS/UNVERIFIED) применены корректно.
- **Согласование severity (применено в этом отчёте):**
  - дефект загрузки аватара (нет таймаута/отмены) — единый корень 🟠 (ERR-05), грани — 🟡;
  - находка «`.env` в Docker build-контексте» выровнена на 🟡 (реальных секретов в `.env` нет).

## Рекомендация по baseline
Занести в `docs/audit-baseline.yml` как `intentional`/`false-positive`: ARC-03 (безопасные type-only/codegen-циклы), SEC-04 (публичные PKCE-идентификаторы), CON-03 (клиентский синглтон роутера) — чтобы не всплывали в следующих прогонах.
