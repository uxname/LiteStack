---
name: fe-add-gql
description: "[litefront] Use this skill when the user asks to add a GraphQL query, mutation, or subscription, fetch data from the API, or work with GraphQL operations. Trigger phrases: \"add graphql query\", \"add mutation\", \"add subscription\", \"graphql codegen\"."
---

Thin pointer to a skill that lives in the **`litefront`** submodule. The real
workflow stays there (next to the code it operates on); this wrapper only makes it
discoverable from the LiteStack root in both opencode and Claude Code.

## Do this

1. `cd litefront`
2. Read and follow `.agents/skills/add-gql/SKILL.md` **exactly** — it is the source of truth.
3. Use that project's quality gate (`npm run check`) before finishing.

## Important

- Run the steps **inside `litefront/`**, not at the meta root — the commands and paths assume that working directory.
- To commit afterwards, use the meta-level `commit` skill (handles submodule pointers + push mode).
