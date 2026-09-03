# AGENTS.md — LiteStack (meta-project)

LiteStack is a **full-stack boilerplate**, not a runnable product. It bundles two real
projects as git submodules and adds a thin coordination layer:

- **`backend/`** — the backend project (**liteend-go**, its own repo). All server code.
- **`frontend/`** — the frontend project (**litefront**, its own repo). All browser code.
- **LiteStack** (this repo) — owns **no application code**. It only coordinates: which
  project to touch, how the two connect, and how to commit across them.

**This file is the entry point, not the whole manual.** Read the file that matches your
task — don't read them all.

## Three boxes — put each change in the right one

| You are changing… | Go to | Why |
|---|---|---|
| API, database, business logic, background jobs, server-side GraphQL | **`backend/`** | it owns all server behaviour |
| UI, pages, routing, client state, styling, GraphQL the browser sends | **`frontend/`** | it owns everything in the browser |
| How the two fit together, this guide, cross-project skills, submodule pointers | **LiteStack root** | the meta-project only coordinates |

Rule of thumb: **never put application code in the meta-project.** Writing a resolver, a
component or a migration means you are in the wrong folder — go into a submodule.

## 🔴 Start here

### 1. Read the retrospectives — learn from past mistakes

Before touching code, read every `docs/retro/*.md`. These record what went wrong in past
sessions, each ending in a one-line **rule**. Reading them first is how you avoid
repeating a mistake this project already paid for.

**Do it in a separate thread so it doesn't bloat your working context.** Spawn a subagent
with this instruction:

> Read every file in `docs/retro/*.md` (skip `README.md` and `TEMPLATE.md`). Return ONLY
> a deduplicated, compact list of the **Rule — do this next time** lines, grouped by area
> (backend / frontend / meta / cross). No file dumps, no narrative — just the rules.

Apply the returned rules to the work you are about to do. If `docs/retro/` has no retro
files yet, there is nothing to read — continue.

### 2. Read the sub-project's own AGENTS.md

`backend/AGENTS.md` or `frontend/AGENTS.md` is the source of truth for that side, and
each routes you onward to its `.agents/*.md`. This root file covers only what spans
**both**. **On any conflict inside a sub-project, that sub-project wins.**

### 3. End of session — write a retrospective before committing

Run the **`/retro` skill** to record what went badly into `docs/retro/`. The `/commit`
skill runs it automatically as its first step. This is what closes the loop: today's
mistakes become tomorrow's rules.

## Where to look

| Your task | Read |
|---|---|
| Decide where to commit and push; git/submodule mechanics | [.agents/OPERATING-MODE.md](./.agents/OPERATING-MODE.md) |
| The back ↔ front seams (codegen, auth audience, CORS + WebSockets), shared conventions, project map | [.agents/CROSS-PROJECT.md](./.agents/CROSS-PROJECT.md) |
| Start a real product from this template | [.agents/DERIVE.md](./.agents/DERIVE.md) |
| Which env vars must match across sides | [docs/ENV-CONTRACT.md](./docs/ENV-CONTRACT.md) |
| Deploy it: local Docker, Dokploy production, registry images | [docs/DEPLOY.md](./docs/DEPLOY.md) |
| Team process: repo model, branch/PR flow, gates | [docs/TEAM.md](./docs/TEAM.md) |
| "See" what the frontend does at runtime (you have no browser) | [frontend/.agents/OBSERVABILITY.md](./frontend/.agents/OBSERVABILITY.md) |
| Known open issues and what was already audited | latest `docs/audits/*/audit-report.md` — **empty in the template**, an audit run creates the first one |
| Anything backend-specific | [backend/AGENTS.md](./backend/AGENTS.md) |
| Anything frontend-specific | [frontend/AGENTS.md](./frontend/AGENTS.md) |

First-time setup of an existing clone: `scripts/setup.sh` (see `README.md`). Note it does
**not** create the `.env` files — copy each `.env.example` yourself, then run
`scripts/doctor.sh`.

## Rules that hold everywhere

1. **One gate per side, and it is not optional**: `task check` in `backend/`,
   `npm run check` in `frontend/`. **There is no CI** — every gate lives in the
   submodules' git hooks, so `--no-verify` has nothing behind it.
2. **Tests are non-optional on both sides**, and coverage floors are machine-enforced.
   Ratchet them up, never down; add the test instead of lowering the bar.
3. **English-only in the repo** — code, comments, identifiers, commit messages, docs.
4. **Never commit application code to the meta-repo.**
5. **Check a gate's exit status, not the tail of its output.** A piped `| tail` shows a
   happy ending even when the command failed.
6. **After subagents run, treat the git index as untrusted**: `git status` in all three
   repos, `git reset` what you did not stage, then stage deliberately.

## How to talk to the user

- **Use the user's language.** Reply in whatever language they write to you in.
- **Explain simply, like to a junior developer.** Short sentences. Define jargon the
  first time. Prefer concrete steps and examples. When you decide something, say what you
  did and why in one plain line.

## Skills

Four skills live in `.claude/skills/`, all genuinely cross-project:

| Skill | Use it to… |
|---|---|
| `full-stack-feature` | Orchestrate a feature across both sides: backend first → start backend → `npm run gen` → UI |
| `commit` | Commit at the meta level: inside each changed submodule, then record the pointers, pushing per the operating mode |
| `retro` | Write a session retrospective to `docs/retro/` (runs automatically as `commit`'s first step) |
| `new-project` | Bootstrap a new product as a meta+submodules pair in DERIVED mode |

The sub-projects ship **no** skills: their workflows live in `AGENTS.md` +
`.agents/*.md`, next to the code they describe. When you add a genuinely cross-project
skill, put it here; anything one-sided belongs in that sub-project's `.agents/` file
instead, so there is exactly one place per topic.
