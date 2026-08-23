#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  SCRIPT_DIR="$BATS_TEST_TMPDIR/repo/scheduler/image-update-check"
  BIN="$BATS_TEST_TMPDIR/bin"
  NTFY_LOG="$BATS_TEST_TMPDIR/ntfy.log"
  STATE_FILE="$SCRIPT_DIR/temp/state.txt"

  mkdir -p "$SCRIPT_DIR/temp" "$BIN"

  cp "$REPO_ROOT/scheduler/image-update-check/check-updates.sh" "$SCRIPT_DIR/check-updates.sh"

  cat > "$BIN/curl" <<'SCRIPT'
#!/usr/bin/env bash
echo "ntfy: $*" >> "$NTFY_LOG"
exit 0
SCRIPT

  chmod +x "$BIN/curl"

  export NTFY_LOG BIN
  export PATH="$BIN:$PATH"
}

write_env() {
  local critical="$1"
  cat > "$SCRIPT_DIR/.env" <<EOF
CMD=docker
SERVER_NAME=test
NTFY_BASE_URL=https://ntfy.example.com
NTFY_TOPIC_CRITICAL=test-critical
NTFY_TOPIC_INFO=test-info
NTFY_CRITICAL_PRIORITY=5
NTFY_INFO_PRIORITY=3
NTFY_ERROR_PRIORITY=5
CRITICAL_CONTAINERS=$critical
EOF
}

# Mock docker — returns controlled values via env vars:
#   RUNNING_HASH:  image ID for the running container
#   LATEST_HASH:   image ID for :latest after pull
write_mock_docker() {
  cat > "$BIN/docker" <<'SCRIPT'
#!/usr/bin/env bash
echo "docker: $*" >> "$MOCK_DOCKER_LOG"

case "$*" in
  *ps*--format*)
    echo "${MOCK_CONTAINERS:-vaultwarden}"
    ;;
  *Config.Image*vaultwarden*)
    echo "${MOCK_IMAGE_REF:-vaultwarden/server:1.32.5}"
    ;;
  *Image*vaultwarden*)
    echo "${RUNNING_HASH:-sha256:cccc}"
    ;;
  *pull*)
    ;;
  *Id*vaultwarden/server*)
    echo "${LATEST_HASH:-${RUNNING_HASH:-sha256:cccc}}"
    ;;
  *Id*vaultwarden*)
    echo "${LATEST_HASH:-${RUNNING_HASH:-sha256:cccc}}"
    ;;
  *rmi*|*tag*)
    ;;
esac
SCRIPT
  chmod +x "$BIN/docker"
}

assert_ntfy_count() {
  local topic="$1" expected="$2"
  local actual
  actual="$(grep -c "ntfy.*$topic" "$NTFY_LOG" 2>/dev/null || true)"
  [ "$actual" -eq "$expected" ] || {
    echo "FAIL: expected $expected ntfy msg(s) for topic '$topic', got $actual"
    echo "--- ntfy log ---"
    cat "$NTFY_LOG"
    return 1
  }
}

assert_state() {
  local expected="$1"
  if [[ -f "$STATE_FILE" ]]; then
    [[ "$(cat "$STATE_FILE")" == "$expected" ]] || {
      echo "FAIL: state.txt mismatch. expected='$expected', got='$(cat "$STATE_FILE")'"
      return 1
    }
  else
    [[ -z "$expected" ]] || {
      echo "FAIL: state.txt not found, expected '$expected'"
      return 1
    }
  fi
}

# ─── Tests ────────────────────────────────────────────────────────────

@test "missing .env exits 1" {
  write_mock_docker
  run bash "$SCRIPT_DIR/check-updates.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ENV_FILE not found"* ]]
}

@test "CMD not found exits 1 and sends error ntfy to both topics" {
  write_env ""
  cat > "$SCRIPT_DIR/.env" <<'EOF'
CMD=fakecmd
SERVER_NAME=test
NTFY_BASE_URL=https://ntfy.example.com
NTFY_TOPIC_CRITICAL=test-critical
NTFY_TOPIC_INFO=test-info
NTFY_CRITICAL_PRIORITY=5
NTFY_INFO_PRIORITY=3
NTFY_ERROR_PRIORITY=5
CRITICAL_CONTAINERS=
EOF
  write_mock_docker
  run bash "$SCRIPT_DIR/check-updates.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Container runtime (fakecmd) not found"* ]]
  assert_ntfy_count "test-critical" 1
  assert_ntfy_count "test-info" 1
}

@test "no update — no ntfy sent" {
  write_env ""
  export RUNNING_HASH="sha256:aaaa"
  export LATEST_HASH="sha256:aaaa"
  write_mock_docker
  > "$NTFY_LOG"

  run bash "$SCRIPT_DIR/check-updates.sh"
  [ "$status" -eq 0 ]

  assert_ntfy_count "test-info" 0
  assert_ntfy_count "test-critical" 0
  assert_state ""
}

@test "info update — ntfy sent, state file written, duplicate suppressed" {
  write_env ""
  export MOCK_CONTAINERS="vaultwarden"
  export MOCK_IMAGE_REF="vaultwarden/server:1.32.5"
  write_mock_docker
  > "$NTFY_LOG"

  # First run: running != latest
  export RUNNING_HASH="sha256:cccc"
  export LATEST_HASH="sha256:dddd"
  run bash "$SCRIPT_DIR/check-updates.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO"* ]]

  assert_ntfy_count "test-info" 1
  assert_ntfy_count "test-critical" 0
  assert_state "vaultwarden/server=sha256:dddd"

  # Second run: same latest, should skip (state file)
  > "$NTFY_LOG"
  run bash "$SCRIPT_DIR/check-updates.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP UPDATE INFO"* ]]

  assert_ntfy_count "test-info" 0
  assert_state "vaultwarden/server=sha256:dddd"
}

@test "critical update — always notifies on each new version" {
  write_env "vaultwarden"
  export MOCK_CONTAINERS="vaultwarden"
  export MOCK_IMAGE_REF="vaultwarden/server:1.32.5"
  write_mock_docker
  > "$NTFY_LOG"

  # First run: running != latest
  export RUNNING_HASH="sha256:cccc"
  export LATEST_HASH="sha256:dddd"
  run bash "$SCRIPT_DIR/check-updates.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CRITICAL"* ]]

  assert_ntfy_count "test-critical" 1

  # Second run: different latest version → notify again
  > "$NTFY_LOG"
  export LATEST_HASH="sha256:eeee"
  run bash "$SCRIPT_DIR/check-updates.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CRITICAL"* ]]

  assert_ntfy_count "test-critical" 1
}
