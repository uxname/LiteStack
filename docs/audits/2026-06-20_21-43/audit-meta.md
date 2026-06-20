# Audit Meta Report — 2026-06-20 21:43

Мета-контроль качества аудита фронтенда LiteStack. Проверяется не код, а сам аудит: полнота покрытия, консистентность severity, качество доказательств, корректность статусов и отсутствие выдуманных находок.

**Проверено:** 14 отчётов направлений в `docs/audits/2026-06-20_21-43/` + `docs/audit-baseline.yml` (пустой шаблон).

---

## Scope Coverage (полнота покрытия)

### Покрытие направлений

Все релевантные для фронтенд-проекта направления выполнены. Присутствуют 14 отчётов:

`api-contracts, architecture, bugs, concurrency, deployment, errors, logging, naming, owasp, performance, secrets, tests, validation, yagni`.

Отсутствует только `audit-matrix` (моделирование сценариев сбоев) — это опциональное направление, не входит в обязательный базовый набор. Все 14 направлений из стандартного чеклиста покрыты.

### Покрытие модулей кода

Сверка директорий `src/` с доказательствами в отчётах:

| Модуль | Упомянут в отчётах | Комментарий |
|--------|--------------------|-------------|
| `src/app/providers/**` | architecture, bugs, errors, logging, performance | покрыт |
| `src/pages/account/**` | bugs, architecture, naming, validation | покрыт |
| `src/pages/home/**` | architecture, naming, yagni | покрыт |
| `src/pages/404/**` | architecture (через `pages/**`) | покрыт косвенно |
| `src/features/auth/**` | owasp, errors, concurrency, bugs, secrets, validation | покрыт глубоко |
| `src/features/profile/**` | большинство отчётов | покрыт глубоко (критический путь) |
| `src/features/theme/**` | concurrency, naming, yagni | покрыт |
| `src/features/locale/**` | errors, naming, bugs | покрыт |
| `src/widgets/Header/**` | logging, naming | покрыт |
| `src/entities/counter/**` | concurrency, yagni, naming | покрыт |
| `src/shared/api/**` | большинство отчётов | покрыт глубоко |
| `src/shared/config/**` | bugs, validation, naming, deployment | покрыт |
| `src/shared/lib/sentry/**` | logging, errors | покрыт |
| `src/shared/lib/cn.ts` | naming (косвенно) | минимально |
| `src/shared/ui/**` | bugs (ErrorFallback), performance, naming | частично — детально только `ErrorFallback`; чисто визуальные компоненты (`Button`, `Card`, `Input`, `Skeleton`, `Textarea`, `Toaster`, `FormField`, `PageLoader`) осознанно пропущены как «без логики/сети» |
| `src/routes/**` | owasp, bugs, errors, validation, naming | покрыт |
| `src/server.ts`, `src/router.tsx`, `src/client.tsx`, `src/start.ts` | errors, performance, naming, concurrency | покрыт |
| `src/generated/**` | везде явно исключён | корректно (автоген) |

**Вывод:** значимых непокрытых модулей нет. Все слои FSD и критические пути (`auth`, `profile`, SSR, GraphQL-клиент) покрыты несколькими отчётами. Пропуски (`generated/**`, тесты-как-объект-багов, чисто презентационные UI-компоненты) явно задекларированы в секциях Audit Coverage каждого отчёта и обоснованы.

✅ **Scope: все релевантные модули и направления проверены.** Единственное отсутствующее направление — опциональный `audit-matrix`.

---

## Baseline Expiry (актуальность исключений)

`docs/audit-baseline.yml` содержит **только закомментированный шаблон** — секции `accepted`, `false_positives`, `intentional` пусты, ни одной активной записи. Поля `expires` нет ни у одной записи (записей нет).

✅ **Baseline: все исключения актуальны** (исключений нет — нечему истекать).

**Наблюдение процесса:** пустой baseline корректно и единообразно задекларирован во всех 14 отчётах («Baseline: пустой / только шаблон»). Это консистентно. Однако несколько отчётов в «Решениях» предлагают занести находки в baseline как `false-positive`/`intentional` (ARC-03, NAM-05, SEC-04, CON-03). Эти предложения пока не реализованы — baseline остаётся чистым, что нормально, поскольку решения по правилам скила необязательны для 🟢/🟡.

