#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/_common.sh"

main() {
	if command_exists mise; then
		log "mise already installed: $(mise --version)"
		return 0
	fi

	log "Installing mise..."
	if ! curl -fsSL https://mise.run | sh; then
		fail "failed to install mise"
		return 1
	fi

	local mise_bin="$HOME/.local/bin"
	if [ -d "$mise_bin" ] && [[ ":$PATH:" != *":$mise_bin:"* ]]; then
		export PATH="$mise_bin:$PATH"
		if [ -n "$ENV_FILE" ]; then
			echo "export PATH=\"$mise_bin:\$PATH\"" >>"$ENV_FILE"
		fi
	fi

	log "mise installed successfully: $(mise --version)"
}

main "$@"
