---
name: git-cleanup-audit
description: "Gitリポジトリの棚卸しスキル。ローカルブランチ・worktree・リモートブランチ・Issueの不要リソースを特定・削除。Use when: リポジトリのクリーンアップ、ブランチ整理、不要worktree削除、open Issueの棚卸しを依頼された時。"
---

# Git Cleanup & Audit

リポジトリに蓄積した不要リソースを棚卸し・クリーンアップするスキル。
責務ごとに4つのスクリプトに分割している。

## 環境判定

```bash
# *_REMOTE が設定されていれば Web 環境（通常ブランチ）
# 設定されていなければ ローカル環境（worktree）
is_remote_env() {
  env | grep -qE '^[A-Z_]+_REMOTE='
}
```

| 環境 | 判定 | 実行方式 |
|------|------|---------|
| ローカルPC | `*_REMOTE` なし | 全スクリプト実行可能 |
| Claude Code Web / Codex Web | `*_REMOTE=true` | `references/cleanup-remote-branches.sh` / `references/audit-issues.sh` のみ |

## スクリプト一覧

### 1. ローカルブランチ削除

`references/cleanup-local-branches.sh`

main にマージ済みのローカルブランチを削除する。

```bash
# 一覧のみ
bash .agents/skills/git-cleanup-audit/references/cleanup-local-branches.sh --dry-run

# 一括削除
bash .agents/skills/git-cleanup-audit/references/cleanup-local-branches.sh --force
```

**判定ロジック:**
```bash
git branch --merged main | sed 's/^[*[:space:]]*//' | grep -vE '^(main|<current-branch>)$'
```

### 2. Worktree 削除

`references/cleanup-worktrees.sh`

メインリポジトリ以外の worktree を削除する。Web環境ではスキップされる。

```bash
# 一覧のみ
bash .agents/skills/git-cleanup-audit/references/cleanup-worktrees.sh --dry-run

# 一括削除（stale worktree のクリーンアップ含む）
bash .agents/skills/git-cleanup-audit/references/cleanup-worktrees.sh --force
```

**コマンド:**
```bash
# worktree 一覧
git worktree list

# Worktrunk 使用時
wt list
wt remove <branch-name>

# stale worktree クリーンアップ
git worktree prune
```

### 3. リモートブランチ削除

`references/cleanup-remote-branches.sh`

PR マージ済み・close済みのリモートブランチを削除する。

```bash
# 一覧のみ
bash .agents/skills/git-cleanup-audit/references/cleanup-remote-branches.sh --dry-run

# 一括削除
bash .agents/skills/git-cleanup-audit/references/cleanup-remote-branches.sh --force
```

**判定ロジック:**
```bash
# PR マージ済みのリモートブランチ
gh pr list --state merged --limit 1000 --json headRefName,isCrossRepository \
  --jq '.[] | select(.isCrossRepository == false) | .headRefName'

# PR close済み（マージ以外）のリモートブランチ
gh pr list --state closed --limit 1000 --json headRefName,isCrossRepository \
  --jq '.[] | select(.isCrossRepository == false) | .headRefName'
```

### 4. Issue 棚卸し

`references/audit-issues.sh`

PR マージ済みに紐づいている open Issue を特定・closeする。

```bash
# 一覧のみ
bash .agents/skills/git-cleanup-audit/references/audit-issues.sh --dry-run

# 一括close
bash .agents/skills/git-cleanup-audit/references/audit-issues.sh --force
```

**判定ロジック:**
```bash
gh pr list --state merged --limit 100 --json closingIssuesReferences --jq '.[].closingIssuesReferences[].number'
gh issue view <number> --json state,title
```

## 注意事項

- 削除前に必ず `--dry-run` で確認すること
- worktree 削除時には、未コミットの変更が失われる
- リモートブランチ削除は `git push origin --delete` で即時反映される
- Issue close は復元可能だが、念のためコメントを残すこと
- Web環境では worktree 操作は実行しない
