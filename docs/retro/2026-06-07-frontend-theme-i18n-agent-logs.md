---
date: 2026-06-07
topic: Fix theme + locale switching, add Playwright agent log harness, wire i18n
area: frontend
tags: [playwright, i18n, paraglide, daisyui, theme, mock-auth, e2e]
---

## What went badly
- Verified the e2e suite against a manually-built preview on an alternate port, but built
  with plain `npm run build:vite` (no `VITE_MOCK_AUTH=true`). 4 auth tests false-failed:
  `getByRole('heading', { name: 'Identity Dashboard' })` timed out because `/protected`
  redirected — the real OIDC provider was used, so the mock-auth `localStorage` flag was
  ignored. Looked like a regression; was a build-env artifact.
- New Playwright spec imported `node:fs`/`node:path`; `npm run check` failed with
  `TS2591: Cannot find name 'node:fs'` — the spec is type-checked under the DOM-lib
  `tsconfig`, which doesn't pull in Node types for `tests/`.
- First theme "fix" attempt assumed the toggle was the bug. The toggle already worked
  (`data-theme` flipped); the real cause was the entire UI being styled with hardcoded
  Tailwind palette colors (`bg-white`, `text-slate-900`, …) instead of daisyUI semantic
  tokens, so the theme switch had nothing to act on.

## Root cause
- `VITE_*` vars are baked at **build time**. `playwright.config.ts`'s `webServer` builds with
  `VITE_MOCK_AUTH=true npm run build:vite`; a hand-rolled build/preview that omits it produces
  a binary where mock auth is off, so any auth-dependent test fails for reasons unrelated to
  the change under test.
- The repo's `tsconfig.json` has no `node` in `types`/`lib`; files under `tests/` that use Node
  built-ins need the Node types pulled in explicitly.
- Theme styling correctness depends on using semantic tokens; hardcoded palette colors silently
  ignore `data-theme`. The visible symptom (theme "not working") points away from the real
  cause (component styling).

## Rule — do this next time
- When running frontend e2e against a manual prod build, build with
  `VITE_MOCK_AUTH=true npm run build:vite` (mirror `playwright.config.ts`'s `webServer`), or
  auth-gated specs will false-fail. Don't read a `/protected` redirect as a code regression
  until you've confirmed the build had mock auth on.
- In a Playwright/`tests/` spec that uses Node built-ins (`node:fs`, `node:path`), add
  `/// <reference types="node" />` at the top so `npm run check` (tsc) passes.
- For daisyUI theme work, style with semantic tokens (`bg-base-*`, `text-base-content`,
  `text-primary/error/success/...`, `*-content`) — never hardcoded Tailwind palette colors. If
  a theme toggle "does nothing", grep for `slate-/gray-/bg-white` before touching the toggle.
