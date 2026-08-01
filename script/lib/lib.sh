#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MAIN='\e[38;5;75m'
RED='\e[31m'
GREEN='\e[32m'
NC='\e[0m'

find_compose_files() {
  local rel
  SELECTED_PATHS=()
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    SELECTED_PATHS+=("$ROOT_DIR/$rel")
    printf '%s\n' "$rel"
  done < <(find "$ROOT_DIR" -maxdepth 3 -name 'docker-compose.y*ml' -printf '%P\n' | sort | sed 's|/docker-compose\.y[a-z]*ml$||')
}

_run_action_for_one_service() {
  local service_dir="$1"
  local action="$2"
  local service_name
  service_name="$(basename "$service_dir")"

  echo -e "${MAIN}─── ${service_name}: docker compose ${action} ───${NC}"

  set +e
  (cd "$service_dir" && docker compose $action 2>&1)
  local exit_code=$?
  set -e

  if [ $exit_code -ne 0 ]; then
    echo -e "${RED}ERROR${NC}"
  fi
  return $exit_code
}

run_action_for_services() {
  local action="$1"
  shift
  local total=0 ok=0 failed=0
  local failed_services=""

  for service_dir in "$@"; do
    total=$((total + 1))

    if _run_action_for_one_service "$service_dir" "$action"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
      local service_name
      service_name="$(basename "$service_dir")"
      failed_services="${failed_services}${failed_services:+, }${service_name}"
    fi
  done

  echo ""
  echo -e "${MAIN}──────────────────────────────────────${NC}"
  echo -e "${MAIN}Total: ${total}${NC} | ${GREEN}OK: ${ok}${NC} | ${RED}Failed: ${failed}${NC}"
  if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed services:${NC} ${failed_services}"
  fi
}
