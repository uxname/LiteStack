# Audit: validation
## Контекст: runtime=go
## Coverage: schema-валидация, границы, JSON parse, identity, prototype pollution
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 VAL-02 — Нет явной maxLength на строковых полях в некоторых GraphQL-типах
**Файл:** `internal/graph/schema.graphqls` (множественные поля)
**Проблема:** Строковые поля (name, title, description) не имеют директив `@maxLength` — клиент может отправить произвольно длинные строки.
**Рекомендация:** Добавить `@maxLength` для всех строковых полей входящих мутаций.
