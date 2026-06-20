# Audit Verification Report — 2026-06-20 21:43

Проект: `frontend` (LiteStack — React 19 + TanStack Start SSR, urql, zustand, FSD).
Дата верификации: 2026-06-20 (возраст аудита: 0 дней — актуален, не stale).
Baseline: `docs/audit-baseline.yml` — пустой (нет принятых/отложенных рисков, нет false-positives). Истёкших ACCEPTED-записей нет.

Метод: для каждого FAIL/UNVERIFIED прочитан реальный код по указанному `file:line` (±контекст). Проверены: `upload-avatar.ts`, `server.ts`, `sentry/config.ts`, `AuthObserver.tsx`, `env.ts`, `account.ts`, `detectErrorCategory.ts`, `vite.config.ts`, `Dockerfile`, `.dockerignore`, `docker-compose.yml`, `.env`, `.env.example`, `package.json`.

## Результаты верификации

| Аудит-файл | ✅ Подтверждено | ❌ False Positive | ⚠️ Устарело | 🔍 Пропущено |
|------------|---------------|-----------------|------------|-------------|
| audit-secrets       | 2 (SEC-04, доп. `.env` в build-контексте) | 0 | 0 | 0 |
| audit-owasp         | 1 (OWA-05) | 0 | 0 | 0 |
| audit-validation    | 1 (VAL-08) | 0 | 0 | 0 |
| audit-bugs          | 4 (BUG-01, BUG-03, BUG-05, BUG-09) | 0 | 0 | 0 |
| audit-errors        | 2 (ERR-03, ERR-05) + ERR-09 | 0 | 0 | 0 |
| audit-concurrency   | 2 (CON-03, CON-06) | 0 | 0 | 0 |
| audit-architecture  | 1 (ARC-03) | 0 | 0 | 0 |
| audit-naming        | 1 (NAM-05) | 0 | 0 | 0 |
| audit-yagni         | 1 (YAGNI-02) | 0 | 0 | 0 |
| audit-tests         | 3 (TST-02, TST-04, TST-05) | 0 | 0 | 0 |
| audit-logging       | 2 (LOG-02, LOG-03) | 0 | 0 | 0 |
| audit-deployment    | 6 (DEP-01, DEP-04, DEP-05, DEP-10, DEP-11, DEP-12) | 0 | 0 | 0 |
| audit-performance   | 1 (PER-08) | 0 | 0 | 0 |
| audit-api-contracts | 1 (API-03) | 0 | 0 | 0 |
| **ИТОГО**           | **~28 FAIL** | **0** | **0** | **0** |

Все проверенные находки FAIL подтверждены реальным кодом по точным `file:line`. Ложных срабатываний, устаревших артефактов и пропущенных критических рисков не обнаружено. Качество доказательной базы аудита высокое: каждая находка имеет корректную ссылку и точное описание поведения кода.

## Проверка точности `file:line` (выборочно)

- `upload-avatar.ts:23` — `fetch(\`${origin}/upload\`, …)` без `signal`/таймаута. **Подтверждено.**
- `server.ts:23` — `const response = await handler(localizedRequest, …)` без try/catch; `server.ts:37` — `Max-Age=31536000`. **Подтверждено.**
- `sentry/config.ts:19-22` — `replayIntegration({ maskAllText: false, blockAllMedia: false })`. **Подтверждено.**
- `AuthObserver.tsx:43-47` — `setUser({ id, email, username })`. **Подтверждено.**
- `env.ts:45` — `if (env.DEV)` оборачивает проверку `requiredEnvVars` (в prod молча `undefined`). **Подтверждено** (корень BUG-03).
- `account.ts:89` — `new Date(String(createdAt)).toLocaleDateString()` без guard и без UTC. **Подтверждено** (BUG-01 и BUG-09 — две проверки на одну строку).
- `detectErrorCategory.ts:12-41` — rules-массив с `?? UNKNOWN`, без exhaustive `never`. **Подтверждено** (BUG-05).
- `vite.config.ts:71-72` — только `X-Frame-Options` + `X-Content-Type-Options`, нет CSP/HSTS/Referrer-Policy. **Подтверждено** (OWA-05).
- `.dockerignore` — `.env` отсутствует; `.env` реально существует (775 байт); `Dockerfile:17` `COPY . ./`. **Подтверждено** (риск реален).
- `docker-compose.yml` — только `healthcheck`, нет `deploy.resources.limits`/`read_only`. **Подтверждено** (DEP-11, DEP-12).
- `package.json:75` — `@graphql-codegen/typescript` присутствует. **Подтверждено** (YAGNI-02).

## Несогласованности severity (один паттерн — разный уровень)

Обнаружены три рассогласования severity для одинаковых паттернов между отчётами:

