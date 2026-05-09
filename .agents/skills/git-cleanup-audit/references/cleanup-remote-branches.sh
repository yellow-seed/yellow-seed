#!/usr/bin/env bash
#
# cleanup-remote-branches.sh - PR close済みのリモートブランチ削除
#
# Usage:
#   bash .agents/skills/git-cleanup-audit/references/cleanup-remote-branches.sh [OPTIONS]
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
	echo "Usage: bash .agents/skills/git-cleanup-audit/references/cleanup-remote-branches.sh [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --dry-run  削除せずに一覧のみ表示（デフォルト）"
	echo "  --force    確認なしに一括削除"
	echo "  --help     ヘルプ表示"
}

main() {
	parse_options "$@"

	if ! command -v gh &>/dev/null; then
		warn "gh CLI が見つかりません。スキップします"
		return
	fi

	info "=== PR close済みのリモートブランチ ==="

	local merged_branches
	merged_branches=$(gh pr list --state merged --limit 1000 --json headRefName,isCrossRepository --jq '.[] | select(.isCrossRepository == false) | .headRefName' 2>/dev/null | sort -u || true)

	local closed_branches
	closed_branches=$(gh pr list --state closed --limit 1000 --json headRefName,isCrossRepository --jq '.[] | select(.isCrossRepository == false) | .headRefName' 2>/dev/null | sort -u || true)

	local all_orphans
	all_orphans=$(echo -e "${merged_branches}\n${closed_branches}" | sort -u | grep -vE '^(|main|master)$' || true)

	if [[ -z $all_orphans ]]; then
		ok "削除候補のリモートブランチはありません"
		return
	fi

	echo ""
	echo "$all_orphans" | head -20 | while read -r b; do echo "  - $b"; done
	local count
	count=$(echo "$all_orphans" | wc -l | tr -d ' ')
	if [[ $count -gt 20 ]]; then
		echo "  ... 他 $((count - 20)) 件"
	fi
	echo ""

	if [[ $DRY_RUN == true ]]; then
		info "ドライランモード: 削除は実行されません"
		return
	fi

	echo "$all_orphans" | while read -r b; do
		if git push origin --delete "$b" 2>/dev/null; then
			ok "削除: $b"
		else
			warn "スキップ: $b"
		fi
	done
}

main "$@"
