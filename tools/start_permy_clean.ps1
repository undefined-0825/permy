param(
    [string]$AvdName = "Medium_Phone_API_36.1",
    [string]$DeviceId = "emulator-5554",
    [switch]$NoWipeData,
    [switch]$NoSnapshot,
    [switch]$SkipFlutterClean,
    [switch]$UseLocalBackend,
    [string]$ApiBaseUrl = "",
    [switch]$CheckOnly,
    [switch]$VerboseFlutter
)

$ErrorActionPreference = "Stop"

function Get-AndroidHome {
    if ($env:ANDROID_HOME) {
        return $env:ANDROID_HOME
    }
    return Join-Path $HOME "AppData\\Local\\Android\\Sdk"
}

function Test-CommandExists {
    param([string]$CommandName)
    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Wait-EmulatorBoot {
    param(
        [string]$AdbPath,
        [string]$DeviceId,
        [int]$TimeoutSec = 180
    )

        $waitDeadline = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $waitDeadline) {
            try {
                & $AdbPath -s $DeviceId wait-for-device 2>$null | Out-Null
                break
            }
            catch {
                Start-Sleep -Seconds 1
            }
        }

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
            try {
                $boot = (& $AdbPath -s $DeviceId shell getprop sys.boot_completed 2>$null)
                if (($boot | Out-String).Trim() -eq "1") {
                    return
                }
            }
            catch {
                # adb 再起動直後の一時失敗（device offline等）は待機継続
        }
        Start-Sleep -Seconds 2
    }

    throw "Emulator boot timeout for $DeviceId"
}

if (-not (Test-CommandExists "flutter")) {
    throw "flutter command not found. Check PATH."
}

$androidHome = Get-AndroidHome
$adbPath = Join-Path $androidHome "platform-tools\\adb.exe"
$emulatorPath = Join-Path $androidHome "emulator\\emulator.exe"

if (-not (Test-Path $adbPath)) {
    throw "adb.exe not found: $adbPath"
}
if (-not (Test-Path $emulatorPath)) {
    throw "emulator.exe not found: $emulatorPath"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $repoRoot "frontend"

if (-not (Test-Path (Join-Path $frontendDir "pubspec.yaml"))) {
    throw "pubspec.yaml not found: $frontendDir"
}

if ($CheckOnly) {
    Write-Host "OK: prerequisites are available."
    Write-Host "ANDROID_HOME: $androidHome"
    Write-Host "AVD: $AvdName"
    Write-Host "Device: $DeviceId"
    return
}

# 既存エミュレータを停止（毎回ワイプ起動を確実化）
$currentDevices = & $adbPath devices
if ($currentDevices -match $DeviceId) {
    try {
        & $adbPath -s $DeviceId emu kill | Out-Null
        Start-Sleep -Seconds 3
    } catch {
        Write-Warning "Failed to kill existing emulator $DeviceId. Continue."
    }
}

& $adbPath kill-server | Out-Null
& $adbPath start-server | Out-Null

$emuArgs = @("-avd", $AvdName)
if (-not $NoWipeData) {
    $emuArgs += "-wipe-data"
}
if ($NoSnapshot) {
    $emuArgs += "-no-snapshot"
}

Start-Process -FilePath $emulatorPath -ArgumentList $emuArgs | Out-Null

Wait-EmulatorBoot -AdbPath $adbPath -DeviceId $DeviceId

Push-Location $frontendDir
try {
    if (-not $SkipFlutterClean) {
        flutter clean
    }

    flutter pub get

    $resolvedApiBaseUrl = $ApiBaseUrl.Trim()
    if ($UseLocalBackend -and [string]::IsNullOrWhiteSpace($resolvedApiBaseUrl)) {
        # Android emulator からホストPCの localhost へ到達するための固定アドレス
        $resolvedApiBaseUrl = "http://10.0.2.2:8000"
    }

    $runArgs = @("run", "-d", $DeviceId)
    if (-not [string]::IsNullOrWhiteSpace($resolvedApiBaseUrl)) {
        $runArgs += "--dart-define=API_BASE_URL=$resolvedApiBaseUrl"
    }

    if ($VerboseFlutter) {
        $runArgs += "--verbose"
    }

    & flutter @runArgs
}
finally {
    Pop-Location
}
