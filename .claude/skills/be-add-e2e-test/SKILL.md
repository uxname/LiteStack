---
name: be-add-e2e-test
description: "[liteend] Create an End-to-End (E2E) test for a REST controller or GraphQL resolver using Fastify injection."
---

Thin pointer to a skill that lives in the **`liteend`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd liteend`
2. Read and follow `.agents/skills/add-e2e-test/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `liteend/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
