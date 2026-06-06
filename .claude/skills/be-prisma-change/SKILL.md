---
name: be-prisma-change
description: "[liteend] Guide through a full Prisma schema change workflow — edit schema, create migration, regenerate client, update affected services."
---

Thin pointer to a skill that lives in the **`liteend`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd liteend`
2. Read and follow `.agents/skills/prisma-change/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `liteend/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
