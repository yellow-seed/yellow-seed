---
name: sync-codex
description: "Codex環境セットアップスキル。Codex向けのセットアップスクリプト整備とDockerfile相当のインストール手順の移植。Use when: Codex向けのセットアップスクリプトを整えてほしい、Dockerfileの手順をシェル化してほしいと依頼された時。"
---

# Codex環境セットアップ同期

Codex環境向けのセットアップスクリプトを整備し、Dockerfileの手順をシェルスクリプトで再現する。

## Codex環境の特徴と制約

- コンテナ内で動作するため Docker コマンドは使用しない
- Dockerfileの `RUN`/`ENV` 相当の手順をシェルスクリプトへ移植する

## セットアップ手順

1. **GitHub CLIのセットアップを案内する**

   - `.codex/hooks/gh-setup.sh` を実行する
   - 例: `bash .codex/hooks/gh-setup.sh`

2. **Codex向け開発環境のセットアップを案内する**

   - `.codex/hooks/env-setup.sh` を実行する
   - 例: `bash .codex/hooks/env-setup.sh`

3. **スキルディレクトリの同期を案内する**
   - `.Codex/hooks/skills-setup.sh` を実行する
   - 例: `bash .Codex/hooks/skills-setup.sh`

## Dockerfile手順の移植ガイド

### 1. Dockerfileから対象手順を抽出する

- `RUN` のインストール手順を列挙する
- `ENV` の環境変数を列挙する
- 例: `apt-get install`, `wget`/`curl`, `go install`, `npm install -g`

### 2. env-setup.sh に移植する

- 既存の `env-setup.sh` に**追記**または**関数化**して追加する
- 冪等性を維持するため、インストール済みチェックを入れる
- 例: `command -v shellcheck >/dev/null 2>&1 || apt-get install -y shellcheck`

### 3. ログとバージョン確認を追加する

- 各ツールのインストール完了後に `--version` を表示する
- 失敗時は明確なメッセージを出力する

### 4. Dockerfileとの差分管理

- Dockerfile更新時は、同様の変更を `env-setup.sh` に反映する
- 手順の差分がある場合、理由と影響をコメントで残す

## 冪等性・エラーハンドリングの指針

- `set -euo pipefail` を使用して早期失敗させる
- 既存インストールの検出とスキップを行う
- ネットワーク取得に失敗した場合の再実行性を考慮する

## プロジェクト固有のカスタマイズ

- `env-setup.sh` にプロジェクト固有のツールを追加する
- 言語/フレームワーク固有の設定を環境変数で制御する
- インストール対象は必ずコメントで理由を記載する

## トラブルシューティング

- **コマンドが見つからない**: `PATH` を確認し、`export` で追加する
- **権限エラー**: `sudo` の必要性を確認（利用可能な場合のみ）
- **依存関係の衝突**: 先に不要なパッケージを削除してから再実行する

## ベストプラクティス

- スクリプトは短い関数に分割し、再利用性を高める
- ログは「何をしているか」が分かる粒度で出力する
- Dockerfile更新時は `env-setup.sh` を必ず見直す
