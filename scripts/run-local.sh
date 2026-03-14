#!/usr/bin/env bash
# Run the self-host stack locally on Mac (no Traefik, api-gateway on API_PORT).
# Usage: from dockerPublish folder run:  ./scripts/run-local.sh
# Or:    cd dockerPublish && ./scripts/run-local.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="$ROOT_DIR/.env"
KEYFILE="$ROOT_DIR/mongo-keyfile"
API_PORT="${API_PORT:-5000}"

echo "==> Using project dir: $ROOT_DIR"

if [ ! -f "$ENV_FILE" ]; then
  echo "==> No .env found; copying from .env.example"
  cp .env.example .env
  echo "    Edit .env and set at least: local URLs (API_PUBLIC_URL=http://localhost:${API_PORT}, etc.), Minio__PublicUrl=http://localhost:9000, and all CHANGE_ME_* / JWT secret."
  echo "    Then run this script again."
  exit 1
fi

if [ ! -f "$KEYFILE" ]; then
  echo "==> Creating mongo-keyfile (required for MongoDB replica set)"
  openssl rand -base64 756 > "$KEYFILE"
  chmod 600 "$KEYFILE"
  echo "    Done."
else
  echo "==> mongo-keyfile exists"
fi

echo "==> Pulling images..."
docker compose -f docker-compose.yml -f docker-compose.local.yml pull

echo "==> Starting stack (local: no Traefik, api-gateway on port ${API_PORT})..."
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

echo ""
echo "==> Stack started. Wait a few minutes for DBs and workers to be ready."
echo "    Frontend:  http://localhost:8081"
echo "    Admin:     http://localhost:8084"
echo "    API/Swagger/WebSocket: http://localhost:${API_PORT}"
echo "    MinIO API:  http://localhost:9000   MinIO Console: http://localhost:9001"
echo ""
echo "    Default admin (if seeded): Admin@gmail.com / Admin123@  — change password after first login."
echo "    Logs: docker compose -f docker-compose.yml -f docker-compose.local.yml logs -f"
