---
name: coderabbit-digest
description: CodeRabbit のコメント/レビューを gh api で抽出し、P0/P1優先で要点を短くまとめる
---

## 目的

- CodeRabbit の指摘を「どこに」「何が」「優先度は」あるか把握し、修正対象を整理する。
- 重要指摘（P0/P1）を優先して潰し、無関係な提案は目的に照らして取捨選択する。

## いつ使うか

- PR を作った直後（自動レビューの全体把握）。
- CI は通っているが CodeRabbit の指摘が残っていそうなとき。
- `@codex` に修正依頼する前に「何を直すべきか」整理したいとき。

## 実行手順

### 0) PR/リポジトリ情報を取得

```bash
PR_NUMBER="$(gh pr view --json number --jq '.number')"
OWNER="$(gh repo view --json owner --jq '.owner.login')"
REPO="$(gh repo view --json name --jq '.name')"

echo "[INFO] PR=$PR_NUMBER repo=$OWNER/$REPO"

```

### 1) PR の Issue コメント（会話コメント）から CodeRabbit を抽出

```bash
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" --paginate \
  --jq '.[] | select(.user.login | test("coderabbit"; "i")) | ("---\n" + .user.login + " (" + .created_at + ")\n" + .body)'

```

### 2) PR の Review コメント（inline コメント）から CodeRabbit を抽出

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" --paginate \
  --jq '.[] | select(.user.login | test("coderabbit"; "i")) | ("---\n" + .user.login + " " + (.path // "") + ":" + ((.line // .original_line // 0) | tostring) + "\n" + .body)'

```

### 3) PR の Review（レビュー本体）から CodeRabbit を抽出

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
  --jq '.[] | select(.user.login | test("coderabbit"; "i")) | ("---\n" + .state + " " + .user.login + " (" + .submitted_at + ")\n" + (.body // ""))'

```

## 要約の作り方（この skill の中でやること）

- 抽出結果から、以下の観点で短く整理して出力する（全文の貼り直しは避ける）:
- P0（壊れる/セキュリティ/データ破壊/CI失敗）: まず対応
- P1（バグ/回帰リスク/重要UX）: 次に対応
- P2（改善提案/好み/リファクタ）: 目的に合うなら対応

- 指摘が「設計変更・挙動変更」を伴う場合は、必要性を判断し、採用しない場合は理由を明記する。

## 出力フォーマット（例）

- `[INFO] CodeRabbit digest`
- `P0:` (箇条書き)
- `P1:` (箇条書き)
- `P2:` (箇条書き)
- `Notes:`（採用しない理由、追加調査が必要な点）
