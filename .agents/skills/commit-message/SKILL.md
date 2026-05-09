---
name: commit-message
description: "コミットメッセージ作成スキル。Conventional + Contextual Commits 形式の日本語メッセージを作成。Use when: コミット作成、変更内容のコミット、git commitを依頼された時。"
---

# コミットメッセージ作成

Conventional Commits をベースに、Contextual Commits で意思決定の文脈を残す。

## 形式

```
<type>: <subject>

<body>

<footer>
```

## ルール

- type は Conventional Commits の標準（feat/fix/docs/style/refactor/perf/test/chore）を使う
- subject/body は日本語で簡潔に書く
- body は「何を変えたか」より「なぜそうしたか」を優先する
- 必要に応じて Contextual Commits の action types を使う
  - `intent:` 目的
  - `decision:` 採用した判断
  - `rejected:` 採用しなかった案
  - `constraint:` 制約
  - `learned:` 学び・次回改善
- GitHub Issue に取り組むコミットでは footer に `Closes #<number>` を必ず含める

## Co-Authored-By 方針

- 固定のモデル名をコミットメッセージへ埋め込まない
- Codex: 環境/設定で正しい Co-Authored-By を付与する
- Claude: skill では「エージェント名までを記載する」指示に留める

## 例

```git
docs: コミット規約の参照導線を簡素化

intent: AGENTS.md の重複規約を減らし、更新箇所を skill に集約する

decision: AGENTS.md は要点とリンクのみ残し、詳細は skill へ委譲する

constraint: 既存の Conventional Commits と互換性を維持する

Closes #234
```

## コミット作成手順

1. `git status` / `git diff` で差分確認
2. type/subject を決める
3. body に intent/decision を最低1つずつ書く
4. 必要なら rejected/constraint/learned を追加
5. Issue 対応時は `Closes #<number>` を footer に追加
6. Co-Authored-By は実行環境の方針に従って付与
7. HEREDOC で整形して `git commit` 実行
