# Team guide — working on LiteStack-derived projects

How a team creates and evolves a product built from LiteStack. Read this with the root
`AGENTS.md` (operating modes, git topology) — this doc covers the team process layered on top.

## Repo model: one shared meta per product (recommended)

A derived product is **three repos** owned by the team: meta + backend + frontend (submodules).

- **One shared meta-repo per product** — everyone clones the same meta. This is the default.
  Do **not** have each developer fork their own meta; the submodule pointers are shared state
  and per-dev forks make them diverge.
- Developers clone with `--recurse-submodules`, then run `scripts/setup.sh`.
- Work happens on **branches + PRs** in each repo (meta and/or submodules), not on `master`.

Forking is only for the **templates** themselves (`uxname/*`): to contribute a boilerplate
improvement upstream, branch the template, PR it, then bump the pointer (TEMPLATE mode).

## Creating the product

Use the **`new-project`** skill (it drives `scripts/rename-project.sh`, `setup.sh`, `doctor.sh`).
It produces the meta+submodules shape in DERIVED mode, repointed at the team's repos. See the
skill and `AGENTS.md → Deriving a new project`.

## Branch / PR flow (per repo)

Because backend and frontend are separate git repos, a cross-cutting change is several PRs:

1. Branch in the submodule(s) that change; open a PR there; merge after CI + review.
2. In the meta-repo, branch, bump the submodule pointer(s) to the merged commits, open a
   meta PR. **Never** point the meta at an unmerged/unpushed submodule commit.
3. Use the meta **`/commit`** skill — it enforces submodule-first ordering and the right push
   targets for the operating mode.

A change touching both sides: backend PR first (the frontend generates types from the live
backend schema), then frontend PR, then the meta pointer bump. See the `full-stack-feature` skill.

## CI

`.github/workflows/ci.yml` runs on the meta-repo: it checks out submodules recursively (which
validates the pinned pointers resolve) and runs each submodule's own quality gate in its own
job — **backend (liteend-go) = `task check` + `task test`** (Go), **frontend = `npm run check`**.
Each submodule also has its own lefthook hooks — backend pre-commit `task check` / pre-push
`task test:all`; frontend pre-commit `npm run check` / pre-push `check` + `test:all` — never
bypass with `--no-verify`. Frontend e2e tests are hermetic (mock auth + stubbed GraphQL), so
they need no live backend.

## Agent tooling — Claude Code & opencode parity

Both agents are first-class. Skill discovery paths each tool reads:

| Path | Claude Code | opencode |
|---|---|---|
| `.claude/skills/<name>/SKILL.md` | ✅ | ✅ (project-Claude compat) |
| `.agents/skills/<name>/SKILL.md` (inside a submodule) | ❌ | ✅ |
| `~/.claude/skills`, `~/.agents/skills` (global) | ✅ / ❌ | ✅ / ✅ |

Consequences for contributors:
- Meta skills + the `be-*`/`fe-*` wrappers live in `.claude/skills/` → **both** tools see them
  from the meta root.
- The real submodule skills live in `<submodule>/.agents/skills/` → opencode loads them
  un-prefixed when working inside a submodule; Claude Code reaches them via the meta wrappers.
- **All load-bearing instructions live in `AGENTS.md`**, which both tools read. The repo
  `CLAUDE.md` is only a pointer to `AGENTS.md` (Claude Code reads it; opencode reads `AGENTS.md`
  directly) — do not put unique guidance in `CLAUDE.md`.
- MCP (CodeGraph) is wired for both: `.mcp.json` (Claude Code) and `opencode.jsonc` (opencode).
  Run `npm run codegraph:setup` per clone; restart the agent afterward.

## Onboarding a new developer (checklist)

1. `git clone --recurse-submodules <meta-repo-url> && cd <dir>`
2. `scripts/setup.sh`
3. Copy `.env.example` → `.env` in each submodule; `scripts/doctor.sh` must pass.
4. Read `AGENTS.md`, `backend/AGENTS.md`, `frontend/AGENTS.md`, and `docs/retro/*`.
5. Restart the agent (Claude Code / opencode) to load the CodeGraph MCP server.
