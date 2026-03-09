# generate_telemetry_secret.ps1
# Permy Telemetry Hash Secret Generator
#
# Usage: .\tools\generate_telemetry_secret.ps1
# Output: 64-character hexadecimal string (256-bit cryptographically secure random)

param()

Write-Host "=== Permy Telemetry Hash Secret Generator ===" -ForegroundColor Cyan
Write-Host ""

# Generate 32 random bytes (256 bits) using cryptographically secure RNG
$bytes = [byte[]]::new(32)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)

# Convert to hexadecimal string (64 characters)
$secret = -join ($bytes | ForEach-Object { $_.ToString("x2") })

Write-Host "Generated TELEMETRY_HASH_SECRET:" -ForegroundColor Green
Write-Host $secret -ForegroundColor White
Write-Host ""
Write-Host "Set this in Render Environment Variables:" -ForegroundColor Yellow
Write-Host "  Key:   TELEMETRY_HASH_SECRET"
Write-Host "  Value: $secret"
Write-Host ""
Write-Host "Or save to .env (local development only):" -ForegroundColor Yellow
Write-Host "  TELEMETRY_HASH_SECRET=$secret"
Write-Host ""
Write-Host "WARNING: Keep this secret secure. Never commit to Git." -ForegroundColor Red
