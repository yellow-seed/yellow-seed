#!/usr/bin/env bash
set -euo pipefail

# GitHub repository / Actions / security settings setup script.

DRY_RUN=${DRY_RUN:-0}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
	local message="$1"
	echo -e "${GREEN}${message}${NC}"
}

log_warn() {
	local message="$1"
	echo -e "${YELLOW}${message}${NC}"
}

log_error() {
	local message="$1"
	echo -e "${RED}${message}${NC}" >&2
}

run_gh() {
	if [[ $DRY_RUN == "1" ]]; then
		printf '[DRY-RUN] gh'
		printf ' %q' "${@:2}"
		printf '\n'
		return 0
	fi

	"$@"
}

get_repo() {
	local repo="${GITHUB_REPOSITORY:-}"

	if [[ -z $repo ]]; then
		repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")"
	fi

	if [[ -z $repo ]]; then
		repo="$(git config --get remote.origin.url 2>/dev/null | sed -E 's|^.*github\.com[/:]||; s|\.git$||' || echo "")"
	fi

	if [[ -z $repo ]]; then
		log_error "エラー: リポジトリ情報を取得できませんでした"
		echo "リポジトリのディレクトリで実行するか、GITHUB_REPOSITORY 環境変数を設定してください" >&2
		exit 1
	fi

	echo "$repo"
}

require_gh() {
	if ! command -v gh &>/dev/null; then
		log_error "エラー: GitHub CLI (gh) がインストールされていません"
		echo "インストール方法: https://cli.github.com/" >&2
		exit 1
	fi

	if ! gh auth status &>/dev/null; then
		if [[ $DRY_RUN == "1" ]]; then
			log_warn "GitHub CLI にログインしていません（DRY-RUN のためログインせず続行します）"
			return 0
		fi

		log_warn "GitHub CLI にログインしていません"
		echo "ログインを実行します..."
		gh auth login
	fi
}

require_jq() {
	if ! command -v jq &>/dev/null; then
		log_error "エラー: jq がインストールされていません"
		exit 1
	fi
}

apply_security_settings() {
	local repo="$1"

	# vulnerability_alerts / secret_scanning / secret_scanning_push_protection は
	# .github/terraform/repository-settings/main.tf で管理する
	log_info "Security 設定を適用中..."
	run_gh gh api "repos/$repo" \
		--method PATCH \
		--field 'security_and_analysis[dependabot_security_updates][status]=enabled' \
		--field 'security_and_analysis[secret_scanning_non_provider_patterns][status]=disabled' \
		--field 'security_and_analysis[secret_scanning_validity_checks][status]=disabled' \
		--silent
}

apply_actions_settings() {
	local repo="$1"

	log_info "Actions 権限設定を適用中..."
	run_gh gh api "repos/$repo/actions/permissions" \
		--method PUT \
		--field enabled=true \
		--field allowed_actions=all \
		--silent

	run_gh gh api "repos/$repo/actions/permissions/workflow" \
		--method PUT \
		--field default_workflow_permissions=read \
		--field can_approve_pull_request_reviews=false \
		--silent
}

apply_environment_settings() {
	local repo="$1"

	log_info "Environment 設定を適用中..."
	run_gh gh api "repos/$repo/environments/copilot" \
		--method PUT \
		--silent
}

check_required_secrets() {
	local repo="$1"
	local secrets_json
	local required_secrets=(
		"ADD_TO_PROJECT_PAT"
		"CLAUDE_CODE_OAUTH_TOKEN"
		"PROJECT_URL"
	)

	log_info "Actions secrets を確認中..."
	if [[ $DRY_RUN == "1" ]]; then
		for secret_name in "${required_secrets[@]}"; do
			echo "  - ${secret_name}（DRY-RUN のため存在確認はスキップ）"
		done
		return 0
	fi

	secrets_json="$(gh api "repos/$repo/actions/secrets" 2>/dev/null || echo '{"secrets":[]}')"

	for secret_name in "${required_secrets[@]}"; do
		if jq -e --arg name "$secret_name" '.secrets[]? | select(.name == $name)' <<<"$secrets_json" >/dev/null; then
			echo "  ✓ ${secret_name}"
		else
			log_warn "  ! ${secret_name} が未設定です（値はスクリプト化せず、GitHub UI または gh secret set で登録してください）"
		fi
	done
}

main() {
	echo -e "${GREEN}GitHub repository settings セットアップスクリプト${NC}"
	echo "================================================"

	if [[ $DRY_RUN == "1" ]]; then
		log_warn "[DRY-RUN モード] 実際の変更は行いません"
		echo ""
	fi

	require_gh
	require_jq

	local repo
	repo="$(get_repo)"

	log_info "リポジトリ: $repo"
	echo ""

	apply_security_settings "$repo"
	apply_actions_settings "$repo"
	apply_environment_settings "$repo"
	check_required_secrets "$repo"

	echo ""
	log_info "Repository settings のセットアップが完了しました！"
}

main "$@"
