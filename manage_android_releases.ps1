param(
    [string]$DistAndroidDir = "",
    [string[]]$Project = @(),
    [switch]$AllowDirty,
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DistAndroidDir)) {
    $DistAndroidDir = Join-Path $repoRoot "dist-android"
}

$projects = @(
    @{ Name = "password_android" },
    @{ Name = "permission_android" },
    @{ Name = "phishing_android" }
)

function Invoke-GitSafe {
    param(
        [string]$RepoPath,
        [string[]]$GitArgs
    )

    & git "-c" "safe.directory=*" "-C" $RepoPath @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git failed in ${RepoPath}: git $($GitArgs -join ' ')"
    }
}

function Get-CurrentBranch {
    param([string]$RepoPath)
    $branch = & git "-c" "safe.directory=*" "-C" $RepoPath branch --show-current
    if ($LASTEXITCODE -ne 0) { throw "Failed to read current branch for $RepoPath" }
    return ($branch | Select-Object -First 1).Trim()
}

function Get-WorkingTreeChanges {
    param([string]$RepoPath)
    $lines = & git "-c" "safe.directory=*" "-C" $RepoPath status --porcelain
    if ($LASTEXITCODE -ne 0) { throw "Failed to read working tree status for $RepoPath" }
    return @($lines)
}

function Get-HeadCommit {
    param([string]$RepoPath)
    $commit = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --short HEAD
    if ($LASTEXITCODE -ne 0) { throw "Failed to read HEAD for $RepoPath" }
    return ($commit | Select-Object -First 1).Trim()
}

function Get-EffectivePackageState {
    param([string]$RepoPath)

    $headShort = Get-HeadCommit -RepoPath $RepoPath
    $subject = & git "-c" "safe.directory=*" "-C" $RepoPath log -1 --pretty=%s
    if ($LASTEXITCODE -ne 0) { throw "Failed to read HEAD subject for $RepoPath" }
    $subject = ($subject | Select-Object -First 1).Trim()

    $changedFiles = @(& git "-c" "safe.directory=*" "-C" $RepoPath diff-tree --no-commit-id --name-only -r HEAD)
    if ($LASTEXITCODE -ne 0) { throw "Failed to read HEAD changed files for $RepoPath" }

    $isReleaseMetadataCommit =
        ($subject -match '^Package v\d+$') -and
        ($changedFiles.Count -eq 1) -and
        ($changedFiles[0] -eq 'releases.json')

    if ($isReleaseMetadataCommit) {
        $parentShort = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --short HEAD^
        if ($LASTEXITCODE -ne 0) { throw "Failed to read release metadata parent commit for $RepoPath" }
        $parentShort = ($parentShort | Select-Object -First 1).Trim()

        return [PSCustomObject]@{
            headCommit = $headShort
            packageCommit = $parentShort
            headIsReleaseMetadata = $true
        }
    }

    return [PSCustomObject]@{
        headCommit = $headShort
        packageCommit = $headShort
        headIsReleaseMetadata = $false
    }
}

function Get-LastRelease {
    param([string]$RepoPath)
    $releaseFile = Join-Path $RepoPath "releases.json"
    if (-not (Test-Path $releaseFile)) { return $null }
    $data = Get-Content $releaseFile | ConvertFrom-Json
    if (-not $data.releases -or $data.releases.Count -eq 0) { return $null }
    return $data.releases[-1]
}

function Get-UpstreamRef {
    param([string]$RepoPath)

    $upstream = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($upstream | Select-Object -First 1).Trim()
}

