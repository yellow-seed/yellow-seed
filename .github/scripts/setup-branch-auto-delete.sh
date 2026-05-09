#!/bin/bash

# ブランチ自動削除設定スクリプト
# マージされたブランチを自動的に削除する設定を有効にします

set -e

# Dry-run モード（環境変数 DRY_RUN=1 で有効化）
DRY_RUN=${DRY_RUN:-0}

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}ブランチ自動削除設定スクリプト${NC}"
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

# 現在の設定を確認
current_setting=$(gh api "repos/$REPO" --jq '.delete_branch_on_merge' 2>/dev/null || echo "false")

if [ "$current_setting" = "true" ]; then
	echo -e "${GREEN}ブランチ自動削除は既に有効になっています${NC}"
	exit 0
fi

echo -e "${YELLOW}現在の設定: ブランチ自動削除は無効です${NC}"

if [ "$DRY_RUN" = "1" ]; then
	echo -e "${YELLOW}[DRY-RUN] ブランチ自動削除を有効にします（スキップ）${NC}"
else
	read -p "ブランチ自動削除を有効にしますか? (y/N): " -n 1 -r
	echo

	if [[ $REPLY =~ ^[Yy]$ ]]; then
		# 設定を更新
		gh api "repos/$REPO" \
			--method PATCH \
			--field delete_branch_on_merge=true \
			--silent

		echo -e "${GREEN}ブランチ自動削除を有効にしました${NC}"
		echo "マージされたプルリクエストのブランチは自動的に削除されます"
	else
		echo -e "${YELLOW}設定を変更しませんでした${NC}"
	fi
fi
