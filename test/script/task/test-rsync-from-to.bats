#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"

  # fixtures
  SRC_DIR="$BATS_TEST_TMPDIR/src"
  DST_DIR="$BATS_TEST_TMPDIR/dst"
  mkdir -p "$SRC_DIR/sub" "$DST_DIR"
  echo "hello" > "$SRC_DIR/file1.txt"
  echo "world" > "$SRC_DIR/sub/file2.txt"

  # mock rsync + du on PATH
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"

  cat > "$MOCK_BIN/rsync" <<'EOF'
#!/usr/bin/env bash
echo "rsync: $*" >> "$MOCK_RSYNC_LOG"
if [[ "$*" == *"--dry-run"* ]]; then
  # rsync -i style output: 11 flags + space + path
  echo ">f+++++++++ file1.txt"
  echo ">f+++++++++ sub/file2.txt"
else
  exit 0
fi
EOF
  chmod +x "$MOCK_BIN/rsync"

  cat > "$MOCK_BIN/du" <<'EOF'
#!/usr/bin/env bash
echo "1.5M	$1"
EOF
  chmod +x "$MOCK_BIN/du"

  export MOCK_RSYNC_LOG="$BATS_TEST_TMPDIR/rsync-calls.log"

  # source the script (guard prevents main from auto-running),
  # then relax the strict mode it enabled so bats can run normally
  source "$ROOT_DIR/script/task/rsync-from-to.sh"
  set +e
  set +u
  set +o pipefail
}

@test "validate_trailing_slashes passes when both paths have trailing slash" {
  SRC="$SRC_DIR/"
  DST="$DST_DIR/"
  SRC_HAS_SLASH=0
  DST_HAS_SLASH=0
  validate_trailing_slashes
  [ "$SRC_HAS_SLASH" -eq 1 ]
  [ "$DST_HAS_SLASH" -eq 1 ]
}


@test "validate_trailing_slashes warns when slash missing and is declined" {
  SRC="$SRC_DIR"
  DST="$DST_DIR/"
  run validate_trailing_slashes <<< "n"
  [ "$status" -eq 1 ]
}

@test "validate_paths_exist rejects missing source" {
  SRC="$BATS_TEST_TMPDIR/nope"
  DST="$DST_DIR/"
  run validate_paths_exist
  [ "$status" -eq 1 ]
  [[ "$output" =~ "source does not exist" ]]
}

@test "validate_paths_exist rejects empty source" {
  SRC="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$SRC"
  DST="$DST_DIR/"
  run validate_paths_exist
  [ "$status" -eq 1 ]
  [[ "$output" =~ "source directory is empty" ]]
}

@test "validate_paths_exist rejects missing dst parent" {
  SRC="$SRC_DIR"
  DST="$BATS_TEST_TMPDIR/missing/dst/"
  run validate_paths_exist
  [ "$status" -eq 1 ]
  [[ "$output" =~ "destination parent directory does not exist" ]]
}

@test "validate_paths_exist warns on missing dst and is declined" {
  SRC="$SRC_DIR"
  DST="$BATS_TEST_TMPDIR/newdst/"
  run validate_paths_exist <<< "n"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "destination does not exist" ]]
}

@test "validate_paths_exist passes with valid src and existing dst" {
  SRC="$SRC_DIR"
  DST="$DST_DIR/"
  run validate_paths_exist
  [ "$status" -eq 0 ]
}

@test "validate_folder_names_match warns on mismatch and is declined" {
  SRC_NAME="src"
  DST_NAME="dst"
  run validate_folder_names_match <<< "n"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "folder names differ" ]]
}

@test "validate_folder_names_match continues on mismatch when accepted" {
  SRC_NAME="src"
  DST_NAME="dst"
  run validate_folder_names_match <<< "y"
  [ "$status" -eq 0 ]
}

@test "warn_if_first_sync warns on empty dst and is declined" {
  DST="$DST_DIR/"
  run warn_if_first_sync <<< "n"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "destination is empty" ]]
}

@test "warn_if_first_sync passes when dst is not empty" {
  DST="$DST_DIR"
  touch "$DST/.keep"
  run warn_if_first_sync
  [ "$status" -eq 0 ]
}

@test "dry-run counts changed files grouped by depth" {
  RAW=$'>f+++++++++ a/b/c1.txt\n>f+++++++++ a/b/c2.txt\n>f+++++++++ x/y.txt\ncd+++++++++ some/dir'
  _dry_run_count_changes
  [ "$total_files" -eq 3 ]
  [ "${file_counts[a/b]}" -eq 2 ]
  [ "${file_counts[x/y.txt]}" -eq 1 ]
}

@test "main runs full flow with mocked rsync/du and answers y" {
  SRC="$SRC_DIR/"
  DST="$DST_DIR/"
  SRC_NAME="src"
  DST_NAME="dst"
  run main <<< $'y\ny\ny\ny\ny'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Proceed with actual sync" ]]
  [[ "$output" =~ "✓ Done" ]]
  [[ "$output" =~ "source:" ]]
}
