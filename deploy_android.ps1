param(
    [ValidateSet("status", "install", "update", "uninstall")]
    [string]$Action = "status",
    [string[]]$App = @(),
    [switch]$All,
    [string]$Serial,
    [string]$DistAndroidDir = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DistAndroidDir)) {
    $DistAndroidDir = Join-Path $repoRoot "dist-android"
}

$apps = @(
    @{
        Name = "password_android"
        ApplicationId = "com.cuarzopolar.password"
    },
    @{
        Name = "permission_android"
        ApplicationId = "com.cuarzopolar.permission"
    },
    @{
        Name = "phishing_android"
        ApplicationId = "com.cuarzopolar.phishing"
    }
)

$adbPath = "C:\Users\caico\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adbPath)) {
    throw "adb not found at $adbPath"
}

function Invoke-Adb {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    if ([string]::IsNullOrWhiteSpace($Serial)) {
        & $adbPath @Args
    } else {
        & $adbPath "-s" $Serial @Args
    }
}

function Resolve-SelectedApps {
    $requestedNames = @()
    foreach ($entry in $App) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            $requestedNames += ($entry -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
    }

    if ($All -or $requestedNames.Count -eq 0) {
        return @($apps)
    }

    $selected = @($apps | Where-Object { $requestedNames -contains $_.Name })
    if ($selected.Count -eq 0) {
        throw "No matching Android apps were selected."
    }
    return $selected
}

function Get-ConnectedDevices {
    $lines = @(Invoke-Adb "devices")
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list adb devices."
    }

    return @(
        $lines |
        Select-Object -Skip 1 |
        Where-Object { $_ -match '\S' } |
        ForEach-Object {
            $parts = ($_ -split '\s+') | Where-Object { $_ }
            if ($parts.Count -ge 2) {
                [PSCustomObject]@{
                    Serial = $parts[0]
                    State = $parts[1]
                }
            }
        }
    )
}

function Get-ReadyDevices {
    param(
        [object[]]$Devices
    )

    return @($Devices | Where-Object { $_.State -eq "device" })
}

function Get-AppStatus {
    param(
        [string]$ApplicationId
    )

    $pathLines = @(Invoke-Adb "shell" "pm" "path" $ApplicationId)
    if ($LASTEXITCODE -ne 0) {
        return [PSCustomObject]@{
            Installed = $false
            VersionName = ""
            VersionCode = ""
        }
    }

    $installed = $pathLines | Where-Object { $_ -match '^package:' }
    if (-not $installed) {
        return [PSCustomObject]@{
            Installed = $false
            VersionName = ""
            VersionCode = ""
        }
    }

    $dumpsys = @(Invoke-Adb "shell" "dumpsys" "package" $ApplicationId)
    $versionName = ""
    $versionCode = ""
    foreach ($line in $dumpsys) {
        if (-not $versionName -and $line -match 'versionName=([^\s]+)') {
            $versionName = $Matches[1]
        }
        if (-not $versionCode -and $line -match 'versionCode=(\d+)') {
            $versionCode = $Matches[1]
        }
        if ($versionName -and $versionCode) { break }
    }

    return [PSCustomObject]@{
        Installed = $true
        VersionName = $versionName
        VersionCode = $versionCode
    }
}

function Get-ReleaseMetadata {
    param(
        [string]$ProjectName
    )

    $projectDist = Join-Path $DistAndroidDir $ProjectName
    $versionFile = Join-Path $projectDist "version.json"
    $apkPath = Join-Path $projectDist "app-release.apk"

    if (-not (Test-Path $versionFile) -or -not (Test-Path $apkPath)) {
        return $null
    }

    $versionData = Get-Content $versionFile | ConvertFrom-Json
    return [PSCustomObject]@{
        ProjectName = $ProjectName
        ApkPath = $apkPath
        Version = $versionData.version
        Commit = $versionData.commit
        Date = $versionData.date
        Message = $versionData.message
        Apk = $versionData.apk
    }
}

$selectedApps = Resolve-SelectedApps

