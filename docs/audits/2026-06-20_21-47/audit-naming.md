# Audit Report: Naming — 2026-06-20 21:47

Проект: Go-бэкенд `liteend-go` (`/home/dex/Документы/Work/LiteStack/backend`).
Runtime: **Go 1.26**. Чеклист скилла оптимизирован под Node.js/TypeScript — проверки адаптированы под идиомы Go (пакеты, экспортируемость, интерфейсы, ошибки `Err*`, receiver-имена, аббревиатуры `ID/URL/HTTP/IP/MIME`).
Анализировался только рукописный код. Исключены: `internal/graph/generated/**`, `internal/graph/model/models_gen.go`, `internal/db/sqlc/**`, `*.gen.go`.

Baseline пуст (`accepted: []`) — все находки активны.

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| NAM-01 | Соглашение об именовании соблюдается консистентно | ✅ PASS | High | Весь рукописный код использует Go-конвенции консистентно: пакеты — короткие строчные одно-словные (`auth`, `profile`, `httperr`, `devtools`), экспортируемые идентификаторы — `PascalCase`, приватные — `camelCase`. Аббревиатуры в Go-идентификаторах единообразно заглавные: `OIDCJWKSURI`, `AvatarURL`, `DatabaseURL` (`config/config.go:37,55`), `RedisAddr`, `taskID`/`userID`/`requestID` (`queue/queue.go:136`, `profile/pubsub.go:42`, `graph/errors.go:23`). camelCase-строки `"profileId"`/`"requestId"` (`profile/service.go:90`, `graph/errors.go:27`) — это значения JSON/лог-полей (внешний API-контракт), а не Go-идентификаторы, поэтому нарушением не являются | — | — |
| NAM-02 | Имена описывают назначение, не реализацию | ✅ PASS | High | Имена доменные и говорящие: `FindOrCreateBySub`, `createOrGet`, `errorPresenter`, `redactSensitive`, `SafeFileInfo`, `RemoveFiles`. Однобуквенные имена встречаются только в идиоматичных Go-ролях: receiver'ы (`s`, `c`, `t`, `w`, `m`), индексы циклов, короткоживущие локальные (`p` для profile, `f` для file). Нет «свалочных» имён вида `data`/`info`/`manager`/`proc`/`mgr`. Generic-имя `Tool` (`backup/backup.go:22`) оправдано контекстом пакета `backup` | — | — |
| NAM-03 | Boolean имеют предикативные имена | ✅ PASS | High | Булевы предикативны: `IsProduction()` (`config/config.go:52`), `AllowedMime()` (`upload/service.go:81`), `isProd` (`middleware/secure.go:11`), `mockEnabled` (`auth/middleware.go:34`), `BackupCompressionEnabled`, `OIDCMockEnabled` (`config`). Поле `ok` из comma-ok идиомы Go. Двойных отрицаний нет | — | — |
| NAM-04 | Функции-читатели без side effects | ✅ PASS | High | Проверены все `Find*`/`Get*`. Единственный read-through-кэш `FindBySub`/`FindOrCreateBySub` (`profile/service.go:64,108`) пишет в Redis при cache-miss — это намеренная оптимизация кэширования, задокументирована комментарием на строках 104-107 и не мутирует доменную сущность. Мутирующие операции явно названы глаголами действия: `Update`, `CreateProfile`, `SaveMetadata`, `Publish`. Нарушения принципа нет | — | — |
| NAM-05 | Magic numbers и strings заменены константами | ❌ FAIL 🟢 | High | Подавляющее большинство значений вынесено в `config/constants.go` (тайм-ауты, лимиты, TTL — образцово). Остаются единичные инлайн-литералы: `health/health.go:51` `context.WithTimeout(r.Context(), 5*time.Second)` (тайм-аут health-проверки) и `cmd/server/main.go:48` тот же `5*time.Second` для healthcheck-проба; `graph/handler.go:50,52` размеры LRU-кэшей `lru.New(1000)` и `lru.New(100)` без именованных констант. Риск минимален (только читаемость/единообразие), значения локальны и очевидны из контекста | **1. Вынести в `config/constants.go`: `HealthCheckTimeout = 5*time.Second`, `GraphQLQueryCacheSize = 1000`, `GraphQLAPQCacheSize = 100`** \\ 2. Объявить локальные `const` рядом с использованием с поясняющим комментарием \\ 3. Оставить как есть, задокументировав значения inline-комментарием (значения тривиальны и не дублируются) | Нет |
| NAM-06 | Утилитные модули не являются свалкой | ✅ PASS | High | Нет файлов-свалок `utils.go`/`helpers.go`/`common.go`. Каждый пакет имеет чёткую единственную ответственность, заявленную в doc-комментарии пакета (`httperr` — единый JSON-конверт ошибок, `version` — build-метаданные, `devtools` — dev-страницы). Мелкая дубликация: helper `clientIP` определён дважды — `upload/handler.go:123` и `middleware/ratelimit.go:54` (плюс родственный `clientIPFromHeaders` в `realip.go:23`). Это дублирование кода, а не нарушение именования; имена корректны и идентичны по смыслу | — | — |
| NAM-07 | Ключевые сущности соответствуют доменному глоссарию | ✅ PASS | Medium | Глоссарий частично задан в `README.md`/`AGENTS.md`. Доменный язык консистентен между слоями: GraphQL-тип `Profile`, таблица `profile`, сервис-пакет `profile`, кэш-ключ `profile:sub:` — одно понятие во всех слоях. Термин «user» обозначает актора (авторизованного субъекта), «profile» — сущность-запись; разделение последовательно. Конкурирующих синонимов (`Account`/`Member`/`Customer`/`Client`) для одной сущности не обнаружено. Уверенность Medium: формального `GLOSSARY.md` нет, вывод по README/AGENTS и сквозному использованию терминов | — | — |

