# Audit Report: OWASP Application Security — 2026-06-20 21:47

> Невыполненная работа по OWASP-аудиту. Закрытые/принятые находки удалены.

## Остаток (backlog)

| Check ID | Проверка | Sev | Доказательство | Решение |
|----------|----------|-----|----------------|---------|
| OWA-04 | A02: Безопасное хранение паролей / передача credentials | 🟡 | `internal/config/config.go:57` — строка подключения к Postgres использует `sslmode=disable`, то есть пароль БД (`DATABASE_PASSWORD`) и весь трафик идут по незашифрованному каналу. Также `config.go:47-48` задаёт дефолт `ADMIN_USER=admin` / `ADMIN_PASSWORD=admin` для Basic Auth dev-страниц — при незаданных переменных в проде доступ к `/playground`, `/swagger`, `/dev` открыт парой admin/admin. Собственных пользовательских паролей приложение не хранит (аутентификация через внешний OIDC), поэтому проблема ограничена инфраструктурными credentials. | **1. Включить TLS к БД (`sslmode=require`/`verify-full`) хотя бы в production, выбирая режим по `IsProduction()`** \\ 2. Сделать `sslmode` настраиваемым через env (`DATABASE_SSLMODE`) и требовать непустое значение в проде \\ 3. Запретить дефолтные admin/admin в проде через валидацию в `Load()`. Сознательно отложено: меняет локальный docker-compose-флоу и требует отдельной проработки prod-конфигурации. Смягчено: dev-страницы привязаны к 127.0.0.1 за auth-прокси. |

## Требует ручной проверки

| Check ID | Проверка | Доказательство |
|----------|----------|----------------|
| OWA-09 | A05: CSRF-защита (SameSite cookies / токены / Origin) | Сессионных cookie нет — аутентификация bearer-токеном (`Authorization: Bearer`) и заголовком `x-mock-sub` (`internal/auth/middleware.go:70,116-123`), которые браузер не отправляет автоматически cross-site, поэтому классический CSRF не применим. GraphQL-мутации по GET заблокированы транспортом gqlgen (`http_get.go:98` — «GET requests only allow query operations»). Отдельной проверки `Origin`/`Referer` или CSRF-токена нет — но при токен-аутентификации без cookie она и не требуется. Статически подтвердить отсутствие cookie-механизма во всех будущих сценариях нельзя. Связанное замечание: WebSocket-апгрейд принимает любой Origin — `internal/graph/handler.go` (`CheckOrigin: func(_ *http.Request) bool { return true }`); при токен-аутентификации в init-payload это приемлемо, но при переходе на cookie-аутентификацию по WS появится риск CSWSH. |
