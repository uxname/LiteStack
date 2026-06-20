# Audit Report: Build & Deployment Configuration — 2026-06-20 21:43

Проект: фронтенд LiteStack (TanStack Start SSR, Node.js / TypeScript). Runtime: Node.js (react, @tanstack/react-start, urql, zustand и др.).
Baseline: пустой (`docs/audit-baseline.yml` без принятых исключений).

| Check ID | Проверка | Статус | Уверенность | Доказательство | Решение | Исправлено |
|----------|----------|--------|-------------|----------------|---------|------------|
| DEP-01 | Docker images используют pinned versions (нет :latest) | ❌ FAIL 🟡 | High | `Dockerfile:2` и `Dockerfile:27` — `FROM node:lts-alpine`. Тег `lts` плавающий: пересборка в разное время даёт разные версии Node/Alpine. Прямого `:latest` нет, но воспроизводимость сборки не гарантирована. | **1. Запиннить конкретную версию: `FROM node:22.14.0-alpine3.21 AS build` (то же для runtime stage)** \\ 2. Запиннить по digest: `FROM node:lts-alpine@sha256:<hash>` для неизменяемости \\ 3. Оставить `lts-alpine`, задокументировать причину и закрепить версию через Renovate/Dependabot | Нет |
| DEP-02 | Контейнеры запускаются от непривилегированного пользователя (USER nonroot) | ✅ PASS | High | `Dockerfile:39` — `USER node` перед `CMD`, используется встроенный non-root пользователь образа node. | — | — |
| DEP-03 | Multi-stage build разделяет dev и prod зависимости | ✅ PASS | High | `Dockerfile:2` stage `build`, `Dockerfile:27` stage `runtime`. Runtime копирует только `COPY --from=build /app/.output ./.output` (`Dockerfile:36`) — self-contained Nitro bundle, без node_modules и dev-зависимостей. | — | — |
| DEP-04 | .dockerignore исключает node_modules, .git, .env | ❌ FAIL 🟡 | High | `.dockerignore:1-2` исключают `.git` и `node_modules/`, но записи `.env` НЕТ. При `COPY . ./` (`Dockerfile:17`) локальный `.env` (содержит реальную конфигурацию, `.env:1-25`) попадёт в build context и в слой `build`. Сейчас секретов в `.env` нет, но риск утечки при добавлении секретов в будущем. | **1. Добавить в `.dockerignore` строки `.env` и `.env.*` (с исключением `!.env.example` при необходимости)** \\ 2. Передавать конфигурацию только через `env_file`/`environment` в docker-compose, не копировать в образ \\ 3. Оставить как есть, задокументировав что `.env` фронтенда не содержит секретов (VITE_ переменные публичны) | Нет |
| DEP-05 | HEALTHCHECK определён в Dockerfile | ❌ FAIL 🟡 | High | В `Dockerfile` директива `HEALTHCHECK` отсутствует. Healthcheck есть только в `docker-compose.yml:10-15` (`wget --spider http://localhost:3000/`). При запуске образа вне compose (k8s, `docker run`, другой оркестратор) проверка здоровья не сработает. | **1. Добавить в `Dockerfile` `HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD wget --spider -q http://localhost:3000/ || exit 1`** \\ 2. Положиться на liveness/readiness probe оркестратора и задокументировать это решение \\ 3. Оставить healthcheck только в compose, если деплой всегда идёт через docker-compose | Нет |
| DEP-06 | Секреты не hardcoded в Dockerfile (нет в ENV) | ✅ PASS | High | `Dockerfile:19,31,32` — `ENV NODE_ENV=production`, `ENV PORT=3000`. Только неконфиденциальные значения. Секретов и credentials в ENV/ARG нет. | — | — |
| DEP-07 | .env исключён из VCS | ✅ PASS | High | `.gitignore:10` содержит `.env`. `git ls-files` показывает только `.env.example` как отслеживаемый; `.env` не закоммичен. | — | — |
| DEP-08 | .env.example документирует все переменные окружения | ✅ PASS | High | `.env.example:1-29` документирует все переменные из `.env` (PORT, VITE_BASE_URL, VITE_GRAPHQL_API_URL, OIDC-набор, Sentry-набор, VITE_MOCK_AUTH, VITE_APP_VERSION). Реальных секретов нет — только публичные dev-идентификаторы и пустые placeholder для Sentry. | — | — |
| DEP-09 | NODE_ENV корректно устанавливается для production | ✅ PASS | High | `Dockerfile:19` (`ENV NODE_ENV=production` в build stage) и `Dockerfile:31` (в runtime stage). | — | — |
| DEP-10 | npm ci используется вместо npm install в Docker | ❌ FAIL 🟡 | High | `Dockerfile:14` — `RUN npm install --legacy-peer-deps`. При этом `package-lock.json` существует в проекте (994 КБ). `npm install` может изменить lock-файл и подтянуть несовпадающие версии — недетерминированная и более медленная сборка. | **1. Заменить на `RUN npm ci --legacy-peer-deps` (требует наличия package-lock.json, который есть)** \\ 2. Если `--legacy-peer-deps` несовместим с `npm ci` — зафиксировать `overrides` в package.json и убрать флаг \\ 3. Оставить `npm install`, задокументировав причину (нестандартное разрешение peer-зависимостей) | Нет |
| DEP-11 | Ограничения ресурсов контейнера определены (CPU limits, Memory limits) | ❌ FAIL 🟠 | High | `docker-compose.yml` для сервиса `app` не содержит `deploy.resources.limits` (`memory`, `cpus`). Утечка памяти или пик нагрузки в SSR-процессе может исчерпать ресурсы хоста и уронить соседние контейнеры (blast radius — весь хост). | **1. Добавить в сервис `app` блок `deploy: { resources: { limits: { cpus: "1.0", memory: "512M" } } }`** \\ 2. Использовать `mem_limit`/`cpus` (Compose v2 non-swarm синтаксис) если деплой не через swarm \\ 3. Задать лимиты на уровне оркестратора (k8s `resources.limits`) и задокументировать это | Нет |
| DEP-12 | Возможность запуска с read-only root filesystem проверена | ❌ FAIL 🟡 | Medium | `docker-compose.yml` не содержит `read_only: true` для сервиса `app` и tmpfs-mount для `/tmp`. Read-only rootfs не настроен и не проверен; запись в FS контейнера остаётся возможной (расширяет поверхность атаки при компрометации). | **1. Добавить `read_only: true` и `tmpfs: ["/tmp"]` в сервис `app`, проверить что Nitro SSR-сервер не пишет в rootfs** \\ 2. Ограничить запись через securityContext оркестратора (`readOnlyRootFilesystem: true` в k8s) \\ 3. Оставить writable rootfs, задокументировав что SSR-процессу нужна запись (кэш/temp) | Нет |

