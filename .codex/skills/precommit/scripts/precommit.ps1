$ErrorActionPreference = "Stop"

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

& git status -sb
& git diff --name-only

& npm run precommit

$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
  Write-Host "[ERROR] bash not found. scripts/tree.sh requires bash."
  exit 1
}
& bash scripts/tree.sh

& npm run precommit

& git status -sb
& git diff --stat
