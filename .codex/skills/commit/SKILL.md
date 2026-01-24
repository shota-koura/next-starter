---
name: commit
description: verify-full 実行後にガードレール検査を行い、COMMIT_MSG を用いて git add / git commit / git push を行う
---

## 目的

- commit 時点で CI 相当の検証を通し、後段（PR/CI）での手戻りを減らす。
- 事前確認が必要な領域の変更を機械的に検知し、意図しない commit/push を防ぐ。
- commit メッセージを運用で統一する（`COMMIT_MSG` 必須）。
- 必要なら push まで行い、次工程（`$pr-flow`）へつなぐ。

## いつ使うか

- `$precommit` を完了した後、commit を作るタイミング。
- PR 提案前の commit を固めるタイミング。

## 前提

- 直前に `$precommit` を実施していること（整形・`codex /review`・tree 更新が完了していること）。
- 作業ブランチ上であること。
- `COMMIT_MSG` を設定していること。

## 環境変数

- `COMMIT_MSG`（必須）
  - commit メッセージ本文。
  - 例: `feat(frontend): タスク作成フォームを追加`
- `PUSH`（任意）
  - `1` なら push する（デフォルト `1`）。
  - `0` なら push しない（commit のみ）。
- `REMOTE`（任意）
  - push 先の remote 名（デフォルト `origin`）。

## ガードレール（必須）

以下に該当するファイル/領域に変更が入っている場合、この skill は停止する（commit/push しない）。

- `.github/` 配下（特に `.github/workflows/`）
- `.coderabbit.yaml` / `.coderabbit.yml`
- 依存管理ファイル/ロックファイル
  - `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`
  - `pyproject.toml`, `poetry.lock`, `requirements*.txt`
- `.env*` など環境変数ファイル

停止した場合は、変更内容が意図通りかを人間が確認し、必要なら方針確定後に再実行する。

## 手順

### 0) 事前チェック（ブランチと COMMIT_MSG）

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] main/master 上です。作業ブランチへ切り替えてください。"
  exit 1
fi

if [[ -z "${COMMIT_MSG:-}" ]]; then
  echo "[ERROR] COMMIT_MSG が未設定です。例:"
  echo "  export COMMIT_MSG='feat(frontend): タスク作成フォームを追加'"
  exit 1
fi

echo "[INFO] branch=$BRANCH"
echo "[INFO] COMMIT_MSG=$COMMIT_MSG"
```

### 1) 状態確認

```bash
git status -sb
git diff --name-only
```

- 想定外のファイルが混ざっていないか確認する。
- 秘密情報が差分に入っていないことを確認する。

### 2) フル検証の実行（必須）

`verify-full` を実行する。

```text
$verify-full
```

- `verify-full` は fix/format を含むため、実行後に差分が増える場合がある。
- 失敗した場合は修正し、成功するまで再実行する。

### 3) 検証後の差分確認

```bash
git status -sb
git diff --stat
```

- `verify-full` により生成/更新されたファイルも含めて、差分が意図通りか確認する。

### 4) ガードレール検査（事前確認が必要な変更の検知）

```bash
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
```

### 5) ステージング

原則として「この commit に含めるべきものだけ」を stage する。

全投入する場合:

```bash
git add -A
```

内容を確認しながら行う場合:

```bash
git add -p
```

ステージ内容の確認:

```bash
git diff --cached
```

### 6) commit

```bash
git commit -m "$COMMIT_MSG"
```

### 7) push（デフォルトで実行）

```bash
PUSH="${PUSH:-1}"
REMOTE="${REMOTE:-origin}"

if [[ "$PUSH" == "1" ]]; then
  git push "$REMOTE" HEAD
  echo "[OK] push 完了: remote=$REMOTE"
else
  echo "[INFO] PUSH=0 のため push はスキップしました。"
fi
```

### 8) 次の行動（任意）

- push 済みで PR を作成・更新する場合は `$pr-flow` を使う。
- PR 前のドキュメント整合が必要な場合は `$document-update` を先に実行してから `$pr-flow` に進む（AGENTS.md を参照）。

## 完了条件

- `$verify-full` が成功している。
- ガードレールに抵触する変更が含まれていない。
- `git commit` が成功している。
- `PUSH=1` の場合、`git push` が成功している。
