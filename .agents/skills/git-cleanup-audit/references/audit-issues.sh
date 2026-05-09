#!/usr/bin/env bash
#
# audit-issues.sh - 解決済み open Issue の棚卸し
#
# Usage:
#   bash .agents/skills/git-cleanup-audit/references/audit-issues.sh [OPTIONS]
#
# Options:
#   --dry-run  closeせずに一覧のみ表示
#   --force    確認なしに一括close
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
	echo "Usage: bash .agents/skills/git-cleanup-audit/references/audit-issues.sh [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --dry-run  closeせずに一覧のみ表示（デフォルト）"
	echo "  --force    確認なしに一括close"
	echo "  --help     ヘルプ表示"
}

main() {
	parse_options "$@"

	if ! command -v gh &>/dev/null; then
		warn "gh CLI が見つかりません。スキップします"
		return
	fi

	info "=== 解決済み open Issue ==="

	local issue_numbers
	issue_numbers=$(gh pr list --state merged --limit 100 --json closingIssuesReferences --jq '.[].closingIssuesReferences[].number' 2>/dev/null | sort -u || true)

	local open_issues
	open_issues=""
	while read -r num; do
		if [[ -z $num ]]; then
			continue
		fi

		local issue_line state title
		issue_line=$(gh issue view "$num" --json state,title --jq '[.state, .title] | @tsv' 2>/dev/null || true)
		state=${issue_line%%$'\t'*}
		title=${issue_line#*$'\t'}
		if [[ $state == "OPEN" ]]; then
			open_issues+="${num}"$'\t'"${title}"$'\n'
		fi
	done <<<"$issue_numbers"

	if [[ -z $open_issues ]]; then
		ok "close可能なIssueはありません"
		return
	fi

	echo ""
	echo "close可能なIssue（PRマージ済み）:"
	echo "$open_issues" | while IFS=$'\t' read -r num title; do
		if [[ -z $num ]]; then
			continue
		fi
		echo "  - #$num: $title"
	done
	echo ""

	if [[ $DRY_RUN == true ]]; then
		info "ドライランモード: closeは実行されません"
		return
	fi

	echo "$open_issues" | while IFS=$'\t' read -r num _title; do
		if [[ -z $num ]]; then
			continue
		fi
		if gh issue close "$num" --comment "関連PRマージ済みのためcloseします" 2>/dev/null; then
			ok "close: #$num"
		else
			warn "スキップ: #$num"
		fi
	done
}

main "$@"
