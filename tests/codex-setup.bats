#!/usr/bin/env bats

# Tests for .codex/hooks/codex-setup.sh – profile branching.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/.codex/hooks/codex-setup.sh"

setup() {
  export WORK_DIR
  WORK_DIR="$(mktemp -d)"

  mkdir -p "$WORK_DIR/.codex/hooks"
  mkdir -p "$WORK_DIR/.claude/hooks"
  mkdir -p "$WORK_DIR/scripts"

  cp "$SCRIPT" "$WORK_DIR/.codex/hooks/codex-setup.sh"

  export CALL_LOG="$WORK_DIR/calls.log"
  : >"$CALL_LOG"

  for stub in \
    "$WORK_DIR/.codex/hooks/gh-setup.sh" \
    "$WORK_DIR/.codex/hooks/env-setup.sh" \
    "$WORK_DIR/.codex/hooks/bootstrap-dotenvx.sh" \
    "$WORK_DIR/.codex/hooks/bootstrap-gh.sh" \
    "$WORK_DIR/.codex/hooks/restore-env.sh" \
    "$WORK_DIR/.codex/hooks/setup-remote-env.sh" \
    "$WORK_DIR/.claude/hooks/skills-setup.sh" \
    "$WORK_DIR/scripts/setup-git-hooks.sh" \
    "$WORK_DIR/scripts/install-tools.sh"; do
    script_name="$(basename "$stub")"
    printf '#!/bin/bash\necho "%s" >> "$CALL_LOG"\nexit 0\n' "$script_name" >"$stub"
    chmod +x "$stub"
  done

  git -C "$WORK_DIR" init --quiet
  git -C "$WORK_DIR" remote add origin https://example.com/repo.git
}

teardown() {
  rm -rf "$WORK_DIR"
}

# --- static checks ---

@test "codex-setup.sh does not remove git remote origin" {
  ! grep -q 'remote remove origin' "$SCRIPT"
}

@test "default profile preserves origin regardless of CODEX_REMOTE" {
  export CODEX_REMOTE=true
  run git -C "$WORK_DIR" remote
  [[ "$output" == *"origin"* ]]

  unset CODEX_REMOTE
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]

  run git -C "$WORK_DIR" remote
  [[ "$output" == *"origin"* ]]
}

# --- default profile: script invocations ---

@test "default profile calls bootstrap-dotenvx" {
  export CODEX_REMOTE=true
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  grep -qx "bootstrap-dotenvx.sh" "$CALL_LOG"
}

@test "default profile calls bootstrap-gh" {
  export CODEX_REMOTE=true
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  grep -qx "bootstrap-gh.sh" "$CALL_LOG"
}

@test "default profile calls setup-remote-env" {
  export CODEX_REMOTE=true
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  grep -qx "setup-remote-env.sh" "$CALL_LOG"
}

@test "default profile calls gh-setup and skills-setup and git-hooks" {
  export CODEX_REMOTE=true
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  grep -qx "gh-setup.sh" "$CALL_LOG"
  grep -qx "skills-setup.sh" "$CALL_LOG"
  grep -qx "setup-git-hooks.sh" "$CALL_LOG"
}

@test "default profile does not call install-tools" {
  export CODEX_REMOTE=true
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  ! grep -qx "install-tools.sh" "$CALL_LOG"
}

# --- full profile ---

@test "full profile calls install-tools in addition to default steps" {
  export CODEX_SETUP_PROFILE=full
  export CODEX_REMOTE=true
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  grep -qx "bootstrap-dotenvx.sh" "$CALL_LOG"
  grep -qx "bootstrap-gh.sh" "$CALL_LOG"
  grep -qx "setup-remote-env.sh" "$CALL_LOG"
  grep -qx "install-tools.sh" "$CALL_LOG"
}

# --- session profile ---

@test "session profile calls bootstrap-gh and setup-remote-env" {
  export CODEX_SETUP_PROFILE=session
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  grep -qx "bootstrap-gh.sh" "$CALL_LOG"
  grep -qx "setup-remote-env.sh" "$CALL_LOG"
}

@test "session profile calls skills-setup and git-hooks" {
  export CODEX_SETUP_PROFILE=session
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  grep -qx "skills-setup.sh" "$CALL_LOG"
  grep -qx "setup-git-hooks.sh" "$CALL_LOG"
}

@test "session profile does not call bootstrap-dotenvx" {
  export CODEX_SETUP_PROFILE=session
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  ! grep -qx "bootstrap-dotenvx.sh" "$CALL_LOG"
}

@test "session profile does not call install-tools" {
  export CODEX_SETUP_PROFILE=session
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  ! grep -qx "install-tools.sh" "$CALL_LOG"
}

@test "session profile does not remove git remote even when CODEX_REMOTE=true" {
  export CODEX_SETUP_PROFILE=session
  export CODEX_REMOTE=true
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -eq 0 ]
  run git -C "$WORK_DIR" remote
  [[ "$output" == *"origin"* ]]
}

# --- unknown profile ---

@test "unknown profile exits with error" {
  export CODEX_SETUP_PROFILE=unknown
  run bash "$WORK_DIR/.codex/hooks/codex-setup.sh"
  [ "$status" -ne 0 ]
}
