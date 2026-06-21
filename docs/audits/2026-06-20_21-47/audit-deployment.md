# Audit Report: Build & Deployment Configuration — 2026-06-20 21:47

> Невыполненная работа по аудиту сборки и деплоя. Закрытые/принятые находки удалены.

## Остаток (backlog)

| Check ID | Проверка | Sev | Доказательство | Решение |
|----------|----------|-----|----------------|---------|
| DEP-01 | Docker images используют pinned versions (нет :latest) | 🟡 | Прод-сервисы запинены, но админ-дашборды на `:latest`: `docker-compose.yml:109` `sosedoff/pgweb:latest`, `:123` `redis/redisinsight:latest`, `:139` `hibiken/asynqmon:latest` — непредсказуемые обновления при пересборке. | **1. Запинить дашборды на конкретные теги (напр. `sosedoff/pgweb:0.16.2`, `redis/redisinsight:2.70`, `hibiken/asynqmon:0.7.2`)** \\ 2. Использовать digest-pinning (`image@sha256:...`) для воспроизводимости. Отложено: нужны выверенные конкретные теги/digest; дашборды — dev-инструменты вне прод-пути данных. |
| DEP-12 | Read-only root filesystem | 🟡 | `docker-compose.yml` (1-181): ни у одного сервиса нет `read_only: true`. Distroless-образ `app` пишет только в named-volume `uploads:/app/data/uploads` (`:24`) — корень мог бы быть read-only с tmpfs для временных файлов, что снизило бы blast radius при компрометации. | **1. Для `app` добавить `read_only: true` + `tmpfs: /tmp` (бинарь пишет только в volume uploads)** \\ 2. Включить `read_only` поэтапно для stateless-сервисов (caddy, asynqmon), оставив stateful (db/redis) как есть. Отложено: требует проверки записи каждого сервиса + tmpfs; смягчено non-root + отсутствием публичных портов у дашбордов. |

## Требует ручной проверки

| Check ID | Проверка | Доказательство |
|----------|----------|----------------|
| DEP-09 | Корректный production-режим окружения | `NODE_ENV` неприменим (Go). Go-аналог — режим логирования/дебага. `.env.example:64` `OIDC_MOCK_ENABLED=true` помечен «never in production», но это dev-дефолт примера, а не прод-конфиг (реальный `.env` в VCS нет). Прод-значение режима в репозитории не зафиксировано — нет file:line ни для нарушения, ни для подтверждения; требует ручной проверки фактического prod-окружения. |
