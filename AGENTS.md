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

# 開発ルール（必須）

## 検証レベル（速い検証 / フル検証）

- 速い検証（開発ループ中）:
  - Run: `npm run format:check`
  - Then run: `npm run lint`
- フル検証（CI 相当 / PR 前 / タスク完了前）:
  - Run: `npm run fix`
  - Then run: `npm run check`

## 完了条件（タスク / PR 共通）

- タスクを「完了」とする、または PR を提案する前に必ず実行:
  - `npm run fix`
  - `npm run check`
- `npm run check` が失敗した場合:
  - 問題を修正し、成功するまで再実行する。
- 開発中は反復速度を優先し、「速い検証」を多用してよい。

## 事前確認が必要な変更（勝手に進めない）

- 以下に該当する場合は、実装前に確認を取る（理由・影響範囲・代替案も併記する）:
  - 本番依存の追加/削除（transitive deps を含む）
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
- `npm run fix` によって大量の変更が出た場合:
  - PR 内で理由を説明する、または
  - 整形のみの PR と機能変更 PR を分ける。

## フォーマット

- フォーマットは Prettier が正とする。
- Tailwind の class 並び替えは `prettier-plugin-tailwindcss` が正とする。
- 手で整形しない:
  - フル自動修正は `npm run fix` を使う。
  - Prettier 適用は `npm run format` を使う。

## Lint

- lint ルールは ESLint が正。
- `npm run lint:fix` は原則 `npm run fix` 経由でのみ実行（または明示依頼がある場合のみ）。

## PR 提案時の出力（レビュー用）

- PR を提案するときに必ず含める:
  - 変更概要
  - 実行したコマンドと結果（最低限 `npm run check`）
  - 大きな整形差分が出た場合の理由
  - UI 変更がある場合はスクリーンショット（可能なら）
  - 挙動変更がある場合はリスクとロールバック方針

# リポジトリ運用ガイド

## プロジェクト構造 / モジュール

- `app/` は Next.js App Router の routes と共通 UI（例: `app/page.tsx`, `app/layout.tsx`）。
- `app/globals.css` は global styles と Tailwind directives。
- `public/` は静的アセット。
- 主要設定ファイル: `next.config.ts`, `tsconfig.json`, `eslint.config.mjs`, `postcss.config.mjs`。

## ビルド / 開発 / 検証コマンド

- `npm install` 依存をインストール。
- `npm run dev` ローカル開発（`http://localhost:3000`）。
- `npm run build` 本番ビルド。
- `npm run start` 本番ビルドを起動（`npm run build` 後）。
- `npm run lint` ESLint 実行。
- `npm run lint:fix` ESLint 自動修正。
- `npm run format` Prettier 実行（Tailwind class 並び替え含む）。
- `npm run format:check` 書き込みなしで整形チェック。
- `npm run check` `format:check` + `lint` + `build`（CI 相当）。
- `npm run fix` format + lint の自動修正。

## コーディング規約 / 命名

- TypeScript + React。コンポーネントや route は `tsx` を優先。
- 整形は Prettier に任せ、手での揃えを避ける。
- Tailwind class の順序は `prettier-plugin-tailwindcss` が正。
- 命名:
  - React component は PascalCase（例: `HeroBanner`）
  - Hooks は `useX`
  - route segment folder は小文字（App Router の慣例）

## テスト方針

- 現時点では test runner 未導入。
- push 前に `npm run check` で build と lint を必ず通す。
- テストを追加する場合:
  - 配置は `tests/` または `__tests__/`
  - 命名は `*.test.tsx` または `*.spec.tsx`
  - 新しい test runner や重いツール導入は事前確認する。

## commit / PR の方針

- commit は最小・目的単位。
- commit subject は簡潔な命令形（例: `Add pricing section`）。
- PR は小さく、リファクタと機能追加は混ぜない（必要がある場合は理由を書く）。
- PR に含める:
  - 短い概要
  - 検証内容（コマンド実行結果）
  - UI 変更のスクリーンショット
  - 関連 issue へのリンク（あれば）

