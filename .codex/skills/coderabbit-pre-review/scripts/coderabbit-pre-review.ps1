$ErrorActionPreference = "Stop"

$reviewType = if ($env:CR_REVIEW_TYPE) { $env:CR_REVIEW_TYPE } else { "uncommitted" }
$baseBranch = if ($env:CR_BASE_BRANCH) { $env:CR_BASE_BRANCH } else { "main" }
$mode = if ($env:CR_MODE) { $env:CR_MODE } else { "prompt-only" }

if (-not (Get-Command coderabbit -ErrorAction SilentlyContinue)) {
  Write-Host "[ERROR] coderabbit CLI not found."
  Write-Host "[HINT] Install: curl -fsSL https://cli.coderabbit.ai/install.sh | sh"
  exit 1
}

$root = (& git rev-parse --show-toplevel 2>$null).Trim()
if ([string]::IsNullOrWhiteSpace($root)) {
  Write-Host "[ERROR] not in a git repository."
  exit 1
}

Set-Location $root
Write-Host "[INFO] repo root: $root"
& git status -sb

$authStatusOutput = (& coderabbit auth status 2>&1 | Out-String)
if ($authStatusOutput -match "Not logged in" -or $authStatusOutput -match "Authentication required") {
  Write-Host "[ERROR] coderabbit is not authenticated."
  Write-Host "[HINT] Run: coderabbit auth login"
  exit 1
}

$modeFlag = if ($mode -eq "plain") { "--plain" } else { "--prompt-only" }

Write-Host "[INFO] Running CodeRabbit pre-review: mode=$mode type=$reviewType base=$baseBranch"

$job = Start-Job -ScriptBlock {
  param($ModeFlag, $ReviewType, $BaseBranch)
  & coderabbit review $ModeFlag -t $ReviewType --base $BaseBranch
  if ($LASTEXITCODE -ne 0) {
    throw "coderabbit review failed with exit code $LASTEXITCODE"
  }
} -ArgumentList $modeFlag, $reviewType, $baseBranch

while ($job.State -eq "Running") {
  Start-Sleep -Seconds 60
  Receive-Job $job -Keep | Out-Host
  if ($job.State -eq "Running") {
    Write-Host "[INFO] CodeRabbit review を待機中です..."
    Write-Host "[INFO] 長い差分では数分かかることがあります"
  }
}

Receive-Job $job | Out-Host

if ($job.State -eq "Failed") {
  exit 1
}
