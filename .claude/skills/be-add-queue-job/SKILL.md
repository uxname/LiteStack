---
name: be-add-queue-job
description: "[backend] Add a new BullMQ job queue to the project — processor, producer injection, module registration, Bull Board integration, and unit tests."
---

Thin pointer to a skill that lives in the **`backend`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd backend`
2. Read and follow `.agents/skills/add-queue-job/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `backend/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
