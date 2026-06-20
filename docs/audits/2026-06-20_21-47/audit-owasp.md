# Audit Report: OWASP Application Security — 2026-06-20 21:47

Проект: Go-бэкенд (`github.com/uxname/liteend-go`), роутер chi, GraphQL (gqlgen),
доступ к БД через sqlc, аутентификация через OIDC. Baseline пуст (`accepted: []`).

Аудит охватывает критические пути: аутентификация и проверка ролей
(`internal/auth/**`), Basic Auth для dev-страниц
(`internal/middleware/basicauth.go`), загрузка файлов (`internal/upload/**`),
авторизация в GraphQL-резолверах (`internal/graph/resolver/**`),
ограничение частоты запросов (`internal/middleware/ratelimit.go`),
заголовки безопасности (`internal/middleware/secure.go`).

## Результаты проверок

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| OWA-01 | A03: Все запросы к БД/OS/LDAP параметризованы, нет injection | ✅ PASS | High | Все SQL-запросы сгенерированы sqlc и используют плейсхолдеры `$1..$N`: `internal/db/sqlc/profile.sql.go:46,66,85` (`WHERE id = $1`, `oidc_sub = $1`, `UPDATE ... WHERE id = $4`), `internal/db/sqlc/upload.sql.go:54` (`getUploadByFilepath`). Конкатенации/склейки строк в SQL нет. Shell-команд с пользовательским вводом нет (единственный HTTP-клиент — OIDC JWKS, `verifier.go:25`). | — | — |
| OWA-02 | A01: Все защищённые маршруты имеют auth-middleware | ✅ PASS | High | Карта маршрутов едина: `internal/app/app.go:133-153`. `POST /upload` обёрнут `authMW.RequireAuth` (`app.go:136`, `upload/handler.go:27`). `/graphql` использует `authMW.Optional` + guard в каждом резолвере. Dev-страницы `/playground`, `/dev`, `/swagger`, `/openapi.yaml` защищены `BasicAuth` (`app.go:144-147`). Публичны только `/health` и `/uploads/*` (по дизайну). Проверка роли ADMIN выполняется в резолверах `Echo`, `Debug`, `TestTranslation` (`schema.resolvers.go:59,77,87,95`). | — | — |
| OWA-03 | A01: Resource ownership проверяется, нет IDOR [⚡ dynamic] | ✅ PASS | High | `UpdateProfile` берёт `user.ID` из контекста аутентификации, а не из аргументов клиента: `schema.resolvers.go:23-28` → `r.Profiles.Update(ctx, user.ID, ...)`. Клиент не может указать чужой ID. `Me` возвращает только профиль текущего пользователя (`schema.resolvers.go:67-72`). Подписка `ProfileUpdated` фильтруется по `user.ID` (`schema.resolvers.go:138`). Файлы под `/uploads/*` намеренно общедоступны (публичные изображения), отдельной модели владения нет. | — | — |
| OWA-04 | A02: Безопасное хранение паролей / передача credentials | ❌ FAIL 🟡 | High | `internal/config/config.go:57` — строка подключения к Postgres использует `sslmode=disable`, то есть пароль БД (`DATABASE_PASSWORD`) и весь трафик идут по незашифрованному каналу. Также `config.go:47-48` задаёт дефолт `ADMIN_USER=admin` / `ADMIN_PASSWORD=admin` для Basic Auth dev-страниц — при незаданных переменных в проде доступ к `/playground`, `/swagger`, `/dev` открыт парой admin/admin. Собственных пользовательских паролей приложение не хранит (аутентификация через внешний OIDC), поэтому проблема ограничена инфраструктурными credentials. | **1. Включить TLS к БД (`sslmode=require`/`verify-full`) хотя бы в production, выбирая режим по `IsProduction()`** \\ 2. Сделать `sslmode` настраиваемым через env (`DATABASE_SSLMODE`) и требовать непустое значение в проде \\ 3. Оставить `disable` для локального docker-compose, но запретить дефолтные admin/admin в проде через валидацию в `Load()` | Нет |
| OWA-05 | A05: Безопасная конфигурация сервера (CORS, security headers, body limits) | ❌ FAIL 🟠 | High | CORS-origin читается из env без валидации: `internal/config/config.go:18` (`CORSOrigin []string env:"CORS_ORIGIN"`), `internal/server/server.go:45` (`AllowedOrigins: cfg.CORSOrigin`). Если переменная `CORS_ORIGIN` не задана, слайс пуст, и библиотека `go-chi/cors` v1.2.2 включает режим «разрешить всё»: `cors.go:131-134` (`if len(options.AllowedOrigins) == 0 { c.allowedOriginsAll = true }`), после чего отдаёт `Access-Control-Allow-Origin: *` (`cors.go` строки 268/319). При этом в конфиге выставлено `AllowCredentials: true` (`server.go:48`). Заголовки безопасности и лимит тела при этом настроены корректно (`secure.go`, `recover.go:38 BodyLimit`, `constants.go:13`). Риск: при незаданной переменной окружения сервер становится полностью открытым по CORS. | **1. В `config.Load()` требовать непустой `CORS_ORIGIN` (или явный список) и падать при пустом значении в production** \\ 2. Задать безопасный дефолт для `CORSOrigin` в коде вместо пустого слайса \\ 3. Заменить `AllowedOrigins` на `AllowOriginFunc` со строгим whitelist, исключив поведение «пусто = все» | Нет |
| OWA-06 | A07: Защита от перебора (rate limiting, надёжная проверка токенов) | ✅ PASS | High | Redis-лимитер (GCRA) применяется ко всем запросам: `internal/server/server.go:41-43`, `internal/middleware/ratelimit.go:18-43` — 100 запросов/мин (`constants.go:8-10`), для `/upload` и `/graphql` ключ `rl:auth:{ip}`. OIDC-верификатор жёстко фиксирует алгоритмы подписи `RS256`/`ES384` (`internal/auth/verifier.go:28-31`, `SupportedSigningAlgs`), поэтому `alg:none` и подмена алгоритма исключены; проверяются issuer, audience, expiry силами `go-oidc`. Замечание (не нарушение): лимитер «fail-open» при недоступности Redis (`ratelimit.go:31-34`) — сознательный выбор доступности; стоит держать в уме. | — | — |
| OWA-07 | A09: Техническая информация не утекает в ответы | ✅ PASS | High | REST-ошибки отдаются единым конвертом `{"statusCode","message"}` без stack trace и внутренних путей: `internal/httperr/httperr.go` (`Write`). Паники перехватываются и логируются, клиенту уходит общий «Internal Server Error» (`internal/middleware/recover.go:18-30`). GraphQL-ошибки нормализуются `errorPresenter` (`internal/graph/errors.go`) — наружу идут стабильные коды (`UNAUTHENTICATED`/`FORBIDDEN`/`INTERNAL_SERVER_ERROR`) и `requestId`, без деталей. Первичный аудит для этой темы — `audit-errors` (*см. ERR-02*). | — | — |
| OWA-08 | A10: SSRF — URL из user input в HTTP-клиент без whitelist | ✅ PASS | High | Пользовательский ввод никуда не запрашивается по сети. `avatarUrl`/`displayName`/`bio` только сохраняются в БД и возвращаются клиенту (`internal/profile/service.go:152-166`, `internal/graph/resolver/convert.go:18`), сервер их не загружает. Единственный исходящий HTTP-клиент — фетч JWKS по сконфигурированному доверенному `OIDC_JWKS_URI` (`internal/auth/verifier.go:25-27`), не управляемому пользователем. | — | — |
| OWA-09 | A05: CSRF-защита (SameSite cookies / токены / Origin) | 🔍 UNVERIFIED | Medium | Сессионных cookie нет — аутентификация bearer-токеном (`Authorization: Bearer`) и заголовком `x-mock-sub` (`internal/auth/middleware.go:70,116-123`), которые браузер не отправляет автоматически cross-site, поэтому классический CSRF не применим. GraphQL-мутации по GET заблокированы транспортом gqlgen (`http_get.go:98` — «GET requests only allow query operations»), что закрывает CSRF-через-GET. Отдельной проверки `Origin`/`Referer` или CSRF-токена нет — но при токен-аутентификации без cookie она и не требуется. Статически подтвердить отсутствие cookie-механизма во всех будущих сценариях нельзя. Связанное замечание: WebSocket-апгрейд принимает любой Origin — `internal/graph/handler.go` (`CheckOrigin: func(_ *http.Request) bool { return true }`); при токен-аутентификации в init-payload это приемлемо, но если перейдут на cookie-аутентификацию по WS — появится риск CSWSH. | — | — |

