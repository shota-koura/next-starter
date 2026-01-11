---
name: verify-fast
description: 開発ループ中の速い検証を、変更範囲に応じて実行する（frontend/backend）
---

## 目的

- 開発ループ中に素早く「明らかな失敗」を潰す。
- 完了前は別skill `$verify-full` を使う。

## いつ使うか

- 小さな変更を入れた直後。
- commit 前の確認（ただし commit 前の整形は `npm run precommit` が正）。

## 手順（推奨）

### 0) 変更範囲を把握

```bash
git status -sb
git diff --name-only

```

### 1) Frontend を触った場合（例: `app/`, `components/`, `lib/`, `__tests__/`, `e2e/` など）

```bash
npm run format:check
npm run lint
# UI/ロジック/テストを触った場合のみ
npm run test:ci

```

### 2) Backend を触った場合（例: `backend/` 配下の `.py`, `pyproject.toml` など）

Makefile があるならそれを優先:

```bash
cd backend
make ruff-format-check
make ruff-check
# API/ロジックを触った場合のみ
make pytest

```

Makefile を使わない場合（venv 有効化前提）:

```bash
cd backend
source .venv/bin/activate
ruff format --check .
ruff check .
# API/ロジックを触った場合のみ
python -m pytest

```

## 注意

- ここで通っても、完了前は必ず `$verify-full` を実行する。
- 依存未導入の失敗が出た場合は、まず `npm install` / `backend/.venv` 作成を疑う。
