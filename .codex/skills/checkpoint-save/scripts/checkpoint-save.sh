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
     "$f" == poetry.lock || "$f" == pyproject.toml || \
     "$f" == requirements*.txt || "$f" == backend/requirements*.txt || \
     "$f" == .env* || "$f" == */.env || "$f" == */.env.* || \
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
  } | sed '/^$/d' | sort -u
}

is_allowed_guarded_file() {
  local target="$1"
  [[ -z "${ALLOW_GUARDED_FILES:-}" ]] && return 1
  local normalized=",${ALLOW_GUARDED_FILES// /},"
  [[ "$normalized" == *",$target,"* ]]
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
      summary="テストの途中経過を保存"
    elif [[ $has_docs -eq 1 && $has_tests -eq 0 && $has_tools -eq 0 ]]; then
      type="docs"
      summary="ドキュメントの途中経過を保存"
    elif [[ $has_tools -eq 1 && $has_tests -eq 0 && $has_docs -eq 0 ]]; then
      type="chore"
      summary="開発周辺の途中経過を保存"
    else
      type="chore"
      summary="作業途中の変更を保存"
    fi
  else
    type="feat"
    if [[ $has_frontend -eq 1 && $has_backend -eq 1 ]]; then
      summary="フロントエンドとバックエンドの途中経過を保存"
    elif [[ $has_frontend -eq 1 ]]; then
      summary="フロントエンドの途中経過を保存"
    elif [[ $has_backend -eq 1 ]]; then
      summary="バックエンドの途中経過を保存"
    else
      summary="実装途中の変更を保存"
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
if [[ "$BRANCH" == "HEAD" ]]; then
  echo "[ERROR] detached HEAD 上です。checkpoint-save は作業ブランチで使ってください。"
  exit 1
fi

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] main/master 上です。checkpoint-save は作業ブランチで使ってください。"
  exit 1
fi

echo "[INFO] branch=$BRANCH"
git status -sb

mapfile -t CHANGED_FILES_ARR < <(collect_changed_files)
if [[ ${#CHANGED_FILES_ARR[@]} -eq 0 ]]; then
  echo "[ERROR] 変更がありません。checkpoint は不要です。"
  exit 1
fi

printf '%s\n' "${CHANGED_FILES_ARR[@]}"

if [[ -f .codex/skills/verify-fast/scripts/verify-fast.sh ]]; then
  bash .codex/skills/verify-fast/scripts/verify-fast.sh
else
  echo "[ERROR] verify-fast script not found: .codex/skills/verify-fast/scripts/verify-fast.sh"
  exit 1
fi

git status -sb
git diff --stat

FORBIDDEN_RE='^(\.github/|\.codex/agents/|\.codex/skills/|AGENTS\.md$|\.coderabbit\.ya?ml$|package(-lock)?\.json$|pnpm-lock\.yaml$|yarn\.lock$|poetry\.lock$|pyproject\.toml$|requirements.*\.txt$|backend/requirements.*\.txt$|(.*/)?\.env($|\.))'
VIOLATION=0
for f in "${CHANGED_FILES_ARR[@]}"; do
  if echo "$f" | grep -Eq "$FORBIDDEN_RE"; then
    if is_allowed_guarded_file "$f"; then
      echo "[WARN] 明示承認済みの guarded file を許可します: $f"
      continue
    fi
    echo "[ERROR] checkpoint-save では人間確認が必要な変更です: $f"
    VIOLATION=1
  fi
done

if [[ "$VIOLATION" == "1" ]]; then
  echo "[ERROR] ガードレール違反のため停止します（commit/push しません）。"
  echo "[HINT] guarded file を含む変更は通常の最終フローまたは人間確認後に扱ってください。"
  exit 1
fi

if [[ -z "${COMMIT_MSG:-}" ]]; then
  COMMIT_MSG="$(infer_commit_msg "${CHANGED_FILES_ARR[@]}")"
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
