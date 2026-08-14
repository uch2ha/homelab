#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
GLANCE_DIR="$REPO_DIR/tool/glance"

source "$SCRIPT_DIR/.env"

RESPONSE=$(curl -sf -X POST "$BESZEL_HOST/api/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$BESZEL_EMAIL\",\"password\":\"$BESZEL_PASSWORD\"}")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')
if [ -z "$TOKEN" ]; then
  echo "ERROR: failed to obtain Beszel token" >&2
  exit 1
fi

echo "BESZEL_TOKEN=$TOKEN" > "$GLANCE_DIR/.env.beszel-token"
docker compose -f "$GLANCE_DIR/docker-compose.yaml" up -d
