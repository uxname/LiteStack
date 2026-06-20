# Audit Report: Resource & Performance — 2026-06-20 21:47

Runtime: **Go 1.26** (gqlgen GraphQL, pgx/pgxpool + sqlc, Redis go-redis, asynq, chi).
Чеклист оптимизирован под Node.js, поэтому проверки адаптированы под Go: вместо `AbortSignal` —
`context.Context`, вместо `process.on` — обработчики сигналов, вместо event loop blocking —
блокировка горутины / stop-the-world паузы рантайма.

Baseline (`docs/audit-baseline.yml`): пуст (`accepted: []`) — записей о принятых исключениях нет.

## Результаты

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| PER-01 | Нет N+1: DB-запросы не выполняются внутри циклов | ✅ PASS | High | В GraphQL-схеме (`internal/graph/schema.graphqls`) нет ни одного списочного запроса/поля-коллекции с дочерней выборкой: только `me`, `debug`, `echo`, `testTranslation` и мутации. Все резолверы (`internal/graph/resolver/schema.resolvers.go`) делают максимум один точечный запрос. DataLoader не нужен, т.к. нет batch-точек. Цикл в `upload/service.go:176` (SaveMetadata) — см. PER-01b ниже. | — [⚡ dynamic] | — |
| PER-01b | N+1 при вставке метаданных загрузок | ❌ FAIL 🟡 | High | `internal/upload/service.go:176-187` — `for _, f := range files { s.q.CreateUpload(...) }`: до `UploadMaxFiles=10` отдельных INSERT в цикле вместо batch-вставки. | **1. Заменить на один batch-INSERT (sqlc `:copyfrom` или `INSERT ... VALUES (...),(...)` с pgx.Batch)** \\ 2. Обернуть цикл в одну транзакцию (`pool.Begin`/`tx.Commit`), чтобы убрать межзапросные round-trip накладные \\ 3. Оставить как есть и задокументировать: максимум 10 строк за запрос, нагрузка пренебрежимо мала | Нет |
| PER-02 | Выборки из БД ограничены (LIMIT, пагинация) | ✅ PASS | High | Все SELECT в `internal/db/sqlc/profile.sql.go` и `upload.sql.go` — это `:one` по уникальному ключу (`WHERE oidc_sub = $1` / `WHERE id = $1` / `WHERE filepath = $1`) либо `count(*)`. Списочных выборок без LIMIT нет вовсе. `count(*)` (`CountProfiles`) вызывается только из ADMIN-only `debug`. | — | — |
| PER-03 | Обработчики запросов не содержат блокирующего I/O | ✅ PASS | High | Загрузка файлов стримится через `io.Copy` в горутине с `select { ctx.Done() / done }` (`upload/service.go:229-261`) — нет `ReadFile`/`ReadAll` всего тела в память; ограничение размера через `io.LimitReader` (`handler.go:62`). Отдача файлов — `http.ServeFile` (`handler.go:116`). Синхронных `os.ReadFile`/busy-wait в хендлерах не найдено. | — | — |
| PER-04 | CPU-интенсивные операции вынесены из main thread | ❌ FAIL 🟡 | High | `internal/health/health.go:91-93` — `runtime.ReadMemStats(&m)` вызывается на КАЖДЫЙ запрос к `GET /health`. `ReadMemStats` останавливает мир (stop-the-world): пауза всех горутин на время сбора статистики. Health-эндпоинт обычно опрашивается часто (k8s/LB liveness/readiness каждые несколько секунд), поэтому периодические STW-паузы бьют по латентности всего сервиса. То же — в ADMIN-only `debug` (`schema.resolvers.go:102`), но там частота низкая. | **1. Кэшировать показатели памяти: фоновая горутина обновляет их раз в N секунд (`time.NewTicker`), хендлер читает atomically — STW отвязан от частоты запросов** \\ 2. Убрать `memory` из публичного `/health` (оставить только db/redis ping), а память отдавать отдельным редким админ-эндпоинтом \\ 3. Оставить, но защитить `/health` от частого внешнего опроса (внутренний порт/частота проверки >= 10s) и задокументировать | Нет |
| PER-05 | Независимые async-операции выполняются параллельно | ❌ FAIL 🟢 | High | `internal/health/health.go:54-58` — проверки `database` (ping), `redis` (ping) и `memory` выполняются последовательно. Db-ping и redis-ping независимы и сетевые — могли бы идти параллельно через горутины; при медленном одном из них суммарная латентность `/health` = сумма, а не максимум. | **1. Запускать оба ping в горутинах и собирать через `sync.WaitGroup`/каналы — латентность = max, а не sum** \\ 2. Использовать `errgroup.Group` для параллельного запуска проверок \\ 3. Оставить: два быстрых ping с общим таймаутом 5s, выигрыш мал | Нет |
| PER-06 | Кэши ограничены по размеру и времени жизни (TTL + size limit) | ✅ PASS | High | Кэш профилей — в Redis с TTL: `cache.SetString(..., config.ProfileCacheTTL)` где `ProfileCacheTTL = time.Hour` (`config/constants.go:52`, `profile/service.go:192`). Инвалидация при обновлении: `Update` вызывает `invalidate` + `toCache` (`service.go:163-164`). Размер ограничен политикой вытеснения Redis (внешний процесс), in-memory unbounded-кэшей в коде нет. | — | — |
| PER-07 | Event listeners и subscriptions очищаются при завершении | ✅ PASS | High | GraphQL-подписка `profileUpdated`: Redis pub/sub подписка закрывается через `defer sub.Close()` в `pump` и завершается по `ctx.Done()` (`profile/pubsub.go:51-68`); мост-горутина в резолвере закрывает выходной канал через `defer close(out)` и слушает `ctx.Done()` (`schema.resolvers.go:140-154`). Утечки подписки при разрыве соединения нет. | — | — |
| PER-08 | Нет утечек памяти: timers и closures не удерживают большие объекты | ✅ PASS | Medium | Module-level состояние — только статичные `allowedMimeTypes`/`allowedMimeTypes` map и `startTime`; накопления без ограничения нет. `setInterval`-аналогов (`time.NewTicker`) в горячих путях, удерживающих большие объекты, не найдено. Все горутины (upload copy, pubsub pump, subscription bridge) завершаются по ctx/каналу. | — | — |

