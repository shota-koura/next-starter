---
name: pr-flow
description: 作業完了時に、document-update、precommit、coderabbit-pre-review、change-review、commit、pr-review-merge を使い、PR 作成からマージとローカル main 同期までを進める。開発途中の save point には使わない
---

# PR Flow

## 目的

- PR 提案からマージとローカル `main` 同期までの標準順序を 1 つの入口で扱えるようにする。
- 既存の `document-update`、`precommit`、`coderabbit-pre-review`、`change-review`、`commit`、`pr-review-merge` を置き換えず、実行順だけを固定する。
- 手順漏れを減らしつつ、各 skill の責務は分けたまま保つ。

## いつ使うか

- PR を新規に作る、または更新して最後まで進めたいとき。
- 毎回 `document-update -> precommit -> local reviews -> commit -> pr-review-merge` を明示するのが煩雑なとき。
- 開発途中の軽い checkpoint ではなく、最終 review / PR / merge に進みたいとき。

## この skill の役割

- この skill は薄い orchestrator であり、個別の検証や GitHub 操作の実体を持たない。
- 実体は既存 skill に委ねる。
- 開発途中の save point は責務外とし、その用途では `$checkpoint-save` を使う。
- 各段階で停止条件に当たった場合は、その skill の結果を優先する。
- ローカル review 段階では `coderabbit-pre-review` と `change-review` を並列で扱う。
- `change-review` は `codex-reviewer` sub-agent を必須とするため、この標準順序は `codex-reviewer` を使えるセッションを前提にする。
- findings の最終確定は `coderabbit-pre-review` と `change-review` の両方が完了してから行う。
- 両レーンが完了するまで findings を提示しない。片側結果の先行提示は行わない。
- 片方が失敗、未完了、または結果回収不能な場合は commit へ進まず停止する。
- local review の応答が遅くても完了を待ち、タイムアウトや遅延を理由に親判断でレビュー対象を狭めない。
- local review で finding が出た場合は commit へ進まず、ID 付き一覧を提示してユーザー指示待ちで停止する。

## 標準順序

1. 必要なら `$document-update`
2. `$precommit`
3. `$coderabbit-pre-review` と `$change-review` を並列で実行
4. 親エージェントが結果を統合し、ID 付き findings を提示する
5. finding があればユーザーが対応 ID を選ぶまで停止し、指定された ID だけ修正する
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

- `coderabbit-pre-review` と `change-review` の**両方が完了するまで** findings を提示しない。片側結果の先行提示は行わない。
- 両レーン完了後、親エージェントが結果を P0/P1/P2 でセクション分けし、各 finding に stable ID を付けて提示する。
- stable ID は一度提示したら再 review 後も維持し、同じ finding が残る限り変えない。新規 finding だけを末尾に追加する。
- ID にレビュー lane 由来のプレフィックスを持たせてもよいが、ユーザーとのやり取りでは stable ID を一次識別子として扱う。
- sub-agent 通知や CLI 生出力が先に表示されていても、親エージェントの findings 提示は最終整理を 1 回だけ返す。
- 片方が失敗、未完了、または結果回収不能な場合は、その理由、推奨対応方針、再開条件を提示したうえでこの段階で停止する。
- finding が 1 件でもあれば commit 前に停止し、ユーザーへ「対応する ID」を確認する。
- ユーザー指示があるまで修正しない。
- `codex-reviewer` を使えないセッション、または `codex-reviewer` が完了しない状態では、この段階で停止し、sub-agent 利用可能なセッションへ切り替えるか、完了を待ってから再開する。
- local review の応答が遅い場合は待機を継続しつつ「どの lane が待機中か」を明示して報告する。
- タイムアウトや遅延を理由に親判断でレビュー対象を狭めない。
- 待機が長引く場合も commit へは進まず、「待機継続」または「ここで停止」をユーザー判断に委ねる。

#### 統合フォーマット

findings は以下の形式で提示する。P0/P1/P2 のセクションに分け、該当なしのセクションは省略する。各 finding には stable ID を付け、再 review 後も同じ指摘である限り同じ ID を維持する。

```text
## P0

### PRF-1. {概要}
- ソース: CodeRabbit|codex-reviewer
- 詳細: {指摘の詳細。参照ファイルパスを含む}
- 推奨方針: 対応推奨
- 解説: {なぜ問題になりうるのか、2-3文の初心者向け説明。対応要否の判断材料}

## P1

### PRF-2. {概要}
- ソース: CodeRabbit|codex-reviewer
- 詳細: {指摘の詳細。参照ファイルパスを含む}
- 推奨方針: 対応推奨|条件付き対応|見送り可
- 解説: {なぜ問題になりうるのか、2-3文の初心者向け説明。対応要否の判断材料}

## P2

### PRF-3. {概要}
- ソース: codex-reviewer
- 詳細: {指摘の詳細。参照ファイルパスを含む}
- 推奨方針: 条件付き対応|見送り可
- 解説: {なぜ問題になりうるのか、2-3文の初心者向け説明。対応要否の判断材料}
```

### 5) 指示された ID だけ修正して review をやり直す

- ユーザーが ID を返したら、その ID だけを最小差分で修正する。
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
- `coderabbit-pre-review` と `change-review` のどちらか片方でも未完了、失敗、または結果回収不能な場合
- local review が長時間待機中で、ユーザーが継続待機または停止を判断する必要がある場合
- local review で finding が出て、まだユーザーの ID 指定が無い場合
- `commit` がガードレール違反を検知した場合
- `pr-review-merge` が禁止領域変更や人間判断を要求した場合

## Subagent 利用方針

- この skill 自体は orchestrator だが、local review 段階では `change-review` 側の方針に従って `codex-reviewer` を使う。
- CodeRabbit CLI は sub-agent 化せず、CLI 実行のまま parallel lane として扱う。
- local review は両 lane の完了まで待ち、両方完了するまで findings を提示しない。
- 遅延時も待機を継続し、親判断でレビュー対象やレビュー観点を削らない。

## 完了条件

- 実行すべき skill の順序が明確である。
- PR 提案からマージとローカル `main` 同期までのどこで止まるか説明できる。
- local review に finding があるとき、ユーザー指示前に commit へ進まない。
- findings の ID は stable ID であり、同じ finding が残る限り再実行後も維持される。
