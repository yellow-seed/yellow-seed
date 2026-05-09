---
name: bash-style-guide
description: "Bashスクリプトのコーディング規約スキル。安全で読みやすく保守しやすいBashを書くための実践ルール集。Use when: Bashスクリプトの新規作成、既存Bashの修正、コードレビュー時。"
---

# Bash Style Guide

Bashスクリプト作成時に守るべき規約をまとめたガイド。

## 1. スクリプトの基本構造

### ルール

- 先頭に shebang を記述する
- `set -euo pipefail` を有効化する

### NG

```bash
#!/bin/bash

echo "start"
```

### OK

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "start"
```

## 2. エラーハンドリング

### ルール

- エラー終了は `exit 1` を使う（正常終了は `exit 0`）
- 一時ファイルは `mktemp` で作成する
- `trap` で一時ファイルを必ず削除する

### NG

```bash
tmp_file="/tmp/result.txt"

do_work || exit 0
```

### OK

```bash
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

if ! do_work >"$tmp_file"; then
  echo "処理に失敗しました" >&2
  exit 1
fi
```

## 3. 変数・クォート

### ルール

- 変数展開は常にダブルクォートする
- コマンド置換は `$()` を使う（バッククォート禁止）
- グローバル変数は大文字、ローカル変数は小文字で命名する

### NG

```bash
REPO_ROOT=`pwd`

print_path() {
  PATH_VALUE=$1
  echo $PATH_VALUE
}
```

### OK

```bash
REPO_ROOT="$(pwd)"

print_path() {
  local path_value="$1"
  echo "$path_value"
}
```

## 4. 関数

### ルール

- 関数名はスネークケースを使う
- 関数内の一時変数は `local` で宣言する

### NG

```bash
installTool() {
  tool="$1"
  echo "install ${tool}"
}
```

### OK

```bash
install_tool() {
  local tool="$1"
  echo "install ${tool}"
}
```

## 5. 出力・ログ

### ルール

- カラー変数名は `RED/GREEN/YELLOW/NC` に統一する
- エラーメッセージは `stderr` に出力する
- ログ関数のシグネチャを統一する（`log_info`, `log_warn`, `log_error` など）

### NG

```bash
ERROR_COLOR='\033[0;31m'
NORMAL='\033[0m'

log() {
  echo "$1"
}

log "error: failed"
```

### OK

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
  local message="$1"
  echo -e "${GREEN}[INFO]${NC} ${message}"
}

log_error() {
  local message="$1"
  echo -e "${RED}[ERROR]${NC} ${message}" >&2
}
```

## 6. パイプラインと条件分岐

### ルール

- `set -o pipefail` 前提で失敗を拾えるように書く
- 条件分岐は `[[ ]]` を使う

### NG

```bash
if [ -n $name ]; then
  echo "name is set"
fi

grep "token" config.txt | head -n 1
```

### OK

```bash
if [[ -n "${name}" ]]; then
  echo "name is set"
fi

if ! grep "token" config.txt | head -n 1 >/dev/null; then
  echo "token が見つかりません" >&2
  exit 1
fi
```

## 7. 参考資料

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- `scripts/installers/_common.sh` の既存実装パターン
