#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  SRC="$BATS_TEST_TMPDIR/temp/src"
  DST="$BATS_TEST_TMPDIR/temp/dst"
  mkdir -p "$SRC/sub" "$DST"
  echo "hello" > "$SRC/file1.txt"
  echo "world" > "$SRC/sub/file2.txt"
}

@test "first run syncs files to empty dst" {
  run bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$SRC/" "$DST/" <<< $'y\ny\ny\ny'
  [ "$status" -eq 0 ]
  [ -f "$DST/file1.txt" ]
  [ -f "$DST/sub/file2.txt" ]
  [[ "$output" =~ "✓ Done" ]]
}

@test "idempotent run reports no changes" {
  bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$SRC/" "$DST/" <<< $'y\ny\ny\ny' >/dev/null
  run bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$SRC/" "$DST/" <<< $'y\ny\ny'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No file changes to sync" ]]
}

@test "second run picks up new files" {
  bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$SRC/" "$DST/" <<< $'y\ny\ny\ny' >/dev/null
  echo "new" > "$SRC/new.txt"
  run bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$SRC/" "$DST/" <<< $'y\ny\ny'
  [ "$status" -eq 0 ]
  [ -f "$DST/new.txt" ]
}

@test "missing source - exits 1" {
  run bash "$ROOT_DIR/script/task/rsync-from-to.sh" /nonexistent/ "$DST/" <<< $'y'
  [ "$status" -eq 1 ]
  [[ "$output" =~ "source does not exist" ]]
}

@test "empty source - exits 1" {
  EMPTY="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$EMPTY"
  run bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$EMPTY/" "$DST/" <<< $'y'
  [ "$status" -eq 1 ]
  [[ "$output" =~ "source directory is empty" ]]
}

@test "missing dst parent - exits 1" {
  run bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$SRC/" "$BATS_TEST_TMPDIR/missing/dst/" <<< $'y'
  [ "$status" -eq 1 ]
  [[ "$output" =~ "destination parent directory does not exist" ]]
}

@test "mismatched folder names - exits 1 when declined" {
  mkdir -p "$BATS_TEST_TMPDIR/src2"
  run bash "$ROOT_DIR/script/task/rsync-from-to.sh" "$SRC/" "$BATS_TEST_TMPDIR/src2/" <<< $'n'
  [ "$status" -eq 1 ]
  [[ "$output" =~ "folder names differ" ]]
}
