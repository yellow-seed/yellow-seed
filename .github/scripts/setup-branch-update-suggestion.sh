#!/bin/bash

# PRブランチ更新提案設定スクリプト
# ベースブランチが更新された際にPRブランチの更新を提案する設定を有効にします

set -e

# Dry-run モード（環境変数 DRY_RUN=1 で有効化）
DRY_RUN=${DRY_RUN:-0}

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}PRブランチ更新提案設定スクリプト${NC}"
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

# リポジトリ情報を取得
# 環境変数 GITHUB_REPOSITORY が設定されている場合はそれを使用
# 設定されていない場合は gh repo view を試し、失敗したら git remote URL から取得
REPO="${GITHUB_REPOSITORY:-}"

if [ -z "$REPO" ]; then
	REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
fi

if [ -z "$REPO" ]; then
	REPO=$(git config --get remote.origin.url 2>/dev/null | sed -E 's|^.*github\.com[/:]||; s|\.git$||' || echo "")
fi

if [ -z "$REPO" ]; then
	echo -e "${RED}エラー: リポジトリ情報を取得できませんでした${NC}"
	echo "リポジトリのディレクトリで実行するか、GITHUB_REPOSITORY 環境変数を設定してください"
	echo "例: GITHUB_REPOSITORY=owner/repo $0"
	exit 1
fi

echo -e "${GREEN}リポジトリ: $REPO${NC}"
echo ""

# 現在の設定を確認
current_setting=$(gh api "repos/$REPO" --jq '.allow_update_branch' 2>/dev/null || echo "false")

if [ "$current_setting" = "true" ]; then
	echo -e "${GREEN}PRブランチ更新提案は既に有効になっています${NC}"
	exit 0
fi

echo -e "${YELLOW}現在の設定: PRブランチ更新提案は無効です${NC}"

if [ "$DRY_RUN" = "1" ]; then
	echo -e "${YELLOW}[DRY-RUN] PRブランチ更新提案を有効にします（スキップ）${NC}"
else
	read -p "PRブランチ更新提案を有効にしますか? (y/N): " -n 1 -r
	echo

	if [[ $REPLY =~ ^[Yy]$ ]]; then
		# 設定を更新
		gh api "repos/$REPO" \
			--method PATCH \
			--field allow_update_branch=true \
			--silent

		echo -e "${GREEN}PRブランチ更新提案を有効にしました${NC}"
		echo "ベースブランチが更新された際にPRブランチの更新を提案するボタンが表示されます"
	else
		echo -e "${YELLOW}設定を変更しませんでした${NC}"
	fi
fi
