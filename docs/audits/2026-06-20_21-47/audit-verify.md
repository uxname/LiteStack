# Audit Verification Report — 2026-06-20 22:10

Свежесть аудита: 0 дней (не устарел, лимит 30).
Baseline: `docs/audit-baseline.yml` = `accepted: []` (пуст) — истёкших ACCEPTED-исключений нет.

Проверены все находки FAIL из 15 аудит-отчётов: каждая открыта по указанным
файлам/строкам и сверена с реальным кодом. Все FAIL подтверждены реальным кодом.
False positives не обнаружено. Пропущенных критических рисков не найдено.

## Результаты верификации

| Аудит-файл | ✅ Подтверждено | ❌ False Positive | ⚠️ Устарело | 🔍 Пропущено |
|------------|---------------|-----------------|------------|-------------|
| audit-secrets | 2 | 0 | 0 | 0 |
| audit-owasp | 2 | 0 | 0 | 0 |
| audit-validation | 2 | 0 | 0 | 0 |
| audit-bugs | 1 | 0 | 0 | 0 |
| audit-errors | 2 | 0 | 0 | 0 |
| audit-concurrency | 1 | 0 | 0 | 0 |
| audit-architecture | 1 | 0 | 0 | 0 |
| audit-naming | 1 | 0 | 0 | 0 |
| audit-yagni | 0 | 0 | 0 | 0 |
| audit-tests | 2 | 0 | 0 | 0 |
| audit-logging | 3 | 0 | 0 | 0 |
| audit-performance | 4 | 0 | 0 | 0 |
| audit-deployment | 3 | 0 | 0 | 0 |
| audit-api-contracts | 4 | 0 | 0 | 0 |
| audit-matrix | — (производный) | 0 | 0 | 0 |
| **ИТОГО** | **30** | **0** | **0** | **0** |

(`audit-matrix` — производная модель сбоев на основе тех же находок;
отдельных file:line-находок FAIL не вводит, поэтому не считается отдельно.)

## Подтверждённые ключевые находки (по заданию)

- **BUG-02 / CON-06 — `internal/upload/service.go:229-261` (writeFile).** ПОДТВЕРЖДЕНО.
  `defer f.Close()` (стр. 234) срабатывает при возврате `writeFile`. На ветке
  `<-ctx.Done()` (стр. 253) функция выходит сразу, пока горутина продолжает
  `io.Copy(f, body)` (стр. 249) уже в закрытый дескриптор. Горутина и reader тела
  живут до разблокировки `body`. Вызывающий `saveOne` (стр. 122) делает
  `os.Remove(fullPath)`, но это не отменяет горутину — утечка реальна.

- **OWA-05 — CORS «разрешить всё».** ПОДТВЕРЖДЕНО. `config.go:18` `CORSOrigin`
  без дефолта; `server.go:45` `AllowedOrigins: cfg.CORSOrigin` + `AllowCredentials: true`
  (стр. 48). При пустом `CORS_ORIGIN` go-chi/cors включает allow-all.

- **ERR-02 / API-05 — утечка `err.Error()`.** ПОДТВЕРЖДЕНО в двух местах:
  `health.go:86` `Error: err.Error()` на публичном `/health` (без авторизации,
  `app.go:135`); `graph/errors.go:36-41` — ветка `default` отдаёт сырой текст,
  prod-маскировки нет, ошибки БД заворачиваются дословно (`profile/service.go:160`).

- **LOG-02 / LOG-03 — нерекурсивная редакция + PII.** ПОДТВЕРЖДЕНО.
  `graph/logging.go:57-69` `redactVariables` обходит только верхний уровень map;
  `displayName`/`bio` под `input` логируются открыто (стр. 50). `logger.go:47-52`
  `redactSensitive` матчит только ключ атрибута, не вложенные значения.

- **statement_timeout в пуле БД — `internal/db/pool.go:28-30`.** ПОДТВЕРЖДЕНО как
  наблюдение (НЕ FAIL): заданы только `MaxConns/MaxConnIdleTime/ConnectTimeout`,
  нет общего statement/query timeout, `MinConns`, `MaxConnLifetime`. В отчётах это
  корректно помечено как 🟡/🟢 замечание (audit-errors ERR-05 note, audit-performance
  note), а не как отдельный FAIL — классификация верна.

- **PER-04 — `ReadMemStats` на `/health`.** ПОДТВЕРЖДЕНО. `health.go:91-93`
  `runtime.ReadMemStats` (stop-the-world) вызывается на каждый запрос к `/health`
  через `memoryCheck()` (стр. 57). PER-05 (последовательные db/redis/memory ping,
  стр. 54-58) также подтверждён.

## Прочие подтверждённые FAIL (выборка)

- SEC-04 (`.env.example:45` реальный bcrypt-хеш), SEC-06 (`Caddyfile:15`
  bcrypt-фоллбэк admin/admin) — подтверждены; смягчение портами `127.0.0.1`
  (`docker-compose.yml:161-163`) реально присутствует.
- OWA-04 (`config.go:57` `sslmode=disable`; admin/admin дефолты стр. 47-48) — подтверждено.
- VAL-02 (нет maxLength на displayName/bio/avatarUrl `schema.graphqls:39-46`;
  `URL → graphql.String` `gqlgen.yml:29-30`; колонки TEXT без CHECK
  `00001_init.sql:13-15`) — подтверждено.
- VAL-05 (нет complexity/depth-лимита, интроспекция включена `graph/handler.go`) — подтверждено.
- ERR-08 (`migrate.go:46` `delay *= 2` без jitter) — подтверждено.
- ARC-05 (`cmd/server/main.go:44-46` `os.Getenv("PORT")` + дефолт `"4000"`) — подтверждено.
- NAM-05 (`health.go:51` и `main.go:48` inline `5*time.Second`; `handler.go:50,52`
  `lru.New(1000)`/`lru.New(100)`) — подтверждено.
- TST-02 (CI-конфигов нет; гейт только в `lefthook.yml` pre-push) — подтверждено.
- TST-08 (`integration_test.go:205` `time.Sleep(300ms)`) — подтверждено.
- PER-01b (`service.go:176-187` `CreateUpload` в цикле) — подтверждено.
- DEP-01 (дашборды на `:latest`, стр. 109/123/139), DEP-11 (нет resource limits),
  DEP-12 (нет `read_only`) — подтверждены grep'ом по `docker-compose.yml`.
- API-01/API-03/API-07 (формы ответов, машиночитаемость, версионирование) — подтверждены.

## Исправленные документы

- `audit-validation.md` — исправлена устаревшая ссылка на строку в VAL-02:
  `internal/profile/service.go:239-253` → `:152-166` (файл всего 199 строк;
  метод `Update` реально на стр. 152-166). Сама находка верна, исправлена только
  неточность номера строки. False positive НЕ удалялся.

Остальные 14 отчётов изменений не потребовали — все ссылки file:line точны.

## Пропущенные критические риски

Не обнаружено. Дополнительно проверены пограничные места (WebSocket
`CheckOrigin: true` при токен-аутентификации, orphan-файл после таймаута загрузки,
нормализация ролей в mock-режиме) — все уже корректно зафиксированы в отчётах
как наблюдения/UNVERIFIED с верной классификацией. Новых 🔴-рисков нет.
