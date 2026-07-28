# Audit: matrix (системные взаимодействия)
## Контекст: runtime=go
## Coverage: связи между компонентами, blast radius, точки отказа
## Результаты: ❌ 2 FAIL 🟠, 1 FAIL 🟡🟢

### ❌ FAIL 🟠 Matrix-A1 — WebSocket handler без ограничения origin (дубль OWA-09)
**Файл:** `internal/graph/handler.go:39`
**Проблема:** WebSocket CheckOrigin=true — любой сайт может подключиться. Это входная точка для cross-site WebSocket hijacking.
**Рекомендация:** Ограничить origin до доверенного домена.

### ❌ FAIL 🟠 Matrix-DB — Пул соединений 10 может быть узким местом
**Файл:** `internal/db/pool.go:29`
**Проблема:** Пул pgx ограничен 10 соединениями. Под нагрузкой (100+ req/s) это может стать узким местом, хотя statement timeout (30s) защищает.
**Рекомендация:** Увеличить pool max до 25-50 или сделать конфигурируемым через env.

### ❌ FAIL 🟡🟢 Matrix-UP — upload handler без формальной проверки ownership
**Файл:** `internal/upload/handler.go:101-117`
**Проблема:** Нет прямой проверки владельца файла. UUID трудно угадать, но это defence-in-depth, а не изоляция.
**Рекомендация:** Добавить проверку владельца: `if file.UserID != ctx.UserID { return ErrForbidden }`.
