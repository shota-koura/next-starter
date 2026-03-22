---
name: pr-review-merge
description: push後にPR作成/表示、CI を監視し、必要に応じて修正→verify→push を繰り返し、条件を満たせば自動マージし、その後ローカル main 同期まで完結する
---

# PR Review Merge

## 目的

- `git push` 後の「PR作成/取得 → CI監視 →（必要に応じて）修正ループ → 自動マージ → ローカル `main` 同期」までを、GitHub Web UI に依存せずに完結させる。
- ローカル pre-review を済ませた前提で、PR 後は CI と merge 条件の収束に集中する。
- CI 失敗時は失敗箇所と必要な修正方針を提示し、修正ループへつなぐ。

## いつ使うか

- `git push` 直後に、PR作成からマージとローカル同期までを一気通貫で進めたいとき。
- PR は既にあるが、CI 完了を待って整理・判断・修正まで回したいとき。
- CI が未開始でも、開始されるまで含めて監視し続けたいとき。
- 上流の `pr-flow` から後段フローとして呼び出したいとき。
- CodeRabbit と `change-review` をローカルで済ませた後、PR 上では CI と merge に絞りたいとき。

## 前提条件（満たせない場合は「停止＋不足条件の提示」）

- 作業ブランチ上（`main` / `master` 直上で実行しない）。
- `gh auth status` が成功する。
- `jq` が利用可能。

## 入力（暗黙）

- 現在のブランチ（`git rev-parse --abbrev-ref HEAD`）
- 現在のHEAD（`git rev-parse HEAD`）
- 対象PR（存在すればそれ、無ければ作成）

## 出力（ユーザーに提示するもの）

- PR URL / 番号 / base / head / 最新SHA
- CIサマリー（成功/失敗/未開始、失敗時は失敗チェック一覧とリンク）
- CI 失敗時の修正方針または必要な確認事項
- 収束後の自動マージ結果（または `AUTO_MERGE=0` の場合はコマンド提示）
- ローカル `main` 同期結果（`POST_MERGE_SYNC=1` の場合）

## 環境変数

- `BASE_BRANCH`: PRのベースブランチ（既定 `main`）
- `POLL_SEC_CI`: CI ポーリング間隔（既定 `120`）
- `AUTO_MERGE`: 収束後に自動マージするか（既定 `1`。`0` の場合はコマンド提示のみ）
- `POST_MERGE_SYNC`: merge 後にローカルを `main` へ戻して `origin/main` に同期するか（既定 `1`）
- `DELETE_LOCAL_BRANCH`: merge 後にローカル作業ブランチを削除するか（既定 `1`）

## ガードレール（全工程で常に優先）

- 無関係な整形/リファクタは禁止（差分最小）。
- 禁止領域に触れる必要が出たら停止し、理由と必要な人手判断を提示する。
  - `.github/**`（特に workflows）
  - `.coderabbit.yaml` / `.coderabbit.yml`
  - 依存・ロック系（例: `package.json`, `pnpm-lock.yaml`, `yarn.lock`, `pyproject.toml`, `poetry.lock`, `requirements*.txt`）
  - `.env*` 等の環境変数ファイル

## Subagent 利用方針

- sub-agent 利用が明示的に許可されている場合のみ、CI 失敗や再現不明の症状調査で `debugger` を使う。
- この skill は PR 収束フローが主目的であり、広い設計作業や実装分担の入口にはしない。

## 実行フロー（状態機械）

以下を順に実行し、条件未達なら同ステップをポーリングで継続する。

### Step 0: 事前チェック

- ブランチが `main/master` なら停止して「作業ブランチへ切替」を指示。
- `gh auth status` / `jq` を確認し、不足があれば停止して導入手順を提示。

### Step 1: PR を「取得または作成」

- 既存PRがあればそれを採用。
- 無ければ `BASE_BRANCH` を base として新規作成。
- 以降は PR 番号/URL を固定して追跡する。

### Step 2: CI 監視（120秒ポーリング・上限なし）

- `gh pr checks` 等で状態を取得し、以下に分類する。
  - `success`: すべて成功
  - `fail`: 失敗が1つ以上
  - `pending`: 実行中/未開始/待ち
- `fail` の場合は「失敗チェック名・URL」を列挙する（可能なら直近ログも要約して添付）。
  - ログ要約は秘密情報/PII を必ずマスキングし、フルログの貼り付けは禁止。
  - 例: `token=***` / `email=***` のように最小限で伏せる。
- `pending` の場合は `POLL_SEC_CI` 秒待って再取得（上限なし）。
- `success` になったら Step 5 へ。
- `fail` の場合は Step 3 へ。

### Step 3: CI 失敗時の整理と修正方針提示

- CI が失敗した場合は、失敗チェック名・URL・要点を列挙する。
- 可能なら直近ログも要約して添付する。
- 必要なら `debugger` の利用を提案する。
- 修正に進む場合は Step 4 へ。

### Step 4: 修正ループ（上限なし）

- 対象: CI 失敗を解消するための最小差分

- ループの基本形:
  1. CI 失敗原因に対して最小差分で修正
  2. ガードレール検査（許可範囲外/禁止領域変更があれば停止）
  3. `$verify-fast` を成功させる（成功するまでローカルで修正を続ける）
  4. commit→ push
  5. Step 2（CI 監視）へ戻す

- 収束判定:
  - CI: success
  - 満たせば Step 5 へ

### Step 5: 自動マージ

- 条件（全て満たす）:
  - CI が success

- `AUTO_MERGE=1` の場合:
  - `gh pr merge --auto --squash --delete-branch` を実行

- `AUTO_MERGE=0` の場合:
  - 上記コマンドを提示して終了

### Step 6: ローカル `main` 同期

- 前提:
  - `AUTO_MERGE=1` で merge が成功している
  - `POST_MERGE_SYNC=1`
- 実行内容:
  - `git fetch origin`
  - `git switch main`
  - `git pull --ff-only origin main`
  - `DELETE_LOCAL_BRANCH=1` かつ merge 対象ブランチが `main/master` 以外なら `git branch -d <merged-branch>`
- 停止条件:
  - 作業ツリーに未コミット差分が残っている
  - `main` への切替または `ff-only` pull に失敗する
  - ローカルブランチ削除に失敗する
- 失敗時:
  - merge 自体は成功扱いのまま停止し、どの post-merge sync が失敗したかを提示する

## 例外処理（必ず守る）

- `gh` が一時的に失敗（API揺れ/ネットワーク）:
  - エラー内容を短く表示し、同ステップを再試行（ポーリングに合流）。

- CI が長時間 `pending`:
  - `POLL_SEC_CI` 秒ごとに継続監視（上限なし）。ユーザー確認なしで続行。

- ガードレール違反が必要になった:
  - commit/push せず停止。変更が必要な理由・該当ファイル・代替案を提示し、ユーザー判断を仰ぐ。

- post-merge sync 中に `main` へ戻せない / `origin/main` へ fast-forward できない:
  - merge 結果は維持したまま停止し、ローカルで必要な追従手順を提示する。
