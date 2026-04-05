#!/usr/bin/env bash
# One-time / repeat: Docker volume, infra_net, copy per-repo nginx vhosts into /opt/nginx/conf.d
#
# From monorepo root:
#   bash scripts/bootstrap.sh           # prod: fundose.in + api.fundose.in
#   bash scripts/bootstrap.sh --dev     # dev: fundose.local + api.fundose.local + /etc/hosts

set -euo pipefail

DEV=false
[[ "${1:-}" == "--dev" ]] && DEV=true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF_D="/opt/nginx/conf.d"
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

mkdir -p "$NGINX_CONF_D"

if $DEV; then
    cp "$REPO_ROOT/fundose-fe/deploy/nginx/fundose.local.conf" "$NGINX_CONF_D/fundose.local.conf"
    echo "[done] Copied fundose.local.conf (frontend)"
    cp "$REPO_ROOT/fundose-backend/deploy/nginx/api.fundose.local.conf" "$NGINX_CONF_D/api.fundose.local.conf"
    echo "[done] Copied api.fundose.local.conf (backend)"
else
    cp "$REPO_ROOT/fundose-fe/deploy/nginx/fundose.in.conf" "$NGINX_CONF_D/fundose.in.conf"
    echo "[done] Copied fundose.in.conf (frontend)"
    cp "$REPO_ROOT/fundose-backend/deploy/nginx/api.fundose.in.conf" "$NGINX_CONF_D/api.fundose.in.conf"
    echo "[done] Copied api.fundose.in.conf (backend)"
fi

if $DEV; then
    if grep -q "api.fundose.local" /etc/hosts 2>/dev/null; then
        echo "[skip] /etc/hosts already has api.fundose.local"
    elif grep -q "fundose.local" /etc/hosts 2>/dev/null; then
        echo "127.0.0.1  api.fundose.local" | sudo tee -a /etc/hosts >/dev/null
        echo "[done] Added api.fundose.local to /etc/hosts"
    else
        echo "127.0.0.1  fundose.local api.fundose.local" | sudo tee -a /etc/hosts >/dev/null
        echo "[done] Added fundose.local api.fundose.local to /etc/hosts"
    fi
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Next:"
echo "  1. fundose-backend: cp .env.example .env && edit secrets"
echo "  2. Prod: TLS certs — fundose.in and api.fundose.in (separate Let's Encrypt certs)"
echo "  3. Reload infra nginx: nginx -t && nginx -s reload"
if $DEV; then
    echo "  4. cd fundose-backend && docker compose -f docker-compose.dev.yml up --build -d"
    echo "  5. cd fundose-fe && docker compose -f docker-compose.dev.yml up --build -d"
    echo "  6. Open http://fundose.local (API at http://api.fundose.local)"
else
    echo "  4. cd fundose-backend && docker compose up --build -d"
    echo "  5. cd fundose-fe && docker compose up --build -d"
fi
echo ""
