#!/usr/bin/env bash
# Start backend + frontend production stacks (requires bootstrap.sh and backend .env).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/fundose-backend"
docker compose up --build -d
cd "$ROOT/fundose-fe"
docker compose up --build -d
echo "Prod compose stacks up. Use infra nginx + TLS for fundose.in."
