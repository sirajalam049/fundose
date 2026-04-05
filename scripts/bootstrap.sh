#!/usr/bin/env bash
# First-time or repeat setup: Docker volume, infra_net, nginx snippet + server conf.
#
# From monorepo root:
#   bash scripts/bootstrap.sh           # production nginx conf (fundose.in)
#   bash scripts/bootstrap.sh --dev     # local dev (fundose.local)

set -euo pipefail

DEV=false
[[ "${1:-}" == "--dev" ]] && DEV=true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF_D="/opt/nginx/conf.d"
NGINX_SNIPPETS="/opt/nginx/snippets"
VOLUME="fundose-backend-postgres"

echo ""
echo "=== Fundose bootstrap ==="
echo "Mode: $(if $DEV; then echo dev; else echo prod; fi)"
echo "Repo: $REPO_ROOT"
echo ""

if docker volume inspect "$VOLUME" &>/dev/null; then
    echo "[skip] Docker volume '$VOLUME' already exists"
else
    docker volume create "$VOLUME"
    echo "[done] Docker volume '$VOLUME' created"
fi

if docker network inspect infra_net &>/dev/null; then
    echo "[skip] Docker network 'infra_net' already exists"
else
    docker network create infra_net
    echo "[done] Docker network 'infra_net' created"
fi

if [ -d "$NGINX_SNIPPETS" ]; then
    echo "[skip] $NGINX_SNIPPETS already exists"
else
    mkdir -p "$NGINX_SNIPPETS"
    echo "[done] Created $NGINX_SNIPPETS"
fi

SNIPPET_SRC="$REPO_ROOT/deploy/nginx/_fundose-locations.conf"
SNIPPET_DST="$NGINX_SNIPPETS/_fundose-locations.conf"
cp "$SNIPPET_SRC" "$SNIPPET_DST"
echo "[done] Copied _fundose-locations.conf to $NGINX_SNIPPETS"

mkdir -p "$NGINX_CONF_D"
if $DEV; then
    CONF_SRC="$REPO_ROOT/deploy/nginx/fundose.local.conf"
    CONF_DST="$NGINX_CONF_D/fundose.local.conf"
else
    CONF_SRC="$REPO_ROOT/deploy/nginx/fundose.in.conf"
    CONF_DST="$NGINX_CONF_D/fundose.in.conf"
fi
cp "$CONF_SRC" "$CONF_DST"
echo "[done] Copied $(basename "$CONF_SRC") to $NGINX_CONF_D"

if $DEV; then
    if grep -q "fundose.local" /etc/hosts 2>/dev/null; then
        echo "[skip] /etc/hosts already mentions fundose.local"
    else
        echo "127.0.0.1  fundose.local" | sudo tee -a /etc/hosts >/dev/null
        echo "[done] Added fundose.local to /etc/hosts"
    fi
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Next:"
echo "  1. fundose-backend: cp .env.example .env && edit secrets"
echo "  2. Reload infra nginx (nginx -t && nginx -s reload) if it is already running"
if $DEV; then
    echo "  3. cd fundose-backend && docker compose -f docker-compose.dev.yml up --build -d"
    echo "  4. cd fundose-fe && docker compose -f docker-compose.dev.yml up --build -d"
    echo "  5. Open http://fundose.local"
else
    echo "  3. cd fundose-backend && docker compose up --build -d"
    echo "  4. cd fundose-fe && docker compose up --build -d"
    echo "  5. Ensure TLS certs exist for fundose.in before using prod nginx conf"
fi
echo ""
