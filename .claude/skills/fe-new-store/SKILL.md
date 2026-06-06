---
name: fe-new-store
description: "[litefront] Use this skill when the user asks to create a new Zustand store, add global state, add client state management, or create a state slice. Trigger phrases: \"new store\", \"state management\", \"add state\", \"zustand store\"."
---

Thin pointer to a skill that lives in the **`litefront`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd litefront`
2. Read and follow `.agents/skills/new-store/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `litefront/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
