---
name: repo-setup
description: git clone（任意）後に Frontend/Backend の初期セットアップと「Recommended first run」を実行し、必要ツール（gh, coderabbit, codex-reviewer, supabase, vercel, playwright等）を検知して不足時はOS別インストール手順を提示する
---

## 目的

- README.md の「Quick Start」「Recommended first run（初回セットアップの推奨手順）」を、ターミナルで再現可能な定型手順として固定する。
- clone 直後に依存関係導入と静的解析/テストを一通り通し、クリーンな状態で開発を開始できるようにする。
- PR/CI 運用に必要な `gh` と、補助 CLI（`coderabbit`, `supabase`, `vercel`, `playwright`）および custom agent（`codex-reviewer`）の存在確認を行い、未導入なら OS を判定してインストール手順を提示する。

## いつ使うか

- 新しいPC/環境で、このリポジトリを初めて clone した直後。
- `.venv` や `node_modules` が無い状態から、まとめて初期セットアップしたいとき。

## 前提

- OS は bash または PowerShell が使える環境（例: macOS / Linux / WSL / Windows）。
- ネットワーク接続があり、npm/pip のインストールができること。
- 次のコマンドが使えること（不足時はこの skill が検知して案内する）:
  - `git`
  - `node` / `npm`（Frontend を実行する場合）
  - `python3`（Backend を実行する場合）
  - `python3 -m pip` / `python3 -m venv`（Backend を実行する場合）
- `gh` は PR/CI 運用に必要（repo-setup では未導入でも実行は継続し、手順だけ提示する）。
- `tree` は `scripts/tree.sh` に必要（repo-setup では未導入でも実行は継続し、手順だけ提示する）。
- `rg` は `$dedupe` に推奨（repo-setup では未導入でも実行は継続し、手順だけ提示する）。
- `jq` は PR/CI スキル（`pr-flow` / `pr-review-merge`）で使用（repo-setup では未導入でも実行は継続し、手順だけ提示する）。
- `coderabbit` は PR 前の pre-review に使う（repo-setup では未導入でも実行は継続し、手順だけ提示する）。
- `codex-reviewer` は `change-review` と標準 `pr-flow` に必要な custom agent（repo-setup では未導入でも実行は継続し、配置場所と不足を案内する）。
- `supabase` は Supabase ローカル開発や型生成で便利（repo-setup では未導入でも実行は継続し、手順だけ提示する）。
- `vercel` は env pull や deploy 確認で便利（repo-setup では未導入でも実行は継続し、手順だけ提示する）。
- `playwright` は E2E の再実行や trace 確認で便利。基本は MCP を優先してよいが、CLI も利用可能にしておくと検証が安定する。

## 環境変数

### clone をこの skill に含める場合（任意）

- `REPO_URL`
  - clone するリポジトリURL（例: `https://github.com/org/next-starter.git`）
- `TARGET_DIR`
  - clone 先のローカルディレクトリ名（例: `next-starter-local`）
  - 「git clone の末尾に指定するローカルディレクトリ名」に相当

### 実行オプション（任意）

- `SKIP_FRONTEND`
  - `1` の場合、Frontend セットアップをスキップ（デフォルト `0`）
- `SKIP_BACKEND`
  - `1` の場合、Backend セットアップをスキップ（デフォルト `0`）
- `RUN_DEV`
  - `1` の場合、最後に起動コマンドを「提示」ではなく「起動」まで行う（デフォルト `0`）
  - 注意: `RUN_DEV=1` はプロセスが起動し続けるため、ターミナルを占有する

## 使い方

### A) clone からセットアップまで 1 回でやる（推奨）

```bash
export REPO_URL="https://github.com/<org>/<repo>.git"
export TARGET_DIR="my-local-dir"
$repo-setup
```

### B) すでに clone 済みのディレクトリで実行する

```bash
cd <cloned-dir>
$repo-setup
```

## 1コマンド実行（推奨）

次を実行する。

```bash
bash .codex/skills/repo-setup/scripts/repo-setup.sh
```

Windows ネイティブ（PowerShell）の場合:

```powershell
pwsh -File .codex/skills/repo-setup/scripts/repo-setup.ps1
```

- 環境変数（`REPO_URL` / `TARGET_DIR` / `SKIP_FRONTEND` / `SKIP_BACKEND` / `RUN_DEV`）は同様に有効。

## 手順

### 0) 前提コマンドと custom agent の検知（gh を含む）

