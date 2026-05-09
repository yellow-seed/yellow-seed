#!/bin/bash

# すべての GitHub 設定を一括でセットアップするスクリプト

# Dry-run モード（環境変数 DRY_RUN=1 で有効化）
DRY_RUN=${DRY_RUN:-0}
export DRY_RUN

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "GitHub 設定の一括セットアップ"
echo "=============================="
if [ "$DRY_RUN" = "1" ]; then
	echo "[DRY-RUN モード] 実際の変更は行いません"
fi
echo ""

declare -a SUCCESS_SCRIPTS=()
declare -a FAILED_SCRIPTS=()

run_script() {
	local number="$1"
	local name="$2"
	local script="$3"

	echo "${number}. ${name} を実行します..."
	if bash "$script"; then
		SUCCESS_SCRIPTS+=("$name")
		echo "✓ ${name} が完了しました"
	else
		FAILED_SCRIPTS+=("$name")
		echo "✗ ${name} が失敗しました"
	fi
	echo ""
}

run_script "1" "Ruleset のセットアップ" "$SCRIPT_DIR/setup-rulesets.sh"
run_script "2" "Repository settings のセットアップ" "$SCRIPT_DIR/setup-repository-settings.sh"
run_script "3" "ラベルの設定" "$SCRIPT_DIR/setup-labels.sh"
run_script "4" "GitHub Project のセットアップ" "$SCRIPT_DIR/setup-github-project.sh"

echo "※ Secrets の値はスクリプトに保存しません"
echo "   setup-repository-settings.sh の確認結果に従って GitHub UI または gh secret set で登録してください"
echo ""

echo "=============================="
echo "実行結果サマリー"
echo "=============================="
echo "成功: ${#SUCCESS_SCRIPTS[@]}"
for script in "${SUCCESS_SCRIPTS[@]}"; do
	echo "  ✓ ${script}"
done

if [ ${#FAILED_SCRIPTS[@]} -gt 0 ]; then
	echo ""
	echo "失敗: ${#FAILED_SCRIPTS[@]}"
	for script in "${FAILED_SCRIPTS[@]}"; do
		echo "  ✗ ${script}"
	done
	echo ""
	echo "一部のセットアップが失敗しました"
	exit 1
fi

echo ""
echo "すべてのセットアップが完了しました！"
