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

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
GLOBAL_AGENT_DIR="$CODEX_HOME_DIR/agents"
LOCAL_AGENT_DIR="$ROOT/.codex/agents"

check_agent() {
  local agent_name="$1"
  local purpose="$2"
  local global_path="$GLOBAL_AGENT_DIR/${agent_name}.toml"
  local local_path="$LOCAL_AGENT_DIR/${agent_name}.toml"

  if [[ -f "$global_path" ]]; then
    echo "[OK] ${agent_name} agent found: $global_path"
  elif [[ -f "$local_path" ]]; then
    echo "[OK] ${agent_name} repo-local agent found: $local_path"
    echo "[HINT] if your Codex environment requires global agents, copy it to:"
    echo "  $global_path"
  else
    echo "[WARN] ${agent_name} agent not found. ${purpose}"
    echo "[HINT] install ${agent_name}.toml into:"
    echo "  $global_path"
  fi
}

check_agent "codex-reviewer" "change-review / pr-flow require it."
check_agent "planning-reviewer" "planning skills use it for requirements / tasklist / implementation-plan review."
check_agent "code-mapper" "autonomous-steering and planning skills use it for impact mapping."
check_agent "autonomous-orchestrator" "autonomous-steering requires it."

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
