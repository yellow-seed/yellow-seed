#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
	export WORK_DIR
	WORK_DIR="$(mktemp -d)"
	export HOME="$WORK_DIR/home"
	mkdir -p "$HOME/.local/bin"

	mkdir -p "$WORK_DIR/scripts/installers"

	cp "$REPO_ROOT/scripts/install-tools.sh" "$WORK_DIR/scripts/install-tools.sh"
	cp "$REPO_ROOT/scripts/installers/_common.sh" "$WORK_DIR/scripts/installers/_common.sh"

	export CALL_LOG="$WORK_DIR/calls.log"
	: >"$CALL_LOG"
	export GITHUB_PATH="$WORK_DIR/github_path"
	: >"$GITHUB_PATH"

	# Stub mise.sh: records invocation and plants a fake mise binary in $HOME/.local/bin
	cat >"$WORK_DIR/scripts/installers/mise.sh" <<SCRIPT
#!/bin/bash
echo "mise.sh" >>"$CALL_LOG"
echo "installer MISE_YES=\${MISE_YES:-}" >>"$CALL_LOG"
echo "installer MISE_TRUSTED_CONFIG_PATHS=\${MISE_TRUSTED_CONFIG_PATHS:-}" >>"$CALL_LOG"
cat >"\$HOME/.local/bin/mise" <<'MISE'
#!/bin/bash
echo "mise \$*" >>"$CALL_LOG"
echo "MISE_YES=\${MISE_YES:-}" >>"$CALL_LOG"
echo "MISE_ENV=\${MISE_ENV:-}" >>"$CALL_LOG"
echo "MISE_TRUSTED_CONFIG_PATHS=\${MISE_TRUSTED_CONFIG_PATHS:-}" >>"$CALL_LOG"
MISE
chmod +x "\$HOME/.local/bin/mise"
SCRIPT
	chmod +x "$WORK_DIR/scripts/installers/mise.sh"

	# Stub helper-scripts.sh
	cat >"$WORK_DIR/scripts/installers/helper-scripts.sh" <<SCRIPT
#!/bin/bash
echo "helper-scripts.sh" >>"$CALL_LOG"
SCRIPT
	chmod +x "$WORK_DIR/scripts/installers/helper-scripts.sh"

	export INSTALL_PREFIX="$WORK_DIR/bin"
	mkdir -p "$INSTALL_PREFIX"
}

teardown() {
	rm -rf "$WORK_DIR"
}

@test "install-tools invokes mise installer" {
	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]

	run grep -x "mise.sh" "$CALL_LOG"
	[ "$status" -eq 0 ]
}

@test "install-tools runs mise install" {
	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]

	run grep "^mise install" "$CALL_LOG"
	[ "$status" -eq 0 ]
}

@test "install-tools trusts repo mise config before install" {
	touch "$WORK_DIR/.mise.toml"
	touch "$WORK_DIR/.mise.ci.toml"

	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]

	run grep -Fx "mise trust --yes $WORK_DIR/.mise.toml" "$CALL_LOG"
	[ "$status" -eq 0 ]

	run grep -Fx "mise trust --yes $WORK_DIR/.mise.ci.toml" "$CALL_LOG"
	[ "$status" -eq 0 ]
}

@test "install-tools makes mise install non-interactive and trusts repo config" {
	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]

	run grep -Fx "installer MISE_YES=1" "$CALL_LOG"
	[ "$status" -eq 0 ]

	run grep -Fx "installer MISE_TRUSTED_CONFIG_PATHS=$WORK_DIR" "$CALL_LOG"
	[ "$status" -eq 0 ]

	run grep -Fx "MISE_YES=1" "$CALL_LOG"
	[ "$status" -eq 0 ]

	run grep -Fx "MISE_TRUSTED_CONFIG_PATHS=$WORK_DIR" "$CALL_LOG"
	[ "$status" -eq 0 ]
}

@test "install-tools defaults to workstation mise environment" {
	run env -u MISE_ENV bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]

	run grep -Fx "MISE_ENV=workstation" "$CALL_LOG"
	[ "$status" -eq 0 ]
}

@test "install-tools preserves caller mise environment and selected tools" {
	run env MISE_ENV=ci bash "$WORK_DIR/scripts/install-tools.sh" bats
	[ "$status" -eq 0 ]

	run grep -Fx "mise install bats" "$CALL_LOG"
	[ "$status" -eq 0 ]

	run grep -Fx "MISE_ENV=ci" "$CALL_LOG"
	[ "$status" -eq 0 ]
}

@test "install-tools persists mise paths for later GitHub Actions steps" {
	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]

	run grep -Fx "$HOME/.local/bin" "$GITHUB_PATH"
	[ "$status" -eq 0 ]

	run grep -Fx "$HOME/.local/share/mise/shims" "$GITHUB_PATH"
	[ "$status" -eq 0 ]
}

@test "install-tools can persist mise paths to bashrc for Codex cloud setup" {
	export PERSIST_TO_BASHRC=true

	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]

	run grep -Fx 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
	[ "$status" -eq 0 ]

	run grep -Fx 'export PATH="$HOME/.local/share/mise/shims:$PATH"' "$HOME/.bashrc"
	[ "$status" -eq 0 ]
}

@test "install-tools continues installer failures when strict mode is false" {
	cat >"$WORK_DIR/scripts/installers/helper-scripts.sh" <<SCRIPT
#!/bin/bash
echo "helper-scripts.sh failed" >>"$CALL_LOG"
exit 1
SCRIPT
	chmod +x "$WORK_DIR/scripts/installers/helper-scripts.sh"

	export STRICT_MODE=false
	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Installing helper scripts... failed"* ]]
	[[ "$output" == *"Tool installation completed"* ]]
}

@test "install-tools fails installer failures when strict mode is true" {
	cat >"$WORK_DIR/scripts/installers/helper-scripts.sh" <<SCRIPT
#!/bin/bash
echo "helper-scripts.sh failed" >>"$CALL_LOG"
exit 1
SCRIPT
	chmod +x "$WORK_DIR/scripts/installers/helper-scripts.sh"

	export STRICT_MODE=true
	run bash "$WORK_DIR/scripts/install-tools.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *"Installing helper scripts... failed"* ]]
}
