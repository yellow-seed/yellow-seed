---
name: pull-request
description: "Pull Request作成スキル。OpenSpec の proposal.md / tasks.md と .github/PULL_REQUEST_TEMPLATE.md に基づいて、変更の背景・完了タスク・検証結果が揃った高品質なPRを作成。Use when: PR作成、Pull Request作成、変更内容のPR化、OpenSpec change をPRにまとめる依頼をされた時。"
---

# Pull Request 作成

OpenSpec で作業した `proposal.md` と `tasks.md` を一次情報として読み、`.github/PULL_REQUEST_TEMPLATE.md` に沿った Pull Request を作成します。
PR 本文では「なぜやるか」「何を完了したか」「差分として何が入ったか」「どう検証したか」が自然につながるようにします。

## PR 作成原則

1. **OpenSpec 起点**: `proposal.md` の背景・目的と `tasks.md` の完了状況を最初に確認する
2. **差分で裏取り**: OpenSpec の記述だけで断定せず、`git diff` / `git status` / コミット履歴で実際の変更を確認する
3. **テンプレート準拠**: `.github/PULL_REQUEST_TEMPLATE.md` の見出しに合わせて本文を作る
4. **レビュアー視点**: レビュアーが背景、変更範囲、未完了事項、検証状況を短時間で追える構成にする
5. **Issue 連携**: proposal やブランチ名、コミット、Issue 情報から関連 Issue を正確に参照する

## 参照する情報

| 情報源                                       | 用途                                       |
| -------------------------------------------- | ------------------------------------------ |
| `openspec/changes/<change>/proposal.md`      | PR の背景、目的、Related Issues の候補     |
| `openspec/changes/<change>/tasks.md`         | 完了タスク、未完了タスク、Test Plan の候補 |
| `git diff <base>...HEAD`                     | 実際に入った変更内容、リスク、レビュー観点 |
| `git log <base>...HEAD --oneline`            | PR タイトル、コミット単位の確認            |
| `.github/PULL_REQUEST_TEMPLATE.md`           | PR 本文の最終フォーマット                  |
| Issue / レビューコメント / CI 結果（あれば） | Related Issues、検証結果、注意事項の補強   |

## PR 本文への写し方

| PR セクション  | 主な情報源              | 書き方                                                               |
| -------------- | ----------------------- | -------------------------------------------------------------------- |
| Summary        | `proposal.md`           | 「なぜやるか」と変更の到達点を 2-3 文で要約する                      |
| Related Issues | proposal、Issue、commit | `Closes #123` / `Fixes #123` / `Related to #123` を必要に応じて記載  |
| OpenSpec       | change directory        | change 名、proposal/tasks の有無、タスク完了状況を記載               |
| Changes Made   | `tasks.md` と diff      | 完了タスクを軸に、実際の差分で確認できる変更をグループ化して列挙する |
| Testing        | `tasks.md` と実行結果   | 実行したコマンド、CI、手動確認など、判断可能な検証結果を明示する     |
| Review Notes   | diff、未完了タスク      | レビュアーに見てほしい点、リスク、未完了事項、補足を簡潔に書く       |
| Evidence       | UI、CLI、API 実行結果   | スクリーンショット、実行ログ、リクエスト/レスポンス例などを載せる    |

## PR 作成手順

### 1. 対象 OpenSpec change を確認

会話やブランチ名から change 名を推定します。曖昧な場合は一覧を確認し、対象を選びます。

```bash
openspec list --json
openspec status --change <change-name> --json
```

次のファイルを必ず読みます。

```bash
openspec/changes/<change-name>/proposal.md
openspec/changes/<change-name>/tasks.md
```

OpenSpec change が存在しない PR でも作成は可能です。その場合は、PR 本文の OpenSpec セクションに「なし」と明記し、diff とコミット履歴を主情報源にします。

### 2. 差分とコミット履歴を確認

```bash
git branch --show-current
git merge-base HEAD origin/main
git log origin/main...HEAD --oneline
git diff origin/main...HEAD --name-only
git diff origin/main...HEAD
```

ベースブランチが `main` ではない場合は、リポジトリの既定ブランチや PR の向きに合わせて置き換えます。

