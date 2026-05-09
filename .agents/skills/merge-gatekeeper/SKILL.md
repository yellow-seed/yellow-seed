---
name: merge-gatekeeper
description: "PR のマージゲートキーパースキル。CI 状態・コンフリクトの有無を自動判定し、安全にマージを実行。追跡用ラベル `merged-by-gatekeeper` を付与して後から検索可能にする。Use when: PRのマージ、マージ作業の自動化、CI通過済みPRの一括マージを依頼された時。"
---

# Merge Gatekeeper

PR のマージ作業を効率化するゲートキーパースキル。
CI が通過している PR のマージ判定を自動化し、安全にマージを実行する。
マージ前に追跡用ラベルを付与することで、後からゲートキーパーでマージされた PR を検索可能にする。

## 環境判定

```bash
# *_REMOTE が設定されていれば Web 環境
# 設定されていなければ ローカル環境
is_remote_env() {
  env | grep -qE '^[A-Z_]+_REMOTE='
}
```

| 環境 | 判定 | 動作 |
|------|------|------|
| ローカルPC | `*_REMOTE` なし | `gh` コマンドで直接実行 |
| Claude Code Web / Codex Web | `*_REMOTE=true` | `gh` コマンドで直接実行 |

両環境とも `gh` コマンドが利用可能である前提。

## 追跡ラベル

マージした PR を後から検索できるよう、`merged-by-gatekeeper` ラベルを付与する。

| 項目 | 値 |
|------|-----|
| ラベル名 | `merged-by-gatekeeper` |
| 色 | `#6B9080`（セージグリーン） |
| 説明 | PR merged by merge-gatekeeper skill |

### ラベルの存在確認と自動作成

```bash
# ラベルの存在確認
gh label list --search "merged-by-gatekeeper" --json name --jq '.[].name' | grep -q "^merged-by-gatekeeper$"

# 存在しない場合は作成
if ! gh label list --search "merged-by-gatekeeper" --json name --jq '.[].name' | grep -q "^merged-by-gatekeeper$"; then
  gh label create "merged-by-gatekeeper" \
    --color "6B9080" \
    --description "PR merged by merge-gatekeeper skill"
fi
```

## マージ判定フロー

PR をマージする前に以下の条件を全て確認する。

### 1. CI ステータスチェック

```bash
# PR の CI チェック状態を取得
gh pr checks <pr-number> --json name,state --jq '.[] | select(.state != "SUCCESS") | .name'
```

- 出力が空 = 全て SUCCESS
- 出力がある = 失敗中のチェックが存在

### 2. コンフリクト状態の確認

```bash
# PR のマージ状態を取得
MERGE_STATUS=$(gh pr view <pr-number> --json mergeStateStatus --jq '.mergeStateStatus')
```

| `mergeStateStatus` | 意味 | マージ可否 |
|---------------------|------|-----------|
| `CLEAN` | コンフリクトなし | マージ可能 |
| `CONFLICTING` | コンフリクトあり | マージ不可 |
| `UNKNOWN` | 状態不明 | 要確認 |
| `BLOCKED` | 保護ルールでブロック | マージ不可 |
| `BEHIND` | ベースブランチに遅れている | マージ可能（設定による） |

### 3. ブランチ保護ルールの確認

```bash
# ルールセットの確認
gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.target == "branch")'
```

このテンプレートでは `.github/rulesets/branch-protection-ruleset.json` で定義。
主な要件：
- 1 件のレビュー承認（オプション）
- CI ステータスチェック `ci` の成功
- non-fast-forward の禁止

## マージ実行手順

### 単一 PR のマージ

```bash
# 1. ラベルの存在確認と作成
if ! gh label list --search "merged-by-gatekeeper" --json name --jq '.[].name' | grep -q "^merged-by-gatekeeper$"; then
  gh label create "merged-by-gatekeeper" \
    --color "6B9080" \
    --description "PR merged by merge-gatekeeper skill"
fi

# 2. マージ判定
CI_FAILED=$(gh pr checks <pr-number> --json name,state --jq '.[] | select(.state != "SUCCESS") | .name' | wc -l)
MERGE_STATUS=$(gh pr view <pr-number> --json mergeStateStatus --jq '.mergeStateStatus')

if [ "$CI_FAILED" -gt 0 ]; then
  echo "CI checks failed. Skipping PR #<pr-number>"
  exit 1
fi

if [ "$MERGE_STATUS" = "CONFLICTING" ]; then
  echo "PR has conflicts. Skipping PR #<pr-number>"
  exit 1
fi

if [ "$MERGE_STATUS" = "BLOCKED" ]; then
  echo "PR is blocked by branch protection. Skipping PR #<pr-number>"
  exit 1
fi

# 3. 追跡ラベルを付与
gh pr edit <pr-number> --add-label "merged-by-gatekeeper"

# 4. マージ実行（マージコミット作成、PRタイトルをそのまま使用）
gh pr merge <pr-number> \
  --merge \
  --delete-branch \
  --subject "$(gh pr view <pr-number> --json title --jq '.title')"

# 5. マージ成功確認
gh pr view <pr-number> --json state --jq '.state' | grep -q "MERGED"
```

