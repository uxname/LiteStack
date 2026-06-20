# Audit Report: State & Concurrency — 2026-06-20 21:43

Runtime: браузер (React 19 + TanStack Start) + SSR (Node.js). Стек: zustand, urql + @urql/exchange-graphcache + @urql/exchange-retry, oidc-client-ts / react-oidc-context, react-hook-form. Baseline пустой.

## Результаты по чеклисту

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| CON-01 | async/await не используется в неасинхронных итераторах (forEach, map) | ✅ PASS | High | Поиск по `src/features`, `src/entities`, `src/shared`, `src/app`: ни одного `forEach`/`.map(` с `async`/`await` внутри. Циклы в обработчиках профиля/аплоада отсутствуют — данные обрабатываются по одному элементу (`files[0]` в `upload-avatar.ts:34`). | — | — |
| CON-02 | Read-modify-write операции выполняются в транзакциях | ✅ PASS | Medium | Клиентский фронтенд не выполняет транзакции БД. Единственный read-modify-write — счётчик в zustand: `entities/counter/model/store.ts:8` `set((state) => ({ counter: state.counter + 1 }))` использует функциональный апдейтер `set`, который zustand применяет атомарно (синхронно, в одном потоке JS). Аналогично `theme/model/store.ts:24-26` (read `get().theme` → write `set`) — синхронно в одном тике, гонки нет. | — | — |
| CON-03 | Нет shared mutable state на уровне модуля (синглтоны, кэши без locks) | ❌ FAIL 🟡 | High | `src/app/providers/router-instance.ts:8` — module-level `let router` (изменяемый синглтон). Записывается только на клиенте под guard `if (typeof document !== "undefined")` (`src/router.tsx:29-32`), на сервере не трогается — поэтому cross-request утечки между SSR-запросами НЕТ. Остаточный риск только теоретический: в браузере один поток, конкурентной записи нет. URQL-клиент НЕ синглтон — создаётся через `useMemo` пер-компонент (`AppProviders.tsx:70`). | **1. Оставить как есть и задокументировать: запись под client-only guard, браузер однопоточен — реальной гонки нет (риск 🟢)** \\ 2. Передавать router в callback через replace-навигацию без module-level переменной (например через router context) \\ 3. Обернуть доступ в фабрику с явной проверкой среды и бросать ошибку при чтении на сервере | Нет |
| CON-04 | Module-level кэш имеет механизм инвалидации | ✅ PASS | High | graphcache (`shared/api/graphql-client.ts:13-17`) — это нормализованный кэш UI, привязанный к жизни клиента, а не модульный синглтон. Profile keyed по `id` (`:15`), поэтому мутация `updateProfile`, возвращающая обновлённый Profile, автоматически патчит все запросы (`me`). При смене access_token клиент полностью пересоздаётся (`AppProviders.tsx:70-73`, dep `[auth.user?.access_token]`) — кэш сбрасывается на login/logout. requestPolicy `cache-and-network` (`:49`) гарантирует фоновое обновление stale-данных. | — | — |
| CON-05 | Обработчики событий и webhook-handlers идемпотентны | 🔍 UNVERIFIED | Medium | OIDC callback не обрабатывается вручную: `routes/callback.tsx` только показывает спиннер + один `captureMessage` в `useEffect` (`:12-14`), без обмена code→token. Сам обмен и защита от повторного использования `code`/`state` выполняется библиотекой `react-oidc-context`/`oidc-client-ts` (`onSigninCallback`, `AppProviders.tsx:24-38`) — это внешний код, статически идемпотентность подтвердить нельзя. `handleCallback` в `auth/model/types.ts:16` — только тип в неиспользуемом интерфейсе `AuthStore` (zustand-стор не реализован), мёртвый контракт. Мутации (`updateProfile`) — не webhook, повтор безопасен на уровне UI (см. CON-06). `[⚡ dynamic]` | — | — |
| CON-06 | Background async операции имеют механизм отмены (AbortController/signal) и не блокируют graceful shutdown | ❌ FAIL 🟡 | High | Аплоад аватара `features/profile/api/upload-avatar.ts:23` — `fetch('/upload', …)` БЕЗ `signal`/`AbortController`. Если пользователь выбрал файл и ушёл со страницы (или выбрал другой файл) до ответа, запрос не отменяется; по возврату промиса `setValue("avatarUrl", url)` (`useProfileForm.ts:54`) может выполниться на размонтированном компоненте → предупреждение React и запись stale-URL. Сам GraphQL-клиент таймаут имеет (`graphql-client.ts:47` `AbortSignal.timeout(15000)`), а REST-аплоад — нет ни таймаута, ни отмены. Повторный сабмит формы предотвращён (`ProfileForm.tsx:104-105` `loading={isSubmitting}`, `disabled={!isDirty \|\| uploading}`), но это не отмена, а блокировка кнопки. | **1. Прокинуть `AbortController` в `uploadAvatar` (signal в fetch), отменять в cleanup `useEffect`/при новом выборе файла, добавить `AbortSignal.timeout` как у GraphQL-клиента** \\ 2. Проверять флаг «компонент смонтирован» (ref) перед `setValue` и игнорировать ответ, если файл уже сменился \\ 3. Оставить как есть и задокументировать: окно гонки мало, кнопка заблокирована на время `uploading` — риск приемлем | Нет |

## Дополнительные наблюдения (в рамках критических путей)

- **Последовательность аплоад → мутация (профиль):** аплоад и `updateProfile` выполняются раздельно: сначала `handleFileSelect` загружает файл и кладёт URL в форму (`useProfileForm.ts:51-59`), затем отдельный `onSubmit` сохраняет (`:62-83`). Кнопка submit заблокирована во время `uploading` (`ProfileForm.tsx:105`), а `isSubmitting` блокирует двойной сабмит — двойного сохранения нет. Это смягчает, но не закрывает CON-06 (сам аплоад-fetch неотменяем).
- **SSR cross-request изоляция:** провайдеры (auth, GraphQL-клиент) создаются пер-рендер через `Wrap` роутера и `useMemo`, без модульных синглтонов состояния; на сервере всегда `NeutralAuthProvider` (`AppProviders.tsx:50-51`). Утечки состояния между SSR-запросами не обнаружено.
- **retryExchange:** retry только сетевых ошибок (`graphql-client.ts:41` `retryIf: networkError`), exponential backoff + `randomDelay` (jitter), max 3 попытки — бизнес-мутации (GraphQL errors) не реплеятся, риска двойного применения от retry нет.

## Итог

- 🔴 Critical: 0
- 🟠 High: 0
- 🟡 Medium FAIL: 2 (CON-03, CON-06)
- 🔍 UNVERIFIED: 1 (CON-05 — обмен OIDC делегирован библиотеке)

Блокирующих находок (🔴/🟠) нет. Обязательного решения по правилам скила требуют только 🔴/🟠 — таких нет; CON-03 и CON-06 (🟡) рекомендательны.

## Audit Coverage
Проверено: src/entities/counter/model/store.ts, src/features/theme/model/**, src/features/auth/** (api, lib, model, ui), src/shared/api/graphql-client.ts, src/routes/callback.tsx, src/features/profile/** (api, lib, ui, model), src/app/providers/** (AppProviders, router-instance), src/router.tsx
Пропущено: src/**/*.test.* (тесты), generated/** (кодоген), компоненты без async/состояния вне критических путей
Файлов проверено: 15 | Пропущено: ~6 (тесты + generated)
