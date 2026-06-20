# Audit Meta Report — 2026-06-20 22:15

Мета-контроль качества аудита Go-бэкенда (`liteend-go`, `/home/dex/Документы/Work/LiteStack/backend`).
Проверяется не код, а сам аудит: всё ли покрыто, нет ли протухших исключений, достаточно ли доказательств.

Входные данные:
- Папка сессии: `docs/audits/2026-06-20_21-47/` — 16 отчётов (15 тематических + `audit-meta` этот файл, плюс `audit-verify`).
- Baseline: `docs/audit-baseline.yml` = `accepted: []` (пуст).
- Кодовая база: 45 рукописных Go-файлов (без тестов) + 16 тестовых файлов.

## Scope Coverage

Кодовая база — Go (стандартного `src/` нет; исходники в `internal/**` и `cmd/**`). Сверка проводилась по фактическим директориям проекта.

Сводка: какие модули в каких отчётах упомянуты с привязкой к коду.

| Модуль | Где покрыт (тематические аудиты) | Статус |
|--------|----------------------------------|--------|
| `internal/auth/**` | secrets, owasp, validation, bugs, errors, concurrency, logging, naming, matrix | покрыт глубоко |
| `internal/upload/**` | bugs, validation, concurrency, performance, owasp, logging, matrix | покрыт глубоко |
| `internal/queue/**` | errors, concurrency, bugs, tests, logging, matrix | покрыт глубоко |
| `internal/db/**` (pool, migrate, sqlc) | errors, owasp, performance, validation, matrix | покрыт глубоко |
| `internal/config/**` | secrets, owasp, validation, architecture, yagni, naming | покрыт глубоко |
| `internal/graph/**` | owasp, api-contracts, errors, logging, validation, concurrency | покрыт глубоко |
| `internal/profile/**` | concurrency, performance, validation, bugs, logging, matrix | покрыт глубоко |
| `internal/backup/**` | bugs, errors, logging, tests (заметка о 0% покрытия), matrix | покрыт |
| `internal/middleware/**` | owasp, errors, concurrency, logging, naming | покрыт глубоко |
| `internal/health/**` | errors (ERR-02), performance (PER-04/05), api-contracts, architecture | покрыт |
| `internal/redis/**` | errors, concurrency, performance, matrix | покрыт |
| `internal/server/**` | owasp, errors, performance, architecture | покрыт |
| `internal/app/**` | owasp, errors, architecture, api-contracts | покрыт |
| `internal/logger/**` | logging, architecture, concurrency, naming | покрыт |
| `internal/httperr/**` | errors, owasp, api-contracts, naming | покрыт |
| `internal/i18n/**` | owasp, errors, architecture, naming, logging, tests | покрыт (поверхностно) |
| `internal/devtools/**` | architecture, naming, yagni, tests, owasp, api-contracts | покрыт |
| `internal/version/**` | naming, architecture | покрыт (поверхностно) |
| `cmd/**` (server, dbbackup, dbrestore) | secrets, errors, deployment, logging, naming, architecture | покрыт |

### Все критические компоненты охвачены

Девять критических компонентов из задания подтверждены явно (каждый — с file:line хотя бы в одном отчёте, большинство — в нескольких):

- **auth** — `internal/auth/{middleware,verifier,context}.go` (проверка токена, роли, mock-режим)
- **upload** — `internal/upload/{handler,service}.go` (MIME, path-traversal, лимиты, таймаут)
- **queue** — `internal/queue/queue.go` (дедуп, ретраи, recover)
- **db** — `internal/db/{pool,migrate}.go` + `sqlc/**` (таймауты, statement_timeout, параметризация)
- **config** — `internal/config/{config,constants}.go` (env, required, дефолты)
- **graph** — `internal/graph/{handler,errors,logging}.go` + resolver (CORS, маскировка ошибок, complexity)
- **profile** — `internal/profile/{service,pubsub}.go` (кэш, гонка find-or-create, подписки)
- **backup** — `internal/backup/backup.go` (ротация, TryLock, exec.CommandContext)
- **middleware** — `internal/middleware/{ratelimit,basicauth,recover,secure,...}.go` (лимит, заголовки, recover)

Дополнительно покрыты вспомогательные: health, redis, server, app, logger, httperr, i18n, devtools, version, cmd.

✅ Scope: все модули проверены. Непокрытых директорий нет.

Замечание (не пробел): `internal/version/**` упомянут только в naming и architecture — это нормально, пакет содержит лишь build-метаданные и не несёт логики/рисков. Сгенерированный код (`internal/graph/generated/**`, `internal/graph/model/models_gen.go`, `internal/db/sqlc/*.sql.go`) намеренно исключён всеми отчётами — корректное и единообразное решение.

## Baseline Expiry

`docs/audit-baseline.yml` = `accepted: []` — записей нет, поле `expires` отсутствует в принципе.

