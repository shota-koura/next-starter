---
name: pr-fix-loop
description: CodeRabbit/Codexの行コメント（P0）とCI失敗ログを抽出し、ダイジェスト表示と日本語要約を行ったうえで、最大3回まで自律修正→verify→commit→push→再レビュー/CIを繰り返し、問題がなければ自動マージする
---

## 目的

- CodeRabbit/Codex の指摘（一次ソースは行コメント）と CI 失敗ログを集約し、何を直すべきかを明確化する。
- 可能な範囲で自律的に「拾う→修正→push→再レビュー/CI」を回し、収束すれば自動マージする。
- ガードレールに違反する変更が必要になった場合は停止し、状況を報告する。

## いつ使うか

- `pr-flow` で CI fail または P0行コメントが検出されたとき。
- CI は通っているが CodeRabbit/Codex の行コメントが残っているとき。
- ローカルで修正→push→再チェックを最大3回まで回したいとき。

## 前提

- main/master への直接 push はしない（作業ブランチ前提）。
- `gh auth status` が通ること。
- PR が存在すること（無い場合は `pr-flow` を先に実行）。
- 既存の検証スキルが使えること:
  - `$verify-fast`（必須）
  - `$verify-full`（任意: 最終確認で推奨）

## 1コマンド実行（推奨・1反復）

次を実行する。

```bash
bash .codex/skills/pr-fix-loop/scripts/pr-fix-loop.sh
```

- CI監視、レビュー出力検知、P0ダイジェスト、収束時の自動マージまでを 1 回分まとめて実行する。
- 修正が必要と出た場合は 1.7〜1.11 を実施してから再実行する（最大 `MAX_ITERS` 回の考え方は維持）。
- スクリプトが `REVIEW_P0_DIGEST` を出力するため、Codex は日本語要約を返す。

## 環境変数

- `POLL_SEC`
  - CIポーリング間隔（秒）。デフォルト `30`
- `POLL_SEC_REVIEW`
  - レビュー出力検知ポーリング間隔（秒）。デフォルト `30`
- `MAX_ITERS`
  - 修正ループ上限回数。デフォルト `3`
- `AUTO_MERGE`
  - 収束したら自動マージを実行するか。デフォルト `1`。`0` でマージしない（コマンド提示のみ）

## ガードレール（必須）

### 1) 変更範囲の制限

変更してよいのは、原則として次の集合の和集合のみ。

- PR差分に既に含まれるファイル（`gh pr diff --name-only`）
- CodeRabbit/Codex の行コメントで参照されているファイル（PR review comments の `.path`）

上記以外のファイルが変更されていたら停止（commit/pushしない）。

### 2) 変更禁止領域（AGENTSの“事前確認が必要”を強制）

次に該当するファイル/領域に変更が入ったら停止（commit/pushしない）。

- `.github/` 配下（特に `.github/workflows/`）
- `.coderabbit.yaml` / `.coderabbit.yml`
- 依存管理ファイル/ロックファイル
  - `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`
  - `pyproject.toml`, `poetry.lock`, `requirements*.txt`
- `.env*` など環境変数ファイル

### 3) 反復回数の上限

- 修正ループは最大 `MAX_ITERS` 回（デフォルト3回）。
- 収束しない場合は停止し、残っている課題を要約して報告する。

### 4) ローカル検証ゲート

- push 前に必ず `$verify-fast` を通す。
- 通らない変更は push しない。

### 5) レビュー再トリガ（毎回有効）

- 各ループで必ず `@codex review in Japanese` と `@coderabbitai review` を投稿する。

## 実行手順（手動）

### 0) 現在状態とPR情報の確認

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"
echo "[OK] ブランチ: $BRANCH $SHA"

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] main/master 上です。作業ブランチへ切り替えてください。"
  exit 1
fi

gh pr view --json number,url,isDraft --jq '"[OK] PR: #\(.number)\n\(.url)\n[INFO] isDraft=\(.isDraft)"'
```

### 1) 反復ループ（最大 MAX_ITERS 回）

この skill は「1回の反復 = 1回の commit/push（または収束判定）」とする。最大 `MAX_ITERS` 回まで繰り返す。

各反復で実施する順序:

1. CI完了まで待つ（failなら失敗ログを抽出して表示）
2. レビュー出力をHEAD単位で検知（Review/行コメント）
3. P0（行コメント）の機械的ダイジェスト表示
4. Codexが日本語で意味的要約を表示
5. 収束判定（CI成功かつP0行コメント0件ならマージへ）
6. 修正が必要なら、最小差分で修正（ガードレール適用）
7. `$verify-fast` を通す
8. commit/push（同じPRを更新）
9. レビュー再トリガ（毎回）

#### 1.1) 反復回数の表示（手動管理）

- `MAX_ITERS="${MAX_ITERS:-3}"` を前提に、反復回数 `i=1..MAX_ITERS` を明示して進める。
- 例: 反復1回目を開始する際に `[INFO] loop 1/3` を出す。

#### 1.2) CI を監視（failならログ抽出）

```bash
echo "[WAIT] CI: チェックをポーリング中..."
POLL_SEC="${POLL_SEC:-30}"

