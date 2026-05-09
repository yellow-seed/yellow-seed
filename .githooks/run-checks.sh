#!/bin/bash
set -euo pipefail

LOG_PREFIX="[githooks]"

log() {
	echo "$LOG_PREFIX $*" >&2
}

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
	log "Not inside a git repository."
	exit 0
fi

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ] && [ "${CODEX_REMOTE:-}" != "true" ]; then
	log "AI hooks disabled (not in Claude/Codex remote environment)."
	exit 0
fi

cd "$REPO_ROOT"

if [ "$#" -eq 0 ]; then
	log "No files provided for linting."
	exit 0
fi

if ! command -v qlty >/dev/null 2>&1; then
	log "qlty not found, skipping lint checks"
	exit 0
fi

log "Running scripts/run-checks.sh..."
"$REPO_ROOT/scripts/run-checks.sh" "$@"
