#!/bin/bash
set -u
set -o pipefail

LOG_PREFIX="[install-tools]"

log() {
	echo "$LOG_PREFIX $*" >&2
}

STRICT_MODE="${STRICT_MODE:-false}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local/bin}"
ENV_FILE="${ENV_FILE:-}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC2034
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

fail() {
	log "ERROR: $1"
	if [ "$STRICT_MODE" = "true" ]; then
		exit 1
	fi
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

ensure_path() {
	mkdir -p "$INSTALL_PREFIX"
	if [[ ":$PATH:" != *":$INSTALL_PREFIX:"* ]]; then
		export PATH="$INSTALL_PREFIX:$PATH"
		if [ -n "$ENV_FILE" ]; then
			echo "export PATH=\"$INSTALL_PREFIX:\$PATH\"" >>"$ENV_FILE"
		fi
	fi
}