## 設定 / 環境

- secrets は `.env.local` に置き、コミットしない。
- `.prettierignore` で生成物や不要なディレクトリを除外（例: `.next`, `node_modules`, `.specstory`）。
- Tailwind 並びが怪しい場合は `npx prettier --write app/page.tsx` で確認してよい。

# `@codex review` 用のレビュー観点

## 重大度（P0-P3）

- P0: セキュリティ問題、credential/PII 漏洩、データ破壊、ビルドが壊れる
- P1: 挙動不正、回帰、UI 崩れ、互換性問題
- P2: 保守性の低下、エッジケース不足、軽微な性能懸念
- P3: 表記、コメント、軽微な改善提案

## この repo で必ず見ること

- secrets/PII をログに出さない。
- 意図しない public surface 変更を避ける（routes / env vars / exported APIs）。
- Next.js App Router:
  - `"use client"` は必要最小限にする
  - server/client の境界を明確にする
- 差分を最小にする（無関係なリファクタをしない）。
- PR コメントで焦点指定があればそれを最優先（例: security）。

## GitHub での使い方

- レビュー依頼: `@codex review`
- 観点を絞る: `@codex review for <focus>`
- 指摘は P0/P1 を優先して出す。

# GitHub Actions / Ruleset を新規リポジトリで有効化する手順（スクショ無しでも迷わない手順）

## 0. 前提

- 対象リポジトリの `Settings` を変更できる権限（通常は admin）が必要。
- Organization 配下の場合、Organization または Enterprise のポリシーで上書きされ、repo 側で変更できないことがある。

## 1. GitHub Actions を有効化する（Repository 単位）

1. GitHub 上で対象リポジトリを開く
2. `Settings` を開く
3. 左メニュー `Actions` -> `General` を開く
4. `Actions permissions` を設定する
   - CI を動かす目的なら、利用する action がブロックされない設定にする
   - "Allow actions and reusable workflows from only in your organization" を選ぶ場合は、
     `actions/checkout` などが使えない可能性があるため注意する
5. `Workflow permissions` を設定する
   - 通常の CI だけなら `Read` を基本にする
   - `GITHUB_TOKEN` で書き込みが必要な場合のみ `Read and write` を検討する
6. 必要な場合のみ `Allow GitHub Actions to create and approve pull requests` を有効化する
7. `Save` を押す
8. `.github/workflows/*.yml` をデフォルトブランチへ追加し、`Actions` タブで workflow が実行されることを確認する

## 2. Ruleset（ブランチ保護）を有効化する（Repository 単位）

1. GitHub 上で対象リポジトリを開く
2. `Settings` を開く
3. `Rules` -> `Rulesets` を開く
4. `New ruleset` を押す
5. `New branch ruleset` を選ぶ
6. `Ruleset name` を入力（例: `main protection`）
7. enforcement status を設定する
   - まず検証したい場合は Evaluate（利用可能な場合）
   - 即時適用するなら Active
8. `Target branches` で対象ブランチを設定する
   - デフォルトブランチ（例: `main`）を含める
   - 必要なら `release/*` なども追加する
9. `Branch protections` を設定する（推奨の最小セット）
   - Require a pull request before merging
   - Require approvals（例: 1）
   - Require status checks before merging
   - Block force pushes
   - (任意) Require conversation resolution
10. `Require status checks before merging` の Additional settings を設定する

- 必須にしたい check 名を追加する（CI の job 名を安定させる）

11. 必要に応じて `Bypass list` を最小限に設定する（例: admins のみ）
12. `Create` を押す

## 3. 運用の注意（Actions と Ruleset の噛み合わせ）

- `Require status checks before merging` を有効にすると、必須チェックがすべて通るまでマージできない。
- workflow の check 名が変わると Ruleset 側の必須チェック名と不整合になりやすいので、CI の job 名は安定させる。
