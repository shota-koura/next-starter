---
name: pr-flow
description: push後にPR作成/表示、CI監視、@codex review投稿、必要に応じてCodeRabbit要約、マージコマンド提示までを gh で実行する
---

## 目的

- push 後の「PR 作成〜CI監視〜レビュー依頼〜（可能なら）マージ提案」までを、Web UI に依存せずターミナルで完結させる。
- 差分最小・CI安定・レビューしやすさを優先する。

## いつ使うか

- `git push` した直後（または push 済みブランチで PR を作りたい/状態を確認したいとき）。
- PR を開いて CI を待ち、`@codex review` を投げたいとき。

## 前提

- main/master への直接 push はしない（作業ブランチ前提）。
- `gh auth status` が通ること。
- `scripts/pr.sh` がある場合はそれを優先して使う（無い場合はフォールバック手順）。

## 実行手順（標準）

### 0) 現在状態を通知（ログ）

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"
echo "[OK] branch: $BRANCH $SHA"

```

- `BRANCH` が `main` / `master` の場合は停止し、作業ブランチ作成へ誘導する。

### 1) PR 作成 or 表示（scripts/pr.sh 優先）

```bash
if [[ -f scripts/pr.sh ]]; then
  bash scripts/pr.sh
else
  echo "[INFO] scripts/pr.sh not found -> fallback with gh"
fi

```

`scripts/pr.sh` が無い場合のフォールバック:

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
gh pr view "$BRANCH" >/dev/null 2>&1 || gh pr create --fill --base main --head "$BRANCH"
gh pr view --json number,title,url,isDraft --jq '"[OK] PR: #\(.number) \(.title)\n\(.url)\n[INFO] isDraft=\(.isDraft)"'

```

### 2) `@codex review` を PR コメントで投稿（必須）

```bash
gh pr comment --body "@codex review"
echo "[OK] review request: posted \"@codex review\""

```

観点指定したい場合（任意）:

```bash
gh pr comment --body "@codex review for security regressions and test coverage"

```

### 3) CI を監視（required checks 優先）

```bash
echo "[WAIT] CI: watching checks..."
gh pr checks --watch --required --fail-fast || gh pr checks --watch --fail-fast

```

## 失敗時（CI が落ちた場合）

1. まず失敗したチェック名を把握する:

```bash
gh pr checks --required || gh pr checks

```

2. 失敗ログを抽出する（skill 推奨）:

- `$ci-log-failed` を実行して失敗ログをターミナルに出す。
- そのログに基づいて修正する（無関係差分は増やさない）。

3. 修正後はローカル検証 → commit/push → この skill を再実行:

- ローカル検証は `$verify-fast`（開発ループ）/ `$verify-full`（完了前）を使う。

## CodeRabbit 指摘がある場合（任意）

- CI が通っていても CodeRabbit 指摘が残っていそうな場合は `$coderabbit-digest` を実行して要点を把握する。
- P0/P1 から優先して対応する。設計変更を伴う提案は目的に照らして必要性を判断し、必要なら理由を明記する。

## 成功時（All green）

- checks が全て pass していることを確認:

```bash
gh pr checks

```

- Draft でないこと（Draft なら Ready for review が必要）:

```bash
gh pr view --json isDraft,url --jq '"[INFO] isDraft=\(.isDraft)\n\(.url)"'

```

- マージ可能なら、マージコマンドを提示（実行は状況に応じて）:

```bash
echo "[OK] All green: ready to merge"
echo "Suggested:"
echo "  gh pr merge --squash --delete-branch"
echo "Or (if enabled):"
echo "  gh pr merge --auto --squash --delete-branch"

```

## 出力フォーマット（目安）

- `[OK] PR: #<number> <url>`
- `[OK] review request: posted "@codex review"`
- `[WAIT] CI: watching checks...`
- `[ERROR] CI failure: <check-name>`（発生時）
- `[OK] All green: ready to merge`
