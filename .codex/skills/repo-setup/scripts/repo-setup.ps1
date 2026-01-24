$ErrorActionPreference = "Stop"

$skipFrontend = if ($env:SKIP_FRONTEND) { $env:SKIP_FRONTEND } else { "0" }
$skipBackend = if ($env:SKIP_BACKEND) { $env:SKIP_BACKEND } else { "0" }
$runDev = if ($env:RUN_DEV) { $env:RUN_DEV } else { "0" }

function Get-OsKind {
  if ($IsWindows) { return "windows" }
  if ($IsMacOS) { return "macos" }
  if ($IsLinux) {
    if (Test-Path "/proc/version") {
      $ver = Get-Content "/proc/version" -ErrorAction SilentlyContinue
      if ($ver -match "microsoft") { return "wsl" }
    }
    return "linux"
  }
  return "unknown"
}

function Need-Cmd {
  param([string]$name)
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] required command not found: $name"
    exit 1
  }
}

$osKind = Get-OsKind
Write-Host "[INFO] os=$osKind"

Need-Cmd git

if ($skipFrontend -ne "1") {
  Need-Cmd node
  Need-Cmd npm

  $nodeVer = & node -p "process.versions.node" 2>$null
  if (-not [string]::IsNullOrWhiteSpace($nodeVer)) {
    $major = [int]($nodeVer.Split(".")[0])
    if ($major -lt 20) {
      Write-Host "[WARN] Node.js 20.x is recommended. current=$nodeVer"
    }
  }
}

if ($skipBackend -ne "1") {
  Need-Cmd python3

  $pyMajor = [int]((& python3 -c "import sys; print(sys.version_info[0])").Trim())
  $pyMinor = [int]((& python3 -c "import sys; print(sys.version_info[1])").Trim())
  if ($pyMajor -lt 3 -or ($pyMajor -eq 3 -and $pyMinor -lt 10)) {
    Write-Host "[WARN] Python 3.10+ is recommended. current=$pyMajor.$pyMinor"
  }

  & python3 -c "import venv" *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] python3 venv module is unavailable (python3 -m venv fails)."
    if ($osKind -eq "linux" -or $osKind -eq "wsl") {
      if (Get-Command apt-get -ErrorAction SilentlyContinue) {
        Write-Host "[HINT] Ubuntu/Debian: sudo apt update && sudo apt install -y python3-venv"
      }
    }
    exit 1
  }

  & python3 -m pip --version *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] pip is unavailable (python3 -m pip fails)."
    if ($osKind -eq "linux" -or $osKind -eq "wsl") {
      if (Get-Command apt-get -ErrorAction SilentlyContinue) {
        Write-Host "[HINT] Ubuntu/Debian: sudo apt update && sudo apt install -y python3-pip"
      }
    }
    exit 1
  }
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
  $ghVersion = & gh --version | Select-Object -First 1
  Write-Host "[OK] gh found: $ghVersion"
} else {
  Write-Host "[WARN] gh (GitHub CLI) not found. PR/CI skills require gh (e.g., pr-flow)."
  Write-Host "[HINT] install gh:"
  switch ($osKind) {
    "macos" { Write-Host "  brew install gh" }
    "linux" { Write-Host "  sudo apt update && sudo apt install -y gh (or distro package manager)" }
    "wsl" { Write-Host "  sudo apt update && sudo apt install -y gh (or distro package manager)" }
    "windows" {
      Write-Host "  winget install --id GitHub.cli"
      Write-Host "  (or) choco install gh"
    }
    default { Write-Host "  install GitHub CLI (gh) for your OS" }
  }
  Write-Host "[HINT] after install:"
  Write-Host "  gh --version"
  Write-Host "  gh auth login"
  Write-Host "  gh auth status"
}

if (-not (Get-Command tree -ErrorAction SilentlyContinue)) {
  Write-Host "[WARN] tree command not found. precommit uses scripts/tree.sh."
  Write-Host "[HINT] install tree:"
  switch ($osKind) {
    "macos" { Write-Host "  brew install tree" }
    "linux" { Write-Host "  sudo apt update && sudo apt install -y tree (or distro package manager)" }
    "wsl" { Write-Host "  sudo apt update && sudo apt install -y tree (or distro package manager)" }
    "windows" { Write-Host "  use WSL (recommended) or install a tree utility compatible with bash scripts" }
    default { Write-Host "  install tree for your OS" }
  }
}

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
  Write-Host "[WARN] rg (ripgrep) not found. dedupe skill recommends it."
  Write-Host "[HINT] install ripgrep (rg):"
  switch ($osKind) {
    "macos" { Write-Host "  brew install ripgrep" }
    "linux" { Write-Host "  sudo apt update && sudo apt install -y ripgrep (or distro package manager)" }
    "wsl" { Write-Host "  sudo apt update && sudo apt install -y ripgrep (or distro package manager)" }
    "windows" {
      Write-Host "  winget install --id BurntSushi.ripgrep.MSVC"
      Write-Host "  (or) choco install ripgrep"
    }
    default { Write-Host "  install ripgrep for your OS" }
  }
}

