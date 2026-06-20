# Audit Report: Naming — 2026-06-20 21:43

Проект: `frontend` (LiteFront — Vite, React 19, TanStack Start SSR, URQL, FSD, Zustand, Tailwind v4 + DaisyUI v5, Paraglide i18n).
Runtime: Node.js / TypeScript. Baseline: пустой (нет принятых исключений).

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| NAM-01 | Соглашение об именовании соблюдается консистентно (camelCase/snake_case) | ✅ PASS | High | По всему `src/` стиль camelCase для переменных/функций, PascalCase для компонентов и типов (`ProfileForm`, `HeaderControls`, `ThemeStore`, `AccountAction`). Единичный snake_case (`show_success` в `src/routes/account.tsx:11`, `Max-Age` в `src/server.ts:37`) — это внешний контракт Logto/HTTP, а не код проекта. Смешения стилей в одном модуле не найдено. | — | — |
| NAM-02 | Имена переменных, функций и классов описывают назначение, не реализацию | ✅ PASS | High | Имена осмысленны и доменно-ориентированы: `buildAccountCenterUrl`, `resolveAvatarUrl`, `detectErrorCategory`, `formatMemberSince`, `useProfileForm`, `copyInstallCommand`. Однобуквенных переменных вне циклов, аббревиатур (`mgr`/`srv`/`tmp`) и общих свалок (`data`/`info`/`handler`) в продакшн-коде нет (grep по `src` без `.test.` — пусто). Короткие `loc`/`kw` локальны и в комментариях расшифрованы. | — | — |
| NAM-03 | Boolean-переменные имеют предикативные имена (is/has/can/should) | ✅ PASS | High | Булевы консистентно предикативны: `isDirty`, `isSubmitting`, `isAuthenticated`, `isLoading`, `hasLocaleCookie` (`src/server.ts:31`), `uploading` (state). Локальный guard-флаг `cancelled` (`src/routes/account.tsx:33`) — устоявшаяся идиома отмены эффекта. Отрицательных/двойных отрицаний (`isNotValid`) не найдено. | — | — |
| NAM-04 | Функции-читатели (get*/find*) не имеют side effects | ✅ PASS | High | Все reader-функции чистые: `getOidcConfig` (`src/features/auth/api/oidc-client.ts:12`) только собирает объект конфигурации, `getAppRouter` (`src/app/providers/router-instance.ts:14`) возвращает ссылку, `getRouter` (`src/router.tsx:19`) — фабрика роутера. `resolve*`/`format*`/`build*` функции в `src/pages/account/lib/account.ts` — чистые трансформации без записи. `find*`/`fetch*` с побочной записью не найдено. | — | — |
| NAM-05 | Magic numbers и magic strings заменены именованными константами | ❌ FAIL 🟢 | High | `src/server.ts:37` — `Max-Age=31536000` (1 год в секундах) вписан строкой в заголовок Set-Cookie без именованной константы и без комментария о значении. Аналогично `src/shared/api/graphql-client.ts:37-39` — `initialDelayMs: 1000`, `maxDelayMs: 15000`, `maxNumberAttempts: 3` и таймаут `AbortSignal.timeout(15000)` (строка 47) заданы инлайн-литералами; `15000` дублируется в двух местах. | **1. Вынести в именованные константы: `const COOKIE_MAX_AGE_SECONDS = 31_536_000; // 1 год` и `const REQUEST_TIMEOUT_MS = 15_000` (переиспользовать в retry и в `AbortSignal.timeout`)** \\ 2. Добавить поясняющий комментарий рядом с каждым литералом, оставив значение инлайн \\ 3. Оставить как есть (значения локальны и одноразовы) — задокументировать в baseline как intentional | Нет |
| NAM-06 | Утилитные модули не являются свалкой несвязанного кода | ✅ PASS | High | `src/shared/lib/` не содержит `utils.ts`/`helpers.ts`-свалки: только `cn.ts` (одна функция склейки classnames) и каталог `sentry/` (config + ре-экспорты). Прочие `lib`-папки сфокусированы по слою/фиче: `pages/account/lib/account.ts` (резолверы профиля), `pages/home/lib/copyInstallCommand.ts`, `features/profile/lib/useProfileForm.ts`, `features/auth/lib/account-center.ts`. Имена файлов отражают содержимое; `index.ts`-баррели экспортируют связанные сущности одного слайса. | — | — |
| NAM-07 | Ключевые сущности названы в соответствии с доменным глоссарием проекта | ✅ PASS | Medium | Полноценного `GLOSSARY.md` нет, но `AGENTS.md`/`README.md` фиксируют доменные термины (`auth`, `theme`, `locale`, `profile`, `account`, `user`). Код им соответствует: FSD-слайсы `features/auth`, `features/theme`, `features/locale`, `features/profile`, сущность `Profile` (URQL cache key в `graphql-client.ts:15`), `AccountAction`/`SecurityAction`. Расхождений-синонимов (`User`/`Member`/`Customer` для одной сущности) не найдено: `client` в коде означает только GraphQL/URQL-клиент, не «заказчика». | — | — |

## Замечания вне чеклиста (информативно, не входят в оценку)

- `src/routes/account.tsx:21` — тост успеха жёстко привязан к `m.change_password_success()`, хотя `show_success` приходит от любого действия Account Center (email/MFA/passkey). Это смысловая/i18n-неточность, не нарушение именования.

## Audit Coverage

Проверено: `src/shared/lib/**`, `src/shared/config/**`, `src/shared/api/**`, `src/shared/ui/ErrorFallback/**`, `src/features/auth/**`, `src/features/profile/**`, `src/features/theme/**`, `src/features/locale/**`, `src/entities/counter/**`, `src/pages/account/**`, `src/pages/home/**`, `src/widgets/Header/**`, `src/app/providers/**`, `src/routes/**`, `src/server.ts`, `src/router.tsx`
Пропущено: `src/generated/**` (автоген: routeTree.gen.ts, graphql.tsx, paraglide), `**/*.test.ts(x)`, `**/*.stories.tsx`, `*.plugin.ts`
Файлов проверено: ~30 ключевых из 109 .ts/.tsx (продакшн-код выборочно покрыт по всем слоям FSD) | Пропущено: автоген + тесты + сторис

## Итог

Стандарты именования соблюдены практически полностью. Единственное нарушение — NAM-05 уровня 🟢 Low (несколько magic-number литералов без именованных констант). 🔴/🟠 FAIL отсутствуют — решений, требующих обязательного действия, нет.
