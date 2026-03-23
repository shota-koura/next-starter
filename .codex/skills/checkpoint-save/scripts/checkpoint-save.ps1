$ErrorActionPreference = "Stop"

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

function Get-ChangedFiles {
  $files = @()
  $files += (& git diff --name-only)
  $files += (& git diff --name-only --cached)
  $files += (& git ls-files --others --exclude-standard)
  return $files | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique
}

function Test-IsTestFile([string]$Path) {
  return $Path -match '(^__tests__/|/__tests__/|^e2e/|/e2e/|/tests/|\.test\.|\.spec\.)'
}

function Test-IsToolFile([string]$Path) {
  return $Path -match '^(\.codex/|scripts/|\.github/|\.coderabbit\.ya?ml$)' -or
    $Path -in @(
      'package.json',
      'package-lock.json',
      'pnpm-lock.yaml',
      'yarn.lock',
      'poetry.lock',
      'pyproject.toml'
    ) -or
    $Path -like 'requirements*.txt' -or
    $Path -like 'backend/requirements*.txt' -or
    $Path -like '.env*' -or
    $Path -like '*/.env' -or
    $Path -like '*/.env.*' -or
    $Path -match '^(eslint\.config\.|jest\.config\.|jest\.setup\.|tsconfig.*\.json$|next\.config\.|postcss\.config\.|playwright\.config\.|tailwind\.config\.|vite\.config\.|vitest\.config\.)'
}

function Test-IsDocFile([string]$Path) {
  return $Path -like 'docs/*' -or $Path -like '*.md'
}

function Test-IsBackendFile([string]$Path) {
  return $Path -like 'backend/*'
}

function Test-IsFrontendFile([string]$Path) {
  return $Path -like 'app/*' -or
    $Path -like 'components/*' -or
    $Path -like 'lib/*' -or
    $Path -like 'public/*' -or
    $Path -like 'styles/*' -or
    $Path -like 'hooks/*' -or
    $Path -like 'contexts/*' -or
    $Path -like 'types/*'
}

function Test-IsAllowedGuardedFile([string]$Path) {
  if (-not $env:ALLOW_GUARDED_FILES) {
    return $false
  }

  $normalized = "," + ($env:ALLOW_GUARDED_FILES -replace '\s+', '') + ","
  return $normalized.Contains(",$Path,")
}

function Get-InferredCommitMessage([string[]]$Files) {
  $hasBackend = $false
  $hasFrontend = $false
  $hasDocs = $false
  $hasTests = $false
  $hasTools = $false
  $hasOther = $false

  foreach ($file in $Files) {
    if (Test-IsTestFile $file) {
      $hasTests = $true
    }

    if (Test-IsToolFile $file) {
      $hasTools = $true
      continue
    }

    if (Test-IsDocFile $file) {
      $hasDocs = $true
      continue
    }

    if (Test-IsBackendFile $file) {
      $hasBackend = $true
      continue
    }

    if (Test-IsFrontendFile $file) {
      $hasFrontend = $true
      continue
    }

    $hasOther = $true
  }

  $hasCode = $hasBackend -or $hasFrontend -or $hasOther
  $type = ""
  $summary = ""
  $scope = ""

  if (-not $hasCode) {
    if ($hasTests -and -not $hasDocs -and -not $hasTools) {
      $type = "test"
      $summary = "テストの途中経過を保存"
    } elseif ($hasDocs -and -not $hasTests -and -not $hasTools) {
      $type = "docs"
      $summary = "ドキュメントの途中経過を保存"
    } elseif ($hasTools -and -not $hasTests -and -not $hasDocs) {
      $type = "chore"
      $summary = "開発周辺の途中経過を保存"
    } else {
      $type = "chore"
      $summary = "作業途中の変更を保存"
    }
  } else {
    $type = "feat"
    if ($hasFrontend -and $hasBackend) {
      $summary = "フロントエンドとバックエンドの途中経過を保存"
    } elseif ($hasFrontend) {
      $summary = "フロントエンドの途中経過を保存"
    } elseif ($hasBackend) {
      $summary = "バックエンドの途中経過を保存"
    } else {
      $summary = "実装途中の変更を保存"
    }
  }

  if ($type -eq "feat") {
    if ($hasBackend -and -not $hasFrontend) {
      $scope = "backend"
    } elseif ($hasFrontend -and -not $hasBackend) {
      $scope = "frontend"
    }
  }

  if ($scope) {
    return "${type}($scope): $summary"
  }

  return "${type}: $summary"
}

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq "HEAD") {
  Write-Host "[ERROR] detached HEAD 上です。checkpoint-save は作業ブランチで使ってください。"
  exit 1
}

if ($branch -in @("main", "master")) {
  Write-Host "[ERROR] main/master 上です。checkpoint-save は作業ブランチで使ってください。"
  exit 1
}

Write-Host "[INFO] branch=$branch"
& git status -sb

$changedFiles = @(Get-ChangedFiles)
if ($changedFiles.Count -eq 0) {
  Write-Host "[ERROR] 変更がありません。checkpoint は不要です。"
  exit 1
}

$changedFiles | ForEach-Object { Write-Host $_ }

$verifyFastScript = Join-Path $root ".codex/skills/verify-fast/scripts/verify-fast.ps1"
if (Test-Path $verifyFastScript) {
  & pwsh -File $verifyFastScript
} else {
  Write-Host "[ERROR] verify-fast script not found: .codex/skills/verify-fast/scripts/verify-fast.ps1"
  exit 1
}

& git status -sb
& git diff --stat

$forbiddenRe = '^(\.github/|\.codex/agents/|\.codex/skills/|AGENTS\.md$|\.coderabbit\.ya?ml$|package(-lock)?\.json$|pnpm-lock\.yaml$|yarn\.lock$|poetry\.lock$|pyproject\.toml$|requirements.*\.txt$|backend/requirements.*\.txt$|(.*/)?\.env($|\.))'
$violation = $false
foreach ($file in $changedFiles) {
  if ($file -match $forbiddenRe) {
    if (Test-IsAllowedGuardedFile $file) {
      Write-Host "[WARN] 明示承認済みの guarded file を許可します: $file"
      continue
    }

    Write-Host "[ERROR] checkpoint-save では人間確認が必要な変更です: $file"
    $violation = $true
  }
}

if ($violation) {
  Write-Host "[ERROR] ガードレール違反のため停止します（commit/push しません）。"
  Write-Host "[HINT] guarded file を含む変更は通常の最終フローまたは人間確認後に扱ってください。"
  exit 1
}

if (-not $env:COMMIT_MSG) {
  $env:COMMIT_MSG = Get-InferredCommitMessage $changedFiles
  if (-not $env:COMMIT_MSG) {
    Write-Host "[ERROR] COMMIT_MSG の自動生成に失敗しました。明示的に設定してください。"
    exit 1
  }

  Write-Host "[INFO] COMMIT_MSG を自動生成しました: $($env:COMMIT_MSG)"
} else {
  Write-Host "[INFO] COMMIT_MSG=$($env:COMMIT_MSG)"
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
