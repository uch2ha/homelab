#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/lib.sh"

CONFIG_FILE="$SCRIPT_DIR/config/start-config.yaml"
PY_FILE="$SCRIPT_DIR/lib/parse_start_config.py"

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}ERROR: config file not found: $CONFIG_FILE${NC}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}ERROR: python3 is required${NC}" >&2
  exit 1
fi

OUTPUT="$(find_compose_files | python3 "$PY_FILE" "$CONFIG_FILE")" || {
  echo -e "${RED}ERROR: failed to parse $CONFIG_FILE${NC}" >&2
  exit 1
}

ACTION="$(printf '%s\n' "$OUTPUT" | head -n1)"
SELECTED_DIRS="$(printf '%s\n' "$OUTPUT" | tail -n +2)"

mapfile -t SELECTED_ARR <<< "$SELECTED_DIRS"
SELECTED_PATHS=()
for dir in "${SELECTED_ARR[@]}"; do
  [ -n "$dir" ] && SELECTED_PATHS+=("$ROOT_DIR/$dir")
done

run_action_for_services "$ACTION" "${SELECTED_PATHS[@]}"
