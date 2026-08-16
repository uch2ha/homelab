#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

main() {
  local failed=()
  local total=0
  local file rel

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    total=$((total + 1))
    rel="${file#"$ROOT_DIR"/}"

    if ! _check_bash_syntax "$file"; then
      echo "ERROR: $rel: bash syntax" >&2
      failed+=("$rel")
    fi

    if ! _check_shellcheck "$file"; then
      echo "ERROR: $rel: shellcheck" >&2
      failed+=("$rel")
    fi
  done < <(_find_sh_files)

   if [ "$total" -eq 0 ]; then
     echo -e "${RED}ERROR: no files found${NC}" >&2
     return 1
   fi

  echo "sh: validated $total file(s)"
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "FAILED (${#failed[@]}):" >&2
    for rel in "${failed[@]}"; do
      echo "  - $rel" >&2
    done
    return 1
  fi
}

_find_sh_files() {
  find "$ROOT_DIR" -name '*.sh' -not -path '*/\.git/*' -type f
}

_check_bash_syntax() {
  local file="$1"
  bash -n "$file"
}

_check_shellcheck() {
  local file="$1"
  local script_dir script_name
  script_dir="$(dirname "$file")"
  script_name="$(basename "$file")"
  (cd "$script_dir" && shellcheck -x -S warning "$script_name")
}

main "$@"