## Дополнительные наблюдения (вне строгого чеклиста, информативно)

- **Пул соединений БД настроен частично** (`internal/db/pool.go:28-30`): задано `MaxConns=10`, `MaxConnIdleTime=30s`,
  `ConnectTimeout=10s`. НЕ заданы `MinConns` (нет прогретого минимума — первые запросы после простоя платят
  за установку соединения), `MaxConnLifetime` (соединения живут вечно — нежелательно за PgBouncer/при ротации),
  `HealthCheckPeriod`. Это не нарушение из чеклиста (connection pooling присутствует), но настройку стоит дополнить.
  Severity при формализации: 🟢 Low.
- **Redis-пул**: явный `PoolSize` не задан (`internal/redis/*.go:24-31`) — используется дефолт go-redis
  (10×GOMAXPROCS). Для текущего профиля нагрузки приемлемо.
- **Pub/sub fan-out**: каждый подписчик `profileUpdated` открывает собственную Redis-подписку на общий канал
  `profile:updated` и фильтрует ВСЕ события по `userID` на стороне приложения (`pubsub.go:42-47`, `forward` :72-87).
  При большом числе одновременных подписчиков каждое событие декодируется N раз. Сейчас бизнес-объём мал —
  не нарушение, но точка масштабирования (рассмотреть per-user канал `profile:updated:<id>`).

## Решение по FAIL

Критических (🔴) и высоких (🟠) нарушений НЕ обнаружено. Все FAIL — это PER-01b (🟡),
PER-04 (🟡), PER-05 (🟢): деградация/неоптимальность без риска немедленного отказа prod.
Согласно правилам скилла, решение обязательно только для 🔴/🟠 — здесь оно не требуется,
находки приведены для бэклога производительности.

## Audit Coverage
Проверено: internal/graph/resolver/**, internal/db/** (pool.go, sqlc/*.sql.go, migrate.go),
internal/profile/** (service.go, pubsub.go), internal/upload/** (service.go, handler.go),
internal/redis/**, internal/health/**, internal/auth/middleware.go, internal/config/constants.go,
db/migrations/00001_init.sql.
Пропущено: **/*_test.go, internal/graph/generated/** (codegen), internal/graph/model/** (DTO),
scripts/**, прочие неготовые-к-нагрузке утилиты.
Файлов проверено: 14 | Пропущено (тесты/codegen): ~6
