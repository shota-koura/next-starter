#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

is_test_file() {
  local f="$1"
  [[ "$f" == "__tests__/"* || "$f" == *"/__tests__/"* || "$f" == "e2e/"* || "$f" == *"/e2e/"* || "$f" == *"/tests/"* || "$f" == *.test.* || "$f" == *.spec.* ]]
}

is_tool_file() {
  local f="$1"
  [[ "$f" == .codex/* || "$f" == scripts/* || "$f" == .github/* || "$f" == .coderabbit.y* || \
     "$f" == package.json || "$f" == package-lock.json || "$f" == pnpm-lock.yaml || "$f" == yarn.lock || \
     "$f" == poetry.lock || "$f" == pyproject.toml || "$f" == requirements*.txt || "$f" == .env* || \
     "$f" == eslint.config.* || "$f" == jest.config.* || "$f" == jest.setup.* || "$f" == tsconfig*.json || \
     "$f" == next.config.* || "$f" == postcss.config.* || "$f" == playwright.config.* || \
     "$f" == tailwind.config.* || "$f" == vite.config.* || "$f" == vitest.config.* ]]
}

is_doc_file() {
  local f="$1"
  [[ "$f" == docs/* || "$f" == *.md ]]
}

is_backend_file() {
  local f="$1"
  [[ "$f" == backend/* ]]
}

is_frontend_file() {
  local f="$1"
  [[ "$f" == app/* || "$f" == components/* || "$f" == lib/* || "$f" == public/* || "$f" == styles/* || \
     "$f" == hooks/* || "$f" == contexts/* || "$f" == types/* ]]
}

collect_changed_files() {
  {
    git diff --name-only
    git diff --name-only --cached
    git ls-files --others --exclude-standard
  } | sort -u
}

infer_commit_msg() {
  local files=("$@")
  if [[ ${#files[@]} -eq 0 ]]; then
    return 1
  fi

  local has_backend=0
  local has_frontend=0
  local has_docs=0
  local has_tests=0
  local has_tools=0
  local has_other=0

  local f
  for f in "${files[@]}"; do
    [[ -z "$f" ]] && continue
    if is_test_file "$f"; then
      has_tests=1
    fi

    if is_tool_file "$f"; then
      has_tools=1
      continue
    fi

    if is_doc_file "$f"; then
      has_docs=1
      continue
    fi

    if is_backend_file "$f"; then
      has_backend=1
      continue
    fi

    if is_frontend_file "$f"; then
      has_frontend=1
      continue
    fi

    has_other=1
  done

  local has_code=0
  if [[ $has_backend -eq 1 || $has_frontend -eq 1 || $has_other -eq 1 ]]; then
    has_code=1
  fi

  local type summary scope
  if [[ $has_code -eq 0 ]]; then
    if [[ $has_tests -eq 1 && $has_docs -eq 0 && $has_tools -eq 0 ]]; then
      type="test"
      summary="テストを更新"
    elif [[ $has_docs -eq 1 && $has_tests -eq 0 && $has_tools -eq 0 ]]; then
      type="docs"
      summary="ドキュメントを更新"
    elif [[ $has_tools -eq 1 && $has_tests -eq 0 && $has_docs -eq 0 ]]; then
      type="chore"
      summary="開発環境を更新"
    else
      type="chore"
      summary="開発周辺を更新"
    fi
  else
    type="feat"
    if [[ $has_frontend -eq 1 && $has_backend -eq 1 ]]; then
      summary="フロントエンドとバックエンドを更新"
    elif [[ $has_frontend -eq 1 ]]; then
      summary="フロントエンドを更新"
    elif [[ $has_backend -eq 1 ]]; then
      summary="バックエンドを更新"
    else
      summary="変更を反映"
    fi
  fi

  scope=""
  if [[ "$type" == "feat" ]]; then
    if [[ $has_backend -eq 1 && $has_frontend -eq 0 ]]; then
      scope="backend"
    elif [[ $has_frontend -eq 1 && $has_backend -eq 0 ]]; then
      scope="frontend"
    fi
  fi

  if [[ -n "$scope" ]]; then
    printf '%s\n' "${type}(${scope}): ${summary}"
  else
    printf '%s\n' "${type}: ${summary}"
  fi
}

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] main/master 上です。作業ブランチへ切り替えてください。"
  exit 1
fi

echo "[INFO] branch=$BRANCH"

git status -sb
git diff --name-only

if [[ -f .codex/skills/verify-full/scripts/verify-full.sh ]]; then
  bash .codex/skills/verify-full/scripts/verify-full.sh
else
  echo "[ERROR] verify-full script not found: .codex/skills/verify-full/scripts/verify-full.sh"
  exit 1
fi

git status -sb
git diff --stat

CHANGED_FILES="$(git status --porcelain | sed -E 's/^.. //; s/^R  .+ -> //')"
if [[ -z "$CHANGED_FILES" ]]; then
  echo "[ERROR] 変更がありません。commit は不要です。"
  exit 1
fi

echo "[INFO] changed files:"
echo "$CHANGED_FILES"

FORBIDDEN_RE='^(\.github/|\.coderabbit\.ya?ml$|package(-lock)?\.json$|pnpm-lock\.yaml$|yarn\.lock$|poetry\.lock$|pyproject\.toml$|requirements.*\.txt$|\.env)'

VIOLATION=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if echo "$f" | grep -Eq "$FORBIDDEN_RE"; then
    echo "[ERROR] 事前確認が必要な領域に変更があります: $f"
    VIOLATION=1
  fi
done <<<"$CHANGED_FILES"

if [[ "$VIOLATION" == "1" ]]; then
  echo "[ERROR] ガードレール違反のため停止します（commit/pushしません）。"
  echo "[HINT] 変更が意図通りか人間が確認し、方針確定後に再実行してください。"
  exit 1
fi

if [[ -z "${COMMIT_MSG:-}" ]]; then
  mapfile -t COMMIT_FILES < <(collect_changed_files)
  COMMIT_MSG="$(infer_commit_msg "${COMMIT_FILES[@]}")"
  if [[ -z "$COMMIT_MSG" ]]; then
    echo "[ERROR] COMMIT_MSG の自動生成に失敗しました。明示的に設定してください。"
    exit 1
  fi
  export COMMIT_MSG
  echo "[INFO] COMMIT_MSG を自動生成しました: $COMMIT_MSG"
else
  echo "[INFO] COMMIT_MSG=$COMMIT_MSG"
fi

git add -A
git diff --cached --name-only
git commit -m "$COMMIT_MSG"

PUSH="${PUSH:-1}"
REMOTE="${REMOTE:-origin}"

if [[ "$PUSH" == "1" ]]; then
  git push "$REMOTE" HEAD
  echo "[OK] push 完了: remote=$REMOTE"
else
  echo "[INFO] PUSH=0 のため push はスキップしました。"
fi
