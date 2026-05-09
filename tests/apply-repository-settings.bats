#!/usr/bin/env bats

# apply-repository-settings.sh のテスト。terraform は PATH 上のモックを使う。

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_ROOT}/.github/scripts/apply-repository-settings.sh"

setup() {
	TEST_BIN="$(mktemp -d)"
	export PATH="${TEST_BIN}:/usr/bin:/bin"
	export TF_VAR_github_owner="test-owner"
	export TF_VAR_repository_name="expected-repo"
	export TF_VAR_github_token="fake-token"
	export MOCK_STATE_LIST=""
	export MOCK_STATE_REPO_NAME=""
	export APPLY_FLAG="${TEST_BIN}/apply_was_called"
	unset DRY_RUN || true

	cat >"${TEST_BIN}/terraform" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
shift || true

case "${cmd}" in
	init)
		exit 0
		;;
	state)
		subcmd="${1:-}"
		case "${subcmd}" in
			list)
				printf '%s\n' "${MOCK_STATE_LIST:-}"
				exit 0
				;;
			show)
				cat <<INNER
# github_repository.template:
resource "github_repository" "template" {
    name = "${MOCK_STATE_REPO_NAME:-wrong-repo}"
}
INNER
				exit 0
				;;
		esac
		exit 1
		;;
	import)
		exit 0
		;;
	plan)
		for arg in "$@"; do
			case "${arg}" in
				-out=*)
					touch "${arg#-out=}"
					;;
			esac
		done
		exit 0
		;;
	apply)
		: >"${APPLY_FLAG}"
		exit 0
		;;
esac

exit 1
EOF
	chmod +x "${TEST_BIN}/terraform"
	rm -f "${APPLY_FLAG}"
}

teardown() {
	rm -rf "${TEST_BIN}"
}

@test "TF_VAR_github_owner が未設定のとき非ゼロ終了する" {
	unset TF_VAR_github_owner

	run bash "${SCRIPT}"

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"TF_VAR_github_owner"* ]]
}

@test "DRY_RUN=1 のとき terraform apply が呼ばれない" {
	export DRY_RUN=1

	run bash "${SCRIPT}"

	[ "${status}" -eq 0 ]
	[ ! -f "${APPLY_FLAG}" ]
	[[ "${output}" == *"DRY_RUN=1"* ]]
}

@test "通常時は terraform apply が実行される" {
	run bash "${SCRIPT}"

	[ "${status}" -eq 0 ]
	[ -f "${APPLY_FLAG}" ]
}

@test "state 内のリポジトリ名が TF_VAR と不一致のとき非ゼロ終了する" {
	export MOCK_STATE_LIST="github_repository.template"
	export MOCK_STATE_REPO_NAME="other-repo"

	run bash "${SCRIPT}"

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"一致しません"* ]]
	[ ! -f "${APPLY_FLAG}" ]
}

@test "import 済みでリポジトリ名が一致するとき apply まで進む" {
	export MOCK_STATE_LIST="github_repository.template"
	export MOCK_STATE_REPO_NAME="expected-repo"

	run bash "${SCRIPT}"

	[ "${status}" -eq 0 ]
	[ -f "${APPLY_FLAG}" ]
}
