---
name: retro
description: Write a session retrospective to docs/retro/ — what went wrong, its root cause, and the check or rule that stops it happening again. Use at the end of a session where a command failed, work was redone or an assumption proved wrong, or when the user asks for a retro or lessons learned.
---

A retro exists for **prevention**: the next agent reads `docs/retro/` before touching code
(root `AGENTS.md`, step 1), so every lesson must change what that agent does. The strongest
prevention is a **check** — a gate goes red on the mistake whether or not anyone read the
lesson. A written **rule** covers what no tool can see.

## Step 1: List what went wrong

Mine the session for mistakes, dead ends and wrong assumptions:

- commands and tests that failed (quote the error);
- wrong files edited, paths that did not exist, the wrong submodule touched;
- a convention misread (wrong Biome quote style, `lint` run instead of `npm run check`,
  `--no-verify`);
- a fix that was redone, reverted, or broke something else;
- time lost to a wrong model of how the code works.

Done when every such event of the session is on the list with its evidence. An empty list
means the session was clean: tell the user so and stop — a retro without a problem is noise.

## Step 2: Classify each problem — check or rule

- **Mechanical** — a fixed pattern a tool can see: a banned API or import, a file in the
  wrong place, a stale generated file, a skipped command. Its prevention is a **check**: a
  linter rule (golangci-lint, go-arch-lint, Biome, steiger), a lefthook command, or a test.
  Start from the gates that already run ([`docs/TEAM.md`](../../../docs/TEAM.md) →
  "Quality gates"): a check that exists but is unwired, skipped or silently green is the
  finding itself, and the fix is to repair it.
- **Judgement call** — needs context to see: the wrong layer, code that clashes with its
  surroundings, a misread requirement. Its prevention is a **rule**. A rule that should
  bind all future work, beyond warning about this one trap, belongs in the owning
  `CODING_STANDARDS.md` or `.agents/*.md` — propose moving it there.

Done when every problem carries one label and a concretely named prevention.

## Step 3: Write the file

Pick `area`: `backend`, `frontend`, `meta`, or `cross` (both submodules or the seam
between them). Take the date from `date +%F`. Filename:
`docs/retro/<YYYY-MM-DD>-<short-slug>.md`, slug = session topic in kebab-case; if today's
file for this topic exists, append to it.

Copy `docs/retro/TEMPLATE.md` exactly and fill every section, one fact per bullet:

- **What went badly** — the problems from Step 1.
- **Root cause** — why it happened, beneath the symptom.
- **Rule — do this next time** — one imperative, checkable line per problem. A judgement
  call states the behaviour: "Run `npm run check` in `frontend/` before declaring done —
  `lint` alone skips knip and steiger". A mechanical problem names its check: "Add
  `log.Printf` to the `forbidigo` list in `backend/.golangci.yml`", or "Enforced by
  `<check>`" once the check exists.

Frontmatter `date`, `topic`, `area`, `tags` is mandatory — readers filter on it. Quote
evidence with secrets redacted: write `<REDACTED>` in place of any token, password or
`.env` value.

Done when every problem has its root cause and its rule.

## Step 4: Hand off

Tell the user the path, then the proposed checks and rule moves, most severe first. Build
a check once the user agrees to it — it is a code change with its own gate and its own
commit.

The commit depends on the operating mode ([`.agents/OPERATING-MODE.md`](../../../.agents/OPERATING-MODE.md)):

- **DERIVED** — the `/commit` skill stages `docs/retro/` with the rest of the session.
- **TEMPLATE** — `docs/retro/` stays empty on purpose ([README](../../../docs/retro/README.md)):
  carry each lesson into its check or its owning doc, then delete the file before staging.
