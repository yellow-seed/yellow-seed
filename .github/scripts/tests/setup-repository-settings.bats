#!/usr/bin/env bats

# setup-repository-settings.sh のテスト

if [ -f "/usr/lib/bats-support/load.bash" ]; then
    load "/usr/lib/bats-support/load.bash"
    load "/usr/lib/bats-assert/load.bash"
elif [ -f "/usr/local/lib/bats/bats-support/load" ]; then
    load "/usr/local/lib/bats/bats-support/load"
    load "/usr/local/lib/bats/bats-assert/load"
elif [ -f "/opt/homebrew/lib/bats/bats-support/load" ]; then
    load "/opt/homebrew/lib/bats/bats-support/load"
    load "/opt/homebrew/lib/bats/bats-assert/load"
fi

if ! declare -F assert_success >/dev/null; then
    assert() { "$@"; }
    assert_success() { [ "$status" -eq 0 ]; }
    assert_failure() { [ "$status" -ne 0 ]; }
    assert_output() {
        if [ "${1:-}" = "--partial" ]; then
            [[ "$output" == *"$2"* ]]
        else
            [ "$output" = "$1" ]
        fi
    }
fi

setup() {
    TEST_DIR=$(mktemp -d)
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export PATH="$TEST_DIR:/usr/bin:/bin"
    export GH_CALL_LOG="$TEST_DIR/gh-calls.log"

    cat > "$TEST_DIR/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    auth)
        if [ "$2" = "status" ]; then
            exit 0
        fi
        ;;
    repo)
        if [ "$2" = "view" ]; then
            echo "test-owner/test-repo"
            exit 0
        fi
        ;;
    api)
        echo "$*" >> "$GH_CALL_LOG"
        if [ "$2" = "repos/test-owner/test-repo/actions/secrets" ]; then
            echo '{"secrets":[{"name":"ADD_TO_PROJECT_PAT"},{"name":"CLAUDE_CODE_OAUTH_TOKEN"},{"name":"PROJECT_URL"}]}'
        fi
        exit 0
        ;;
esac

exit 0
EOF
    chmod +x "$TEST_DIR/gh"

    cat > "$TEST_DIR/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "-e" ] && [ "${2:-}" = "--arg" ]; then
    name="$4"
    input="$(cat)"
    if [[ "$input" == *"\"name\":\"$name\""* ]]; then
        exit 0
    fi
    exit 1
fi

cat
EOF
    chmod +x "$TEST_DIR/jq"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "setup-repository-settings.sh が存在する" {
    assert [ -f "$SCRIPT_DIR/setup-repository-settings.sh" ]
}

@test "setup-repository-settings.sh が実行可能である" {
    assert [ -x "$SCRIPT_DIR/setup-repository-settings.sh" ]
}

@test "setup-repository-settings.sh が正しいshebangを持っている" {
    run head -n 1 "$SCRIPT_DIR/setup-repository-settings.sh"
    assert_output "#!/usr/bin/env bash"
}

@test "ghコマンドが見つからない場合にエラーを表示する" {
    rm -f "$TEST_DIR/gh"

    run env PATH="$TEST_DIR" /bin/bash "$SCRIPT_DIR/setup-repository-settings.sh"
    assert_failure
    assert_output --partial "GitHub CLI (gh) がインストールされていません"
}

@test "DRY_RUNでGitHub UI由来の設定を表示する" {
    export DRY_RUN=1

    run bash "$SCRIPT_DIR/setup-repository-settings.sh"
    assert_success
    assert_output --partial "actions/permissions/workflow"
    assert_output --partial "environments/copilot"
    assert_output --partial "ADD_TO_PROJECT_PAT"
}

@test "Repository / Actions / security / environment 設定APIを呼び出す" {
    run bash "$SCRIPT_DIR/setup-repository-settings.sh"
    assert_success

    run grep -q "repos/test-owner/test-repo --method PATCH" "$GH_CALL_LOG"
    assert_success

    run grep -q "repos/test-owner/test-repo/actions/permissions/workflow --method PUT" "$GH_CALL_LOG"
    assert_success

    run grep -q "repos/test-owner/test-repo/environments/copilot --method PUT" "$GH_CALL_LOG"
    assert_success
}

@test "環境変数GITHUB_REPOSITORYが設定されている場合は優先する" {
    export GITHUB_REPOSITORY="env-owner/env-repo"
    export DRY_RUN=1

    run bash "$SCRIPT_DIR/setup-repository-settings.sh"
    assert_success
    assert_output --partial "env-owner/env-repo"
}
