# dotenvx 環境変数チェックリスト

## 環境分類

| 環境 | 用途 | 暗号化ファイル | 復号鍵 | AI への露出 |
| --- | --- | --- | --- | --- |
| local | 人間のPC上で手動操作や検証に使う | `.env.local` | `secrets/.env.local.keys` | 渡さない |
| remote | AI の Web 実行環境に使わせる | `.env.remote` | Web 側 secret に登録 | AI 用の最小限だけ |
| prd | 本番環境で使う | `.env.production` など | secret manager | 渡さない |

## 新規導入チェック

- 対象環境が `local` / `remote` / `prd` のどれか明確
- `.gitignore` が `.env`, `.env.keys`, `.env.*.keys`, `secrets/` を除外している
- `.env.sample` に変数名だけを追加している
- `read -rsp` などで secret 実値を人間のローカルシェルから入力している
- `dotenvx set -f .env.<env> "$VAR_NAME" "$SECRET_VALUE"` を人間のローカルシェルで実行している
- 生成された `.env.keys` を対象環境に応じた保管先へ移している
- secret 実値、復号鍵、作業用 `.env` が `git ls-files` に出ない

## 既存更新チェック

- 更新対象の `.env.<env>` を間違えていない
- 対象環境専用の復号鍵だけを人間のローカルシェルで読み込んでいる
- 変数名の追加なら `.env.sample` も更新している
- 値の変更だけなら `.env.sample` に不要な差分を入れていない
- 差分確認で secret 実値を表示していない
- commit 対象が暗号化済みファイルと必要なドキュメントだけになっている

## Remote AI 専用方針

Remote は AI の Web 実行環境向けに分離した環境。`.env.remote` は local / prd の代替ではない。

Remote に入れてよい値:

- AI が作業するために必要な最小権限 token
- 対象 repository や対象サービスを絞った値
- 漏洩時の影響を限定できる有効期限・権限の値

Remote に入れない値:

- 人間の local 用 token
- prd 用 secret
- 管理者権限や secret 管理権限を持つ token
- 本番データベース接続情報

Remote 側 secret には `.env.remote` 用の `DOTENV_PRIVATE_KEY*` だけを登録する。値そのものを登録する運用に戻さない。

## 検証コマンド

```bash
git check-ignore .env
git check-ignore .env.keys
git check-ignore secrets/.env.local.keys
git check-ignore secrets/.env.remote.keys
git ls-files .env .env.keys secrets/.env.local.keys secrets/.env.remote.keys
git status --short
```

Remote では値を表示しない。

```bash
env | cut -d= -f1 | grep '^DOTENV_PRIVATE_KEY' || true
test -s .env.remote
test -s .env
grep -q '^VARIABLE_NAME=' .env
```

## ローテーション

値を差し替えるとき:

```bash
set -a
. secrets/.env.<env>.keys
set +a
VAR_NAME=VARIABLE_NAME
read -rsp "$VAR_NAME: " SECRET_VALUE; echo
dotenvx set -f .env.<env> "$VAR_NAME" "$SECRET_VALUE"
unset SECRET_VALUE
git diff -- .env.<env> .env.sample
```

通常は `.env.<env>` の暗号化値だけを commit する。復号鍵を作り直していない場合、外部 secret の再登録は不要。

鍵を作り直した場合:

- 対象環境の secret 保管先を更新する
- 古い secret を削除または上書きする
- 古い token / key をサービス側で revoke する
