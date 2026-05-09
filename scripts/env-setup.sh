#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LOG_PREFIX="[env-setup]"

log_info() {
	local message="$1"
	echo "${LOG_PREFIX} ${message}" >&2
}

log_error() {
	local message="$1"
	echo "${LOG_PREFIX} ERROR: ${message}" >&2
}

setup_env_from_remote() {
	local env_remote="${REPO_ROOT}/.env.remote"
	local env_file="${REPO_ROOT}/.env"

	if [[ ! -f ${env_remote} ]]; then
		log_info ".env.remote not found, skipping env decryption"
		return 0
	fi

	if [[ -z ${DOTENV_PRIVATE_KEY_REMOTE:-} && -z ${DOTENV_PRIVATE_KEY:-} ]]; then
		log_info "DOTENV_PRIVATE_KEY_REMOTE / DOTENV_PRIVATE_KEY not set, skipping env decryption"
		return 0
	fi

	if ! command -v dotenvx >/dev/null 2>&1; then
		log_info "dotenvx not found, skipping env decryption"
		return 0
	fi

	log_info "Decrypting .env.remote..."
	cd "${REPO_ROOT}"
	local gh_token
	if ! gh_token="$(dotenvx get GH_TOKEN -f .env.remote --strict --no-ops)"; then
		log_error "failed to read GH_TOKEN from .env.remote"
		return 1
	fi

	if [[ -z ${gh_token} ]]; then
		log_error "GH_TOKEN is empty in .env.remote"
		return 1
	fi

	umask 077
	printf "GH_TOKEN=%s\n" "${gh_token}" >"${env_file}"

	if [[ ! -s ${env_file} ]]; then
		log_error "failed to generate .env from .env.remote"
		return 1
	fi

	log_info "Generated ${env_file}"

	set -a
	# shellcheck source=/dev/null
	. "${env_file}"
	set +a
}

log_info "Installing tools..."
bash "${SCRIPT_DIR}/install-tools.sh"

log_info "Setting up environment from remote..."
setup_env_from_remote

log_info "Environment setup completed."
