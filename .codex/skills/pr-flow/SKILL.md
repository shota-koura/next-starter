---
name: pr-flow
description: push後にPR作成/表示、@codex review/投稿、CIとレビュー出力をポーリング監視、行コメントのダイジェスト表示と日本語要約、問題がなければ自動マージまでを gh で実行する（修正が必要なら pr-fix-loop に委譲）
---

## 目的

- push 後の「PR 作成〜レビュー起動〜CI監視〜（必要なら）修正ループ〜自動マージ」までを、Web UI に依存せずターミナルで完結させる。
- 差分最小・CI安定・レビューしやすさを優先する。
- レビュー内容は P0 として「行コメント（PR review comments）」のみを一次ソースとし、Conversation の summary/walkthrough は検知用途に限定する。

## いつ使うか

- `git push` した直後（または push 済みブランチで PR を作りたい/状態を確認したいとき）。
- PR を開いて CI とレビューを待ち、`@codex review` を投げたいとき。
- CI とレビューが未開始でも、そのままポーリングで待ち続けたいとき。

## 前提

- main/master への直接 push はしない（作業ブランチ前提）。
- `gh auth status` が通ること。
- `scripts/pr.sh` がある場合はそれを優先して使う（無い場合はフォールバック手順）。

## 1コマンド実行（推奨）

次を実行する。

```bash
bash .codex/skills/pr-flow/scripts/pr-flow.sh
```

- このスクリプトが本ファイルの手順をまとめて実行する。
- スクリプトは `REVIEW_P0_DIGEST` を出力するため、Codex が日本語要約を返す。
- 失敗した場合は「実行手順（手動）」に従う。

## 運用ポリシー

- CI とレビュー監視はユーザーへの確認なしで継続する。
  - pending のまま、または未開始（チェック0件・レビュー0件）でも待ち続ける。
- `gh` コマンドの一時的な失敗（通信・API揺れ等）が起きても自動で再試行する。
- 停止条件は次のいずれかのみ。
  - ユーザーが明示的に停止を指示した
  - 修正が必要（CI fail またはレビュー行コメントあり）になったので `pr-fix-loop` に委譲した

## 環境変数

必要なら実行前に設定する（未設定ならデフォルトで進む）。

- `BASE_BRANCH`
  - PRのbaseブランチ。デフォルト `main`
- `POLL_SEC`
  - CIポーリング間隔（秒）。デフォルト `30`
- `POLL_SEC_REVIEW`
  - レビュー検知ポーリング間隔（秒）。デフォルト `30`
- `AUTO_MERGE`
  - 問題が無い場合に自動マージを実行するか。デフォルト `1`。`0` でマージしない（コマンド提示のみ）

## 実行手順（手動）

### 0) 現在状態を通知

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"
echo "[OK] ブランチ: $BRANCH $SHA"

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] main/master 上です。作業ブランチへ切り替えてください。"
  exit 1
fi
```

### 1) PR 作成 or 表示

```bash
if [[ -f scripts/pr.sh ]]; then
  bash scripts/pr.sh
else
  echo "[INFO] scripts/pr.sh not found -> fallback with gh"
  BASE_BRANCH="${BASE_BRANCH:-main}"
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  gh pr view "$BRANCH" >/dev/null 2>&1 || gh pr create --fill --base "$BASE_BRANCH" --head "$BRANCH"
fi

gh pr view --json number,title,url,isDraft --jq '"[OK] PR: #\(.number) \(.title)\n\(.url)\n[INFO] isDraft=\(.isDraft)"'
```

### 2) レビュー依頼コメントを投稿（毎回）

```bash
gh pr comment --body "@codex review in Japanese"
echo "[OK] レビュー依頼: \"@codex review in Japanese\" を投稿"
```

### 3) CI を監視

`--watch` を使わず、短い `gh pr checks` を繰り返すポーリングで待つ。

```bash
echo "[WAIT] CI: チェックをポーリング中..."

POLL_SEC="${POLL_SEC:-30}"

SCOPE="--required"
REQ_TOTAL="$(gh pr checks $SCOPE --json bucket --jq 'length' 2>/dev/null || true)"
if [[ -z "$REQ_TOTAL" || "$REQ_TOTAL" == "0" ]]; then
  SCOPE=""
fi

