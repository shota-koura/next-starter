$ErrorActionPreference = "Stop"

function To-Array {
  param($obj)
  if ($null -eq $obj) { return @() }
  if ($obj -is [System.Array]) { return $obj }
  return @($obj)
}

function Is-ReviewBot {
  param([string]$login)
  if ($null -eq $login) { return $false }
  return $login -match '(?i)coderabbit|chatgpt-codex-connector|codex'
}

function Invoke-GhApiJson {
  param([string]$Path)
  $json = & gh api $Path 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
    return $null
  }
  return $json | ConvertFrom-Json
}

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

$pollSec = if ($env:POLL_SEC) { [int]$env:POLL_SEC } else { 30 }
$pollSecReview = if ($env:POLL_SEC_REVIEW) { [int]$env:POLL_SEC_REVIEW } else { 30 }
$autoMerge = if ($env:AUTO_MERGE) { $env:AUTO_MERGE } else { "1" }

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$sha = (git rev-parse --short HEAD).Trim()

Write-Host "[OK] branch: $branch $sha"

if ($branch -eq "main" -or $branch -eq "master") {
  Write-Host "[ERROR] On main/master. Switch to a work branch."
  exit 1
}

& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERROR] gh auth status failed. Authenticate with gh first."
  exit 1
}

$prInfo = & gh pr view --json number,url,isDraft | ConvertFrom-Json
Write-Host "[OK] PR: #$($prInfo.number)"
Write-Host $prInfo.url
Write-Host "[INFO] isDraft=$($prInfo.isDraft)"

Write-Host "[WAIT] CI: polling checks..."

$scope = "--required"
$reqJson = & gh pr checks $scope --json bucket 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($reqJson)) {
  $scope = ""
} else {
  $req = $reqJson | ConvertFrom-Json
  if ((To-Array $req).Count -eq 0) {
    $scope = ""
  }
}

$ciFail = $false

while ($true) {
  $args = @("pr", "checks")
  if (-not [string]::IsNullOrWhiteSpace($scope)) { $args += $scope }
  $args += @("--json", "bucket")
  $checksJson = & gh @args 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($checksJson)) {
    Write-Host "[INFO] CI: fetch failed (transient) -> retry"
    Start-Sleep -Seconds $pollSec
    continue
  }

  $checks = $checksJson | ConvertFrom-Json
  $checksArr = To-Array $checks
  $total = $checksArr.Count

  if ($total -eq 0) {
    Write-Host "[INFO] CI: not started -> retry"
    Start-Sleep -Seconds $pollSec
    continue
  }

  $pass = ($checksArr | Where-Object { $_.bucket -eq "pass" }).Count
  $skip = ($checksArr | Where-Object { $_.bucket -eq "skipping" }).Count
  $pend = ($checksArr | Where-Object { $_.bucket -eq "pending" }).Count
  $cancel = ($checksArr | Where-Object { $_.bucket -eq "cancel" }).Count
  $fail = ($checksArr | Where-Object { $_.bucket -eq "fail" }).Count

  Write-Host "[INFO] CI: total=$total pass=$pass skip=$skip pending=$pend cancel=$cancel fail=$fail"

  if ($fail -gt 0) {
    $ciFail = $true
    Write-Host "[ERROR] CI: failure detected"
    $args = @("pr", "checks")
    if (-not [string]::IsNullOrWhiteSpace($scope)) { $args += $scope }
    $args += @("--json", "name,bucket,state,link")
    $failJson = & gh @args 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($failJson)) {
      $failChecks = (ConvertFrom-Json $failJson) | Where-Object { $_.bucket -eq "fail" }
      foreach ($c in (To-Array $failChecks)) {
        Write-Host "- $($c.name) ($($c.state)) $($c.link)"
      }
    }
    break
  }

  if ($pend -eq 0 -and $cancel -eq 0) {
    Write-Host "[OK] CI: all checks completed"
    break
  }

  Start-Sleep -Seconds $pollSec
}

if ($ciFail) {
  Write-Host "[INFO] CI: trying to fetch failed logs (GitHub Actions)"

  $runsJson = & gh run list --branch $branch --limit 20 --json databaseId,conclusion,createdAt 2>$null
  if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($runsJson)) {
    $runs = $runsJson | ConvertFrom-Json
    $failRun = (To-Array $runs | Where-Object { $_.conclusion -eq "failure" } | Select-Object -First 1)
    if ($null -ne $failRun) {
      Write-Host "[INFO] run_id=$($failRun.databaseId)"
      & gh run view $failRun.databaseId --log-failed | Out-Null
    } else {
      Write-Host "[INFO] Failed run not found. See failing check links above."
    }
  } else {
    Write-Host "[INFO] Failed run not found. See failing check links above."
  }
}

