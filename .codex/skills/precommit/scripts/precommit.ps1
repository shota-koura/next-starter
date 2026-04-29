$ErrorActionPreference = "Stop"

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
  Write-Host "[ERROR] bash not found. precommit requires bash scripts."
  exit 1
}

& bash .codex/skills/verify-full/scripts/verify-full.sh

& bash scripts/tree.sh

& bash .codex/skills/verify-full/scripts/verify-full.sh

& git status -sb
& git diff --stat
