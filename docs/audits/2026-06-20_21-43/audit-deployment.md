# Audit Report: Build & Deployment Configuration — 2026-06-20 21:43

Проект: фронтенд LiteStack (TanStack Start SSR, Node.js / TypeScript).

## Осталось сделать (backlog)

| Check ID | Проверка | Sev | Доказательство | Решение (остаток) |
|----------|----------|-----|----------------|-------------------|
| DEP-01 | Docker images используют pinned versions | 🟡 | `Dockerfile` уже переведён с плавающего `node:lts-alpine` на `node:22-alpine` (пин мажорной LTS-линии). **Остаётся не закрыто:** нет пина по полной версии/digest — пересборка внутри `22.x` всё ещё может дать разные patch-версии Node/Alpine. | Запиннить по digest: `FROM node:22-alpine@sha256:<hash>` (то же для обеих стадий), либо закрепить полную версию и обновлять через Renovate/Dependabot. |
| DEP-10 | npm ci используется вместо npm install | 🟡 | `Dockerfile:14` — `RUN npm install --legacy-peer-deps`. При этом `package-lock.json` существует (994 КБ). `npm install` может изменить lock-файл и подтянуть несовпадающие версии — недетерминированная и более медленная сборка. | Заменить на `RUN npm ci --legacy-peer-deps`. Если `--legacy-peer-deps` несовместим с `npm ci` — зафиксировать `overrides` в `package.json` и убрать флаг (требует выверки peer-зависимостей, чтобы не сломать сборку). |
| DEP-12 | Возможность запуска с read-only root filesystem | 🟡 | `docker-compose.yml` не содержит `read_only: true` для сервиса `app` и tmpfs-mount для `/tmp`. Read-only rootfs не настроен и не проверен; запись в FS контейнера остаётся возможной (расширяет поверхность атаки при компрометации). | Добавить `read_only: true` и `tmpfs: ["/tmp"]` в сервис `app`, предварительно проверив, что Nitro SSR-сервер не пишет в rootfs (кэш/temp). Альтернатива — `readOnlyRootFilesystem: true` в securityContext оркестратора. |

## Audit Coverage
Проверено: Dockerfile, docker-compose.yml, .dockerignore, .gitignore, .env, .env.example, package.json
Пропущено: src/** (не относится к deployment-чеклисту), CI/CD конфиги (не обнаружены), Kubernetes-манифесты (отсутствуют)
