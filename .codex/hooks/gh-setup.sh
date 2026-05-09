#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE_PATH="${CODEX_ENV_FILE:-${REPO_ROOT}/.env}"

if [[ -f ${ENV_FILE_PATH} ]]; then
	set -a
	# shellcheck source=/dev/null
	. "${ENV_FILE_PATH}"
	set +a
fi

export REMOTE_ENV_VAR="CODEX_REMOTE"
export ENV_FILE="${ENV_FILE_PATH}"

exec bash "$REPO_ROOT/scripts/gh-setup.sh"
