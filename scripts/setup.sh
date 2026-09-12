#!/usr/bin/env bash
#
# setup.sh — one-shot environment setup for a fresh LiteStack clone.
#
# Idempotent: safe to re-run. Replaces the manual steps in README.md.
#   1. init/update submodules
#   2. fetch deps: `go mod download` in backend (Go), `npm install` in frontend
#      and at the meta root (unless --no-install)
#
# Note: this only fetches dependencies. Full backend bring-up (env, hooks, codegen,
# DB+Redis, migrations) is `cd backend && task setup` — it needs Docker, so it is not
# run here. See backend/AGENTS.md.
#
# Usage: scripts/setup.sh [--no-install]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DO_INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --no-install)   DO_INSTALL=0 ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)              echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }

step "Submodules: init + update"
git submodule update --init --recursive

if [[ "$DO_INSTALL" == 1 ]]; then
  step "Backend (Go): go mod download"
  ( cd backend && go mod download )
  step "Frontend: npm install"
  ( cd frontend && npm install )
  step "Meta: npm install (LikeC4 CLI)"
  npm install
else
  echo "  (skipped dependency install — --no-install)"
fi

step "Done"
echo "Next: read AGENTS.md, then backend/AGENTS.md and frontend/AGENTS.md."
echo "Backend full bring-up (Docker DB+Redis + migrations): cd backend && task setup."
echo "For a new project (not just a clone), see the rename + new-project flow in AGENTS.md."
