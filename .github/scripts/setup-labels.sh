#!/bin/bash

# GitHub ラベルを自動作成するスクリプト
# Issue テンプレートで使用されるラベルを自動的に作成します

set -e

# Dry-run モード（環境変数 DRY_RUN=1 で有効化）
DRY_RUN=${DRY_RUN:-0}

# 色定義
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'

echo -e "${COLOR_BLUE}GitHub ラベルのセットアップ${COLOR_RESET}"
echo "=============================="
if [ "$DRY_RUN" = "1" ]; then
	echo -e "${COLOR_YELLOW}[DRY-RUN モード] 実際の変更は行いません${COLOR_RESET}"
fi
echo ""

# リポジトリ名を取得（まず gh repo view を試し、失敗したら git remote URL から取得）
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")

if [ -z "$REPO" ]; then
	REPO=$(git config --get remote.origin.url 2>/dev/null | sed -E 's|^.*github\.com[/:]||; s|\.git$||')
fi

if [ -z "$REPO" ]; then
	echo "エラー: GitHub リポジトリが見つかりません"
	echo "このスクリプトは GitHub リポジトリのディレクトリ内で実行してください"
	exit 1
fi

echo "リポジトリ: $REPO"
echo ""

# ラベル定義
# 形式: "name|color|description"
declare -a LABELS=(
	"bug|d73a4a|Something isn't working"
	"enhancement|a2eeef|New feature or request"
	"todo|0e8a16|Task or future work item"
	"openspec-archive|0075ca|Automated OpenSpec archive operation"
)

# ラベルの作成または更新
create_or_update_label() {
	local name="$1"
	local color="$2"
	local description="$3"

	echo "ラベル: $name"

	# 既存のラベルを確認
	if gh label list --json name -q ".[] | select(.name==\"$name\") | .name" | grep -q "^$name$"; then
		echo "  既存のラベルが見つかりました"

		if [ "$DRY_RUN" = "1" ]; then
			echo -e "  ${COLOR_YELLOW}[DRY-RUN]${COLOR_RESET} ラベルを更新します: $name (color: #$color)"
		else
			if gh label edit "$name" --color "$color" --description "$description" 2>/dev/null; then
				echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ラベルを更新しました"
			else
				echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} ラベルの更新に失敗しました（権限がない可能性があります）"
			fi
		fi
	else
		echo "  ラベルが存在しません"

		if [ "$DRY_RUN" = "1" ]; then
			echo -e "  ${COLOR_YELLOW}[DRY-RUN]${COLOR_RESET} ラベルを作成します: $name (color: #$color)"
		else
			if gh label create "$name" --color "$color" --description "$description" 2>/dev/null; then
				echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ラベルを作成しました"
			else
				echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} ラベルの作成に失敗しました（既に存在するか、権限がない可能性があります）"
			fi
		fi
	fi

	echo ""
}

# すべてのラベルを処理
for label_def in "${LABELS[@]}"; do
	IFS='|' read -r name color description <<<"$label_def"
	create_or_update_label "$name" "$color" "$description"
done

if [ "$DRY_RUN" = "1" ]; then
	echo -e "${COLOR_YELLOW}[DRY-RUN] 実際の変更は行われませんでした${COLOR_RESET}"
else
	echo -e "${COLOR_GREEN}ラベルのセットアップが完了しました！${COLOR_RESET}"
fi