Write-Host "[WAIT] Review: polling for outputs..."

$repo = (gh repo view --json nameWithOwner | ConvertFrom-Json).nameWithOwner
$prNum = (gh pr view --json number | ConvertFrom-Json).number

while ($true) {
  $headSha = (gh pr view --json headRefOid | ConvertFrom-Json).headRefOid

  $reviews = Invoke-GhApiJson "repos/$repo/pulls/$prNum/reviews"
  $reviewsHeadCnt = if ($null -ne $reviews) {
    (To-Array $reviews | Where-Object {
      (Is-ReviewBot $_.user.login) -and ($_.commit_id -eq $headSha)
    }).Count
  } else { $null }

  $lineComments = Invoke-GhApiJson "repos/$repo/pulls/$prNum/comments"
  $lineHeadCnt = if ($null -ne $lineComments) {
    (To-Array $lineComments | Where-Object {
      (Is-ReviewBot $_.user.login) -and ($_.commit_id -eq $headSha)
    }).Count
  } else { $null }

  if ($null -eq $reviewsHeadCnt -or $null -eq $lineHeadCnt) {
    Write-Host "[INFO] Review: fetch failed (transient) -> retry"
    Start-Sleep -Seconds $pollSecReview
    continue
  }

  Write-Host "[INFO] Review: head=$headSha reviews(head)=$reviewsHeadCnt line(head)=$lineHeadCnt"

  if ($reviewsHeadCnt -ne 0 -or $lineHeadCnt -ne 0) {
    Write-Host "[OK] Review: output detected"
    break
  }

  Start-Sleep -Seconds $pollSecReview
}

$repo = (gh repo view --json nameWithOwner | ConvertFrom-Json).nameWithOwner
$prNum = (gh pr view --json number | ConvertFrom-Json).number
$headSha = (gh pr view --json headRefOid | ConvertFrom-Json).headRefOid

$lineComments = Invoke-GhApiJson "repos/$repo/pulls/$prNum/comments"
if ($null -eq $lineComments) {
  Write-Host "[ERROR] Review(P0): failed to fetch line comments. Retry."
  exit 1
}

$lineHead = To-Array ($lineComments | Where-Object {
  (Is-ReviewBot $_.user.login) -and ($_.commit_id -eq $headSha)
})
$lineCntHead = $lineHead.Count

Write-Host "[INFO] Review(P0): head=$headSha line_comments=$lineCntHead"

if ($lineCntHead -ne 0) {
  Write-Host "[INFO] Review(P0) digest:"
  Write-Host "----- BEGIN REVIEW_P0_DIGEST -----"
  foreach ($c in $lineHead) {
    $lineNum = if ($null -ne $c.line) { $c.line } elseif ($null -ne $c.original_line) { $c.original_line } else { 0 }
    $body = ($c.body -replace "`r?`n", " ")
    if ($body.Length -gt 160) { $body = $body.Substring(0, 160) }
    Write-Host "- $($c.path):$lineNum [$($c.user.login)] $body"
    Write-Host "  $($c.html_url)"
  }
  Write-Host "----- END REVIEW_P0_DIGEST -----"
} else {
  Write-Host "[OK] Review(P0): no line comments"
}

if (-not $ciFail -and $lineCntHead -eq 0) {
  $isDraft = (gh pr view --json isDraft | ConvertFrom-Json).isDraft
  if ($isDraft -eq $true) {
    Write-Host "[ERROR] PR is draft. Mark Ready for review, then rerun."
    exit 1
  }

  if ($autoMerge -eq "1") {
    Write-Host "[OK] enable auto-merge:"
    & gh pr merge --auto --squash --delete-branch
  } else {
    Write-Host "[INFO] AUTO_MERGE=0: skip merge"
    Write-Host "Suggested: gh pr merge --auto --squash --delete-branch"
  }

  exit 0
}

Write-Host "[INFO] Fixes required. Apply changes, run verify-fast, commit/push, then rerun this script."
exit 2
