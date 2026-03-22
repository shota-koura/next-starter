---
name: pr-flow
description: document-update、precommit、commit、pr-review-merge を順に実行し、PR 提案からマージとローカル main 同期までの標準順序をまとめて案内する
---

# PR Flow

## 目的

- PR 提案からマージとローカル `main` 同期までの標準順序を 1 つの入口で扱えるようにする。
- 既存の `document-update`、`precommit`、`commit`、`pr-review-merge` を置き換えず、実行順だけを固定する。
- 手順漏れを減らしつつ、各 skill の責務は分けたまま保つ。

## いつ使うか

- PR を新規に作る、または更新して最後まで進めたいとき。
- 毎回 `document-update -> precommit -> commit -> pr-review-merge` を明示するのが煩雑なとき。

## この skill の役割

- この skill は薄い orchestrator であり、個別の検証や GitHub 操作の実体を持たない。
- 実体は既存 skill に委ねる。
- 各段階で停止条件に当たった場合は、その skill の結果を優先する。

## 標準順序

1. 必要なら `$document-update`
2. `$precommit`
3. `COMMIT_MSG` を設定して `$commit`
4. push 後に `$pr-review-merge`

## 実行ガイド

### 1) ドキュメント整合の要否を確認

- 差分が `docs/development/.steering/` や `AGENTS.md` に影響する可能性があるなら `$document-update` を先に使う。
- ステアリング不要の小作業で、ドキュメント更新も不要ならこの段階は省略してよい。

### 2) プレコミット

```text
$precommit
```

### 3) コミット

```bash
export COMMIT_MSG='type(scope): 日本語要約'
```

```text
$commit
```

### 4) PR 作成からマージとローカル同期まで

```text
$pr-review-merge
```

## 停止条件

- `document-update` が大きな設計判断を要求して停止した場合
- `commit` がガードレール違反を検知した場合
- `pr-review-merge` が禁止領域変更や人間判断を要求した場合

## Subagent 利用方針

- この skill 自体は orchestrator であり、直接 sub-agent を起動する前提を持たない。
- sub-agent の利用は、後続の各 skill 側の方針に従う。

## 完了条件

- 実行すべき skill の順序が明確である。
- PR 提案からマージとローカル `main` 同期までのどこで止まるか説明できる。
