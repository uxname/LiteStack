---
name: fe-analyze-bundle
description: "[frontend] Use this skill when the user asks to analyze the bundle size, find large dependencies, optimize the build output, check what's included in the bundle, or reduce the app size. Trigger phrases: \"analyze bundle\", \"bundle size\", \"large bundle\", \"reduce bundle size\"."
---

Thin pointer to a skill that lives in the **`frontend`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd frontend`
2. Read and follow `.agents/skills/analyze-bundle/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `frontend/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
