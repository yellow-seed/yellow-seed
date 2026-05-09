---
name: dotenvx-env
description: "dotenvxで環境変数を環境別に暗号化して作成・追加・更新し、local / remote / prd の鍵と値の境界を確認する運用スキル。Use when: dotenvxを新規導入する、既存の.env.local/.env.remote/.env.productionへ環境変数を追加する、値を変更・ローテーションする、AIエージェントへ渡す復号鍵を確認する時。"
---

# dotenvx 環境変数運用

このスキルは、dotenvx で環境変数を暗号化管理するときに使う。対象は API key、token、接続文字列などの secret 全般。

最重要ルール:

- secret の実値をチャット、Issue、ログへ貼らない。ユーザーのローカルシェル入力に任せる
- まず「新規導入」か「既存 dotenvx への追加・変更」かを判定する
- 次に対象環境が `local` / `remote` / `prd` のどれかを判定する
- 対象環境ごとに `.env.<env>` と復号鍵を分離し、別環境の値や鍵を混ぜない
- PC(local) / PRD 用の `DOTENV_PRIVATE_KEY*` を AI エージェントへ注入しない
- Remote は AI の Web 実行環境向けの専用環境として扱い、AI に使わせてよい最小限の環境変数だけを置く
- `.env`, `.env.keys`, `.env.*.keys`, `secrets/` は Git 管理しない
- 暗号化済み `.env.local`, `.env.remote`, `.env.production` と `.env.sample` は方針に応じて Git 管理してよい

詳細なチェックリストが必要な場合は [references/checklists.md](references/checklists.md) を読む。

## 判断順序

1. 既存確認
   - dotenvx 管理が未導入なら「新規導入」
   - `.env.<env>` と対応する鍵が既にあるなら「既存への追加・変更」
2. 対象環境確認
   - `local`: 人間のPC上で使う値
   - `remote`: Codex on the web / Codex on the web など、AI の Web 実行環境で使わせる値
   - `prd`: 本番で使う値
3. 変数の扱い確認
   - AI に見えてよい値か
   - 本番専用か
   - ローテーションか新規追加か
   - `.env.sample` に変数名だけ追記すべきか

## 基本ファイル構成

```text
.env                    # 作業用。Git 管理しない
.env.sample             # 変数名だけ。Git 管理する
.env.local              # local 用。暗号化済み。Git 管理可
.env.remote             # Remote AI 用。暗号化済み。Git 管理可
.env.production         # prd 用。暗号化済み。必要な場合のみ Git 管理可
secrets/
  .env.local.keys       # local 用復号鍵。Git 管理しない
  .env.remote.keys      # Remote AI 用復号鍵。Git 管理しない
  .env.production.keys  # prd 用復号鍵。通常リポジトリに置かず secret manager へ
```

`.gitignore` に最低限以下が含まれることを確認し、なければ追加する。

```gitignore
.env
.env.keys
.env.*.keys
secrets/
```

## 新規に dotenvx を入れる

新しい環境ファイルを作る場合は、ユーザーに対象環境と変数名を確認してから進める。実値はユーザーがターミナルで直接書き換えて実行する。

値をインラインで渡す1コマンド形式にすることで、書き換え箇所を最小限にする。
履歴に残したくない場合は先頭にスペースを付けること（zsh の `HIST_IGNORE_SPACE` が有効な場合）。

local 例（`値` の部分だけ書き換えて実行）:

```bash
 dotenvx set VARIABLE_NAME '値' -f .env.local
```
```bash
mkdir -p secrets && mv .env.keys secrets/.env.local.keys && chmod 600 secrets/.env.local.keys
```

remote 例（`値` の部分だけ書き換えて実行）:

```bash
 dotenvx set VARIABLE_NAME '値' -f .env.remote
```
```bash
mkdir -p secrets && mv .env.keys secrets/.env.remote.keys && chmod 600 secrets/.env.remote.keys
```

prd 例（`値` の部分だけ書き換えて実行）:

```bash
 dotenvx set VARIABLE_NAME '値' -f .env.production
```

prd の復号鍵は原則としてリポジトリ配下へ置かず、本番の secret manager に保存する。検証用に一時生成された `.env.keys` がある場合も commit しない。

`.env.sample` には値を入れず、変数名だけを追記する。

```dotenv
VARIABLE_NAME=
```

## 既存 dotenvx に変数を追加・変更する

既存の `.env.<env>` を更新する場合は、その環境専用の復号鍵を人間のローカルシェルで読み込んでから `dotenvx set` する。

local 例（`値` の部分だけ書き換えて実行）:

```bash
set -a; . secrets/.env.local.keys; set +a
```
```bash
 dotenvx set VARIABLE_NAME '値' -f .env.local
```

remote 例（`値` の部分だけ書き換えて実行）:

```bash
set -a; . secrets/.env.remote.keys; set +a
```
```bash
 dotenvx set VARIABLE_NAME '値' -f .env.remote
```

prd は、ローカルファイルの鍵ではなく本番 secret manager の運用に従う。AI に prd 用復号鍵を渡さない。

更新後に見る差分は暗号化済みファイルと `.env.sample` だけにする。

```bash
git diff -- .env.local .env.remote .env.production .env.sample
git status --short
```

## Remote AI 環境の扱い

`remote` は、人間のローカルや本番ではなく、Codex on the web / Codex on the web などの AI Web 実行環境向けの専用環境。

Remote 用 `.env.remote` には、AI に使わせてよい値だけを入れる。local / prd の secret を流用しない。Remote 側の secret / environment variable には、値の実体ではなく `.env.remote` 用の `DOTENV_PRIVATE_KEY*` だけを登録する。

Remote 起動時に `.env.remote` から Git 管理されない `.env` を生成する場合は、必要な変数だけを書き出す。例:

```bash
dotenvx run -f .env.remote -- sh -c 'umask 077; printf "VARIABLE_NAME=%s\n" "$VARIABLE_NAME" > .env'
```

複数の値を書き出す場合も、AI 用に許可した変数だけを明示的に列挙する。`.env.remote` 全体を無条件にコピーしない。

## 検証

実値を表示しない範囲で確認する。

```bash
git check-ignore .env
git check-ignore .env.keys
git check-ignore secrets/.env.local.keys
git check-ignore secrets/.env.remote.keys
git status --short
```

Remote AI 環境では、PC(local) / PRD 用の鍵がないことと、必要な作業用 `.env` があることを確認する。

```bash
env | cut -d= -f1 | grep '^DOTENV_PRIVATE_KEY' || true
test -s .env
```

変数の存在確認は値を表示しない形で行う。

```bash
grep -q '^VARIABLE_NAME=' .env
```

## 返答方針

ユーザーへは、対象環境、作業パターン、新規作成か更新か、次に人間が実行するコマンドを短く示す。secret の実値や復号鍵の値は貼らせない。

Remote AI の環境方針に関係する変更をした場合は、AGENTS.md にも方針が書かれているか確認する。
