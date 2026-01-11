# AGENTS.md

## 言語

- 原則、日本語で記述する。
- ただし、以下は原文（英数字）を維持する:
  - コード、コマンド、ファイルパス、設定キー、拡張子、チェック名
  - GitHub 画面上のメニュー名や操作名
  - ツールのトリガー文言（例: `@codex review`、`$pr-flow`）
  - エラー文やログの引用

## Codex 指示の適用範囲と優先順位（重要）

- このファイルはリポジトリ全体の共通指示。
- 特定ディレクトリで追加ルールが必要な場合は、そのディレクトリ直下に `AGENTS.md` または `AGENTS.override.md` を置く。
- 同一ディレクトリでは `AGENTS.override.md` が `AGENTS.md` より優先される。
- 変更対象ファイルに近い階層の指示ほど優先する（root はフォールバック）。

## 基本方針（常時適用・最重要）

### 秘密情報・安全

- PII/秘密情報をログ・例・コメント・テストデータ・PR本文に含めない。
  - トークン/API key/認証情報/内部URL などは出力しない。貼られている場合は伏せる。
- 「設定にAPI keyが含まれるもの（例: MCP）」は特に注意し、コピペで漏らさない。

### Git / GitHub 運用

- main/master への直接 push は禁止（PR 運用）。
- GitHub 上の操作（PR 作成/コメント/CI監視/ログ取得/マージ）は原則 `gh` を使う。
- ローカルのソース管理は `git` を使う（commit / push は `git`）。
- 認証は `gh auth status` を前提にし、`GH_TOKEN` の常用は避ける（CI/自動化用途の一時注入は可）。

### 差分の品質

- 無関係な差分を避ける（タスクと関係ない整形・リファクタを混ぜない）。
- 差分は最小にする:
  - タスクに必要なファイルのみ編集する
  - 明示的な必要がない限り repo 全体の整形はしない
- `npm run fix` / `ruff check --fix` で大量差分が出た場合:
  - PR で理由を説明する、または
  - 整形のみの commit と機能変更 commit を分ける

### UI 方針

- UI は shadcn/ui を優先する（独自UIの乱立を避ける）。
- 既存の shadcn/ui で足りない場合は、先に CLI で追加してから使う（例: `npx shadcn@latest add dialog`）。
- `lib/utils.ts` の `cn` を使って class 結合を統一する。
- UI変更があるPRでは、可能ならスクリーンショットを添付する。

## Review guidelines（Codex GitHub Code Review 用）

- PII/秘密情報をログ・例・コメント・テストデータに含めない。
- 意図しない public surface 変更を避ける（routes / env vars / exported APIs）。
- 無関係な差分を避ける（タスクと関係ない整形・リファクタを混ぜない）。
- CI を壊さない（`verify` を通せない変更は不可）。
- UI は shadcn/ui を優先する（独自UIの乱立を避ける）。
- テストを更新する:
  - Frontend: `__tests__/` の unit test（Jest + RTL）
  - Backend: `backend/tests/` の pytest
  - E2E: `e2e/` の Playwright（必須ではないが、重要導線は追加を検討）
- 重要度は P0/P1 を優先して指摘する（必要なら `@codex review for <focus>` で観点指定）。

## 事前確認が必要な変更（勝手に進めない）

- 以下に該当する場合は、実装前に確認を取る（理由・影響範囲・代替案も併記する）:
  - 本番依存の追加/削除（transitive deps を含む）
  - UIライブラリの追加（shadcn/ui 以外を足す、または設計が変わるもの）
  - 大規模リファクタ、repo 全体の整形、タスクと無関係な変更の混入
  - 認証/認可（authn/authz）、middleware、アクセス制御の変更
  - `.github/workflows/*`、CI の挙動、リポジトリ運用ルール（Ruleset など）に関する変更
  - 新しい環境変数の導入、既存環境変数の意味変更
  - 公開されている route / API / 外部参照されるコンポーネントの削除・リネーム
  - テスト基盤（Jest/Playwright/pytest/pyright 等）の差し替えや大幅変更
  - `.coderabbit.yaml` の大幅変更（レビュー品質/ノイズ量に直結）

## 標準コマンド（共通）

- commit 前の整形・整合チェック（必須）: `npm run precommit`
- PR 作成〜CI待ち（入口）: `bash scripts/pr.sh`（無い場合は `gh` でフォールバック）

## 完了条件（タスク / PR 共通）

- PR を提案する前、またはタスクを「完了」とする前に、必ずフル検証を通す:
  - 詳細手順は skill `$verify-full` を使う
- どれかが失敗した場合:
  - 問題を修正し、成功するまで再実行する
- Codex CLI はエディタ保存時整形を使わない前提のため、CLIチェックの通過を完了条件として重視する。

## commit メッセージ規約（日本語）

- コミットメッセージは日本語で書く（要約は日本語）。
- 形式:
  - `<type>(<scope>): <日本語の要約>`
  - scope が不要なら `<type>: <日本語の要約>`
- type/scope は英字固定。要約だけ日本語。
- 例:
  - `feat(backend): ヘルスチェックAPIを追加`
  - `fix(frontend): モバイルでボタンが切れる問題を修正`
  - `docs: セットアップ手順を更新`
  - `ci: PythonテストをCIに追加`

## skills（手順の本体）

このリポジトリでは、長い手順・状況依存の手順は skills に分離する。
skills は `$<skill-name>` で呼び出す。

- PR/CI の一連フロー（push後）: `$pr-flow`
- CI 失敗ログ抽出: `$ci-log-failed`
- CodeRabbit 指摘の抽出と要約: `$coderabbit-digest`
- 速い検証（開発ループ）: `$verify-fast`
- フル検証（PR前/完了前）: `$verify-full`
- ブランチ作成（git alias 優先）: `$branch-create`
- （MCP）ドキュメント参照: `$mcp-context7-docs`
- （MCP）UI再現・スクショ・ログ収集: `$mcp-playwright-debug`
- （MCP）安全なリファクタ（シンボル操作）: `$mcp-serena-refactor`
- （MCP）パフォーマンス計測（DevTools）: `$mcp-chrome-devtools-perf`
- Ruleset / required checks 運用メモ: `$ruleset-notes`

## ドキュメント整形

- `*.md` は Prettier の対象になり得る。
- `AGENTS.md` や skills を編集したら `npm run precommit` を実行して整形差分を確定する。
- 整形差分が大量に出る場合は、理由を PR に明記するか、整形のみの commit と機能変更 commit を分ける。
