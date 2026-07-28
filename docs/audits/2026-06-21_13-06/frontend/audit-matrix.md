# Audit: matrix (системные взаимодействия)
## Контекст: runtime=node
## Coverage: связи между компонентами, blast radius, точки отказа
## Результаты: ❌ 1 FAIL 🟠

### ❌ FAIL 🟠 MATRIX-006 — OIDC localStorage без fallback
**Файл:** `src/features/auth/api/oidc-client.ts:30`
**Проблема:** `new WebStorageStateStore({ store: window.localStorage })` — в режиме incognito/Safari IFrame режиме localStorage недоступен. Всё приложение останется без аутентификации.
**Рекомендация:** Добавить try/catch с fallback на in-memory store для случаев, когда localStorage недоступен.
