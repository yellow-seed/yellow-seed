#!/bin/bash
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/_common.sh"

install_helper_script() {
	local script_name="$1"
	local source_path="$REPO_ROOT/scripts/${script_name}.sh"
	local dest_path="$INSTALL_PREFIX/$script_name"

	if [ -x "$dest_path" ]; then
		log "$script_name already installed"
		return 0
	fi

	if [ ! -f "$source_path" ]; then
		fail "$source_path not found"
		return 1
	fi

	if ! cp "$source_path" "$dest_path"; then
		fail "failed to copy $script_name"
		return 1
	fi

	if ! chmod +x "$dest_path"; then
		fail "failed to mark $script_name as executable"
		return 1
	fi

	log "$script_name installed"
}

main() {
	local had_error=false

	ensure_path || return 1

	install_helper_script "lint-shell" || had_error=true
	install_helper_script "lint-docs" || had_error=true
	install_helper_script "run-checks" || had_error=true

	if [ "$had_error" = "true" ]; then
		return 1
	fi
}

main "$@"
