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
- このファイル内の `gh` 運用ルールは Codex CLI / Codex Web の両方に適用する（GitHub 操作は原則 `gh` を使う）。

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

## GitHub CLI (gh) 運用（Codex CLI / Codex Web / Terminal-first）

目的: PR 作成〜CI監視〜失敗ログ抽出〜修正〜push〜PR更新〜レビュー依頼〜マージまでを、Web UI に極力依存せずターミナルで完結させる。

### 方針（必須）

- Codex は CLI でも Web でも、GitHub 上の操作は原則 `gh` を使う（PR/コメント/レビュー依頼/CI監視/ログ取得/マージ）。
- ローカルのソース管理は `git` を使う（commit / push は `git`）。
- 認証は `gh auth status` を前提にし、`GH_TOKEN` の常用は避ける（CI/自動化用途の一時注入は可）。
- 秘密情報を出力しない:
  - トークン文字列、認証情報、内部URL、個人情報はログ/コメント/PR本文に含めない。

### プッシュをトリガーにした一連フロー（必須）

Codex CLI が `git push` を実行した、または push を検知した場合は「通知」し、続けて PR 作成〜レビュー依頼〜CI監視までを CLI で実行する。

- ここでの「通知」は、ターミナル出力（ログ）としてユーザーが読める形で出すこと。

#### 標準フロー（push → PR作成/更新 → レビュー依頼 → CI監視）

以下は「現在のブランチ」を対象にする（PR番号指定が不要な運用に寄せる）。

1. 現在ブランチ確認（main 直作業は禁止）

```bash
git status -sb
git rev-parse --abbrev-ref HEAD
```

2. push（PRは自動更新される）

```bash
git push -u origin HEAD
```

3. PR が無ければ作成（既にあればスキップ）

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

gh pr view "$BRANCH" >/dev/null 2>&1 || \
  gh pr create --fill --base main --head "$BRANCH"
```

4. PR URL を表示（通知）

```bash
gh pr view --json number,title,url -q '.number | tostring + " " + .title + "\n" + .url'
```

5. レビュー依頼（必須）

- Codex の GitHub Code Review を走らせるため、PR にコメントで `@codex review` を投稿する。

```bash
gh pr comment --body "@codex review"
```

- 追加で観点指定する場合（任意）

```bash
gh pr comment --body "@codex review for security regressions and test coverage"
```

6. CI（required checks）を監視し、完了まで待つ（必須）

- Ruleset で必須にしているチェック（例: `verify`）を中心に監視する。

```bash
gh pr checks --watch --required
```

- 失敗を見つけたら即終了したい場合（任意）

```bash
gh pr checks --watch --required --fail-fast
```

### CI 失敗時のログ抽出（必須）

CI が失敗したら、必ず「失敗したチェック名」と「失敗ログ（該当箇所）」をターミナルに出してから修正に入る。

1. 失敗チェックの把握

```bash
gh pr checks --required
```

2. 対象ブランチの最新 run を特定し、失敗ログを出す

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

RUN_ID="$(gh run list --branch "$BRANCH" --event pull_request --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
if [[ -z "$RUN_ID" ]]; then
  echo "❌ Error: No GitHub Actions runs found for branch $BRANCH"
  exit 1
fi

gh run view "$RUN_ID" --log-failed
```

補足:

- このテンプレの CI が `pull_request` トリガー前提の場合、PR が存在しないブランチには run が無いことがある（先に PR を作成してから CI を確認する）。

3. 修正 → ローカル検証 → commit/push → PR checks 再監視

- 修正の完了条件は本ファイルの「完了条件（タスク / PR 共通）」に従う。
- push 後は再度 `gh pr checks --watch --required` を実行する。

### CodeRabbit 指摘の抽出と通知（必須）

CodeRabbit が指摘を出した場合、指摘内容（本文）をターミナルに通知し、P0/P1 を優先して修正対象にする。

基本方針:

- CodeRabbit の commit status が required checks に入っている場合は、`gh pr checks` で状態が取れるためまずそこを見る。
- 追加で「指摘本文」を必ず取得し、ターミナルに出す（全文貼り付けではなく、要点が分かる形で可）。
- CI が pass していても CodeRabbit 指摘が残っている場合は修正を優先する（必要な場合のみ）。

#### PR 番号/リポジトリ情報の取得（補助）

```bash
PR_NUMBER="$(gh pr view --json number --jq '.number')"
OWNER="$(gh repo view --json owner --jq '.owner.login')"
REPO="$(gh repo view --json name --jq '.name')"
```

#### PR の Issue コメント（会話コメント）から CodeRabbit を抽出

```bash
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" --paginate \
  --jq '.[] | select(.user.login | test("coderabbit"; "i")) | ("---\n" + .user.login + " (" + .created_at + ")\n" + .body)'
```

#### PR の Review コメント（inline コメント）から CodeRabbit を抽出

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" --paginate \
  --jq '.[] | select(.user.login | test("coderabbit"; "i")) | ("---\n" + .user.login + " " + (.path // "") + ":" + ((.line // .original_line // 0) | tostring) + "\n" + .body)'
```

#### PR の Review（レビュー本体）から CodeRabbit を抽出

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
  --jq '.[] | select(.user.login | test("coderabbit"; "i")) | ("---\n" + .state + " " + .user.login + " (" + .submitted_at + ")\n" + (.body // ""))'
```

運用ルール:

