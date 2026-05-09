#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_REMOTE="${REPO_ROOT}/.env.remote"

LOG_PREFIX="[setup-remote-env]"

log_info() {
	local message="$1"
	echo "${LOG_PREFIX} ${message}" >&2
}

log_error() {
	local message="$1"
	echo "${LOG_PREFIX} ERROR: ${message}" >&2
}

shell_single_quote() {
	local value="$1"
	printf "'%s'" "${value//\'/\'\\\'\'}"
}

write_bashrc_gh_token() {
	local gh_token="$1"
	local bashrc="${HOME}/.bashrc"
	local tmp_file
	local quoted_token

	mkdir -p "$(dirname "${bashrc}")"
	touch "${bashrc}"
	tmp_file="$(mktemp)"

	awk '
		/^# BEGIN MANAGED GH_TOKEN FOR CODEX REMOTE$/ { skip = 1; next }
		/^# END MANAGED GH_TOKEN FOR CODEX REMOTE$/ { skip = 0; next }
		skip != 1 { print }
	' "${bashrc}" >"${tmp_file}"

	quoted_token="$(shell_single_quote "${gh_token}")"
	{
		printf "# BEGIN MANAGED GH_TOKEN FOR CODEX REMOTE\n"
		printf "export GH_TOKEN=%s\n" "${quoted_token}"
		printf "# END MANAGED GH_TOKEN FOR CODEX REMOTE\n"
	} >>"${tmp_file}"

	mv "${tmp_file}" "${bashrc}"
}

run_with_timeout() {
	local timeout_seconds="$1"
	shift

	if command -v timeout >/dev/null 2>&1; then
		timeout --kill-after=1s "${timeout_seconds}" "$@"
		return "$?"
	fi

	"$@" &
	local command_pid="$!"

	(
		sleep "${timeout_seconds}"
		if kill -0 "${command_pid}" 2>/dev/null; then
			kill "${command_pid}" 2>/dev/null || true
			sleep 1
			kill -9 "${command_pid}" 2>/dev/null || true
		fi
	) &
	local watchdog_pid="$!"

	local status
	set +e
	wait "${command_pid}"
	status="$?"
	set -e

	kill "${watchdog_pid}" 2>/dev/null || true
	wait "${watchdog_pid}" 2>/dev/null || true

	if [[ ${status} -eq 143 || ${status} -eq 137 ]]; then
		return 124
	fi
	return "${status}"
}

LOCAL_BIN="${HOME}/.local/bin"
if [[ ":${PATH}:" != *":${LOCAL_BIN}:"* ]]; then
	export PATH="${LOCAL_BIN}:${PATH}"
fi

if [[ ! -f ${ENV_REMOTE} ]]; then
	log_info ".env.remote not found, skipping remote env setup"
	exit 0
fi

if ! command -v dotenvx >/dev/null 2>&1; then
	log_info "dotenvx not found, skipping remote env setup"
	exit 0
fi

if [[ -z ${DOTENV_PRIVATE_KEY_REMOTE:-} && -z ${DOTENV_PRIVATE_KEY:-} ]]; then
	log_info "DOTENV_PRIVATE_KEY_REMOTE / DOTENV_PRIVATE_KEY not set, skipping validation"
	log_info "Use dotenvx run -f .env.remote -- <command> to load remote env at runtime"
	exit 0
fi

decrypt_status=0
set +e
(cd "${REPO_ROOT}" && run_with_timeout "${SETUP_REMOTE_ENV_TIMEOUT_SECONDS:-60}" dotenvx run -f .env.remote -- true) >/dev/null 2>&1
decrypt_status=$?
set -e

if [[ ${decrypt_status} -ne 0 ]]; then
	if [[ ${decrypt_status} -eq 124 ]]; then
		log_error "dotenvx run timed out after ${SETUP_REMOTE_ENV_TIMEOUT_SECONDS:-60}s"
	else
		log_error "failed to load .env.remote with current DOTENV_PRIVATE_KEY*"
	fi
	exit 1
fi

log_info "Validated .env.remote decryption key"

gh_token=""
if gh_token="$(cd "${REPO_ROOT}" && dotenvx get GH_TOKEN -f .env.remote --strict --no-ops 2>/dev/null)"; then
	if [[ -n ${gh_token} ]]; then
		write_bashrc_gh_token "${gh_token}"
		log_info "Wrote GH_TOKEN export to ~/.bashrc"
	else
		log_info "GH_TOKEN is empty in .env.remote"
	fi
else
	log_info "GH_TOKEN not found in .env.remote"
fi
