# AI Agents Documentation

このドキュメントは、AIエージェントがこのプロジェクトを理解し、適切に支援するための情報を提供します。

## プロジェクト概要

<!-- プロジェクトの概要を記述してください -->

## 技術スタック

<!-- 使用している技術スタックを記述してください -->
<!-- 例: Ruby on Rails, Python, Node.js, Go など -->

## ディレクトリ構造

<!-- プロジェクトのディレクトリ構造を説明してください -->

```bash
project/
├── src/
├── tests/
├── docs/
└── ...
```

## 開発環境のセットアップ

### スキルディレクトリのセットアップ（Windows環境など）

このリポジトリでは、`.claude/skills` は `.agents/skills` へのシンボリックリンクとして構成されています。

**シンボリックリンクが機能しない環境**（Windows管理者権限なし、`core.symlinks=false`など）では、以下のスクリプトを実行してください：

```bash
bash .claude/hooks/skills-setup.sh
```

このスクリプトは`.agents/skills`を`.claude/skills`にコピーします。

**注意事項**:

- シンボリックリンク環境では、すべてのディレクトリは自動的に同期されます
- コピー環境では、`.agents/skills`を変更した場合、再度`skills-setup.sh`を実行して同期する必要があります
- 新しいスキルを追加する際は、必ず`.agents/skills/`に配置してください

### dotenvx による環境変数管理

dotenvx で secret を扱う場合は、local / remote / prd の環境を分けて管理します。

- `local`: 人間のPC上で使う環境変数。復号鍵はAIエージェントへ渡さない
- `remote`: Claude Code on the web / Codex on the web など、AIのWeb実行環境専用の環境変数。AIに使わせてよい最小限の値だけを置く
- `prd`: 本番環境の環境変数。復号鍵や値をAIエージェントへ渡さない

Remote 用 `.env.remote` は local / prd の代替ではなく、AI作業用に分離した専用ファイルです。
Web 側 secret / environment variable には、値の実体ではなく `.env.remote` 用の `DOTENV_PRIVATE_KEY*` だけを登録します。
Remote 環境変数の参照は常に `dotenvx` 経由で行い、復号結果を `.bashrc` や永続ファイルへ書き出さないでください。
例外として、Codex Web の SessionStart では `gh` を後続プロセスから素のコマンドで使えるよう、`.codex/hooks/setup-remote-env.sh` が復号済み `GH_TOKEN` だけを `~/.bashrc` の管理ブロックへ冪等に書き出します。この例外は remote 環境専用であり、local / prd の値や鍵を永続化する用途には使いません。
Claude Code の SessionStart では `.claude/hooks/setup-remote-env.sh` が stdout に env JSON を出力して `GH_TOKEN` を渡します。ログは stderr に出し、stdout は Claude Code が解釈する JSON だけに保ちます。
`scripts/env-setup.sh` はローカル開発環境向けのセットアップスクリプトであり、`.env.remote` を復号して `.env` を生成します。このスクリプトは Remote AI 環境（Codex/Claude Web）では使用しません。
`setup-remote-env.sh` は `DOTENV_PRIVATE_KEY*` が未設定の場合、セットアップフローを妨げないようスキップして正常終了します（exit 0）。鍵が設定済みで復号に失敗した場合のみ異常終了します（exit 1）。
dotenvx の新規導入、環境変数の追加、値の変更、ローテーションを行う場合は [.claude/skills/dotenvx-env/SKILL.md](.claude/skills/dotenvx-env/SKILL.md) を参照してください。

### Codex Web セットアップ確認

Codex Cloud environment settings の setup script には、remote 環境に必要な処理だけを明示的に登録します。

```bash
bash .codex/hooks/bootstrap-dotenvx.sh
bash .codex/hooks/bootstrap-gh.sh
bash .codex/hooks/setup-remote-env.sh
bash .codex/hooks/gh-setup.sh
```

`gh-setup.sh` は、先に用意された `gh` と `GH_TOKEN`、認証済みの `gh`、または `.env.remote` を dotenvx で復号して実行できる `gh` を使い GitHub CLI extensions などを設定します。

### mise 環境の分割

`.mise.toml` は共通最小ツール（`node` / `openspec` / `prettier`）だけを定義します。
重いツールや用途限定ツールは `.mise.<env>.toml` に分割します。

| 環境          | ファイル                 | 用途                                  |
| ------------- | ------------------------ | ------------------------------------- |
| `remote`      | `.mise.remote.toml`      | Codex Web などの軽量 Remote 環境      |
| `ci`          | `.mise.ci.toml`          | GitHub Actions のジョブ別選択 install |
| `sidecar`     | `.mise.sidecar.toml`     | Docker の `tool-sidecar`              |
| `workstation` | `.mise.workstation.toml` | ローカル開発PCのフルセット            |

Remote 向けに mise を使う場合は、必ず軽量 profile を明示します。

```bash
MISE_ENV=remote mise install
```

CI では必要なツールだけを選択 install します。

```bash
MISE_ENV=ci bash scripts/install-tools.sh bats
```

ローカル開発PCで `bash scripts/install-tools.sh` を実行した場合は、既定で `MISE_ENV=workstation` を使います。

### ブランチ管理（Worktree / 通常ブランチ）

ブランチの作成・切り替え・削除は [.agents/skills/git-branch-worktree/SKILL.md](.agents/skills/git-branch-worktree/SKILL.md) に集約している。
`*_REMOTE` 環境変数の有無に応じて、worktree（ローカルPC）または通常ブランチ（Web環境）を自動選択する。

