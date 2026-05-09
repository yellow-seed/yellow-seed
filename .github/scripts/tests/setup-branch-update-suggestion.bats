#!/usr/bin/env bats

# setup-branch-update-suggestion.sh のテスト

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
    auth)
        if [ "$2" = "status" ]; then
            exit 0  # ログイン済みとして扱う
        fi
        ;;
    repo)
        if [ "$2" = "view" ]; then
            echo '{"nameWithOwner":"test-owner/test-repo"}'
        fi
        ;;
    api)
        if echo "$2" | grep -q "repos/"; then
            if [ "$3" = "--method" ] && [ "$4" = "PATCH" ]; then
                # 設定更新のモック
                exit 0
            else
                # 現在の設定を取得
                echo '{"allow_update_branch":false}'
            fi
        fi
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

@test "setup-branch-update-suggestion.sh が存在する" {
    assert [ -f "$SCRIPT_DIR/setup-branch-update-suggestion.sh" ]
}

@test "setup-branch-update-suggestion.sh が実行可能である" {
    assert [ -x "$SCRIPT_DIR/setup-branch-update-suggestion.sh" ]
}

@test "setup-branch-update-suggestion.sh が正しいshebangを持っている" {
    run head -n 1 "$SCRIPT_DIR/setup-branch-update-suggestion.sh"
    assert_output "#!/bin/bash"
}

@test "ghコマンドが見つからない場合にエラーを表示する" {
    # ghコマンドを削除
    rm -f "$TEST_DIR/gh"

    run bash "$SCRIPT_DIR/setup-branch-update-suggestion.sh" <<< ""
    assert_failure
    assert_output --partial "GitHub CLI (gh) がインストールされていません"
}

@test "gh repo viewが失敗した場合にgit configから取得する" {
    # gh repo viewを失敗させるモック
    cat > "$TEST_DIR/gh" <<'EOF'
#!/bin/bash
case "$1" in
    auth)
        if [ "$2" = "status" ]; then
            exit 0
        fi
        ;;
    repo)
        if [ "$2" = "view" ]; then
            exit 1  # 失敗させる
        fi
        ;;
    api)
        if echo "$2" | grep -q "repos/fallback-owner/fallback-repo"; then
            echo '{"allow_update_branch":false}'
        fi
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
    run bash "$SCRIPT_DIR/setup-branch-update-suggestion.sh"
    assert_output --partial "fallback-owner/fallback-repo"
}

@test "gh repo viewとgit configの両方が失敗した場合にエラー" {
    # gh repo viewを失敗させるモック
    cat > "$TEST_DIR/gh" <<'EOF'
#!/bin/bash
case "$1" in
    auth)
        if [ "$2" = "status" ]; then
            exit 0
        fi
        ;;
    *)
        exit 1
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

    run bash "$SCRIPT_DIR/setup-branch-update-suggestion.sh"
    assert_failure
    assert_output --partial "リポジトリ情報を取得できませんでした"
}

@test "環境変数GITHUB_REPOSITORYが設定されている場合は優先する" {
    export GITHUB_REPOSITORY="env-owner/env-repo"
    export DRY_RUN=1

    # ghモックを更新
    cat > "$TEST_DIR/gh" <<'EOF'
#!/bin/bash
case "$1" in
    auth)
        if [ "$2" = "status" ]; then
            exit 0
        fi
        ;;
    api)
        if echo "$2" | grep -q "repos/env-owner/env-repo"; then
            echo '{"allow_update_branch":false}'
        fi
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_DIR/gh"

    run bash "$SCRIPT_DIR/setup-branch-update-suggestion.sh"
    assert_output --partial "env-owner/env-repo"
}
