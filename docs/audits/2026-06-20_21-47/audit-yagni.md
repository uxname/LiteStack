# Audit Report: Over-engineering & YAGNI — 2026-06-20 21:47

Проект: Go-бэкенд `liteend-go` (шаблон / boilerplate). Анализировался только написанный вручную код.
Сгенерированный код (`internal/graph/generated/generated.go`, `internal/graph/model/models_gen.go`,
`internal/db/sqlc/*.go`) исключён из проверки по условию задачи.

Учтён контекст: это базовый шаблон проекта, поэтому часть инфраструктуры (очередь задач,
pub/sub, backup, dev-страницы, демонстрационный «test job») намеренно обобщена как готовая основа
для будущих продуктов и не считается лишней.

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| YAGNI-01 | Нет закомментированного кода | ✅ PASS | High | Поиск по `internal/`, `cmd/` шаблонов закомментированного кода (`// if`, `// for`, `// return`, `// :=` и т.п.) дал только настоящие doc-комментарии (`internal/middleware/recover.go:14`, `internal/profile/pubsub.go:70`, `internal/app/app.go:132`). Закомментированных блоков кода нет. | — | — |
| YAGNI-02 | Нет dead code — неиспользуемых экспортов, функций, переменных | ✅ PASS | High | `go run golang.org/x/tools/cmd/deadcode -test ./...` → пустой вывод, exit 0. Линтеры `unused`, `unparam`, `unconvert`, `ineffassign` (включены в `.golangci.yml`) → `0 issues`. Все поля `Config`/`BackupConfig` и константы из `internal/config/constants.go` имеют потребителей вне пакета config (проверено grep'ом по каждому полю). | — | — |
| YAGNI-03 | Абстракции оправданы: интерфейс/фабрика имеет >1 реализации или требуется тестами | ✅ PASS | High | Найдено 9 интерфейсов в рукописном коде. Все — узкие consumer-defined интерфейсы (объявлены там, где используются) и каждый имеет тестовый fake: `Writer`→`fakeWriter` (`internal/upload/service_test.go:15`), `Profiles`→`fakeProfiles` (`internal/auth/middleware_test.go:14`), `Pinger`→`fakePinger` (`internal/health/health_test.go:14`, плюс 2 реальные реализации: db и redis), `ProfileService`/`ProfilePubSub`/`Enqueuer`/`Translator` (`internal/graph/resolver/resolver.go:21-40`) используются с `fakeEnqueuer`/`fakeTranslator` (`internal/graph/resolver/resolvers_test.go:49,59`), `Querier`/`Cache` (`internal/profile/service.go:35,43`) — для подмены sqlc и redis в тестах. Фабрик/Builder/Strategy/Repository-поверх-ORM/прокси-service-слоёв без логики не обнаружено. `convert.go:toModelProfile` — настоящий маппер (int32 ID → string, набор полей отличается от entity), не лишний DTO. | — | — |
| YAGNI-04 | Feature flags не зафиксированы в одном значении | ✅ PASS | High | Булевые переключатели читаются из окружения и реально влияют на поведение: `OIDCMockEnabled` (`internal/config/config.go:38`, проверка в `Load()` строки 78-80, прокидывается в auth middleware), `BackupCompressionEnabled` (`internal/config/config.go:100`, используется в `internal/backup`). Захардкоженных в коде `true`/`false` feature-флагов не найдено. Константы тюнинга (таймауты, лимиты, размеры пула) в `constants.go` намеренно зафиксированы как значения шаблона, а не как избыточная конфигурируемость. | — | — |
| YAGNI-05 | Технический долг актуален — нет заброшенных TODO/FIXME без даты или прогресса | ✅ PASS | High | Поиск `TODO\|FIXME\|XXX\|HACK` по `internal/`, `cmd/` (без сгенерированного кода) → совпадений нет. | — | — |

## Дополнительные проверки (вне обязательного чеклиста, для полноты)

- Преждевременная оптимизация: не найдено `sync.Pool`, `unsafe`, `reflect`, ручных кэшей сверх
  нужного, самодельных пулов. Generics в рукописном коде отсутствуют (нет надуманных
  generic-типов с единственным использованием).
- Размеры файлов адекватны (`app.go` 171 строк, `devtools.go` 136, `server.go` 98) — признаков
  раздувания нет.
- `internal/queue` `AddTestJob`/`TestJobPayload` — это намеренный демонстрационный примитив
  шаблона (пример фоновой задачи), а не мёртвый код: используется резолвером через интерфейс
  `Enqueuer` и покрыт тестами.

## Итог

✅ Over-engineering не обнаружен.

Кодовая база следует идиоматичному Go: узкие consumer-defined интерфейсы под тесты, никаких
лишних слоёв абстракции, мёртвого кода, зафиксированных feature-флагов или заброшенного техдолга.
Инструменты обнаружения (deadcode, unused, unparam, ineffassign) уже встроены в CI
(`Taskfile.yml`, `.golangci.yml`), что предотвращает накопление dead code в будущем.

## Audit Coverage
Проверено: internal/**, cmd/** (рукописный код)
Пропущено: internal/graph/generated/**, internal/graph/model/models_gen.go, internal/db/sqlc/** (сгенерированный код), db/migrations/**, test fixtures
Файлов проверено: 54 | Пропущено: 6
