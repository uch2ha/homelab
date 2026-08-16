#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/lib.sh
source "$SCRIPT_DIR/lib/lib.sh"

find_compose_files > /dev/null
run_action_for_services "stop" "${SELECTED_PATHS[@]}"