#!/usr/bin/env bats

# Tests for .claude/hooks/claude-setup.sh profile branching.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/.claude/hooks/claude-setup.sh"
SETTINGS="$REPO_ROOT/.claude/settings.json"

setup() {
  export WORK_DIR
  WORK_DIR="$(mktemp -d)"

  mkdir -p "$WORK_DIR/.claude/hooks"
  mkdir -p "$WORK_DIR/scripts"

  cp "$SCRIPT" "$WORK_DIR/.claude/hooks/claude-setup.sh"

  export CALL_LOG="$WORK_DIR/calls.log"
  : >"$CALL_LOG"

  for stub in \
    "$WORK_DIR/.claude/hooks/bootstrap-dotenvx.sh" \
    "$WORK_DIR/.claude/hooks/bootstrap-gh.sh" \
    "$WORK_DIR/.claude/hooks/setup-remote-env.sh" \
    "$WORK_DIR/.claude/hooks/gh-setup.sh" \
    "$WORK_DIR/.claude/hooks/env-setup.sh" \
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

@test "claude settings uses claude-setup as the single SessionStart entrypoint" {
  grep -q './.claude/hooks/claude-setup.sh' "$SETTINGS"
  ! grep -q './.claude/hooks/env-setup.sh' "$SETTINGS"
  ! grep -q './.claude/hooks/gh-setup.sh' "$SETTINGS"
}

@test "default profile preserves origin even when CLAUDE_CODE_REMOTE=true" {
  export CLAUDE_CODE_REMOTE=true

  run bash "$WORK_DIR/.claude/hooks/claude-setup.sh"
  [ "$status" -eq 0 ]

  run git -C "$WORK_DIR" remote
  [[ "$output" == *"origin"* ]]
}

@test "default profile calls lightweight cloud setup scripts" {
  export CLAUDE_CODE_REMOTE=true

  run bash "$WORK_DIR/.claude/hooks/claude-setup.sh"
  [ "$status" -eq 0 ]

  grep -qx "bootstrap-dotenvx.sh" "$CALL_LOG"
  grep -qx "bootstrap-gh.sh" "$CALL_LOG"
  grep -qx "setup-remote-env.sh" "$CALL_LOG"
  grep -qx "gh-setup.sh" "$CALL_LOG"
  grep -qx "skills-setup.sh" "$CALL_LOG"
  grep -qx "setup-git-hooks.sh" "$CALL_LOG"
}

@test "default profile does not call env-setup or install-tools" {
  export CLAUDE_CODE_REMOTE=true

  run bash "$WORK_DIR/.claude/hooks/claude-setup.sh"
  [ "$status" -eq 0 ]

  ! grep -qx "env-setup.sh" "$CALL_LOG"
  ! grep -qx "install-tools.sh" "$CALL_LOG"
}

@test "full profile calls env-setup after default steps" {
  export CLAUDE_SETUP_PROFILE=full
  export CLAUDE_CODE_REMOTE=true

  run bash "$WORK_DIR/.claude/hooks/claude-setup.sh"
  [ "$status" -eq 0 ]

  grep -qx "bootstrap-dotenvx.sh" "$CALL_LOG"
  grep -qx "setup-remote-env.sh" "$CALL_LOG"
  grep -qx "env-setup.sh" "$CALL_LOG"
}

@test "session profile keeps setup lightweight" {
  export CLAUDE_SETUP_PROFILE=session

  run bash "$WORK_DIR/.claude/hooks/claude-setup.sh"
  [ "$status" -eq 0 ]

  grep -qx "bootstrap-gh.sh" "$CALL_LOG"
  grep -qx "setup-remote-env.sh" "$CALL_LOG"
  grep -qx "skills-setup.sh" "$CALL_LOG"
  grep -qx "setup-git-hooks.sh" "$CALL_LOG"
  ! grep -qx "bootstrap-dotenvx.sh" "$CALL_LOG"
  ! grep -qx "env-setup.sh" "$CALL_LOG"
}

@test "unknown profile exits with error" {
  export CLAUDE_SETUP_PROFILE=unknown

  run bash "$WORK_DIR/.claude/hooks/claude-setup.sh"
  [ "$status" -ne 0 ]
}

@test "default profile stdout contains only env JSON from setup-remote-env" {
  env_json='{"env":{"GH_TOKEN":"test-token"}}'

  cat >"$WORK_DIR/.claude/hooks/setup-remote-env.sh" <<EOF
#!/bin/bash
echo "setup-remote-env.sh" >> "\$CALL_LOG"
printf '%s\n' '$env_json'
exit 0
EOF
  chmod +x "$WORK_DIR/.claude/hooks/setup-remote-env.sh"

  for stub in \
    "$WORK_DIR/.claude/hooks/bootstrap-dotenvx.sh" \
    "$WORK_DIR/.claude/hooks/bootstrap-gh.sh" \
    "$WORK_DIR/.claude/hooks/gh-setup.sh" \
    "$WORK_DIR/.claude/hooks/skills-setup.sh" \
    "$WORK_DIR/scripts/setup-git-hooks.sh"; do
    script_name="$(basename "$stub")"
    printf '#!/bin/bash\necho "%s stdout noise" \necho "%s" >> "$CALL_LOG"\nexit 0\n' \
      "$script_name" "$script_name" >"$stub"
    chmod +x "$stub"
  done

  stdout_file="$WORK_DIR/stdout.txt"
  bash "$WORK_DIR/.claude/hooks/claude-setup.sh" >"$stdout_file" 2>/dev/null
  [ "$(cat "$stdout_file")" = "$env_json" ]
}

@test "session profile stdout contains only env JSON from setup-remote-env" {
  export CLAUDE_SETUP_PROFILE=session
  env_json='{"env":{"GH_TOKEN":"test-token"}}'

  cat >"$WORK_DIR/.claude/hooks/setup-remote-env.sh" <<EOF
#!/bin/bash
echo "setup-remote-env.sh" >> "\$CALL_LOG"
printf '%s\n' '$env_json'
exit 0
EOF
  chmod +x "$WORK_DIR/.claude/hooks/setup-remote-env.sh"

  for stub in \
    "$WORK_DIR/.claude/hooks/bootstrap-gh.sh" \
    "$WORK_DIR/.claude/hooks/skills-setup.sh" \
    "$WORK_DIR/scripts/setup-git-hooks.sh"; do
    script_name="$(basename "$stub")"
    printf '#!/bin/bash\necho "%s stdout noise" \necho "%s" >> "$CALL_LOG"\nexit 0\n' \
      "$script_name" "$script_name" >"$stub"
    chmod +x "$stub"
  done

  stdout_file="$WORK_DIR/stdout.txt"
  bash "$WORK_DIR/.claude/hooks/claude-setup.sh" >"$stdout_file" 2>/dev/null
  [ "$(cat "$stdout_file")" = "$env_json" ]
}
