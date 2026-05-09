#!/usr/bin/env bats

# setup-all.sh のテスト

# batsライブラリを環境に応じて読み込む
# Ubuntu: /usr/lib/bats-support, macOS (Homebrew): /usr/local/lib/bats
if [ -f "/usr/lib/bats-support/load.bash" ]; then
    # Ubuntu (apt install bats-support bats-assert)
    load "/usr/lib/bats-support/load.bash"
    load "/usr/lib/bats-assert/load.bash"
elif [ -f "/usr/local/lib/bats/bats-support/load" ]; then
    # macOS Homebrew
    load "/usr/local/lib/bats/bats-support/load"
    load "/usr/local/lib/bats/bats-assert/load"
elif [ -f "/opt/homebrew/lib/bats/bats-support/load" ]; then
    # macOS Homebrew (Apple Silicon)
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
    # テスト用の一時ディレクトリを作成
    TEST_DIR=$(mktemp -d)
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    
    # モック用のパスを設定
    export PATH="$TEST_DIR:/usr/bin:/bin"
}

teardown() {
    # 一時ディレクトリを削除
    rm -rf "$TEST_DIR"
}

@test "setup-all.sh が存在する" {
    assert [ -f "$SCRIPT_DIR/setup-all.sh" ]
}

@test "setup-all.sh が実行可能である" {
    assert [ -x "$SCRIPT_DIR/setup-all.sh" ]
}

@test "setup-all.sh が正しいshebangを持っている" {
    run head -n 1 "$SCRIPT_DIR/setup-all.sh"
    assert_output "#!/bin/bash"
}

@test "setup-all.sh が他のスクリプトを呼び出す" {
    run grep -E "setup-(rulesets|repository-settings|labels|github-project)\\.sh" "$SCRIPT_DIR/setup-all.sh"
    assert_success
}

@test "setup-all.sh がsetup-github-project.shを含む" {
    run grep -q "setup-github-project.sh" "$SCRIPT_DIR/setup-all.sh"
    assert_success
}

@test "setup-all.sh がsetup-repository-settings.shを含む" {
    run grep -q "setup-repository-settings.sh" "$SCRIPT_DIR/setup-all.sh"
    assert_success
}
