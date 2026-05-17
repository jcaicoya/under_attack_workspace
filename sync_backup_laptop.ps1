param(
    [string]$RemoteRoot = "\\192.168.0.84\bajo_ataque",
    [pscredential]$Credential,
    [switch]$SkipRefresh,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$localRoot = $PSScriptRoot
$localDistQt = Join-Path $localRoot "dist_qt"
$localDistMedia = Join-Path $localRoot "dist_media"
$remoteBasePath = $RemoteRoot
$createdPsDrive = $null

function Invoke-RobocopyChecked {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$ListOnly
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source path not found: $Source"
    }

    $args = @(
        $Source,
        $Destination,
        "/MIR",
        "/FFT",
        "/R:2",
        "/W:2",
        "/NP",
        "/NFL",
        "/NDL"
    )

    if ($ListOnly) {
        $args += "/L"
    }

    & robocopy @args
    $exitCode = $LASTEXITCODE

    if ($exitCode -gt 7) {
        throw "robocopy failed from '$Source' to '$Destination' with exit code $exitCode"
    }
}

function Test-AccessiblePath {
    param([string]$Path)

    try {
        return (Test-Path -LiteralPath $Path)
    } catch {
        return $false
    }
}

function Connect-RemoteRoot {
    param(
        [string]$Root,
        [pscredential]$RemoteCredential
    )

    if (Test-AccessiblePath -Path $Root) {
        return [PSCustomObject]@{
            BasePath = $Root
            DriveName = $null
        }
    }

    if (-not $RemoteCredential) {
        $RemoteCredential = Get-Credential -Message "Credenciales para acceder a $Root"
    }

    $driveName = "BAK" + ([System.Guid]::NewGuid().ToString("N").Substring(0, 5))
    New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Root -Credential $RemoteCredential -Scope Script | Out-Null

    return [PSCustomObject]@{
        BasePath = "${driveName}:\"
        DriveName = $driveName
    }
}

try {
    $remoteConnection = Connect-RemoteRoot -Root $RemoteRoot -RemoteCredential $Credential
    $remoteBasePath = $remoteConnection.BasePath
    $createdPsDrive = $remoteConnection.DriveName
    $remoteDistQt = Join-Path $remoteBasePath "dist_qt"
    $remoteDistMedia = Join-Path $remoteBasePath "dist_media"

    if (-not $SkipRefresh) {
        $refreshArgs = @(
            "-File",
            (Join-Path $localRoot "refresh_backup_qt_dist.ps1")
        )
        if ($WhatIf) {
            $refreshArgs += "-WhatIf"
        }

        Write-Host "Refreshing local dist_qt..."
        & "C:\Program Files\PowerShell\7\pwsh.exe" @refreshArgs
        if ($LASTEXITCODE -ne 0) {
            throw "refresh_backup_qt_dist.ps1 failed."
        }
    }

    Write-Host "Syncing dist_qt to $remoteDistQt ..."
    Invoke-RobocopyChecked -Source $localDistQt -Destination $remoteDistQt -ListOnly:$WhatIf

    Write-Host "Syncing dist_media to $remoteDistMedia ..."
    Invoke-RobocopyChecked -Source $localDistMedia -Destination $remoteDistMedia -ListOnly:$WhatIf

    Write-Host ""
    if ($WhatIf) {
        Write-Host "Simulation complete."
    } else {
        Write-Host "Backup laptop sync complete."
    }
} finally {
    if ($createdPsDrive) {
        Remove-PSDrive -Name $createdPsDrive -Scope Script -Force -ErrorAction SilentlyContinue
    }
}
