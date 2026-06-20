# Audit Report: Resource & Performance — 2026-06-20 21:43

**Объект:** фронтенд (`frontend/src`)
**Стек:** React 19 + TypeScript, TanStack Start (SSR), urql + @urql/exchange-graphcache, zustand
**Особенность:** у фронтенда нет собственной БД — проверки PER-01/PER-02 трактуются применительно к GraphQL-запросам и SSR-обработчику.

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| PER-01 | Нет N+1: запросы не выполняются внутри циклов | 🔍 UNVERIFIED | High | Статически N+1 не найден: GraphQL-вызовы (`generated/graphql.tsx` — `useQuery(Me)`, `useMutation(UpdateProfile)`) и `fetch` (`upload-avatar.ts:23`) не находятся внутри циклов. Проверка помечена `[⚡ dynamic]` — окончательно подтверждается только в рантайме | — [⚡ dynamic] | — |
| PER-02 | Выборки ограничены (LIMIT, пагинация) | ✅ PASS | High | В `src/graphql/**` всего два документа: `me` (один объект текущего пользователя) и мутация `updateProfile`. Списочных выборок, способных вернуть неограниченный набор, нет — пагинация не требуется | — | — |
| PER-03 | Обработчики запросов не содержат блокирующего I/O | ✅ PASS | High | SSR-обработчик `server.ts` полностью асинхронный (`await handler(...)` внутри `paraglideMiddleware`), синхронного I/O в пути запроса нет. Найденные `readFileSync` (`app/strip-dangling-sourcemaps.plugin.ts`, `app/vite-dotenv-checker.plugin.ts`) — это Vite-плагины уровня сборки, не рантайм-handler. `JSON.parse` в `routes/__root.tsx:35` — инлайн-скрипт темы, исполняется в браузере над крошечным значением localStorage | — | — |
| PER-04 | CPU-интенсивные операции вынесены из main thread | ✅ PASS | High | Тяжёлых вычислений (crypto, обработка изображений, сжатие, сортировка больших массивов, regex по длинным строкам) в `src/` не обнаружено. Загрузка аватара (`upload-avatar.ts`) делегирует обработку файла бэкенду через `POST /upload`, на клиенте файл не обрабатывается | — | — |
| PER-05 | Независимые async-операции выполняются параллельно | ✅ PASS | High | Единственная многошаговая цепочка — загрузка аватара: `uploadAvatar` → затем сохранение URL через `updateProfile`. Шаги зависимы (URL нужен до сохранения), поэтому последовательность корректна. Независимых await'ов, которые стоило бы объединить в `Promise.all`, нет | — | — |
| PER-06 | Кэши ограничены по размеру и времени жизни (TTL + size limit) | ✅ PASS | Medium | Кэш — нормализованный `cacheExchange` urql (`graphql-client.ts:14`), in-memory в рамках сессии вкладки, очищается при перезагрузке. Это управляемый библиотекой кэш на клиенте, а не долгоживущий серверный кэш без границ — unbounded-роста в long-lived процессе не возникает. Своих самописных кэшей без TTL/лимита нет | — | — |
| PER-07 | Event listeners и subscriptions очищаются при завершении | ✅ PASS | High | `GlobalErrorBoundary.tsx:16-20` — слушатели `unhandledrejection`/`error` снимаются в cleanup. `AuthObserver.tsx` — `addSilentRenewError(handler)` снимается через `removeSilentRenewError(handler)` в return эффекта. Все эффекты имеют корректные зависимости и cleanup | — | — |
| PER-08 | Нет утечек памяти через timers и closures | ❌ FAIL 🟢 | High | `ErrorFallback.tsx:56` (`setTimeout(doRetry, delay)`) и `:76` (`setTimeout(() => setCopied(false), 2000)`) не сохраняются и не отменяются. Это одноразовые таймеры в обработчиках событий (не в `useEffect`), коротких длительностей (макс. 30 с / 2 с), больших объектов в замыкании не удерживают. Реальной утечки нет; в React 19 `setState` после размонтирования — no-op. Замечание уровня best-practice | **1. Сохранять id таймера в `useRef` и очищать в `useEffect`-cleanup при размонтировании** \\ 2. Гейтить `setCopied(false)` флагом «компонент жив» (`mountedRef`) \\ 3. Оставить как есть — таймеры одноразовые и короткие, утечки нет (задокументировать) | Нет |

## Итог

Производительность фронтенда в хорошем состоянии. Архитектура запросов простая (один объектный query + мутации), пагинация не нужна. GraphQL-клиент сделан грамотно: таймаут запроса через `AbortSignal.timeout(15000)`, retry с экспоненциальным backoff только для сетевых ошибок, нормализованный кэш. Слушатели и подписки везде корректно очищаются. Единственная находка — низкого уровня (🟢): два неотменяемых `setTimeout` в `ErrorFallback`, что является лишь отклонением от best-practice без фактической утечки.

## Audit Coverage
Проверено: `src/app/**`, `src/features/**`, `src/pages/**`, `src/routes/**`, `src/shared/api/**`, `src/shared/ui/**`, `src/graphql/**`, `src/server.ts`, `src/start.ts`
Пропущено: `src/generated/**` (автогенерация), `src/app/*.plugin.ts` (build-time, вне рантайм-пути), `tests/**`, `scripts/**`
Файлов проверено: 109 (.ts/.tsx) | Пропущено: автоген + тесты + build-плагины
