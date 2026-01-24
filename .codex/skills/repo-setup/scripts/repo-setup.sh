#!/usr/bin/env bash
set -euo pipefail

SKIP_FRONTEND="${SKIP_FRONTEND:-0}"
SKIP_BACKEND="${SKIP_BACKEND:-0}"
RUN_DEV="${RUN_DEV:-0}"

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
  echo "[WARN] jq not found. PR/CI skills use jq (e.g., pr-flow, pr-fix-loop)."
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

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
echo "[INFO] repo root: $(pwd)"

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

if [[ "$SKIP_BACKEND" != "1" ]]; then
  echo "[STEP] Backend: create venv (if missing) + install deps"
  cd "$ROOT/backend"

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

if [[ "$RUN_DEV" != "1" ]]; then
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
  exit 0
fi

echo "[STEP] RUN_DEV=1: start backend (background) then frontend (foreground)"

(
  cd "$ROOT/backend"
  . .venv/bin/activate
  .venv/bin/uvicorn app:app --reload --port 8000
) &

echo "[INFO] backend started (background)"
echo "[STEP] start frontend (foreground)"
npm run dev