switch ($Action) {
    "status" {
        $devices = Get-ConnectedDevices
        $readyDevices = Get-ReadyDevices -Devices $devices
        Write-Host ""
        Write-Host "=== Devices ==="
        if ($devices.Count -eq 0) {
            Write-Host "No adb devices detected."
        } else {
            $devices | Format-Table -AutoSize
            $unauthorizedDevices = @($devices | Where-Object { $_.State -eq "unauthorized" })
            if ($unauthorizedDevices.Count -gt 0) {
                Write-Host ""
                Write-Host "Authorize the device on-screen, then rerun the command."
            }
        }

        Write-Host ""
        Write-Host "=== Android Apps ==="
        $report = foreach ($appEntry in $selectedApps) {
            $release = Get-ReleaseMetadata -ProjectName $appEntry.Name
            $deviceStatus = if ($readyDevices.Count -gt 0) { Get-AppStatus -ApplicationId $appEntry.ApplicationId } else { $null }

            [PSCustomObject]@{
                app = $appEntry.Name
                applicationId = $appEntry.ApplicationId
                localVersion = if ($release) { "v{0:D2}" -f [int]$release.Version } else { "" }
                localCommit = if ($release) { $release.Commit } else { "" }
                installed = if ($deviceStatus) { $deviceStatus.Installed } else { $false }
                deviceVersion = if ($deviceStatus) { $deviceStatus.VersionName } else { "" }
            }
        }
        $report | Format-Table -AutoSize
    }

    "install" {
        $devices = Get-ConnectedDevices
        $readyDevices = Get-ReadyDevices -Devices $devices
        if ($readyDevices.Count -eq 0) {
            throw "No authorized adb device is ready. Unlock the device, accept the RSA prompt, and rerun."
        }

        foreach ($appEntry in $selectedApps) {
            $release = Get-ReleaseMetadata -ProjectName $appEntry.Name
            if (-not $release) {
                throw "No packaged release found for $($appEntry.Name) in $DistAndroidDir"
            }

            Write-Host ""
            Write-Host "=== Installing $($appEntry.Name) ==="
            Write-Host "APK: $($release.ApkPath)"
            Invoke-Adb "install" "-r" $release.ApkPath
            if ($LASTEXITCODE -ne 0) {
                throw "adb install failed for $($appEntry.Name)"
            }
        }
    }

    "update" {
        $devices = Get-ConnectedDevices
        $readyDevices = Get-ReadyDevices -Devices $devices
        if ($readyDevices.Count -eq 0) {
            throw "No authorized adb device is ready. Unlock the device, accept the RSA prompt, and rerun."
        }

        foreach ($appEntry in $selectedApps) {
            $release = Get-ReleaseMetadata -ProjectName $appEntry.Name
            if (-not $release) {
                throw "No packaged release found for $($appEntry.Name) in $DistAndroidDir"
            }

            Write-Host ""
            Write-Host "=== Updating $($appEntry.Name) ==="
            Write-Host "APK: $($release.ApkPath)"
            Invoke-Adb "install" "-r" $release.ApkPath
            if ($LASTEXITCODE -ne 0) {
                throw "adb update failed for $($appEntry.Name)"
            }
        }
    }

    "uninstall" {
        $devices = Get-ConnectedDevices
        $readyDevices = Get-ReadyDevices -Devices $devices
        if ($readyDevices.Count -eq 0) {
            throw "No authorized adb device is ready. Unlock the device, accept the RSA prompt, and rerun."
        }

        foreach ($appEntry in $selectedApps) {
            Write-Host ""
            Write-Host "=== Uninstalling $($appEntry.Name) ==="
            $uninstallOutput = @(& {
                Invoke-Adb "uninstall" $appEntry.ApplicationId 2>&1
            })
            if ($LASTEXITCODE -ne 0) {
                $knownMissingPackage = $uninstallOutput | Where-Object {
                    $_ -match "Unknown package:" -or $_ -match "not installed for 0"
                }

                if ($knownMissingPackage) {
                    Write-Host "Package not installed; nothing to remove."
                    continue
                }

                throw "adb uninstall failed for $($appEntry.Name)"
            }
        }
    }
}
