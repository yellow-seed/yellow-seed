#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/gh-setup.sh"

setup() {
  export WORK_DIR
  WORK_DIR="$(mktemp -d)"

  export GH_LOG="$WORK_DIR/gh.log"
  export GH_EXTENSIONS="$WORK_DIR/extensions.txt"
  : >"$GH_LOG"
  : >"$GH_EXTENSIONS"

  mkdir -p "$WORK_DIR/bin"
  cat >"$WORK_DIR/bin/gh" <<'GH'
#!/bin/bash
set -e

printf '%s\n' "$*" >>"$GH_LOG"

case "$1 $2" in
  "--version ")
    echo "gh version 9.9.9"
    ;;
  "auth status")
    [ "${GH_AUTH_STATUS:-failure}" = "success" ]
    ;;
  "extension list")
    cat "$GH_EXTENSIONS"
    ;;
  "extension install")
    echo "$3" >>"$GH_EXTENSIONS"
    ;;
esac
GH
  chmod +x "$WORK_DIR/bin/gh"

  cat >"$WORK_DIR/bin/dotenvx" <<'DOTENVX'
#!/bin/bash
set -e

if [ "$1" = "run" ] && [ "$2" = "-f" ] && [ "$3" = ".env.remote" ] && [ "$4" = "--" ]; then
  shift 4
  GH_TOKEN="remote-token" "$@"
  exit 0
fi

printf 'unexpected dotenvx args: %s\n' "$*" >&2
exit 2
DOTENVX
  chmod +x "$WORK_DIR/bin/dotenvx"

  export PATH="$WORK_DIR/bin:$PATH"
  export GH_TOKEN="test-token"
  export REMOTE_ENV_VAR="TEST_REMOTE"
  export TEST_REMOTE=true
}

teardown() {
  rm -rf "$WORK_DIR"
}

@test "gh-setup installs gh-sub-issue and gh-discussion extensions" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  run grep -x "yahsan2/gh-sub-issue" "$GH_EXTENSIONS"
  [ "$status" -eq 0 ]

  run grep -x "harakeishi/gh-discussion" "$GH_EXTENSIONS"
  [ "$status" -eq 0 ]
}

@test "gh-setup installs extensions through dotenvx when GH_TOKEN is unset and .env.remote decrypts" {
  unset GH_TOKEN
  export GH_AUTH_STATUS="failure"
  export DOTENV_PRIVATE_KEY_REMOTE="test-key"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  run grep -x "yahsan2/gh-sub-issue" "$GH_EXTENSIONS"
  [ "$status" -eq 0 ]

  run grep -x "harakeishi/gh-discussion" "$GH_EXTENSIONS"
  [ "$status" -eq 0 ]
}

@test "gh-setup skips extension install when both extensions already exist" {
  cat >"$GH_EXTENSIONS" <<'EXT'
yahsan2/gh-sub-issue
harakeishi/gh-discussion
EXT

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  run awk '/^extension install / { count++ } END { print count + 0 }' "$GH_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "gh-setup skips extension install when GH_TOKEN is unset and gh is not authenticated" {
  unset GH_TOKEN
  export GH_AUTH_STATUS="failure"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GH_TOKEN is not set"* ]]
  [[ "$output" == *"gh is not authenticated"* ]]

  run awk '/^extension install / { count++ } END { print count + 0 }' "$GH_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "gh-setup installs extensions when GH_TOKEN is unset but gh is authenticated" {
  unset GH_TOKEN
  export GH_AUTH_STATUS="success"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  run grep -x "yahsan2/gh-sub-issue" "$GH_EXTENSIONS"
  [ "$status" -eq 0 ]

  run grep -x "harakeishi/gh-discussion" "$GH_EXTENSIONS"
  [ "$status" -eq 0 ]
}
