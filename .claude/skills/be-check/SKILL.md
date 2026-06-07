---
name: be-check
description: "[backend] Run the full code quality pipeline (TypeScript + Biome + Knip), fix all issues, and clean up comments in changed code."
---

Thin pointer to a skill that lives in the **`backend`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd backend`
2. Read and follow `.agents/skills/check/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `backend/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
