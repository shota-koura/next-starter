$ErrorActionPreference = "Stop"

function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

& git status -sb
& git diff --name-only

if (-not $env:VIRTUAL_ENV) {
  if (-not (Test-Path ".venv")) {
    $venvCreated = $false

    if (Get-Command py -ErrorAction SilentlyContinue) {
      & py -3.12 -m venv .venv
      $venvCreated = ($LASTEXITCODE -eq 0)
    }

    if (-not $venvCreated) {
      if (Get-Command uv -ErrorAction SilentlyContinue) {
        Invoke-Native "uv" "venv" ".venv" "--python" "3.12"
        $venvCreated = $true
      } else {
        throw "Python 3.12 venv creation failed and uv is unavailable."
      }
    }

    if (-not $venvCreated) {
      throw "Python 3.12 venv creation failed."
    }
  }

  . .venv\Scripts\Activate.ps1
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
  $pythonPath = (Get-Command python).Source
  Invoke-Native "uv" "pip" "install" "--python" $pythonPath "-r" "requirements-dev.txt"
} else {
  Invoke-Native "python" "-m" "pip" "install" "-U" "pip"
  Invoke-Native "python" "-m" "pip" "install" "-r" "requirements-dev.txt"
}

Invoke-Native "ruff" "check" "."
Invoke-Native "ruff" "format" "--check" "."
Invoke-Native "black" "--check" "."
Invoke-Native "mypy" "voice_typer" "tests"
Invoke-Native "pytest"
Invoke-Native "python" "-m" "voice_typer"
