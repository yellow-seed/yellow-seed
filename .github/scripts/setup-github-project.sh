#!/bin/bash

# GitHub Project セットアップスクリプト
# このスクリプトは、GitHub CLI (gh) を使用して GitHub Project を設定します

set -e

# Dry-run モード（環境変数 DRY_RUN=1 で有効化）
DRY_RUN=${DRY_RUN:-0}

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}GitHub Project セットアップスクリプト${NC}"
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

# gh repo view が使える場合は直接取得、使えない場合は -R フラグで取得
REPO_NAME=$(gh repo view --json name -q .name 2>/dev/null || gh repo view -R "$REPO" --json name -q .name 2>/dev/null || echo "")
OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null || gh repo view -R "$REPO" --json owner -q .owner.login 2>/dev/null || echo "")

echo -e "${GREEN}リポジトリ: $REPO${NC}"
echo ""

# Project名を設定
PROJECT_TITLE="${REPO_NAME} Issue Tracker"

# 既存のProjectをチェック
echo "既存のProjectを確認中..."
EXISTING_PROJECT=$(gh project list --owner "$OWNER" --format json 2>/dev/null | jq -r ".projects[] | select(.title == \"$PROJECT_TITLE\") | .number" || echo "")

if [ -n "$EXISTING_PROJECT" ]; then
	echo -e "${YELLOW}既存のProject「$PROJECT_TITLE」が見つかりました (番号: $EXISTING_PROJECT)${NC}"

	if [ "$DRY_RUN" = "1" ]; then
		echo -e "${YELLOW}[DRY-RUN] Projectは既に存在します（スキップ）${NC}"
		exit 0
	else
		read -p "既存のProjectを使用しますか? (Y/n): " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Nn]$ ]]; then
			PROJECT_NUMBER="$EXISTING_PROJECT"
			echo -e "${GREEN}既存のProjectを使用します${NC}"
		else
			echo -e "${YELLOW}スクリプトを終了します${NC}"
			exit 0
		fi
	fi
else
	if [ "$DRY_RUN" = "1" ]; then
		echo -e "${YELLOW}[DRY-RUN] 新しいProject「$PROJECT_TITLE」を作成します（スキップ）${NC}"
		exit 0
	else
		# 新しいProjectを作成
		echo -e "${GREEN}新しいProject「$PROJECT_TITLE」を作成中...${NC}"
		PROJECT_NUMBER=$(gh project create --owner "$OWNER" --title "$PROJECT_TITLE" --format json 2>/dev/null | jq -r '.number')

		if [ -z "$PROJECT_NUMBER" ]; then
			echo -e "${RED}エラー: Projectの作成に失敗しました${NC}"
			exit 1
		fi

		echo -e "${GREEN}Project #$PROJECT_NUMBER を作成しました${NC}"
	fi
fi

# Projectのフィールドを設定
echo ""
echo -e "${GREEN}Projectのフィールドを設定中...${NC}"

# Status フィールド（デフォルトで存在する可能性があるので確認）
echo "Status フィールドを確認中..."
STATUS_FIELD=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null | jq -r '.fields[] | select(.name == "Status") | .id' || echo "")
PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json | jq -r '.id')

if [ -z "$STATUS_FIELD" ]; then
	if [ "$DRY_RUN" = "1" ]; then
		echo -e "${YELLOW}[DRY-RUN] Status フィールドを作成します（スキップ）${NC}"
	else
		echo "Status フィールドを作成中..."
		cat >/tmp/gh-project-status.json <<EOF
{
  "query": "mutation(\$projectId: ID!, \$name: String!, \$dataType: ProjectV2CustomFieldType!, \$options: [ProjectV2SingleSelectFieldOptionInput!]) { createProjectV2Field(input: { projectId: \$projectId dataType: \$dataType name: \$name singleSelectOptions: \$options }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } } }",
  "variables": {
    "projectId": "$PROJECT_ID",
    "name": "Status",
    "dataType": "SINGLE_SELECT",
    "options": [
      {"name": "Todo", "color": "GRAY", "description": ""},
      {"name": "Ready", "color": "BLUE", "description": ""},
      {"name": "In Progress", "color": "YELLOW", "description": ""},
      {"name": "Done", "color": "GREEN", "description": ""}
    ]
  }
}
EOF
		gh api graphql --input /tmp/gh-project-status.json >/dev/null 2>&1 || true
		rm -f /tmp/gh-project-status.json

		echo -e "${GREEN}Status フィールドを設定しました${NC}"
	fi
