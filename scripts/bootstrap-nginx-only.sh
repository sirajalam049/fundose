#!/usr/bin/env bash
# Refresh only nginx files (snippet + server block). Use after editing deploy/nginx/*.
# Does not create Docker volume/network. Run: bash scripts/bootstrap-nginx-only.sh [--dev]

set -euo pipefail

DEV=false
[[ "${1:-}" == "--dev" ]] && DEV=true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF_D="/opt/nginx/conf.d"
NGINX_SNIPPETS="/opt/nginx/snippets"

mkdir -p "$NGINX_SNIPPETS" "$NGINX_CONF_D"
cp "$REPO_ROOT/deploy/nginx/_fundose-locations.conf" "$NGINX_SNIPPETS/"
if $DEV; then
    cp "$REPO_ROOT/deploy/nginx/fundose.local.conf" "$NGINX_CONF_D/"
else
    cp "$REPO_ROOT/deploy/nginx/fundose.in.conf" "$NGINX_CONF_D/"
fi
echo "Nginx files updated under /opt/nginx. Test and reload your infra nginx container."