### 複数 PR のマージ（バッチ処理）

```bash
# マージ対象 PR の一覧取得（CI 成功済みのもの）
gh pr list --search "status:success is:open" --json number,title,mergeStateStatus --jq '.[] | select(.mergeStateStatus == "CLEAN") | .number'
```

バッチ処理フロー：

```bash
#!/bin/bash

# 追跡ラベルの存在確認と作成
if ! gh label list --search "merged-by-gatekeeper" --json name --jq '.[].name' | grep -q "^merged-by-gatekeeper$"; then
  gh label create "merged-by-gatekeeper" \
    --color "6B9080" \
    --description "PR merged by merge-gatekeeper skill"
fi

# マージ対象 PR の一覧取得
PR_NUMBERS=$(gh pr list --search "status:success is:open" --json number,mergeStateStatus --jq '.[] | select(.mergeStateStatus == "CLEAN" or .mergeStateStatus == "BEHIND") | .number')

SKIPPED=()
MERGED=()

for PR_NUM in $PR_NUMBERS; do
  echo "Processing PR #$PR_NUM..."

  # 再確認：CI 状態
  CI_FAILED=$(gh pr checks "$PR_NUM" --json name,state --jq '.[] | select(.state != "SUCCESS") | .name' | wc -l)
  if [ "$CI_FAILED" -gt 0 ]; then
    echo "  CI checks failed. Skipping."
    SKIPPED+=("$PR_NUM")
    continue
  fi

  # 再確認：コンフリクト状態
  MERGE_STATUS=$(gh pr view "$PR_NUM" --json mergeStateStatus --jq '.mergeStateStatus')
  if [ "$MERGE_STATUS" = "CONFLICTING" ] || [ "$MERGE_STATUS" = "BLOCKED" ]; then
    echo "  PR has conflicts or is blocked. Skipping."
    SKIPPED+=("$PR_NUM")
    continue
  fi

  # 追跡ラベルを付与
  gh pr edit "$PR_NUM" --add-label "merged-by-gatekeeper"

  # マージ実行
  if gh pr merge "$PR_NUM" \
    --merge \
    --delete-branch \
    --subject "$(gh pr view "$PR_NUM" --json title --jq '.title')"; then
    echo "  Merged successfully."
    MERGED+=("$PR_NUM")
  else
    echo "  Merge failed. Skipping."
    SKIPPED+=("$PR_NUM")
  fi
done

# 結果サマリー
echo ""
echo "=== Merge Summary ==="
echo "Merged: ${#MERGED[@]} PRs"
for num in "${MERGED[@]}"; do
  echo "  - PR #$num"
done

if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo ""
  echo "Skipped: ${#SKIPPED[@]} PRs"
  for num in "${SKIPPED[@]}"; do
    echo "  - PR #$num"
  done
fi
```

## コンフリクトハンドリング

コンフリクトが発生した PR はスキップし、他のマージ可能 PR の処理を継続する。

1. コンフリクト検出（`mergeStateStatus == "CONFLICTING"`）
2. その PR をスキップリストに追加
3. ログ出力：`Skipped PR #<number>: conflicts detected`
4. 次の PR へ継続

マージ終了後にスキップされた PR の一覧を出力する。

## 実装タスクでの使用

`/opsx:apply` で実装完了後、マージ作業を依頼された際にこのスキルを参照する。

- マージ対象の PR 番号を指定して単一マージ
- 条件を満たす全 PR をバッチ処理でマージ
- 両方とも `merged-by-gatekeeper` ラベルを付与して追跡可能にする

## 他のスキルとの連携

- `pull-request`: マージ後の PR 状態確認、PR 作成フローとの連携
- `self-review`: マージ前の最終確認に使用
- `git-branch-worktree`: マージ後のブランチ削除、worktree 整理

## 注意事項

- マージは取消し不可。実行前に必ず判定条件を確認する
- コンフリクト発生時は無理にマージせず、スキップして手動対応とする
- `--delete-branch` を使用するため、マージ後にブランチは自動削除される
- Web 環境では `gh` コマンドの認証状態を事前に確認する
- バッチ処理中は各 PR の間に短いウェイトを置くことを推奨（API レート制限回避）
- マージ失敗時は原因を特定し、手動対応が必要な場合はスキップして継続する
