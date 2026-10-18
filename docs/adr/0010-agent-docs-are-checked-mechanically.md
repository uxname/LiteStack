# ADR 0010: The agent docs' links and command names are checked on every meta commit

- **Date:** 2026-10-18
- **Status:** accepted

## Context

Agents act on what `AGENTS.md`, `CLAUDE.md`, `.agents/*.md` and the skills tell them. In
all three repos those files hold about 140 references that can go stale without anyone
noticing: relative Markdown links, `@` imports in `CLAUDE.md`, `task <name>` and
`npm run <name>` commands. A renamed file, task or npm script leaves the agent with a
false instruction, and nothing fails — meta ADR-0007 leaves documentation drift to a
periodic audit, on no calendar.

Projects that adopted coding agents widely check the same thing mechanically (7 of 24
surveyed in full, 4 partly — e.g. a docsync test in beads, `make lint/agents` in coder). A
pilot here caught 4 of 4 injected breakages with no false positive on the clean tree.

## Decision

`scripts/check-agent-docs.mjs` runs in the meta-repo's pre-commit hook and fails when a
relative link or `@` import in an agent doc points at nothing, or a `` `task <name>` `` /
`` `npm run <name>` `` names a task or script that no `Taskfile.yml` / `package.json` in
the repo tree defines. It is plain Node with no dependencies, regexes and file existence
only — no model, no network.

Its limits are deliberate:

- **Existence, not meaning.** "`task lint` runs the tests" passes as long as `lint`
  exists. Semantic drift stays with the audit ADR-0007 describes.
- **Names are matched against the union** of every Taskfile and `package.json`, not the
  sub-project a doc belongs to: the root `AGENTS.md` says `npm run check` and means the
  frontend's.
- A command counts only in backticks, so one inside a fenced code block goes unchecked;
  anchors (`#…`) are not checked; only the listed file kinds are read.

## Alternatives

- **Keep it to the periodic audit** — the audit happens on no calendar, so a broken link
  lives until someone happens to look; the check costs well under a second per commit.
- **A check per sub-project hook** — the docs cross repo borders (the root routes into
  both submodules), so the meta, which sees all three, is the one place it can run whole.
- **An LLM reviewer for meaning too** — needs a network and a key in a hook, is
  non-deterministic, and ADR-0001 rules out the CI it would otherwise live in.

## Consequences

- Renaming a file, task or npm script that a doc names fails the next meta commit until
  the doc follows. A rename made inside a submodule is caught only when the meta commits
  the pointer — which is the step that publishes it to the template anyway.
- It extends meta ADR-0001: the meta hook now has three checks (model, agent docs,
  secrets), plus the checker's own test (`scripts/check-agent-docs.test.mjs`) when the
  checker changes. Like every hook, `--no-verify` skips it.
- A new kind of agent file (another tool's folder) is unchecked until its glob is added.
