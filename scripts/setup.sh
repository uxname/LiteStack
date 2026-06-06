#!/usr/bin/env bash
# LiteStack bootstrap: init submodules, fix binary attributes, install deps.
# Does NOT run the projects — start them separately per their AGENTS.md.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Initializing submodules"
git submodule update --init --recursive

# Upstream litefront marks some binaries (e.g. .github/logo.png) as text with eol=lf
# in .gitattributes, so git corrupts them on checkout and the submodule shows dirty.
# Override locally (per-clone, not pushed) to treat binaries as binary, then restore.
echo "==> Fixing binary file attributes in submodules"
for sm in liteend litefront; do
  [ -d "$sm" ] || continue
  gitdir="$(git -C "$sm" rev-parse --absolute-git-dir)"
  mkdir -p "$gitdir/info"
  cat > "$gitdir/info/attributes" <<'ATTR'
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.webp binary
*.woff binary
*.woff2 binary
*.pdf binary
ATTR
  git -C "$sm" checkout -- . 2>/dev/null || true
done

echo "==> Installing liteend dependencies"
( cd liteend && npm install )

echo "==> Installing litefront dependencies"
( cd litefront && npm install )

cat <<'EOF'

==> Done.

Next steps (run each project separately):

  Backend (liteend):
    cd liteend
    cp .env.example .env          # fill in values
    docker-compose up -d db redis
    npm run db:migrations:apply
    npm run start:dev             # http://localhost:4000/graphql

  Frontend (litefront):
    cd litefront
    cp .env.example .env          # fill in values
    npm run gen                   # needs backend running
    npm run start:dev             # http://localhost:3000

Read AGENTS.md first — especially the Operating mode section (template vs derived).
EOF
