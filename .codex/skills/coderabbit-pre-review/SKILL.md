---
name: coderabbit-pre-review
description: CodeRabbit CLI を使って、precommit 後・commit 前のローカル差分を事前レビューし、P0/P1/P2相当で整理して修正要否を判断する
---

## 目的

- PR を作る前に、ローカル差分へ CodeRabbit の観点を当てる。
- 指摘を `P0/P1/P2` 相当で整理し、commit 前に直すべきものを決める。
- GitHub 上の CodeRabbit 自動レビューを待たずに、左シフトで手戻りを減らす。
- `change-review` と並列で走らせても、親エージェントが結果を統合できる形に揃える。

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
4. 出力を `P0/P1/P2` 相当で整理する
5. finding が 1 件でもあれば、番号付きで提示してユーザーが対応番号を選ぶまで停止する
6. `P0` は原則 `対応推奨`、`P1/P2` は `条件付き対応` または `見送り可` を付けて示す
7. 指示された番号だけを修正し、必要なら再度 `$verify-fast` または `$verify-full` を行ってから `$commit` に進む

## 出力の扱い

- CodeRabbit CLI の出力を、そのまま貼るのではなく要点化する。
- 提示形式は次を推奨する。

```text
- No.:
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
- finding がある場合、ユーザー指示前に自動修正へ進まない。

## 完了条件

- CodeRabbit CLI の結果が `P0/P1/P2` 相当で整理されている。
- commit 前に直すべきものと、見送るものが説明できる。