while true; do
  TSV="$(gh pr checks $SCOPE --json bucket --jq '
    [
      length,
      ([.[]|select(.bucket=="pass")]|length),
      ([.[]|select(.bucket=="skipping")]|length),
      ([.[]|select(.bucket=="pending")]|length),
      ([.[]|select(.bucket=="cancel")]|length),
      ([.[]|select(.bucket=="fail")]|length)
    ] | @tsv
  ' 2>/dev/null || true)"

  if [[ -z "$TSV" ]]; then
    echo "[INFO] CI: 取得失敗(一時) -> リトライ"
    sleep "$POLL_SEC"
    continue
  fi

  IFS=$'\t' read -r TOTAL PASS SKIP PEND CANCEL FAIL <<<"$TSV"

  if [[ "$TOTAL" -eq 0 ]]; then
    echo "[INFO] CI: 未開始 -> リトライ"
    sleep "$POLL_SEC"
    continue
  fi

  echo "[INFO] CI: total=$TOTAL pass=$PASS skip=$SKIP pending=$PEND cancel=$CANCEL fail=$FAIL"

  if [[ "$FAIL" -gt 0 ]]; then
    echo "[ERROR] CI: 失敗を検知"
    gh pr checks $SCOPE --json name,bucket,state,link --jq \
      '.[] | select(.bucket=="fail") | "- \(.name) (\(.state)) \(.link)"'
    echo "[INFO] 修正ループへ委譲: \$pr-fix-loop"
    exit 0
  fi

  if [[ "$PEND" -eq 0 && "$CANCEL" -eq 0 ]]; then
    echo "[OK] CI: 全チェック完了"
    break
  fi

  sleep "$POLL_SEC"
done
```

### 4) レビュー出力を検知し、行コメントの機械的ダイジェストを表示

- 目的: 「レビューが動いた」ことを確認しつつ、一次ソースは行コメント（PR review comments）だけに限定する。
- Conversation の summary/walkthrough は検知用途のみ（タスク化しない）。

#### 4.1) レビューが動いたことの検知（HEADに紐づく Review/行コメント、または会話コメント）

```bash
echo "[WAIT] Review: 出力を検知するまでポーリング中..."

POLL_SEC_REVIEW="${POLL_SEC_REVIEW:-30}"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PR_NUM="$(gh pr view --json number --jq .number)"

while true; do
  HEAD_SHA="$(gh pr view --json headRefOid --jq .headRefOid)"
  HEAD_TIME="$(gh api "repos/$REPO/commits/$HEAD_SHA" --jq .commit.author.date 2>/dev/null || true)"

  ISSUE_CNT="0"
  if [[ -n "$HEAD_TIME" ]]; then
    ISSUE_CNT="$(gh api "repos/$REPO/issues/$PR_NUM/comments" --paginate --jq \
      '[.[]
        | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
        | select((.created_at | fromdateiso8601) >= ("'"$HEAD_TIME"'" | fromdateiso8601))
      ] | length' 2>/dev/null || true)"
  fi

  REVIEWS_HEAD_CNT="$(gh api "repos/$REPO/pulls/$PR_NUM/reviews" --paginate --jq \
    '[.[]
      | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
      | select((.commit_id // "") == "'"$HEAD_SHA"'")
    ] | length' 2>/dev/null || true)"

  LINE_HEAD_CNT="$(gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate --jq \
    '[.[]
      | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
      | select(.commit_id == "'"$HEAD_SHA"'")
    ] | length' 2>/dev/null || true)"

  if [[ -z "$ISSUE_CNT" || -z "$REVIEWS_HEAD_CNT" || -z "$LINE_HEAD_CNT" ]]; then
    echo "[INFO] Review: 取得失敗(一時) -> リトライ"
    sleep "$POLL_SEC_REVIEW"
    continue
  fi

  echo "[INFO] Review: head=$HEAD_SHA issue=$ISSUE_CNT reviews(head)=$REVIEWS_HEAD_CNT line(head)=$LINE_HEAD_CNT"

  if [[ "$ISSUE_CNT" != "0" || "$REVIEWS_HEAD_CNT" != "0" || "$LINE_HEAD_CNT" != "0" ]]; then
    echo "[OK] Review: 出力を検知"
    break
  fi

  sleep "$POLL_SEC_REVIEW"
