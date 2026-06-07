---
name: fe-add-auth-guard
description: "[frontend] Use this skill when the user asks to protect a route, add authentication to a page, restrict access to authenticated users, or work with OIDC/OAuth auth context. Trigger phrases: \"protect route\", \"auth guard\", \"restricted page\", \"protected route\"."
---

Thin pointer to a skill that lives in the **`frontend`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd frontend`
2. Read and follow `.agents/skills/add-auth-guard/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `frontend/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
