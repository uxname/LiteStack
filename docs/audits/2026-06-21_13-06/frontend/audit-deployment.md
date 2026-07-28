# Audit: deployment
## Контекст: runtime=node
## Coverage: DEP-01–12 — Dockerfile, pinned versions, nonroot user, multi-stage, healthcheck, secrets
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 DEPL-007 — npm install --legacy-peer-deps вместо npm ci
**Файл:** `Dockerfile:14`
**Проблема:** `npm install --legacy-peer-deps` — сборка не воспроизводима, package-lock.json игнорируется. `--legacy-peer-deps` маскирует реальные конфликты peer-зависимостей.
**Рекомендация:** Использовать `npm ci` (работает по lock-файлу). Если peer-deps конфликтуют — разобраться с зависимостями.
