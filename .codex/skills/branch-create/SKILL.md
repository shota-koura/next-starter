---
name: branch-create
description: ブランチ作成の際に、ステアリング名または作業意図から自動生成してブランチを作成する
---

## 目的

- Codex がブランチ名を質問して停止する状況をなくす。
- 「ステアリング作業はステアリング名をブランチ名にする」「ステアリング無しの小改修は意図から自動命名」を一貫した手順で実行する。
- ブランチ作成時に base（main など）を最新化してから切る。

## いつ使うか

- 新しい作業を始めるとき。
- 作業着手前（ファイル編集前）にブランチを作りたいとき。
- ステアリング作業（`.steering/<dir>/...`）を開始するタイミング。
- ステアリング無しの小改修（例: `.codex/config.toml` など）で、ブランチを自動で切りたいとき。

## ガードレール（必須）

- ブランチ名についてユーザーへ質問しない（本 skill のロジックで決めて進める）。
- working tree が clean でない場合は停止し、何が残っているかだけを提示して終了する（勝手に stash/commit しない）。
- base ブランチ（通常 main）を最新化してからブランチを切る（`git pull --ff-only`）。
- 既存ブランチ名と衝突する場合は `-2`, `-3`… を付与して回避する（ユーザーに確認しない）。

## 入力（任意の上書き）

- `BRANCH_TYPE` : `feat|fix|docs|chore`（未指定なら自動推定）
- `BRANCH_NAME` : 作業スラッグ（未指定なら自動推定。ここに `feat/` などの接頭辞は含めない）
- `REQUEST_TEXT` : ユーザー依頼文（ブランチ種別の推定に使用）
- `STEERING_DIR` : `.steering/<dir>` を明示したい場合（未指定なら自動検出）
- `BASE_BRANCH` : 既定 `main`（無ければ自動で `main` にフォールバック）
- `REMOTE` : 既定 `origin`

## ブランチ名の決め方（優先順位）

1. `BRANCH_NAME` が指定されていればそれを使う。
2. `STEERING_DIR` が指定されていれば、その basename を使う（例: `.steering/1.0-20250115-add-tag-feature` -> `add-tag-feature`）。
3. `.steering/` 配下に複数ある場合は停止し、`STEERING_DIR` を明示する。
4. それでも決まらない場合（ステアリング無し）:推定してブランチ名を確定する

## ブランチ種別（type）の決め方（未指定時）

- まずユーザー指示の意図から推定する（キーワードベース、質問しない）。
  - `fix` : `fix`, `bug`, `不具合`, `修正`, `エラー` を含む
  - `docs` : `docs`, `README`, `.md`, `ドキュメント`, `議事録`, `設計書` を含む
  - `chore`: `config`, `tool`, `.codex`, `CI`, `lint`, `format`, `deps`, `依存`, `設定` を含む
  - それ以外は `feat`

## 手順

### 0) 状態確認（必須）

```bash
git status -sb
DIRTY="$(git status --porcelain || true)"
if [[ -n "$DIRTY" ]]; then
  echo "[ERROR] working tree is not clean. Resolve these changes first:"
  echo "$DIRTY"
  exit 1
fi
```

未コミット変更がある場合は停止する（stash/commit/破棄の判断が必要）。

### 1) base ブランチを決定して最新化（必須）

```bash
REMOTE="${REMOTE:-origin}"
BASE_BRANCH="${BASE_BRANCH:-main}"

# BASE_BRANCH が無ければ main にフォールバック（質問しない）
if ! git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
  if git show-ref --verify --quiet "refs/heads/main"; then
    BASE_BRANCH="main"
  fi
fi

git switch "${BASE_BRANCH}"
git pull --ff-only "${REMOTE}" "${BASE_BRANCH}"
```

### 2) STEERING_DIR / BRANCH_NAME を自動推定（必須）

