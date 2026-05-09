#!/usr/bin/env bash
set -euo pipefail

# .github/terraform/repository-settings の Terraform を init / import / plan / apply する。

DRY_RUN="${DRY_RUN:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
	local message="$1"
	echo -e "${GREEN}[INFO]${NC} ${message}"
}

log_warn() {
	local message="$1"
	echo -e "${YELLOW}[WARN]${NC} ${message}"
}

log_error() {
	local message="$1"
	echo -e "${RED}[ERROR]${NC} ${message}" >&2
}

require_command() {
	local command_name="$1"
	if ! command -v "${command_name}" >/dev/null 2>&1; then
		log_error "${command_name} が見つかりません"
		exit 1
	fi
}

require_env() {
	local name="$1"
	if [[ -z ${!name:-} ]]; then
		log_error "${name} が設定されていません"
		exit 1
	fi
}

state_managed_repository_name() {
	local line

	while IFS= read -r line || [[ -n ${line} ]]; do
		if [[ ${line} =~ ^[[:space:]]*name[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]]; then
			echo "${BASH_REMATCH[1]}"
			return 0
		fi
	done < <(terraform state show "${RESOURCE_ADDR}" 2>/dev/null)

	return 1
}

ensure_repository_imported() {
	local state_list
	local state_name

	state_list="$(terraform state list 2>/dev/null || true)"

	if printf '%s\n' "${state_list}" | grep -Fxq "${RESOURCE_ADDR}"; then
		if ! state_name="$(state_managed_repository_name)" || [[ -z ${state_name} ]]; then
			log_error "${RESOURCE_ADDR} は state にありますがリポジトリ名を取得できませんでした"
			exit 1
		fi

		if [[ ${state_name} != "${TARGET_REPOSITORY_NAME}" ]]; then
			log_error "Terraform state のリポジトリ (${state_name}) と TF_VAR_repository_name (${TARGET_REPOSITORY_NAME}) が一致しません"
			log_error "誤ったリポジトリを更新しないよう中断しました。state を確認するか terraform state rm ${RESOURCE_ADDR} のうえ再 import してください"
			exit 1
		fi

		log_info "${RESOURCE_ADDR} は import 済みです (${TARGET_REPOSITORY_NAME})"
		return 0
	fi

	log_info "${RESOURCE_ADDR} を ${TARGET_REPOSITORY_NAME} から import します"
	terraform import -input=false "${RESOURCE_ADDR}" "${TARGET_REPOSITORY_NAME}"
}

main() {
	require_command terraform
	require_env TF_VAR_github_owner
	require_env TF_VAR_repository_name
	require_env TF_VAR_github_token

	# shellcheck disable=SC2154 # require_env で検証済み
	readonly TARGET_REPOSITORY_NAME="${TF_VAR_repository_name}"
	REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
	readonly REPO_ROOT
	readonly TF_DIR="${REPO_ROOT}/.github/terraform/repository-settings"
	readonly RESOURCE_ADDR="github_repository.template"

	cd "${TF_DIR}"

	log_info "Terraform init"
	terraform init -input=false

	ensure_repository_imported

	TFPLAN="$(mktemp)"
	trap 'rm -f "${TFPLAN}"' EXIT

	log_info "Terraform plan"
	terraform plan -input=false -out="${TFPLAN}"

	if [[ ${DRY_RUN} == "1" ]]; then
		log_warn "DRY_RUN=1 のため apply はスキップします"
		exit 0
	fi

	log_info "Terraform apply"
	terraform apply -input=false "${TFPLAN}"

	log_info "完了しました"
}

main "$@"