else
	echo -e "${YELLOW}Status フィールドは既に存在します${NC}"
fi

# Priority フィールド
echo "Priority フィールドを確認中..."
PRIORITY_FIELD=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null | jq -r '.fields[] | select(.name == "Priority") | .id' || echo "")

if [ -z "$PRIORITY_FIELD" ]; then
	echo "Priority フィールドを作成中..."
	PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json | jq -r '.id')

	cat >/tmp/gh-project-priority.json <<-EOF
		{
		  "query": "mutation(\$projectId: ID!, \$name: String!, \$dataType: ProjectV2CustomFieldType!, \$options: [ProjectV2SingleSelectFieldOptionInput!]) { createProjectV2Field(input: { projectId: \$projectId dataType: \$dataType name: \$name singleSelectOptions: \$options }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } } }",
		  "variables": {
		    "projectId": "$PROJECT_ID",
		    "name": "Priority",
		    "dataType": "SINGLE_SELECT",
		    "options": [
		      {"name": "Low", "color": "GRAY", "description": ""},
		      {"name": "Medium", "color": "YELLOW", "description": ""},
		      {"name": "High", "color": "ORANGE", "description": ""},
		      {"name": "Critical", "color": "RED", "description": ""}
		    ]
		  }
		}
	EOF
	gh api graphql --input /tmp/gh-project-priority.json >/dev/null 2>&1 || true
	rm -f /tmp/gh-project-priority.json

	echo -e "${GREEN}Priority フィールドを設定しました${NC}"
else
	echo -e "${YELLOW}Priority フィールドは既に存在します${NC}"
fi

# Category フィールド
echo "Category フィールドを確認中..."
CATEGORY_FIELD=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null | jq -r '.fields[] | select(.name == "Category") | .id' || echo "")

if [ -z "$CATEGORY_FIELD" ]; then
	echo "Category フィールドを作成中..."
	PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json | jq -r '.id')

	cat >/tmp/gh-project-category.json <<-EOF
		{
		  "query": "mutation(\$projectId: ID!, \$name: String!, \$dataType: ProjectV2CustomFieldType!, \$options: [ProjectV2SingleSelectFieldOptionInput!]) { createProjectV2Field(input: { projectId: \$projectId dataType: \$dataType name: \$name singleSelectOptions: \$options }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } } }",
		  "variables": {
		    "projectId": "$PROJECT_ID",
		    "name": "Category",
		    "dataType": "SINGLE_SELECT",
		    "options": [
		      {"name": "Feature", "color": "BLUE", "description": ""},
		      {"name": "Bug", "color": "RED", "description": ""},
		      {"name": "Enhancement", "color": "PURPLE", "description": ""},
		      {"name": "Documentation", "color": "GRAY", "description": ""},
		      {"name": "Refactor", "color": "PINK", "description": ""}
		    ]
		  }
		}
	EOF
	gh api graphql --input /tmp/gh-project-category.json >/dev/null 2>&1 || true
	rm -f /tmp/gh-project-category.json

	echo -e "${GREEN}Category フィールドを設定しました${NC}"
else
	echo -e "${YELLOW}Category フィールドは既に存在します${NC}"
fi

echo ""
echo -e "${GREEN}セットアップが完了しました！${NC}"
echo -e "Project URL: https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
echo ""

# Projectにリポジトリをリンク
echo "Projectにリポジトリをリンク中..."
PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json | jq -r '.id')
REPO_ID=$(gh repo view --json id -q .id 2>/dev/null || gh repo view -R "$REPO" --json id -q .id)

gh api graphql -f query="
  mutation(\$projectId: ID!, \$repositoryId: ID!) {
    linkProjectV2ToRepository(input: {
      projectId: \$projectId
      repositoryId: \$repositoryId
    }) {
      repository {
        id
      }
    }
  }" -f projectId="$PROJECT_ID" -f repositoryId="$REPO_ID" >/dev/null 2>&1 || echo -e "${YELLOW}リポジトリのリンクをスキップしました（既にリンクされている可能性があります）${NC}"

echo ""
echo "次のステップ:"
echo "1. Projectページでビュー（Board/Table）をカスタマイズできます"
echo "2. 新しいIssueは自動的にTodoステータスで追加されます"
echo "3. 既存のIssueを追加: gh project item-add $PROJECT_NUMBER --owner $OWNER --url <issue-url>"
echo ""
echo -e "${GREEN}Issueを作成すると、自動的にProjectのTodoステータスに追加されます${NC}"
echo -e "次に取り掛かるIssueは、TodoからReadyに移動してください"