## Сводка по FAIL

- 🔴 Critical: 0
- 🟠 High: 1 — DEP-11 (нет лимитов ресурсов контейнера)
- 🟡 Medium: 5 — DEP-01, DEP-04, DEP-05, DEP-10, DEP-12
- 🟢 Low: 0

Требуют решения (🔴/🟠): только DEP-11.

## Ключевые находки

1. **DEP-11 (🟠 High)** — единственная находка с обязательным решением. В `docker-compose.yml` нет лимитов CPU/памяти: один контейнер с утечкой памяти может исчерпать ресурсы всего хоста.
2. **DEP-10 (🟡)** — `npm install` вместо `npm ci` при наличии `package-lock.json` делает Docker-сборку недетерминированной.
3. **DEP-04 (🟡)** — `.env` не исключён в `.dockerignore`, при `COPY . ./` он попадает в build-слой. Сейчас секретов в `.env` нет (только публичные VITE_-значения), но это потенциальная утечка при будущем добавлении секретов.
4. **DEP-05 (🟡)** — HEALTHCHECK есть только в compose, но не в Dockerfile; теряется при запуске вне docker-compose.
5. **DEP-01 (🟡)** — `node:lts-alpine` это плавающий тег, не запиннена конкретная версия → невоспроизводимые сборки.
6. **Положительное:** корректный multi-stage build, non-root `USER node`, `NODE_ENV=production`, `.env` исключён из VCS, `.env.example` полон и без секретов, нет секретов в Dockerfile ENV.

## Audit Coverage
Проверено: Dockerfile, docker-compose.yml, .dockerignore, .gitignore, .env, .env.example, package.json (scripts + наличие package-lock.json)
Пропущено: src/** (не относится к deployment-чеклисту), CI/CD конфиги (`.github/workflows`, `gitlab-ci.yml` — не обнаружены в корне), Kubernetes-манифесты (отсутствуют)
Файлов проверено: 7 | Пропущено: 0 (релевантных deployment-файлов)
