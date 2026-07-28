# Audit: bugs
## Контекст: runtime=node
## Coverage: BUG-01–10 — type coercion, async, null-safety, mutation, exhaustive, float, dates, ReDoS
## Результаты: ❌ 1 FAIL 🟡🟢

### ❌ FAIL 🟡🟢 BUG-010 — Type assertion bypass: `as unknown as AuthContextProps`
**Файл:** `src/features/auth/lib/stub-auth-value.ts:47`
**Проблема:** Используется `as unknown as AuthContextProps` для приведения типа, что полностью отключает type checking. Если react-oidc-context добавит новое обязательное поле, компилятор не поймает ошибку.
**Рекомендация:** Создать корректный объект, реализующий интерфейс AuthContextProps, вместо обходного приведения типов.
