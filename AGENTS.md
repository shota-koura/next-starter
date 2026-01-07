# AGENTS.md

## 言語

- 原則、日本語で記述する。
- ただし、以下は原文（英数字）を維持する:
  - コード、コマンド、ファイルパス、設定キー、拡張子、チェック名
  - GitHub 画面上のメニュー名や操作名
  - ツールのトリガー文言（例: `@codex review`）
  - エラー文やログの引用

## Codex 指示の適用範囲と優先順位（重要）

- このファイルはリポジトリ全体の共通指示。
- 特定ディレクトリで追加ルールが必要な場合は、そのディレクトリ直下に `AGENTS.md` または `AGENTS.override.md` を置く。
- 同一ディレクトリでは `AGENTS.override.md` が `AGENTS.md` より優先される。
- 変更対象ファイルに近い階層の指示ほど優先する（root はフォールバック）。

## Review guidelines

このセクションは Codex の GitHub Code Review が参照するレビュー方針。

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

## AI PR review 運用（CodeRabbit + Codex）

前提:

- CodeRabbit は GitHub App として PR に自動レビューを付ける。
- Codex は PR コメントで `@codex review` を受けると code review を実行し、`@codex <task>` でクラウドタスクを開始できる。

運用ルール:

- CodeRabbit の指摘と `verify`（CI）の失敗は「修正すべき入力」として扱う。
- ただし、挙動変更・設計変更を伴う提案は、目的に照らして必要かを判断し、必要なら理由を明記する。
- CodeRabbit の inline コメントに「Prompt for AI Agents」が含まれる場合、その指示は修正実装の制約として尊重する（破る場合は理由を書く）。

PR コメントで Codex に依頼するテンプレ（例）:

- レビュー:
  - `@codex review`
  - `@codex review for security regressions and test coverage`
- 修正:
  - `@codex fix the CI failures (verify) and keep diffs minimal`
  - `@codex address CodeRabbit P0/P1 comments and make verify pass`

# 開発ルール（必須）

## 検証レベル（速い検証 / フル検証）

- 速い検証（開発ループ中）
  - Frontend:
    - `npm run format:check`
    - `npm run lint`
    - （UI/ロジックを触った場合）`npm run test:ci`
  - Backend（Python を触った場合）
    - `cd backend && source .venv/bin/activate && ruff format --check .`
    - `cd backend && source .venv/bin/activate && ruff check .`
    - （API/ロジックを触った場合）`cd backend && source .venv/bin/activate && python -m pytest`

- フル検証（CI 相当 / PR 前 / タスク完了前）
  - Frontend:
    - `npm run fix`
    - `npm run check` # format:check + lint + unit test + build
  - Backend（Python を触った場合）
    - `cd backend && source .venv/bin/activate && ruff check --fix .`
    - `cd backend && source .venv/bin/activate && ruff format .`
    - `cd backend && source .venv/bin/activate && pyright`
    - `cd backend && source .venv/bin/activate && python -m pytest`
  - E2E（任意）
    - 重要導線を触った場合のみ `npm run e2e` を追加で実行してよい（CI必須ではない）

## 完了条件（タスク / PR 共通）

- タスクを「完了」とする、または PR を提案する前に必ず実行:
  - Frontend: `npm run fix` と `npm run check`
  - Backend を変更した場合は Backend のフル検証も通す
- どれかが失敗した場合:
  - 問題を修正し、成功するまで再実行する。
- Codex CLI はエディタの保存時整形を使わないため、CLIチェックの通過を完了条件として重視する。

## commit 時の自動修正（Husky + lint-staged）

- `.husky/pre-commit` で `npx lint-staged` が実行される。
- ステージ済みファイルに対して自動修正が走る:
  - JS/TS: Prettier / ESLint
  - Python: Ruff（`ruff check --fix` と `ruff format`）
- 自動修正で差分が追加される場合があるため、commit が止まったら `git status` を確認し、必要なら `git add` を行ってから再度 commit する。
- Python の自動修正は `backend/.venv` が前提。未作成なら Backend setup を先に実施する。

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
  - `.coderabbit.yaml` の大幅変更（レビュー品質/ノイズ量に直結するため）

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

