#!/usr/bin/env bash
set -euo pipefail

ORCHESTRATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ORCHESTRATOR_DIR/installers/_common.sh"

append_path() {
	local path_entry="$1"
	local bashrc_path_entry="$path_entry"

	if [[ $path_entry == "$HOME" ]]; then
		# shellcheck disable=SC2016
		bashrc_path_entry='$HOME'
	elif [[ $path_entry == "$HOME/"* ]]; then
		bashrc_path_entry="\$HOME/${path_entry#"$HOME/"}"
	fi

	if [[ ":$PATH:" != *":$path_entry:"* ]]; then
		export PATH="$path_entry:$PATH"
	fi
	if [[ -n ${ENV_FILE:-} ]]; then
		echo "export PATH=\"$path_entry:\$PATH\"" >>"$ENV_FILE"
	fi
	if [[ -n ${GITHUB_PATH:-} ]]; then
		echo "$path_entry" >>"$GITHUB_PATH"
	fi
	if [[ ${PERSIST_TO_BASHRC:-false} == "true" ]]; then
		mkdir -p "$HOME"
		touch "$HOME/.bashrc"
		if ! grep -F "export PATH=\"${bashrc_path_entry}:\$PATH\"" "$HOME/.bashrc" >/dev/null 2>&1; then
			echo "export PATH=\"${bashrc_path_entry}:\$PATH\"" >>"$HOME/.bashrc"
		fi
	fi
}

run_step() {
	local description="$1"
	shift

	log "$description"
	if "$@"; then
		return 0
	fi

	fail "$description failed"
	if [[ $STRICT_MODE == "true" ]]; then
		return 1
	fi
	return 0
}

install_mise_tools() {
	(
		cd "$REPO_ROOT"
		mise install "$@"
	)
}

trust_mise_config() {
	(
		cd "$REPO_ROOT"
		local config_files=()
		if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
			while IFS= read -r rel_path; do
				[[ -f "$REPO_ROOT/$rel_path" ]] || continue
				config_files+=("$REPO_ROOT/$rel_path")
			done < <(git -C "$REPO_ROOT" ls-files '.mise.toml' '.mise.*.toml' 2>/dev/null)
		else
			shopt -s nullglob
			config_files=("$REPO_ROOT/.mise.toml" "$REPO_ROOT"/.mise.*.toml)
			shopt -u nullglob
		fi

		for config_file in "${config_files[@]}"; do
			mise trust --yes "$config_file"
		done
	)
}

setup_worktrunk_shell() {
	if ! command -v wt >/dev/null 2>&1; then
		return 0
	fi

	wt config shell install 2>/dev/null || true
}

setup_worktrunk_config() {
	if ! command -v wt >/dev/null 2>&1; then
		return 0
	fi

	local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/worktrunk"
	local config_file="$config_dir/config.toml"

	mkdir -p "$config_dir"
	touch "$config_file"

	if grep -Eq '^[[:space:]]*worktree-path[[:space:]]*=' "$config_file"; then
		return 0
	fi

	{
		echo ""
		echo "# Default worktree location for repositories using this template."
		echo 'worktree-path = "~/worktrees/{{ repo }}/{{ branch | sanitize }}"'
	} >>"$config_file"
}

main() {
	export MISE_YES=1
	export MISE_ENV="${MISE_ENV:-workstation}"
	export MISE_TRUSTED_CONFIG_PATHS="${MISE_TRUSTED_CONFIG_PATHS:+${MISE_TRUSTED_CONFIG_PATHS}:}${REPO_ROOT}"

	run_step "Installing mise..." bash "$ORCHESTRATOR_DIR/installers/mise.sh"

	local mise_bin="$HOME/.local/bin"
	append_path "$mise_bin"

	run_step "Trusting mise config..." trust_mise_config

	run_step "Installing tools via mise..." install_mise_tools "$@"

	local shims_dir="$HOME/.local/share/mise/shims"
	append_path "$shims_dir"

	run_step "Installing helper scripts..." bash "$ORCHESTRATOR_DIR/installers/helper-scripts.sh"

	run_step "Configuring Worktrunk worktree path..." setup_worktrunk_config

	run_step "Setting up Worktrunk shell integration..." setup_worktrunk_shell

	log "Tool installation completed"
}

main "$@"