## Дополнительные замечания (вне чеклиста)

- **WebSocket CheckOrigin = true** (`internal/graph/handler.go`): подключение разрешено
  с любого Origin. Сейчас безопасно, т.к. аутентификация идёт через токен в
  connection-payload (`InitFunc`), а не через cookie. Зафиксировать как сознательное
  решение и пересмотреть при переходе на cookie-сессии.
- **Rate limit fail-open** (`internal/middleware/ratelimit.go:31`): при недоступности
  Redis лимитер пропускает все запросы. Это выбор «доступность важнее троттлинга»;
  для чувствительных операций можно рассмотреть fail-closed.
- **Уязвимые зависимости**: проект на Go — `npm audit` неприменим. Рекомендуется
  запустить `govulncheck ./...` в CI как отдельную зону (вне текущего чеклиста).

## Сводка по FAIL

- 🔴 Critical: 0
- 🟠 High: 1 — OWA-05 (CORS «разрешить всё» при незаданном `CORS_ORIGIN` + `AllowCredentials: true`).
- 🟡 Medium: 1 — OWA-04 (`sslmode=disable` для БД; дефолтные admin/admin для dev-страниц).
- 🟢 Low: 0

## Audit Coverage

Проверено: `internal/auth/**`, `internal/middleware/**`, `internal/upload/**`,
`internal/graph/**` (handler, resolver, errors, logging),
`internal/server/server.go`, `internal/app/app.go`, `internal/config/**`,
`internal/profile/service.go`, `internal/db/sqlc/*.sql.go`, `internal/httperr/**`.

Пропущено: `*_test.go`, `internal/db/migrations` и `db/queries/*.sql` (исходники для
sqlc — генерат проверен), `internal/queue/**`, `internal/backup/**`, `internal/redis/**`,
`internal/i18n/**`, `internal/devtools/**`, `internal/health/**` (не на критических путях
OWASP-чеклиста).

Файлов проверено: ~22 | Пропущено: ~25
