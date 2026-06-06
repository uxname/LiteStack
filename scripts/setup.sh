#!/usr/bin/env bash
# LiteStack bootstrap: init submodules and install deps in both sub-projects.
# This does NOT run the projects — start them separately per their AGENTS.md.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Initializing submodules"
git submodule update --init --recursive

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

See AGENTS.md and docs/ for details.
EOF
