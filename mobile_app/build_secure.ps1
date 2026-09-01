# ============================================================
# SECURE PRODUCTION BUILD SCRIPT
# ============================================================
# Use this script to build the APK with environment variables
# instead of hardcoded API keys.
#
# USAGE:
#   .\build_secure.ps1
#
# BEFORE FIRST USE:
#   1. Copy this file and rename to build_secure.local.ps1
#   2. Fill in your actual API keys in the local copy
#   3. Add build_secure.local.ps1 to .gitignore
# ============================================================

# API Keys - Replace these with your actual values for production
$env:SUPABASE_URL = "https://plftorurxmtbzmdvttdm.supabase.co"
$env:SUPABASE_ANON_KEY = "YOUR_PRODUCTION_ANON_KEY_HERE"
$env:CLOUDINARY_CLOUD_NAME = "YOUR_CLOUD_NAME_HERE"
$env:CLOUDINARY_UPLOAD_PRESET = "YOUR_UPLOAD_PRESET_HERE"

# Build with environment variables passed via --dart-define and enable code obfuscation
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=CLOUDINARY_CLOUD_NAME=$env:CLOUDINARY_CLOUD_NAME `
  --dart-define=CLOUDINARY_UPLOAD_PRESET=$env:CLOUDINARY_UPLOAD_PRESET

Write-Host ""
Write-Host "Build complete! APK is at: build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "SECURITY NOTE: API keys are injected at build time and are NOT"
Write-Host "hardcoded in the Dart source code."
