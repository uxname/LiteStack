# Матрица — LiteStack frontend — 2026-06-20

> Оставлены только сценарии с невыполненной работой (backlog) и сценарии, требующие ручной проверки. Закрытые/принятые сценарии и 🟢-сценарии (защита уже есть) удалены.

## Компоненты системы (затронутые остатком)

| # | Компонент | Роль | Где |
|---|-----------|------|-----|
| 2 | **Profile + Avatar** | форма профиля, REST-загрузка аватара, мутация updateProfile | `src/features/profile/api/upload-avatar.ts`, `src/features/profile/lib/useProfileForm.ts` |
| 4 | **SSR-сервер** | рендер HTML, резолв локали, Set-Cookie | `src/server.ts` (прод-сервер — Nitro-бандл в `.output/`) |
| 5 | **UI/роутинг** | TanStack Router, страницы, guard, токен в localStorage | `vite.config.ts`, `src/features/auth/api/oidc-client.ts` |

---

## Осталось сделать (backlog)

| # / ID | В чём опасность | Компонент | Риск | Решение |
|--------|-----------------|-----------|------|---------|
| #2 / E1 (OWA-05) | Нет строгого CSP, а access-токен лежит в `localStorage` и в `<head>` есть инлайн-скрипт → при любом XSS чужой скрипт сразу читает токен. Безопасные заголовки (Referrer-Policy/Permissions-Policy/HSTS/X-XSS) уже добавлены; CSP и перенос токена — остаток. | UI/конфиг | 🟠 | Добавить строгий `Content-Security-Policy` (nonce/hash для инлайн-скрипта темы) в Nitro `routeRules["/**"].headers` + перенести токен из `localStorage` в memory/httpOnly-cookie. Файл: `vite.config.ts:71`. |
| B2 (CON-06) | Аплоад аватара уже имеет таймаут (`AbortSignal.timeout(30000)`), но не имеет внешней отмены: при уходе со страницы/смене файла запрос не отменяется → `setValue("avatarUrl", url)` может выполниться на размонтированной форме (предупреждение React, запись stale-URL). | Profile | 🟡 | Передать внешний `AbortController` в `uploadAvatar` и звать `abort()` в cleanup-эффекте; скомбинировать с таймаут-сигналом через `AbortSignal.any([...])`. Файл: `src/features/profile/lib/useProfileForm.ts:54`. |

---

## Требует ручной проверки

| # / ID | Сценарий | Доказательство |
|--------|----------|----------------|
| CON-05 | Идемпотентность OIDC-callback | Обмен code→token и защита от повторного `code`/`state` делегированы `react-oidc-context`/`oidc-client-ts` — внешний код, статически не подтверждается. |
| OWA-03 | Resource ownership / IDOR | Фронт шлёт только «свои» запросы (`me`, `updateProfile` без чужого ID); ownership — зона бэкенда, статически на фронте не подтверждается. |
| D2 (ERR-04 / ERR-06) | Падение/перезапуск процесса (SIGTERM, unhandled rejection) | В app-коде нет `process.on('SIGTERM'/'uncaughtException')`; обработка лежит в сгенерированном Nitro-бандле (`.output/`, вне исходников). Сервер stateless → graceful drain менее критичен. **Проверить** поведение Nitro-пресета `node-server` на SIGTERM/unhandled rejection; при необходимости добавить process-обработчики в кастомную точку входа. |

---

## Замечания (вне severity-таблиц)
- **Уязвимые транзитивные зависимости** (из audit-owasp): `undici` — high CVE (используется SSR-сервером для исходящих запросов), `@opentelemetry/core` — 3× moderate. Рекомендуется поднять версии.
