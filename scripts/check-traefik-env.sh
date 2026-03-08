#!/usr/bin/env bash
# Run from repo root (dockerPublish): ./scripts/check-traefik-env.sh
# Ensures .env has real hostnames for Traefik so routing works when you deploy.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found at $ENV_FILE. Create it from .env.example and set TRAEFIK_*_HOST to your hostnames."
  exit 1
fi

# Read TRAEFIK_*_HOST (allow exported vars and inline KEY=value)
get_var() {
  local key="$1"
  grep -E "^[[:space:]]*${key}=" "$ENV_FILE" 2>/dev/null | head -1 | sed 's/^[^=]*=//' | tr -d '\r' | xargs
}

API_HOST="$(get_var TRAEFIK_API_HOST)"
FRONTEND_HOST="$(get_var TRAEFIK_FRONTEND_HOST)"
ADMIN_HOST="$(get_var TRAEFIK_ADMIN_HOST)"

placeholder_pattern='your-domain|your_domain|example\.com'
check() {
  local name="$1"
  local val="$2"
  if [ -z "$val" ]; then
    echo "Missing: $name (set it in .env)"
    return 1
  fi
  if echo "$val" | grep -qiE "$placeholder_pattern"; then
    echo "Placeholder detected: $name=$val — set this to your real hostname (e.g. api.yourdomain.com)."
    return 1
  fi
  return 0
}

err=0
check "TRAEFIK_API_HOST" "$API_HOST" || err=1
check "TRAEFIK_FRONTEND_HOST" "$FRONTEND_HOST" || err=1
check "TRAEFIK_ADMIN_HOST" "$ADMIN_HOST" || err=1

if [ $err -eq 1 ]; then
  echo ""
  echo "Fix .env then run again. See TRAEFIK_DEPLOY.md for the full checklist."
  exit 1
fi

echo "TRAEFIK_*_HOST look set: api=$API_HOST frontend=$FRONTEND_HOST admin=$ADMIN_HOST"
echo "Ensure DNS for these hostnames points to this server and ports 80/443 are open. See TRAEFIK_DEPLOY.md."
