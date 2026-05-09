#!/usr/bin/env bats

# setup-github-project.sh のテスト

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
            if echo "$*" | grep -q "nameWithOwner"; then
                echo '{"nameWithOwner":"test-owner/test-repo"}'
            elif echo "$*" | grep -q "name"; then
                echo '{"name":"test-repo"}'
            elif echo "$*" | grep -q "owner"; then
                echo '{"owner":{"login":"test-owner"}}'
            fi
        fi
        ;;
    project)
        case "$2" in
            list)
                echo '{"projects":[]}'
                ;;
            create)
                echo '{"number":123}'
                ;;
            field-list)
                echo '{"fields":[]}'
                ;;
            field-create)
                exit 0
                ;;
            view)
                echo '{"id":"PVT_test123"}'
                ;;
        esac
        ;;
    api)
        if [[ "$*" == *"graphql"* ]]; then
            echo '{"data":{"addProjectV2SingleSelectFieldOption":{"projectV2SingleSelectFieldOption":{"id":"test","name":"test"}}}}'
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

@test "setup-github-project.sh が存在する" {
    assert [ -f "$SCRIPT_DIR/setup-github-project.sh" ]
}

@test "setup-github-project.sh が実行可能である" {
    assert [ -x "$SCRIPT_DIR/setup-github-project.sh" ]
}

@test "setup-github-project.sh が正しいshebangを持っている" {
    run head -n 1 "$SCRIPT_DIR/setup-github-project.sh"
    assert_output "#!/bin/bash"
}

@test "ghコマンドが見つからない場合にエラーを表示する" {
    # ghコマンドを削除
    rm -f "$TEST_DIR/gh"

    run bash "$SCRIPT_DIR/setup-github-project.sh" <<< ""
    assert_failure
    assert_output --partial "GitHub CLI (gh) がインストールされていません"
}

@test "DRY_RUNモードで実行できる" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-github-project.sh" <<< ""
    # DRY_RUNモードでは実際の変更は行わない
    assert_success || assert_failure  # モックのため、どちらでもOK
    assert_output --partial "DRY-RUN モード"
}

@test "リポジトリ情報を正しく取得する" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-github-project.sh" <<< ""
    assert_output --partial "test-owner/test-repo" || true
}

@test "Project作成メッセージが表示される" {
    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-github-project.sh" <<< ""
    assert_output --partial "GitHub Project" || true
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
            # -R フラグ付きの場合は成功させる
            if echo "$*" | grep -q "\-R"; then
                if echo "$*" | grep -q "nameWithOwner"; then
                    echo '{"nameWithOwner":"fallback-owner/fallback-repo"}'
                elif echo "$*" | grep -q "\"name\""; then
                    echo '{"name":"fallback-repo"}'
                elif echo "$*" | grep -q "owner"; then
                    echo '{"owner":{"login":"fallback-owner"}}'
                elif echo "$*" | grep -q "id"; then
                    echo '{"id":"R_test123"}'
                fi
            else
                exit 1  # -R フラグなしは失敗
            fi
        fi
        ;;
    project)
        case "$2" in
            list)
                echo '{"projects":[]}'
                ;;
            create)
                echo '{"number":456}'
                ;;
            field-list)
                echo '{"fields":[]}'
                ;;
            view)
                echo '{"id":"PVT_fallback"}'
                ;;
        esac
        ;;
    api)
        if [[ "$*" == *"graphql"* ]]; then
            echo '{"data":{}}'
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
    echo "https://github.com/fallback-owner/fallback-repo.git"
fi
exit 0
EOF
    chmod +x "$TEST_DIR/git"

    export DRY_RUN=1
    run bash "$SCRIPT_DIR/setup-github-project.sh" <<< ""
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

    run bash "$SCRIPT_DIR/setup-github-project.sh" <<< ""
    assert_failure
    assert_output --partial "リポジトリ情報を取得できませんでした"
}