## Lint / Type check / Test

- Frontend:
  - lint は ESLint
  - unit test は Jest + RTL（`npm run test:ci`）
- Backend:
  - lint と自動修正は Ruff
  - 型チェックは Pyright
  - テストは pytest
- E2E:
  - Playwright（`npm run e2e`）
  - CI必須にしない（必要な変更のときだけ実行）

## UI 開発ルール（shadcn/ui を優先）

- UI の新規実装では、まず `components/ui/*` にある shadcn/ui コンポーネントを使う。
- 既存の shadcn/ui で足りない場合は、先に CLI で追加してから使う（例: `npx shadcn@latest add dialog`）。
- `lib/utils.ts` の `cn` を使って class 結合を統一する。
- UI変更があるPRでは、可能ならスクリーンショットを添付する。

## PR 提案時の出力（レビュー用）

- PR を提案するときに必ず含める:
  - 変更概要
  - 実行したコマンドと結果（最低限 `npm run check`。Python を触ったなら `pyright` と `python -m pytest`）
  - E2E を回した場合は `npm run e2e` の結果も書く（任意）
  - 大きな整形差分が出た場合の理由
  - 挙動変更がある場合はリスクとロールバック方針

## Git運用（commit / push / PR）: テンプレ標準

### 目的

- 人間の認知負荷を下げる
- AIレビュー（CodeRabbit/Codex）と人間レビューが破綻しない差分サイズに保つ
- 変更理由と影響が追える履歴にする

### commit の粒度（最重要）

- 1 commit = 1つの論理的変更（Atomic）
- 目安:
  - 変更ファイルが増えすぎたら分ける（例: 6ファイル以上になりそうなら分割を検討）
  - 差分が大きい場合は先に「下準備（型/関数抽出/リネーム）」と「機能変更」を分ける
- 自動整形のみの変更が大量に出る場合:
  - 整形だけのcommitと、機能変更commitを分ける

### commit メッセージ規約（日本語）

- コミットメッセージは日本語で書く（要約は日本語）
- 形式:
  - `<type>(<scope>): <日本語の要約>`
  - scope が不要なら `<type>: <日本語の要約>`
- type/scope は英字固定。要約だけ日本語。
- 例:
  - `feat(backend): ヘルスチェックAPIを追加`
  - `fix(frontend): モバイルでボタンが切れる問題を修正`
  - `docs: セットアップ手順を更新`
  - `ci: PythonテストをCIに追加`

### 推奨コマンド（人間/AI共通）

- 変更のチェック:
  - コミット前に必ずテストやLintを通すこと
- commit手順:
  - 上記の「commit メッセージ規約」に従ったメッセージを作成し、通常の `git commit -m "..."` を使用する
- push:
  - `git push origin <branch-name>` を使用
  - main/master への直接pushは禁止（PR運用）

### PR のセオリー

- 目安: 差分 200〜400行程度を上限に分割を検討
- PR では「何を」「なぜ」「どう確認したか」を短く書く
- 指摘修正は、可能なら小さめのcommitで積み上げる

# GitHub での使い方（Codex）

- レビュー依頼:
  - `@codex review`
  - `@codex review for <focus>`
- 修正依頼（クラウドタスク）:
  - `@codex <task>`
  - 例: `@codex fix the CI failures`
- Codex は `AGENTS.md` の `Review guidelines` を参照してレビューする。

# Ruleset（ブランチ保護）運用メモ（CodeRabbit を required checks に入れる場合）

- required checks の候補が出ない場合、対象チェックが1回以上実行されていない可能性が高い。
- CodeRabbit の check を required checks にしたい場合:
  - 先に PR を作って CodeRabbit を動かす
  - `Settings` -> `Rules` -> `Rulesets` -> `Require status checks to pass` で追加する
- CodeRabbit 側で commit status を出すには `.coderabbit.yaml` の `reviews.commit_status` が有効である必要がある（デフォルト有効）。

```

```
