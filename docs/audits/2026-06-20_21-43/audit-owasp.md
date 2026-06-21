# Audit Report: OWASP Application Security — 2026-06-20 21:43

Проект — клиентский фронтенд (React 19 + TanStack Start SSR, OIDC через Logto,
GraphQL через urql). Своей базы данных и серверного хранилища паролей у него нет:
аутентификацию полностью ведёт внешний OIDC-провайдер (Logto), пароли там же.

## Осталось сделать (backlog)

| Check ID | Проверка | Sev | Доказательство | Решение (остаток) |
|----------|----------|-----|----------------|-------------------|
| OWA-05 | A05: Безопасная конфигурация сервера (security headers) | 🟠 | Безопасные заголовки (`Referrer-Policy`, `Permissions-Policy`, `Strict-Transport-Security`, `X-XSS-Protection`) уже добавлены в `vite.config.ts`. **Остаётся не закрыто:** нет строгого `Content-Security-Policy`, а access-токен лежит в `localStorage` (`src/features/auth/api/oidc-client.ts:30`) при наличии инлайн-скрипта в SSR-`<head>` (`src/routes/__root.tsx:53`) — без CSP любой XSS сразу читает токен. | **1. Добавить строгий `Content-Security-Policy` (`default-src 'self'`; для FOUC-/theme-скрипта использовать nonce/hash вместо unsafe-inline) в Nitro `routeRules["/**"].headers`.** \\ 2. Перенести access-токен из `localStorage` в memory/httpOnly-cookie, чтобы XSS не мог его прочитать. Оба пункта требуют отдельной проработки, чтобы не сломать SSR/инлайн-скрипт. |

## Требует ручной проверки

| Check ID | Проверка | Доказательство |
|----------|----------|----------------|
| OWA-03 | A01: Resource ownership проверяется, нет IDOR | Фронтенд запрашивает только «свои» данные: `me` без ID-параметра (`src/graphql/queries/me.graphql`), `updateProfile(input)` тоже без чужого ID (`src/features/profile/lib/useProfileForm.ts:76`). Прямого обращения к ресурсу по произвольному ID в коде нет. Фактическая проверка ownership — обязанность бэкенда и статически на фронтенде не подтверждается. `[⚡ dynamic]` |

## Замечания (вне чеклиста)

- **Уязвимые зависимости (`npm audit`).** `undici` — **high** CVE (TLS cert validation bypass, HTTP header/response injection, cache poisoning и др.); `@opentelemetry/core` + транзитивные — 3× **moderate** (unbounded memory в W3C Baggage). `undici` тянется транзитивно (через Nitro/server-стек), на SSR-сервере он используется для исходящих запросов. Рекомендуется `npm audit fix` / поднять версии.