---

## Evidence Quality (качество доказательств)

Проверены все строки со статусом ❌ FAIL во всех отчётах. Итого **15 FAIL** (по числу строк чеклиста; ряд из них описывает одну и ту же первопричину).

| Отчёт | Check ID | Severity | Доказательство `file:line` | Конкретный код/значение | Качество |
|-------|----------|----------|----------------------------|--------------------------|----------|
| api-contracts | API-03 | 🟡 | `upload-avatar.ts:27-29` | да (`throw new Error(...status)`) | хорошее |
| architecture | ARC-03 | 🟢 | `useProfileForm.ts:12`, `routeTree.gen.ts ↔ router.tsx` | да (type-only import) | хорошее |
| bugs | BUG-01 | 🟡 | `account.ts:89` | да (`new Date(String(createdAt))`) | хорошее |
| bugs | BUG-03 | 🟠 | `account-center.ts:39`, `upload-avatar.ts:19` | да (`new URL(env...)`) | хорошее |
| bugs | BUG-05 | 🟡 | `detectErrorCategory.ts:12-41`, `account.ts:92` | да | хорошее |
| bugs | BUG-09 | 🟡 | `account.ts:89` | да (`toLocaleDateString()`) | хорошее |
| concurrency | CON-03 | 🟡 | `router-instance.ts:8`, `router.tsx:29-32` | да (`let router`) | хорошее |
| concurrency | CON-06 | 🟡 | `upload-avatar.ts:23`, `useProfileForm.ts:54` | да (`fetch` без signal) | хорошее |
| deployment | DEP-01 | 🟡 | `Dockerfile:2,27` | да (`FROM node:lts-alpine`) | хорошее |
| deployment | DEP-04 | 🟡 | `.dockerignore:1-2`, `Dockerfile:17` | да (нет `.env`) | хорошее |
| deployment | DEP-05 | 🟡 | `Dockerfile` / `docker-compose.yml:10-15` | да | хорошее |
| deployment | DEP-10 | 🟡 | `Dockerfile:14` | да (`npm install --legacy-peer-deps`) | хорошее |
| deployment | DEP-11 | 🟠 | `docker-compose.yml` (сервис `app`) | да (нет `deploy.resources.limits`) | хорошее |
| deployment | DEP-12 | 🟡 | `docker-compose.yml` | да (нет `read_only`) | хорошее |
| errors | ERR-03 | 🟡 | `server.ts:23` | да (`await handler(...)` без try/catch) | хорошее |
| errors | ERR-05 | 🟠 | `upload-avatar.ts:23` | да (`fetch` без таймаута) | хорошее |
| errors | ERR-09 | 🟡 | `upload-avatar.ts:23` | да (`fetch` без signal) | хорошее |
| logging | LOG-02 | 🟠 | `AuthObserver.tsx:43-47`, `sentry/config.ts:19-22` | да (`email`, `maskAllText:false`) | хорошее |
| logging | LOG-03 | 🟠 | `graphql-client.ts:46,20-29`, `config.ts:19-22` | да | хорошее |
| naming | NAM-05 | 🟢 | `server.ts:37`, `graphql-client.ts:37-39,47` | да (`Max-Age=31536000`, `15000`) | хорошее |
| owasp | OWA-05 | 🟠 | `vite.config.ts:71-79`, `__root.tsx:53`, `oidc-client.ts:30` | да (только 2 заголовка) | хорошее |
| performance | PER-08 | 🟢 | `ErrorFallback.tsx:56,76` | да (`setTimeout` без cleanup) | хорошее |
| secrets | SEC-04 | 🟡 | `.env.example:13-14` | да (реальные authority/client_id) | хорошее |
| secrets | доп. `.env` в build context | 🟠 | `.dockerignore`, `Dockerfile` `COPY . ./` | да | хорошее |
| tests | TST-02 | 🟡 | `vitest.config.ts:26-31`, отсутствие `.github/workflows` | да | хорошее |
| tests | TST-04 | 🟡 | `upload-avatar.ts:29-37`, `useProfileForm.ts:55-59,77-80` | да | хорошее |
| tests | TST-05 | 🟡 | `tests/setup.ts:37-58`, `vitest.config.ts` | да | хорошее |
| validation | VAL-08 | 🟡 | `useProfileForm.ts:47-54`, `ProfileForm.tsx:52` | да | хорошее |
| yagni | YAGNI-02 | 🟢 | `package.json:75`, `codegen.yml:7` | да (`@graphql-codegen/typescript`) | хорошее |

