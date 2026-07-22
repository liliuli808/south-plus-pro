param(
  [ValidateSet("debug", "release")]
  [string]$Mode = "debug"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "=== Building South Plus APK ($Mode) ===" -ForegroundColor Cyan
Write-Host ""

# Check Flutter
$flutter = Get-Command "flutter" -ErrorAction SilentlyContinue
if (-not $flutter) {
  Write-Error "Flutter not found. Install from https://docs.flutter.dev/get-started/install"
  exit 1
}

Write-Host "Flutter version:" -NoNewline
flutter --version 2>&1 | Select-Object -First 1

# Get dependencies
Write-Host ""
Write-Host ">>> Getting dependencies..." -ForegroundColor Yellow
Set-Location -LiteralPath $ProjectRoot
flutter pub get
if (-not $?) { exit 1 }

# Analyze
Write-Host ""
Write-Host ">>> Running analysis..." -ForegroundColor Yellow
flutter analyze
if (-not $?) { Write-Warning "Analysis has warnings" }

# Build APK
Write-Host ""
Write-Host ">>> Building APK ($Mode)..." -ForegroundColor Yellow
if ($Mode -eq "release") {
  flutter build apk --release --split-per-abi
  flutter build apk --release
} else {
  flutter build apk --debug
}

if ($?) {
  Write-Host ""
  Write-Host "=== Build successful! ===" -ForegroundColor Green
  Get-ChildItem -Path "$ProjectRoot\build\app\outputs\flutter-apk" -Filter "*.apk" | ForEach-Object {
    Write-Host "  $($_.Name) ($([math]::Round($_.Length / 1MB, 1)) MB)"
  }
}
