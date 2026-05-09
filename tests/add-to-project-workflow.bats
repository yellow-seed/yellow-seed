#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/add-to-project.yml"

@test "add-to-project skips successfully when PROJECT_URL is not configured" {
	run grep -F "enabled=false" "$WORKFLOW"
	[ "$status" -eq 0 ]

	run grep -F "Project 追加をスキップします" "$WORKFLOW"
	[ "$status" -eq 0 ]

	run grep -F "exit 0" "$WORKFLOW"
	[ "$status" -eq 0 ]
}

@test "add-to-project only runs project action when enabled" {
	run grep -F "if: steps.validate.outputs.enabled == 'true'" "$WORKFLOW"
	[ "$status" -eq 0 ]
}

@test "add-to-project still fails when configured project secrets are invalid" {
	run grep -F 'errors=$((errors + 1))' "$WORKFLOW"
	[ "$status" -eq 0 ]

	run grep -F 'if [ "$errors" -gt 0 ]; then' "$WORKFLOW"
	[ "$status" -eq 0 ]
}
