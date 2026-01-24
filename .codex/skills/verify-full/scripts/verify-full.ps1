$ErrorActionPreference = "Stop"

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

$runBackend = if ($env:RUN_BACKEND) { $env:RUN_BACKEND } else { "auto" }
$runE2E = if ($env:RUN_E2E) { $env:RUN_E2E } else { "0" }

& git status -sb
& git diff --name-only

& npm run fix
& npm run format:check
& npm run lint
& npm run test:ci

if ($runBackend -eq "auto") {
  $changed = & git diff --name-only
  if ($changed -match '^(backend/|pyproject\.toml$|requirements.*\.txt$)') {
    $runBackend = "1"
  } else {
    $runBackend = "0"
  }
}

if ($runBackend -eq "1") {
  $backendDir = Join-Path $root "backend"
  if ((Test-Path (Join-Path $backendDir "Makefile")) -and (Get-Command make -ErrorAction SilentlyContinue)) {
    Push-Location $backendDir
    & make ruff-fix
    & make ruff-format
    & make pyright
    & make pytest
    Pop-Location
  } else {
    Push-Location $backendDir

    if (-not (Test-Path ".venv")) {
      & python3 -m venv .venv
    }

    $activated = $false
    if (-not $env:VIRTUAL_ENV) {
      if ($IsWindows) {
        . .venv\Scripts\Activate.ps1
      } else {
        . .venv/bin/activate
      }
      $activated = $true
    }

    & python -m pip install -U pip
    & pip install -r requirements-dev.txt
    & ruff check --fix .
    & ruff format .
    & pyright
    & python -m pytest

    if ($activated -and (Get-Command deactivate -ErrorAction SilentlyContinue)) {
      deactivate
    }

    Pop-Location
  }
} else {
  Write-Host "[SKIP] Backend checks (RUN_BACKEND=$runBackend)"
}

if ($runE2E -eq "1") {
  & npm run e2e
} else {
  Write-Host "[SKIP] E2E (set RUN_E2E=1 to run)"
}
