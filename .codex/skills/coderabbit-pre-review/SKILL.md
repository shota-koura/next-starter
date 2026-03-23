---
name: coderabbit-pre-review
description: CodeRabbit CLI を使って、precommit 後・commit 前のローカル差分を事前レビューし、P0/P1/P2相当で整理して修正要否を判断する
---

## 目的

- PR を作る前に、ローカル差分へ CodeRabbit の観点を当てる。
- 指摘を `P0/P1/P2` 相当で整理し、commit 前に直すべきものを決める。
- GitHub 上の CodeRabbit 自動レビューを待たずに、左シフトで手戻りを減らす。
- `change-review` と並列で走らせても、親エージェントが結果を統合できる形に揃える。
- 応答が遅くてもレビュー完了を待ち、タイムアウトや遅延を理由に親判断でこの review の結果待ちを打ち切らない。
- 応答が遅い場合は待機を継続しつつ、待機中であることを明示して報告する。

## いつ使うか

- `$precommit` の直後、`$commit` の前。
- PR 前提の標準フローで CodeRabbit の観点を先に入れたいとき。
- 大きめの差分で、ローカルのうちに review を済ませたいとき。
- `change-review` と並列に流して、ローカル review の待ち時間を短くしたいとき。

## 前提

- `coderabbit` CLI が利用可能であること。
- `coderabbit auth login` 済みであること。
- 差分が整形済みであること。通常は直前に `$precommit` を使う。

## 1コマンド実行（推奨）

次を実行する。

```bash
bash .codex/skills/coderabbit-pre-review/scripts/coderabbit-pre-review.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/coderabbit-pre-review/scripts/coderabbit-pre-review.ps1
```

## 環境変数

- `CR_REVIEW_TYPE`
  - `uncommitted` / `committed` / `all`（既定 `uncommitted`）
- `CR_BASE_BRANCH`
  - 比較対象ブランチ（既定 `main`）
- `CR_MODE`
  - `prompt-only` / `plain`（既定 `prompt-only`）

## 手順

1. `git status -sb` で差分を確認する
2. `coderabbit auth status` で認証状態を確認する
3. `coderabbit review --prompt-only -t uncommitted --base main` を基準にレビューする
   - 実行中は 60 秒ごとに次を表示して待機状態を明確にする
     - `CodeRabbit review を待機中です...`
     - `長い差分では数分かかることがあります`
4. 応答が遅くてもレビュー完了を待ち、タイムアウトや遅延を理由にこの review の結果待ちを打ち切らない
5. 出力を `P0/P1/P2` 相当で整理する
6. `pr-flow` 配下で CLI 生出力が先に見えていても、親エージェントは同じ finding を verbatim で二重再掲せず、最終整理だけを 1 回返す
7. finding が 1 件でもあれば、ID 付きで提示してユーザーが対応 ID を選ぶまで停止する
8. `P0` は原則 `対応推奨`、`P1/P2` は `条件付き対応` または `見送り可` を付けて示す
9. 指示された ID だけを修正し、必要なら再度 `$verify-fast` または `$verify-full` を行ってから `$commit` に進む

補足:

- 待機が長引く場合も、親判断で review 結果待ちを打ち切らない。
- 待機中は「CodeRabbit の完了待ちであり、まだ commit 判定に進めない」ことを明示する。

## 出力の扱い

- CodeRabbit CLI の出力を、そのまま貼るのではなく要点化する。
- 提示形式は次を推奨する。

```text
- ID: CR-1
- ソース: CodeRabbit
- 懸念レベル: P0|P1|P2
- レビュータイトル:
- レビュー内容:
- 参照:
- 解釈:
- 対応方針: 対応推奨|条件付き対応|見送り可
```

## 運用ルール

- token や機密情報を出力しない。
- `P0` は原則修正候補として扱う。
- `P1/P2` は差分規模、期限、影響度で対応要否を判断する。
- CodeRabbit CLI の結果は pre-review 用であり、PR 上の merge gate にはしない。
- `pr-flow` で使う場合、`change-review` と両方完了する前に commit 可否判定へ進まない。
- `pr-flow` 配下では、この skill の finding には `CR-*` の stable ID を付ける。
- `pr-flow` 配下では、もう片方の review lane が未完了、失敗、または結果回収不能な場合でも、この lane 自身が返した確定済み finding を親エージェントが「片側結果」として提示してよい。
- `pr-flow` 配下では、親エージェントは CodeRabbit CLI の raw 出力をそのまま繰り返さず、統合済み finding または片側結果だけを返す。
- `pr-flow` 配下で片側結果に基づく修正が入った場合は、修正前差分を見た未完了 lane の結果を stale とみなし、親エージェントは両 lane の review を修正後差分で再実行する。
- finding がある場合、ユーザーの ID 指定前に一切修正しない。
- 待機が長引く場合も、自動で打ち切らず、継続待機または停止の判断はユーザーに委ねる。

## 完了条件

- CodeRabbit CLI の結果が `P0/P1/P2` 相当で整理されている。
- 応答遅延があっても結果待ちを打ち切らず、未完了のまま commit 判定へ進んでいない。
- commit 前に直すべきものと、見送るものが説明できる。
- `pr-flow` 配下で片側結果として提示された finding も、最終統合時に同じ stable ID を維持できる。
