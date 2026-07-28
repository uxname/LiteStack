# Audit: documentation
## Контекст: runtime=go
## Coverage: DOC-01–06 — README, env, ссылки, комментарии, публичное API, проектная документация
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 DOC-02 — Не все env-переменные задокументированы
**Файл:** `internal/config/config.go` + `.env.example`
**Проблема:** Некоторые env-переменные (OIDC_MOCK_ENABLED, CORS_ORIGIN) используются в коде, но отсутствуют в .env.example или в README.
**Рекомендация:** Синхронизировать .env.example со всеми переменными из config.go.
