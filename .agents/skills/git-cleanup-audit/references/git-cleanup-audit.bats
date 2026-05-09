#!/usr/bin/env bats

SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CLEANUP_LOCAL="$SKILL_DIR/references/cleanup-local-branches.sh"
CLEANUP_WORKTREES="$SKILL_DIR/references/cleanup-worktrees.sh"
CLEANUP_REMOTE="$SKILL_DIR/references/cleanup-remote-branches.sh"
AUDIT_ISSUES="$SKILL_DIR/references/audit-issues.sh"
BASH_PATH="$(which bash)"

setup() {
  export WORK_DIR
  WORK_DIR="$(mktemp -d)"

  export TEST_REPO="$WORK_DIR/repo"
  mkdir -p "$TEST_REPO"
  (
    cd "$TEST_REPO"
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "init" > file.txt
    git add .
    git commit -q -m "initial"
  )

  mkdir -p "$WORK_DIR/bin"
  export ORIGINAL_PATH="$PATH"
  export PATH="$WORK_DIR/bin:$PATH"
}

teardown() {
  export PATH="$ORIGINAL_PATH"
  rm -rf "$WORK_DIR"
}

# ──────────────────────────────────────────────
# cleanup-local-branches.sh
# ──────────────────────────────────────────────

@test "cleanup-local-branches --help exits 0" {
  run "$BASH_PATH" "$CLEANUP_LOCAL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--force"* ]]
}

@test "cleanup-local-branches defaults to dry-run mode" {
  (
    cd "$TEST_REPO"
    git checkout -q -b feature/default-dry-run
    echo "feature" > default-dry-run.txt
    git add .
    git commit -q -m "default dry-run"
    git checkout -q main
    git merge -q feature/default-dry-run
  )

  run "$BASH_PATH" -c "cd '$TEST_REPO' && $BASH_PATH '$CLEANUP_LOCAL'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ドライランモード"* ]]

  local branches
  branches=$(git -C "$TEST_REPO" branch --list "feature/default-dry-run")
  [[ -n "$branches" ]]
}

@test "cleanup-local-branches --dry-run shows merged branches without deleting" {
  (
    cd "$TEST_REPO"
    git checkout -q -b feature/old
    echo "feature" > feature.txt
    git add .
    git commit -q -m "feature"
    git checkout -q main
    git merge -q feature/old
  )

  run "$BASH_PATH" -c "cd '$TEST_REPO' && $BASH_PATH '$CLEANUP_LOCAL' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feature/old"* ]]

  local branches
  branches=$(git -C "$TEST_REPO" branch --list "feature/old")
  [[ -n "$branches" ]]
}

@test "cleanup-local-branches --force deletes merged branches" {
  (
    cd "$TEST_REPO"
    git checkout -q -b feature/to-delete
    echo "feature" > feature.txt
    git add .
    git commit -q -m "feature"
    git checkout -q main
    git merge -q feature/to-delete
  )

  run "$BASH_PATH" -c "cd '$TEST_REPO' && $BASH_PATH '$CLEANUP_LOCAL' --force"
  [ "$status" -eq 0 ]

  local branches
  branches=$(git -C "$TEST_REPO" branch --list "feature/to-delete" || true)
  [[ -z "$branches" ]]
}

@test "cleanup-local-branches does not delete unmerged branches" {
  (
    cd "$TEST_REPO"
    git checkout -q -b feature/unmerged
    echo "unmerged" > unmerged.txt
    git add .
    git commit -q -m "unmerged feature"
    git checkout -q main
  )

  run "$BASH_PATH" -c "cd '$TEST_REPO' && $BASH_PATH '$CLEANUP_LOCAL' --force"
  [ "$status" -eq 0 ]

  local branches
  branches=$(git -C "$TEST_REPO" branch --list "feature/unmerged")
  [[ -n "$branches" ]]
}

# ──────────────────────────────────────────────
# cleanup-worktrees.sh
# ──────────────────────────────────────────────

@test "cleanup-worktrees --help exits 0" {
  run "$BASH_PATH" "$CLEANUP_WORKTREES" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "cleanup-worktrees skips in remote env" {
  export TEST_REMOTE=true

  run "$BASH_PATH" "$CLEANUP_WORKTREES" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Web環境のためworktree操作はスキップします"* ]]
}

@test "cleanup-worktrees --dry-run shows report header" {
  run "$BASH_PATH" "$CLEANUP_WORKTREES" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Worktree の棚卸し"* ]]
}

# ──────────────────────────────────────────────
# cleanup-remote-branches.sh
# ──────────────────────────────────────────────

@test "cleanup-remote-branches --help exits 0" {
  run "$BASH_PATH" "$CLEANUP_REMOTE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "cleanup-remote-branches skips when gh is not available" {
  local empty_bin="$WORK_DIR/empty-bin"
  mkdir -p "$empty_bin"
  export PATH="$empty_bin"

  run "$BASH_PATH" "$CLEANUP_REMOTE" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh CLI が見つかりません"* ]]
}

# ──────────────────────────────────────────────
# audit-issues.sh
# ──────────────────────────────────────────────

@test "audit-issues --help exits 0" {
  run "$BASH_PATH" "$AUDIT_ISSUES" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "audit-issues skips when gh is not available" {
  local empty_bin="$WORK_DIR/empty-bin"
  mkdir -p "$empty_bin"
  export PATH="$empty_bin"

  run "$BASH_PATH" "$AUDIT_ISSUES" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh CLI が見つかりません"* ]]
}

@test "audit-issues --dry-run shows report header" {
  run "$BASH_PATH" "$AUDIT_ISSUES" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"解決済み open Issue"* ]]
}