### リポジトリの棚卸し

ローカルブランチ・worktree・リモートブランチ・Issue の不要リソースを棚卸し・クリーンアップする場合は [.agents/skills/git-cleanup-audit/SKILL.md](.agents/skills/git-cleanup-audit/SKILL.md) を参照する。
この用途専用のスクリプトと bats は、所有者が分かるよう [.agents/skills/git-cleanup-audit/references/](.agents/skills/git-cleanup-audit/references/) に配置している。

```bash
# ローカルブランチ
bash .agents/skills/git-cleanup-audit/references/cleanup-local-branches.sh --dry-run

# Worktree
bash .agents/skills/git-cleanup-audit/references/cleanup-worktrees.sh --dry-run

# リモートブランチ
bash .agents/skills/git-cleanup-audit/references/cleanup-remote-branches.sh --dry-run

# Issue 棚卸し
bash .agents/skills/git-cleanup-audit/references/audit-issues.sh --dry-run
```

## 変更管理ワークフロー（OpenSpec）

このプロジェクトでは、AIエージェントへの**すべての実装依頼に OpenSpec ワークフローを使用します**。実装を始める前に必ず change を作成し、proposal.md と tasks.md を用意してください。

### 基本フロー

1. **提案** (`/opsx:propose`): `proposal.md`（なぜやるか＋Ref）と `tasks.md`（実装TODO）を生成
2. **実装** (`/opsx:apply`): `tasks.md` のタスクを順に実装・チェックオフ
3. **アーカイブ** (`/opsx:archive`): 完了した変更をアーカイブ（月次 GitHub Actions でも自動実行）

### スキーマの使い分け

| スキーマ              | 用途                             | コマンド                                            |
| --------------------- | -------------------------------- | --------------------------------------------------- |
| `rapid`（デフォルト） | 小〜中規模の変更                 | `openspec new change "<name>"`                      |
| `spec-driven`         | 仕様書・設計書が必要な大規模変更 | `openspec new change --schema spec-driven "<name>"` |

詳細は [docs/OPENSPEC.md](docs/OPENSPEC.md) を参照してください。

## コーディング規約

<!-- プロジェクトで使用しているコーディング規約を記述してください -->

## コミットメッセージ規約

コミットメッセージは Conventional Commits を基本にしつつ、
Contextual Commits の考え方で「なぜその判断をしたか」を残します。
詳細な書式・例・Co-Authored 運用は
[.agents/skills/commit-message/SKILL.md](.agents/skills/commit-message/SKILL.md) を参照してください。

## コミット粒度

適切なコミット粒度を保つことで、レビューが容易になり、問題発生時の原因特定や安全なrevertが可能になります。

### 基本原則

- **機能の意味のある単位でコミット**: 実装とそれが通るテストコードなど、機能的に独立した単位でコミットする
- **Pull Requestのすべての変更を一つのコミットにまとめない**: 複数の異なる目的の変更は別々のコミットに分割する

### 詳細なガイドライン

コミット分割の判断基準や実践例については、[.claude/skills/git-commit/SKILL.md](.claude/skills/git-commit/SKILL.md) を参照してください。

## テスト戦略

### CI 必要検証

CI は、リポジトリ内スクリプトや将来のアプリケーションコードの動作を確認する `ci` と、アプリケーションそのものを動かさず品質補助ツールを実行する `sidecar` の2つの文脈で整理します。
`.github/workflows/ci.yml` はアプリケーションコードやリポジトリ内スクリプトの動作検証、`.github/workflows/sidecar-ci.yml` は qlty / actionlint / pinact / dockerfile-pin などの品質補助検証を担います。
GitHub Actions の workflow ファイルは `.github/workflows` 直下に置き、肥大化する処理は `scripts/`、skill の `references/`、composite actions、reusable workflows へ逃がします。
CI で必要な補助ツールは `tool-sidecar` コンテナに揃えています。
このコンテナはアプリケーションそのものを動かすためではなく、`bats` / `qlty` など、アプリケーションの実行状態に左右されない検証・整形・補助ツールを実行するための sidecar です。
ローカル環境に必要なツールが無い場合でも、「確認できない」とせず、原則として次の Docker Compose 経由で検証します。

まず sidecar を起動し、以降は `docker compose exec` で同じコンテナを使い回します。
作業が終わったら `docker compose down` で片付けます。

```bash
docker compose up -d tool-sidecar
docker compose exec tool-sidecar scripts/run-checks.sh
docker compose exec tool-sidecar bats tests/*.bats
docker compose exec tool-sidecar bats .agents/skills/*/references/*.bats
docker compose down
```

### ドキュメント/設定ファイルのフォーマット

- qltyでMarkdown/YAML/JSONをフォーマットします
- ローカル実行:
  - `qlty check --all` (チェック)
  - `qlty fmt --all` (自動フォーマット)
- Docker実行:
  - `docker compose up -d tool-sidecar`
  - `docker compose exec tool-sidecar qlty check --all`
  - `docker compose down`

## Pull Request 作成

このプロジェクトでは、`.github/PULL_REQUEST_TEMPLATE.md`のテンプレート形式に準拠した高品質なPull Requestを作成します。

詳細なガイドラインは [.claude/skills/pull-request/SKILL.md](.claude/skills/pull-request/SKILL.md) を参照してください。

## デプロイメント

<!-- デプロイメントの手順を記述してください -->

## その他の重要な情報

<!-- AIエージェントが知っておくべきその他の情報を記述してください -->
