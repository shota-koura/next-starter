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

$baseBranch = if ($env:BASE_BRANCH) { $env:BASE_BRANCH } else { "main" }
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

if (Test-Path "scripts/pr.sh") {
  $bash = Get-Command bash -ErrorAction SilentlyContinue
  if ($bash) {
    & bash scripts/pr.sh
  } else {
    Write-Host "[INFO] scripts/pr.sh found but bash not available -> fallback with gh"
    & gh pr view $branch *> $null
    if ($LASTEXITCODE -ne 0) {
      & gh pr create --fill --base $baseBranch --head $branch
    }
  }
} else {
  Write-Host "[INFO] scripts/pr.sh not found -> fallback with gh"
  & gh pr view $branch *> $null
  if ($LASTEXITCODE -ne 0) {
    & gh pr create --fill --base $baseBranch --head $branch
  }
}

$prInfo = & gh pr view --json number,title,url,isDraft | ConvertFrom-Json
Write-Host "[OK] PR: #$($prInfo.number) $($prInfo.title)"
Write-Host $prInfo.url
Write-Host "[INFO] isDraft=$($prInfo.isDraft)"

& gh pr comment --body "@codex review in Japanese"
Write-Host "[OK] review request posted"

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
    Write-Host "[INFO] Hand off to pr-fix-loop"
    exit 0
  }

  if ($pend -eq 0 -and $cancel -eq 0) {
    Write-Host "[OK] CI: all checks completed"
    break
  }

  Start-Sleep -Seconds $pollSec
}

Write-Host "[WAIT] Review: polling for outputs..."

$repo = (gh repo view --json nameWithOwner | ConvertFrom-Json).nameWithOwner
$prNum = (gh pr view --json number | ConvertFrom-Json).number

while ($true) {
  $headSha = (gh pr view --json headRefOid | ConvertFrom-Json).headRefOid

  $headTime = $null
  $commit = Invoke-GhApiJson "repos/$repo/commits/$headSha"
  if ($null -ne $commit) {
    $headTime = $commit.commit.committer.date
  }

  $issueCnt = $null
  if (-not [string]::IsNullOrWhiteSpace($headTime)) {
    $issueComments = Invoke-GhApiJson "repos/$repo/issues/$prNum/comments"
    if ($null -ne $issueComments) {
      $headDt = [DateTime]::Parse($headTime)
      $issueCnt = (To-Array $issueComments | Where-Object {
        (Is-ReviewBot $_.user.login) -and ([DateTime]::Parse($_.created_at) -ge $headDt)
      }).Count
    }
  }

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

  if ($null -eq $issueCnt -or $null -eq $reviewsHeadCnt -or $null -eq $lineHeadCnt) {
    Write-Host "[INFO] Review: fetch failed (transient) -> retry"
    Start-Sleep -Seconds $pollSecReview
    continue
  }

  Write-Host "[INFO] Review: head=$headSha issue=$issueCnt reviews(head)=$reviewsHeadCnt line(head)=$lineHeadCnt"

  if ($issueCnt -ne 0 -or $reviewsHeadCnt -ne 0 -or $lineHeadCnt -ne 0) {
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

if ($lineCntHead -ne 0) {
  Write-Host "[INFO] Fixes required. Next: pr-fix-loop"
  exit 0
}

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
