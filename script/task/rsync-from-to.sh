#!/usr/bin/env bash
set -euo pipefail

# rsync-from-to.sh — dry-run preview with grouped summary, then actual sync.
# Usage: rsync-from-to.sh <source> <destination>

MAIN='\e[38;5;75m'
GREEN='\e[32m'
ORANGE='\e[38;5;208m'
RED='\e[31m'
NC='\e[0m'

RSYNC_FLAGS_DRYRUN="-aiv --info=progress2"
RSYNC_FLAGS_REALRUN="-a --info=progress2"

# how many directory levels to group in dry-run summary (0 = single "(root)" group)
DRY_RUN_LOG_DEPTH=2
# rsync -i change types to count (space-separated). Examples: >f files, cd dirs
DRY_RUN_CHANGE_TYPES=">f"

LOG_DIR="/tmp/rsync-script"
LOG_FILE=""

# input arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 <source> <destination>" >&2
  exit 1
fi

SRC="$1"
DST="$2"

SRC_NAME="$(basename "$SRC")"
DST_NAME="$(basename "$DST")"

validate_paths_exist() {
  if [ ! -d "$SRC" ]; then
    echo -e "${RED}ERROR: source does not exist or is not a directory: $SRC${NC}" >&2
    exit 1
  fi

  if [ -z "$(find "$SRC" -mindepth 1 -print -quit 2>/dev/null)" ]; then
    echo -e "${RED}ERROR: source directory is empty: $SRC${NC}" >&2
    exit 1
  fi

  if [ ! -d "$(dirname "$DST")" ]; then
    echo -e "${RED}ERROR: destination parent directory does not exist: $(dirname "$DST")${NC}" >&2
    exit 1
  fi

  if [ ! -d "$DST" ]; then
    echo -e "${ORANGE}WARNING: destination does not exist — rsync will create it.${NC}"
    echo -e "${ORANGE}  Check that the path is correct: $DST${NC}"
    echo -n -e "${MAIN}Continue? [y/N] ${NC}"
    read -r REPLY
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
      exit 1
    fi
  fi
}

validate_trailing_slashes() {
  SRC_HAS_SLASH=0
  DST_HAS_SLASH=0
  [[ "$SRC" == */ ]] && SRC_HAS_SLASH=1
  [[ "$DST" == */ ]] && DST_HAS_SLASH=1

  if [ "$SRC_HAS_SLASH" -eq 0 ] || [ "$DST_HAS_SLASH" -eq 0 ]; then
    echo -e "${ORANGE}WARNING: one or both paths are missing trailing '/'${NC}"
    echo -e "${ORANGE}  source: $SRC${NC}"
    echo -e "${ORANGE}  dest:   $DST${NC}"
    echo -e "${ORANGE}  Trailing slash changes behaviour — see 'man rsync'.${NC}"
    echo -n -e "${MAIN}Continue? [y/N] ${NC}"
    read -r REPLY
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
      exit 1
    fi
  fi
}

validate_folder_names_match() {
  if [ "$SRC_NAME" != "$DST_NAME" ]; then
    echo -e "${ORANGE}WARNING: folder names differ:${NC}"
    echo -e "${ORANGE}  source folder: $SRC_NAME${NC}"
    echo -e "${ORANGE}  dest folder:   $DST_NAME${NC}"
    echo -n -e "${MAIN}Continue? [y/N] ${NC}"
    read -r REPLY
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
      exit 1
    fi
  fi
}

warn_if_first_sync(){
  if [ -z "$(find "$DST" -mindepth 1 -print -quit 2>/dev/null)" ]; then
    echo -e "${ORANGE}WARNING: destination is empty — this looks like a first sync.${NC}"
    echo -n -e "${MAIN}Continue? [y/N] ${NC}"
    read -r REPLY
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
      exit 1
    fi
  fi
}

_dry_run_collect(){
  echo ""
  echo -e "${MAIN}─── dry-run ───${NC}"

  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  LOG_FILE="${LOG_DIR}/rsync-${SRC_NAME}-${TIMESTAMP}.log"
  mkdir -p "$LOG_DIR"

  set +e
  RAW="$(rsync $RSYNC_FLAGS_DRYRUN --dry-run "$SRC" "$DST" 2>&1)"
  DRY_EXIT=$?
  set -e

  echo "─── dry-run (full) ───" >> "$LOG_FILE"
  echo "$RAW" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
}

_dry_run_count_changes(){
  declare -g -A file_counts
  total_files=0

  while IFS= read -r line; do
    path="${line:12}"
    [ -z "$path" ] && continue
    if [ $DRY_RUN_LOG_DEPTH -gt 0 ]; then
      group="$(echo "$path" | cut -d'/' -f1-$DRY_RUN_LOG_DEPTH)"
    else
      group="(root)"
    fi
    if [ -z "${file_counts[$group]+x}" ]; then
      file_counts["$group"]=1
    else
      file_counts["$group"]=$((file_counts["$group"] + 1))
    fi
    total_files=$((total_files + 1))
  done < <(echo "$RAW" | grep -E "^($(echo "$DRY_RUN_CHANGE_TYPES" | sed 's/ /|/g'))")
}

_dry_run_show_summary(){
  if [ $total_files -eq 0 ]; then
    echo -e "${GREEN}✓ No file changes to sync.${NC}"
    exit 0
  fi

  for group in $(printf '%s\n' "${!file_counts[@]}" | sort); do
    echo -e "${ORANGE}${group} — ${file_counts[$group]} files${NC}"
  done
}

_dry_run_ask_proceed(){
  echo ""
  echo -n -e "${MAIN}Proceed with actual sync? [y/N] ${NC}"
  read -r REPLY
  if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
    exit 1
  fi
}

dry_run(){
  _dry_run_collect
  _dry_run_count_changes
  _dry_run_show_summary
  _dry_run_ask_proceed
}

real_run() {
  echo ""
  echo -e "${MAIN}─── syncing: ${SRC_NAME} ───${NC}"
  echo -e "${MAIN}  log: $LOG_FILE${NC}"

  echo "" >> "$LOG_FILE"
  echo "─── real-run ───" >> "$LOG_FILE"

  set +e
  rsync $RSYNC_FLAGS_REALRUN "$SRC" "$DST" 2>&1 | tee -a "$LOG_FILE"
  REAL_EXIT=$?
  set -e

  echo ""
  if [ $REAL_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓ Done.${NC}"
  else
    echo -e "${RED}✗ rsync finished with exit code ${REAL_EXIT}${NC}"
    echo -e "${RED}  Check log: $LOG_FILE${NC}"
    exit $REAL_EXIT
  fi
}

print_folder_sizes(){
  SRC_SIZE="$(du -sh "$SRC" 2>/dev/null | cut -f1)"
  DST_SIZE="$(du -sh "$DST" 2>/dev/null | cut -f1)"
  echo -e "${MAIN}source: ${SRC_SIZE}${NC}"
  echo -e "${MAIN}dest:   ${DST_SIZE:-?}${NC}"
}

main() {
  validate_trailing_slashes
  validate_paths_exist
  validate_folder_names_match
  warn_if_first_sync
  dry_run
  real_run
  print_folder_sizes
}

main
