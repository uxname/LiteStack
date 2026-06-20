# Audit Report: Architecture & File Structure — 2026-06-20 21:47

**Проект:** `/home/dex/Документы/Work/LiteStack/backend` (Go 1.26, модуль `github.com/uxname/liteend-go`)
**Runtime:** Go. JS-специфичные проверки (AbortSignal, process.on) не применимы и заменены на Go-эквиваленты (`context.Context`, `os/signal`).
**Baseline:** `docs/audit-baseline.yml` — пуст (`accepted: []`).

## Инструментальное подтверждение

- `task arch` (go-arch-lint v1.15.0) — **OK, нарушений нет**. Проверены границы слоёв из `.go-arch-lint.yml`: entrypoint → composition → transport → domain → infrastructure + cross-cutting (config/logger/version/httperr).
- `depguard` в `.golangci.yml` (правило `domain-no-transport`) — domain/infra пакетам запрещён импорт `internal/graph`, `internal/server`, `internal/app`. Проверено: ни один domain/infra пакет таких импортов не содержит.

## Результаты

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| ARC-01 | Бизнес-логика вынесена из route handlers в service/domain слой | ✅ PASS | High | Резолверы (`internal/graph/resolver`) и REST-хендлеры делегируют в сервисы; вся логика профиля в `internal/profile/service.go`, загрузок — в `internal/upload/service.go`. Хендлеры не содержат бизнес-правил. | — | — |
| ARC-02 | Presentation layer не взаимодействует с БД напрямую | ✅ PASS | High | Транспортный слой (`graph`, `server`, `middleware`) не импортирует `internal/db`. БД-доступ только через сервисы профиля/загрузки, которые транспорт получает через узкие интерфейсы (`resolver.go:21` `ProfileService`). | — | — |
| ARC-03 | Нет circular dependencies между модулями | ✅ PASS | High | `task arch` → OK. Граф зависимостей строго однонаправлен внутрь. Domain-импорты (`profile`, `upload`, `auth`) ведут только в `config/logger/db/sqlc/redis/httperr` — циклов нет. `go build` (через `task arch`) прошёл бы с ошибкой при наличии цикла. | — | — |
| ARC-04 | Нет god-объектов: единственная ответственность | ✅ PASS | High | Самый крупный неавтогенерируемый файл — `internal/upload/service.go` (261 строка), затем `backup.go` (224). Все < 500 строк. Лимиты сложности (`funlen: 80`, `cyclop: 15`, `gocognit: 20`) форсируются в `.golangci.yml`. | — | — |
| ARC-05 | Конфигурация и env-переменные изолированы в config-модуле | ❌ FAIL 🟢 | High | `cmd/server/main.go:44` — `port := os.Getenv("PORT")` с дублированием дефолта `"4000"` (строка 47) в обход `internal/config`. Единственное прямое чтение env вне config-модуля. Риск: рассинхрон дефолта порта между `config` и healthcheck-утилитой при изменении конфигурации. | **1. Прокинуть порт через `config.Load()` и передать в `healthcheck()`** \\ 2. Вынести имя переменной и дефолт `"4000"` в константу пакета `config` и использовать её в обоих местах \\ 3. Оставить как есть и задокументировать: `healthcheck` запускается отдельным процессом контейнера до полной инициализации config, прямое чтение env обосновано | Нет |
| ARC-06 | Внешние зависимости инжектируются (DI), не импортируются напрямую | ✅ PASS | High | `internal/app/app.go:45` `Build()` — корректный composition root с ручным DI: `profile.New(database.Queries, rdb)`, `auth.NewMiddleware(verifier, profiles, ...)`, `resolver.Resolver{Profiles: profiles, ...}`. Все зависимости передаются через конструкторы, ни одна не создаётся внутри сервисных функций. | — | — |
| ARC-07 | Доменный слой не импортирует transport (направление внутрь) | ✅ PASS | High | Проверены импорты `profile/upload/queue/auth`: ни одного импорта `graph`/`server`/`app`/Express-аналогов. Domain зависит только от config/logger/db/redis/httperr (cross-cutting + infrastructure — разрешённое направление). Принудительно проверяется `depguard` и `go-arch-lint`. | — | — |

## Отдельно: узкие интерфейсы у потребителя (Interface Segregation / consumer-side interfaces)

Образцовое применение паттерна — интерфейсы объявлены **на стороне потребителя**, а не поставщика:

- `internal/graph/resolver/resolver.go:21-40` — транспорт объявляет `ProfileService`, `ProfilePubSub`, `Enqueuer`, `Translator` (по 1-2 метода каждый) вместо зависимости от конкретных сервисов.
- `internal/profile/service.go:35` — `Querier` (подмножество sqlc-методов) и `:43` `Cache` (3 метода Redis) — сервис не тянет весь `*sqlc.Queries`/`*redis.Client`.
- `internal/auth/middleware.go:23` — `Profiles` (узкий контракт для middleware).
- `internal/health/health.go:23` — `Pinger`.

Это обеспечивает тестируемость (моки) и инверсию зависимостей при сохранении разрешённого направления `domain → infrastructure`.

## Итог

Архитектура соответствует заявленной слоистой модели практически полностью. Зависимости направлены строго внутрь, нарушений слоёв и циклов нет, structure папок чистая, DI и узкие интерфейсы применены последовательно. Единственная находка — мелкое (🟢 Low) дублирование чтения env-переменной `PORT` в entrypoint-утилите healthcheck вне config-модуля.

**Сводка FAIL по severity:** 🔴 Critical: 0 | 🟠 High: 0 | 🟡 Medium: 0 | 🟢 Low: 1

## Audit Coverage

Проверено: `cmd/server/**`, `internal/app/**`, `internal/graph/**`, `internal/server/**`, `internal/middleware/**`, `internal/auth/**`, `internal/profile/**`, `internal/upload/**`, `internal/queue/**`, `internal/redis/**`, `internal/db/**`, `internal/config/**`, `internal/logger/**`, `internal/health/**`, `internal/i18n/**`, `internal/httperr/**`, `internal/devtools/**`, `internal/backup/**`, `.go-arch-lint.yml`, `.golangci.yml`, `Taskfile.yml`
Пропущено: `*_test.go` (тестовое scaffolding, исключено из arch-правил), автогенерируемый код (`internal/graph/generated/**`, `internal/db/sqlc/*.sql.go`, `*_gen.go`)
Файлов проверено: 33 (.go, не считая тестов/генерации) | Пропущено: ~20 (тесты + генерация)
