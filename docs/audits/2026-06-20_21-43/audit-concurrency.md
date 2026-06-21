# Audit Report: State & Concurrency — 2026-06-20 21:43

Runtime: браузер (React 19 + TanStack Start) + SSR (Node.js). Стек: zustand, urql + @urql/exchange-graphcache + @urql/exchange-retry, oidc-client-ts / react-oidc-context, react-hook-form.

## Осталось сделать (backlog)

| Check ID | Проверка | Sev | Доказательство | Решение |
|----------|----------|-----|----------------|---------|
| CON-06 | Background async операции имеют механизм отмены (AbortController/signal) | 🟡 | Аплоад аватара `features/profile/api/upload-avatar.ts:23` уже имеет таймаут (`AbortSignal.timeout(30000)`, см. ERR-05), но НЕ имеет внешней отмены: если пользователь ушёл со страницы (или выбрал другой файл) до ответа, запрос не отменяется; по возврату промиса `setValue("avatarUrl", url)` (`useProfileForm.ts:54`) может выполниться на размонтированном компоненте → предупреждение React и запись stale-URL. | Прокинуть внешний `AbortController` из компонента в `uploadAvatar` (signal в fetch), отменять в cleanup `useEffect`/при новом выборе файла. Скомбинировать unmount-сигнал с существующим timeout-сигналом через `AbortSignal.any([...])`. |

## Требует ручной проверки

| Check ID | Проверка | Доказательство |
|----------|----------|----------------|
| CON-05 | Обработчики событий и webhook-handlers идемпотентны | OIDC callback не обрабатывается вручную: `routes/callback.tsx` только показывает спиннер + один `captureMessage` в `useEffect` (`:12-14`), без обмена code→token. Сам обмен и защита от повторного использования `code`/`state` выполняется библиотекой `react-oidc-context`/`oidc-client-ts` (`onSigninCallback`, `AppProviders.tsx:24-38`) — это внешний код, статически идемпотентность подтвердить нельзя. `[⚡ dynamic]` |
