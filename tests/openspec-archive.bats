#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/.github/scripts/openspec-archive.sh"

setup() {
  WORK_DIR="$(mktemp -d)"
  mkdir -p "$WORK_DIR/openspec/changes"
  cd "$WORK_DIR"
}

teardown() {
  rm -rf "$WORK_DIR"
}

make_change() {
  local name="$1"
  local tasks="$2"

  mkdir -p "openspec/changes/$name"
  printf '%s\n' "$tasks" >"openspec/changes/$name/tasks.md"
}

@test "completed changes are moved into archive" {
  make_change "done-change" "- [x] Finish implementation"

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ ! -d "openspec/changes/done-change" ]
  [ -d "openspec/changes/archive" ]
  find "openspec/changes/archive" -maxdepth 1 -type d -name "*-done-change" | grep -q .
  [[ "$output" == *"Archived: 1 change(s)"* ]]
}

@test "incomplete changes with indented markdown tasks are not archived" {
  make_change "pending-change" "  - [ ] Finish implementation"

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -d "openspec/changes/pending-change" ]
  [ -d "openspec/changes/archive" ]
  [[ "$output" == *"Archived: 0 change(s)"* ]]
}

@test "existing archive entries are preserved" {
  mkdir -p "openspec/changes/archive/2026-01-01-old-change"
  make_change "done-change" "- [x] Finish implementation"

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -d "openspec/changes/archive/2026-01-01-old-change" ]
  find "openspec/changes/archive" -maxdepth 1 -type d -name "*-done-change" | grep -q .
}

@test "archive directory is created when missing" {
  make_change "done-change" "- [x] Finish implementation"

  run bash "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -d "openspec/changes/archive" ]
}
