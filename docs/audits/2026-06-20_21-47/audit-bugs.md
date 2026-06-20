# Audit Report: Bugs & Logic Errors — 2026-06-20 21:47

Runtime: Go 1.26 (модуль `github.com/uxname/liteend-go`). Чеклист BUG-XX из JS адаптирован под Go-специфику (context.Context вместо AbortSignal, defer/Close, проигнорированные ошибки, nil pointer, goroutine leaks).

Baseline: отсутствует (`docs/audit-baseline.yml` не найден). Все находки оцениваются заново.

## Результаты

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| BUG-02 | async/await используется корректно (Go: отмена контекста, goroutine без утечки) | ❌ FAIL 🟠 | High | `internal/upload/service.go:229-261` — при `<-ctx.Done()` функция `writeFile` сразу выходит (строка 254), `defer f.Close()` (234) закрывает файл, но запущенная горутина продолжает `io.Copy(f, body)` (249) уже в закрытый дескриптор. Горутина и читатель `body` не отменяются и живут, пока тело не дочитается. | **1. Закрывать файл внутри горутины после io.Copy (а не через defer в writeFile), чтобы close произошёл только когда копирование завершилось/прервалось** \\ 2. Использовать `os.File` с `SetWriteDeadline` нельзя для обычного файла — вместо этого оборачивать `body` в reader, который реагирует на ctx (контекстный reader), чтобы io.Copy завершался сам \\ 3. Оставить, задокументировав, что таймаут уплыва ведёт к утечке горутины до конца тела запроса | Нет |
| BUG-03 | Null-safety (Go: nil pointer dereference, nil-проверки) | ✅ PASS | High | `internal/auth/context.go:29-31` — type assertion с `ok` и доп. проверкой `p != nil`. `internal/profile/service.go:93-94` — `errors.As` перед обращением к `pgErr.Code`. `convert.go` обращается только к полям-значениям. Range по `p.Roles` (`context.go:47`) безопасен при nil. | — | — |
| BUG-06 | Математические guard-условия / граничные значения | ✅ PASS | High | `internal/upload/service.go:181` — `int32(f.size)` защищён лимитом `UploadMaxFileSize` (проверка на 125-128 до записи метаданных). Деления нет. `handler.go:62` `LimitReader(..+1)` корректно ловит overflow. | — | — |
| BUG-07 | Off-by-one (границы slice, ротация, пагинация) | ✅ PASS | High | `internal/backup/backup.go:159-163` — guard `len(files) <= BackupRotation`, затем `files[:len(files)-BackupRotation]` — корректно удаляет только лишние, без выхода за границы. `handler.go:56` `fileCount > UploadMaxFiles` корректная граница. | — | — |
| BUG-09 | Дата/время в UTC | ✅ PASS | High | `upload/service.go:105` `time.Now().UTC()`; `queue/queue.go:59` `.UTC().Format(RFC3339)`; `backup/backup.go:72` `.UTC().Format(...)`; `resolver/schema.resolvers.go:110` `.UTC()`. Везде явный UTC. | — | — |
| BUG-01 | Преобразования типов безопасны | ✅ PASS | Medium | В критических путях нет небезопасных строковых→числовых преобразований с пользовательским вводом. `convert.go:13` `strconv.FormatInt` (вывод, не парсинг). `backup.go:83` `strconv.Itoa` для порта из конфига. | — | — |
| BUG-04 | Функции не мутируют входные аргументы | 🔍 UNVERIFIED | Medium | `upload/service.go:165` `RemoveFiles(files)` итерирует, не мутируя slice. `backup.go:162` `sort.Slice` сортирует локально созданный `files`, не аргумент. Прямой мутации аргументов не найдено, но `profile.FindOrCreateMockUser` (`service.go:137-139`) мутирует **копию** `sqlc.Profile` (значение, не указатель) — безопасно. Полного обзора всех функций не делал. | — | — |
| BUG-05 | Exhaustive handling (switch по enum/union) | 🔍 UNVERIFIED | Low | В критических путях нет switch по `ProfileRole`/enum. `handler.go:104` switch по типам ошибок имеет `case err != nil` как catch-all (безопасно). Полного обзора enum-веток вне критических путей не делал. | — | — |
| BUG-08 | Float comparison | ✅ PASS | High | Сравнений float через `==` в критических путях нет. Денежных сумм нет. | — | — |
| BUG-10 | ReDoS (regexp с user input) | ✅ PASS | High | В критических путях `regexp` с пользовательским вводом не используется. Парсинг Authorization/Bearer (`middleware.go:108-123`) — простые срезы строк, не regexp. | — | — |

## Дополнительные наблюдения (вне строгого чеклиста, для разработчика)

- `internal/auth/middleware.go:79-82` — в mock-режиме `FindBySub` возвращает профиль из БД/кэша **без** нормализации ролей к `[USER, ADMIN]` (нормализация есть только в `FindOrCreateMockUser`, `profile/service.go:137`). Если по `x-mock-sub` нашёлся реальный профиль, его роли используются как есть. Это логика авторизации/тестового режима, формально не входит в BUG-чеклист — отнести к `audit-owasp`/`audit-validation`. Уверенность Medium.
- `internal/profile/service.go:79` — `FindOrCreateBySub` кладёт в кэш профиль, но при mock-логине роли мокаются в памяти и в кэш попадает «реальный» набор ролей. Потенциальное расхождение, но это поведение кэша, не явный баг логики. Уверенность Low.

## Главная находка

🟠 **BUG-02 / `internal/upload/service.go:229-261`** — единственный FAIL. При срабатывании таймаута загрузки (`FileUploadTimeout`) `writeFile` возвращается и `defer f.Close()` закрывает файл, пока фоновая горутина ещё выполняет `io.Copy` в этот же дескриптор: запись в закрытый файл + утечка горутины и читателя тела до конца передачи. Под нагрузкой/медленными клиентами это накапливает зависшие горутины и FD.

## Audit Coverage
Проверено (критические пути): `internal/auth/**`, `internal/upload/**`, `internal/queue/**`, `internal/profile/**`, `internal/backup/**`, `internal/graph/resolver/**`
Пропущено: `**/*_test.go`, автогенерированный код (`internal/graph/generated/**`, `internal/db/sqlc/**`), конфиги.
Файлов проверено: 11 | Пропущено (test/generated): ~6
