---
name: github-repository-settings
description: "GitHubリポジトリ設定適用スキル。yellow-seed/template 由来の .github/terraform/repository-settings を対象リポジトリへ import / plan / apply する。Use when: GitHub のリポジトリ設定、Terraform 管理の repository settings、template 由来設定の実リポジトリ反映、delete_branch_on_merge / allow_update_branch の適用を依頼された時。"
---

# GitHub Repository Settings

yellow-seed/template 由来の GitHub リポジトリ基本設定を、対象リポジトリへ安全に反映するためのスキル。

## 目的

- `.github/terraform/repository-settings` の Terraform 定義を実リポジトリへ適用する
- 既存リポジトリは必ず `terraform import` してから `plan` / `apply` する
- テンプレートの標準設定を使いつつ、派生リポジトリ固有の運用例外を不用意に壊さない

## 事前確認

1. ブランチを作成して作業する。
   - 例: `chore/apply-repository-settings`
2. `git status --short --branch` で既存変更を確認する。
   - ユーザーの未コミット変更を戻さない
3. 対象リポジトリを確認する。
   - `git remote -v`
   - `gh repo view --json nameWithOwner,viewerPermission`
4. `gh auth status` を確認する。
   - ローカルで `gh auth token` が使えるなら、そのトークンを `TF_VAR_github_token` として使う
   - トークン値はログ、コミット、回答に出さない

## 適用方針

- ホストに Terraform が無くても、AGENTS.md の方針どおり `tool-sidecar` で実行する
- `TF_VAR_repository_name` は固定値にしない。対象リポジトリ名を必ず明示する
- 初回は `terraform import github_repository.template "${TF_VAR_repository_name}"` を実行する
- `terraform plan` に目的外の差分が出た場合は、apply せず原因を確認する
- 既存で有効な GitHub 機能 (`has_issues`, `has_projects`, `has_wiki`, `has_downloads` など) が Terraform の未指定により変わりそうなら、現状維持として明示する
- `has_downloads` は provider で deprecated warning が出ることがある。import 後の noop を優先するため、既存設定維持に必要な場合のみ明示する

## Ruleset 方針

テンプレートの Ruleset は `refs/heads/main` を保護対象に含む場合がある。

派生リポジトリで `main` への直接 push などの運用例外を意図している場合:

- `.github/rulesets/branch-protection-ruleset.json` をそのまま適用しない
- テンプレ JSON を直接書き換えず、派生リポジトリ用のコピーや override 機構を検討する
- `delete_branch_on_merge` / `allow_update_branch` の Terraform apply は main 保護とは別物として扱う
- 方針を `docs/GITHUB_RULESET_SETUP.md` や Terraform README に明記する

## 標準コマンド

`gh` のローカルトークンを使う場合:

```bash
export TF_VAR_github_owner="<owner>"
export TF_VAR_repository_name="<repo>"
export TF_VAR_github_token="$(gh auth token)"
export DRY_RUN=1

docker compose up -d tool-sidecar
docker compose exec \
  -e TF_VAR_github_owner \
  -e TF_VAR_repository_name \
  -e TF_VAR_github_token \
  -e DRY_RUN \
  tool-sidecar \
  bash .github/scripts/apply-repository-settings.sh
```

plan が目的の差分だけであることを確認してから apply:

```bash
unset DRY_RUN

docker compose exec \
  -e TF_VAR_github_owner \
  -e TF_VAR_repository_name \
  -e TF_VAR_github_token \
  tool-sidecar \
  bash .github/scripts/apply-repository-settings.sh
```

作業後:

```bash
docker compose down
```

ヘルパーを使わない場合の最小手順:

```bash
cd .github/terraform/repository-settings
terraform init -input=false
terraform import -input=false github_repository.template "${TF_VAR_repository_name}"
terraform plan -input=false
terraform apply -input=false
```

## 検証

apply 後は次を確認する。

```bash
gh api "repos/${TF_VAR_github_owner}/${TF_VAR_repository_name}" \
  --jq '{delete_branch_on_merge, allow_update_branch, has_issues, has_projects, has_wiki}'

docker compose exec \
  -e TF_VAR_github_owner \
  -e TF_VAR_repository_name \
  -e TF_VAR_github_token \
  tool-sidecar \
  bash -c 'cd .github/terraform/repository-settings && terraform plan -input=false -detailed-exitcode'
```

期待結果:

- GitHub API で管理対象の値が意図どおりである
- `terraform plan -detailed-exitcode` が No changes / exit code 0 になる
- `tfplan` などの生成物は削除し、state は `.gitignore` 対象としてローカルに残す

## 関連スキル

- Bash スクリプトを追加・修正する場合は `bash-style-guide` を読む
- dotenvx へ token を登録する場合は `dotenvx-env` を読む
- テンプレート同期の文脈なら `template-sync` と併用する
