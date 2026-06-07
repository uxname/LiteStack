---
name: fe-new-component
description: "[frontend] Use this skill when the user asks to create a new reusable UI component, shared UI element, or design system component. Strictly for shared/ui layer. Trigger phrases: \"new component\", \"new ui component\", \"create component\", \"add to shared/ui\"."
---

Thin pointer to a skill that lives in the **`frontend`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd frontend`
2. Read and follow `.agents/skills/new-component/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `frontend/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
