param(
    [string]$DistQtDir = "",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DistQtDir)) {
    $DistQtDir = Join-Path $PSScriptRoot "dist_qt"
}

if (-not (Test-Path -LiteralPath $DistQtDir)) {
    throw "DistQtDir not found: $DistQtDir"
}

function Invoke-Step {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    if ($WhatIf) {
        Write-Host "[WhatIf] $Description"
        return
    }

    Write-Host $Description
    & $Action
}

function Get-ZipReleaseInfo {
    param([System.IO.FileInfo]$File)

    if ($File.Name -notmatch '^(?<Project>.+)_v(?<Version>\d+)\.zip$') {
        return $null
    }

    return [PSCustomObject]@{
        Project = $Matches.Project
        Version = [int]$Matches.Version
        File = $File
    }
}

function Unblock-IfPresent {
    param([string]$TargetPath)

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return
    }

    Unblock-File -LiteralPath $TargetPath -ErrorAction SilentlyContinue
}

function Expand-ReleaseZip {
    param(
        [string]$ZipPath,
        [string]$DestinationDir,
        [string]$ProjectName
    )

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bajo_ataque_dist_qt_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    try {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempRoot -Force

        $rootEntries = @(Get-ChildItem -LiteralPath $tempRoot -Force)
        $singleDirectoryOnly =
            ($rootEntries.Count -eq 1) -and
            ($rootEntries[0].PSIsContainer)

        if ($singleDirectoryOnly) {
            $sourceDir = $rootEntries[0].FullName
            Move-Item -LiteralPath $sourceDir -Destination $DestinationDir
            return
        }

        New-Item -ItemType Directory -Path $DestinationDir | Out-Null
        foreach ($entry in $rootEntries) {
            Move-Item -LiteralPath $entry.FullName -Destination $DestinationDir
        }
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

$zipInfos = @(
    Get-ChildItem -LiteralPath $DistQtDir -File -Filter *.zip |
    ForEach-Object { Get-ZipReleaseInfo -File $_ } |
    Where-Object { $null -ne $_ }
)

if ($zipInfos.Count -eq 0) {
    throw "No release zip files matching <project>_vNN.zip were found in $DistQtDir"
}

$grouped = $zipInfos | Group-Object -Property Project

foreach ($group in $grouped) {
    $projectName = $group.Name
    $ordered = @($group.Group | Sort-Object -Property Version, @{ Expression = { $_.File.LastWriteTimeUtc } })
    $latest = $ordered[-1]
    $older = @($ordered | Select-Object -SkipLast 1)

    foreach ($entry in $older) {
        $zipPath = $entry.File.FullName
        Invoke-Step -Description "Deleting old zip $($entry.File.Name)" -Action {
            Remove-Item -LiteralPath $zipPath -Force
        }
    }

    $projectDir = Join-Path $DistQtDir $projectName
    if (Test-Path -LiteralPath $projectDir) {
        Invoke-Step -Description "Removing deployed directory $projectName" -Action {
            Remove-Item -LiteralPath $projectDir -Recurse -Force
        }
    }

    $zipPath = $latest.File.FullName
    Invoke-Step -Description "Unblocking $($latest.File.Name)" -Action {
        Unblock-IfPresent -TargetPath $zipPath
    }
    Invoke-Step -Description "Extracting $($latest.File.Name) to $projectName" -Action {
        Expand-ReleaseZip -ZipPath $zipPath -DestinationDir $projectDir -ProjectName $projectName
    }
    Invoke-Step -Description "Unblocking extracted files for $projectName" -Action {
        Get-ChildItem -LiteralPath $projectDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Processed $($grouped.Count) Qt projects in $DistQtDir"
