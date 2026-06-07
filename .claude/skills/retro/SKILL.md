---
name: retro
description: Write a session retrospective to docs/retro/ — what went badly this session, the root cause, and the rule to prevent repeating it. Use at the end of a work session before committing, when the user asks to "write a retro", "record a retrospective", "capture lessons", or "/retro". Runs automatically as the first step of the meta-level /commit skill.
---

The point of a retro is **future prevention**, not a changelog. Capture what went *wrong*
this session so the next agent — which reads `docs/retro/*` before touching code — does not
repeat it. Successes are irrelevant here.

## Step 1: Reconstruct what went badly this session

Look back over the session and list only the **mistakes, dead ends, and wrong assumptions**.
Concrete signals to mine:

- Commands/tests that failed and why (quote the error).
- Wrong files edited, paths assumed that didn't exist, wrong submodule touched.
- Doc/convention misread (e.g. wrong Biome quote style, skipped `npm run check`, used `--no-verify`).
- A fix that had to be redone, reverted, or that broke something else.
- Time lost to a wrong mental model of how the code works.

If the session was genuinely clean (no mistakes), say so to the user and **do not** write an
empty retro file. A retro with no problems is noise.

## Step 2: Pick the area and a filename

Decide `area`: `backend` (only `backend/` touched), `frontend` (only `frontend/`), `meta`
(only meta-repo files), or `cross` (spanned both submodules or the seam between them).

```bash
date +%F        # use this real date — never guess
```

Filename: `docs/retro/<YYYY-MM-DD>-<short-slug>.md`. Slug = session topic, kebab-case.
If a file for today's topic already exists, append to it rather than overwriting.

## Step 3: Write the file

Copy `docs/retro/TEMPLATE.md` exactly. Fill every section:

- **What went badly** — one concrete fact per bullet.
- **Root cause** — the underlying reason, not the symptom.
- **Rule — do this next time** — one imperative line per problem. This is the payload the
  next agent acts on. Make it specific and checkable (e.g. "Run `npm run check` in
  `frontend/` before declaring done — `lint` alone skips knip/steiger").

Frontmatter `date`, `topic`, `area`, `tags` are mandatory — the reader subagent filters on them.

## Step 4: Confirm

Tell the user the path written and a one-line summary of the rules captured. Do **not** commit
here — the `/commit` skill stages and commits `docs/retro/` with the rest of the session.

## What NOT to do

- Don't record successes or a play-by-play of the session.
- Don't invent generic best-practice advice — only lessons from mistakes that actually happened.
- Don't write secrets (`.env`, tokens, credentials) into the retro.
- Don't leave a problem without a matching rule.
