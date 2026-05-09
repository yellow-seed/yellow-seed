#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/installers/helper-scripts.sh"

setup() {
	export WORK_DIR
	WORK_DIR="$(mktemp -d)"

	mkdir -p "$WORK_DIR/scripts/installers"
	cp "$REPO_ROOT/scripts/installers/_common.sh" "$WORK_DIR/scripts/installers/_common.sh"
	cp "$SCRIPT" "$WORK_DIR/scripts/installers/helper-scripts.sh"
	chmod +x "$WORK_DIR/scripts/installers/helper-scripts.sh"

	export INSTALL_PREFIX="$WORK_DIR/bin"
	mkdir -p "$INSTALL_PREFIX"

	# Ensure scripts are discoverable from the copied installer's REPO_ROOT.
	mkdir -p "$WORK_DIR/scripts"
	cat >"$WORK_DIR/scripts/lint-shell.sh" <<'SHELL'
#!/bin/bash
exit 0
SHELL
	cat >"$WORK_DIR/scripts/lint-docs.sh" <<'DOCS'
#!/bin/bash
exit 0
DOCS
	cat >"$WORK_DIR/scripts/run-checks.sh" <<'RUN'
#!/bin/bash
exit 0
RUN
	chmod +x "$WORK_DIR/scripts/lint-shell.sh" "$WORK_DIR/scripts/lint-docs.sh" "$WORK_DIR/scripts/run-checks.sh"
}

teardown() {
	rm -rf "$WORK_DIR"
}

@test "installer fails when copy step fails" {
	rm -rf "$INSTALL_PREFIX"
	ln -s /dev/null "$INSTALL_PREFIX"

	run bash "$WORK_DIR/scripts/installers/helper-scripts.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *"failed to copy lint-shell"* ]]
}

@test "installer propagates failure when one helper script is missing" {
	rm -f "$WORK_DIR/scripts/lint-docs.sh"

	run bash "$WORK_DIR/scripts/installers/helper-scripts.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *"lint-docs.sh not found"* ]]

	[ -x "$INSTALL_PREFIX/lint-shell" ]
	[ -x "$INSTALL_PREFIX/run-checks" ]
}

@test "installer fails when chmod step fails" {
	mkdir -p "$WORK_DIR/fake-bin"
	cat >"$WORK_DIR/fake-bin/chmod" <<'CHMOD'
#!/bin/bash
exit 1
CHMOD
	chmod +x "$WORK_DIR/fake-bin/chmod"

	PATH="$WORK_DIR/fake-bin:$PATH" run bash "$WORK_DIR/scripts/installers/helper-scripts.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *"failed to mark lint-shell as executable"* ]]
	[ -f "$INSTALL_PREFIX/lint-shell" ]
}
