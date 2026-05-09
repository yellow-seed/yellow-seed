---
name: react-to-review
description: "PRレビューコメント対応スキル。レビューコメントを取得し、妥当な指摘を修正したうえで各コメントへ対応結果とコミットSHAを返信する。Use when: レビューコメント対応、レビュー指摘の修正、コメント返信の自動化を依頼された時。"
---

# react-to-review

PRのレビューコメントに対応するためのスキルです。

レビューコメントを取得し、妥当な指摘を修正したうえで、
各コメントに「何を対応したか」と「対応コミットSHA」を返信します。

## このスキルの目的

- レビュー対応漏れを防ぐ
- どのコメントにどのコミットで対応したかを明確化する
- レビュアーの再確認コストを下げる

## 前提条件

- 対象PR番号が分かっていること
- `gh` コマンドが利用可能で認証済みであること
- 修正作業用ブランチにチェックアウト済みであること

## 実施手順

### 1. 対象PRのレビューコメントを取得

```bash
# owner/repo は環境に合わせて置き換える
REPO="owner/repo"
PR_NUMBER="123"

gh api \
  --paginate \
  "repos/${REPO}/pulls/${PR_NUMBER}/comments" \
  --jq '.[] | {id: .id, path: .path, line: .line, user: .user.login, body: .body}'
```

必要に応じて未対応コメントだけを抽出します。

```bash
gh api \
  --paginate \
  "repos/${REPO}/pulls/${PR_NUMBER}/comments" \
  --jq '. as $comments
    | map(select(.in_reply_to_id == null))
    | .[] as $parent
    | {
        id: $parent.id,
        body: $parent.body,
        reply_count: ($comments | map(select(.in_reply_to_id == $parent.id)) | length)
      }'
```

`in_reply_to_id == null` はトップレベルコメント抽出に有効ですが、
それだけでは「未対応かどうか」は判定できません。
`reply_count` や会話内容を確認し、既に対応済みでないかを判断します。

### 2. コメントを分類して対応方針を決める

各コメントを以下のどちらかに分類します。

- **対応する**: バグ、仕様逸脱、可読性低下など妥当な指摘
- **対応しない**: 要件外、誤解、既存制約により対応不能

> 対応しない場合も、理由を返信して会話を閉じる。

### 3. 妥当な指摘を修正してテスト

指摘ごとに修正を行い、関連テストや静的チェックを実行します。

```bash
# 例: 変更確認

git diff

# 例: プロジェクトに応じたテスト
npm test
```

### 4. コミットを作成

Conventional Commitsでコミットします。

```bash
git add <files>
git commit -m "fix: <scope> のレビューコメントに対応"
```

対応コミットSHAを取得します。

```bash
COMMIT_SHA=$(git rev-parse --short HEAD)
echo "$COMMIT_SHA"
```

### 5. 各レビューコメントに返信

`/pulls/{pull_number}/comments/{comment_id}/replies` エンドポイントで返信します。

```bash
COMMENT_ID="456789"

# 対応した場合

gh api \
  --method POST \
  "repos/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_ID}/replies" \
  -f body="対応しました。Fixed in ${COMMIT_SHA}"

# 対応しない場合（例）

gh api \
  --method POST \
  "repos/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_ID}/replies" \
  -f body="確認しました。今回は要件範囲外のため対応を見送ります。"
```

> `git rebase` や `git push --force-with-lease` を行った場合、
> 返信済みコメント中のコミットSHAが古くなることがあります。
> その場合は最新SHAを添えて追記返信し、レビュアーに参照先更新を伝えます。

## 返信テンプレート

### 対応した場合

```markdown
対応しました。Fixed in <commit-sha>
```

### 追加説明が必要な場合

```markdown
対応しました。<対応内容を1-2文で説明>。
Fixed in <commit-sha>
```

### 対応しない場合

```markdown
確認しました。<対応しない理由>のため今回は見送ります。
必要であれば別Issueで対応します。
```

## 複数コメントを1コミットで対応する場合

1つのコミットで複数コメントを解消した場合でも、
**各コメントに個別返信**して同じコミットSHAを明記します。

## 実行例

```bash
REPO="yellow-seed/yellow-seed"
PR_NUMBER="42"
COMMIT_SHA=$(git rev-parse --short HEAD)

# コメントID 1001, 1002 に返信
for COMMENT_ID in 1001 1002; do
  gh api --method POST \
    "repos/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_ID}/replies" \
    -f body="対応しました。Fixed in ${COMMIT_SHA}"
done
```

## 他スキルとの連携

- `code-review`: レビュー観点を再確認する
- `self-review`: 修正後の差分を自己点検する
- `git-commit`: コミット粒度を適切に保つ
- `commit-message`: Conventional Commitsに沿って記述する
- `pull-request`: PR本文の更新や最終チェックを行う
