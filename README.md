# next-starter

Next.js (App Router) + TypeScript + Tailwind CSS のフロントエンドと、Python (FastAPI) のバックエンドを同一リポジトリで扱う開発スターターです。

目的は「保存時」「commit時」「CI」で自動整形・自動修正・静的チェックが回り、AI駆動開発（Codex CLI / Cursor 等）でも品質が崩れにくい状態をテンプレとして使い回せるようにすることです。

## Features

### Frontend (Next.js)

- Next.js (App Router) + TypeScript
- ESLint (Next.js core-web-vitals + TypeScript)
- Prettier（保存時フォーマット）
- prettier-plugin-tailwindcss（Tailwind class の自動並び替え）
- Cursor / VS Code 向けワークスペース設定（`.vscode/settings.json`）

### Backend (Python)

- FastAPI + Uvicorn
- Ruff（Formatter + Linter、自動修正対応）
- Pyright（型チェック）
- pytest（テスト）

### Automation

- Husky + lint-staged（commit 前に、ステージ済みファイルへ自動整形/自動修正）
  - JS/TS: Prettier / ESLint
  - Python: Ruff（`ruff check --fix` と `ruff format`）
- GitHub Actions（CIで Frontend/Backend のチェックを実行）
- ブランチ保護（Ruleset）で「CIが通らないと main にマージ不可」にできる

## Requirements

- Node.js: 20.x 推奨
- npm: Node に同梱
- Python: 3.10 以上推奨
- （任意）Cursor / VS Code
- （任意）WSL (Ubuntu) 環境でも動作

## Project Structure

このテンプレはフロントとバックエンドを同一リポジトリで管理します。

```text
next-starter/
  app/                 # Next.js (App Router)
  backend/             # Python (FastAPI + tooling)
    .venv/             # venv (gitignore)
    pyproject.toml     # ruff 設定
    pyrightconfig.json # pyright 設定
    requirements.txt
    requirements-dev.txt
    app.py
    tests/
      test_smoke.py
  .vscode/
    settings.json
  .github/
    workflows/ci.yml
  package.json
  AGENTS.md
  README.md
```

## Create a new project from this template

`create-next-app --example` で、このリポジトリを雛形として新規プロジェクトを作成できます。

```bash
npx create-next-app@latest my-app --example "https://github.com/shota-koura/next-starter"
cd my-app
```

注意: `--example` は作成時にテンプレをコピーするだけです。テンプレ側の更新は既存プロジェクトへ自動追従しません。

## Recommended first run

最初に Frontend（Node）と Backend（Python）の両方をセットアップします。

### 1) Frontend setup

```bash
npm install
npm run format
npm run check
npm run dev
```

- `format`: Prettier 実行（Tailwind class 並び替えもここで適用）
- `check`: CI相当の検証（`format:check` / `lint` / `build` など。内容は `package.json` を参照）
- `dev`: 開発サーバ起動（通常 `http://localhost:3000`）

### 2) Backend setup

バックエンドは `backend/` 直下で venv を作り、依存関係を入れます。

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate

pip install -U pip
pip install -r requirements-dev.txt
```

初回セットアップ後、以下でチェックが通ればOKです。

```bash
ruff check --fix .
ruff format .
pyright
python -m pytest
```

### 3) Backend run (FastAPI)

```bash
cd backend
source .venv/bin/activate
uvicorn app:app --reload --port 8000
```

ヘルスチェック例:

- `GET http://localhost:8000/health`

## Quality gates（自動化の考え方）

このテンプレは「3段階」で品質を担保します。

### 1) 保存時（Editor: Cursor / VS Code）

- Frontend:
  - 保存時に Prettier で整形
  - 保存時に ESLint の autofix が可能な範囲で自動修正
  - Tailwind class の順序は Prettier により自動で整う

- Backend:
  - 保存時に Ruff で整形 / 自動修正（設定が有効な場合）
  - 型や import の指摘は Pyright 相当（Cursor では Cursor Pyright 等）で表示

重要:

- ターミナルで `source backend/.venv/bin/activate` するのは「CLIで使うPython」を切り替える操作です。
- エディタが参照するPythonは別なので、エディタ側でも `./backend/.venv/bin/python` を選択するのが一般的です。

### 2) commit時（Husky + lint-staged）

`git commit` 時に `lint-staged` が動き、ステージ済みファイルに対して整形/自動修正をかけます。

- JS/TS: Prettier / ESLint
- Python: Ruff（`ruff check --fix` / `ruff format`）

補足:

- commit 直前にファイルが書き換わることがあります（自動修正による差分）。
- その場合は `git status` を確認し、必要なら `git add` してから commit してください。

Codex CLI について:

- Codex CLI はエディタの「保存時整形」を使いません。
- その代わり、commit（Husky）と CI（GitHub Actions）が常に品質を担保します。
- タスク完了前は、ローカルでも `npm run check` と Backend のチェックを通す運用が安定します。

### 3) CI（GitHub Actions）

`.github/workflows/ci.yml` で PR と main push をトリガーに `verify` を実行します。

- Frontend: `npm ci` → `format:check` → `lint` → `build`
- Backend: Ruff / Pyright / pytest

ブランチ保護（Ruleset）で `verify` を必須にすると、CIが通らない限り main にマージできません。

## Cursor / VS Code extensions（推奨）

- ESLint
- Prettier - Code formatter
- Tailwind CSS IntelliSense
- Python（`ms-python.python`）
- Ruff（`charliermarsh.ruff`）
- （推奨）型チェック拡張（環境により異なる）
  - VS Code: Pylance
  - Cursor: Cursor Pyright 等（同等機能）

## Verify Tailwind class sorting

`app/page.tsx` の `className="..."` の順序を崩してから、次を実行してください。
class の順序が自動的に整えば有効です。

```bash
npx prettier --write app/page.tsx
```

## Commands（Frontend）

主要コマンド（詳細は `package.json` を参照）

```bash
npm run dev           # start dev server
npm run build         # next build
npm run lint          # run eslint
npm run lint:fix      # eslint --fix
npm run format        # prettier --write .
npm run format:check  # prettier --check .
npm run fix           # format + eslint fix
npm run check         # CI-style checks (format:check + lint + build)
```

## Commands（Backend）

`backend/` ディレクトリで実行します。

```bash
ruff format .         # formatter
ruff check .          # lint
ruff check --fix .    # lint + autofix
pyright               # type check
python -m pytest      # test
uvicorn app:app --reload --port 8000  # run server
```

（任意）backend/Makefile がある場合は、まとめコマンドとして使えます。

```bash
cd backend
make fix
make check
```

## Troubleshooting

### `from fastapi import FastAPI` が黄色波線になる / import が解決されない

エディタが `backend/.venv` を使っていない可能性が高いです。エディタ側の Interpreter を `./backend/.venv/bin/python` に切り替えてください。

### pytest で `ModuleNotFoundError` が出る

`backend/` を root として実行する前提の構成です。以下の形で実行してください。

```bash
cd backend
source .venv/bin/activate
python -m pytest
```

### Python の pre-commit が失敗する

`.venv` が未作成、または依存未導入の可能性があります。Backend setup を先に完了してください。

## Notes

- Prettier の対象外にしたいファイルがある場合は `.prettierignore` を編集してください。
- Python の依存は venv 前提です。`backend/.venv` はコミットしません。
- AIエージェント運用（Codex CLI 等）向けのルールは `AGENTS.md` を参照してください。
