# template-sync: 共通参照

[SKILL.md](../SKILL.md) の Pull / Push どちらでも使う前提・パターン・付帯情報。

## 共通原則

1. **非破壊**: 派生の既存カスタムを前提にし、上書きで消さない
2. **選択的**: 取り込む変更は必要なものだけに絞る
3. **カスタム維持**: アプリ固有の設定・ワークフローは尊重する
4. **説明可能**: 何を・なぜ・どこから来たかをコミット／Issue／PR で残す
5. **事前確認**: 広い差分はブランチ・PR・Issue でレビューしてから適用
6. **パターン志向**: 単一パス列挙に頼らず、ディレクトリの役割で判断する

## 対象パターンと同期のしかた

| 区分 | パス・例 | 同期のしかた |
|------|-----------|----------------|
| GitHub | `.github/**/*` | 新規は追加しやすい。既存ワークフローは**構造**（トリガー・ジョブ分割・依存）はテンプレに寄せ、**コマンド**はスタックに合わせて維持または個別調整 |
| AI エージェント設定 | `.agents/**`, `.claude/**`, `.Codex/**`, `.codex/**`, `.cursor/**`, `.aider/**`, `.codeium/**`, `.copilot/**` など、`skills/`・`hooks/` を含むドット配下 | `skills/` は追加・更新確認。`hooks/` は差分確認。シンボリックリンク不可環境は `skills-setup` 系の既存方針に従う |
| ツール・CI 設定 | `.editorconfig`, `.prettierrc*`, `.eslintrc*`, `.codecov.yml`, `.renovate.json`, `.dependabot/**`, `.mise.sidecar.toml`, `compose.yml`, `Dockerfile` など | 新規は追加。既存は差分を見てテンプレ基準値とのすり合わせやマージ。`tool-sidecar` など品質補助環境は、派生先でも有効なら導入候補にする |
| スクリプト | `scripts/**/*`, `.agents/skills/*/references/*.sh` | 新規追加、既存は差分レビュー。汎用基盤は `scripts/`、skill 専用実装は所有 skill の `references/` に置く |
| Git メタ | `.gitignore`, `.gitattributes`, `.gitmodules` | 行・ブロック単位でマージし、重複を避けて足す |
| フック | `.githooks/**/*` | テンプレと共通のフックを足す／更新。プロジェクト専用フックは残す |
| ドキュメント | `README.md`, `AGENTS.md`, `CONTRIBUTING.md` | **README**: バッジ用コメントブロックなど決めた区間のみ置換。**AGENTS.md**: 見出し構造をテンプレのお手本に寄せ、中身はプロジェクトに合わせて保持 |

**同期しない（原則）**: アプリマニフェストやランタイム中心のファイル（例: `package.json` の依存そのもの、`Cargo.toml` のクレート選定）は対象外。テンプレが担う**周辺ツール・運用**に限定する。

### sidecar 同期の原則

`tool-sidecar` / `.mise.sidecar.toml` / qlty / pinact / dockerfile-pin は、template で品質補助の標準を担う設定です。派生リポジトリへ pull しても有効なものは導入候補にします。

ただし、template 固有の検証対象・リポジトリ名・実行コマンドは派生スタックに合わせて調整します。sidecar という名前や設定を盲目的にコピーするのではなく、アプリケーション本体から独立した品質補助環境として価値があるかで判断します。

## 同期タイプ早見

| タイプ | 例 | 動き |
|--------|-----|------|
| 完全同期 | 新規 `.github/workflows/*.yml`、新規 Issue テンプレ | テンプレからそのまま追加 |
| 構造同期 | 既存ワークフローの `on:` / ジョブ分割 | パターンはテンプレ、実行コマンドはプロジェクト次第 |
| マージ同期 | `.gitignore` | 既存を残しつつ不足分を追加 |
| 値同期 | `.codecov.yml`, `.renovate.json` | 組織基準に数値・ポリシーを揃える（例外は明示） |
| 選択的同期 | README のバッジコメントブロック | 区間だけ差し替え |
| 差分同期 | `scripts/`, `.agents/skills/*/references/`, `.githooks/` | 差分をレビューしてから適用 |

## 事前に読むリポジトリの様子（Pull / Push 共通）

```bash
ls package.json pyproject.toml Cargo.toml go.mod Gemfile 2>/dev/null
ls -la .github .agents .claude .codex .Codex .cursor scripts .githooks 2>/dev/null
ls -la Dockerfile compose.yml .mise.sidecar.toml 2>/dev/null
```

## トラブルシューティング

| 状況 | 対処 |
|------|------|
| テンプレに fetch できない | SSH／HTTPS の切り替え、`git ls-remote` で認証確認 |
| 差分が大きすぎる | ディレクトリやテーマごとに PR を分割 |
| マージが難しい | 構造だけ先に揃え中身は手動調整。Push 型は Issue に差分を整理してからテンプレ側で取り込み |

## 他のスキルとの連携

- **commit-message**: 同期は `chore:` / `docs:` / `ci:` など。テンプレ由来は本文で明示
- **pull-request**: 派生側の大量変更の取り込みは PR。テンプレへ還流する Push パターンの**入口は `yellow-seed/template` の Issue**
- **github-issue**: Push 型の主経路。**github-issue** スキルに沿って Issue を作成し、[push.md](push.md) のテンプレートを埋める

## 既定のテンプレ情報

- **リポジトリ**: `yellow-seed/template`
- **ブランチ**: `main`
- **URL**: `https://github.com/yellow-seed/template.git`

別テンプレートを参照するとき:

```bash
export TEMPLATE_REPO="https://github.com/your-org/your-template.git"
```
