# Audit: deployment
## Контекст: runtime=go
## Coverage: DEP-01–12 — Dockerfile, pinned versions, nonroot user, multi-stage, healthcheck, secrets
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 DEP-12 — Не проверена read-only root filesystem
**Файл:** `Dockerfile`
**Проблема:** Dockerfile не включает `--read-only` флаг и не проверяет возможность запуска с read-only корневой ФС.
**Рекомендация:** Добавить `readOnlyRootFilesystem: true` и `securityContext.runAsNonRoot: true` в docker-compose/K8s, проверить что /tmp доступен для записи (tmpfs).
