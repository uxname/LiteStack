---
date: 2026-08-23
topic: skeptic subagents returned empty or truncated reports during deploy-path review
area: meta
tags: [subagents, orchestration, skeptics, review]
---

## What went badly
- Two of three `devsolo-skeptic` tasks returned a completely empty final message on the first launch.
- A third returned a full report but truncated mid-sentence inside finding #1, losing findings 2+ and the top-3 summary.
- Time was spent deciding whether to redo the whole investigation instead of recovering the existing one.

## Root cause
- Subagent final-message delivery is not guaranteed complete: nothing in the task result flags "empty" or "cut off", so incompleteness is only noticed by reading the output.
- The session continuation mechanism (`task_id`) exists precisely for this but is easy to forget when a result looks failed.

## Rule — do this next time
- After EVERY subagent task, check the result is non-empty AND ends where the prompt said it should end (e.g. the mandated top-3 block) before consuming it.
- On empty or truncated output, FIRST resume the same session via `task_id` with "re-emit your full report compactly" — only relaunch from scratch if resume fails too.
