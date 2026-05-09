#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[restore-env]"

log_info() {
	local message="$1"
	echo "${LOG_PREFIX} ${message}" >&2
}

log_info "No-op: remote env is no longer restored from ~/.bashrc"
log_info "Use dotenvx run -f .env.remote -- <command>"
