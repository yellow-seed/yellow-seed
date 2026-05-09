#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# /dev/fd が存在しない環境（Claude Code on the Web など）では
# /proc/self/fd へのシンボリックリンクを作成して bats などのツールを動作させる
if [ ! -e /dev/fd ] && [ -d /proc/self/fd ]; then
	ln -s /proc/self/fd /dev/fd 2>/dev/null || true
fi

export REMOTE_ENV_VAR="CLAUDE_CODE_REMOTE"
export ENV_FILE="${CLAUDE_ENV_FILE:-}"

bash "$REPO_ROOT/scripts/gh-setup.sh"

if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
	bash "$REPO_ROOT/scripts/setup-git-hooks.sh"
fi