SCOPE="--required"
REQ_TOTAL="$(gh pr checks $SCOPE --json bucket --jq 'length' 2>/dev/null || true)"
if [[ -z "$REQ_TOTAL" || "$REQ_TOTAL" == "0" ]]; then
  SCOPE=""
fi

CI_FAIL=0

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
    CI_FAIL=1
    echo "[ERROR] CI: 失敗を検知"
    gh pr checks $SCOPE --json name,bucket,state,link --jq \
      '.[] | select(.bucket=="fail") | "- \(.name) (\(.state)) \(.link)"'
    break
  fi

  if [[ "$PEND" -eq 0 && "$CANCEL" -eq 0 ]]; then
    echo "[OK] CI: 全チェック完了"
    break
  fi

  sleep "$POLL_SEC"
done

if [[ "$CI_FAIL" == "1" ]]; then
  echo "[INFO] CI: 失敗ログ抽出を試行（GitHub Actions）"

  BRANCH="$(git rev-parse --abbrev-ref HEAD)"

  RUN_ID="$(gh run list --branch "$BRANCH" --limit 20 --json databaseId,conclusion,createdAt --jq '
    map(select(.conclusion=="failure")) | .[0].databaseId // empty
  ' 2>/dev/null || true)"

  if [[ -n "$RUN_ID" ]]; then
    echo "[INFO] run_id=$RUN_ID"
    gh run view "$RUN_ID" --log-failed || true
  else
    echo "[INFO] GitHub Actions run が特定できませんでした（外部CIの可能性）。上の failing check link を参照してください。"
  fi
fi
```

#### 1.3) レビュー出力の検知（HEAD単位）

- 目的: 反復ごとに「最新HEADに対するレビューが動いた」ことを検知する。
- 判定に使う一次情報:
  - PR reviews の `commit_id == HEAD_SHA`（レビュー本文やApprove等）
  - PR review comments の `commit_id == HEAD_SHA`（行コメント）

```bash
echo "[WAIT] Review: HEADに対する出力を検知するまでポーリング中..."

POLL_SEC_REVIEW="${POLL_SEC_REVIEW:-30}"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PR_NUM="$(gh pr view --json number --jq .number)"

while true; do
  HEAD_SHA="$(gh pr view --json headRefOid --jq .headRefOid)"

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

  if [[ -z "$REVIEWS_HEAD_CNT" || -z "$LINE_HEAD_CNT" ]]; then
    echo "[INFO] Review: 取得失敗(一時) -> リトライ"
    sleep "$POLL_SEC_REVIEW"
    continue
  fi

  echo "[INFO] Review: head=$HEAD_SHA reviews(head)=$REVIEWS_HEAD_CNT line(head)=$LINE_HEAD_CNT"

  if [[ "$REVIEWS_HEAD_CNT" != "0" || "$LINE_HEAD_CNT" != "0" ]]; then
    echo "[OK] Review: HEADに対する出力を検知"
    break
  fi

  sleep "$POLL_SEC_REVIEW"
done
```

#### 1.4) 行コメント（P0）の機械的ダイジェスト表示（一次ソース）

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
  echo "[OK] Review(P0): 行コメントなし"
fi
```

#### 1.5) 意味的要約（Codexが日本語で実施）

直前の出力を入力として、以下の形式で日本語要約をターミナルに必ず出力する。

入力（あるものだけ）:

- CI fail の場合: 失敗チェック名と失敗ログの要点（直前に表示された内容）
- 行コメント: `BEGIN REVIEW_P0_DIGEST` から `END REVIEW_P0_DIGEST` まで

制約:

- 15行以内
- 推測禁止
- 修正方針は最小差分

出力テンプレート:

```text
要約（日本語）:
- 結論: <何を直せば収束するか 1行>
- CI: <failなら要点1行 / 問題なければ "問題なし">
- 高: <file>: <1行>（最大3件）
- 中: <file>: <1行>（最大3件）
- 次の一手:
  - 1) <最初にやること>
  - 2) <次にやること>
  - 3) <最後にやること（verify-fastまで）>
```

#### 1.6) 収束判定

- CI が成功している（fail を検知していない）
- 最新HEADに対する P0行コメントが 0件

上記を満たす場合は「修正不要」として 2) 自動マージへ進む。満たさない場合は 1.7 へ進む。

#### 1.7) 修正（Codexが実際に編集する）

- 1.2 のCI失敗ログ、および 1.4 の行コメント（P0）に基づき、必要最小限の修正を行う。
- 無関係な整形・リファクタは禁止。
- ガードレールに抵触する変更が必要になった場合は停止し、理由を報告する。

必要なら差分コンテキストを確認する（任意）:

