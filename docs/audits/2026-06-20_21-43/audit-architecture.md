# Audit Report: Architecture & File Structure — 2026-06-20 21:43

**Проект:** LiteStack frontend (React 19 + TanStack Start SSR, urql, Zustand, Zod, Feature-Sliced Design).
**Runtime:** Node.js / TypeScript.
**Baseline:** пустой (`docs/audit-baseline.yml` — только шаблон, ни одного принятого риска).
**Инструменты:** `npx steiger src` → **No problems found**; `npx madge --circular` → 2 цикла (оба разобраны ниже).

Проект использует FSD-слои: `app / pages / widgets / features / entities / shared` (+ служебные `routes`, `graphql`, `generated`). Чеклист ARC-01..07 адаптирован под фронтенд: «service/domain» = слой `model/lib`, «presentation» = слой `ui`, «DB» = GraphQL/REST API.

## Результаты

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| ARC-01 | Бизнес-логика вынесена из компонентов (route handlers) в слой model/lib | ✅ PASS | High | Логика форм/деривации вынесена в хуки и чистые функции: `src/features/profile/lib/useProfileForm.ts` (RHF + submit), `src/pages/account/lib/account.ts:49-93` (резолверы claims), `src/features/auth/lib/account-center.ts:35` (построение URL). Компоненты `ProfileForm.tsx`, `account/ui/index.tsx` — чистый рендер | — | — |
| ARC-02 | Слой представления не обращается к API напрямую (минуя слой данных) | ✅ PASS | High | Доступ к данным — только через urql-хуки из `@generated/graphql` (`useMeQuery`, `useUpdateProfileMutation`) — допустимо по заданию. REST-загрузка аватара изолирована в `src/features/profile/api/upload-avatar.ts`, а не вызывается из компонента напрямую. urql-клиент собирается в `src/shared/api/graphql-client.ts` | — | — |
| ARC-03 | Нет circular dependencies между слайсами/модулями | ❌ FAIL 🟢 | High | `madge` нашёл 2 цикла. (1) `features/profile/ui/ProfileForm.tsx` ↔ `features/profile/lib/useProfileForm.ts` — внутрислайсовый и **type-only** (`useProfileForm.ts:12` → `import type { ProfileFormProps }`), стирается при компиляции. (2) `generated/routeTree.gen.ts` ↔ `router.tsx` — сгенерирован TanStack, не редактируется. Межслайсовых рантайм-циклов нет; FSD-импорты между фичами отсутствуют | **1. Вынести `ProfileFormProps` в `features/profile/model` (или в сам хук) и импортировать оттуда — цикл исчезает** \\ 2. Оставить как есть и задокументировать: type-only импорт не создаёт рантайм-цикла, сгенерированный файл вне контроля \\ 3. Добавить оба паттерна в `docs/audit-baseline.yml` как `false-positive` | Нет |
| ARC-04 | Нет god-объектов: один файл — одна ответственность | ✅ PASS | High | Самые крупные файлы — презентационные: `pages/home/ui/index.tsx` (186), `pages/account/ui/index.tsx` (182), `shared/ui/ErrorFallback/ErrorFallback.tsx` (179). Все < 200 строк, без смешения ответственностей; логика вынесена в `lib`. God-объектов нет | — | — |
| ARC-05 | Конфигурация и env изолированы в config-модуле | ✅ PASS | High | Все `VITE_*` собраны в `src/shared/config/env.ts` с типизацией `Env` и проверкой required-переменных. Прямой `import.meta.env` вне config — только технические флаги сборки: `client.tsx:12` / `__root.tsx:18,43` (`import.meta.env.DEV/MODE` для devtools) и `app/vite-dotenv-checker.plugin.ts:12` (`process.env.NODE_ENV` в Vite-плагине, выполняется на этапе сборки). Бизнес-переменные не разбросаны | — | — |
| ARC-06 | Внешние зависимости инжектируются, а не создаются внутри | ✅ PASS | Medium | urql-клиент создаётся фабрикой `createGraphQLClient(accessToken)` и прокидывается через React-контекст (`AppProviders.tsx:68-75` `GraphQLBridge`). OIDC-провайдер выбирается по окружению в `AuthBoundary` (server/mock/real), `getOidcConfig()` вызывается лениво. `accessToken` прокидывается параметром в `uploadAvatar(file, accessToken)`. Подмена в тестах возможна через провайдеры | — | — |
| ARC-07 | Нижние слои не импортируют верхние (Dependency Rule) | ✅ PASS | High | Проверено grep'ом: `shared/` не импортирует `entities/features/widgets/pages/app`; `entities/` не импортирует `features/widgets/pages`; межфичевых импортов (`features → features`) нет; `pages` импортируют только `widgets/features/entities/shared` (корректное направление). Глубоких импортов во внутренности слайсов (минуя `index.ts`) нет — инкапсуляция FSD соблюдена. `steiger` подтверждает: 0 нарушений | — | — |

## Ключевые наблюдения

- **Образцовая FSD-дисциплина.** Каждый слайс имеет публичный API (`index.ts`), внутренности (`ui/model/lib/api`) наружу не торчат. `steiger` (официальный FSD-линтер, в `steiger.config.js` подключён `fsd.configs.recommended`) не нашёл ни одного нарушения, и `lint:fsd` встроен в скрипты.
- **Разделение ответственностей.** Компоненты — чистый рендер; вся логика (формы, резолверы OIDC-claims, построение URL, выбор auth-провайдера) живёт в `lib`/`model`/`api`. Это прямое выполнение ARC-01 в терминах фронтенда.
- **Критические пути чистые.** `features/auth/**`, `features/profile/**`, `shared/**` проверены пофайлово — нарушений слоёв, god-объектов или прямого доступа к API из UI нет.
- **Единственная находка — 🟢 Low (ARC-03):** два цикла от `madge`, оба безопасные (type-only внутри одного слайса + сгенерированный TanStack-файл). Это не межслайсовый рантайм-цикл и не нарушает FSD. Решение опционально.

## Audit Coverage

Проверено: `src/app/**`, `src/pages/**`, `src/widgets/**`, `src/features/**` (вкл. critical `auth`, `profile`), `src/entities/**`, `src/shared/**`, `src/routes/**`, корневые `client.tsx / router.tsx / server.ts / start.ts`.
Пропущено: `src/generated/**` (кодоген: GraphQL, routeTree, paraglide), `*.test.*`, `*.stories.*`, `node_modules`.
Файлов проверено: 76 (исходные .ts/.tsx без тестов/историй/генерации) | Пропущено: 33 (тесты, истории, сгенерированные).
