#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[gh-setup]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_REMOTE="${REPO_ROOT}/.env.remote"

log_info() {
	local message="$1"
	echo "${LOG_PREFIX} ${message}" >&2
}

install_gh_extension() {
	local -n gh_cmd_ref="$1"
	local extension_repo="$2"
	local extension_name="${extension_repo#*/}"

	log_info "Checking ${extension_name} extension..."

	if "${gh_cmd_ref[@]}" extension list 2>/dev/null | grep -q "${extension_repo}"; then
		log_info "${extension_name} extension already installed"
		return 0
	fi

	log_info "Installing ${extension_name} extension..."
	if "${gh_cmd_ref[@]}" extension install "${extension_repo}" 2>/dev/null; then
		log_info "${extension_name} extension installed successfully"
	else
		log_info "Failed to install ${extension_name} extension (non-critical, continuing)"
	fi
}

install_gh_extensions() {
	install_gh_extension "$1" "yahsan2/gh-sub-issue"
	install_gh_extension "$1" "harakeishi/gh-discussion"
}

has_dotenv_private_key() {
	local key_name
	for key_name in $(compgen -A variable DOTENV_PRIVATE_KEY); do
		if [[ -n ${!key_name:-} ]]; then
			return 0
		fi
	done
	return 1
}

resolve_gh_cmd() {
	GH_CMD=(gh)

	if [[ -n ${GH_TOKEN:-} ]]; then
		return 0
	fi

	if gh auth status >/dev/null 2>&1; then
		return 0
	fi

	if command -v dotenvx >/dev/null 2>&1 && [[ -f ${ENV_REMOTE} ]] && has_dotenv_private_key; then
		if (cd "${REPO_ROOT}" && dotenvx run -f .env.remote -- true) >/dev/null 2>&1; then
			GH_CMD=(dotenvx run -f .env.remote -- gh)
			return 0
		fi
	fi

	log_info "GH_TOKEN is not set, gh is not authenticated, and dotenvx remote fallback is unavailable; skipping gh extension setup"
	return 1
}

if [[ -z ${REMOTE_ENV_VAR:-} ]]; then
	log_info "REMOTE_ENV_VAR is not set, skipping gh setup"
	exit 0
fi

REMOTE_ENV_VALUE="${!REMOTE_ENV_VAR:-}"
if [[ ${REMOTE_ENV_VALUE} != "true" ]]; then
	log_info "Not a remote session, skipping gh setup"
	exit 0
fi

log_info "Remote session detected, checking gh CLI..."

# gh is installed by mise; ensure shims are in PATH
MISE_SHIMS="${HOME}/.local/share/mise/shims"
if [[ -d ${MISE_SHIMS} && ":${PATH}:" != *":${MISE_SHIMS}:"* ]]; then
	export PATH="${MISE_SHIMS}:${PATH}"
fi

if ! command -v gh &>/dev/null; then
	log_info "gh CLI not found; run install-tools.sh first"
	exit 0
fi

log_info "gh CLI available: $(gh --version | head -1)"

# shellcheck disable=SC2034 # referenced by install_gh_extensions via nameref
GH_CMD=(gh)
if resolve_gh_cmd; then
	install_gh_extensions GH_CMD
fi
