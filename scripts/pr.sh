#!/usr/bin/env bash
set -euo pipefail

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# PRが無ければ作る（openが無いだけの可能性があるので state all で拾う）
PR_NUM="$(gh pr list --head "$BRANCH" --state all --json number --jq '.[0].number' 2>/dev/null || true)"

if [[ -z "${PR_NUM:-}" ]]; then
  gh pr create --fill --base main --head "$BRANCH"
  PR_NUM="$(gh pr view --json number --jq .number)"
fi

gh pr view "$PR_NUM" --json number,title,url --jq '"\(.number) \(.title)\n\(.url)"'
gh pr checks "$PR_NUM" --watch --fail-fast

echo "CI ok. Merge with:"
echo "  gh pr merge $PR_NUM --squash --delete-branch"
