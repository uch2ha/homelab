#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="homelab-test"

MAIN='\e[38;5;75m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

main() {
  local scope="${1:-all}"

  if [[ "${CI:-}" == "true" ]]; then
    _run_tests "$scope"
  else
    _run_tests_with_docker "$scope"
  fi
}

# Local run with Docker wrapper
_run_tests_with_docker() {
  local scope="$1"
  _build_image
  docker run --rm -v "$ROOT_DIR:/repo" -e CI=true "$IMAGE_NAME" \
    bash /repo/test/run-tests.sh "$scope"
  _remove_image
}

_build_image() {
  echo "==> building image $IMAGE_NAME"
  docker build -q -t "$IMAGE_NAME" "$ROOT_DIR/test"
  echo ""
}

_remove_image() {
  echo ""
  echo "==> removing image $IMAGE_NAME"
  docker rmi "$IMAGE_NAME"
}

# Real run
_run_tests() {
  local scope="$1"
  cd "$ROOT_DIR"

  local failed=()
  local total=0
  local file rel

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    total=$((total + 1))
    rel="${file#"$ROOT_DIR"/}"

    echo -e "${MAIN}==> running ${rel}${NC}"
    if ! _run_test_file "$file"; then
      failed+=("$rel")
    fi
    echo "-----------------"
    echo ""
  done < <(_find_files "$scope")

  echo -e "${MAIN}tests: found ${total} file(s)${NC}"
  if [ "$total" -eq 0 ]; then
    echo -e "${RED}ERROR: no test files found for scope '${scope}'${NC}" >&2
    return 1
  fi
  echo -e "${GREEN}OK: $((total - ${#failed[@]})) file(s)${NC}"
  if [ "${#failed[@]}" -gt 0 ]; then
    echo -e "${RED}FAILED (${#failed[@]}):${NC}" >&2
    for rel in "${failed[@]}"; do
      echo -e "  ${RED}- ${rel}${NC}" >&2
    done
    return 1
  fi
}

# Runs a single test file based on its extension
_run_test_file() {
  local file="$1"

  case "$file" in
    *.sh) bash "$file" ;;
    *.py) python3 "$file" ;;
    *.bats) bats "$file" ;;
    *) return 1 ;;
  esac
}

# Looks for all .sh, .py, and .bats files
_find_files() {
  local scope="$1"
  local search_root

  if [[ "$scope" == "all" ]]; then
    search_root="$ROOT_DIR/test"
  else
    search_root="$ROOT_DIR/test/$scope"
  fi

  find "$search_root" -type f \
    \( -name '*.sh' -o -name '*.py' -o -name '*.bats' \) \
    -not -name 'run-tests.sh' | sort
}

main "$@"
