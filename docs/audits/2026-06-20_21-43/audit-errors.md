# Audit Report: Error Handling & Resiliency — 2026-06-20 21:43

**Runtime:** Node.js / TypeScript. Гибридное приложение: клиент в браузере (React 19) + SSR-сервер на TanStack Start (Nitro node-server, запуск `node .output/server/index.mjs`). Пользовательская SSR-точка входа — `src/server.ts`.

> Невыполненной работы по исправлениям нет. Остались только проверки, которые невозможно подтвердить статически (логика — в сгенерированном Nitro-сервере `.output/`, вне исходников).

## Требует ручной проверки

| Check ID | Проверка | Доказательство |
|----------|----------|----------------|
| ERR-04 | Unhandled rejections и uncaught exceptions имеют process-level обработчики | Клиент: оконные обработчики есть — `GlobalErrorBoundary.tsx:16-17` слушает `unhandledrejection` и `error`, шлёт в Sentry. Сервер: в app-коде (`src/server.ts`, `src/router.tsx`, `src/client.tsx`) нет `process.on('unhandledRejection'/'uncaughtException')` (grep по `src/**` — 0 совпадений). HTTP-сервер генерируется Nitro в `.output/server/index.mjs` (вне исходников), его process-level поведение статически из репозитория не подтверждается. **Проверить:** поведение Nitro-пресета `node-server` на unhandled rejection/exception; при необходимости добавить process-обработчики в кастомную точку входа. |
| ERR-06 | Graceful shutdown реализован — SIGTERM обрабатывается | В app-коде нет `process.on('SIGTERM'/'SIGINT')` (grep по `src/**` — 0 совпадений). Прод-сервер — сгенерированный Nitro-бандл (`Dockerfile` CMD `node .output/server/index.mjs`), его shutdown-логика лежит вне исходников и статически не подтверждается. SSR-сервер stateless (нет своего DB-пула/долгих коннектов в app-коде), поэтому graceful drain менее критичен, но не верифицирован. **Проверить:** поведение Nitro-пресета `node-server` на SIGTERM. |
