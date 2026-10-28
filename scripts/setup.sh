#!/usr/bin/env bash
#
# setup.sh — the one command that takes a fresh LiteStack clone to a runnable state.
# Idempotent. It walks the whole path and stops at the first step that fails, saying
# what is wrong: toolchain check (git, docker >= 27.4, go, task, node >= 24.15.0) ->
# submodules -> an .env per side (`cp -n`, never overwrites) -> scripts/doctor.sh on the
# env -> `task setup` in backend -> `npm ci` in frontend -> `npm ci` at the meta
# root -> scripts/doctor.sh again, whole, to prove the installs left a git hook in all
# three repos. Then it prints the two commands left for a human to type.
#
# Usage: scripts/setup.sh [--no-install]     --no-install: skip the three installs
#
set -euo pipefail

src="${BASH_SOURCE[0]}"
[[ "$src" == */* ]] || src="./$src"
cd "${src%/*}/.."

DO_INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --no-install)   DO_INSTALL=0 ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)              echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
# ver_ge HAVE MIN — true when dotted-numeric HAVE is at least MIN.
ver_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }

step "Toolchain"
# The same minimums stand in README.md ("What you need"). Sources of truth: Go —
# backend/go.mod, Node — frontend/package.json "engines", Docker — the `type: image`
# mount the stand needs (backend/.agents/OPERATIONS.md). All gaps reported at once.
TASK=task
missing=()
command -v git >/dev/null || missing+=("git")
command -v go  >/dev/null || missing+=("go (1.27+)")
command -v task >/dev/null || { TASK=go-task; command -v go-task >/dev/null || missing+=("task (on Arch: go-task)"); }
if ! command -v node >/dev/null; then missing+=("node (>= 24.15.0)")
elif ! ver_ge "$(node -v | tr -d v)" 24.15.0; then missing+=("node >= 24.15.0 — found $(node -v)"); fi
# docc 0.7.0 is the first that checks one submodule's tags (`docc check <folder>`) and
# every requirement's coverage (DOC404), as the hooks need (docs/adr/0011). A local
# build reports "dev" and is taken as new enough.
if ! command -v docc >/dev/null; then missing+=("docc (>= 0.7.0): curl -fsSL https://raw.githubusercontent.com/uxname/docc/main/install.sh | sh")
elif ! docc --version | grep -q ' dev$' && ! ver_ge "$(docc --version | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)" 0.7.0; then
  missing+=("docc >= 0.7.0 — found $(docc --version); run: docc update"); fi
if ! command -v docker >/dev/null; then missing+=("docker (Engine >= 27.4)")
elif ! ver_ge "$(docker --version | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)" 27.4; then
  missing+=("docker Engine >= 27.4 — found $(docker --version)"); fi
if ((${#missing[@]})); then
  echo "install these first, then re-run scripts/setup.sh:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi
echo "  ok"

step "Submodules: init + update"
git submodule update --init --recursive

step "Env files (existing ones are kept)"
cp -n backend/.env.example backend/.env
cp -n frontend/.env.example frontend/.env

step "Env contract"
# The hooks come from the installs below, so they are checked after them.
scripts/doctor.sh --no-hooks

if [[ "$DO_INSTALL" == 1 ]]; then
  step "Backend: $TASK setup"
  ( cd backend && "$TASK" setup )
  step "Frontend: npm ci"
  ( cd frontend && npm ci )
  # src/generated/paraglide is not in git; Vite writes it only on dev/build, so without
  # this step `npm run check` (and the pre-commit hook) fails on a fresh clone.
  # Keep project and outdir in step with paraglideVitePlugin in frontend/vite.config.ts.
  step "Frontend: Paraglide messages"
  ( cd frontend && npx paraglide-js compile --project ./project.inlang --outdir ./src/generated/paraglide )
  step "Meta root: npm ci"
  npm ci
  # The prototype is optional (docs/adr/0011): a product that removed it skips this.
  # Its hooks come from the meta's lefthook binary, so this runs after the npm ci above.
  if [[ -d protokit/prototype ]]; then
    step "Prototype: npm ci + hooks"
    ( cd protokit/prototype && npm ci )
    ( cd protokit && ../node_modules/.bin/lefthook install )
  fi
  # `task setup` only warns when lefthook is missing, so a clone can come out of the
  # installs with no hook — and with no CI, no gate (docs/adr/0001).
  step "Final check: env contract + git hooks"
  scripts/doctor.sh
else
  echo "  (--no-install: skipped the backend, frontend and meta installs)"
fi

step "Done — two commands left to type"
cat <<'EOF'
  cd backend  && task start:dev
  cd frontend && npm run start:dev

It worked when both of these answer:
  http://localhost:3000          the frontend page
  http://localhost:4000/readyz   a body starting {"status":"ok"
EOF
