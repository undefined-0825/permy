param(
    [int]$BuildIncrement = 1,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

if ($BuildIncrement -lt 1) {
    throw "BuildIncrement must be 1 or greater."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $repoRoot "frontend"
$pubspecPath = Join-Path $frontendDir "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml was not found: $pubspecPath"
}

$pubspecContent = Get-Content -Path $pubspecPath -Raw
$versionPattern = '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$'
$match = [regex]::Match($pubspecContent, $versionPattern)

if (-not $match.Success) {
    throw "version line was not found or has unsupported format in pubspec.yaml"
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$build = [int]$match.Groups[4].Value
$newBuild = $build + $BuildIncrement

$oldVersion = "$major.$minor.$patch+$build"
$newVersion = "$major.$minor.$patch+$newBuild"
$newPubspec = [regex]::Replace($pubspecContent, $versionPattern, "version: $newVersion", 1)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pubspecPath, $newPubspec, $utf8NoBom)

Write-Host "Updated version: $oldVersion -> $newVersion"

if ($SkipBuild) {
    Write-Host "SkipBuild is set. Version update only."
    exit 0
}

Push-Location $frontendDir
try {
    flutter pub get
    flutter build appbundle
}
finally {
    Pop-Location
}

$aabPath = Join-Path $frontendDir "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabPath) {
    Write-Host "AAB generated: $aabPath"
}
