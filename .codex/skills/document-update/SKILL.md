---
name: document-update
description: PR作成/更新の前に、.steering/ と AGENTS.md を最小差分で同期する（必要なときだけ更新し、必要ならドキュメントだけを追加コミットして push する）
---

## 目的

- PR の差分内容と、作業ドキュメント（`.steering/`）の記載が乖離しないようにする。
- 技術選定・実装方針・運用ルールが変わった場合にのみ `AGENTS.md` を最小差分で更新する（頻繁な編集はしない）。
- `pr-flow` / `pr-fix-loop` と連動し、PR作成/更新の直前に「ドキュメント整合」を挟めるようにする。

## いつ使うか

- PR を作る直前（推奨: `$pr-flow` の前）。
- 既にPRがある場合でも、差分の方向性が変わった/追加の作業が入ったとき（push前の追加コミットとして）。
- `pr-fix-loop` で修正方針が変わり、`.steering/*/design.md` や `tasklist.md` の更新が必要になったとき。

## 前提

- 作業ブランチ上で実行する（main/master では実行しない）。
- `.steering/` が存在することが望ましい（無い場合は最小限で作成してよい）。
- `gh` が使える（PR URL の取得に使う。無くても進められる）。

## 環境変数

- `BASE_BRANCH`
  - 差分比較の base ブランチ。デフォルト `main`
- `DOC_COMMIT`
  - ドキュメント更新が発生した場合にドキュメントだけを追加コミットするか。デフォルト `1`
- `DOC_PUSH`
  - `DOC_COMMIT=1` のとき push も行うか。デフォルト `1`

## ガードレール

- `.steering/steering.md` は並び替え禁止。追記は末尾に追加し、既存行の大規模整形をしない。
- `.steering/<作業ID-...>/tasklist.md` は「自分の作業分」だけ更新する。番号や順序の全体編集は禁止。追加は末尾に追記。
- `AGENTS.md` は「技術選定/実装方針/運用ルール」が変わった場合にのみ更新する。表現の言い換えや再構成のための編集は禁止。
- この skill は原則として「ドキュメントだけ」を変更する。コード変更やリファクタは行わない。
- もしドキュメント更新のために大きな設計判断が必要になったら停止し、差分と判断ポイントを要約して報告する。

## 実行手順

### 0) 現在状態の確認

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"
echo "[OK] branch=$BRANCH sha=$SHA"

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "[ERROR] main/master 上です。作業ブランチへ切り替えてください。"
  exit 1
fi

BASE_BRANCH="${BASE_BRANCH:-main}"
git fetch origin "$BASE_BRANCH" --quiet || true
BASE_REF="$BASE_BRANCH"
if git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
  BASE_REF="origin/$BASE_BRANCH"
fi
echo "[INFO] base_ref=$BASE_REF"
```

### 1) PR差分から「今回の作業が触っている領域」を機械的に把握

```bash
CHANGED_FILES="$(git diff --name-only "$BASE_REF"...HEAD | sed '/^$/d' || true)"
echo "[INFO] changed files (vs $BASE_REF):"
echo "$CHANGED_FILES"
```

### 2) 「現在作業の .steering ディレクトリ」を推定

優先順位:

1. PR差分に含まれる `.steering/<dir>/` があれば、それを現在作業として扱う（複数ある場合は最小限にし、必要なものだけ更新する）。
2. 1が無い場合は `.steering/steering.md` に現在ブランチ名が書かれている行があれば、その行の作業ディレクトリを現在作業として扱う。
3. それも無ければ、`.steering/` 配下に作業ディレクトリが1つだけある場合のみ、それを現在作業として扱う。
4. 上記で一意に決まらない場合、`.steering/steering.md` だけを最小限更新して終了し、個別ディレクトリ更新は行わない。

機械的抽出（候補一覧）:

```bash
STEERING_DIRS_FROM_DIFF="$(
  echo "$CHANGED_FILES" \
  | grep -E '^\.(steering)/[^/]+/' \
  | cut -d/ -f1-2 \
  | sort -u || true
)"
echo "[INFO] steering dirs from diff:"
echo "$STEERING_DIRS_FROM_DIFF"
```

### 3) `.steering/steering.md` を最小差分で更新

目的:

- 作業行（自分の作業）に「ブランチ」「状態」「必要ならPR URL」を反映する。
- 追記は末尾。並び替えや全体整形は禁止。

手順:

- `.steering/steering.md` が無ければ作成する（最小の表）。
- 既存フォーマットがあるなら維持する。
- 自分の作業行が無ければ末尾に追記する。
- 自分の作業行があれば、その行だけ更新する。

PR URL（取得できる場合のみ）:

```bash
PR_URL="$(gh pr view --json url --jq .url 2>/dev/null || true)"
if [[ -n "$PR_URL" ]]; then
  echo "[INFO] pr_url=$PR_URL"
