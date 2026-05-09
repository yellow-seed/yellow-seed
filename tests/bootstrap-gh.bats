#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/.codex/hooks/bootstrap-gh.sh"

setup() {
	export WORK_DIR
	WORK_DIR="$(mktemp -d)"
	export HOME="$WORK_DIR/home"
	mkdir -p "$HOME" "$WORK_DIR/bin"
	export PATH="$WORK_DIR/bin:/usr/bin:/bin"
}

teardown() {
	rm -rf "$WORK_DIR"
}

write_gh_binary() {
	local target="$1"
	mkdir -p "$(dirname "$target")"
	cat >"$target" <<'GH'
#!/usr/bin/env bash
echo "gh version test"
GH
	chmod +x "$target"
}

@test "bootstrap-gh falls back to pinned version when release API lookup fails" {
	cat >"$WORK_DIR/bin/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
  -s) echo Linux ;;
  -m) echo x86_64 ;;
esac
UNAME
	chmod +x "$WORK_DIR/bin/uname"

	cat >"$WORK_DIR/bin/curl" <<'CURL'
#!/usr/bin/env bash
if [[ "$*" == *"api.github.com/repos/cli/cli/releases/latest"* ]]; then
  exit 22
fi
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then
    : >"$2"
    exit 0
  fi
  shift
done
exit 1
CURL
	chmod +x "$WORK_DIR/bin/curl"

	cat >"$WORK_DIR/bin/tar" <<'TAR'
#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-C" ]]; then
    out_dir="$2"
    break
  fi
  shift
done
mkdir -p "$out_dir/gh_2.62.0_linux_amd64/bin"
cat >"$out_dir/gh_2.62.0_linux_amd64/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh version 2.62.0"
GH
chmod +x "$out_dir/gh_2.62.0_linux_amd64/bin/gh"
TAR
	chmod +x "$WORK_DIR/bin/tar"

	export GH_BOOTSTRAP_FORCE_INSTALL=true
	run bash "$SCRIPT"
	unset GH_BOOTSTRAP_FORCE_INSTALL
	[ "$status" -eq 0 ]
	[[ "$output" == *"Falling back to gh v2.62.0"* ]]
	[ -x "$HOME/.local/bin/gh" ]
}

@test "bootstrap-gh downloads macOS zip assets on Darwin" {
	cat >"$WORK_DIR/bin/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
  -s) echo Darwin ;;
  -m) echo arm64 ;;
esac
UNAME
	chmod +x "$WORK_DIR/bin/uname"

	cat >"$WORK_DIR/bin/curl" <<'CURL'
#!/usr/bin/env bash
if [[ "$*" == *"api.github.com/repos/cli/cli/releases/latest"* ]]; then
  printf '{"tag_name":"v2.90.0"}\n'
  exit 0
fi
if [[ "$*" != *"gh_2.90.0_macOS_arm64.zip"* ]]; then
  printf 'unexpected download: %s\n' "$*" >&2
  exit 1
fi
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then
    : >"$2"
    exit 0
  fi
  shift
done
exit 1
CURL
	chmod +x "$WORK_DIR/bin/curl"

	cat >"$WORK_DIR/bin/unzip" <<'UNZIP'
#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-d" ]]; then
    out_dir="$2"
    break
  fi
  shift
done
mkdir -p "$out_dir/gh_2.90.0_macOS_arm64/bin"
cat >"$out_dir/gh_2.90.0_macOS_arm64/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh version 2.90.0"
GH
chmod +x "$out_dir/gh_2.90.0_macOS_arm64/bin/gh"
UNZIP
	chmod +x "$WORK_DIR/bin/unzip"

	export GH_BOOTSTRAP_FORCE_INSTALL=true
	run bash "$SCRIPT"
	unset GH_BOOTSTRAP_FORCE_INSTALL
	[ "$status" -eq 0 ]
	[[ "$output" == *"Downloading gh v2.90.0 (macOS/arm64)"* ]]
	[ -x "$HOME/.local/bin/gh" ]
}
