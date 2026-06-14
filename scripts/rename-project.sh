#!/usr/bin/env bash
#
# rename-project.sh — replace the LiteStack template identity (liteend-go / litefront /
# LiteFront) with a new project identity across both submodules.
#
# Run this ONCE on a freshly derived project, BEFORE deps install / `docker compose up`.
# It is idempotent: once the template tokens are gone, re-running is a no-op.
#
# Usage:
#   scripts/rename-project.sh --name <machine-name> [--display "<Brand>"] \
#                             [--repo-owner <git-owner>] [--dry-run]
#
#   --name        Machine name: lowercase, [a-z0-9-], starts with a letter.
#                 Used for the frontend npm package name, the docker network, theme key.
#   --display     Human brand word (default: Title-Cased --name). Replaces "LiteFront"
#                 in PWA manifest, page <title>s, meta tags, and the header.
#                 Keep it a brand word — surrounding " App" / " | " suffixes are preserved.
#   --repo-owner  If set, rewrites demo refs uxname/litefront and uxname/liteend-go on the
#                 home page to <repo-owner>/<name>, AND rewrites the backend Go module path
#                 (github.com/uxname/liteend-go → github.com/<repo-owner>/<name>) across
#                 go.mod and every backend *.go import. Omit to leave both untouched.
#   --dry-run     Show every match that would change; mutate nothing.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NAME=""
DISPLAY=""
REPO_OWNER=""
DRY_RUN=0

die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       NAME="${2:-}"; shift 2 ;;
    --display)    DISPLAY="${2:-}"; shift 2 ;;
    --repo-owner) REPO_OWNER="${2:-}"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown argument: $1" ;;
  esac
done

[[ -n "$NAME" ]] || die "--name is required"
[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || die "--name must be lowercase [a-z0-9-] and start with a letter (got: $NAME)"

# Default display: Title-Case the machine name (my-app -> My App).
if [[ -z "$DISPLAY" ]]; then
  DISPLAY="$(echo "$NAME" | sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g')"
fi

[[ -d "$ROOT/backend" && -d "$ROOT/frontend" ]] || die "expected backend/ and frontend/ submodules under $ROOT"

# Edit operations: "<relative-file>|<perl-regex-from>|<replacement>"
# Machine identity (exact, anchored where ambiguous):
OPS=(
  "frontend/package.json|\"name\": \"litefront\"|\"name\": \"$NAME\""
  "backend/docker-compose.yml|liteend-net|$NAME-net"
  "frontend/src/features/theme/model/store.ts|litefront-theme|$NAME-theme"
)
# Brand identity (token replacement preserves surrounding text):
BRAND_FILES=(
  "frontend/vite.config.ts"
  "frontend/src/routes/__root.tsx"
  "frontend/src/routes/index.tsx"
  "frontend/src/routes/protected/index.tsx"
  "frontend/src/routes/protected/account.tsx"
  "frontend/src/widgets/Header/ui/index.tsx"
  "frontend/src/pages/home/ui/index.tsx"
)
for f in "${BRAND_FILES[@]}"; do
  OPS+=("$f|LiteFront|$DISPLAY")
done
# Demo repo refs (only when --repo-owner is provided):
if [[ -n "$REPO_OWNER" ]]; then
  OPS+=("frontend/src/pages/home/ui/index.tsx|uxname/litefront|$REPO_OWNER/$NAME")
  OPS+=("frontend/src/pages/home/ui/index.tsx|uxname/liteend-go|$REPO_OWNER/$NAME")
fi

echo "Project rename:"
echo "  name (machine): $NAME"
echo "  display (brand): $DISPLAY"
[[ -n "$REPO_OWNER" ]] && echo "  repo owner: $REPO_OWNER"
[[ "$DRY_RUN" == 1 ]] && echo "  MODE: dry-run (no files changed)"
echo

changed=0
for op in "${OPS[@]}"; do
  IFS='|' read -r file from to <<< "$op"
  path="$ROOT/$file"
  [[ -f "$path" ]] || { echo "skip (missing): $file"; continue; }

  if [[ "$DRY_RUN" == 1 ]]; then
    matches="$(grep -nF "$from" "$path" || true)"
    if [[ -n "$matches" ]]; then
      echo "WOULD edit $file  ($from -> $to):"
      echo "$matches" | sed 's/^/    /'
      changed=1
    fi
  else
    if grep -qF "$from" "$path"; then
      # Pass from/to via the environment so they are NEVER interpolated into the perl
      # program: \Q\E quotes the pattern literally, and $ENV{TO} is a plain string (not a
      # regex, not a delimiter) — so values containing '/', '$', etc. are safe.
      RP_FROM="$from" RP_TO="$to" perl -i -pe 's/\Q$ENV{RP_FROM}\E/$ENV{RP_TO}/g' "$path"
      echo "edited $file  ($from -> $to)"
      changed=1
    fi
  fi
done

# Backend Go module path (tree-wide; only when --repo-owner is provided). The Go module
# path is the machine identity of the backend (liteend-go) — it prefixes every internal
# import, so it must be rewritten across go.mod and all *.go, not per-file.
if [[ -n "$REPO_OWNER" ]]; then
  OLD_MODULE="github.com/uxname/liteend-go"
  NEW_MODULE="github.com/$REPO_OWNER/$NAME"
  if [[ "$OLD_MODULE" != "$NEW_MODULE" ]]; then
    # go.mod + every backend *.go that references the old module path.
    mapfile -t GO_FILES < <(grep -rlF "$OLD_MODULE" "$ROOT/backend/go.mod" "$ROOT/backend" --include='go.mod' --include='*.go' 2>/dev/null | sort -u)
    for path in "${GO_FILES[@]}"; do
      [[ -f "$path" ]] || continue
      rel="${path#"$ROOT"/}"
      if [[ "$DRY_RUN" == 1 ]]; then
        echo "WOULD edit $rel  (Go module: $OLD_MODULE -> $NEW_MODULE)"
        changed=1
      else
        RP_FROM="$OLD_MODULE" RP_TO="$NEW_MODULE" perl -i -pe 's/\Q$ENV{RP_FROM}\E/$ENV{RP_TO}/g' "$path"
        echo "edited $rel  (Go module path)"
        changed=1
      fi
    done
  fi
fi

echo
if [[ "$changed" == 0 ]]; then
  echo "No template tokens found — already renamed or nothing to do."
else
  [[ "$DRY_RUN" == 1 ]] && echo "Dry-run complete." || echo "Rename complete. Next: deps install (scripts/setup.sh), then verify with scripts/doctor.sh."
fi
