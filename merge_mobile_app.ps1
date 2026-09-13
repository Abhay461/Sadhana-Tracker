# Powershell script to merge mobile_app into root project directory and cleanup unused code

$rootDir = "d:\work update app"
$mobileAppDir = Join-Path $rootDir "mobile_app"

Write-Host "Starting project cleanup and merge..." -ForegroundColor Cyan

# Folders to replace in root
$foldersToReplace = @("lib", "android", "ios", "assets", "test", "web", "windows", "linux", "macos", ".dart_tool", "build")

foreach ($folder in $foldersToReplace) {
    $targetPath = Join-Path $rootDir $folder
    $sourcePath = Join-Path $mobileAppDir $folder
    
    if (Test-Path $sourcePath) {
        if (Test-Path $targetPath) {
            Write-Host "Removing outdated root folder: $folder" -ForegroundColor Gray
            Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "Moving production mobile_app/$folder to root..." -ForegroundColor Green
        Move-Item -Path $sourcePath -Destination $targetPath -Force
    }
}

# Key root files to copy from mobile_app
$filesToMove = @(
    "pubspec.yaml",
    "pubspec.lock",
    ".gitignore",
    ".metadata",
    "analysis_options.yaml",
    "devtools_options.yaml",
    "privacy_policy.html",
    "privacy_policy.txt",
    "build_play_store.ps1",
    "build_play_store.local.ps1",
    "build_secure.ps1",
    "build_secure.local.ps1",
    "run_secure.local.ps1",
    "mobile_app.iml"
)

foreach ($file in $filesToMove) {
    $sourceFile = Join-Path $mobileAppDir $file
    $targetFile = Join-Path $rootDir $file
    if (Test-Path $sourceFile) {
        Write-Host "Moving $file to root..." -ForegroundColor Green
        Move-Item -Path $sourceFile -Destination $targetFile -Force
    }
}

# Cleanup leftover temp/unnecessary files in root
$unusedFiles = @(
    "copy_logo.dart",
    "copy_logo.js",
    "copy_logo.py",
    "supabase_rls_policies.sql",
    "test_db.py",
    "schema.json",
    "lib\test_supabase.dart",
    "PHASE_25_FINAL_REAL_DEVICE_QA_REPORT.md",
    "PHASE_26_FINAL_PRODUCTION_DEPLOYMENT_REPORT.md",
    "PHASE_27_FINAL_PRODUCTION_STABILITY_REPORT.md",
    "PHASE_28_SYSTEM_MAINTENANCE_SAFETY_BASELINE_REPORT.md"
)

foreach ($tf in $unusedFiles) {
    $tfPath = Join-Path $rootDir $tf
    if (Test-Path $tfPath) {
        Write-Host "Deleting unused file: $tf" -ForegroundColor Yellow
        Remove-Item -Path $tfPath -Force -ErrorAction SilentlyContinue
    }
}

# Delete remaining mobile_app directory if it exists
if (Test-Path $mobileAppDir) {
    Write-Host "Removing redundant mobile_app directory..." -ForegroundColor Green
    Remove-Item -Path $mobileAppDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Cleanup and Merge completed successfully!" -ForegroundColor Green
Write-Host "Run 'flutter pub get' and 'flutter run' now." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
