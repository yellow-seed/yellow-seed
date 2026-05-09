# OpenSpec 導入ガイド（案A）

Issue #207 の方針として、OpenSpec をテンプレートへそのまま導入しました。

## 追加されたもの

- Claude Code 向けコマンド
  - `.github/commands/opsx/propose.md`
  - `.github/commands/opsx/explore.md`
  - `.github/commands/opsx/apply.md`
  - `.github/commands/opsx/archive.md`
- Claude/Codex 共通スキル（`.agents/skills/` 経由）
  - `openspec-propose`
  - `openspec-explore`
  - `openspec-apply-change`
  - `openspec-archive-change`
- OpenSpec 管理ディレクトリ
  - `openspec/changes/`
  - `openspec/specs/`

## 基本ワークフロー

1. `/opsx:propose` で変更提案を作る
2. `openspec/changes/<change-name>/` に proposal / specs / design / tasks をそろえる
3. `/opsx:apply` で tasks を実装する
4. `/opsx:archive` で変更をアーカイブする

## 既存 `design-plan` スキルとの関係

- `design-plan` は既存ユーザー向けの導線として残します
- 新規フローの標準は OpenSpec（`/opsx:propose`）です
- 既存の設計レビュー観点（API/UI/CLI/インフラ）は、必要に応じて OpenSpec の design/specs 作成時に継続利用してください

## 補足

OpenSpec CLI をローカルで使う場合の例:

```bash
openspec list --json
openspec status --change <change-name> --json
```
