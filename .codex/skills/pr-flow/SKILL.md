---
name: pr-flow
description: document-update、precommit、coderabbit-pre-review、change-review、commit、pr-review-merge を使い、ローカル review は並列で進めつつ、PR 提案からマージとローカル main 同期までの標準順序をまとめて案内する
---

# PR Flow

## 目的

- PR 提案からマージとローカル `main` 同期までの標準順序を 1 つの入口で扱えるようにする。
- 既存の `document-update`、`precommit`、`coderabbit-pre-review`、`change-review`、`commit`、`pr-review-merge` を置き換えず、実行順だけを固定する。
- 手順漏れを減らしつつ、各 skill の責務は分けたまま保つ。

## いつ使うか

- PR を新規に作る、または更新して最後まで進めたいとき。
- 毎回 `document-update -> precommit -> local reviews -> commit -> pr-review-merge` を明示するのが煩雑なとき。

## この skill の役割

- この skill は薄い orchestrator であり、個別の検証や GitHub 操作の実体を持たない。
- 実体は既存 skill に委ねる。
- 各段階で停止条件に当たった場合は、その skill の結果を優先する。
- ローカル review 段階では `coderabbit-pre-review` と `change-review` を並列で扱う。
- `change-review` は `codex-reviewer` sub-agent を必須とするため、この標準順序は `codex-reviewer` を使えるセッションを前提にする。
- local review で finding が出た場合は commit へ進まず、番号付き一覧を提示してユーザー指示待ちで停止する。

## 標準順序

1. 必要なら `$document-update`
2. `$precommit`
3. `$coderabbit-pre-review` と `$change-review` を並列で実行
4. 親エージェントが結果を統合し、番号付き findings を提示する
5. finding があればユーザーが対応番号を選ぶまで停止し、指定された番号だけ修正する
6. local review を再実行して finding が無いことを確認する
7. `COMMIT_MSG` を設定して `$commit`
8. push 後に `$pr-review-merge`

## 実行ガイド

### 1) ドキュメント整合の要否を確認

- 差分が `docs/development/.steering/` や `AGENTS.md` に影響する可能性があるなら `$document-update` を先に使う。
- ステアリング不要の小作業で、ドキュメント更新も不要ならこの段階は省略してよい。

### 2) プレコミット

```text
$precommit
```

### 3) ローカル AI review を並列開始

CodeRabbit CLI と `codex-reviewer` を同時に走らせ、待ち時間を直列化しない。

```text
$coderabbit-pre-review
$change-review
```

### 4) 結果を統合して停止判定

- 親エージェントは CodeRabbit と `codex-reviewer` の結果を同じ形式へ正規化し、連番で統合して提示する。
- finding が 1 件でもあれば commit 前に停止し、ユーザーへ「対応する番号」を確認する。
- ユーザー指示があるまで修正しない。
- `codex-reviewer` を使えないセッションでは、この段階で停止し、sub-agent 利用可能なセッションへ切り替えてから再開する。

```text
- No.:
- ソース: CodeRabbit|codex-reviewer
- 懸念レベル: P0|P1|P2
- レビュータイトル:
- レビュー内容:
- 参照:
- 解釈:
- 対応方針: 対応推奨|条件付き対応|見送り可
```

### 5) 指示された番号だけ修正して review をやり直す

- ユーザーが番号を返したら、その番号だけを最小差分で修正する。
- 修正後は `$precommit` と local review 段階を再実行する。
- finding が無くなったら commit に進む。

### 6) コミット

```bash
export COMMIT_MSG='type(scope): 日本語要約'
```

```text
$commit
```

### 7) PR 作成からマージとローカル同期まで

```text
$pr-review-merge
```

## 停止条件

- `document-update` が大きな設計判断を要求して停止した場合
- `coderabbit-pre-review` が修正判断や認証不足で停止した場合
- `change-review` が blocking issue を返した場合
- `change-review` が `codex-reviewer` を利用できず停止した場合
- local review で finding が出て、まだユーザーの番号指定が無い場合
- `commit` がガードレール違反を検知した場合
- `pr-review-merge` が禁止領域変更や人間判断を要求した場合

## Subagent 利用方針

- この skill 自体は orchestrator だが、local review 段階では `change-review` 側の方針に従って `codex-reviewer` を使う。
- CodeRabbit CLI は sub-agent 化せず、CLI 実行のまま parallel lane として扱う。

## 完了条件

- 実行すべき skill の順序が明確である。
- PR 提案からマージとローカル `main` 同期までのどこで止まるか説明できる。
- local review に finding があるとき、ユーザー指示前に commit へ進まない。
