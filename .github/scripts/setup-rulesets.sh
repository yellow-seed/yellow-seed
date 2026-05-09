#!/bin/bash

# GitHub Ruleset セットアップスクリプト
# このスクリプトは、GitHub CLI (gh) を使用して Ruleset を設定します

set -e

# Dry-run モード（環境変数 DRY_RUN=1 で有効化）
DRY_RUN=${DRY_RUN:-0}

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULESETS_DIR="$(cd "$SCRIPT_DIR/../rulesets" && pwd)"

echo -e "${GREEN}GitHub Ruleset セットアップスクリプト${NC}"
echo "=================================="

if [ "$DRY_RUN" = "1" ]; then
	echo -e "${YELLOW}[DRY-RUN モード] 実際の変更は行いません${NC}"
	echo ""
fi

# GitHub CLI がインストールされているか確認
if ! command -v gh &>/dev/null; then
	echo -e "${RED}エラー: GitHub CLI (gh) がインストールされていません${NC}"
	echo "インストール方法: https://cli.github.com/"
	exit 1
fi

# jq がインストールされているか確認
if ! command -v jq &>/dev/null; then
	echo -e "${RED}エラー: jq がインストールされていません${NC}"
	echo "インストール方法:"
	echo "  macOS: brew install jq"
	echo "  Linux: apt-get install jq または yum install jq"
	exit 1
fi

# GitHub CLI にログインしているか確認
if ! gh auth status &>/dev/null; then
	echo -e "${YELLOW}GitHub CLI にログインしていません${NC}"
	echo "ログインを実行します..."
	gh auth login
fi

# リポジトリ名を取得（まず gh repo view を試し、失敗したら git remote URL から取得）
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")

if [ -z "$REPO" ]; then
	REPO=$(git config --get remote.origin.url 2>/dev/null | sed -E 's|^.*github\.com[/:]||; s|\.git$||' || echo "")
fi

if [ -z "$REPO" ]; then
	echo -e "${RED}エラー: リポジトリ情報を取得できませんでした${NC}"
	echo "リポジトリのディレクトリで実行してください"
	exit 1
fi

echo -e "${GREEN}リポジトリ: $REPO${NC}"
echo ""

# Ruleset ファイルのリストを取得
RULESET_FILES=(
	"$RULESETS_DIR/branch-protection-ruleset.json"
	"$RULESETS_DIR/feature-branch-ruleset.json"
	"$RULESETS_DIR/default-ruleset.json"
)

# 各 Ruleset を適用
for ruleset_file in "${RULESET_FILES[@]}"; do
	if [ ! -f "$ruleset_file" ]; then
		echo -e "${YELLOW}警告: $ruleset_file が見つかりません。スキップします${NC}"
		continue
	fi

	ruleset_name=$(jq -r '.name' "$ruleset_file")
	echo -e "${GREEN}Ruleset を適用中: $ruleset_name${NC}"

	# 既存の Ruleset をチェック
	existing_ruleset=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$ruleset_name\") | .id" 2>/dev/null || echo "")

	if [ -n "$existing_ruleset" ]; then
		echo -e "${YELLOW}既存の Ruleset が見つかりました (ID: $existing_ruleset)${NC}"

		if [ "$DRY_RUN" = "1" ]; then
			echo -e "${YELLOW}[DRY-RUN] Ruleset を更新します（スキップ）${NC}"
		else
			read -p "更新しますか? (y/N): " -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				gh api "repos/$REPO/rulesets/$existing_ruleset" \
					--method PUT \
					--input "$ruleset_file" \
					--silent
				echo -e "${GREEN}Ruleset を更新しました${NC}"
			else
				echo -e "${YELLOW}スキップしました${NC}"
			fi
		fi
	else
		if [ "$DRY_RUN" = "1" ]; then
			echo -e "${YELLOW}[DRY-RUN] 新しい Ruleset を作成します（スキップ）${NC}"
		else
			# 新しい Ruleset を作成
			gh api "repos/$REPO/rulesets" \
				--method POST \
				--input "$ruleset_file" \
				--silent
			echo -e "${GREEN}Ruleset を作成しました${NC}"
		fi
	fi
	echo ""
done

echo -e "${GREEN}セットアップが完了しました！${NC}"
