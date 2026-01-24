$ErrorActionPreference = "Stop"

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

function Test-TestFile {
  param([string]$Path)
  return ($Path -match "(^|/)(__tests__|tests)/" -or $Path -match "^e2e/" -or $Path -match "\.test\." -or $Path -match "\.spec\.")
}

function Test-ToolFile {
  param([string]$Path)
  return (
    $Path -like ".codex/*" -or
    $Path -like "scripts/*" -or
    $Path -like ".github/*" -or
    $Path -match "^\.coderabbit\.ya?ml$" -or
    $Path -match "^(package(-lock)?\.json|pnpm-lock\.yaml|yarn\.lock|poetry\.lock|pyproject\.toml|requirements.*\.txt|\.env)" -or
    $Path -match "^(eslint\.config\..+|jest\.config\..+|jest\.setup\..+|tsconfig.*\.json|next\.config\..+|postcss\.config\..+|playwright\.config\..+|tailwind\.config\..+|vite\.config\..+|vitest\.config\..+)$"
  )
}

function Test-DocFile {
  param([string]$Path)
  return ($Path -like "docs/*" -or $Path -like "*.md")
}

function Test-BackendFile {
  param([string]$Path)
  return ($Path -like "backend/*")
}

function Test-FrontendFile {
  param([string]$Path)
  return (
    $Path -like "app/*" -or
    $Path -like "components/*" -or
    $Path -like "lib/*" -or
    $Path -like "public/*" -or
    $Path -like "styles/*" -or
    $Path -like "hooks/*" -or
    $Path -like "contexts/*" -or
    $Path -like "types/*"
  )
}

function Get-ChangedFilesForMessage {
  $files = @()
  $files += & git diff --name-only
  $files += & git diff --name-only --cached
  $files += & git ls-files --others --exclude-standard
  return $files | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
}

function Get-CommitMessage {
  param([string[]]$Files)

  if (-not $Files -or $Files.Count -eq 0) {
    return ""
  }

  $hasBackend = $false
  $hasFrontend = $false
  $hasDocs = $false
  $hasTests = $false
  $hasTools = $false
  $hasOther = $false

  foreach ($file in $Files) {
    if ([string]::IsNullOrWhiteSpace($file)) { continue }
    if (Test-TestFile $file) { $hasTests = $true }

    if (Test-ToolFile $file) { $hasTools = $true; continue }
    if (Test-DocFile $file) { $hasDocs = $true; continue }
    if (Test-BackendFile $file) { $hasBackend = $true; continue }
    if (Test-FrontendFile $file) { $hasFrontend = $true; continue }

    $hasOther = $true
  }

  $hasCode = ($hasBackend -or $hasFrontend -or $hasOther)
  $type = ""
  $summary = ""
  $scope = ""

  if (-not $hasCode) {
    if ($hasTests -and -not $hasDocs -and -not $hasTools) {
      $type = "test"
      $summary = "テストを更新"
    } elseif ($hasDocs -and -not $hasTests -and -not $hasTools) {
      $type = "docs"
      $summary = "ドキュメントを更新"
    } elseif ($hasTools -and -not $hasTests -and -not $hasDocs) {
      $type = "chore"
      $summary = "開発環境を更新"
    } else {
      $type = "chore"
      $summary = "開発周辺を更新"
    }
  } else {
    $type = "feat"
    if ($hasFrontend -and $hasBackend) {
      $summary = "フロントエンドとバックエンドを更新"
    } elseif ($hasFrontend) {
      $summary = "フロントエンドを更新"
    } elseif ($hasBackend) {
      $summary = "バックエンドを更新"
    } else {
      $summary = "変更を反映"
    }
  }

  if ($type -eq "feat") {
    if ($hasBackend -and -not $hasFrontend) {
      $scope = "backend"
    } elseif ($hasFrontend -and -not $hasBackend) {
      $scope = "frontend"
    }
  }

  if ([string]::IsNullOrWhiteSpace($scope)) {
    return "$type: $summary"
  }

  return "$type($scope): $summary"
}

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq "main" -or $branch -eq "master") {
  Write-Host "[ERROR] main/master 上です。作業ブランチへ切り替えてください。"
  exit 1
}

Write-Host "[INFO] branch=$branch"

& git status -sb
& git diff --name-only

$verifyScript = Join-Path $root ".codex/skills/verify-full/scripts/verify-full.ps1"
if (Test-Path $verifyScript) {
  & pwsh -File $verifyScript
} else {
  Write-Host "[ERROR] verify-full script not found: $verifyScript"
  exit 1
}

& git status -sb
& git diff --stat

$status = & git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
  Write-Host "[ERROR] 変更がありません。commit は不要です。"
  exit 1
}

$files = @()
foreach ($line in ($status -split "`n")) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  if ($line.Length -lt 4) { continue }
  $path = $line.Substring(3)
  if ($path -match " -> ") {
    $path = $path.Split(" -> ")[1]
  }
  $files += $path.Trim()
}

Write-Host "[INFO] changed files:"
$files | ForEach-Object { Write-Host $_ }

$forbidden = [regex]::new('^(\.github/|\.coderabbit\.ya?ml$|package(-lock)?\.json$|pnpm-lock\.yaml$|yarn\.lock$|poetry\.lock$|pyproject\.toml$|requirements.*\.txt$|\.env)')
$violation = $false
foreach ($f in $files) {
  if ($forbidden.IsMatch($f)) {
    Write-Host "[ERROR] 事前確認が必要な領域に変更があります: $f"
    $violation = $true
  }
}

if ($violation) {
  Write-Host "[ERROR] ガードレール違反のため停止します（commit/pushしません）。"
  Write-Host "[HINT] 変更が意図通りか人間が確認し、方針確定後に再実行してください。"
  exit 1
}

$commitMsg = $env:COMMIT_MSG
if ([string]::IsNullOrWhiteSpace($commitMsg)) {
  $messageFiles = Get-ChangedFilesForMessage
  $commitMsg = Get-CommitMessage -Files $messageFiles
  if ([string]::IsNullOrWhiteSpace($commitMsg)) {
    Write-Host "[ERROR] COMMIT_MSG の自動生成に失敗しました。明示的に設定してください。"
    exit 1
  }
  $env:COMMIT_MSG = $commitMsg
  Write-Host "[INFO] COMMIT_MSG を自動生成しました: $commitMsg"
} else {
  Write-Host "[INFO] COMMIT_MSG=$commitMsg"
}

& git add -A
& git diff --cached --name-only
& git commit -m $env:COMMIT_MSG

$push = if ($env:PUSH) { $env:PUSH } else { "1" }
$remote = if ($env:REMOTE) { $env:REMOTE } else { "origin" }

if ($push -eq "1") {
  & git push $remote HEAD
  Write-Host "[OK] push 完了: remote=$remote"
} else {
  Write-Host "[INFO] PUSH=0 のため push はスキップしました。"
}
