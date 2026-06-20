# Audit Report: Boundary Data Validation — 2026-06-20 21:43

Runtime: Node.js / TypeScript (клиентский фронтенд). Стек: React 19, TanStack
Router/Start (SSR), react-hook-form + zod, urql (GraphQL), oidc-client-ts /
react-oidc-context. Baseline пустой.

Контекст оценки: это **клиентский фронтенд**. Настоящая граница доверия (trust
boundary) — на backend. Браузерная валидация здесь — это UX и защита от случайных
ошибок, а не финальный барьер безопасности. Поэтому severity нарушений, которые
backend всё равно обязан перепроверять, понижен относительно серверного кода.

## Результаты

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| VAL-01 | Все входящие данные (body, params, query) проходят schema-валидацию | ✅ PASS | High | Формы: `src/features/profile/lib/useProfileForm.ts:33` (`zodResolver(profileFormSchema)`). URL-параметры: `src/routes/callback.tsx:29` и `src/routes/account.tsx:59` — `validateSearch` приводит и фильтрует каждое поле. Ответ загрузки проверяется в `src/features/profile/api/upload-avatar.ts:33-37`. | — | — |
| VAL-02 | Строки имеют maxLength, числа — диапазон, enum-значения — whitelist | ✅ PASS | High | `src/features/profile/model/schema.ts:13,18,23` — `displayName` `.max(80)`, `bio` `.max(500)`, `avatarUrl` `.url().max(2048)` или пустая строка. `AccountAction` ограничен union-типом в `src/features/auth/lib/account-center.ts:8-14`. | — | — |
| VAL-03 | JSON.parse обёрнут в try/catch с последующей валидацией структуры | ✅ PASS | High | `src/routes/__root.tsx:33-39` — `JSON.parse` темы в try/catch; результат не используется вслепую, а пропускается через whitelist `if (theme === 'dark' || theme === 'cmyk')` перед записью в `dataset.theme`. Единственный `JSON.parse` в `src/`. | — | — |
| VAL-04 | Identity данные берутся из аутентифицированного контекста (не из user input) | ✅ PASS | High | `src/pages/account/ui/index.tsx:150` — `accessToken={auth.user?.access_token}` берётся из OIDC-контекста (`useAuth`), не из user input. В `useProfileForm.ts:62-74` в мутацию `updateProfile` кладутся только whitelisted поля (`displayName`/`bio`/`avatarUrl`); user-id / роли в payload не передаются — бэкенд берёт identity из Bearer-токена. | — | — |
| VAL-05 | Вложенные структуры и массивы ограничены (глубина, minItems/maxItems) | ✅ PASS | Medium | Схемы плоские (`schema.ts` — 3 скалярных поля, без массивов/рекурсии). Ответ `/upload` типизирован как `UploadedFile[]`, но используется только `files[0]` (`upload-avatar.ts:34`), без обхода всего массива — неограниченный размер массива не приводит к проблеме. Рекурсивных/глубоко вложенных схем нет. | — | — |
| VAL-06 | Валидатор не выполняет неявный coercion [⚡ dynamic] | 🔍 UNVERIFIED | High | В zod-схемах нет `.coerce.*`. В `validateSearch` приведение типов явное и безопасное (`typeof search.code === "string"` в `callback.tsx:30-32`; `=== true \|\| === "true"` в `account.tsx:61`). Динамическую проверку нельзя статически подтвердить как PASS по правилам скилла, но evidence нарушения тоже нет. | — | — |
| VAL-07 | Prototype pollution: merge/assign с user input фильтрует `__proto__`, `constructor`, `prototype` | ✅ PASS | High | Deep-merge / `Object.assign` / lodash.merge с user input в `src/` отсутствуют. Сборка `input` в `useProfileForm.ts:63-72` — присваивание фиксированных ключей литералу, без копирования произвольных ключей из user-объекта. | — | — |
| VAL-08 | Загрузка файлов: MIME проверяется по содержимому, имя санитизировано, размер ограничен | ❌ FAIL 🟡 | High | `src/features/profile/lib/useProfileForm.ts:47-54` берёт `event.target.files?.[0]` и сразу шлёт в `uploadAvatar` без проверки `file.size` и `file.type`. Атрибут `accept="image/png,..."` в `ProfileForm.tsx:52` — лишь подсказка диалога выбора, его легко обойти (drag&drop, изменённое расширение). Имя файла (`file.name`) в URL стройт **backend** (`upload-avatar.ts:39` использует возвращённый `uploaded.path`), path traversal на клиенте не формируется. Риск (на клиенте): загрузка огромного файла → лишний трафик/UX-зависание; не-картинка дойдёт до бэкенда. Реальный барьер — backend, поэтому 🟡, а не выше. | **1. Перед отправкой проверять `file.size` (например ≤ 5 МБ) и `file.type` по whitelist (`image/png\|jpeg\|gif\|webp`), показывать toast при несоответствии** \\ 2. Добавить отдельную zod-схему для `File` (size/type) и валидировать в `handleFileSelect` до `uploadAvatar` \\ 3. Оставить как есть, задокументировать что валидация загрузки полностью делегирована backend `/upload` (приемлемо только при подтверждённой серверной проверке MIME/размера) | Нет |

## Сводка

- 🔴 Critical: 0
- 🟠 High: 0
- 🟡 Medium: 1 (VAL-08)
- 🟢 Low: 0

Требуют решения (🔴/🟠): нет. VAL-08 — Medium, решение необязательно, но рекомендуется
ради UX и снижения нагрузки на backend.

## Audit Coverage
Проверено: src/features/profile/** (schema.ts, useProfileForm.ts, ProfileForm.tsx, api/upload-avatar.ts), src/features/auth/** (oidc-client.ts, MockAuthProvider.tsx, account-center.ts), src/routes/** (__root.tsx, callback.tsx, account.tsx, index.tsx), src/pages/account/**, src/shared/config/**
Пропущено: src/shared/ui/** (presentational), tests (*.test.ts), generated (@generated/**)
Файлов проверено: 12 | Пропущено (вне границы валидации): ~остальной UI-слой
