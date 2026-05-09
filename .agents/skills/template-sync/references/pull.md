# template-sync: Pull 型（テンプレート → 派生）

[SKILL.md](../SKILL.md) · 前提・パターン表は [shared.md](shared.md)。

派生リポのルートで、テンプレをリモートとして一時参照し差分を取り、選択的に取り込む。

## 差分取得

```bash
TEMPLATE_REPO="${TEMPLATE_REPO:-https://github.com/yellow-seed/template.git}"
if git remote get-url template >/dev/null 2>&1; then
  current_template_repo=$(git remote get-url template)
  if [ "$current_template_repo" != "$TEMPLATE_REPO" ]; then
    echo "template remote points to $current_template_repo; updating to $TEMPLATE_REPO"
    git remote set-url template "$TEMPLATE_REPO"
  fi
else
  git remote add template "$TEMPLATE_REPO"
fi
git fetch template main

git diff HEAD template/main --name-only
git diff HEAD template/main -- .github/
git diff HEAD template/main -- .agents/ .claude/ .codex/ .cursor/ .Codex/ 2>/dev/null
git diff HEAD template/main -- scripts/ .githooks/
git diff HEAD template/main -- Dockerfile compose.yml .mise.sidecar.toml
git diff HEAD template/main -- README.md AGENTS.md

# 単ファイル取得の例
git show template/main:.github/workflows/example.yml
```

## 手順の流れ

1. `TEMPLATE_REPO` の `main` を fetch（対象 SHA を記録するとよい）
2. [shared.md](shared.md) の観点で言語・CI・カスタムを把握し、盲目適用しない
3. パス差分と内容差分を分けて見る
4. 「新規で足す」「既存マージ」「スタック都合でスキップ」を仕分け
5. `git show` / `git checkout template/main -- path` / 手動マージで適用
6. 動作確認・`chore:` 等でコミット（本文に `template@<短いSHA>` が望ましい）
7. `git remote remove template` で一時リモートを片付ける

## 運用上のメモ

- **GitHub Actions**: テンプレは `paths-ignore`・`branches`・ジョブ分割など**運用パターン**のお手本。`npm test` / `pytest` など**実行コマンド**は派生スタック優先。
- **sidecar**: `tool-sidecar` / `.mise.sidecar.toml` / qlty / pinact / dockerfile-pin は、派生先でも有効な品質補助なら導入候補。template 固有の検証対象や実行コマンドは派生スタックに合わせる。
- **README バッジ**: テンプレで決めたコメント区間（例: `<!-- CI/CD ... -->`）だけ同期し、リポジトリ名は派生のオーナー／名前に置換。

## Pull チェックリスト

- [ ] `template/main`（または対象 SHA）を取得した
- [ ] 適用範囲を選び、スタックに合わない変更を除外した
- [ ] コミット／PR にテンプレ側の参照（SHA など）を残した
- [ ] CI またはローカルで最低限の確認をした
