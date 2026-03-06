param(
    [string]$DeviceId = "emulator-5554",
    [switch]$LaunchEmulator,
    [switch]$Clean,
    [switch]$Verbose,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param([string]$CommandName)

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandExists "flutter")) {
    throw "flutter command not found. Check PATH."
}

$frontendDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath "frontend"
pushd $frontendDir
try {
    if (-not (Test-Path "pubspec.yaml")) {
        throw "pubspec.yaml was not found in frontend directory."
    }

    if ($LaunchEmulator) {
        flutter emulators --launch Medium_Phone_API_36.1
        Start-Sleep -Seconds 20
    }

    if ($Clean) {
        flutter clean
    }

    $devices = flutter devices
    if (-not ($devices -match $DeviceId)) {
        throw "Device '$DeviceId' was not found. Check output of flutter devices."
    }

    if ($CheckOnly) {
        Write-Host "OK: frontend preflight check completed."
        return
    }

    if ($Verbose) {
        flutter run -d $DeviceId --verbose
    }
    else {
        flutter run -d $DeviceId
    }
}
finally {
    popd
}