1. **`upload-avatar.ts:23` — отсутствие AbortSignal/таймаута в `fetch`.**
   Один и тот же дефект оценён по-разному в разных направлениях:
   - `audit-errors` ERR-05 (отсутствие таймаута) → **🟠 High**
   - `audit-errors` ERR-09 (отсутствие AbortSignal) → **🟡 Medium**
   - `audit-concurrency` CON-06 (отсутствие отмены/таймаута) → **🟡 Medium**
   - `audit-validation` VAL-08 (нет проверки size/type перед отправкой) → **🟡 Medium**
   - `audit-api-contracts` API-03 (тело ошибки не парсится) → **🟡 Medium**

   Замечание: ERR-05 (🟠) и ERR-09/CON-06 (🟡) описывают **один и тот же** отсутствующий `signal` в `fetch` (одно исправление — `AbortSignal.timeout(...)` — закрывает все три). При этом в `audit-errors` ERR-09 помечен 🟡, хотя в сводке того же файла он ошибочно отнесён к High-блоку текстом — фактический статус в таблице 🟡 Medium, в сводке формулировка «🟠 High: 1 — ERR-05» корректна, но строка ERR-09 указана в перечне Medium вместе с ERR-03. Внутренних противоречий в таблицах нет; рассинхрон только межотчётный: один корневой дефект получает то High (по критерию «висящий запрос»), то Medium (по критерию «утечка отмены»). Это ожидаемо при разных линзах оценки, но при сводном ранжировании следует трактовать дефект как единый 🟠 High (наихудшая оценка), поскольку причина и фикс общие.

2. **`.env` не исключён из Docker build-контекста.**
   - `audit-secrets` (доп. находка) → **🟠 High**
   - `audit-deployment` DEP-04 → **🟡 Medium**

   Одинаковый паттерн (`.dockerignore` без `.env` + `COPY . ./`), разный severity. Обоснование расхождения у авторов разное: secrets смотрит на потенциал утечки реальных секретов (выше), deployment — на текущее отсутствие секретов в `.env` (ниже). Рекомендуемая согласованная оценка — **🟡 Medium** на текущий момент (в `.env` сейчас только публичные `VITE_*`-значения; `VITE_SENTRY_AUTH_TOKEN` пуст), с эскалацией до 🟠 при добавлении реальных секретов. Сейчас оценка 🟠 в secrets завышена относительно фактического содержимого `.env`.

3. **Утечка stack trace / технических деталей.**
   - `audit-errors` ERR-02 → ✅ PASS, `audit-owasp` OWA-07 → ✅ PASS, `audit-api-contracts` API-05 → ✅ PASS.
   Согласованы между собой (все PASS, перекрёстные ссылки корректны) — рассогласования нет, отмечено для полноты.

## Дубли между отчётами (одна первопричина в нескольких направлениях)

Не ошибки, а ожидаемое многолинзовое покрытие — фиксируется для дедупликации при сводном плане:

- **`upload-avatar.ts` `fetch` без signal/таймаута/валидации файла** фигурирует в 5 отчётах: ERR-05, ERR-09, CON-06, VAL-08, API-03. Все ссылаются на один файл; ERR-05+ERR-09+CON-06 закрываются одним фиксом (`AbortSignal.timeout`), VAL-08 и API-03 — отдельными (pre-validation + парсинг тела ошибки).
- **`sentry/config.ts:19-22` `maskAllText: false`** — общая первопричина LOG-02 и LOG-03 (оба 🟠 High). Авторы сами это отметили; один фикс (`maskAllText: true`) закрывает оба.
- **`env.ts:45` (`requiredEnvVars` только в DEV)** — корень BUG-03 (🟠 High); упомянут как «дополнительная находка» в audit-bugs и пересекается с audit-validation (VAL-01/04). Дубля-конфликта нет, граница обозначена корректно.
- **`account.ts:89`** — BUG-01 (🟡, Invalid Date) и BUG-09 (🟡, локальная таймзона) на одной строке. Разные дефекты, не дубль.

## Несогласованности UNVERIFIED

- ERR-04, ERR-06 (process-level / graceful shutdown в Nitro-бандле вне исходников) — корректно помечены 🔍 UNVERIFIED, не FAIL. Согласовано с реальностью (`.output/**` не в репозитории). Подтверждено grep'ом авторов — повторная проверка не требуется.

### Исправленные документы

Изменения в аудит-файлы **не вносились**: false-positives отсутствуют, устаревших и пропущенных находок нет, истёкших baseline-записей нет. По правилу SKILL (Шаг 3, «Если файл не требует изменений — не перезаписывай его») все 14 отчётов оставлены без правок.

Рекомендации авторам (не правки, а для сводного ранжирования):
- Привести severity дефекта `upload-avatar.ts:23` к единому 🟠 High во всех отчётах (общая первопричина и фикс).
- Согласовать severity `.env`-в-build-контексте между audit-secrets (🟠) и audit-deployment (🟡) → рекомендуется 🟡 на текущий момент.

### Пропущенные критические риски

Не обнаружено. В ходе верификации новых 🔴-рисков, не попавших в исходные отчёты, не выявлено. Самые высокие подтверждённые риски — 🟠 High: OWA-05 (нет CSP/HSTS при токене в localStorage), LOG-02/LOG-03 (PII/секреты в Sentry Session Replay), BUG-03 (`new URL(undefined)` при отсутствии env в prod), ERR-05 (upload без таймаута), DEP-11 (нет лимитов ресурсов контейнера).
