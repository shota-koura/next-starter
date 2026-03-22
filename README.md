# next-starter

Next.js (App Router) + TypeScript + Tailwind CSS のフロントエンドと、Python (FastAPI) のバックエンドを同一リポジトリで扱う開発スターターです。

目的は「保存時」「commit時」「CI」で自動整形・自動修正・静的チェック・テストが回り、AI駆動開発（Codex CLI / Cursor 等）でも品質が崩れにくい状態をテンプレとして使い回せるようにすることです。

加えて、任意で「CodeRabbit CLI による pre-review」と「PR コメント駆動の自動レビュー/自動修正（Codex）」をテンプレの導線として用意します。

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
- （任意）CodeRabbit CLI
  - `precommit` 後、`commit` 前のローカル差分を pre-review する
  - 既定では GitHub PR 自動レビューではなく CLI pre-review を主に使う
- （任意）Codex Code Review fallback（GitHub の PR コメントで `@codex review`）
  - 既定運用はローカルの `change-review`
  - 必要なときだけ GitHub 上の fallback として使う
- Codex skills（`.codex/skills/`）
  - PR/CI/レビュー運用や検証コマンドを、Codex CLI の skills として定型化（`$pr-flow` など）
  - 詳細は後述の「Codex skills（.codex/skills）」参照

## Requirements

- Node.js: 20.x 推奨
- npm: Node に同梱
- Python: 3.10 以上推奨
- GitHub CLI: `gh`（PR/CI 運用や skills の実行に必要）
- （推奨）ripgrep: `rg`（`$dedupe` skill の既存実装検索に使用）
- （任意）Cursor / VS Code
- （任意）WSL (Ubuntu) 環境でも動作

AI レビュー機能を使う場合の前提:

- CodeRabbit CLI: ローカルで `coderabbit` が使え、`coderabbit auth login` 済みであること
- Codex: Codex を使えるプラン/権限があること

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
  .codex/
    skills/            # Codex skills（PR/CI運用などの手順を定型化）
  .coderabbit.yaml     # CodeRabbit 設定（任意機能。CLI pre-review 用）
  components.json      # shadcn/ui の設定
  package.json
  AGENTS.md
  README.md