### 3. セルフレビューを実施

PR 作成前に、ブランチ差分をレビュー観点で確認します。
詳細な手順は [self-review/SKILL.md](../self-review/SKILL.md) を参照してください。

特に以下を確認します。

- proposal の目的と実際の差分がずれていない
- tasks の完了チェックが実態と一致している
- PR に含めるべき検証結果が残っている
- 未完了タスクや既知リスクを隠していない

### 4. Summary を作成

`proposal.md` の「なぜやるか」を主軸にします。
ただし、PR では実装後の状態を伝えるため、目的だけでなく「今回どこまで完了したか」も含めます。

```markdown
## Summary

OpenSpec で整理した PR 作成フローに合わせて、pull-request スキルと PR テンプレートを更新します。proposal/tasks を PR 本文の一次情報として扱うことで、変更の背景、完了範囲、検証結果をレビューしやすくします。
```

### 5. OpenSpec セクションを作成

change 名と artifacts の状態を記載します。
`tasks.md` は完了数と未完了タスクの有無が伝わるようにします。

```markdown
## OpenSpec

- Change: `align-pr-template-with-openspec`
- Proposal: `openspec/changes/align-pr-template-with-openspec/proposal.md`
- Tasks: 6/6 complete
```

### 6. Changes Made を作成

`tasks.md` のタスクを骨格にし、`git diff` で確認できる実ファイル単位の変更を添えます。

```markdown
## Changes Made

- pull-request スキルを OpenSpec 起点の PR 作成フローに更新
  - proposal/tasks を一次情報として読む手順を追加
  - diff とコミット履歴で実装内容を裏取りする流れに整理

- PR テンプレートを proposal/tasks と揃う構成に更新
  - Summary、OpenSpec、Changes Made、Testing、Review Notes を追加
```

### 7. Testing を作成

実行済みのコマンドを具体的に書きます。
未実施の検証がある場合は、Review Notes に理由を添えます。

```markdown
## Testing

- [x] `openspec status --change align-pr-template-with-openspec --json`
- [x] `prettier --check .agents/skills/pull-request/SKILL.md .github/PULL_REQUEST_TEMPLATE.md`
- CI checks: not run locally
```

### 8. PR を作成

テンプレートに沿った本文を一時ファイルに作成してから `gh pr create` を実行します。

```bash
gh pr create --title "<type>: <subject>" --body-file /tmp/pr-body.md
```

## 品質チェック

| 項目           | チェック内容                                                    |
| -------------- | --------------------------------------------------------------- |
| Summary        | proposal の目的と実装後の到達点が 2-3 文で説明されている        |
| OpenSpec       | change 名、proposal/tasks、タスク完了状況が記載されている       |
| Changes Made   | tasks と diff の両方に基づいて変更内容が説明されている          |
| Testing        | CI や実行コマンドなど、決定的に確認できる検証結果が書かれている |
| Evidence       | UI、CLI、API 変更でレビュー判断に使える証跡が添えられている     |
| Review Notes   | 既知リスク、未完了事項、レビューしてほしい点が隠されていない    |
| Template       | `.github/PULL_REQUEST_TEMPLATE.md` の見出しを崩していない       |
| Title          | Conventional Commits 形式になっている                           |
| Related Issues | proposal や Issue 情報に基づいて正確な参照になっている          |

## 他のスキルとの連携

- `self-review`: PR 作成前の差分確認に使う
- `commit-message`: PR タイトルを Conventional Commits 形式に整える時に使う
- `github-issue`: Related Issues や受け入れ基準の確認に使う
- `code-review`: リスクやレビュアー観点を洗い出す時に使う

## 注意事項

- `tasks.md` にチェックが付いていても、diff や検証結果で確認できない内容は PR に断定的に書かない
- 未完了タスクや未実施検証は Review Notes や Testing に明示する
- OpenSpec change が複数ある場合は、PR に含める change を混ぜずに明確化する
- 変更種別を運用したい場合は PR 本文の自己申告欄ではなく、GitHub label の整備と付与ルールで扱う
- PR 本文の末尾に Codex 署名を入れる場合は、リポジトリの既存運用に従う