## Дополнительные наблюдения (вне формального чеклиста, информативно)

- **Receiver-имена** — идиоматичны и консистентны в пределах типа: `(s *Service)`, `(c *Client)`, `(t *Tool)`, `(m *Middleware)`, `(ps *PubSub)`, `(w *Worker)`. Нарушений Go-конвенции «короткий консистентный receiver» нет.
- **Ошибки** — все sentinel-ошибки именованы с префиксом `Err`: `ErrProfileNotFound`, `ErrUnauthenticated`, `ErrForbidden`, `ErrCacheMiss`, `ErrNotFound`, `ErrDisallowedMime`, `ErrFileTooLarge`. Полное соответствие конвенции.
- **Интерфейсы** — определены у потребителя и названы по роли: `Querier`, `Cache`, `Pinger`, `Profiles`, `Enqueuer`, `Translator`, `Writer`. `Pinger`/`Enqueuer` следуют суффиксу `-er`. Хорошая практика.
- **Пакет `db`** объявлен дважды (корневой `db/embed.go` и `internal/db/pool.go`), импортируется как `rootdb` и `db`. Это легитимный Go и осознанное разделение (встраивание миграций vs пул соединений); конфликта именования нет.

## Audit Coverage

Проверено (рукописный код, 100% пакетов):
`cmd/server/**`, `cmd/dbbackup/**`, `cmd/dbrestore/**`, `db/embed.go`,
`internal/profile/**`, `internal/auth/**`, `internal/config/**`, `internal/graph/*.go`,
`internal/graph/resolver/*.go` (кроме `schema.resolvers.go` — частично generated, проверены рукописные тела резолверов),
`internal/app/**`, `internal/upload/**`, `internal/middleware/**`, `internal/server/**`,
`internal/redis/**`, `internal/queue/**`, `internal/i18n/**`, `internal/httperr/**`,
`internal/health/**`, `internal/version/**`, `internal/logger/**`, `internal/db/{migrate,enums,pool}.go`,
`internal/devtools/**`, `internal/backup/**`.

Пропущено (по инструкции — сгенерированный код): `internal/graph/generated/**`, `internal/graph/model/models_gen.go`, `internal/db/sqlc/**`, `*.gen.go`.
Тест-файлы (`*_test.go`) просмотрены на консистентность именования, отдельно не оценивались.

Файлов проверено (рукописных, без тестов): ~36 | Пропущено (generated): сгенерированный слой gqlgen + sqlc.

## Итог

Код демонстрирует образцовое следование Go-конвенциям именования. Единственная находка — `NAM-05` уровня 🟢 Low (несколько инлайн-литералов тайм-аутов и размеров кэша при том, что в проекте уже есть централизованный `config/constants.go`). Критических и высоких нарушений именования нет.
