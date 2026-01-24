#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

POLL_SEC="${POLL_SEC:-30}"
POLL_SEC_REVIEW="${POLL_SEC_REVIEW:-30}"
AUTO_MERGE="${AUTO_MERGE:-1}"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"

echo "[OK] branch: $BRANCH $SHA"

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] On main/master. Switch to a work branch."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[ERROR] gh auth status failed. Authenticate with gh first."
  exit 1
fi

gh pr view --json number,url,isDraft --jq '"[OK] PR: #\(.number)\n\(.url)\n[INFO] isDraft=\(.isDraft)"'

echo "[WAIT] CI: polling checks..."

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
    echo "[INFO] CI: fetch failed (transient) -> retry"
    sleep "$POLL_SEC"
    continue
  fi

  IFS=$'\t' read -r TOTAL PASS SKIP PEND CANCEL FAIL <<<"$TSV"

  if [[ "$TOTAL" -eq 0 ]]; then
    echo "[INFO] CI: not started -> retry"
    sleep "$POLL_SEC"
    continue
  fi

  echo "[INFO] CI: total=$TOTAL pass=$PASS skip=$SKIP pending=$PEND cancel=$CANCEL fail=$FAIL"

  if [[ "$FAIL" -gt 0 ]]; then
    CI_FAIL=1
    echo "[ERROR] CI: failure detected"
    gh pr checks $SCOPE --json name,bucket,state,link --jq \
      '.[] | select(.bucket=="fail") | "- \(.name) (\(.state)) \(.link)"'
    break
  fi

  if [[ "$PEND" -eq 0 && "$CANCEL" -eq 0 ]]; then
    echo "[OK] CI: all checks completed"
    break
  fi

  sleep "$POLL_SEC"
done

if [[ "$CI_FAIL" == "1" ]]; then
  echo "[INFO] CI: trying to fetch failed logs (GitHub Actions)"

  RUN_ID="$(gh run list --branch "$BRANCH" --limit 20 --json databaseId,conclusion,createdAt --jq '
    map(select(.conclusion=="failure")) | .[0].databaseId // empty
  ' 2>/dev/null || true)"

  if [[ -n "$RUN_ID" ]]; then
    echo "[INFO] run_id=$RUN_ID"
    gh run view "$RUN_ID" --log-failed || true
  else
    echo "[INFO] Failed run not found. See failing check links above."
  fi
fi

echo "[WAIT] Review: polling for outputs..."

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
    echo "[INFO] Review: fetch failed (transient) -> retry"
    sleep "$POLL_SEC_REVIEW"
    continue
  fi

  echo "[INFO] Review: head=$HEAD_SHA reviews(head)=$REVIEWS_HEAD_CNT line(head)=$LINE_HEAD_CNT"

  if [[ "$REVIEWS_HEAD_CNT" != "0" || "$LINE_HEAD_CNT" != "0" ]]; then
    echo "[OK] Review: output detected"
    break
  fi

  sleep "$POLL_SEC_REVIEW"
done

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
    | "- \(.path):\((.line // .original_line // 0)|tostring) [\(.user.login)] \(.body | gsub("\\r?\\n"; " ") | .[:160])\\n  \(.html_url)"
  '
  echo "----- END REVIEW_P0_DIGEST -----"
else
  echo "[OK] Review(P0): no line comments"
fi

if [[ "$CI_FAIL" == "0" && "$LINE_CNT_HEAD" == "0" ]]; then
  IS_DRAFT="$(gh pr view --json isDraft --jq .isDraft)"
  if [[ "$IS_DRAFT" == "true" ]]; then
    echo "[ERROR] PR is draft. Mark Ready for review, then rerun."
    exit 1
  fi

  if [[ "$AUTO_MERGE" == "1" ]]; then
    echo "[OK] enable auto-merge:"
    gh pr merge --auto --squash --delete-branch
  else
    echo "[INFO] AUTO_MERGE=0: skip merge"
    echo "Suggested: gh pr merge --auto --squash --delete-branch"
  fi

  exit 0
fi

echo "[INFO] Fixes required. Apply changes, run verify-fast, commit/push, then rerun this script."
exit 2
