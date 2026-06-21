# Полный аудит бэкенда — 2026-06-20 21:47

**Объект:** `backend/` — Go-порт LiteEnd (GraphQL API + OIDC-аутентификация, загрузка файлов, фоновые очереди asynq, Postgres + Redis).

> Этот документ сокращён до **остатка работы**. Все исправленные (✅) и принятые (⚪) находки удалены; PER-04 и PER-05 сознательно откачены как over-engineering для MVP+ и backlog-ом не являются.
> Легенда: ⏳ осталось (backlog) · ◐ частично · 🔎 требует ручной проверки.

---

## ⏳ Backlog (осталось сделать)

| Check ID | Sev | Что осталось | Файл |
|----------|-----|--------------|------|
| PER-01b | 🟡 | Batch-вставка метаданных загрузок (до 10 отдельных INSERT в цикле) | `internal/upload/service.go:176-187` |
| MATRIX-DISK | 🟠 | Обработка ENOSPC: понятная ошибка + алерт по диску | `internal/upload/service.go:120-124` |
| API-03 | 🟡 | Единая модель ошибок REST/GraphQL (строковый `code` + `requestId` в REST) | `internal/httperr/httperr.go` |
| API-07 | 🟡 | Стратегия версионирования REST/GraphQL | `internal/app/app.go:135-139`, `internal/devtools/openapi.yaml:8` |
| API-01 | 🟢 | Единый success-конверт REST | `internal/health/health.go`, `internal/upload/handler.go` |
| OWA-04 | 🟡 | `sslmode=require` для БД в prod / убрать dev-дефолты admin/admin | `internal/config/config.go:47-48,57` |
| SEC-06 | 🟡 | Убрать дефолтный bcrypt-фоллбэк в Caddyfile (сейчас смягчён привязкой к 127.0.0.1) | `Caddyfile:15` |
| MATRIX-START | 🟠 | Ретраи зависимостей на старте (сейчас осознанный fail-fast) | `internal/app/app.go:48-83` |
| MATRIX-REDIS | 🟠 | Деградация при падении Redis (таймауты pub/sub, контроль очереди) | `internal/profile/pubsub.go:44-67`, `internal/queue/queue.go:66-80` |
| MATRIX-BACKUP | 🟠 | Offsite-копии + мониторинг свежести бэкапов | `internal/backup/backup.go:42-58`, `docker-compose.yml` |
| TST-02 | 🟠 | CI-гейт (`task test:cov` на каждый PR, нельзя обойти `--no-verify`) | `lefthook.yml:13`, CI отсутствует |
| DEP-01 | 🟡 | Пин версий образов дашбордов (pgweb/redisinsight/asynqmon на `:latest`) | `docker-compose.yml:109,123,139` |
| DEP-12 | 🟡 | Read-only root FS (+ tmpfs) для stateless-сервисов | `docker-compose.yml` |

**Итог backlog:** 13 находок — 🟠 5 · 🟡 6 · 🟢 2.

### Требует ручной проверки (🔎)

| Check ID | Что проверить | Файл |
|----------|---------------|------|
| OWA-09 | CSRF/CSWSH: при переходе на cookie-аутентификацию (вкл. WS `CheckOrigin: true`) появится риск | `internal/graph/handler.go` |
| VAL-06 | Неявный coercion в кастомных скалярах `URL`/`JSON`/`DateTime` (забинжены без своих unmarshal-проверок) | `gqlgen.yml` |
| DEP-09 | Фактический prod-режим окружения (`OIDC_MOCK_ENABLED` в реальном prod-`.env`) | `.env` (вне VCS) |
| TST-09 | Snapshot-политика — неприменима (Go, нет golden-файлов); проверка для полноты | — |

---

## Сводка остатка по компонентам

| Компонент | ⏳ 🟠 | ⏳ 🟡🟢 | Итого backlog |
|-----------|:---:|:---:|:---:|
| Загрузка файлов (PER-01b, MATRIX-DISK) | 1 | 1 | 2 |
| GraphQL/REST-контракты (API-01/03/07) | 0 | 3 | 3 |
| Конфигурация и секреты (OWA-04, SEC-06) | 0 | 2 | 2 |
| Устойчивость инфраструктуры (MATRIX-START/REDIS/BACKUP) | 3 | 0 | 3 |
| Тесты/деплой (TST-02, DEP-01, DEP-12) | 1 | 2 | 3 |
| **ИТОГО** | **5** | **8** | **13** |

---

## Приоритет (остаток)

1. **🟠 Устойчивость/эксплуатация:** ENOSPC на загрузке (MATRIX-DISK), деградация при падении Redis (MATRIX-REDIS), ретраи зависимостей на старте (MATRIX-START), offsite/мониторинг бэкапов (MATRIX-BACKUP), CI-гейт (TST-02).
2. **🟡 Бэклог:** `sslmode=require` + удаление dev-дефолтов admin/admin (OWA-04), bcrypt-фоллбэк в Caddyfile (SEC-06), единая модель ошибок REST/GraphQL (API-03), версионирование API (API-07), пин образов дашбордов (DEP-01), read-only FS (DEP-12), batch-вставка метаданных (PER-01b).
3. **🟢 По желанию:** единый success-конверт REST (API-01).

## Рекомендация по baseline
Осознанные trade-off'ы (fail-open rate-limit, WebSocket `CheckOrigin: true`, dev-дефолт admin/admin под привязкой к 127.0.0.1, откат PER-04/PER-05) стоит занести в `docs/audit-baseline.yml` с полями `type`/`expires`/`accepted_by`, чтобы при следующих прогонах они не всплывали как новые находки.
