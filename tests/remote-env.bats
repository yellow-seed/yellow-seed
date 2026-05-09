#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

make_dotenvx_stub() {
  local bin_dir="$1"
  cat >"$bin_dir/dotenvx" <<'DOTENVX'
#!/bin/bash
set -euo pipefail

if [ "$1" = "get" ] && [ "$2" = "GH_TOKEN" ] && [ "$3" = "-f" ] && [ "$4" = ".env.remote" ] && [ "$5" = "--strict" ] && [ "$6" = "--no-ops" ]; then
  printf '%s\n' "remote-token"
  exit 0
fi

if [ "$1" = "run" ] && [ "$2" = "-f" ] && [ "$3" = ".env.remote" ] && [ "$4" = "--" ]; then
  shift 4
  GH_TOKEN="remote-token" "$@"
  exit 0
fi

printf 'unexpected dotenvx args: %s\n' "$*" >&2
exit 2
DOTENVX
  chmod +x "$bin_dir/dotenvx"
}

SCRIPT_CODEX_REMOTE_ENV="$REPO_ROOT/.codex/hooks/setup-remote-env.sh"
SCRIPT_CLAUDE_REMOTE_ENV="$REPO_ROOT/.claude/hooks/setup-remote-env.sh"

setup_remote_env_fixture() {
  export WORK_DIR
  WORK_DIR="$(mktemp -d)"

  export HOME="$WORK_DIR/home"
  mkdir -p "$HOME/.local/bin"

  mkdir -p "$WORK_DIR/repo/.codex/hooks" "$WORK_DIR/repo/.claude/hooks" "$WORK_DIR/bin"
  cp "$SCRIPT_CODEX_REMOTE_ENV" "$WORK_DIR/repo/.codex/hooks/setup-remote-env.sh"
  cp "$SCRIPT_CLAUDE_REMOTE_ENV" "$WORK_DIR/repo/.claude/hooks/setup-remote-env.sh"

  make_dotenvx_stub "$WORK_DIR/bin"
  export PATH="$WORK_DIR/bin:$PATH"
}

teardown_remote_env_fixture() {
  rm -rf "$WORK_DIR"
}

@test "codex setup-remote-env validates .env.remote and writes GH_TOKEN to bashrc idempotently" {
  setup_remote_env_fixture
  touch "$WORK_DIR/repo/.env.remote"
  export DOTENV_PRIVATE_KEY_REMOTE="test-key"

  run bash "$WORK_DIR/repo/.codex/hooks/setup-remote-env.sh"
  [ "$status" -eq 0 ]
  [[  "$output" == *"Validated .env.remote decryption key"* ]]
  [[ "$output" == *"Wrote GH_TOKEN export to ~/.bashrc"* ]]

  run grep -Fx "export GH_TOKEN='remote-token'" "$HOME/.bashrc"
  [ "$status" -eq 0 ]

  run bash "$WORK_DIR/repo/.codex/hooks/setup-remote-env.sh"
  [ "$status" -eq 0 ]

  run awk '/BEGIN MANAGED GH_TOKEN/,/END MANAGED GH_TOKEN/ { count++ } END { print count + 0 }' "$HOME/.bashrc"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]

  [ ! -f "$WORK_DIR/repo/.env" ]

  teardown_remote_env_fixture
}

@test "codex setup-remote-env exits successfully when .env.remote is missing" {
  setup_remote_env_fixture
  export DOTENV_PRIVATE_KEY_REMOTE="test-key"

  run bash "$WORK_DIR/repo/.codex/hooks/setup-remote-env.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *".env.remote not found"* ]]

  teardown_remote_env_fixture
}

@test "codex setup-remote-env accepts DOTENV_PRIVATE_KEY fallback" {
  setup_remote_env_fixture
  touch "$WORK_DIR/repo/.env.remote"
  unset DOTENV_PRIVATE_KEY_REMOTE
  export DOTENV_PRIVATE_KEY="fallback-key"

  run bash "$WORK_DIR/repo/.codex/hooks/setup-remote-env.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validated .env.remote decryption key"* ]]

  teardown_remote_env_fixture
}

