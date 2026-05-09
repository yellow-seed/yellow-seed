---
name: template-sync
description: "テンプレート同期スキル。yellow-seed/template と派生リポジトリ間の変更のやりとりを支援（Pull: テンプレ→子へ反映、Push: 子の改善を yellow-seed/template へ GitHub Issue で提案）。Use when: テンプレート更新の反映、派生→template へのフィードバック、template 同期全般。"
---

# テンプレート同期

`yellow-seed/template` と**派生リポジトリ**のあいだで差分を運ぶ。向きに応じて参照ドキュメントを開く。パス列挙より**役割・パターン**で考える（表・原則は共通参照に集約）。

## 同期の向き

| 向き | ソース | 宛先 | 参照 |
|------|--------|------|------|
| **Pull** | `yellow-seed/template`（既定 `main`） | 派生リポジトリ | [references/pull.md](references/pull.md) |
| **Push** | 派生で検証済みの、テンプレに載せられる変更 | `yellow-seed/template` | [references/push.md](references/push.md) |

Push は派生の全マージではなく、**一般化でき秘密・固有情報がない差分**に限る。**還流の標準**は派生からテンプレへ直接 PR を作らず、`yellow-seed/template` に **GitHub Issue** を立てて差分・出典を渡すこと（理由・手順は [push.md](references/push.md)）。

## 共通参照

パターン別の同期方針・同期タイプ早見・調査コマンド・トラブルシュート・他スキル連携・`TEMPLATE_REPO` は [references/shared.md](references/shared.md)。

**読み順の例**: `shared` で対象と原則を把握 → Pull なら `pull`、Push なら `push` の手順へ進む。
