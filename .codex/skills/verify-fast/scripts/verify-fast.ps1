$ErrorActionPreference = "Stop"

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

$runFrontend = if ($env:RUN_FRONTEND) { $env:RUN_FRONTEND } else { "auto" }
$runBackend = if ($env:RUN_BACKEND) { $env:RUN_BACKEND } else { "auto" }
$runTest = if ($env:RUN_TEST) { $env:RUN_TEST } else { "0" }
$runPytest = if ($env:RUN_PYTEST) { $env:RUN_PYTEST } else { "0" }

& git status -sb
& git diff --name-only

$changed = & git diff --name-only

if ($runFrontend -eq "auto") {
  if ($changed -match '^(app/|components/|lib/|__tests__/|e2e/)') {
    $runFrontend = "1"
  } else {
    $runFrontend = "0"
  }
}

if ($runBackend -eq "auto") {
  if ($changed -match '^(backend/|pyproject\.toml$|requirements.*\.txt$)') {
    $runBackend = "1"
  } else {
    $runBackend = "0"
  }
}

if ($runFrontend -eq "1") {
  & npm run format:check
  & npm run lint
  if ($runTest -eq "1") {
    & npm run test:ci
  } else {
    Write-Host "[SKIP] Frontend tests (set RUN_TEST=1 to run)"
  }
} else {
  Write-Host "[SKIP] Frontend checks (RUN_FRONTEND=$runFrontend)"
}

if ($runBackend -eq "1") {
  $backendDir = Join-Path $root "backend"
  if ((Test-Path (Join-Path $backendDir "Makefile")) -and (Get-Command make -ErrorAction SilentlyContinue)) {
    Push-Location $backendDir
    & make ruff-format-check
    & make ruff-check
    if ($runPytest -eq "1") {
      & make pytest
    } else {
      Write-Host "[SKIP] Backend tests (set RUN_PYTEST=1 to run)"
    }
    Pop-Location
  } else {
    Push-Location $backendDir

    $activated = $false
    if (-not $env:VIRTUAL_ENV) {
      if (Test-Path ".venv") {
        if ($IsWindows) {
          . .venv\Scripts\Activate.ps1
        } else {
          . .venv/bin/activate
        }
        $activated = $true
      } else {
        Write-Host "[ERROR] backend/.venv not found. Create venv before backend checks."
        exit 1
      }
    }

    & ruff format --check .
    & ruff check .
    if ($runPytest -eq "1") {
      & python -m pytest
    } else {
      Write-Host "[SKIP] Backend tests (set RUN_PYTEST=1 to run)"
    }

    if ($activated -and (Get-Command deactivate -ErrorAction SilentlyContinue)) {
      deactivate
    }

    Pop-Location
  }
} else {
  Write-Host "[SKIP] Backend checks (RUN_BACKEND=$runBackend)"
}
