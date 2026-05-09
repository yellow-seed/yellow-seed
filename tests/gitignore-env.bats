#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "working env files and dotenvx key files are ignored" {
  run git -C "$REPO_ROOT" check-ignore .env
  [ "$status" -eq 0 ]

  run git -C "$REPO_ROOT" check-ignore .env.keys
  [ "$status" -eq 0 ]

  run git -C "$REPO_ROOT" check-ignore secrets/.env.local.keys
  [ "$status" -eq 0 ]

  run git -C "$REPO_ROOT" check-ignore secrets/.env.remote.keys
  [ "$status" -eq 0 ]
}

@test "encrypted dotenvx files and sample env stay trackable" {
  run git -C "$REPO_ROOT" check-ignore .env.sample
  [ "$status" -eq 1 ]

  run git -C "$REPO_ROOT" check-ignore .env.local
  [ "$status" -eq 1 ]

  run git -C "$REPO_ROOT" check-ignore .env.remote
  [ "$status" -eq 1 ]
}
