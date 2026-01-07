# next-starter

Next.js (App Router) + TypeScript + Tailwind CSS のフロントエンドと、Python (FastAPI) のバックエンドを同一リポジトリで扱う開発スターターです。

目的は「保存時」「commit時」「CI」で自動整形・自動修正・静的チェック・テストが回り、AI駆動開発（Codex CLI / Cursor 等）でも品質が崩れにくい状態をテンプレとして使い回せるようにすることです。

加えて、任意で「PRレビュー自動化（CodeRabbit）」と「PRコメント駆動の自動レビュー/自動修正（Codex）」をテンプレの導線として用意します。

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
- Unit test: Jest + React Testing Library（最小サンプル付き）
- Cursor / VS Code 向けワークスペース設定（`.vscode/settings.json`）

### Backend (Python)

- FastAPI + Uvicorn
- Ruff（Formatter + Linter、自動修正対応）
- Pyright（型チェック）
- pytest（テスト。最小スモークテスト付き）

### E2E (Playwright)

- Playwright の最小 E2E テストを同梱
- E2E はテンプレに含めるが、CI の必須チェックにはしない（必要なときだけ `npm run e2e` で実行）

### Automation

- Husky + lint-staged（commit 前に、ステージ済みファイルへ自動整形/自動修正）
  - JS/TS: Prettier / ESLint
  - Python: Ruff（`ruff check --fix` と `ruff format`）
- GitHub Actions（CIで Frontend/Backend のチェックとテストを実行）
- ブランチ保護（Ruleset）で「CIが通らないと main にマージ不可」にできる
- （任意）CodeRabbit（GitHub App）
  - PR 作成時に自動でレビューが付く（挙動は `.coderabbit.yaml` で制御）
- （任意）Codex Code Review（GitHub の PR コメントで `@codex review`）
  - Codex 設定で対象リポジトリの Code review を ON にする必要あり
  - Codex は `AGENTS.md` の `Review guidelines` を参照してレビューする

## Requirements

- Node.js: 20.x 推奨
- npm: Node に同梱
- Python: 3.10 以上推奨
- （任意）Cursor / VS Code
- （任意）WSL (Ubuntu) 環境でも動作

AI PR レビュー機能を使う場合の前提:

- CodeRabbit: リポジトリに GitHub App をインストールできる権限（通常 admin）
- Codex: Codex を使えるプラン/権限 + GitHub 連携が可能であること

## Project Structure

