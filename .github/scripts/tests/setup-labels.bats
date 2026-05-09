#!/usr/bin/env bats

# setup-labels.sh のテスト

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

setup() {
    # テスト用の一時ディレクトリを作成
    TEST_DIR=$(mktemp -d)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    # モック用のパスを設定
    export PATH="$TEST_DIR:$PATH"

    # モックのghコマンドを作成
    cat > "$TEST_DIR/gh" <<'EOF'
#!/bin/bash
case "$1" in
    repo)
        if [ "$2" = "view" ]; then
            echo '{"nameWithOwner":"test-owner/test-repo"}'
        fi
        ;;
    label)
        case "$2" in
            list)
                # 既存のラベルをシミュレート（bug と enhancement は存在、todo は未存在）
                echo '[{"name":"bug"},{"name":"enhancement"}]'
                ;;
            create)
                # ラベル作成のモック
                exit 0
                ;;
            edit)
                # ラベル編集のモック
                exit 0
                ;;
        esac
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_DIR/gh"
}

teardown() {
    # 一時ディレクトリを削除
    rm -rf "$TEST_DIR"
}

@test "setup-labels.sh が存在する" {
    assert [ -f "$SCRIPT_DIR/setup-labels.sh" ]
}

@test "setup-labels.sh が実行可能である" {
    assert [ -x "$SCRIPT_DIR/setup-labels.sh" ]
}

@test "setup-labels.sh が正しいshebangを持っている" {
    run head -n 1 "$SCRIPT_DIR/setup-labels.sh"
    assert_output "#!/bin/bash"
}

@test "DRY_RUNモードで実際の変更を行わない" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_success
    assert_output --partial "[DRY-RUN モード]"
    assert_output --partial "実際の変更は行いません"
}

@test "リポジトリ情報を正しく取得する" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_success
    assert_output --partial "test-owner/test-repo"
}

@test "必要なラベルが定義されている" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_success
    assert_output --partial "bug"
    assert_output --partial "enhancement"
    assert_output --partial "todo"
    assert_output --partial "openspec-archive"
}

@test "既存のラベルを更新する" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_success
    assert_output --partial "既存のラベルが見つかりました"
}

@test "新規ラベルを作成する" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_success
    assert_output --partial "ラベルが存在しません"
    assert_output --partial "ラベルを作成します: todo"
}

@test "リポジトリが見つからない場合にエラーを表示する" {
    # ghコマンドを更新してリポジトリが見つからないようにする
    cat > "$TEST_DIR/gh" <<'EOF'
#!/bin/bash
case "$1" in
    repo)
        if [ "$2" = "view" ]; then
            exit 1
        fi
        ;;
esac
exit 1
EOF
    chmod +x "$TEST_DIR/gh"

    # git configも失敗させる
    cat > "$TEST_DIR/git" <<'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$TEST_DIR/git"

    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_failure
    assert_output --partial "GitHub リポジトリが見つかりません"
}

@test "ラベルの色が正しく設定されている" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_success
    assert_output --partial "d73a4a"  # bug の色
    assert_output --partial "a2eeef"  # enhancement の色
    assert_output --partial "0e8a16"  # todo の色
    assert_output --partial "0075ca"  # openspec-archive の色
}

@test "gh repo viewが失敗した場合にgit configから取得する" {
    # gh repo viewを失敗させるモック
    cat > "$TEST_DIR/gh" <<'EOF'
#!/bin/bash
case "$1" in
    repo)
        if [ "$2" = "view" ]; then
            exit 1  # 失敗させる
        fi
        ;;
    label)
        case "$2" in
            list)
                echo '[{"name":"bug"},{"name":"enhancement"}]'
                ;;
            create|edit)
                exit 0
                ;;
        esac
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_DIR/gh"

    # git configのモックを作成
    cat > "$TEST_DIR/git" <<'EOF'
#!/bin/bash
if [ "$1" = "config" ] && [ "$2" = "--get" ] && [ "$3" = "remote.origin.url" ]; then
    echo "git@github.com:fallback-owner/fallback-repo.git"
fi
exit 0
EOF
    chmod +x "$TEST_DIR/git"

    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-labels.sh"
    assert_success
    assert_output --partial "fallback-owner/fallback-repo"
}