✅ Baseline: все исключения актуальны (исключений нет, истекать нечему).

## Evidence Quality

Проверены все строки `❌ FAIL` во всех 15 тематических отчётах (30 находок FAIL по сводке `audit-verify`). Качество доказательств оценивалось по двум критериям: есть ли `файл:строка` и есть ли конкретный код/значение, а не только имя файла.

Результат: **все 30 находок FAIL подкреплены конкретными ссылками `файл:строка` и приводят сам код/значение/литерал.** Примеры:

- SEC-04 — `.env.example:45` с приведением реального bcrypt-хеша.
- OWA-05 — `config.go:18`, `server.go:45,48` + цитата поведения `go-chi/cors` (`cors.go:131-134`).
- BUG-02 / CON-06 — `upload/service.go:229-261` с разбором строк 234/249/253-254.
- ERR-02 / API-05 — `health.go:86`, `graph/errors.go:36-41`, `profile/service.go:160`.
- LOG-02 / LOG-03 — `graph/logging.go:50,57-70`, `logger.go:47-52` + тест-доказательство `logging_test.go:21`.
- PER-04 — `health.go:91-93`; DEP-11/DEP-12 — конкретные сервисы в `docker-compose.yml`.

Находки со статусом `🔍 UNVERIFIED` (VAL-06, BUG-04, BUG-05, CON-05, TST-09, DEP-09, OWA-09) честно помечены и не выдаются за FAIL — это корректная классификация `[⚡ dynamic]`, а не слабое доказательство.

✅ Evidence: все FAIL подкреплены доказательствами `файл:строка` с конкретным кодом.

### Находки с недостаточными доказательствами

Не обнаружено.

Единственная замеченная неточность номера строки (VAL-02: `service.go:239-253` → `:152-166`) уже исправлена на этапе `audit-verify` (см. раздел «Исправленные документы» в `audit-verify.md`); сама находка верна.

## False Positive Suppression Audit

Baseline пуст, записей без поля `type` нет.

✅ Baseline Types: нечего классифицировать (0 записей).

Рекомендация на будущее: когда команда начнёт принимать риски (например, осознанный fail-open у rate-limit или WebSocket `CheckOrigin: true`), заносить их в baseline **с обязательным полем `type`** (`accepted-risk` / `false-positive` / `intentional-design`), полем `expires` и `accepted_by`. Сейчас эти осознанные решения живут только как заметки в отчётах, а не как формальные исключения — это нормально для первого прогона, но при повторных аудитах их стоит зафиксировать в baseline, чтобы они не всплывали каждый раз как новые находки.

## Итог

| Проверка | Статус |
|----------|--------|
| Scope Coverage | ✅ все модули покрыты (9/9 критических + вспомогательные) |
| Baseline Expiry | ✅ истёкших нет (baseline пуст) |
| Evidence Quality | ✅ все 30 FAIL с file:line и конкретным кодом |
| Baseline Types | ✅ нет записей для классификации |

**Общая оценка качества аудита: высокая.**

Сильные стороны:
- Полное покрытие кодовой базы: ни одной непокрытой директории; все 9 критических компонентов разобраны несколькими аудитами с разных ракурсов.
- Образцовое качество доказательств: каждая находка привязана к `файл:строка` и приводит сам код/значение; инструментальные подтверждения (go-arch-lint, deadcode, gitleaks, golangci-lint) указаны там, где применимы.
- Корректная классификация: `UNVERIFIED`/`[⚡ dynamic]` не маскируются под FAIL; severity расставлены адекватно (0 Critical среди отдельных находок, единственный 🔴 — каскадный сценарий в `audit-matrix`: исчерпание пула БД из-за отсутствия `statement_timeout`, `internal/db/pool.go:28`).
- Этап `audit-verify` реально отработал: 30/30 FAIL подтверждены по коду, 0 false positives, одна неточность строки исправлена.

Зоны внимания (не дефекты аудита, а рекомендации):
- Главные подтверждённые риски для исправления в первую очередь: отсутствие `statement_timeout` на пуле БД (каскадный 🔴), CORS allow-all при пустом `CORS_ORIGIN` + `AllowCredentials:true` (OWA-05, 🟠), утечка `err.Error()` в `/health` и GraphQL без prod-маскировки (ERR-02/API-05, 🟠), нерекурсивная редакция логов + PII в `displayName`/`bio` (LOG-02/LOG-03, 🟠), отсутствие resource limits в compose (DEP-11, 🟠).
- При следующем прогоне завести осознанные trade-off'ы (rate-limit fail-open, WS CheckOrigin, дефолт admin/admin для dev) в `audit-baseline.yml` с полями `type`/`expires`/`accepted_by`, чтобы не пересматривать их каждый раз.

Пробелов в покрытии аудита не выявлено.