@test "codex setup-remote-env skips validation when DOTENV_PRIVATE_KEY variables are missing" {
  setup_remote_env_fixture
  touch "$WORK_DIR/repo/.env.remote"
  unset DOTENV_PRIVATE_KEY_REMOTE
  unset DOTENV_PRIVATE_KEY

  run bash "$WORK_DIR/repo/.codex/hooks/setup-remote-env.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOTENV_PRIVATE_KEY_REMOTE / DOTENV_PRIVATE_KEY not set"* ]]

  teardown_remote_env_fixture
}

@test "codex setup-remote-env fails when dotenvx run fails" {
  setup_remote_env_fixture
  touch "$WORK_DIR/repo/.env.remote"
  export DOTENV_PRIVATE_KEY_REMOTE="test-key"

  cat >"$WORK_DIR/bin/dotenvx" <<'DOTENVX'
#!/bin/bash
exit 1
DOTENVX
  chmod +x "$WORK_DIR/bin/dotenvx"

  run bash "$WORK_DIR/repo/.codex/hooks/setup-remote-env.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to load .env.remote"* ]]

  teardown_remote_env_fixture
}

@test "claude setup-remote-env emits clean env JSON with GH_TOKEN on stdout" {
  setup_remote_env_fixture
  touch "$WORK_DIR/repo/.env.remote"
  export DOTENV_PRIVATE_KEY_REMOTE="test-key"
  export CLAUDE_ENV_FILE="$WORK_DIR/claude-env-file"

  stdout_file="$WORK_DIR/stdout"
  stderr_file="$WORK_DIR/stderr"
  bash "$WORK_DIR/repo/.claude/hooks/setup-remote-env.sh" >"$stdout_file" 2>"$stderr_file"
  status=$?
  [ "$status" -eq 0 ]
  [ "$(cat "$stdout_file")" = '{"env":{"GH_TOKEN":"remote-token"}}' ]
  run grep -F "Validated .env.remote decryption key" "$stderr_file"
  [ "$status" -eq 0 ]

  [ ! -f "$WORK_DIR/repo/.env" ]
  [ ! -f "$CLAUDE_ENV_FILE" ]
  [ ! -f "$HOME/.bashrc" ]

  teardown_remote_env_fixture
}

@test "claude setup-remote-env exits successfully when .env.remote is missing" {
  setup_remote_env_fixture
  export DOTENV_PRIVATE_KEY_REMOTE="test-key"

  run bash "$WORK_DIR/repo/.claude/hooks/setup-remote-env.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *".env.remote not found"* ]]

  teardown_remote_env_fixture
}

@test "claude setup-remote-env skips validation when DOTENV_PRIVATE_KEY variables are missing" {
  setup_remote_env_fixture
  touch "$WORK_DIR/repo/.env.remote"
  unset DOTENV_PRIVATE_KEY_REMOTE
  unset DOTENV_PRIVATE_KEY

  run bash "$WORK_DIR/repo/.claude/hooks/setup-remote-env.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOTENV_PRIVATE_KEY_REMOTE / DOTENV_PRIVATE_KEY not set"* ]]

  teardown_remote_env_fixture
}

@test "claude setup-remote-env fails when dotenvx run fails" {
  setup_remote_env_fixture
  touch "$WORK_DIR/repo/.env.remote"
  export DOTENV_PRIVATE_KEY_REMOTE="test-key"

  cat >"$WORK_DIR/bin/dotenvx" <<'DOTENVX'
#!/bin/bash
exit 1
DOTENVX
  chmod +x "$WORK_DIR/bin/dotenvx"

  run bash "$WORK_DIR/repo/.claude/hooks/setup-remote-env.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to load .env.remote"* ]]

  teardown_remote_env_fixture
}
