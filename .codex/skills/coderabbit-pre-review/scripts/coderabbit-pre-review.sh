#!/usr/bin/env bash
set -euo pipefail

CR_REVIEW_TYPE="${CR_REVIEW_TYPE:-uncommitted}"
CR_BASE_BRANCH="${CR_BASE_BRANCH:-main}"
CR_MODE="${CR_MODE:-prompt-only}"

if ! command -v coderabbit >/dev/null 2>&1; then
  echo "[ERROR] coderabbit CLI not found."
  echo "[HINT] Install: curl -fsSL https://cli.coderabbit.ai/install.sh | sh"
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  echo "[ERROR] not in a git repository."
  exit 1
fi
cd "$ROOT"

echo "[INFO] repo root: $ROOT"
git status -sb

AUTH_STATUS_OUTPUT="$(coderabbit auth status 2>&1 || true)"
if [[ "$AUTH_STATUS_OUTPUT" == *"Not logged in"* ]] || [[ "$AUTH_STATUS_OUTPUT" == *"Authentication required"* ]]; then
  echo "[ERROR] coderabbit is not authenticated."
  echo "[HINT] Run: coderabbit auth login"
  exit 1
fi

MODE_FLAG="--prompt-only"
if [[ "$CR_MODE" == "plain" ]]; then
  MODE_FLAG="--plain"
fi

echo "[INFO] Running CodeRabbit pre-review: mode=$CR_MODE type=$CR_REVIEW_TYPE base=$CR_BASE_BRANCH"

coderabbit review "$MODE_FLAG" -t "$CR_REVIEW_TYPE" --base "$CR_BASE_BRANCH" &
REVIEW_PID=$!

while kill -0 "$REVIEW_PID" 2>/dev/null; do
  sleep 60
  if kill -0 "$REVIEW_PID" 2>/dev/null; then
    echo "[INFO] CodeRabbit review を待機中です..."
    echo "[INFO] 長い差分では数分かかることがあります"
  fi
done

wait "$REVIEW_PID"