done
```

#### 4.2) 行コメント（P0）の件数確認とダイジェスト表示（一次ソース）

```bash
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PR_NUM="$(gh pr view --json number --jq .number)"
HEAD_SHA="$(gh pr view --json headRefOid --jq .headRefOid)"

LINE_CNT_HEAD="$(gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate --jq \
  '[.[]
    | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
    | select(.commit_id == "'"$HEAD_SHA"'")
  ] | length' 2>/dev/null || true)"

echo "[INFO] Review(P0): head=$HEAD_SHA line_comments=$LINE_CNT_HEAD"

if [[ "$LINE_CNT_HEAD" != "0" ]]; then
  echo "[INFO] Review(P0) digest:"
  echo "----- BEGIN REVIEW_P0_DIGEST -----"
  gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate --jq '
    .[]
    | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
    | select(.commit_id == "'"$HEAD_SHA"'")
    | "- \(.path):\((.line // .original_line // 0)|tostring) [\(.user.login)] \(.body | gsub("\r?\n"; " ") | .[:160])\n  \(.html_url)"
  '
  echo "----- END REVIEW_P0_DIGEST -----"
else
  echo "[OK] Review(P0): 行コメントなし（修正要求なしの可能性）"
fi
```

#### 4.3) 意味的要約（Codexが日本語で実施）

4.2 の実行結果（`BEGIN REVIEW_P0_DIGEST` から `END REVIEW_P0_DIGEST` まで）を入力として、以下の形式で日本語要約をターミナルに必ず出力する。

- 制約: 10行以内、推測禁止、同じ指摘は統合する。

出力テンプレート:

```text
要約（日本語）:
- 結論: <1行>
- 高: <file>: <1行>（最大2件）
- 中: <file>: <1行>（最大2件）
- 低: <file>: <1行>（最大2件）
```

注意:

- `Review(P0): 行コメントなし` の場合は、要約は `結論: 指摘なし` の1行だけでよい。

### 5) 分岐（修正が必要なら委譲、不要なら自動マージ）

- `LINE_CNT_HEAD > 0` の場合:
  - 修正が必要。次に `$pr-fix-loop` を実行して「拾う→修正→push→再レビュー/CI→収束→自動マージ」まで委譲する。
- `LINE_CNT_HEAD == 0` かつ CI が成功している場合:
  - `AUTO_MERGE=1` なら自動マージを実行する。

```bash
AUTO_MERGE="${AUTO_MERGE:-1}"

# ここで必ず再計算（bashブロック間で変数が引き継がれない前提）
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PR_NUM="$(gh pr view --json number --jq .number)"
HEAD_SHA="$(gh pr view --json headRefOid --jq .headRefOid)"

LINE_CNT_HEAD="$(gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate --jq \
  '[.[]
    | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
    | select(.commit_id == "'"$HEAD_SHA"'")
  ] | length' 2>/dev/null || true)"

if [[ -z "$LINE_CNT_HEAD" ]]; then
  echo "[ERROR] Review(P0): 行コメント件数の取得に失敗しました。再実行してください。"
  exit 1
fi

if [[ "$LINE_CNT_HEAD" != "0" ]]; then
  echo "[INFO] 修正が必要。次に \$pr-fix-loop を実行してください。"
  exit 0
fi

IS_DRAFT="$(gh pr view --json isDraft --jq .isDraft)"
if [[ "$IS_DRAFT" == "true" ]]; then
  echo "[ERROR] PRがDraftです。Ready for reviewにしてから再実行してください。"
  exit 1
fi

if [[ "$AUTO_MERGE" == "1" ]]; then
  echo "[OK] 自動マージを設定します:"
  gh pr merge --auto --squash --delete-branch
else
  echo "[INFO] AUTO_MERGE=0 のためマージは実行しません。"
  echo "Suggested:"
  echo "  gh pr merge --auto --squash --delete-branch"
fi
```

## 完了条件

- PRが作成/表示できている。
- `@codex review in Japanese` を投稿している。
- CI が成功している（fail の場合は `pr-fix-loop` に委譲して停止）。
- レビュー出力を検知し、P0（行コメント）のダイジェストを表示し、Codexが日本語で意味的要約を表示している。
- P0行コメントが無い場合は `gh pr merge --auto --squash --delete-branch` を実行している（AUTO_MERGE=1）。
- P0行コメントがある場合は `pr-fix-loop` に委譲している。
