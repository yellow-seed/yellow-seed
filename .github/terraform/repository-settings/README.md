# Repository settings Terraform

`github_repository` リソースで、リポジトリの基本設定を管理します。
既存リポジトリへ適用する場合は、必ず import してから plan / apply してください。

## 管理対象

- `description = "Template for AI era Develop"`
- `visibility = "public"`
- `is_template = true`
- `has_issues = true`
- `has_projects = true`
- `has_wiki = true`
- `has_downloads = true`
- `has_discussions = false`
- `allow_merge_commit = true`
- `allow_squash_merge = true`
- `allow_rebase_merge = true`
- `allow_auto_merge = false`
- `delete_branch_on_merge = true`
- `allow_update_branch = false`
- squash / merge commit message 設定
- `web_commit_signoff_required = false`
- `security_and_analysis` の secret scanning 設定
- `github_repository_vulnerability_alerts` による Dependabot alerts 設定

Dependabot security updates、secret scanning の追加オプション、Actions 権限、
Environment、Actions secrets の存在確認は `.github/scripts/setup-repository-settings.sh`
で管理します。

`has_downloads` は GitHub provider で deprecated warning が出ることがあります。
ただし、import 後に既存リポジトリ設定の意図しない差分を抑えるため、現状維持が必要な明示属性として残しています。

## 前提

- リポジトリ管理者権限を持つ GitHub token
  - classic PAT の場合は `repo`
  - fine-grained PAT の場合は対象リポジトリの `Administration: Read and write`
- Docker / Docker Compose
- AGENTS.md の方針に従い、検証・適用は原則 `tool-sidecar` 経由で実行する

## 必須環境変数

| 変数                     | 用途                                       |
| ------------------------ | ------------------------------------------ |
| `TF_VAR_github_owner`    | GitHub owner / organization                |
| `TF_VAR_repository_name` | 対象リポジトリ名。暗黙デフォルトは持たない |
| `TF_VAR_github_token`    | リポジトリ管理者権限を持つ GitHub token    |

このテンプレートリポジトリへ適用する場合も、対象を明示してください。

```bash
export TF_VAR_github_owner="yellow-seed"
export TF_VAR_repository_name="template"
export TF_VAR_github_token="$(gh auth token)"
```

token を dotenvx で管理する場合は、AGENTS.md と `.agents/skills/dotenvx-env/SKILL.md` の環境分離方針に従ってください。
token の実値をログ、コミット、PR本文へ出さないでください。

## 適用: ヘルパー利用

```bash
docker compose up -d tool-sidecar
```

まず dry-run で `init -> import -> plan` まで実行します。

```bash
export DRY_RUN=1

docker compose exec \
  -e TF_VAR_github_owner \
  -e TF_VAR_repository_name \
  -e TF_VAR_github_token \
  -e DRY_RUN \
  tool-sidecar \
  bash .github/scripts/apply-repository-settings.sh
```

plan が意図どおりであることを確認してから apply します。

```bash
unset DRY_RUN

docker compose exec \
  -e TF_VAR_github_owner \
  -e TF_VAR_repository_name \
  -e TF_VAR_github_token \
  tool-sidecar \
  bash .github/scripts/apply-repository-settings.sh

docker compose down
```

ヘルパーは Terraform state に `github_repository.template` が無い場合だけ import します。
import 済み state の repository 名と `TF_VAR_repository_name` が一致しない場合は、誤ったリポジトリへの適用を避けるため中断します。

## 適用: 手動実行

ヘルパーを使わない場合も、対象リポジトリ名を必ず明示します。

```bash
cd .github/terraform/repository-settings
terraform init -input=false
terraform import -input=false github_repository.template "${TF_VAR_repository_name}"
terraform plan -input=false
terraform apply -input=false
```

No changes へ収束したことを確認する場合:

```bash
terraform plan -input=false -detailed-exitcode
```

`plan -detailed-exitcode` の終了コードは、0 が No changes、2 が差分あり、1 がエラーです。

## 検証

Terraform 定義の静的検証:

```bash
docker compose up -d tool-sidecar
docker compose exec tool-sidecar bash -c 'cd .github/terraform/repository-settings && terraform fmt -check -recursive'
docker compose exec tool-sidecar bash -c 'cd .github/terraform/repository-settings && terraform init -backend=false && terraform validate'
```

適用後の収束確認:

```bash
docker compose exec \
  -e TF_VAR_github_owner \
  -e TF_VAR_repository_name \
  -e TF_VAR_github_token \
  tool-sidecar \
  bash -c 'cd .github/terraform/repository-settings && terraform plan -input=false -detailed-exitcode'
```

## 補足

- `.github/scripts/setup-repository-settings.sh` は、GitHub UI で確認した実設定を
  GitHub API 経由で再適用するためのスクリプトです。
- Actions secrets の値はリポジトリへ保存しません。スクリプトは必要な secret 名の
  存在だけを確認します。
- Ruleset は `.github/rulesets/` と `.github/scripts/setup-rulesets.sh` で管理します。
  テンプレートから派生したリポジトリで main ブランチ直 push などの運用例外がある場合は、
  テンプレートの Ruleset JSON をそのまま適用せず、派生側の方針を先に整理してください。
