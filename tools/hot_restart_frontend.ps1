param(
    [string]$DeviceId = "emulator-5554",
    [string]$PackageName = "jp.sukimalab.permy",
    [switch]$ClearAppData,
    [switch]$ClearBackendDb,
    [switch]$FlushRedis,
    [switch]$FullLocalReset,
    [switch]$NoFallback,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param([string]$CommandName)
    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-AndroidHome {
    if ($env:ANDROID_HOME) {
        return $env:ANDROID_HOME
    }
    return Join-Path $HOME "AppData\\Local\\Android\\Sdk"
}

function Get-RepoRoot {
    return Split-Path -Parent $PSScriptRoot
}

function Assert-DeviceConnected {
    param(
        [string]$AdbPath,
        [string]$DeviceId
    )

    $devices = & $AdbPath devices
    if (-not ($devices -match "^$DeviceId\s+device")) {
        throw "Device '$DeviceId' is not connected."
    }
}

function Reset-AppData {
    param(
        [string]$AdbPath,
        [string]$DeviceId,
        [string]$PackageName
    )

    Write-Host "Clearing app data for $PackageName ..."
    & $AdbPath -s $DeviceId shell pm clear $PackageName | Out-Null
}

function Reset-BackendDb {
    param([string]$RepoRoot)

    $dbPath = Join-Path $RepoRoot "backend\permy.db"
    if (Test-Path $dbPath) {
        Remove-Item $dbPath -Force
        Write-Host "Deleted local SQLite DB: $dbPath"
        Write-Warning "If uvicorn is running, restart it so the new DB is recreated cleanly."
        return
    }

    Write-Host "Local SQLite DB not found: $dbPath"
}

function Reset-RedisState {
    if (-not (Test-CommandExists "redis-cli")) {
        Write-Warning "redis-cli not found. Skipping Redis flush."
        return
    }

    Write-Host "Flushing local Redis DB 0 ..."
    & redis-cli -n 0 FLUSHDB | Out-Null
}

if (-not (Test-CommandExists "flutter")) {
    throw "flutter command not found. Check PATH."
}

$androidHome = Get-AndroidHome
$adbPath = Join-Path $androidHome "platform-tools\\adb.exe"
if (-not (Test-Path $adbPath)) {
    throw "adb.exe not found: $adbPath"
}

$repoRoot = Get-RepoRoot

if ($FullLocalReset) {
    $ClearAppData = $true
    $ClearBackendDb = $true
    $FlushRedis = $true
}

Assert-DeviceConnected -AdbPath $adbPath -DeviceId $DeviceId

if ($CheckOnly) {
    Write-Host "OK: hot restart preflight check completed."
    Write-Host "Device: $DeviceId"
    Write-Host "Package: $PackageName"
    Write-Host "Repo: $repoRoot"
    return
}

if ($ClearBackendDb) {
    Reset-BackendDb -RepoRoot $repoRoot
}

if ($FlushRedis) {
    Reset-RedisState
}

if ($ClearAppData) {
    Reset-AppData -AdbPath $adbPath -DeviceId $DeviceId -PackageName $PackageName
}

# flutter attach に R を送って hot restart を実行
$attachInput = "R`nq`n"
$hotRestartSucceeded = $false

try {
    Write-Host "Trying hot restart via flutter attach..."
    $null = $attachInput | flutter attach -d $DeviceId

    if ($LASTEXITCODE -eq 0) {
        $hotRestartSucceeded = $true
        Write-Host "Hot restart completed via flutter attach."
    }
}
catch {
    Write-Warning "flutter attach failed: $($_.Exception.Message)"
}

if ($hotRestartSucceeded) {
    return
}

if ($NoFallback) {
    throw "Hot restart failed and fallback is disabled."
}

Write-Warning "Hot restart failed. Fallback: restart app process only (no emulator reboot)."
& $adbPath -s $DeviceId shell am force-stop $PackageName | Out-Null
& $adbPath -s $DeviceId shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null

Write-Host "App process restarted on $DeviceId."
