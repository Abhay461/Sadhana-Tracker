# ============================================================
# PLAY STORE PRODUCTION BUILD SCRIPT (AAB)
# ============================================================
# Use this script to build the App Bundle (.aab) with environment
# variables instead of hardcoded API keys.
#
# USAGE:
#   .\build_play_store.ps1
#
# BEFORE FIRST USE:
#   1. Copy this file and rename to build_play_store.local.ps1
#   2. Fill in your actual production API keys in the local copy
#   3. Add build_play_store.local.ps1 to .gitignore
# ============================================================

# API Base URL configuration
$env:API_BASE_URL = "https://sadhana-tracker-qq6m.onrender.com/api/v1"

# Build App Bundle (.aab) with environment variables passed via --dart-define and enable code obfuscation
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols `
  --dart-define=API_BASE_URL=$env:API_BASE_URL

Write-Host ""
Write-Host "Build complete! App Bundle (AAB) is at: build\app\outputs\bundle\release\app-release.aab"
Write-Host ""
Write-Host "SECURITY NOTE: API keys are injected at build time and are NOT"
Write-Host "hardcoded in the Dart source code."
