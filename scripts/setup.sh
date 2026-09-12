#!/usr/bin/env bash
#
# setup.sh — the one command that takes a fresh LiteStack clone to a runnable state.
# Idempotent. It walks the whole path and stops at the first step that fails, saying
# what is wrong: toolchain check (git, docker >= 27.4, go, task, node >= 24.15.0) ->
# submodules -> an .env per side (`cp -n`, never overwrites) -> scripts/doctor.sh ->
# `task setup` in backend -> `npm ci` in frontend -> `npm install` at the meta root.
# Then it prints the two commands left for a human to type.
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
scripts/doctor.sh

if [[ "$DO_INSTALL" == 1 ]]; then
  step "Backend: $TASK setup"
  ( cd backend && "$TASK" setup )
  step "Frontend: npm ci"
  ( cd frontend && npm ci )
  step "Meta root: npm install"
  npm install
else
  echo "  (--no-install: skipped the backend, frontend and meta installs)"
fi

step "Done — two commands left to type"
cat <<'EOF'
  cd backend  && task start:dev
  cd frontend && npm run start:dev

It worked when both of these answer:
  http://localhost:3000          the frontend page
  http://localhost:4000/readyz   {"status":"ok"}
EOF
