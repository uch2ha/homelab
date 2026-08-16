#!/usr/bin/env bash
set -euo pipefail

# Validate every committed docker-compose file against the compose schema.
# Placeholder values (xxx, 192.168.0.x) from .env.example are replaced with
# valid dummy values so interpolation + value validation can run in CI.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
git config --global --add safe.directory "$ROOT_DIR" 2>/dev/null || true

sanitize_env() {
  awk '
    {
      i = index($0, "=")
      if (i > 0) {
        key = substr($0, 1, i - 1)
        if (key ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
          val = substr($0, i + 1)
          gsub(/[xX]+/, "1", val)
          print key "=" val
          next
        }
      }
      print
    }
  ' "$1"
}

failed=0
total=0
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  compose_file="$ROOT_DIR/$rel"
  dir="$(dirname "$compose_file")"
  total=$((total + 1))

  env_file=""
  if [ -f "$dir/.env.example" ]; then
    env_file="$dir/.env"
    sanitize_env "$dir/.env.example" > "$env_file"
  fi

  set +e
  if [ -n "$env_file" ]; then
    docker compose --env-file "$env_file" -f "$compose_file" config -q 2>&1
  else
    docker compose -f "$compose_file" config -q 2>&1
  fi
  rc=$?
  set -e
  rm -f "$env_file"

  if [ $rc -ne 0 ]; then
    echo "FAIL: $rel"
    failed=$((failed + 1))
  fi
done < <(git -C "$ROOT_DIR" ls-files ':(glob)**/docker-compose.y*ml')

echo ""
echo "Compose check: $((total - failed))/$total passed"
if [ $failed -gt 0 ]; then
  exit 1
fi