function Sync-AndroidDist {
    param(
        [string]$RepoPath,
        [string]$ProjectName,
        [string]$DestinationRoot,
        [string]$ApkName
    )

    $destination = Join-Path $DestinationRoot $ProjectName
    if (Test-Path $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $destination | Out-Null

    Copy-Item (Join-Path $RepoPath ("dist\" + $ApkName)) (Join-Path $destination "app-release.apk")
    Copy-Item (Join-Path $RepoPath "dist\version.json") $destination
    Copy-Item (Join-Path $RepoPath "dist\BUILD_INFO.txt") $destination

    return $destination
}

if (-not (Test-Path $DistAndroidDir)) {
    New-Item -ItemType Directory -Path $DistAndroidDir | Out-Null
}

$requestedProjectNames = @()
foreach ($entry in $Project) {
    if (-not [string]::IsNullOrWhiteSpace($entry)) {
        $requestedProjectNames += ($entry -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
}

$selectedProjects = if ($requestedProjectNames.Count -gt 0) {
    @($projects | Where-Object { $requestedProjectNames -contains $_.Name })
} else {
    @($projects)
}

if ($selectedProjects.Count -eq 0) {
    throw "No matching projects were selected."
}

$report = @()

foreach ($projectEntry in $selectedProjects) {
    $name = $projectEntry.Name
    $sourceRepo = Join-Path $repoRoot $name
    $branch = Get-CurrentBranch -RepoPath $sourceRepo
    $packageState = Get-EffectivePackageState -RepoPath $sourceRepo
    $headCommit = $packageState.headCommit
    $packageCommit = $packageState.packageCommit
    $lastBefore = Get-LastRelease -RepoPath $sourceRepo
    $workingTreeChanges = Get-WorkingTreeChanges -RepoPath $sourceRepo
    $isDirty = $workingTreeChanges.Count -gt 0
    $alreadyPackaged = $lastBefore -and (
        $lastBefore.commit -eq $packageCommit -or
        $lastBefore.commit -eq $headCommit
    )

    Write-Host ""
    Write-Host "=== $name ==="

    if ($isDirty -and -not $AllowDirty) {
        Write-Host ">> Blocked: working tree is dirty."
        $report += [PSCustomObject]@{
            project = $name
            status = "blocked_dirty"
            branch = $branch
            head = $headCommit
            version = ""
            apk = ""
            notes = ($workingTreeChanges -join "; ")
        }
        continue
    }

    $releaseChanged = $false
    if (-not $alreadyPackaged) {
        Write-Host ">> Running package_release.ps1 on branch $branch..."
        Push-Location $sourceRepo
        try {
            & "C:\Program Files\PowerShell\7\pwsh.exe" -File ".\package_release.ps1"
        } finally {
            Pop-Location
        }
        if ($LASTEXITCODE -ne 0) { throw "Packaging failed for $name" }

        $lastAfter = Get-LastRelease -RepoPath $sourceRepo
        if (-not $lastAfter) { throw "No release entry found after packaging for $name" }

        $releaseChanged =
            (-not $lastBefore) -or
            ($lastAfter.version -ne $lastBefore.version) -or
            ($lastAfter.apk -ne $lastBefore.apk) -or
            ($lastAfter.commit -ne $lastBefore.commit)
    } else {
        Write-Host ">> HEAD already packaged as $($lastBefore.apk). Syncing dist-android only."
        $lastAfter = $lastBefore
    }

    $apkName = $lastAfter.apk
    $versionTag = "v{0:D2}" -f [int]$lastAfter.version
    $apkSource = Join-Path $sourceRepo ("dist\" + $apkName)
    if (-not (Test-Path $apkSource)) { throw "Expected APK not found for ${name}: $apkSource" }

    $distFolder = Sync-AndroidDist -RepoPath $sourceRepo -ProjectName $name -DestinationRoot $DistAndroidDir -ApkName $apkName

    if ($releaseChanged) {
        Invoke-GitSafe -RepoPath $sourceRepo -GitArgs @("add", "releases.json")
        Invoke-GitSafe -RepoPath $sourceRepo -GitArgs @("commit", "-m", "Package $versionTag")
    }

    $pushStatus = "skipped"
    if (-not $SkipPush) {
        $upstreamRef = Get-UpstreamRef -RepoPath $sourceRepo
        if ($upstreamRef) {
            Write-Host ">> Pushing branch $branch..."
            Invoke-GitSafe -RepoPath $sourceRepo -GitArgs @("push", "origin", $branch)
            Write-Host ">> Pushing tags..."
            Invoke-GitSafe -RepoPath $sourceRepo -GitArgs @("push", "--tags")
            $pushStatus = "pushed"
        } else {
            Write-Host ">> No upstream configured for $name. Branch/tag push skipped."
            $pushStatus = "no_upstream"
        }
    }

    $report += [PSCustomObject]@{
        project = $name
        status = if ($releaseChanged) { "released" } else { "synced" }
        branch = $branch
        head = $packageCommit
        version = $versionTag
        apk = $apkName
        notes = "$pushStatus | $distFolder"
    }
}

Write-Host ""
Write-Host "=== Release Report ==="
$report | Format-Table -AutoSize
