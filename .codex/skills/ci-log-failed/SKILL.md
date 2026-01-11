---
name: ci-log-failed
description: PRのCIが失敗したときに、失敗チェック名と最新runの失敗ログを gh で抽出して表示する
---

## 目的

- CI 失敗時に「どのチェックが落ちたか」と「失敗ログ（該当箇所）」を、修正前に必ずターミナルへ出す。

## いつ使うか

- `gh pr checks` が失敗しているとき。
- `verify` など required checks が落ちたとき。

## 実行手順

### 1) 失敗チェックの把握

required checks が取れるなら優先:

```bash
gh pr checks --required || gh pr checks

```

### 2) 対象ブランチの最新 run を特定して失敗ログを出す

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

RUN_ID="$(gh run list --branch "$BRANCH" --event pull_request --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
if [[ -z "$RUN_ID" ]]; then
  echo "ERROR: No GitHub Actions runs found for branch $BRANCH"
  echo "HINT: PR が無い/まだCIが走っていない可能性。先に PR を作成してから再実行する。"
  exit 1
fi

echo "[INFO] run_id=$RUN_ID (branch=$BRANCH)"
gh run view "$RUN_ID" --log-failed

```

## 補足

- workflow が `pull_request` トリガー前提の場合、PR が存在しないブランチには run が無いことがある。
- `--event pull_request` で見つからない場合、必要に応じて `--event push` も試す（ただし PR の required checks は pull_request に寄ることが多い）。

## 完了条件

- 失敗ログがターミナルに出ていること（ログ無しで修正に入らない）。
- ログに基づく最小差分の修正案ができていること。
