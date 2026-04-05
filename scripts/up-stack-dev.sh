#!/usr/bin/env bash
# Start backend + frontend dev stacks (requires bootstrap.sh --dev and .env in backend).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/fundose-backend"
docker compose -f docker-compose.dev.yml up --build -d
cd "$ROOT/fundose-fe"
docker compose -f docker-compose.dev.yml up --build -d
echo "Dev stack up. Open http://fundose.local (via infra nginx)."
