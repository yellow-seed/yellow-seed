#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${CODEX_SETUP_PROFILE:-default}"

LOG_PREFIX="[codex-setup]"

log_info() {
	local message="$1"
	echo "${LOG_PREFIX} ${message}" >&2
}

ensure_local_bin_in_path() {
	local local_bin="${HOME}/.local/bin"
	if [[ ":${PATH}:" != *":${local_bin}:"* ]]; then
		export PATH="${local_bin}:${PATH}"
	fi
}

setup_bashrc_path() {
	local bashrc="${HOME}/.bashrc"
	mkdir -p "${HOME}"
	touch "${bashrc}"

	# shellcheck disable=SC2016
	if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "${bashrc}"; then
		# shellcheck disable=SC2016
		echo 'export PATH="$HOME/.local/bin:$PATH"' >>"${bashrc}"
		log_info "Added ~/.local/bin to PATH in ~/.bashrc"
	fi
}

setup_remote_env() {
	log_info "Setting up remote environment from dotenvx if needed..."
	bash "${REPO_ROOT}/.codex/hooks/setup-remote-env.sh"
}

setup_default() {
	setup_bashrc_path

	log_info "Bootstrapping dotenvx..."
	bash "${REPO_ROOT}/.codex/hooks/bootstrap-dotenvx.sh"

	log_info "Bootstrapping gh..."
	bash "${REPO_ROOT}/.codex/hooks/bootstrap-gh.sh"
	ensure_local_bin_in_path

	log_info "Setting up remote environment..."
	setup_remote_env

	log_info "Running gh CLI setup..."
	bash "${REPO_ROOT}/.codex/hooks/gh-setup.sh"

	log_info "Syncing skills directory..."
	bash "${REPO_ROOT}/.claude/hooks/skills-setup.sh"

	log_info "Configuring git hooks..."
	bash "${REPO_ROOT}/scripts/setup-git-hooks.sh"
}

setup_full() {
	setup_default

	log_info "Installing tools via mise (full profile)..."
	bash "${REPO_ROOT}/scripts/install-tools.sh"
}

setup_session() {
	setup_bashrc_path

	log_info "Bootstrapping gh..."
	bash "${REPO_ROOT}/.codex/hooks/bootstrap-gh.sh"
	ensure_local_bin_in_path

	log_info "Setting up remote environment..."
	setup_remote_env

	log_info "Syncing skills directory..."
	bash "${REPO_ROOT}/.claude/hooks/skills-setup.sh"

	log_info "Configuring git hooks..."
	bash "${REPO_ROOT}/scripts/setup-git-hooks.sh"
}

log_info "Starting Codex setup (profile: ${PROFILE})..."

case "${PROFILE}" in
default)
	setup_default
	;;
full)
	setup_full
	;;
session)
	setup_session
	;;
*)
	log_info "Unknown profile: ${PROFILE}" >&2
	exit 1
	;;
esac

log_info "Codex setup completed (profile: ${PROFILE})."
