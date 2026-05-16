param(
    [string]$DistQtDir = "",
    [string[]]$Project = @(),
    [switch]$AllowDirty,
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DistQtDir)) {
    $DistQtDir = Join-Path $repoRoot "dist_qt"
}

$projects = @(
    @{ Name = "permission_qt" },
    @{ Name = "orchestrator" },
    @{ Name = "password_qt" },
    @{ Name = "phishing_qt" },
    @{ Name = "public_wifi" },
    @{ Name = "pulse_console" },
    @{ Name = "qr" },
    @{ Name = "cuarzito_race" }
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
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read current branch for $RepoPath"
    }
    return ($branch | Select-Object -First 1).Trim()
}

function Get-HeadCommit {
    param([string]$RepoPath)
    $commit = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --short HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read HEAD for $RepoPath"
    }
    return ($commit | Select-Object -First 1).Trim()
}

function Get-EffectivePackageState {
    param([string]$RepoPath)

    $headFull = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read full HEAD for $RepoPath"
    }
    $headFull = ($headFull | Select-Object -First 1).Trim()

    $headShort = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --short HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read short HEAD for $RepoPath"
    }
    $headShort = ($headShort | Select-Object -First 1).Trim()

    $subject = & git "-c" "safe.directory=*" "-C" $RepoPath log -1 --pretty=%s
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read HEAD subject for $RepoPath"
    }
    $subject = ($subject | Select-Object -First 1).Trim()

    $changedFiles = @(& git "-c" "safe.directory=*" "-C" $RepoPath diff-tree --no-commit-id --name-only -r HEAD)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read HEAD changed files for $RepoPath"
    }

    $isReleaseMetadataCommit =
        ($subject -match '^Package v\d+$') -and
        ($changedFiles.Count -eq 1) -and
        ($changedFiles[0] -eq 'releases.json')

    if ($isReleaseMetadataCommit) {
        $parentShort = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --short HEAD^
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read release metadata parent commit for $RepoPath"
        }
        $parentShort = ($parentShort | Select-Object -First 1).Trim()

        return [PSCustomObject]@{
            headCommit = $headShort
            packageCommit = $parentShort
            headSubject = $subject
            headIsReleaseMetadata = $true
        }
    }

    return [PSCustomObject]@{
        headCommit = $headShort
        packageCommit = $headShort
        headSubject = $subject
        headIsReleaseMetadata = $false
    }
}

function Get-WorkingTreeChanges {
    param([string]$RepoPath)
    $lines = & git "-c" "safe.directory=*" "-C" $RepoPath status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read working tree status for $RepoPath"
    }
    return @($lines)
}

function Get-LastRelease {
    param([string]$RepoPath)
    $releaseFile = Join-Path $RepoPath "releases.json"
    $data = Get-Content $releaseFile | ConvertFrom-Json
    if (-not $data.releases -or $data.releases.Count -eq 0) {
        return $null
    }
    return $data.releases[-1]
}

function Commit-Exists {
    param(
        [string]$RepoPath,
        [string]$Commit
    )

    if ([string]::IsNullOrWhiteSpace($Commit)) {
        return $false
    }

    & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --verify --quiet $Commit | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Get-UpstreamRef {
    param([string]$RepoPath)

    $upstream = & git "-c" "safe.directory=*" "-C" $RepoPath rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return ($upstream | Select-Object -First 1).Trim()
}

if (-not (Test-Path $DistQtDir)) {
    New-Item -ItemType Directory -Path $DistQtDir | Out-Null
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
    $expectedDistFolder = Join-Path $DistQtDir $name
    $expectedZipPath = if ($lastBefore) { Join-Path $DistQtDir $lastBefore.zip } else { $null }
    $publishedAlready = $alreadyPackaged -and (Test-Path $expectedDistFolder) -and $expectedZipPath -and (Test-Path $expectedZipPath)
    $nextVersion = if ($lastBefore) { [int]$lastBefore.version + 1 } else { 0 }
    $nextTag = "v{0:D2}" -f $nextVersion
    $tagExists = (& git "-c" "safe.directory=*" "-C" $sourceRepo tag --list $nextTag | Measure-Object).Count -gt 0

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
            zip = ""
            notes = ($workingTreeChanges -join "; ")
        }
        continue
    }

    if (-not $alreadyPackaged -and $tagExists) {
        $tagCommit = & git "-c" "safe.directory=*" "-C" $sourceRepo rev-list -n 1 $nextTag
        $tagCommit = ($tagCommit | Select-Object -First 1).Trim()
        if (-not (Commit-Exists -RepoPath $sourceRepo -Commit $tagCommit) -or $tagCommit -ne $headCommit) {
            Write-Host ">> Blocked: next tag $nextTag already exists on a different commit."
            $report += [PSCustomObject]@{
                project = $name
                status = "blocked_tag_conflict"
                branch = $branch
                head = $packageCommit
                version = $nextTag
                zip = ""
                notes = "Existing tag $nextTag points to $tagCommit"
            }
            continue
        }
    }

    $releaseChanged = $false

    if (-not $publishedAlready) {
        Write-Host ">> Running package_release.ps1 on branch $branch..."
        Push-Location $sourceRepo
        try {
            & "C:\Program Files\PowerShell\7\pwsh.exe" -File ".\package_release.ps1"
        } finally {
            Pop-Location
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Packaging failed for $name"
        }

        $lastAfter = Get-LastRelease -RepoPath $sourceRepo
        if (-not $lastAfter) {
            throw "No release entry found after packaging for $name"
        }

        $releaseChanged =
            (-not $lastBefore) -or
            ($lastAfter.version -ne $lastBefore.version) -or
            ($lastAfter.zip -ne $lastBefore.zip) -or
            ($lastAfter.commit -ne $lastBefore.commit)
    } else {
        Write-Host ">> HEAD already packaged as $($lastBefore.zip). Verifying dist_qt only."
        $lastAfter = $lastBefore
    }

    $zipName = $lastAfter.zip
    $versionTag = "v{0:D2}" -f [int]$lastAfter.version
    $distFolder = $expectedDistFolder
    $zipPath = Join-Path $DistQtDir $zipName
    if (-not (Test-Path $distFolder)) {
        throw "Expected dist_qt folder not found for ${name}: $distFolder"
    }
    if (-not (Test-Path $zipPath)) {
        throw "Expected zip not found for ${name}: $zipPath"
    }

    $finalTagExists = (& git "-c" "safe.directory=*" "-C" $sourceRepo tag --list $versionTag | Measure-Object).Count -gt 0
    if (-not $finalTagExists) {
        Invoke-GitSafe -RepoPath $sourceRepo -GitArgs @("tag", $versionTag)
    } elseif (-not $alreadyPackaged) {
        Write-Host ">> Tag $versionTag already exists in $name, continuing."
    }

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
        zip = $zipName
        notes = "$pushStatus | $distFolder"
    }
}

Write-Host ""
Write-Host "=== Release Report ==="
$report | Format-Table -AutoSize
