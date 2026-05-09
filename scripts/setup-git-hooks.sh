#!/bin/bash
set -euo pipefail

LOG_PREFIX="[hooks-setup]"

log() {
	echo "$LOG_PREFIX $*" >&2
}

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	log "Not inside a git repository, skipping hooks setup."
	exit 0
fi

if [ ! -d "$REPO_ROOT/.githooks" ]; then
	log ".githooks directory not found, skipping hooks setup."
	exit 0
fi

log "Configuring git to use .githooks..."
git -C "$REPO_ROOT" config core.hooksPath .githooks
log "Git hooks configured."
