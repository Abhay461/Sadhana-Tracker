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

# API Keys - Replace these with your actual values for production
$env:SUPABASE_URL = "https://plftorurxmtbzmdvttdm.supabase.co"
$env:SUPABASE_ANON_KEY = "YOUR_PRODUCTION_ANON_KEY_HERE"
$env:ONESIGNAL_APP_ID = "YOUR_ONESIGNAL_APP_ID_HERE"

# Build App Bundle (.aab) with environment variables passed via --dart-define and enable code obfuscation
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=ONESIGNAL_APP_ID=$env:ONESIGNAL_APP_ID

Write-Host ""
Write-Host "Build complete! App Bundle (AAB) is at: build\app\outputs\bundle\release\app-release.aab"
Write-Host ""
Write-Host "SECURITY NOTE: API keys are injected at build time and are NOT"
Write-Host "hardcoded in the Dart source code."
