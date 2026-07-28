# Audit: performance
## Контекст: runtime=node
## Coverage: PER-01–08 — N+1, limits, blocking I/O, parallelism, cache, event listeners, memory leaks
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 PERF-012 — React compiler (babel-plugin) без явной проверки в production
**Файл:** `vite.config.ts:105-107`
**Проблема:** Экспериментальный babel-плагин React compiler подключён. Может вызывать неожиданное поведение в production под нагрузкой.
**Рекомендация:** Убедиться что плагин стабилен для production, добавить feature flag.
