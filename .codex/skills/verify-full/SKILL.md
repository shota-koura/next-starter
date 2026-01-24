---
name: verify-full
description: 'PR前/タスク完了前のフル検証を実行する（frontend: fix+format/lint/test / backend: ruff+pyright+pytest / 必要に応じてe2e）'
---

## 目的

- PR を提案する前、またはタスクを「完了」とする前に、CI 相当の検証を通す。
- 「ローカルでは大丈夫だった」を減らす（format/lint/type/test を一通り通す）。

## いつ使うか

- PR 作成前 / PR 更新前の最終確認
- CI 失敗を直した後の最終確認
- リファクタや依存更新など、回帰リスクがある変更を入れた後

## 前提

- このテンプレでは、Frontend のフル検証は以下を正とする:
  - `npm run fix`
  - `npm run format:check`
  - `npm run lint`
  - `npm run test:ci`
- Backend を変更した場合は、Backend のフル検証も実行する（Makefile があるなら Makefile 優先）。

## 1コマンド実行（推奨）

次を実行する。

```bash
bash .codex/skills/verify-full/scripts/verify-full.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/verify-full/scripts/verify-full.ps1
```

- スクリプトが本ファイルの手順をまとめて実行する。

## 環境変数（スクリプト用）

- `RUN_BACKEND`
  - `auto` / `1` / `0`（デフォルト `auto`）
  - `auto` の場合、`git diff --name-only` に `backend/` や `pyproject.toml` 等が含まれると Backend を実行する
- `RUN_E2E`
  - `1` の場合のみ `npm run e2e` を実行（デフォルト `0`）

## 手順

### 0) 状態確認（任意だが推奨）

```bash
git status -sb
git diff --name-only

```

### 1) Frontend（必須）

リポジトリ root で実行する。

```bash
npm run fix
npm run format:check
npm run lint
npm run test:ci

```

**補足:** `npm run fix` / `npm run format:check` などが依存不足で落ちる場合は、まず `npm install` を疑う。
**補足:** `next build` は CI で実行するため、ここでは実行しない。

### 2) Backend を変更した場合（必須）

**推奨:** Makefile がある場合（`backend/` で実行）

```bash
cd backend
make ruff-fix
make ruff-format
make pyright
make pytest

```

**フォールバック:** Makefile を使わない場合（venv 有効化前提）

```bash
cd backend
source .venv/bin/activate
ruff check --fix .
ruff format .
pyright
python -m pytest

```

**Backend の前提準備（未実施の場合）:**

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements-dev.txt

```

### 3) E2E（任意）

次のいずれかに該当する場合のみ、追加で実行してよい（CI必須ではない）:

- ルーティング/ナビゲーション/ページ遷移に影響する変更（例: `app/**/page.tsx`, `app/**/layout.tsx`, `app/**/route.ts`, `middleware.ts`）
- フロント⇄バックの接続導線や API 契約に影響する変更
- 認証/オンボーディング/決済など重要導線に影響する変更
- `e2e/` 配下の spec がカバーしている導線に影響する変更

実行:

```bash
npm run e2e

```

## 完了条件（この skill のゴール）

- Frontend: `npm run fix` / `npm run format:check` / `npm run lint` / `npm run test:ci` が成功している
- Backend を変更した場合: Backend のフル検証（ruff/pyright/pytest）が成功している
- 必要に応じて E2E も実行し、成功している
- PR 提案時に「実行したコマンド」を短く列挙できる
