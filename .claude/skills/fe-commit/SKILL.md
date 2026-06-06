---
name: fe-commit
description: "[litefront] Create a git commit with all unstaged changes. Use this skill whenever the user asks to commit, make a commit, save changes to git, or says something like \"commit this\", \"commit all changes\". Always runs npm run check before committing and fixes any errors found."
---

Thin pointer to a skill that lives in the **`litefront`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd litefront`
2. Read and follow `.agents/skills/commit/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `litefront/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
