# Audit: owasp
## Контекст: runtime=go
## Coverage: A01-A10 OWASP Top 10 — injection, auth, IDOR, CORS, rate limit, SSRF, CSRF
## Результаты: ❌ 2 FAIL 🟠

### ❌ FAIL 🟠 OWA-09 — WebSocket CheckOrigin пропускает все источники
**Файл:** `internal/graph/handler.go:39`
**Проблема:** `CheckOrigin: func(r *http.Request) bool { return true }` — любой сайт может открыть WebSocket-соединение с сервером.
**Рекомендация:** Установить конкретный origin для production: `CheckOrigin: func(r *http.Request) bool { origin := r.Header.Get("Origin"); return origin == "https://yourdomain.com" }`

### ❌ FAIL 🟠 OWA-03 — Файлы без проверки владельца (IDOR)
**Файл:** `internal/upload/handler.go:101-117`
**Проблема:** Раздача файлов проверяет только UUID, но не проверяет владельца ресурса. UUID не угадать, но формальной защиты от IDOR нет.
**Рекомендация:** Добавить проверку ownership: `if file.UserID != ctx.UserID { return ErrForbidden }`
