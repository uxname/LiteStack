# Audit Report: Build & Deployment Configuration — 2026-06-20 21:47

Runtime проекта: **Go** (обнаружен `go.mod`). Чеклист DEP оптимизирован под Node.js, поэтому
Node-специфичные проверки (DEP-09 NODE_ENV, DEP-10 npm ci) переинтерпретированы под Go-эквиваленты
или помечены как неприменимые. Baseline (`docs/audit-baseline.yml`) отсутствует/пуст — ACCEPTED-статусов нет.

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| DEP-01 | Docker images используют pinned versions (нет :latest) | ❌ FAIL 🟡 | High | Прод-сервисы запинены: `Dockerfile:4` `golang:1.26-alpine`, `Dockerfile:23` `gcr.io/distroless/static-debian12:nonroot`, `docker-compose.yml:41` `postgres:18.1-alpine`, `:62` `redis:8.4-alpine`, `:153` `caddy:2-alpine`. Но админ-дашборды на `:latest`: `docker-compose.yml:109` `sosedoff/pgweb:latest`, `:123` `redis/redisinsight:latest`, `:139` `hibiken/asynqmon:latest` — непредсказуемые обновления при пересборке | **1. Запинить дашборды на конкретные теги (напр. `sosedoff/pgweb:0.16.2`, `redis/redisinsight:2.70`, `hibiken/asynqmon:0.7.2`)** \\ 2. Использовать digest-pinning (`image@sha256:...`) для воспроизводимости \\ 3. Оставить `:latest`, задокументировав, что дашборды — вспомогательные dev-инструменты, не часть прод-пути данных | Нет |
| DEP-02 | Контейнеры запускаются от непривилегированного пользователя | ✅ PASS | High | `Dockerfile:23` runtime-образ `distroless/...:nonroot` (uid 65532) + `Dockerfile:26` `--chown=65532:65532`; `Dockerfile.dbbackup:17` `USER postgres`. Прод-приложение и backup не от root. Готовые образы дашбордов не имеют явного `user:`, но порты не публикуются и доступ только через прокси — проверено | — | — |
| DEP-03 | Multi-stage build разделяет dev и prod зависимости | ✅ PASS | High | `Dockerfile:3-31` две стадии (`AS build` → distroless runtime), копируется только бинарь `/out/server` (`:25`); `Dockerfile.dbbackup:3-19` аналогично. Build-toolchain (golang+git) в финальный образ не попадает | — | — |
| DEP-04 | .dockerignore исключает мусор/секреты из контекста | ✅ PASS | High | `.dockerignore:1-15` исключает `.git`, `.github`, `.idea`, `.vscode`, `bin`, `dist`, `data`, `*.log` и явно `.env` (`:11`). Секреты в build context не попадают | — | — |
| DEP-05 | HEALTHCHECK определён | ✅ PASS | High | `Dockerfile:29-30` `HEALTHCHECK ... CMD ["/app/server", "-healthcheck"]`; реализация флага `cmd/server/main.go:30-67` (пробует `/health`, exit 0 при ok); продублировано в `docker-compose.yml:33-38`. У db/redis свои healthcheck (`:55`, `:74`) | — | — |
| DEP-06 | Секреты не hardcoded в Dockerfile ENV | ✅ PASS | High | В `Dockerfile` и `Dockerfile.dbbackup` нет `ENV`/`ARG` с секретами — только `ARG COMMIT`/`BUILD_TIME` (`Dockerfile:10-11`). Секреты подаются через `env_file: .env` в рантайме (`docker-compose.yml:16-17`), не вшиты в слои образа | — | — |
| DEP-07 | .env исключён из VCS | ✅ PASS | High | `git ls-files` не содержит `.env` (проверено, NOT tracked); `.gitignore:14` `.env` + `:15` `!.env.example`. Файл `.env` существует на диске, но не в репозитории | — | — |
| DEP-08 | .env.example документирует все переменные | ✅ PASS | High | `.env.example:1-65` покрывает PORT, CORS_ORIGIN, LOG_LEVEL, DATABASE_*, BACKUP_*, REDIS_*, *_PORT дашбордов, ADMIN_*, OIDC_*. Реальных секретов нет — только дефолты-плейсхолдеры (postgres/redis/admin). Совпадает с переменными, используемыми в `docker-compose.yml` | — | — |
| DEP-09 | Корректный production-режим окружения | 🔍 UNVERIFIED | Medium | `NODE_ENV` неприменим (Go). Go-аналог — режим логирования/дебага. `.env.example:64` `OIDC_MOCK_ENABLED=true` помечен «never in production», но это dev-дефолт примера, а не прод-конфиг (реальный `.env` в VCS нет). Прод-значение режима в репозитории не зафиксировано — нет file:line ни для нарушения, ни для подтверждения | — | — |
| DEP-10 | Детерминированная установка зависимостей | ✅ PASS | High | `npm ci` неприменим (Go). Go-аналог: `Dockerfile:7-8` копирует `go.mod`+`go.sum` и `go mod download`; `go.sum` присутствует в репозитории (проверено) — сборка детерминирована по checksum | — | — |
| DEP-11 | Ограничения ресурсов контейнера (CPU/Memory limits) | ❌ FAIL 🟠 | High | `docker-compose.yml` (весь файл, 1-181): ни один сервис не имеет `deploy.resources.limits`, `mem_limit` или `cpus`. Утечка памяти/CPU-spike в одном контейнере (напр. `db_studio` `:108` или `app` `:11`) может исчерпать ресурсы хоста и уронить все сервисы | **1. Добавить каждому сервису `deploy.resources.limits` (memory + cpus), напр. app: `memory: 512M, cpus: "1.0"`, db: `memory: 1G`** \\ 2. Задать глобальные `mem_limit`/`cpus` (Compose v2 non-swarm синтаксис) под каждый сервис \\ 3. Вынести лимиты на уровень оркестратора (systemd slice / cgroup) и задокументировать решение | Нет |
| DEP-12 | Read-only root filesystem | ❌ FAIL 🟡 | High | `docker-compose.yml` (1-181): ни у одного сервиса нет `read_only: true`. Distroless-образ `app` пишет только в named-volume `uploads:/app/data/uploads` (`:24`) — корень мог бы быть read-only с tmpfs для временных файлов, что снизило бы blast radius при компрометации | **1. Для `app` добавить `read_only: true` + `tmpfs: /tmp` (бинарь пишет только в volume uploads)** \\ 2. Включить `read_only` поэтапно для stateless-сервисов (caddy, asynqmon), оставив stateful (db/redis) как есть \\ 3. Оставить без read-only, задокументировав, что контейнеры уже non-root и порты не публикуются наружу | Нет |