```bash
set -euo pipefail

SKIP_FRONTEND="${SKIP_FRONTEND:-0}"
SKIP_BACKEND="${SKIP_BACKEND:-0}"

detect_os() {
  local u
  u="$(uname -s 2>/dev/null || echo unknown)"

  case "$u" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

need_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "[ERROR] required command not found: $c"
    exit 1
  fi
}

warn_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "[WARN] optional command not found: $c"
    return 1
  fi
  return 0
}

OS_KIND="$(detect_os)"
echo "[INFO] os=$OS_KIND"

need_cmd git

if [[ "$SKIP_FRONTEND" != "1" ]]; then
  need_cmd node
  need_cmd npm

  NODE_VER="$(node -p "process.versions.node" 2>/dev/null || true)"
  if [[ -n "$NODE_VER" ]]; then
    NODE_MAJOR="${NODE_VER%%.*}"
    if [[ "$NODE_MAJOR" -lt 20 ]]; then
      echo "[WARN] Node.js 20.x is recommended. current=$NODE_VER"
    fi
  fi
fi

if [[ "$SKIP_BACKEND" != "1" ]]; then
  need_cmd python3

  PY_MAJOR="$(python3 -c 'import sys; print(sys.version_info[0])')"
  PY_MINOR="$(python3 -c 'import sys; print(sys.version_info[1])')"
  if [[ "$PY_MAJOR" -lt 3 || ( "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 10 ) ]]; then
    echo "[WARN] Python 3.10+ is recommended. current=${PY_MAJOR}.${PY_MINOR}"
  fi

  if ! python3 -c "import venv" >/dev/null 2>&1; then
    echo "[ERROR] python3 venv module is unavailable (python3 -m venv fails)."
    if [[ "$OS_KIND" == "linux" || "$OS_KIND" == "wsl" ]]; then
      if command -v apt-get >/dev/null 2>&1; then
        echo "[HINT] Ubuntu/Debian: sudo apt update && sudo apt install -y python3-venv"
      fi
    fi
    exit 1
  fi

  if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "[ERROR] pip is unavailable (python3 -m pip fails)."
    if [[ "$OS_KIND" == "linux" || "$OS_KIND" == "wsl" ]]; then
      if command -v apt-get >/dev/null 2>&1; then
        echo "[HINT] Ubuntu/Debian: sudo apt update && sudo apt install -y python3-pip"
      fi
    fi
    exit 1
  fi
fi

# gh: PR/CI運用で必要。repo-setup自体は継続するが、未導入なら手順提示する。
if command -v gh >/dev/null 2>&1; then
  echo "[OK] gh found: $(gh --version | head -n 1)"
else
  echo "[WARN] gh (GitHub CLI) not found. PR/CI skills require gh (e.g., pr-flow)."
  echo "[HINT] install gh:"
  case "$OS_KIND" in
    macos)
      echo "  brew install gh"
      ;;
    linux|wsl)
      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt update && sudo apt install -y gh"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install -y gh"
      elif command -v pacman >/dev/null 2>&1; then
        echo "  sudo pacman -S github-cli"
      else
        echo "  install via your distribution package manager"
      fi
      ;;
    windows)
      echo "  winget install --id GitHub.cli"
      echo "  (or) choco install gh"
      ;;
    *)
      echo "  install GitHub CLI (gh) for your OS"
      ;;
  esac
  echo "[HINT] after install:"
  echo "  gh --version"
  echo "  gh auth login"
  echo "  gh auth status"
fi

# tree: precommitで使用（scripts/tree.sh）。repo-setupは継続するが、未導入なら手順提示する。
if ! command -v tree >/dev/null 2>&1; then
  echo "[WARN] tree command not found. precommit uses scripts/tree.sh."
  echo "[HINT] install tree:"
  case "$OS_KIND" in
    macos) echo "  brew install tree" ;;
    linux|wsl)
      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt update && sudo apt install -y tree"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install -y tree"
      elif command -v pacman >/dev/null 2>&1; then
        echo "  sudo pacman -S tree"
      else
        echo "  install via your distribution package manager"
      fi
      ;;
    windows)
      echo "  use WSL (recommended) or install a tree utility compatible with bash scripts"
      ;;
    *)
      echo "  install tree for your OS"
      ;;
  esac
fi

# rg: dedupeで推奨。repo-setupは継続する。
if ! command -v rg >/dev/null 2>&1; then
  echo "[WARN] rg (ripgrep) not found. dedupe skill recommends it."
  echo "[HINT] install ripgrep (rg):"
  case "$OS_KIND" in
    macos) echo "  brew install ripgrep" ;;
    linux|wsl)
      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt update && sudo apt install -y ripgrep"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install -y ripgrep"
      elif command -v pacman >/dev/null 2>&1; then
        echo "  sudo pacman -S ripgrep"
      else
        echo "  install via your distribution package manager"
      fi
      ;;
    windows)
      echo "  winget install --id BurntSushi.ripgrep.MSVC"
      echo "  (or) choco install ripgrep"
      ;;
    *)
      echo "  install ripgrep for your OS"
      ;;
  esac
fi

# jq: PR/CIスキルで使用。repo-setupは継続する。
if ! command -v jq >/dev/null 2>&1; then
  echo "[WARN] jq not found. PR/CI skills use jq (e.g., pr-flow, pr-review-merge)."
  echo "[HINT] install jq:"
  case "$OS_KIND" in
    macos) echo "  brew install jq" ;;
    linux|wsl)
      if command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt update && sudo apt install -y jq"
      elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install -y jq"
      elif command -v pacman >/dev/null 2>&1; then
        echo "  sudo pacman -S jq"
      else
        echo "  install via your distribution package manager"
      fi
      ;;
    windows)
      echo "  winget install --id jqlang.jq"
      echo "  (or) choco install jq"
      ;;
    *)
      echo "  install jq for your OS"
      ;;
  esac
fi

# coderabbit: 任意だが pre-review workflow で便利。repo-setup は継続する。
if command -v coderabbit >/dev/null 2>&1; then
  echo "[OK] coderabbit found"
else
  echo "[WARN] coderabbit CLI not found. PR前の pre-review workflow may use it."
  echo "[HINT] install CodeRabbit CLI:"
  case "$OS_KIND" in
    macos|linux|wsl) echo "  curl -fsSL https://cli.coderabbit.ai/install.sh | sh" ;;
    windows) echo "  see https://docs.coderabbit.ai/cli for the latest install steps" ;;
    *) echo "  install CodeRabbit CLI for your OS" ;;
  esac
fi

# codex-reviewer: change-review / pr-flow で必要な custom agent。repo-setup は継続する。
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_REVIEWER_PATH="$CODEX_HOME_DIR/agents/codex-reviewer.toml"
if [[ -f "$CODEX_REVIEWER_PATH" ]]; then
  echo "[OK] codex-reviewer agent found: $CODEX_REVIEWER_PATH"
else
  echo "[WARN] codex-reviewer agent not found. change-review / pr-flow require it."
  echo "[HINT] install codex-reviewer.toml into:"
  echo "  $CODEX_REVIEWER_PATH"
  echo "[HINT] if your team manages shared agents outside this repo, copy or install codex-reviewer.toml there before using pr-flow."
fi

# supabase: 任意だが local/dev workflow で便利。repo-setup は継続する。
if command -v supabase >/dev/null 2>&1; then
  echo "[OK] supabase found: $(supabase --version | head -n 1)"
else
  echo "[WARN] supabase CLI not found. Local Supabase workflows and type generation use it."
  echo "[HINT] install supabase CLI:"
  case "$OS_KIND" in
    macos) echo "  brew install supabase/tap/supabase" ;;
    linux|wsl) echo "  see https://supabase.com/docs/guides/cli/getting-started" ;;
    windows) echo "  scoop install supabase" ;;
    *) echo "  install Supabase CLI for your OS" ;;
  esac
fi

# vercel: 任意だが env/deploy workflow で便利。repo-setup は継続する。
if command -v vercel >/dev/null 2>&1; then
  echo "[OK] vercel found: $(vercel --version | head -n 1)"
else
  echo "[WARN] vercel CLI not found. Deploy/env workflows may require it."
  echo "[HINT] install vercel CLI:"
  case "$OS_KIND" in
    macos|linux|wsl) echo "  npm install -g vercel" ;;
    windows) echo "  npm install -g vercel" ;;
    *) echo "  install Vercel CLI for your OS" ;;
  esac
fi

# playwright: CLI がなくても npx で動くことがあるが、あると再実行しやすい。
if command -v playwright >/dev/null 2>&1; then
  echo "[OK] playwright found: $(playwright --version | head -n 1)"
else
  echo "[WARN] playwright CLI not found. E2E reruns can still use npx if the package is installed."
  echo "[HINT] install Playwright CLI:"
  case "$OS_KIND" in
    macos|linux|wsl) echo "  npm install -g playwright" ;;
    windows) echo "  npm install -g playwright" ;;
    *) echo "  install Playwright CLI for your OS" ;;
  esac
fi
```

