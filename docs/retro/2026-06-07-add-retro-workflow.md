---
date: 2026-06-07
topic: Add session-retrospective workflow (docs/retro + /retro skill + commit/AGENTS wiring)
area: meta
tags: [skills, edit-tool, agents-md, workflow]
---

## What went badly
- Tried to `Edit` `.claude/skills/commit/SKILL.md` after only reading it via `cat` in Bash —
  the Edit failed: `File has not been read yet. Read it first before writing to it.` Cost a
  wasted tool call and a re-read.

## Root cause
- The Edit tool tracks file state from the **Read tool only**. Reading a file's contents
  through `Bash cat`/`head` does not register it as read, so Edit refuses the change.

## Rule — do this next time
- Before editing an existing file, open it with the **Read tool** (not `Bash cat`/`head`).
  If you inspected it via Bash, do a Read first, then Edit.
