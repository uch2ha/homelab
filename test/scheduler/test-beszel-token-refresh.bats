#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  REPO="$BATS_TEST_TMPDIR/repo"
  SCRIPT_DIR="$REPO/scheduler/beszel-token-refresh"
  GLANCE_DIR="$REPO/tool/glance"
  BIN="$BATS_TEST_TMPDIR/bin"

  mkdir -p "$SCRIPT_DIR" "$GLANCE_DIR" "$BIN"

  cp "$REPO_ROOT/scheduler/beszel-token-refresh/refresh.sh" "$SCRIPT_DIR/refresh.sh"

  cat > "$GLANCE_DIR/docker-compose.yaml" <<'EOF'
services:
  glance:
    image: glanceapp/glance:latest
EOF

  cat > "$BIN/curl" <<'SCRIPT'
#!/usr/bin/env bash
echo "$@" > "$MOCK_CURL_LOG"
if [ -z "${CURL_OUTPUT:-}" ]; then
  echo '{"token":"test-token"}'
else
  echo "$CURL_OUTPUT"
fi
exit "${CURL_EXIT:-0}"
SCRIPT

  cat > "$BIN/docker" <<'SCRIPT'
#!/usr/bin/env bash
echo "$@" > "$MOCK_DOCKER_LOG"
SCRIPT

  chmod +x "$BIN/curl" "$BIN/docker"

  export MOCK_CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
  export MOCK_DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export PATH="$BIN:$PATH"
}

write_env() {
  cat > "$SCRIPT_DIR/.env" <<'EOF'
BESZEL_HOST=https://beszel.example.com
BESZEL_EMAIL=admin@example.com
BESZEL_PASSWORD=secretpass
EOF
}

@test "writes token file and restarts glance" {
  write_env
  run bash "$SCRIPT_DIR/refresh.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$GLANCE_DIR/.env.beszel-token")" = "BESZEL_TOKEN=test-token" ]
}

@test "curl receives host and credentials" {
  write_env
  run bash "$SCRIPT_DIR/refresh.sh"
  [ "$status" -eq 0 ]
  [[ "$(cat "$MOCK_CURL_LOG")" == *"https://beszel.example.com/api/collections/users/auth-with-password"* ]]
  [[ "$(cat "$MOCK_CURL_LOG")" == *"admin@example.com"* ]]
  [[ "$(cat "$MOCK_CURL_LOG")" == *"secretpass"* ]]
}

@test "docker compose uses glance compose file" {
  write_env
  run bash "$SCRIPT_DIR/refresh.sh"
  [ "$status" -eq 0 ]
  [[ "$(cat "$MOCK_DOCKER_LOG")" == *"compose"* ]]
  [[ "$(cat "$MOCK_DOCKER_LOG")" == *"-f $GLANCE_DIR/docker-compose.yaml"* ]]
  [[ "$(cat "$MOCK_DOCKER_LOG")" == *"up"* ]]
  [[ "$(cat "$MOCK_DOCKER_LOG")" == *"-d"* ]]
}

@test "curl failure exits 1" {
  write_env
  CURL_EXIT=1 run bash "$SCRIPT_DIR/refresh.sh"
  [ "$status" -eq 1 ]
}

@test "empty token exits 1 with error message" {
  write_env
  CURL_OUTPUT='{}' run bash "$SCRIPT_DIR/refresh.sh"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "failed to obtain Beszel token" ]]
}

@test "missing .env exits 1" {
  run bash "$SCRIPT_DIR/refresh.sh"
  [ "$status" -eq 1 ]
}
