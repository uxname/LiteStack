---
date: 2026-07-28
topic: Dependency refresh, parallel audit, and splitting AGENTS.md into topic files
area: cross
tags: [gates, docs-split, subagents, rename-project, verification]
---

## What went badly

- Trusted `task check | tail` and reported the backend gate green. It had **failed** —
  the pipeline's exit status came from `tail`. Two later findings were built on that
  false green before the mistake surfaced.
- Split three `AGENTS.md` files into `.agents/*.md`, verified links with a script, and
  reported "0 broken links". True and useless: the script only understood
  `[text](path)`, while seven **prose** pointers (`` `AGENTS.md` → Operating mode ``)
  still aimed at sections the same commit had moved out. README's layout tree and
  Skills paragraph also still described the 15 skills deleted in that commit.
- Rebuilt `rename-project.sh`'s brand-file list from `grep -rn LiteFront frontend/src`
  and declared it complete. It missed `frontend/tests/` — one E2E test asserts the page
  title and the screenshot harness seeds the theme key — so a derived project would
  have had a failing `verify:push` and a harness silently no longer capturing dark mode.
  Then missed `.github/logo.svg`, whose `<title>` this same session had added.
- Deleted the previous audit's Russian reports and claimed their lessons survived in
  `docs/retro/`. They did not: that retro is about Docker and env handling, and two live
  findings (the production image ignoring the lockfile, SSR errors never reaching
  Sentry) existed nowhere else.
- Accepted a subagent's "proved by experiment" claim that steiger ignores `tsconfig`
  aliases, which would have meant the FSD gate was inert. It resolves them fine — the
  agent had run its probe on a copy of `src/` in a scratch directory with no
  `tsconfig.json` beside it.
- Wrote an SSR regression test with `@testing-library/react`. It failed for the wrong
  reason: `render` itself needs a DOM and threw before the component was reached.

## Root cause

- Confusing *the command* with *the pipeline it was piped into*, and treating a
  convenient-looking tail as evidence.
- Verifying the mechanism that is easy to automate (markdown links) and calling it
  coverage of the risk (any reference, including prose).
- Choosing a search scope that matched where the code lives rather than where the
  string lives — twice, in the same file list.
- Asserting a claim about where content survives without opening the file that was
  supposed to contain it.
- Accepting an experiment's conclusion without checking that the experiment ran in an
  environment where the tool could work at all.

## Rule — do this next time

- Never judge a gate by piped output. Run it bare and read `$status`, or redirect to a
  file and check the status separately — `cmd | tail` reports the tail's success.
- After moving a documented section, grep for **prose** references to its old home
  (`grep -rn 'AGENTS.md' --include=*.md`), not just markdown links. A link checker
  returning zero is necessary, not sufficient.
- When a script hard-codes a list of files, derive it from a grep over the **whole**
  submodule (excluding `node_modules`, build output and generated code), then diff the
  script's own `--dry-run` output against that list. Never eyeball it, and never scope
  the grep to `src/`.
- Before deleting a document, open whatever you claim preserves its content and confirm
  each item is actually there. "The lessons live elsewhere" is a checkable statement.
- Probe a config-dependent linter (steiger, biome, tsc, knip) **inside the real
  project**, then clean the probe up. A detached copy of the tree silently disables it,
  and the resulting silence looks like a passing gate.
- To test SSR-safety, use `renderToString` from `react-dom/server`, not
  `@testing-library/react` — the latter requires a DOM and fails before your code runs.
  Then prove the test has teeth by restoring the bug and watching it go red.
