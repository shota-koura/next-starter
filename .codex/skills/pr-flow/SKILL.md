---
name: pr-flow
description: push後にPR作成/表示、CIとレビューをポーリング監視、@codex review投稿、必要に応じてCodeRabbit要約、マージコマンド提示までを gh で実行する。構造変更があれば repository-structure.md を同期する
---

## 目的

- push 後の「PR 作成〜CI監視〜レビュー依頼〜（可能なら）マージ提案」までを、Web UI に依存せずターミナルで完結させる。
- 差分最小・CI安定・レビューしやすさを優先する。
- 構造変更（ファイル追加/削除/移動/改名）がある場合に `docs/repository-structure.md` を最新化し、PRの整合性を担保する。

## いつ使うか

- `git push` した直後（または push 済みブランチで PR を作りたい/状態を確認したいとき）。
- PR を開いて CI とレビューを待ち、`@codex review` を投げたいとき。
- push直後に CI やレビューがまだ開始していない場合でも、そのままポーリングで待ち続けたいとき。

## 前提

- main/master への直接 push はしない（作業ブランチ前提）。
- `gh auth status` が通ること。
- `scripts/pr.sh` がある場合はそれを優先して使う（無い場合はフォールバック手順）。
- `bash scripts/tree.sh` が利用できること（`docs/repository-structure.md` を更新するため）。

## 運用ポリシー

- CI とレビュー監視はユーザーへの確認なしで継続する。
  - pending のまま、または未開始（チェック0件・レビュー0件）でも待ち続ける。
- `gh` コマンドの一時的な失敗（通信・API揺れ等）が起きても自動で再試行する。
- 停止条件は次のいずれかのみ。
  - CI の fail を検知した
  - ユーザーが明示的に停止を指示した

## 環境変数

必要なら実行前に設定する（未設定ならデフォルトで進む）。

- `POLL_SEC`  
  CIポーリング間隔（秒）。デフォルト `15`
- `POLL_SEC_REVIEW`  
  CodeRabbitポーリング間隔（秒）。デフォルト `20`
- `WAIT_CODERABBIT`  
  CodeRabbit完了まで待つか。デフォルト `1`（待つ）。`0` で待たない

## 実行手順

### 0 現在状態を通知

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"
echo "[OK] branch: $BRANCH $SHA"
```

- `BRANCH` が `main` / `master` の場合は停止し、作業ブランチ作成へ誘導する。

### 0.5 リポジトリ構造の同期

目的:

- PRレビュー前提となる「現在の構造」を `docs/repository-structure.md` に反映し、重複実装・配置ミス・見落としを減らす。

手順:

1. ベースブランチとの差分で、構造変更（Add/Delete/Rename/Copy）を検知
2. 構造変更があれば `bash scripts/tree.sh` を実行して `docs/repository-structure.md` を更新
3. `docs/repository-structure.md` をコミットして push
4. その後にPR作成/レビュー依頼/CIへ進む

```bash
# base ref: origin/main を優先（無ければ main）
BASE_REF="main"

# まずは origin/main を最新化（失敗しても継続）
git fetch origin main --quiet || true

if git show-ref --verify --quiet refs/remotes/origin/main; then
  BASE_REF="origin/main"
fi

# A=add, C=copy, D=delete, R=rename を構造変更扱い
STRUCT_CHANGES="$(git diff --name-status "$BASE_REF"...HEAD --diff-filter=ACDR || true)"
if [[ -n "${STRUCT_CHANGES}" ]]; then
  echo "[INFO] structure changes detected vs $BASE_REF:"
  echo "$STRUCT_CHANGES"

  bash scripts/tree.sh
  git add docs/repository-structure.md

  # 変更が無ければ commit は失敗するので許容
  git commit -m "docs: update repository structure" || true

  # push 済みでも、追加コミットが必要ならもう一度 push する
  git push
else
  echo "[OK] no structural changes vs $BASE_REF"
fi
```

補足:

- ここで `docs/repository-structure.md` の更新コミットが入った場合、CIは再実行される。以降の手順はその最新コミットに対して進める。

### 1 PR 作成 or 表示

```bash
if [[ -f scripts/pr.sh ]]; then
  bash scripts/pr.sh
else
  echo "[INFO] scripts/pr.sh not found -> fallback with gh"
fi
```

`scripts/pr.sh` が無い場合のフォールバック:

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
gh pr view "$BRANCH" >/dev/null 2>&1 || gh pr create --fill --base main --head "$BRANCH"
gh pr view --json number,title,url,isDraft --jq '"[OK] PR: #\(.number) \(.title)\n\(.url)\n[INFO] isDraft=\(.isDraft)"'
```

### 2 レビュー依頼コメントを投稿

#### 2.1 @codex review を PR コメントで投稿

```bash
gh pr comment --body "@codex review"
echo "[OK] review request: posted \"@codex review\""
```

観点指定したい場合:

```bash
gh pr comment --body "@codex review for security regressions and test coverage"
```

#### 2.2 CodeRabbit を確実に起動するためのトリガを投稿

CodeRabbit が自動で起動しない/遅いケースの保険として、標準で投げる。

```bash
gh pr comment --body "@coderabbitai review"
echo "[OK] CodeRabbit: posted \"@coderabbitai review\""
```

### 3 CI を監視

`--watch` を使わず、短い `gh pr checks` を繰り返すポーリングで待つ。