```bash
# 行コメントに出たファイルの差分を表示（必要なときだけ）
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PR_NUM="$(gh pr view --json number --jq .number)"
HEAD_SHA="$(gh pr view --json headRefOid --jq .headRefOid)"

PATHS="$(gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate --jq '
  .[]
  | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
  | select(.commit_id == "'"$HEAD_SHA"'")
  | .path
' 2>/dev/null | sed '/^$/d' | sort -u)"

if [[ -n "$PATHS" ]]; then
  echo "$PATHS" | while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    echo "[INFO] diff: $p"
    gh pr diff --patch -- "$p" || true
  done
fi
```

#### 1.8) ガードレール検査（変更範囲/禁止領域）

修正後、commit前に必ず実行する。

```bash
# 許可ファイル集合を毎回再計算（bashブロック間で変数が引き継がれない前提）
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PR_NUM="$(gh pr view --json number --jq .number)"
HEAD_SHA="$(gh pr view --json headRefOid --jq .headRefOid)"

ALLOWED_FILES="$(
  {
    gh pr diff --name-only
    gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate --jq '
      .[]
      | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
      | select(.commit_id == "'"$HEAD_SHA"'")
      | .path
    '
  } 2>/dev/null | sed '/^$/d' | sort -u
)"

echo "[INFO] allowed files:"
echo "$ALLOWED_FILES"

# 変更ファイル検出（rename等は想定しない。必要最小差分が前提）
CHANGED_FILES="$(git status --porcelain | sed -E 's/^.. //' | sed -E 's/^R  .+ -> //')"
if [[ -z "$CHANGED_FILES" ]]; then
  echo "[ERROR] 修正が必要なのに変更がありません。停止します（commit/pushしません）。"
  exit 1
fi

echo "[INFO] changed files:"
echo "$CHANGED_FILES"

FORBIDDEN_RE='^(\.github/|\.coderabbit\.ya?ml$|package(-lock)?\.json$|pnpm-lock\.yaml$|yarn\.lock$|poetry\.lock$|pyproject\.toml$|requirements.*\.txt$|\.env)'

VIOLATION=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue

  if ! echo "$ALLOWED_FILES" | grep -Fxq "$f"; then
    echo "[ERROR] 変更範囲外のファイルが変更されています: $f"
    VIOLATION=1
  fi

  if echo "$f" | grep -Eq "$FORBIDDEN_RE"; then
    echo "[ERROR] 事前確認が必要な領域に変更があります: $f"
    VIOLATION=1
  fi
done <<<"$CHANGED_FILES"

if [[ "$VIOLATION" == "1" ]]; then
  echo "[ERROR] ガードレール違反のため停止します（commit/pushしません）。"
  exit 1
fi
```

#### 1.9) ローカル検証ゲート（必須）

以下を実行し、成功するまで修正を続ける（成功するまで push しない）。

```text
$verify-fast
```

#### 1.10) commit / push（同じPRを更新）

```bash
git add -A
git status --porcelain

git commit -m "fix: レビュー/CI指摘対応"
git push
echo "[OK] push 完了（同じPRが更新されます）"
```

#### 1.11) レビュー再トリガ（毎回）

```bash
gh pr comment --body "@codex review in Japanese"
echo "[OK] レビュー再トリガ: \"@codex review in Japanese\" を投稿"

gh pr comment --body "@coderabbitai review"
echo "[OK] レビュー再トリガ: \"@coderabbitai review\" を投稿"
```

- ここまで完了したら、反復回数を 1 増やして 1.2 に戻る（最大 `MAX_ITERS` 回）。

### 2) 収束時: 自動マージ

- CI が成功
- 最新HEADに対する P0行コメントが 0件

```bash
AUTO_MERGE="${AUTO_MERGE:-1}"

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

### 3) 収束しない場合（上限到達）

`MAX_ITERS` 回実行しても収束しない場合は停止する。最後に次を日本語で短くまとめて出力して終了する。

- 残っている failing checks（名称とリンク）
- 残っている行コメントの要点（ファイル別）
- これ以上自動対応できない理由（ガードレール、設計判断、再現不能など）

残課題の機械的ダイジェスト（任意）:

```bash
echo "[INFO] remaining checks:"
gh pr checks --required || gh pr checks

REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
PR_NUM="$(gh pr view --json number --jq .number)"
HEAD_SHA="$(gh pr view --json headRefOid --jq .headRefOid)"

echo "[INFO] remaining P0 line comments on head=$HEAD_SHA:"
gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate --jq '
  .[]
  | select(.user.login | test("coderabbit|chatgpt-codex-connector|codex"; "i"))
  | select(.commit_id == "'"$HEAD_SHA"'")
  | "- \(.path):\((.line // .original_line // 0)|tostring) [\(.user.login)] \(.body | gsub("\r?\n"; " ") | .[:160])\n  \(.html_url)"
'
```

## 完了条件

- 収束した場合:
  - CI が成功し、P0行コメントが無く、`gh pr merge --auto --squash --delete-branch` を実行している（AUTO_MERGE=1）
- 停止した場合:
  - ガードレール違反、または上限到達により停止し、残課題を要約して報告している