- CodeRabbit の指摘がある場合は「指摘内容を通知」し、修正が必要なら修正→push→再チェック。
- 指摘が見当たらず、required checks も全て pass の場合は「問題なし」と通知する（次節）。

### 成功時の通知とマージ手順（必須）

条件:

- `gh pr checks --required` が全て pass
- CodeRabbit 指摘（P0/P1 など実質的な修正要求）が残っていない（必要なら上記抽出で確認）
- PR が Draft でない

満たした場合:

- 「マージ可能」をターミナルに通知し、マージコマンドを提示する。

例（squash merge + ブランチ削除）:

```bash
gh pr merge --squash --delete-branch
```

Auto-merge を使う場合（任意。権限とリポジトリ設定が許す場合のみ）:

```bash
gh pr merge --auto --squash --delete-branch
```

注意:

- main/master への直接 push は禁止（PR運用）。
- マージ方法（squash/merge/rebase）はリポジトリ方針に従う（不明なら squash をデフォルトに寄せ、必要に応じてユーザーに確認を促す）。

### 通知フォーマット（必須）

ターミナル通知は以下の粒度で出す（ユーザーが「いま何が起きているか」を追えること）。

- `✅ push 完了: <branch> <short-sha>`
- `✅ PR: #<number> <url>`
- `✅ review request: posted "@codex review"`
- `⏳ CI: watching required checks...`
- `❌ CI failure: <check-name>` → `gh run view ... --log-failed` の該当箇所を出す
- `❗ CodeRabbit comments:` → 抽出した指摘本文（要点が分かる形）
- `✅ All green: ready to merge` → 提示する `gh pr merge ...`

### ドキュメント整形（必須）

- `*.md` は Prettier の対象になり得るため、`AGENTS.md` を編集したら `npm run format` を実行して整形差分を確定する。
- 整形差分が大量に出る場合は、理由を PR に明記するか、整形のみの commit と機能変更 commit を分ける。

# 開発ルール（必須）

## 検証レベル（速い検証 / フル検証）

- 速い検証（開発ループ中）
  - Frontend:
    - `npm run format:check`
    - `npm run lint`
    - （UI/ロジックを触った場合）`npm run test:ci`
  - Backend（Python を触った場合）
    - 前提（初回のみ）:
      - `cd backend`
      - `python3 -m venv .venv`
      - `source .venv/bin/activate`
      - `pip install -U pip`
      - `pip install -r requirements-dev.txt`
    - 推奨（`backend/Makefile` のターゲットを優先。名称は `cd backend && make help` で確認）:
      - `cd backend && make ruff-format-check`
      - `cd backend && make ruff-check`
      - （API/ロジックを触った場合）`cd backend && make pytest`
    - 直接実行（Makefile を使わない場合は venv を有効化した上で実行）:
      - `cd backend && source .venv/bin/activate && ruff format --check .`
      - `cd backend && source .venv/bin/activate && ruff check .`
      - （API/ロジックを触った場合）`cd backend && source .venv/bin/activate && python -m pytest`

- フル検証（CI 相当 / PR 前 / タスク完了前）
  - Frontend:
    - `npm run fix`
    - `npm run check` # format:check + lint + unit test + build
  - Backend（Python を触った場合）
    - 推奨（`backend/Makefile` のターゲットを優先。名称は `cd backend && make help` で確認）:
      - `cd backend && make ruff-fix`
      - `cd backend && make ruff-format`
      - `cd backend && make pyright`
      - `cd backend && make pytest`
    - 直接実行（Makefile を使わない場合は venv を有効化した上で実行）:
      - `cd backend && source .venv/bin/activate && ruff check --fix .`
      - `cd backend && source .venv/bin/activate && ruff format .`
      - `cd backend && source .venv/bin/activate && pyright`
      - `cd backend && source .venv/bin/activate && python -m pytest`
  - E2E（任意）
    - 次のいずれかに該当する場合のみ `npm run e2e` を追加で実行してよい（CI必須ではない）:
      - ルーティング/ナビゲーション/ページ遷移に影響する変更（例: `app/**/page.tsx`, `app/**/layout.tsx`, `app/**/route.ts`, `middleware.ts`）
      - フロント⇄バックの接続導線や API 契約に影響する変更（例: `backend/app.py` の API 変更、クライアントの fetch ラッパ変更）
      - 認証/オンボーディング/決済など、プロダクト上の重要ユーザー導線に影響する変更がある場合
      - `e2e/` 配下の spec がカバーしている導線に影響する変更がある場合（例: `e2e/health.spec.ts` など、既存 spec の対象ルート/導線）
    - 「重要導線」とは:
      - `e2e/**/*.spec.ts` が明示的にカバーしているルート/操作
      - または、ユーザーが最初に到達する/主要機能に到達するために必須の画面遷移/操作

## 完了条件（タスク / PR 共通）

- タスクを「完了」とする、または PR を提案する前に必ず実行:
  - Frontend: `npm run fix` と `npm run check`
  - Backend を変更した場合は Backend のフル検証も通す（`backend/Makefile` がある場合は Makefile ルートを優先）
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
- PR/CI 監視（ターミナルで完結させる）:
  - PR 作成: `gh pr create --fill`
  - CI 監視: `gh pr checks --watch --required`
  - 失敗ログ: `gh run view <run-id> --log-failed`
  - レビュー依頼: `gh pr comment --body "@codex review"`

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
