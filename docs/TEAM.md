# Team guide — working on LiteStack-derived projects

How a team creates and evolves a product built from LiteStack. Read this with the root
`AGENTS.md` (operating modes, git topology) — this doc covers the team process layered on top.

## Repo model: one shared meta per product (recommended)

A derived product is **three repos** owned by the team: meta + backend + frontend (submodules).

- **One shared meta-repo per product** — everyone clones the same meta. This is the default.
  Do **not** have each developer fork their own meta; the submodule pointers are shared state
  and per-dev forks make them diverge.
- Developers clone with `--recurse-submodules`, then run `scripts/setup.sh`.
- Work happens on `master` in each repo; the pre-commit and pre-push hooks are the
  guarantee, not review. In a derived product's team branches and pull requests are a
  **recommendation** — nothing in the tooling assumes them.

Forking is only for the **templates** themselves (`uxname/*`): a boilerplate improvement
goes to the template's `master`, then the pointer moves. An outside contributor without
push rights opens a pull request instead.

## Creating the product

Use the **`new-project`** skill (it drives `scripts/rename-project.sh`, `setup.sh`, `doctor.sh`).
It produces the meta+submodules shape in DERIVED mode, repointed at the team's repos. See the
skill and [`../.agents/DERIVE.md`](../.agents/DERIVE.md).

## A cross-repo change, in order

A change that touches a submodule is two commits in two repositories: commit and
**push** in the submodule, then bump that pointer in the meta-repo. **Never** point
the meta at a submodule commit that is not pushed — on someone else's clone the
change simply is not there. The meta **`/commit`** skill does this ordering for you.

## Quality gates (no CI)

There is **no CI service** — LiteStack is a template and forks may run on any host (GitLab,
Gitea, Drone, …), so the entire quality guarantee lives in lefthook git hooks. In the two
submodules, fast checks run on `pre-commit` and the slow, full gate on `pre-push` (the last
line before code leaves the machine); the meta-repo has a small `pre-commit` of its own for
the artefacts it owns.

| Repo | pre-commit | pre-push |
|---|---|---|
| **backend** (Go) | `task check` (codegen-freshness, tidy, lint, arch, deadcode, secrets) | `task test:cov` (unit + integration via testcontainers + coverage floors; needs Docker), `task vuln` (govulncheck — the only gate that needs the network) |
| **frontend** (npm) | `npm run verify:commit` (`check` + gitleaks `secrets`) | `npm run verify:push` (`verify:commit` + `test:cov` + Playwright E2E + Storybook build) |
| **meta** (npm) | `npm run scale:validate` (compose + Caddyfile syntax), `npm run likec4:validate` (the architecture model, [ADR-0003](./adr/0003-living-likec4-model.md)) and `npm run secrets` (gitleaks on the staged diff, skipped if not installed) | — (nothing slow to run) |

Hooks are thin — they just call those npm/task scripts, so you can run the exact same gate by
hand. `--no-verify` skips them and nothing else will catch it, so don't. Frontend E2E tests are
hermetic (mock auth + stubbed GraphQL), so they need no live backend.

## Agent tooling — Claude Code & opencode parity

Both agents are first-class, and the instruction layout is deliberately chosen so neither
tool has an advantage.

**Instructions, not skills, carry the workflows.** Each project has one entry point —
`AGENTS.md` — that holds the non-negotiable rules plus a routing table into topic files
under its own `.agents/` directory (`ARCHITECTURE.md`, `TESTING.md`, `QUALITY-GATES.md`, …).
Every agent reads plain files, so this works identically everywhere, and an agent loads
only the file its task needs instead of one long document.

Skills are reserved for **genuinely cross-project orchestration** and live in
`.claude/skills/`, which both tools read from the meta root: `full-stack-feature`,
`commit`, `retro`, `new-project`. The submodules ship none — a one-sided workflow belongs
in that submodule's `.agents/` file, so there is exactly one place per topic and nothing
to keep in sync.

Consequences for contributors:
- Adding guidance? Put it in the right `.agents/*.md` and, if a new topic, add one row to
  that project's `AGENTS.md` routing table. Don't grow `AGENTS.md` itself.
- **Every shared value has one owner file** — every other file, of any type, points at
  it. The owner table is in [`../.agents/CROSS-PROJECT.md`](../.agents/CROSS-PROJECT.md).
  Every copied value in this repo has drifted at least once.
- The repo `CLAUDE.md` is only a pointer to `AGENTS.md` — do not put unique guidance there.

## Onboarding a new developer (checklist)

1. `git clone --recurse-submodules <meta-repo-url> && cd <dir>`
2. `scripts/setup.sh` — one command: toolchain, submodules, both `.env` files, contract check.
3. Both pages answer: `http://localhost:3000` and `http://localhost:4000/readyz`.