fi
```

注意:

- ここは機械的に「状態=doing」へ寄せるのが基本。`done` は merge 後に更新する（必要なら同 skill を再実行）。

### 4) 作業ディレクトリ配下（requirements/design/tasklist）を更新（必要な場合のみ）

対象候補:

- 2. で推定した現在作業ディレクトリ
- もしくは PR差分に含まれる `.steering/<dir>/`（必要なものだけ）

更新方針（最小差分）:

- `tasklist.md`: PR差分で実装完了しているタスクを `done` にする。抜けている必須タスクがあれば末尾に追記する。並び替えはしない。
- `design.md`: 実装方針が当初と変わった場合のみ、差分が出た箇所に追記/修正する（全面書き換え禁止）。
- `requirements.md`: 受け入れ条件・要件の解釈が変わった場合のみ、追記または最小修正する。

### 5) `AGENTS.md` を更新（必要な場合のみ）

更新トリガ（明確な場合のみ）:

- 技術選定の変更（例: フレームワーク/主要ライブラリ/テスト基盤/運用フローの変更）
- 実装方針の恒久的な変更（例: 命名規則や構成ルール、レビュー運用の変更）
- 事前確認が必要な変更範囲の更新が必要になった

禁止:

- 表現の言い換えや章の再構成だけの編集
- 無関係な整形

### 6) ドキュメント以外が変わっていないかをチェック（必須）

```bash
DOC_ONLY_OK=1

CHANGED_NOW="$(git status --porcelain | sed -E 's/^.. //')"
echo "[INFO] working tree changes:"
echo "$CHANGED_NOW"

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ "$f" != .steering/* && "$f" != AGENTS.md ]]; then
    echo "[ERROR] document-update でドキュメント以外が変更されています: $f"
    DOC_ONLY_OK=0
  fi
done <<<"$CHANGED_NOW"

if [[ "$DOC_ONLY_OK" != "1" ]]; then
  echo "[ERROR] 停止します（ドキュメント以外の変更が混入）。"
  exit 1
fi
```

### 7) 変更があれば「ドキュメントだけ」追加コミットして push（任意）

```bash
DOC_COMMIT="${DOC_COMMIT:-1}"
DOC_PUSH="${DOC_PUSH:-1}"

CHANGED_DOCS="$(git status --porcelain | awk '{print $2}' | sed '/^$/d' || true)"
if [[ -z "$CHANGED_DOCS" ]]; then
  echo "[OK] ドキュメント更新なし"
  exit 0
fi

echo "[INFO] doc files to commit:"
echo "$CHANGED_DOCS"

if [[ "$DOC_COMMIT" != "1" ]]; then
  echo "[INFO] DOC_COMMIT!=1 のため commit はしません。"
  exit 0
fi

# ドキュメントだけをステージ
git add .steering AGENTS.md

# ステージ内容の確認（要点）
git diff --cached --name-only

git commit -m "docs: ステアリング/運用ドキュメントを更新"

if [[ "$DOC_PUSH" == "1" ]]; then
  git push
  echo "[OK] pushed"
else
  echo "[INFO] DOC_PUSH!=1 のため push はしません。"
fi
```

## 完了条件

- `.steering/` と `AGENTS.md` が必要な範囲で更新され、PR差分と乖離していない。
- 無関係なドキュメント編集（全体整形/並び替え）が無い。
- 変更が発生した場合、ドキュメントだけの commit/push が完了している（DOC_COMMIT=1 の場合）。
