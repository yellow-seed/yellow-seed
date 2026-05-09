#!/usr/bin/env bash
#
# cleanup-local-branches.sh - マージ済みローカルブランチの削除
#
# Usage:
#   bash .agents/skills/git-cleanup-audit/references/cleanup-local-branches.sh [OPTIONS]
#
# Options:
#   --dry-run  削除せずに一覧のみ表示
#   --force    確認なしに一括削除
#   --help     ヘルプ表示

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }

DRY_RUN=true

parse_options() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--force)
			DRY_RUN=false
			shift
			;;
		--help | -h)
			show_help
			exit 0
			;;
		*)
			warn "Unknown option: $1"
			show_help
			exit 1
			;;
		esac
	done
}

show_help() {
	echo "Usage: bash .agents/skills/git-cleanup-audit/references/cleanup-local-branches.sh [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --dry-run  削除せずに一覧のみ表示（デフォルト）"
	echo "  --force    確認なしに一括削除"
	echo "  --help     ヘルプ表示"
}

main() {
	parse_options "$@"

	info "=== マージ済みローカルブランチ ==="

	local current_branch branches
	current_branch=$(git branch --show-current 2>/dev/null || true)
	branches=$(
		{ git branch --merged main 2>/dev/null || true; } |
			sed 's/^[*[:space:]]*//' |
			while read -r branch; do
				if [[ -z $branch || $branch == "main" || $branch == "$current_branch" ]]; then
					continue
				fi
				echo "$branch"
			done
	)

	if [[ -z $branches ]]; then
		ok "マージ済みローカルブランチはありません"
		return
	fi

	echo ""
	echo "$branches" | while read -r b; do echo "  - $b"; done
	echo ""

	if [[ $DRY_RUN == true ]]; then
		info "ドライランモード: 削除は実行されません"
		return
	fi

	echo "$branches" | while read -r b; do
		if git branch -d "$b"; then
			ok "削除: $b"
		else
			warn "スキップ: $b"
		fi
	done
}

main "$@"