### 1) 作業ディレクトリ確定（clone する場合は clone して移動）

```bash
set -euo pipefail

if [[ -n "${REPO_URL:-}" ]]; then
  if [[ -z "${TARGET_DIR:-}" ]]; then
    echo "[ERROR] REPO_URL を指定した場合は TARGET_DIR が必須です。"
    echo '例: export TARGET_DIR="next-starter-local"'
    exit 1
  fi

  if [[ -e "$TARGET_DIR" ]]; then
    echo "[ERROR] TARGET_DIR が既に存在します: $TARGET_DIR"
    exit 1
  fi

  echo "[INFO] git clone: $REPO_URL -> $TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
  cd "$TARGET_DIR"
else
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    ROOT="$(git rev-parse --show-toplevel)"
    cd "$ROOT"
  else
    echo "[ERROR] git リポジトリ配下ではありません。"
    echo "[HINT] clone 済みのディレクトリで実行するか、REPO_URL/TARGET_DIR を指定してください。"
    exit 1
  fi
fi

echo "[INFO] repo root: $(pwd)"
```

### 2) Frontend setup（README: npm install / format / check）

README の「Recommended first run（Frontend setup）」を実行する。

```bash
set -euo pipefail

SKIP_FRONTEND="${SKIP_FRONTEND:-0}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ "$SKIP_FRONTEND" != "1" ]]; then
  echo "[STEP] Frontend: npm install"
  npm install

  echo "[STEP] Frontend: npm run format"
  npm run format

  echo "[STEP] Frontend: npm run check"
  npm run check
else
  echo "[SKIP] Frontend setup"
fi
```

