#!/usr/bin/env bash
set -o pipefail

trap 'echo; echo "ABORTED by user"; exit 130' INT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
STATE_FILE="${SCRIPT_DIR}/_temp/state.txt"

TEMPLATE_CRITICAL='Image %s can be updated'
TEMPLATE_INFO='Image %s can be updated'
TEMPLATE_FAILURE='Failed to check updates for %s — %s'
TEMPLATE_ERROR='Container runtime (%s) not found — update checks disabled'

MAIN='\e[38;5;75m'
GREEN='\e[32m'
ORANGE='\e[38;5;208m'
RED='\e[31m'
NC='\e[0m'

main() {
  failures=()

  load_env
  check_requirements

  while IFS=$'\t' read -r name; do
    [[ -z "$name" ]] && continue

    local image_ref
    image_ref="$(get_container_image_ref "$name")"

    if [[ -z "$image_ref" || "$image_ref" =~ ^[a-f0-9]{12,}$ ]]; then
      handle_error "$name" "No image reference found (untagged/unknown image)"
      echo
      continue
    fi

    if has_sha256_pin "$image_ref"; then
      echo -e "${MAIN}SKIP $name — pinned image ($image_ref)${NC}"
      echo
      continue
    fi

    local base
    base="$(get_image_base "$image_ref")"

    handle_single_container "$name" "$base"
  done < <(get_running_containers)

  if [[ ${#failures[@]} -gt 0 ]]; then
    local body=""
    for f in "${failures[@]}"; do
      body="${body}• ${f}"
    done

    body="${body%"${body##*[![:space:]]}"}"
    send_ntfy "$NTFY_TOPIC_CRITICAL" "Check failures" "$body" "$NTFY_ERROR_PRIORITY" "warning"
  fi

  echo -e "${GREEN}DONE${NC}"
}

handle_single_container() {
  local name="$1" base="$2"

  echo -e "${MAIN}CHECK $name → $base${NC}"

  local latest_tag old_latest_id
  pull_latest_and_get_old_latest_id "$name" "$base" || { echo; return; }

  local running_id new_latest_id
  extract_running_and_new_latest_ids "$name" "$base" || { echo; return; }

  if [[ "$running_id" != "$new_latest_id" ]]; then
    if is_container_critical "$name"; then
      handle_critical_notification "$name" "$base"
    else
      handle_info_notification_and_state_update "$name" "$base" "$new_latest_id"
    fi
  fi

  cleanup_latest_image "$base" "$new_latest_id" "$old_latest_id" "$latest_tag"
  echo
}

pull_latest_and_get_old_latest_id() {
  local name="$1" base="$2"

  latest_tag="latest"

  pull_image "$base" "$latest_tag"
  old_latest_id="$(get_latest_image_id "$base" "$latest_tag")"

  if [[ -z "$old_latest_id" ]]; then
    local image_ref container_tag
    image_ref="$(get_container_image_ref "$name")"
    container_tag="${image_ref##*:}"
    [[ "$container_tag" == "$image_ref" ]] && container_tag="latest"
    latest_tag="$container_tag"

    pull_image "$base" "$latest_tag"
    old_latest_id="$(get_latest_image_id "$base" "$latest_tag")"
  fi

  if [[ -z "$old_latest_id" ]]; then
    handle_error "$name" "Failed to pull image (tried :latest, then :${container_tag})"
    return 1
  fi
}

extract_running_and_new_latest_ids() {
  local name="$1" base="$2"

  running_id="$(get_container_image_id "$name")"

  if [[ -z "$running_id" ]]; then
    handle_error "$name" "Cannot inspect running container"
    return 1
  fi

  new_latest_id="$(get_latest_image_id "$base" "$latest_tag")"

  if [[ -z "$new_latest_id" ]]; then
    handle_error "$name" "Failed to inspect pulled image"
    return 1
  fi
}

handle_critical_notification() {
  local name="$1" base="$2"
  local msg
  msg="$(printf "$TEMPLATE_CRITICAL" "${base}")"
  echo -e "${ORANGE}UPDATE${RED} CRITICAL${NC} — $name ($base)"
  send_ntfy "$NTFY_TOPIC_CRITICAL" "Critical update available" "$msg" "$NTFY_CRITICAL_PRIORITY"
}

handle_info_notification_and_state_update() {
  local name="$1" base="$2" new_id="$3"

  local known
  known="$(read_state "$base")"
  if [[ "$known" == "$new_id" ]]; then
    echo -e "${ORANGE}SKIP UPDATE INFO${NC} — $name ($base) — already notified for this version"
    return
  fi

  local msg
  msg="$(printf "$TEMPLATE_INFO" "${base}")"
  echo -e "${ORANGE}UPDATE${MAIN} INFO${NC} — $name ($base)"
  send_ntfy "$NTFY_TOPIC_INFO" "Update available" "$msg" "$NTFY_INFO_PRIORITY"
  write_state "$base" "$new_id"
}

send_ntfy() {
  local topic="$1" title="$2" body="$3" priority="$4" tags="$5"
  local url="${NTFY_BASE_URL}/${topic}"

  curl -s -o /dev/null \
    -H "Title: ${SERVER_NAME}: ${title}" \
    -H "Priority: ${priority}" \
    -H "Tags: ${tags}" \
    -d "${body}" \
    "$url" 2>/dev/null || true
}

handle_error() {
  local container="$1" reason="$2"
  local msg
  msg="$(printf "$TEMPLATE_FAILURE" "$container" "$reason")"
  echo -e "${RED}ERROR: $msg${NC}"
  failures+=("$msg")
}

# Helper functions

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
  else
    echo "ENV_FILE not found: $ENV_FILE"
    exit 1
  fi
}

check_requirements() {
  if ! command -v "$CMD" &>/dev/null; then
    local msg
    msg="$(printf "$TEMPLATE_ERROR" "$CMD")"
    echo -e "${RED}ERROR: $msg${NC}"
    send_ntfy "$NTFY_TOPIC_CRITICAL" "Update checker error" "$msg" "$NTFY_ERROR_PRIORITY" "warning"
    send_ntfy "$NTFY_TOPIC_INFO" "Update checker error" "$msg" "$NTFY_ERROR_PRIORITY" "warning"
    exit 1
  fi
}

get_image_base() {
  local image="$1"
  # Strip tag (remove everything after last colon)
  echo "${image%:*}"
}

has_sha256_pin() {
  local image="$1"
  [[ "$image" == *"@sha256:"* ]]
}

is_container_critical() {
  local name="$1"
  local IFS=','
  for c in $CRITICAL_CONTAINERS; do
    [[ "$name" == "$c" ]] && return 0
  done
  return 1
}

# Container commands

get_running_containers() {
  $CMD ps --format '{{.Names}}' 2>/dev/null || true
}

get_container_image_ref(){
  local name="$1"
  $CMD inspect --format '{{.Config.Image}}' "$name" 2>/dev/null || true
}

get_container_image_id() {
  local name="$1"
  $CMD inspect --format '{{.Image}}' "$name" 2>/dev/null || true
}

pull_image() {
  local base="$1" tag="$2"
  $CMD pull --quiet "${base}:${tag}" 2>/dev/null | sed 's/^/---/' || true
}

get_latest_image_id() {
  local base="$1" tag="$2"
  $CMD inspect --format '{{.Id}}' "${base}:${tag}" 2>/dev/null || true
}

cleanup_latest_image(){
  local base="$1" new_id="$2" old_id="$3" tag="$4"
  [[ "$old_id" == "$new_id" ]] && return
  remove_image "$new_id"
  [[ -n "$old_id" ]] && reset_latest_tag "$base" "$old_id" "$tag"
}

remove_image() {
  local id="$1"
  $CMD rmi "$id" 2>/dev/null | sed 's/^/---/' || true
}

reset_latest_tag() {
  local base="$1" image_id="$2" tag="$3"
  if [[ -z "$image_id" ]]; then
    return
  fi
  $CMD tag "$image_id" "${base}:${tag}" 2>/dev/null | sed 's/^/---/' || true
}

# State file commands for INFO services

read_state() {
  local image="$1"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo ""; return
  fi
  grep "^${image}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || true
}

write_state() {
  local image="$1" digest="$2"
  mkdir -p "$(dirname "$STATE_FILE")"
  touch "$STATE_FILE" 2>/dev/null
  sed -i "/^${image}=/d" "$STATE_FILE" 2>/dev/null || true
  echo "${image}=${digest}" >> "$STATE_FILE"
}

main "$@"