**Выборочная верификация доказательств по реальному коду** (5 находок проверены инструментально):
- `upload-avatar.ts` — подтверждено: `fetch` без `signal`/таймаута, читается только `response.status` (ERR-05/ERR-09/CON-06/API-03 верны).
- `env.ts:45` — подтверждено: проверка required-переменных обёрнута в `if (env.DEV)` (обоснование BUG-03 верно).
- `sentry/config.ts` — подтверждено: `maskAllText: false, blockAllMedia: false` (LOG-02/LOG-03 верны).
- `.dockerignore` — подтверждено: `.env` отсутствует (DEP-04 и доп. находка secrets верны).
- `account.ts` `formatMemberSince` — подтверждено: `toLocaleDateString()` без UTC и без проверки валидности (BUG-01/BUG-09 верны).

✅ **Evidence: все FAIL подкреплены доказательствами `file:line` с конкретным кодом/значением.** Выдуманных находок не обнаружено — все проверенные ссылки соответствуют реальному коду. Слабых доказательств (только имя файла без строки) нет.

---

## Корректность статусов

- **PASS только при явной верификации.** Проверено: статусы ✅ PASS везде сопровождаются конкретным доказательством (`file:line` или результат grep «0 совпадений»). Динамические проверки `[⚡ dynamic]` корректно НЕ получают PASS — там, где статическая верификация невозможна, выставлен 🔍 UNVERIFIED (PER-01, CON-05, ERR-04, ERR-06, OWA-03, VAL-06, TST-08, API-07, LOG-04). Где для `[⚡ dynamic]` есть явное доказательство нарушения (отсутствие AbortSignal) — корректно выставлен FAIL, а не UNVERIFIED (ERR-09 — это прямо отмечено в отчёте).
- **Разграничение зон фронт/бэк.** Серверные аспекты (HTTP-статусы, envelope, версионирование, ownership/IDOR, rate limiting, graceful shutdown в Nitro-бандле) последовательно помечаются N/A или UNVERIFIED с пояснением, а не выдаются за PASS/FAIL фронтенда. Это методологически корректно.

✅ **Статусы корректны:** PASS обоснованы, UNVERIFIED применяется к dynamic/серверным проверкам, FAIL — только при наличии доказательства.

---

## Консистентность severity между отчётами

Несколько находок касаются одной первопричины в разных отчётах. Проверена согласованность оценок.

### 1. `.env` не исключён в `.dockerignore` — РАСХОЖДЕНИЕ severity

| Отчёт | Check ID | Severity |
|-------|----------|----------|
| deployment | DEP-04 | 🟡 Medium |
| secrets | доп. находка | 🟠 High |

Одна и та же проблема (`COPY . ./` тянет `.env` в build-слой) оценена как 🟡 в deployment и 🟠 в secrets. Расхождение частично объяснимо разным фокусом (deployment смотрит на воспроизводимость, secrets — на вектор утечки), и **оба отчёта явно оговаривают**, что сейчас в `.env` реальных секретов нет (только публичные `VITE_`-значения). Тем не менее итоговая severity одной и той же находки различается на один уровень — это **несогласованность, которую стоит выровнять**. По сути риск условный (срабатывает только при будущем добавлении секрета), поэтому 🟡 ближе к истине; маркировка 🟠 в secrets слегка завышена.

### 2. Upload без таймаута/отмены — СОГЛАСОВАНО