### 3) Backend setup（README: venv 作成 / pip install / ruff/pyright/pytest）

README の「Recommended first run（Backend setup）」を実行する。

```bash
set -euo pipefail

SKIP_BACKEND="${SKIP_BACKEND:-0}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ "$SKIP_BACKEND" != "1" ]]; then
  echo "[STEP] Backend: create venv (if missing) + install deps"
  cd backend

  if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
  fi

  . .venv/bin/activate
  python -m pip install -U pip
  pip install -r requirements-dev.txt

  echo "[STEP] Backend: ruff check --fix ."
  ruff check --fix .

  echo "[STEP] Backend: ruff format ."
  ruff format .

  echo "[STEP] Backend: pyright"
  pyright

  echo "[STEP] Backend: pytest"
  python -m pytest

  deactivate
  cd "$ROOT"
else
  echo "[SKIP] Backend setup"
fi
```

### 4) 初回整形の結果確認（差分が増えていないか）

初回セットアップの実行で差分が出る場合があるため、機械的に検知して表示する。

```bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "[STEP] git status check"
git status -sb

DIRTY="$(git status --porcelain || true)"
if [[ -n "$DIRTY" ]]; then
  echo "[WARN] セットアップ実行により差分が発生しています。内容を確認してください。"
  echo "[INFO] changed files:"
  echo "$DIRTY" | sed -E 's/^.. //'
else
  echo "[INFO] working tree clean"
fi
```

### 5) 開発サーバ起動（提示 or 起動）

README の「Quick Start」に沿った起動コマンドを案内する。

#### 5.1 起動コマンドの提示（デフォルト）

```bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ "${RUN_DEV:-0}" != "1" ]]; then
  echo "[NEXT] 開発サーバ起動（別ターミナル推奨）"
  echo
  echo "Frontend:"
  echo "  npm run dev"
  echo "  http://localhost:3000"
  echo
  echo "Backend:"
  echo "  cd backend"
  echo "  source .venv/bin/activate"
  echo "  uvicorn app:app --reload --port 8000"
  echo "  http://localhost:8000/health"
fi
```

#### 5.2 起動まで行う（RUN_DEV=1 の場合）

- backend をバックグラウンド起動し、その後 frontend をフォアグラウンド起動する。
- 終了時は Ctrl-C（frontend 停止）後に backend プロセスを手動で止めること。

```bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ "${RUN_DEV:-0}" == "1" ]]; then
  echo "[STEP] RUN_DEV=1: start backend (background) then frontend (foreground)"

  (
    cd backend
    . .venv/bin/activate
    .venv/bin/uvicorn app:app --reload --port 8000
  ) &

  echo "[INFO] backend started (background)"
  echo "[STEP] start frontend (foreground)"
  npm run dev
fi
```

## 完了条件

- Frontend:
  - `npm install` が成功している
  - `npm run format` が成功している
  - `npm run check` が成功している

- Backend:
  - `backend/.venv` が作成されている
  - `pip install -r requirements-dev.txt` が成功している
  - `ruff check --fix .` / `ruff format .` / `pyright` / `pytest` が成功している

- `gh` が未導入なら、OS別のインストール手順が提示されている
- 必要に応じて開発サーバを起動できる状態になっている（起動コマンドを提示済み、または `RUN_DEV=1` で起動済み）
