# Audit Report: Over-engineering & YAGNI — 2026-06-20 21:43

**Объект:** фронтенд (`frontend/src`)
**Стек:** React 19 + TypeScript, TanStack Start/Router, urql (GraphQL), zustand, Feature-Sliced Design (FSD)
**Инструменты:** knip (анализ неиспользуемого кода/зависимостей), ручная проверка по чеклисту

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| YAGNI-01 | Нет закомментированного кода | ✅ PASS | High | По всему `src/` закомментированных блоков кода нет. Найденные комментарии (`server.ts:22`, `start.ts:4`, `routes/account.tsx:36`) — поясняющие, а не отключённый код | — | — |
| YAGNI-02 | Нет dead code — неиспользуемых экспортов, функций, переменных | ❌ FAIL 🟢 | High | `package.json:75` — `@graphql-codegen/typescript` числится в devDependencies, но не используется. В `codegen.yml:7` явно сказано, что плагин намеренно убран из генерации, однако сам пакет остался в зависимостях. Knip подтверждает: единственная неиспользуемая зависимость | **1. Удалить пакет: `npm rm @graphql-codegen/typescript`** \\ 2. Оставить и убрать из knip-отчёта через `ignoreDependencies` с комментарием «зарезервирован на будущее» \\ 3. Вернуть плагин в `codegen.yml`, если duplicate-types больше не воспроизводится в актуальной версии | Нет |
| YAGNI-02 | Неиспользуемые экспорты/файлы (код) | ✅ PASS | High | Knip не нашёл ни одного неиспользуемого экспорта, файла, типа или namespace-члена в `src/`. Все env-поля (`VITE_OIDC_API_RESOURCE`, `VITE_BASE_URL`, `VITE_APP_VERSION`, `VITE_SENTRY_DSN`, `VITE_GRAPHQL_API_URL`) реально читаются вне `env.ts` | — | — |
| YAGNI-03 | Абстракции оправданы: интерфейс/фабрика имеет >1 реализации или требуется тестами | ✅ PASS | High | Паттернов Factory/Builder/Strategy/Repository в `src/` нет. Интерфейсы (`auth/model/types.ts` — `AuthUser`, `AuthStore`) — это контракты типов для zustand-стора, а не лишние абстракции. Демо-сущность `entities/counter` реально используется на главной (`pages/home/ui/index.tsx:146`), это часть витрины шаблона, а не мёртвый слой | — | — |
| YAGNI-04 | Feature flags не зафиксированы в одном значении | ✅ PASS | High | `VITE_MOCK_AUTH` читается из env (`shared/config/env.ts:38`) и реально ветвит логику провайдера (`app/providers/AppProviders.tsx:21` — `env.VITE_MOCK_AUTH === "true"`). Жёстко зашитых в коде флагов не обнаружено | — | — |
| YAGNI-05 | Технический долг актуален — нет заброшенных TODO/FIXME без даты или прогресса | ✅ PASS | High | Поиск `TODO/FIXME/XXX/HACK` по `src/**/*.{ts,tsx}` не дал совпадений | — | — |

## Итог

Проект почти эталонно чистый по YAGNI. Единственная находка — низкого уровня (🟢): лишний dev-пакет `@graphql-codegen/typescript`, оставшийся в `package.json` после намеренного отказа от плагина. Это не влияет на runtime, лишь немного увеличивает размер установки зависимостей. Архитектура FSD выдержана, абстракций «на вырост» нет, мёртвого и закомментированного кода нет.

## Audit Coverage
Проверено: `src/app/**`, `src/entities/**`, `src/features/**`, `src/pages/**`, `src/routes/**`, `src/shared/**`, `src/widgets/**`, `src/graphql/**`, `package.json`, `codegen.yml`, `knip.json`
Пропущено: `src/generated/**` (автогенерация), `tests/**`, `scripts/**`, `dist/**`, `node_modules/**`
Файлов проверено: 109 (.ts/.tsx) | Пропущено: автоген + тесты
