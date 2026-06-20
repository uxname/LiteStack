# Audit Report: API Contracts — 2026-06-20 21:43

**Проект:** frontend (LiteStack) — **потребитель** API.
**Стек:** React 19 + TanStack Start (SSR), URQL, GraphQL codegen (`typescript-operations` + `typescript-urql`), один REST-вызов `POST /upload`.
**Важно:** фронтенд не определяет серверные HTTP-статусы, envelope ответов и версионирование. Эти аспекты оцениваются с точки зрения «как фронт формирует запросы и разбирает ответы». Где направление относится только к серверу — помечено N/A / UNVERIFIED с пояснением.
**Baseline:** пустой (`docs/audit-baseline.yml` — только шаблон).

## Результаты

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| API-01 | Форма ответов консистентна — единый envelope или его отсутствие по всему API | ✅ PASS | High | GraphQL: все операции без envelope, плоский объект данных — `src/graphql/queries/me.graphql`, `src/graphql/mutations/update-profile.graphql`; разбор через URQL `result.data`/`result.error` единообразно. REST: единственный вызов `src/features/profile/api/upload-avatar.ts:31` возвращает массив `UploadedFile[]`. Форма ответов внутри каждого транспорта консистентна, смешения envelope-паттернов нет. | — | — |
| API-02 | HTTP статус-коды семантически корректны (201 при создании, 4xx для client errors) | ✅ PASS | High | Фронт не задаёт статусы (он клиент), но корректно их трактует: `upload-avatar.ts:27` проверяет `!response.ok` (покрывает все не-2xx). Бэкенд (для подтверждения контракта) отдаёт `201 Created` при создании файла (`backend/internal/upload/handler.go:96`) и `4xx` на клиентские ошибки — фронт это принимает без зависимости от конкретного 2xx-кода. Нарушений со стороны фронта нет. | — | — |
| API-03 | Error responses машиночитаемы и консистентны по структуре | ❌ FAIL 🟡 | High | `src/features/profile/api/upload-avatar.ts:27-29` — фронт читает только `response.status`, тело ошибки (`{statusCode, message}`, см. `backend/internal/httperr/httperr.go`) полностью игнорируется и не разбирается: `throw new Error(\`Upload failed with status ${response.status}\`)`. Машиночитаемый код/сообщение от сервера отбрасываются → пользователь всегда видит один общий тост `profile_avatar_upload_error` независимо от причины (слишком большой файл / неверный MIME / 401). Деградация UX и диагностики, не отказ. | **1. Распарсить JSON-тело ошибки (`{statusCode, message}`) и пробросить `message` в `Error`, чтобы показывать причину (размер/тип/авторизация)** \\ 2. Завести разбор кодов ошибок в общий REST-хелпер `shared/api` для единообразия с будущими REST-вызовами \\ 3. Оставить как есть и задокументировать, что детализация ошибок загрузки не требуется (одна точка вызова, generic-тост приемлем) | Нет |
| API-04 | Именование полей консистентно (camelCase или snake_case, не смешано) | ✅ PASS | High | GraphQL-поля все camelCase: `avatarUrl`, `displayName`, `createdAt`, `updatedAt` (`src/graphql/queries/me.graphql`, `src/generated/graphql.tsx:36`). REST upload: `filename`/`path` (camelCase, single word) совпадает с бэкендом `json:"filename"`/`json:"path"` (`backend/internal/upload/service.go:69`). Zod-схема формы использует те же имена (`avatarUrl`, `displayName`, `bio` — `src/features/profile/model/schema.ts`). Снейк-кейс отсутствует, аббревиатуры (`Url`) единообразны. | — | — |
| API-05 | Stack trace и внутренние детали не попадают в error responses | ✅ PASS | Medium | Фронт — клиент, ответы не формирует. Со стороны потребления: ошибки уходят в Sentry через `errorExchange` (`src/shared/api/graphql-client.ts:18`) и не показываются пользователю «как есть» — UI отдаёт локализованные тосты (`profile_save_error`, `profile_avatar_upload_error`), а не сырые `error.message`. Утечки технических деталей в UI нет. Серверная сторона envelope — вне зоны фронта (*см. ERR-02 / OWA-07 в backend-аудите*). | — | — |
| API-06 | Пагинация включает метаданные (total/hasNext) где применима | ✅ N/A | High | В потребляемом API нет пагинируемых коллекций: `me` возвращает один профиль, `roles` — короткий enum-массив без пагинации (`src/graphql/queries/me.graphql`), upload — массив результатов одной загрузки. Пагинация неприменима. | — | — |
| API-07 | Публичный API имеет стратегию версионирования | 🔍 UNVERIFIED | High | Версионирование API определяет сервер, не фронт-потребитель. Со стороны фронта: эндпоинты не версионированы в URL (`VITE_GRAPHQL_API_URL`, `POST /upload` без `/v1`), но это решение бэкенда. Контракт фронта защищён иначе — codegen генерирует типы из живой схемы (`codegen.yml`: `schema: ${VITE_GRAPHQL_API_URL}`), поэтому breaking-изменение схемы ломает сборку. Оценить стратегию версионирования сервера из фронт-репозитория нельзя. | — | — |

## Дополнительные наблюдения (вне FAIL)

- **Контракт upload подтверждён сквозь обе стороны.** Фронт ожидает `UploadedFile[]` с полем `path` (`upload-avatar.ts:4-7,38`), бэкенд сериализует `[]*SavedFile{filename, path}` с теми же JSON-тегами и статусом 201 (`backend/internal/upload/handler.go:90-96`). Расхождений формы нет.
- **GraphQL-контракт типобезопасен на сборке.** `codegen.yml` мапит кастомные скаляры (`URL → string`, `DateTime → string`), `skipTypename: false`, нормализованный кэш кейзит `Profile` по `id` (`graphql-client.ts:13`). Изменение/удаление поля в схеме приведёт к ошибке типов в `src/generated/graphql.tsx` — это эффективная защита потребителя от drift'а.
- **Обработка GraphQL-ошибок консистентна.** Везде используется паттерн `result.error` после await мутации (`useProfileForm.ts:77`) и `errorExchange` для централизованного репортинга (`graphql-client.ts:18`). Retry только для `networkError` (`graphql-client.ts:40`) — бизнес-ошибки не ретраятся, что корректно.
- **Микро-несоответствие envelope между транспортами** (GraphQL flat vs REST array) — ожидаемо и не является нарушением: это два разных транспорта с разными конвенциями, внутри каждого форма единообразна.

## Итог

- 🔴 Critical: 0
- 🟠 High: 0
- 🟡 Medium: 1 (API-03 — тело ошибки REST upload не парсится)
- 🟢 Low: 0

API-контракты в целом консистентны. Единственная находка — потеря машиночитаемой ошибки загрузки аватара (severity 🟡, решение необязательно по правилу 5).

## Audit Coverage
Проверено: src/graphql/queries/**, src/graphql/mutations/**, codegen.yml, src/generated/graphql.tsx, src/generated/schema.graphql, src/features/profile/api/upload-avatar.ts, src/features/profile/model/schema.ts, src/features/profile/lib/useProfileForm.ts, src/shared/api/graphql-client.ts; cross-check: backend/internal/upload/handler.go, backend/internal/upload/service.go, backend/internal/httperr/httperr.go, backend/internal/devtools/openapi.yaml
Пропущено: tests/**, src/features/auth/** (OIDC, не API-контракты данных), src/app/providers/** (кроме error-handling)
Файлов проверено: ~12 | Пропущено: ~остальной src
