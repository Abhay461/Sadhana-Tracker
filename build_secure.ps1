# ============================================================
# SECURE PRODUCTION BUILD SCRIPT
# ============================================================
# Use this script to build the APK with environment variables
# instead of hardcoded API keys.
# ============================================================

$env:API_BASE_URL = "https://sadhana-tracker-qq6m.onrender.com/api/v1"
$env:CLOUDINARY_CLOUD_NAME = "YOUR_CLOUD_NAME_HERE"
$env:CLOUDINARY_UPLOAD_PRESET = "YOUR_UPLOAD_PRESET_HERE"

# Build with environment variables passed via --dart-define and enable code obfuscation
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols `
  --dart-define=API_BASE_URL=$env:API_BASE_URL `
  --dart-define=CLOUDINARY_CLOUD_NAME=$env:CLOUDINARY_CLOUD_NAME `
  --dart-define=CLOUDINARY_UPLOAD_PRESET=$env:CLOUDINARY_UPLOAD_PRESET

Write-Host ""
Write-Host "Build complete! APK is at: build\app\outputs\flutter-apk\app-release.apk"