if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
  Write-Host "[WARN] jq not found. PR/CI skills use jq (e.g., pr-flow, pr-fix-loop)."
  Write-Host "[HINT] install jq:"
  switch ($osKind) {
    "macos" { Write-Host "  brew install jq" }
    "linux" { Write-Host "  sudo apt update && sudo apt install -y jq (or distro package manager)" }
    "wsl" { Write-Host "  sudo apt update && sudo apt install -y jq (or distro package manager)" }
    "windows" {
      Write-Host "  winget install --id jqlang.jq"
      Write-Host "  (or) choco install jq"
    }
    default { Write-Host "  install jq for your OS" }
  }
}

if (-not [string]::IsNullOrWhiteSpace($env:REPO_URL)) {
  if ([string]::IsNullOrWhiteSpace($env:TARGET_DIR)) {
    Write-Host "[ERROR] REPO_URL を指定した場合は TARGET_DIR が必須です。"
    Write-Host '例: export TARGET_DIR="next-starter-local"'
    exit 1
  }

  if (Test-Path $env:TARGET_DIR) {
    Write-Host "[ERROR] TARGET_DIR が既に存在します: $env:TARGET_DIR"
    exit 1
  }

  Write-Host "[INFO] git clone: $env:REPO_URL -> $env:TARGET_DIR"
  & git clone $env:REPO_URL $env:TARGET_DIR
  Set-Location $env:TARGET_DIR
} else {
  $root = (& git rev-parse --show-toplevel 2>$null).Trim()
  if ([string]::IsNullOrWhiteSpace($root)) {
    Write-Host "[ERROR] git リポジトリ配下ではありません。"
    Write-Host "[HINT] clone 済みのディレクトリで実行するか、REPO_URL/TARGET_DIR を指定してください。"
    exit 1
  }
  Set-Location $root
}

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root
Write-Host "[INFO] repo root: $root"

if ($skipFrontend -ne "1") {
  Write-Host "[STEP] Frontend: npm install"
  & npm install

  Write-Host "[STEP] Frontend: npm run format"
  & npm run format

  Write-Host "[STEP] Frontend: npm run check"
  & npm run check
} else {
  Write-Host "[SKIP] Frontend setup"
}

if ($skipBackend -ne "1") {
  Write-Host "[STEP] Backend: create venv (if missing) + install deps"
  Set-Location (Join-Path $root "backend")

  if (-not (Test-Path ".venv")) {
    & python3 -m venv .venv
  }

  if ($IsWindows) {
    . .venv\Scripts\Activate.ps1
  } else {
    . .venv/bin/activate
  }

  & python -m pip install -U pip
  & pip install -r requirements-dev.txt

  Write-Host "[STEP] Backend: ruff check --fix ."
  & ruff check --fix .

  Write-Host "[STEP] Backend: ruff format ."
  & ruff format .

  Write-Host "[STEP] Backend: pyright"
  & pyright

  Write-Host "[STEP] Backend: pytest"
  & python -m pytest

  if (Get-Command deactivate -ErrorAction SilentlyContinue) {
    deactivate
  }
  Set-Location $root
} else {
  Write-Host "[SKIP] Backend setup"
}

Write-Host "[STEP] git status check"
& git status -sb

$dirty = & git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
  Write-Host "[WARN] セットアップ実行により差分が発生しています。内容を確認してください。"
  Write-Host "[INFO] changed files:"
  $dirty -split "`n" | ForEach-Object {
    if ($_.Length -ge 4) { $_.Substring(3) }
  }
} else {
  Write-Host "[INFO] working tree clean"
}

if ($runDev -ne "1") {
  Write-Host "[NEXT] 開発サーバ起動（別ターミナル推奨）"
  Write-Host ""
  Write-Host "Frontend:"
  Write-Host "  npm run dev"
  Write-Host "  http://localhost:3000"
  Write-Host ""
  Write-Host "Backend:"
  Write-Host "  cd backend"
  Write-Host "  source .venv/bin/activate"
  Write-Host "  uvicorn app:app --reload --port 8000"
  Write-Host "  http://localhost:8000/health"
  exit 0
}

Write-Host "[STEP] RUN_DEV=1: start backend (background) then frontend (foreground)"

$uvicornPath = if ($IsWindows) {
  Join-Path $root "backend/.venv/Scripts/uvicorn.exe"
} else {
  Join-Path $root "backend/.venv/bin/uvicorn"
}

if (Test-Path $uvicornPath) {
  Start-Process -FilePath $uvicornPath -ArgumentList "app:app --reload --port 8000" -WorkingDirectory (Join-Path $root "backend")
  Write-Host "[INFO] backend started (background)"
} else {
  Write-Host "[WARN] uvicorn not found at $uvicornPath. Start backend manually."
}

Write-Host "[STEP] start frontend (foreground)"
& npm run dev
