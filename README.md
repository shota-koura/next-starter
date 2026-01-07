# next-starter

Next.js (App Router) + TypeScript + Tailwind CSS のフロントエンドと、Python (FastAPI) のバックエンドを同一リポジトリで扱う開発スターターです。

目的は「保存時」「commit時」「CI」で自動整形・自動修正・静的チェックが回り、AI駆動開発（Codex CLI / Cursor 等）でも品質が崩れにくい状態をテンプレとして使い回せるようにすることです。

## Features

### Frontend (Next.js)

- Next.js (App Router) + TypeScript
- ESLint (Next.js core-web-vitals + TypeScript)
- Prettier（保存時フォーマット）
- prettier-plugin-tailwindcss（Tailwind class の自動並び替え）
- shadcn/ui（必要な UI コンポーネントだけ生成して使う方式）
  - style: `new-york`
  - baseColor: `zinc`
  - CSS variables: 有効（`cssVariables: true`）
  - RSC: 有効（`rsc: true`）
  - icon library: `lucide`（`lucide-react`）
  - Tailwind CSS の取り込み先: `app/globals.css`
  - import alias:
    - `@/components`
    - `@/components/ui`
    - `@/lib`
    - `@/lib/utils`
    - `@/hooks`
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
- （任意）Codex Code Review（GitHub の PR コメントで `@codex review`）

## Requirements

- Node.js: 20.x 推奨
- npm: Node に同梱
- Python: 3.10 以上推奨
- （任意）Cursor / VS Code
- （任意）WSL (Ubuntu) 環境でも動作

## Project Structure

```text
next-starter/
  app/                 # Next.js (App Router)
  components/          # UI コンポーネント置き場
    ui/                # shadcn/ui で生成されたコンポーネント（例: button, dialog, card など）
  lib/                 # 共通ユーティリティ（例: lib/utils.ts の cn など）
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
  components.json      # shadcn/ui の設定
  package.json
  AGENTS.md
  README.md
```

## Quick Start（最短で動かす）

### Frontend

```bash
npm install
npm run dev
```

- 開発サーバ: `http://localhost:3000`

### Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements-dev.txt
uvicorn app:app --reload --port 8000
```

- ヘルスチェック例: `GET http://localhost:8000/health`

## Recommended first run（初回セットアップの推奨手順）

### 1) Frontend setup

```bash
npm install
npm run format
npm run check
npm run dev
```

- `format`: Prettier 実行（Tailwind class 並び替えもここで適用）
- `check`: CI相当の検証（`format:check` / `lint` / `build` 等）
- `dev`: 開発サーバ起動

### 2) Backend setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate

pip install -U pip
pip install -r requirements-dev.txt
```

初回セットアップ後、以下が通ればOKです。

```bash
ruff check --fix .
ruff format .
pyright
python -m pytest
```

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

- ターミナルで `source backend/.venv/bin/activate` は「CLIで使うPython」を切り替える操作です。
- エディタが参照するPythonは別なので、エディタ側の Interpreter も `./backend/.venv/bin/python` を選ぶのが一般的です。

### 2) commit時（Husky + lint-staged）

`git commit` 時に `lint-staged` が動き、ステージ済みファイルに対して整形/自動修正をかけます。

- JS/TS: Prettier / ESLint
- Python: Ruff（ステージされた `*.py` に対して `ruff check --fix` と `ruff format`）

補足:

- commit 直前にファイルが書き換わることがあります（自動修正による差分）。
- その場合は `git status` を確認し、必要なら `git add` してから commit してください。
- Python の pre-commit は `backend/.venv` が前提です。未作成の場合は Backend setup を先に完了してください。

Codex CLI について:

- Codex CLI はエディタの「保存時整形」を使いません。
- その代わり、commit（Husky）と CI（GitHub Actions）が品質を担保します。

### 3) CI（GitHub Actions）

`.github/workflows/ci.yml` で PR と main push をトリガーに `verify` を実行します（CIが落ちたらマージできない運用が可能）。

## Codex Code Review（GitHubで `@codex review`）

Codex cloud 側で対象リポジトリの Code review をオンにすると、Pull Request のコメントで `@codex review` を書いてレビューを呼び出せます。([OpenAI Developers][1])

### 使い方（最小）

1. GitHub で PR を開く
2. PR のコメント欄（Conversation）に次を書いて投稿する

```text
@codex review
```

観点指定もできます。([OpenAI Developers][1])

```text
@codex review for security regressions
```

CIが落ちているPRでもコメントは書けるため、レビュー依頼は可能です（レビューはCI成功が前提ではありません）。

### どんなルールでレビューされるか

Codex はリポジトリ内の `AGENTS.md` を探索し、そこに書かれた `## Review guidelines` に従ってレビューします。さらに、変更ファイルに最も近い階層の `AGENTS.md` を優先します。([OpenAI Developers][1])

このテンプレでは、`AGENTS.md` に

- PII/秘密情報をログに出さない
- 無関係差分を避ける
- CIで落ちる変更を避ける
- shadcn/ui 優先
  などの指針を置いています。

## shadcn/ui（このリポジトリの実態に合わせた説明）

### 設定（components.json）

このリポジトリの shadcn/ui は `components.json` で次の設定になっています。

- style: `new-york`
- RSC: `true`
- TSX: `true`
- Tailwind:
  - css: `app/globals.css`
  - baseColor: `zinc`
  - cssVariables: `true`
  - prefix: `""`（なし）
  - config: `""`（未指定）

- iconLibrary: `lucide`
- aliases:
  - `components`: `@/components`
  - `ui`: `@/components/ui`
  - `utils`: `@/lib/utils`
  - `lib`: `@/lib`
  - `hooks`: `@/hooks`

### 生成済み UI コンポーネント（components/ui）

現状 `components/ui` には少なくとも次が入っている前提です（export 名ベース）。

- `Button`
- `Card`（`CardHeader` / `CardContent` / `CardFooter` 等を含む）
- `Dialog`（`DialogTrigger` / `DialogContent` / `DialogTitle` 等を含む）
- `Input`
- `Label`
- `Textarea`
- `Toaster`（Sonner ベース。`next-themes` の theme に追従）

### 追加でコンポーネントを入れる

必要な UI だけ追加する運用です。

例:

```bash
npx shadcn@latest add dropdown-menu tabs
```

追加されたコンポーネントは `components/ui/` 配下に生成され、import は `@/components/ui/*` を使います。

### Toaster（Sonner）

通知を出す側は `sonner` の API を使います。

```ts
import { toast } from 'sonner';

toast('Hello');
toast.success('Saved');
toast.error('Failed');
```

## Commands（Frontend）

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
