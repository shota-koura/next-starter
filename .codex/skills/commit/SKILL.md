---
name: commit
description: verify-full 実行後にガードレール検査を行い、COMMIT_MSG を自動生成または指定して git add / git commit / git push を行う
---

## 目的

- commit 時点で CI 相当の検証を通し、後段（PR/CI）での手戻りを減らす。
- 事前確認が必要な領域の変更を機械的に検知し、意図しない commit/push を防ぐ。
- commit メッセージは `COMMIT_MSG` 未設定時に差分から自動生成する。
- 必要なら push まで行い、次工程（`$pr-flow`）へつなぐ。

## いつ使うか

- `$precommit` を完了した後、commit を作るタイミング。
- PR 提案前の commit を固めるタイミング。

## 前提

- 直前に `$precommit` を実施していること（整形・tree 更新が完了していること）。
- 作業ブランチ上であること。

## 環境変数

- `COMMIT_MSG`（任意）
  - commit メッセージ本文。未設定なら差分から自動生成する。
  - 例: `feat(frontend): タスク作成フォームを追加`
- `PUSH`（任意）
  - `1` なら push する（デフォルト `1`）。
  - `0` なら push しない（commit のみ）。
- `REMOTE`（任意）
  - push 先の remote 名（デフォルト `origin`）。

## 自動生成ルール（概要）

- 変更ファイルは次を統合して判定する:
  - `git diff --name-only`
  - `git diff --name-only --cached`
  - `git ls-files --others --exclude-standard`
- 種別の推定:
  - コード変更（frontend/backend/その他）が含まれる: `feat`
  - 非コードのみ:
    - docs のみ: `docs`
    - tests のみ: `test`
    - tooling のみ: `chore`
    - 上記が混在: `chore`
- scope の推定（`feat` のみ）:
  - backend のみ: `backend`
  - frontend のみ: `frontend`
  - 混在: 省略
- 要約テンプレート:
  - `docs`: `ドキュメントを更新`
  - `test`: `テストを更新`
  - `chore`: `開発環境を更新`（混在時は `開発周辺を更新`）
  - `feat`: `フロントエンドを更新` / `バックエンドを更新` / `フロントエンドとバックエンドを更新` / `変更を反映`

## 1コマンド実行（推奨）

次を実行する。

```bash
bash .codex/skills/commit/scripts/commit.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/commit/scripts/commit.ps1
```

- スクリプト内で `verify-full` を実行する（`verify-full` のスクリプトが必要）。

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

### 0) 事前チェック（ブランチ）

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] main/master 上です。作業ブランチへ切り替えてください。"
  exit 1
fi

echo "[INFO] branch=$BRANCH"
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

### 5) COMMIT_MSG 自動生成（未設定時）

- `COMMIT_MSG` が未設定なら、自動生成して使用する。
- 生成結果はログに表示される。必要なら `COMMIT_MSG` を明示設定して再実行する。

### 6) ステージング

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

### 7) commit

```bash
git commit -m "$COMMIT_MSG"
```

### 8) push（デフォルトで実行）

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

### 9) 次の行動（任意）

- push 済みで PR を作成・更新する場合は `$pr-flow` を使う。
- PR 前のドキュメント整合が必要な場合は `$document-update` を先に実行してから `$pr-flow` に進む（AGENTS.md を参照）。

## 完了条件

- `$verify-full` が成功している。
- ガードレールに抵触する変更が含まれていない。
- `git commit` が成功している。
- `PUSH=1` の場合、`git push` が成功している。
