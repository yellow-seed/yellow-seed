#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[bootstrap-dotenvx]"

log_info() {
	local message="$1"
	echo "${LOG_PREFIX} ${message}" >&2
}

log_error() {
	local message="$1"
	echo "${LOG_PREFIX} ERROR: ${message}" >&2
}

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "${INSTALL_DIR}"

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
	export PATH="${INSTALL_DIR}:${PATH}"
fi

if command -v dotenvx >/dev/null 2>&1; then
	log_info "dotenvx already available: $(dotenvx --version 2>&1 | head -1)"
	exit 0
fi

log_info "Installing dotenvx to ${INSTALL_DIR}..."
if ! curl -sfLS "https://dotenvx.sh/install.sh" | DOTENVX_INSTALL_DIR="${INSTALL_DIR}" sh; then
	log_error "dotenvx install failed (startup will continue without dotenvx)"
	exit 0
fi

if command -v dotenvx >/dev/null 2>&1; then
	log_info "dotenvx installed: $(dotenvx --version 2>&1 | head -1)"
else
	log_error "dotenvx not found after install (startup will continue without dotenvx)"
	exit 0
fi