```

## Codex skills（.codex/skills）

このテンプレは、Codex CLI の skills（`.codex/skills/<skill-name>/SKILL.md`）を同梱しています。

- `AGENTS.md` は「方針（常時適用）」を主に扱い、長い運用手順は skills に分離しています。
- skills は Codex CLI セッション内で `$<skill-name>` と入力して呼び出す想定です（例: `$pr-flow`）。
- 自分の運用に合わせて、`.codex/skills/**/SKILL.md` を編集してカスタマイズできます。

### 同梱 skills 一覧

#### PR / CI / レビュー運用

- `$pr-flow`
  - `document-update`、`precommit`、`coderabbit-pre-review`、`change-review`、`commit`、`pr-review-merge` を順に使い、PR 提案からマージまでの入口をまとめる
  - `change-review` が reviewer sub-agent 必須のため、reviewer を使えるセッションを前提にする
- `$coderabbit-pre-review`
  - CodeRabbit CLI で `precommit` 後・`commit` 前のローカル差分を事前レビューし、P0/P1/P2 相当で整理する
- `$change-review`
  - ローカル差分を reviewer sub-agent で事前レビューし、親エージェントが CodeRabbit と同じ形式で結果を整理する
- `$pr-review-merge`
  - push 後の PR 作成/表示、CI 監視、マージまでを定型化

#### 重複抑止（既存探索）

- `$dedupe`
  - `rg` で既存実装を横断検索し、追記/統合の候補を提示する（util/型/スキーマの増殖を防ぐ）

#### 検証コマンド（開発ループ / 完了前）

- `$verify-fast`
  - 開発ループ中の速い検証（変更範囲に応じた最小セット）
- `$verify-full`
  - PR 前 / タスク完了前のフル検証（CI 相当の検証セット。frontend: `npm run fix` + `npm run check`、backend 変更時: ruff/pyright/pytest、必要に応じて E2E）

#### ブランチ運用

- `$branch-create`
  - 新しい作業を開始する際のブランチ作成を定型化（git alias 優先、無ければフォールバック手順）

#### MCP 連携（任意・環境依存）

以下は、MCP（Model Context Protocol）で対応ツールが有効化されている前提の補助 skill です。
テンプレ利用者が MCP を使わない場合でも、削除せずに「未使用で問題ない」想定です。

- `$mcp-playwright-debug`（UI 再現/スクショ/ログ収集）
  - UI の再現、スクリーンショット、console/network 要点を収集して原因切り分けに使う
- `$mcp-serena-refactor`（安全なリファクタ）
  - シンボル参照を追跡しながら rename/置換を行い、検索置換の事故を避ける
- `$mcp-chrome-devtools-perf`（パフォーマンス計測）
  - trace/insight でパフォーマンス課題を根拠づけ、改善ポイントを特定する

#### 補助 CLI（任意）

- `$coderabbit-pre-review`
  - CodeRabbit CLI を使って `precommit` 後・`commit` 前のローカル差分を review する
- `$change-review`
  - ローカル差分を reviewer sub-agent で review し、親エージェントが CodeRabbit と同じ形式で結果を整理する
- `$supabase-cli-workflow`
  - Supabase CLI を使って local 開発、link、migration、型生成の流れを整理する
- `$vercel-cli-workflow`
  - Vercel CLI を使って project link、env pull、deploy / inspect の流れを整理する

注意:

- MCP 設定には API key 等の秘密情報が含まれる場合があります。ログや README、PR本文に貼らないでください。

### よく使う呼び出し例

- 新しい util/型/スキーマを追加する前に既存探索する: `$dedupe`
- PR 提案からマージまでの入口として回す: `$pr-flow`
- commit 前に CodeRabbit CLI の pre-review を行う: `$coderabbit-pre-review`
- commit 前に Codex 観点のローカル review を行う: `$change-review`
- push 後の PR/CI/マージ収束だけを回す: `$pr-review-merge`
- 開発ループ中にサクッと検証する: `$verify-fast`
- PR 前 / 完了前にフル検証する: `$verify-full`

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

## Git運用（ブランチ作成ショートカット: git alias）

新しい作業は「1ブランチ=1PR」を基本とし、ブランチ作成時に main を最新化してから切る運用を推奨します。
WSL(Ubuntu) などのターミナルで、以下の git alias を 1 回だけ設定してください（PC/環境ごとの設定です）。

```bash
git config --global alias.feat  '!f(){ set -e; test -z "$(git status --porcelain)" || { echo "ERROR: working tree is not clean"; exit 1; }; git switch main; git pull --ff-only; git switch -c "feat/$1"; }; f'
git config --global alias.fix   '!f(){ set -e; test -z "$(git status --porcelain)" || { echo "ERROR: working tree is not clean"; exit 1; }; git switch main; git pull --ff-only; git switch -c "fix/$1"; }; f'
git config --global alias.docs  '!f(){ set -e; test -z "$(git status --porcelain)" || { echo "ERROR: working tree is not clean"; exit 1; }; git switch main; git pull --ff-only; git switch -c "docs/$1"; }; f'
git config --global alias.chore '!f(){ set -e; test -z "$(git status --porcelain)" || { echo "ERROR: working tree is not clean"; exit 1; }; git switch main; git pull --ff-only; git switch -c "chore/$1"; }; f'
```

使い方（例）:

```bash
git feat agents-gh-flow
git fix ci-format
git docs readme-update
git chore vscode-settings
```

注意:

- working tree に未コミット変更があると停止します（安全のため）。
- default branch が `main` でない場合は、この alias はそのままでは動きません。

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
- また、このテンプレは Codex skills（`.codex/skills`）を同梱しており、PR/CI運用や検証手順を `$pr-flow` などで呼び出せます（詳細は「Codex skills（.codex/skills）」参照）。

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

## AI レビュー運用（CodeRabbit CLI + Codex reviewer）

ここはテンプレ利用者が「同じ導線で再現」できるように、手順を明記します。

### 何を実現するか

- CodeRabbit:
  - ローカル差分を CLI で pre-review する
  - 既定では PR 自動レビューではなく、`coderabbit-pre-review` で左シフトする

- Codex:
  - 既定では `change-review` で reviewer sub-agent を使ってローカル差分を review する
  - 親エージェントが reviewer の結果を回収し、CodeRabbit と同じ形式に揃えて提示する
  - そのため、標準の `pr-flow` は reviewer を使えるセッションを前提にする
  - GitHub 上の `@codex review` は manual fallback としてのみ使う

### 1) `.coderabbit.yaml` を用意する（完了している前提）

- このテンプレには `.coderabbit.yaml` が含まれます
- もし別リポジトリに移植する場合は「リポジトリ直下」に配置してください
- 日本語レビューにしたい場合は `language: "ja-JP"` を設定します
- ノイズが出やすい生成物や lockfile は `path_filters` で除外する運用が一般的です

参考:

- CodeRabbit 設定リファレンス: [https://docs.coderabbit.ai/reference/configuration](https://docs.coderabbit.ai/reference/configuration)
- YAML validator: [https://docs.coderabbit.ai/reference/yaml-validator](https://docs.coderabbit.ai/reference/yaml-validator)

### 2) CodeRabbit CLI をインストールして認証する

手順:

1. CodeRabbit CLI をインストールする

```bash
curl -fsSL https://cli.coderabbit.ai/install.sh | sh
```

2. 認証する

```bash
coderabbit auth login
```

3. 状態確認

```bash
coderabbit auth status
```

参考:

- CLI docs: [https://docs.coderabbit.ai/cli](https://docs.coderabbit.ai/cli)
- Codex integration: [https://docs.coderabbit.ai/cli/codex-integration](https://docs.coderabbit.ai/cli/codex-integration)

### 3) ローカル pre-review を試す（最短の確認手順）

1. ブランチを切って変更を入れる
2. `precommit` を通す
3. `coderabbit-pre-review` を実行する
4. `change-review` を実行する
5. 必要なら指摘を修正する
6. commit 後に `pr-flow` で PR へ進む

### 4) CI 失敗を Codex に直させる（手動トリガー）

Codex は PR コメントでクラウドタスクを開始できます（`review` 以外の指示を `@codex` に続けて書く）。

例:

- `@codex fix the CI failures`
- `@codex make verify pass with the smallest safe change`

運用のコツ:

- 先に CI を通すこと（`verify`）を必須要件として書く
- 変更範囲を狭く書く（差分が最小になりやすい）

### 5) （任意）GitHub 上の `@codex review` は manual fallback として使える

- 既定運用はローカル pre-review です。
- 必要なら PR コメントで `@codex review` を投げて GitHub 上の review を追加できます。
- ただし通常フローの `pr-review-merge` はこれを自動では実行しません。
- Codex review の観点指定だけ必要なら `@codex review for <focus>` が使えます。

### 6) （任意）CodeRabbit GitHub App は手動 fallback として残してよい

- 既定運用は CLI pre-review です。
- 必要なら CodeRabbit GitHub App を残し、PR 上で手動レビューを使ってもよいです。
- ただし、このテンプレの既定では `.coderabbit.yaml` の `auto_review` と `commit_status` は無効です。

## Codex Code Review fallback（GitHubで `@codex review`）

- PR コメントで `@codex review` を投稿するとレビューが付く
- レビュー方針は `AGENTS.md` の `Review guidelines` を参照します
- `@codex review for <focus>` で観点指定ができます（例: security）

## Commands（Frontend）

```bash
npm run dev
npm run build
npm run lint
npm run lint:fix
npm run precommit
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

### CodeRabbit CLI が動かない

- `coderabbit auth status` で認証状態を確認してください
- `coderabbit auth login` を実行してください
- `coderabbit review --help` が通るか確認してください

## Notes

- Prettier の対象外にしたいファイルがある場合は `.prettierignore` を編集してください。
- Python の依存は venv 前提です。`backend/.venv` はコミットしません。
- Playwright の成果物はコミットしません（`.gitignore` を参照）。
- AIエージェント運用（Codex CLI 等）向けのルールは `AGENTS.md` を参照してください。
- 長い運用手順は `.codex/skills/` に分離されています。