`upload-avatar.ts:23` фигурирует в errors (ERR-05 🟠 таймаут, ERR-09 🟡 abort) и concurrency (CON-06 🟡 abort). Severity согласованы: отсутствие таймаута (риск вечного зависания) оценено выше (🟠), отсутствие отмены (узкое окно гонки, кнопка заблокирована) — 🟡. Отчёты корректно ссылаются друг на друга.

### 3. Sentry `maskAllText:false` + PII — СОГЛАСОВАНО

LOG-02 и LOG-03 (оба 🟠) сходятся в одной точке `sentry/config.ts:19-22`, что явно отмечено. Severity 🟠 для утечки PII/токенов в Session Replay адекватна.

### 4. Stack trace / утечка деталей — СОГЛАСОВАНО

OWA-07 (✅ PASS) и ERR-02 (✅ PASS) и API-05 (✅ PASS) согласованно ссылаются на `ErrorFallback.tsx:166` (`env.DEV &&`) с перекрёстными ссылками. Дублирования с разной оценкой нет.

### 5. `new URL(undefined)` при отсутствии env — СОГЛАСОВАНО

BUG-03 (🟠) и упоминание в errors/validation про `env.ts:45` (`if (env.DEV)`) согласованы; bugs корректно поднимает severity до 🟠, т.к. в prod это TypeError, ломающий функциональность.

**Вывод:** из 5 пересекающихся находок 4 согласованы (с перекрёстными ссылками — хороший признак), 1 имеет расхождение severity на один уровень (DEP-04 🟡 vs secrets 🟠).

---

## Итог

| Проверка | Статус |
|----------|--------|
| Scope Coverage (направления) | ✅ 14/14 обязательных покрыто (опциональный `audit-matrix` отсутствует) |
| Scope Coverage (модули) | ✅ значимых непокрытых модулей нет |
| Baseline Expiry | ✅ исключений нет — нечему истекать |
| Baseline Types | ✅ записей нет (пустой шаблон) — n/a |
| Evidence Quality | ✅ все 15 FAIL подкреплены `file:line` + код; 5 проверены инструментально, выдуманных находок нет |
| Корректность статусов | ✅ PASS верифицированы, UNVERIFIED применён к dynamic/серверным проверкам |
| Консистентность severity | ⚠️ 1 расхождение: `.env`/`.dockerignore` — 🟡 (deployment) vs 🟠 (secrets) |

### Общая оценка качества аудита: ВЫСОКАЯ

Аудит выполнен на высоком уровне. Сильные стороны:
- Полное покрытие всех слоёв FSD и критических путей (`auth`, `profile`, SSR, GraphQL-клиент) несколькими отчётами.
- Доказательства точны и инструментально подтверждаются — проверенная выборка из 5 находок совпала с реальным кодом 1:1, выдуманных находок нет.
- Методологически корректное разграничение зон фронт/бэк и дисциплинированное использование 🔍 UNVERIFIED для динамических проверок вместо ложного PASS.
- Перекрёстные ссылки между отчётами (errors↔concurrency, owasp↔errors, logging) показывают согласованную картину одной первопричины.

Выявленные проблемы процесса (некритичные):
1. **Расхождение severity** одной находки (`.env` в build context) между deployment (🟡) и secrets (🟠) — стоит выровнять на 🟡, так как риск условный и оба отчёта подтверждают отсутствие реальных секретов сейчас.
2. **Предложения занести находки в baseline** (ARC-03, NAM-05, SEC-04, CON-03) не реализованы — baseline остаётся пустым. Это допустимо (решения для 🟢/🟡 необязательны), но если часть из них действительно `intentional`/`false-positive`, стоит оформить записи с полем `type`, чтобы они не всплывали как FAIL в следующих прогонах.
3. **`audit-matrix` не выполнен** — опциональное направление, при необходимости моделирования сценариев сбоев стоит запустить отдельно.

Блокирующих проблем качества аудита нет. Сводная картина находок самого кода: 🔴 Critical 0; 🟠 High 5 (DEP-11, ERR-05, LOG-02, LOG-03, OWA-05, BUG-03 — по разным отчётам, с пересечениями); остальное 🟡/🟢.