## Дополнительные наблюдения (вне формального чеклиста, для контекста)

- **Привязка портов — хорошо.** Все публикуемые порты привязаны к loopback: `docker-compose.yml:22,50,70,161-163` используют `127.0.0.1:...`, а не `0.0.0.0`. Дашборды (pgweb/RedisInsight/Asynqmon) не публикуют host-порты вовсе — доступ только через Caddy Basic-Auth прокси (`admin_proxy`, `:152-170`) с bcrypt-хешем. Это сильная конфигурация.
- **`data_init`/chown volumes.** В текущем `docker-compose.yml` отдельного сервиса `data_init` нет; права на volume `uploads` обеспечиваются на этапе сборки через `--chown=65532:65532` (`Dockerfile:26`) — рабочий подход для named volume.
- **Логирование с ротацией** настроено глобально (`docker-compose.yml:1-5`, `max-size: 50m`, `max-file: 5`) — защищает от переполнения диска.
- **Caddyfile дефолтный bcrypt-хеш** (`Caddyfile:15`) — это дефолт «admin/admin» для dev; в проде переопределяется через `ADMIN_PASSWORD_HASH`. Не находка по чеклисту, но требует обязательной смены при деплое.

## Сводка FAIL

- 🔴 Critical: 0
- 🟠 High: 1 (DEP-11 — нет ограничений ресурсов)
- 🟡 Medium: 2 (DEP-01 — `:latest` на дашбордах; DEP-12 — нет read-only fs)
- 🟢 Low: 0

Решения обязательны только для 🔴/🟠 → требует действия **DEP-11**.

## Audit Coverage
Проверено: `Dockerfile`, `Dockerfile.dbbackup`, `.dockerignore`, `docker-compose.yml`, `Caddyfile`, `.env.example`, `.gitignore`, `cmd/server/main.go` (healthcheck), `go.sum` (наличие)
Пропущено: исходный код приложения (`internal/**`, `cmd/**` кроме healthcheck) — вне периметра deployment-аудита; CI/CD конфиги отсутствуют (`.github/workflows`, `.gitlab-ci.yml`, `Jenkinsfile` не найдены)
Файлов проверено: 9 | Пропущено: 0 (deployment-релевантных файлов вне периметра не обнаружено)
