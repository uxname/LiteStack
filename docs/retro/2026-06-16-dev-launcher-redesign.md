---
date: 2026-06-16
topic: Redesign of the /dev launcher page (backend)
area: backend
tags: [devtools, bash, fish, working-directory]
---

## What went badly
- Re-ran `cd backend` in a later Bash call and it failed with "Нет такого файла или каталога: backend" — the previous call had already left the shell inside `backend/`, so the relative path no longer existed.

## Root cause
- The Bash tool's working directory persists across calls; treating each call as if it started from the meta-repo root caused a redundant `cd` into an already-current directory.

## Rule — do this next time
- Don't re-`cd` into a submodule the previous Bash call already entered — the working directory persists between calls; check the current dir or use absolute paths instead of repeating relative `cd`.