```bash
echo "[WAIT] CI: polling checks..."

POLL_SEC="${POLL_SEC:-15}"

# required が 0件なら全チェックへフォールバックして監視する
SCOPE="--required"
REQ_TOTAL="$(gh pr checks $SCOPE --json bucket --jq 'length' 2>/dev/null || true)"
if [[ -z "$REQ_TOTAL" || "$REQ_TOTAL" == "0" ]]; then
  SCOPE=""
fi

while true; do
  # 一時エラーは想定内としてリトライ
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
    echo "[INFO] CI: unable to fetch checks (transient). retrying..."
    sleep "$POLL_SEC"
    continue
  fi

  IFS=$'\t' read -r TOTAL PASS SKIP PEND CANCEL FAIL <<<"$TSV"

  # push直後は 0件(未開始) があり得るので、そのまま待つ
  if [[ "$TOTAL" -eq 0 ]]; then
    echo "[INFO] CI: checks not started yet. retrying..."
    sleep "$POLL_SEC"
    continue
  fi

  echo "[INFO] CI: total=$TOTAL pass=$PASS skip=$SKIP pending=$PEND cancel=$CANCEL fail=$FAIL"

  if [[ "$FAIL" -gt 0 ]]; then
    echo "[ERROR] CI failure detected"
    gh pr checks $SCOPE --json name,bucket,state,link --jq \
      '.[] | select(.bucket=="fail") | "- \(.name) (\(.state)) \(.link)"'
    exit 1
  fi

  # pending/cancel が 0 なら完了扱い
  if [[ "$PEND" -eq 0 && "$CANCEL" -eq 0 ]]; then
    echo "[OK] CI all finished"
    gh pr checks $SCOPE
    break
  fi

  sleep "$POLL_SEC"
done
```

### 4 CodeRabbit を監視して要約を自動取得

- CodeRabbit のレビューが未開始でも待ち続ける。
- 検知したら `$coderabbit-digest` を実行して要点を自動取得する。
- `$coderabbit-digest` が「未検知」相当の結果なら、再度ポーリングする。

```bash
WAIT_CODERABBIT="${WAIT_CODERABBIT:-1}"
if [[ "$WAIT_CODERABBIT" != "1" ]]; then
  echo "[INFO] CodeRabbit: WAIT_CODERABBIT!=1 -> skip waiting"
else
  echo "[WAIT] CodeRabbit: polling for review output..."

  POLL_SEC_REVIEW="${POLL_SEC_REVIEW:-20}"

  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
  PR_NUM="$(gh pr view --json number --jq .number)"

  while true; do
    # PR会話コメント(issue comments)から CodeRabbit を探す
    HIT="$(gh api "repos/$REPO/issues/$PR_NUM/comments" --paginate --jq \
      '[.[] | select(.user.login | test("coderabbit"; "i"))] | length' 2>/dev/null || true)"

    if [[ -n "$HIT" && "$HIT" != "0" ]]; then
      echo "[OK] CodeRabbit: comment detected"
      echo "[INFO] CodeRabbit: fetching latest comment"
      gh api "repos/$REPO/issues/$PR_NUM/comments" --paginate --jq \
        '[.[] | select(.user.login | test("coderabbit"; "i"))]
         | sort_by(.created_at)
         | last
         | .body'

      echo "[INFO] CodeRabbit: running digest"
      $coderabbit-digest
      break
    fi

    echo "[INFO] CodeRabbit: not ready yet. retrying..."
    sleep "$POLL_SEC_REVIEW"
  done
fi
```

## 失敗時

CI が落ちた場合:

1. まず失敗したチェック名を把握する:

```bash
gh pr checks --required || gh pr checks
```

2. 失敗ログを抽出する:

- `$ci-log-failed` を実行して失敗ログをターミナルに出す。
- そのログに基づいて修正する（無関係差分は増やさない）。

3. 修正後はローカル検証 -> commit/push -> この skill を再実行:

- ローカル検証は `$verify-fast`（開発ループ）/ `$verify-full`（完了前）を使う。

## CodeRabbit 指摘がある場合

- CI が通っていても CodeRabbit 指摘が残っていそうな場合は `$coderabbit-digest` を実行して要点を把握する。
- P0/P1 から優先して対応する。
- 設計変更を伴う提案は目的に照らして必要性を判断し、必要なら理由を明記する。

## 成功時

- checks が全て pass していることを確認:

```bash
gh pr checks
```

- Draft でないこと（Draft なら Ready for review が必要）:

```bash
gh pr view --json isDraft,url --jq '"[INFO] isDraft=\(.isDraft)\n\(.url)"'
```

- マージ可能なら、マージコマンドを提示（実行は状況に応じて）:

```bash
echo "[OK] All green: ready to merge"
echo "Suggested:"
echo "  gh pr merge --squash --delete-branch"
echo "Or (if enabled):"
echo "  gh pr merge --auto --squash --delete-branch"
```

## 出力フォーマット

- `[OK] branch: <branch> <sha>`
- `[INFO] structure changes detected ...`（該当時）
- `[OK] PR: #<number> <url>`
- `[OK] review request: posted "@codex review"`
- `[OK] CodeRabbit: posted "@coderabbitai review"`
- `[WAIT] CI: polling checks...`
- `[INFO] CI: checks not started yet. retrying...`（未開始時）
- `[ERROR] CI failure detected`（失敗時）
- `[WAIT] CodeRabbit: polling for review output...`
- `[OK] CodeRabbit: comment detected`
- `[OK] All green: ready to merge`

## 完了条件

- PRが作成/表示できている。
- `@codex review` を投稿している。
- CI結果が確認できている。
- 構造変更（追加/削除/移動/改名）がある場合、`docs/repository-structure.md` が更新され、コミット＆push済みである。
- CodeRabbit が利用可能な環境では、レビュー出力を検知して `$coderabbit-digest` で内容を確認済みである。