```text
next-starter/
  app/                 # Next.js (App Router)
  components/          # UI コンポーネント置き場
    ui/                # shadcn/ui で生成されたコンポーネント
  lib/                 # 共通ユーティリティ
  __tests__/           # Frontend unit tests (Jest + RTL)
  e2e/                 # E2E tests (Playwright)
  playwright.config.ts # Playwright 設定
  jest.config.js       # Jest 設定
  jest.setup.ts        # Jest セットアップ
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
    rulesets/
      protect-main.json # Ruleset のエクスポート（Import 用）
  .coderabbit.yaml     # CodeRabbit 設定（任意機能。PRレビュー自動化）
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
- `check`: CI相当の検証（整形チェック / lint / unit test / build）
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

## Testing（テスト）

### Frontend unit tests（Jest + RTL）

- CIで実行されます（`npm run check` に含まれる前提）
- ローカルで実行する例:

```bash
npm run test:ci
```

テストは `__tests__/` 配下に置きます。

### Backend tests（pytest）

`backend/` を root として実行します。

```bash
cd backend
source .venv/bin/activate
python -m pytest
```

### E2E（Playwright）

E2E はローカル実行を基本にします（CI必須にはしません）。

```bash
npm run e2e
```

Playwright の成果物は `.gitignore` で除外します。

- `test-results/`
- `playwright-report/`

## Quality gates（自動化の考え方）

このテンプレは「3段階」で品質を担保します。

### 1) 保存時（Editor: Cursor / VS Code）

- Frontend:
  - 保存時に Prettier で整形
  - 保存時に ESLint の autofix が可能な範囲で自動修正
  - Tailwind class の順序は Prettier により自動で整う

- Backend:
  - 保存時に Ruff で整形 / 自動修正（設定が有効な場合）
  - 型や import の指摘は Pyright 相当で表示

重要:

- ターミナルで `source backend/.venv/bin/activate` は「CLIで使うPython」を切り替える操作です。
- エディタが参照するPythonは別なので、エディタ側の Interpreter も `./backend/.venv/bin/python` を選択するのが一般的です。

### 2) commit時（Husky + lint-staged）

`git commit` 時に `lint-staged` が動き、ステージ済みファイルに対して整形/自動修正をかけます。

- JS/TS: Prettier / ESLint
- Python: Ruff（ステージされた `*.py` に対して `ruff check --fix` と `ruff format`）

補足:

- commit 直前にファイルが書き換わることがあります。
- その場合は `git status` を確認し、必要なら `git add` してから commit してください。
- Python の自動修正は `backend/.venv` が前提です。未作成の場合は Backend setup を先に完了してください。

Codex CLI について:

- Codex CLI はエディタの保存時整形を使いません。
- その代わり、commit（Husky）と CI（GitHub Actions）が品質を担保します。
- 任意で、Codex CLI のローカルレビュー（`codex` -> `/review`）を併用できます。

### 3) CI（GitHub Actions）

`.github/workflows/ci.yml` で PR と main push をトリガーに `verify` を実行します。

- Frontend: format check / lint / unit test / build
- Backend: ruff（lint/format check）/ pyright / pytest

ブランチ保護（Ruleset）で `verify` を必須にすると、CIが通らない限り main にマージできません。

## Ruleset（ブランチ保護）を JSON で再利用する（個人アカウント向け）

GitHub のテンプレ機能は「リポジトリ内のファイル」はコピーできますが、`Settings` 側の設定（Ruleset など）は自動では複製されません。
個人アカウント運用で毎回の設定作業を減らすため、このテンプレでは Ruleset を JSON として同梱し、Import で再現する運用を推奨します。

このリポジトリには、Ruleset `protect-main` のエクスポートを次に格納しています。

- `.github/rulesets/protect-main.json`

### Import 手順（新しいリポジトリで毎回やる作業）

前提:

- 対象リポジトリの `Settings` を変更できる権限（通常 admin）が必要です。

手順:

1. 新しいリポジトリを開く
2. `Settings` を開く
3. 左メニューから `Rules` -> `Rulesets` を開く
4. `New ruleset` の右側にあるプルダウン（またはメニュー）から `Import a ruleset` を選ぶ
5. このテンプレに含まれる `.github/rulesets/protect-main.json` をアップロードする
   - ローカルに clone 済みなら、作業PC上のファイルをそのまま選択できます

6. 取り込み後、対象ブランチが `main` になっていること、`verify`（CI）が必須チェックとして設定されていることを確認する
7. いちど PR を作って CI が動くこと、CI が落ちたらマージできないことを確認する

### Export 手順（Ruleset を変更したときにテンプレ側へ反映する）

テンプレの Ruleset 設定を変更した場合は、エクスポートし直して JSON を差し替えるとテンプレの再現性が保てます。

手順:

1. このテンプレリポジトリを開く
2. `Settings` -> `Rules` -> `Rulesets` を開く
3. `protect-main` を開く
4. 画面右上のメニューから `Export` を実行して JSON をダウンロードする
5. ダウンロードした JSON を `.github/rulesets/protect-main.json` に置き換える
6. commit して main に入れる

### 注意点

- Ruleset 側で必須にするチェック名は、CI のチェック名と一致している必要があります。
  - このテンプレでは CI の必須チェックは基本 `verify` を想定しています。

- CI の job 名や workflow 構成を大きく変えた場合は、Ruleset も更新して Export し直す運用にしてください。

## AI PR レビュー自動化（CodeRabbit + Codex）

ここはテンプレ利用者が「同じ導線で再現」できるように、手順を明記します。

### 何を実現するか

- CodeRabbit:
  - PR を作ると自動でレビューが付く
  - 設定はリポジトリ直下の `.coderabbit.yaml` で制御

- Codex:
  - PR コメントで `@codex review` を投げると Codex が GitHub 上でコードレビューする
  - `@codex` に続けて指示を書くと、PR を文脈としてクラウドタスクを開始できる（例: `@codex fix the CI failures`）
  - Codex のレビュー方針は `AGENTS.md` の `Review guidelines` を参照する

### 1) `.coderabbit.yaml` を用意する（完了している前提）

- このテンプレには `.coderabbit.yaml` が含まれます
- もし別リポジトリに移植する場合は「リポジトリ直下」に配置してください
- 日本語レビューにしたい場合は `language: "ja-JP"` を設定します
- ノイズが出やすい生成物や lockfile は `path_filters` で除外する運用が一般的です

参考:

- CodeRabbit 設定リファレンス: [https://docs.coderabbit.ai/reference/configuration](https://docs.coderabbit.ai/reference/configuration)
- YAML validator: [https://docs.coderabbit.ai/reference/yaml-validator](https://docs.coderabbit.ai/reference/yaml-validator)

### 2) CodeRabbit GitHub App をリポジトリにインストールする（リポジトリ毎に必要）

手順（CodeRabbit 公式 Quickstart の流れに沿う）:

1. ブラウザで CodeRabbit にログインする
   - [https://app.coderabbit.ai](https://app.coderabbit.ai)

2. CodeRabbit のダッシュボードで `Add Repositories` を押す
3. GitHub の権限ダイアログで `Only select repositories` を選ぶ
4. 対象リポジトリを選択する
5. `Install & Authorize` を押して許可する

確認:

- PR を作ると、GitHub 上で CodeRabbit のレビュー（例: `@coderabbitai`）が付く

### 3) Codex を GitHub 連携して「Code review」を有効化する（リポジトリ毎に必要）

概要:

- Codex web で GitHub 連携を行う
- Codex settings で対象リポジトリの Code review を ON にする

手順:

1. Codex web を開く
   - [https://chatgpt.com/codex](https://chatgpt.com/codex)

2. GitHub アカウントを接続する（リポジトリが読める状態にする）
3. Codex settings を開き、対象リポジトリの `Code review` を ON にする
   - 参照: [https://developers.openai.com/codex/integrations/github/](https://developers.openai.com/codex/integrations/github/)

確認:

- PR のコメントで `@codex review` を投稿すると、Codex が GitHub の code review として返信する

### 4) PR を作って動作確認する（最短の確認手順）

1. ブランチを切って変更を入れる
2. PR を作る
3. CodeRabbit がレビューを付けることを確認する
4. PR コメントで `@codex review` を試す
5. 必要なら `@codex review for <focus>` で観点を絞る（例: `@codex review for security regressions`）

### 5) CodeRabbit 指摘/CI 失敗を Codex に直させる（手動トリガー）

Codex は PR コメントでクラウドタスクを開始できます（`review` 以外の指示を `@codex` に続けて書く）。

例:

- `@codex fix the CI failures`
- `@codex address CodeRabbit P0/P1 comments and make verify pass`

運用のコツ:

- 先に CI を通すこと（`verify`）を必須要件として書く
- 変更範囲を狭く書く（差分が最小になりやすい）

### 6) （任意）Ruleset で CodeRabbit を required checks に入れる

注意:

- GitHub の required checks の候補は「そのチェックが1回以上走っている」必要があります
- 候補に CodeRabbit が出ない場合は、先に PR を作って CodeRabbit を動かしてから設定してください

手順（GitHub UI）:

1. `Settings` -> `Rules` -> `Rulesets`
2. `protect-main`（または該当ルール）を開く
3. `Require status checks to pass` を有効化
4. `Status checks that are required` に CodeRabbit のチェックを追加する
5. `verify`（CI）と合わせて必須化する

### 7) （任意）CodeRabbit で commit status を有効にしておく

CodeRabbit 側は設定で commit status を出せます（デフォルト有効）。
`.coderabbit.yaml` で `reviews.commit_status` が有効になっているか確認してください。

## Codex Code Review（GitHubで `@codex review`）

- PR コメントで `@codex review` を投稿するとレビューが付く
- レビュー方針は `AGENTS.md` の `Review guidelines` を参照します
- `@codex review for <focus>` で観点指定ができます（例: security）

## Commands（Frontend）

```bash
npm run dev
npm run build
npm run lint
npm run lint:fix
npm run format
npm run format:check
npm run test:ci
npm run e2e
npm run fix
npm run check
```

## Commands（Backend）

`backend/` ディレクトリで実行します。

```bash
ruff format .
ruff check .
ruff check --fix .
pyright
python -m pytest
uvicorn app:app --reload --port 8000
```

## Troubleshooting

### `from fastapi import FastAPI` が黄色波線になる / import が解決されない

エディタが `backend/.venv` を使っていない可能性が高いです。Interpreter を `./backend/.venv/bin/python` に切り替えてください。

### pytest で `ModuleNotFoundError` が出る

`backend/` を root として実行する前提です。次で実行してください。

```bash
cd backend
source .venv/bin/activate
python -m pytest
```

### Python の pre-commit が失敗する

`.venv` が未作成、または依存未導入の可能性があります。Backend setup を先に完了してください。

### CodeRabbit が PR をレビューしない

- CodeRabbit GitHub App が対象リポジトリにインストールされているか確認してください
- `.coderabbit.yaml` がリポジトリ直下にあるか確認してください
- Draft PR を対象外にしている設定の場合、Ready for review にする必要があります

### GitHub の Ruleset で CodeRabbit の required check が候補に出ない

- そのチェックが1回以上実行されていない可能性があります
- 先に PR を作って CodeRabbit を動かしてから、Ruleset の required checks を設定してください

## Notes

- Prettier の対象外にしたいファイルがある場合は `.prettierignore` を編集してください。
- Python の依存は venv 前提です。`backend/.venv` はコミットしません。
- Playwright の成果物はコミットしません（`.gitignore` を参照）。
- AIエージェント運用（Codex CLI 等）向けのルールは `AGENTS.md` を参照してください。
