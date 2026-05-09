#!/usr/bin/env bash
#
# cleanup-worktrees.sh - 不要な worktree の削除
#
# Usage:
#   bash .agents/skills/git-cleanup-audit/references/cleanup-worktrees.sh [OPTIONS]
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
	echo "Usage: bash .agents/skills/git-cleanup-audit/references/cleanup-worktrees.sh [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --dry-run  削除せずに一覧のみ表示（デフォルト）"
	echo "  --force    確認なしに一括削除"
	echo "  --help     ヘルプ表示"
}

is_remote_env() {
	env | grep -qE '^[A-Z_]+_REMOTE='
}

list_non_main_worktrees() {
	local current_worktree
	current_worktree=$(git rev-parse --show-toplevel)
	git worktree list --porcelain 2>/dev/null | awk -v current_worktree="$current_worktree" '
		/^worktree / {
			if (path != "") {
				emit()
			}
			path = substr($0, 10)
			branch = ""
		}
		/^branch / {
			branch = substr($0, 8)
		}
		END {
			if (path != "") {
				emit()
			}
		}
		function emit() {
			if (path == current_worktree || branch == "refs/heads/main") {
				return
			}
			name = branch
			sub("^refs/heads/", "", name)
			print path "\t" name
		}
	'
}

main() {
	parse_options "$@"

	if is_remote_env; then
		info "Web環境のためworktree操作はスキップします"
		return
	fi

	info "=== Worktree の棚卸し ==="

	local worktrees
	worktrees=$(list_non_main_worktrees || true)

	if [[ -z $worktrees ]]; then
		ok "メイン以外のworktreeはありません"
		return
	fi

	echo ""
	echo "$worktrees" | while IFS=$'\t' read -r path branch; do
		if [[ -n $branch ]]; then
			echo "  - $path [$branch]"
		else
			echo "  - $path [detached]"
		fi
	done
	echo ""

	if [[ $DRY_RUN == true ]]; then
		info "ドライランモード: 削除は実行されません"
		return
	fi

	if git worktree prune 2>/dev/null; then
		ok "stale worktree をクリーンアップしました"
	fi

	echo "$worktrees" | while IFS=$'\t' read -r path branch; do
		local label
		label=${branch:-$path}
		if [[ -n $branch && $(command -v wt || true) ]]; then
			if wt remove "$branch" 2>/dev/null; then
				ok "削除: $label"
				continue
			fi
		fi
		if git worktree remove "$path" 2>/dev/null; then
			ok "削除: $label"
		else
			warn "スキップ: $label"
		fi
	done
}

main "$@"
