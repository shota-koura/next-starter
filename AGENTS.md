# AGENTS.md

## 言語

- 原則、日本語で記述する。
- ただし、以下は原文（英数字）を維持する:
  - コード、コマンド、ファイルパス、設定キー、拡張子、チェック名
  - GitHub 画面上のメニュー名や操作名（例: `Settings` -> `Actions` -> `General`）
  - ツールのトリガー文言（例: `@codex review`）
  - エラー文やログの引用

## Codex 指示の適用範囲と優先順位（重要）

- このファイルはリポジトリ全体の共通指示。
- 特定ディレクトリで追加ルールが必要な場合は、そのディレクトリ直下に `AGENTS.md` または `AGENTS.override.md` を置く。
- 同一ディレクトリでは `AGENTS.override.md` が `AGENTS.md` より優先される。
- 変更対象ファイルに近い階層の指示ほど優先する（root はフォールバック）。

## Review guidelines

このセクションは Codex の GitHub Code Review が参照するレビュー方針です。変更されたファイルに最も近い `AGENTS.md` の内容が優先されます。:contentReference[oaicite:7]{index=7}

- PII/秘密情報をログ・例・コメント・テストデータに含めない。
- 意図しない public surface 変更を避ける（routes / env vars / exported APIs）。
- 無関係な差分を避ける（タスクと関係ない整形・リファクタを混ぜない）。
- CI を壊さない（`verify` を通せない変更は不可）。
- Frontend の UI は shadcn/ui を優先する（独自UIの乱立を避ける）。
- 重要度は P0/P1 を優先して指摘する（必要なら `@codex review for <focus>` で観点指定）。

# 開発ルール（必須）

## 検証レベル（速い検証 / フル検証）

- 速い検証（開発ループ中）
  - Frontend:
    - `npm run format:check`
    - `npm run lint`
  - Backend（Python を触った場合）
    - `cd backend && source .venv/bin/activate && ruff format --check .`
    - `cd backend && source .venv/bin/activate && ruff check .`

- フル検証（CI 相当 / PR 前 / タスク完了前）
  - Frontend:
    - `npm run fix`
    - `npm run check`
  - Backend（Python を触った場合）
    - `cd backend && source .venv/bin/activate && ruff check --fix .`
    - `cd backend && source .venv/bin/activate && ruff format .`
    - `cd backend && source .venv/bin/activate && pyright`
    - `cd backend && source .venv/bin/activate && python -m pytest`

## 完了条件（タスク / PR 共通）

- タスクを「完了」とする、または PR を提案する前に必ず実行:
  - Frontend: `npm run fix` と `npm run check`
  - Backend を変更した場合は Backend のフル検証も通す
- `npm run check` または Backend のチェックが失敗した場合:
  - 問題を修正し、成功するまで再実行する。
- Codex CLI はエディタの保存時整形を使わないため、CLIチェックの通過を完了条件として重視する。

## commit 時の自動修正（Husky + lint-staged）

- `.husky/pre-commit` で `npx lint-staged` が実行される。
- ステージ済みファイルに対して自動修正が走る（JS/TS: Prettier/ESLint、Python: Ruff）。
- Python の自動修正は、ステージされた `*.py` に対して `ruff check --fix` と `ruff format` が走る（`backend/.venv` が前提）。
- 自動修正で差分が追加される場合があるため、commit が止まったら `git status` を確認し、必要なら `git add` を行ってから再度 commit する。

## 事前確認が必要な変更（勝手に進めない）

- 以下に該当する場合は、実装前に確認を取る（理由・影響範囲・代替案も併記する）:
  - 本番依存の追加/削除（transitive deps を含む）
  - UIライブラリの追加（shadcn/ui 以外を足す、または設計が変わるもの）
  - 大規模リファクタ、repo 全体の整形、タスクと無関係な変更の混入
  - 認証/認可（authn/authz）、middleware、アクセス制御の変更
  - `.github/workflows/*`、CI の挙動、リポジトリ運用ルール（Ruleset など）に関する変更
  - 新しい環境変数の導入、既存環境変数の意味変更
  - 公開されている route / API / 外部参照されるコンポーネントの削除・リネーム

## 無関係な差分を避ける（重要）

- 無関係な整形変更を入れない。
- 差分は最小にする:
  - タスクに必要なファイルのみを編集する。
  - 明示的な必要がない限り、repo 全体の整形はしない。
- `npm run fix` や `ruff check --fix` によって大量の変更が出た場合:
  - PR 内で理由を説明する、または
  - 整形のみの PR と機能変更 PR を分ける。

## フォーマット

- Frontend のフォーマットは Prettier が正とする。
- Tailwind の class 並び替えは `prettier-plugin-tailwindcss` が正とする。
- Backend のフォーマットは Ruff が正とする。
- 手で整形しない:
  - Frontend: `npm run format` / `npm run fix`
  - Backend: `ruff format` / `ruff check --fix`

## Lint / Type check

- Frontend:
  - lint ルールは ESLint が正。
  - `npm run lint:fix` は原則 `npm run fix` 経由でのみ実行（または明示依頼がある場合のみ）。