```bash
# STEERING_DIR を自動検出（指定済みならそのまま）
STEERING_DIR="${STEERING_DIR:-}"
if [[ -z "$STEERING_DIR" ]]; then
  mapfile -t STEERING_DIRS < <(ls -d .steering/*/ 2>/dev/null)
  if [[ "${#STEERING_DIRS[@]}" -gt 1 ]]; then
    echo "[ERROR] steering dirs are multiple. Set STEERING_DIR explicitly."
    exit 1
  fi
  if [[ "${#STEERING_DIRS[@]}" -eq 1 ]]; then
    STEERING_DIR="${STEERING_DIRS[0]%/}"
  fi
fi

# BRANCH_NAME を決定
if [[ -z "$BRANCH_NAME" && -n "$STEERING_DIR" ]]; then
  BASE_NAME="$(basename "$STEERING_DIR")"
  if [[ "$BASE_NAME" =~ ^[0-9.]+-[0-9]{8}-(.+)$ ]]; then
    BRANCH_NAME="${BASH_REMATCH[1]}"
  else
    BRANCH_NAME="$BASE_NAME"
  fi
fi

# まだ空なら意図から簡易推定
BRANCH_NAME="${BRANCH_NAME:-misc-update}"
```

### 3) BRANCH_TYPE を自動推定（必須）

```bash
REQUEST_TEXT="${REQUEST_TEXT:-}"
if [[ -z "$BRANCH_TYPE" ]]; then
  if echo "$REQUEST_TEXT" | grep -Eqi 'fix|bug|不具合|修正|エラー'; then
    BRANCH_TYPE="fix"
  elif echo "$REQUEST_TEXT" | grep -Eqi 'docs|README|\.md|ドキュメント|議事録|設計書'; then
    BRANCH_TYPE="docs"
  elif echo "$REQUEST_TEXT" | grep -Eqi 'config|tool|\.codex|CI|lint|format|deps|依存|設定'; then
    BRANCH_TYPE="chore"
  else
    BRANCH_TYPE="feat"
  fi
fi
```

### 4) 衝突回避してブランチ作成（必須）

```bash
branch_exists() {
  git show-ref --verify --quiet "refs/heads/$1" && return 0
  git show-ref --verify --quiet "refs/remotes/${REMOTE}/$1"
}

BRANCH_SLUG="$BRANCH_NAME"
BRANCH_FULL="${BRANCH_TYPE}/${BRANCH_SLUG}"

if branch_exists "$BRANCH_FULL"; then
  i=2
  while branch_exists "${BRANCH_TYPE}/${BRANCH_NAME}-${i}"; do
    i=$((i+1))
  done
  BRANCH_SLUG="${BRANCH_NAME}-${i}"
  BRANCH_FULL="${BRANCH_TYPE}/${BRANCH_SLUG}"
fi
```

#### 1. git alias が使えるならそれを使う（推奨）

- `git feat <slug>` -> `feat/<slug>`
- `git fix <slug>` -> `fix/<slug>`
- `git docs <slug>` -> `docs/<slug>`
- `git chore <slug>` -> `chore/<slug>`

例:

```bash
if git config --get "alias.${BRANCH_TYPE}" >/dev/null; then
  git "${BRANCH_TYPE}" "${BRANCH_SLUG}"
else
  echo "[INFO] alias not found. Use fallback below."
fi

```

#### 2. alias が無い場合のフォールバック

- `BASE_BRANCH` / `REMOTE` を使って base を揃える。

```bash
git switch "${BASE_BRANCH}"
git pull --ff-only "${REMOTE}" "${BASE_BRANCH}"
git switch -c "${BRANCH_FULL}" "${BASE_BRANCH}"

```

## 例

- ステアリング作業（ステアリング名を使う）:
  - `.steering/1.0-20260125-update-steering-flow/` がある場合
  - `update-steering-flow`

- ステアリング無しの改修（編集作業の意図から自動命名）:
  - `feat/misc-update`（例）

## 完了条件

- working tree が clean のまま、base を最新化したうえで新規ブランチへ checkout 済み。
- ブランチ名は推定ロジックに従い、ユーザーへ質問せずに確定している。
- `git rev-parse --abbrev-ref HEAD` が新規ブランチ名を返す。
