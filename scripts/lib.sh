#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MAIN='\e[38;5;75m'
RED='\e[31m'
GREEN='\e[32m'
NC='\e[0m'

_find_compose_files() {
  find "$SCRIPT_DIR/.." -maxdepth 3 -name 'docker-compose.y*ml' -not -path '*/private/*' | sort
}

_run_one_service() {
  local service_name="$1"
  local service_dir="$2"
  local action="$3"

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

run_action() {
  local action="$1"
  local total=0 ok=0 failed=0
  local failed_services=""

  while IFS= read -r compose_file; do
    local service_dir service_name
    service_dir="$(dirname "$compose_file")"
    service_name="$(basename "$service_dir")"
    total=$((total + 1))

    if _run_one_service "$service_name" "$service_dir" "$action"; then
      ok=$((ok + 1))
    else
      failed=$((failed + 1))
      failed_services="${failed_services}${failed_services:+, }${service_name}"
    fi
  done < <(_find_compose_files)

  echo ""
  echo -e "${MAIN}──────────────────────────────────────${NC}"
  echo -e "${MAIN}Total: ${total}${NC} | ${GREEN}OK: ${ok}${NC} | ${RED}Failed: ${failed}${NC}"
  if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed services:${NC} ${failed_services}"
  fi
}