- Backend:
  - lint と自動修正は Ruff が正。
  - 型チェックは Pyright が正。
  - テストは pytest が正。

## UI 開発ルール（shadcn/ui を優先）

- UI の新規実装では、まず `components/ui/*` にある shadcn/ui コンポーネントを使う。
- 既存の shadcn/ui で足りない場合は、先に CLI で追加してから使う（例: `npx shadcn@latest add dialog`）。
- Tailwind のクラス直書きで大きなUIを組まない。部品化する場合は shadcn/ui の流儀に寄せる。
- `lib/utils.ts` の `cn` を使って class 結合を統一する。
- UI変更があるPRでは、必ずスクリーンショット（可能なら）を添付する。

## PR 提案時の出力（レビュー用）

- PR を提案するときに必ず含める:
  - 変更概要
  - 実行したコマンドと結果（最低限 `npm run check`。Python を触ったなら `pyright` と `python -m pytest`）
  - 大きな整形差分が出た場合の理由
  - UI 変更がある場合はスクリーンショット（可能なら）
  - 挙動変更がある場合はリスクとロールバック方針

# リポジトリ運用ガイド

## プロジェクト構造 / モジュール

- `app/` は Next.js App Router の routes と共通 UI（例: `app/page.tsx`, `app/layout.tsx`）。
- `components/` は UI コンポーネント（shadcn/ui は `components/ui/` 配下に生成される前提）。
- `lib/` は共通ユーティリティ。
- `backend/` は Python バックエンド（FastAPI + Ruff + Pyright + pytest）。
- 主要設定ファイル: `next.config.ts`, `tsconfig.json`, `eslint.config.mjs`, `postcss.config.mjs`, `components.json`。

## ビルド / 開発 / 検証コマンド（Frontend）

- `npm install` 依存をインストール。
- `npm run dev` ローカル開発。
- `npm run build` 本番ビルド。
- `npm run start` 本番ビルドを起動（`npm run build` 後）。
- `npm run lint` ESLint 実行。
- `npm run lint:fix` ESLint 自動修正。
- `npm run format` Prettier 実行（Tailwind class 並び替え含む）。
- `npm run format:check` 書き込みなしで整形チェック。
- `npm run check` `format:check` + `lint` + `build`（CI 相当）。
- `npm run fix` format + lint の自動修正。

## ビルド / 開発 / 検証コマンド（Backend）

- venv を有効化してから実行する:
  - `cd backend && source .venv/bin/activate`
- 主要コマンド:
  - `ruff check .`
  - `ruff check --fix .`
  - `ruff format .`
  - `ruff format --check .`
  - `pyright`
  - `python -m pytest`
  - `uvicorn app:app --reload --port 8000`

# `@codex review` の使い方（GitHub）

- PR のコメント欄（Conversation）で `@codex review` を投稿するとレビューが実行される。:contentReference[oaicite:8]{index=8}
- 観点を絞る場合は `@codex review for <focus>` を使う。:contentReference[oaicite:9]{index=9}
- Codex はリポジトリ内の `AGENTS.md` を探索し、このファイルの `## Review guidelines` を参照してレビューする。:contentReference[oaicite:10]{index=10}

# GitHub Actions / Ruleset を新規リポジトリで有効化する手順

## 0. 前提

- 対象リポジトリの `Settings` を変更できる権限（通常は admin）が必要。
- Organization 配下の場合、Organization または Enterprise のポリシーで上書きされ、repo 側で変更できないことがある。

## 1. GitHub Actions を有効化する（Repository 単位）

1. GitHub 上で対象リポジトリを開く
2. `Settings` を開く
3. 左メニュー `Actions` -> `General` を開く
4. `Actions permissions` を設定する
5. `Workflow permissions` を設定する
6. 必要な場合のみ `Allow GitHub Actions to create and approve pull requests` を有効化する
7. `Save` を押す
8. `.github/workflows/*.yml` をデフォルトブランチへ追加し、`Actions` タブで workflow が実行されることを確認する

## 2. Ruleset（ブランチ保護）を有効化する（Repository 単位）

1. GitHub 上で対象リポジトリを開く
2. `Settings` を開く
3. `Rules` -> `Rulesets` を開く
4. `New ruleset` -> `New branch ruleset` を選ぶ
5. `Ruleset name` を入力（例: `main protection`）
6. enforcement status を設定する（例: `Active`）
7. `Target branches` で対象ブランチを設定する（例: default branch）
8. ルール（推奨の最小セット）
   - `Require a pull request before merging`
   - `Require status checks to pass`
   - `Block force pushes`
   - （任意）`Require conversation resolution before merging`
9. `Require status checks to pass` の `Add checks` で必須チェック名を追加（例: `verify`）
10. 必要に応じて `Bypass list` を最小限に設定（例: admins のみ）
11. `Create` を押す

## 3. 運用の注意（Actions と Ruleset の噛み合わせ）

- `Require status checks to pass` を有効にすると、必須チェックがすべて通るまでマージできない。
- workflow の check 名が変わると Ruleset 側の必須チェック名と不整合になりやすいので、CI の job 名は安定させる（例: `verify`）。
