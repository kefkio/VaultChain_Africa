# =====================================================================
# VaultChain Africa Project Cleanup & Folder Setup Script
# =====================================================================

# Define base directories
$basePath = "C:\Users\kefak\Projects\Blockchain+Projects\VaultChainAfrica_v1\backend"
$automationPath = Join-Path $basePath "vc_automation"
$logPath = Join-Path $automationPath "logs"
$logFile = Join-Path $logPath "cleanup_log.txt"

# Ensure log directory exists
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

# Function for logging and printing
function Log {
    param ([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Out-File -Append -FilePath $logFile -Encoding utf8
}

# Start header
Log "==========================================================" Cyan
Log "VaultChain Africa Project Cleanup Started..." Cyan
Log "==========================================================" Cyan

# 1. Create automation folders
Log "[1/5] Creating automation folders..." Yellow
$folders = @("deployments", "transactions", "reports", "logs")

foreach ($folder in $folders) {
    $path = Join-Path $automationPath $folder
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Log "  Created folder: $path" Green
    } else {
        Log "  Folder exists: $path" DarkYellow
    }
}

# 2. Clean redundant directories
Log "`n[2/5] Cleaning redundant directories..." Yellow
$redundantDirs = @("broadcast", "artifacts", "cache", "out")

foreach ($dir in $redundantDirs) {
    $path = Join-Path $basePath $dir
    if (Test-Path $path) {
        Remove-Item -Recurse -Force $path
        Log "  Removed directory: $path" Green
    } else {
        Log "  Skipped (not found): $path" DarkYellow
    }
}

# 3. Move deployment files
Log "`n[3/5] Moving deployment files..." Yellow
$deploySrc = Join-Path $basePath "broadcast"
$deployDest = Join-Path $automationPath "deployments"

if (Test-Path $deploySrc) {
    $filesMoved = 0
    Get-ChildItem -Path $deploySrc -Recurse -Include *.json | ForEach-Object {
        $destFile = Join-Path $deployDest $_.Name
        Move-Item $_.FullName $destFile -Force
        Log "  Moved file: $($_.FullName) → $destFile" Green
        $filesMoved++
    }
    if ($filesMoved -gt 0) {
        Log "  Total deployment files moved: $filesMoved" Cyan
    } else {
        Log "  No deployment JSON files found in $deploySrc" DarkYellow
    }
} else {
    Log "  No broadcast folder found. Skipped moving files." DarkYellow
}

# 4. Clean Python cache directories
Log "`n[4/5] Removing Python cache folders..." Yellow
$pycacheDirs = Get-ChildItem -Path $basePath -Recurse -Directory -Force | Where-Object { $_.Name -eq "__pycache__" }

if ($pycacheDirs.Count -gt 0) {
    foreach ($cache in $pycacheDirs) {
        Remove-Item -Recurse -Force $cache.FullName
        Log "  Removed: $($cache.FullName)" Green
    }
    Log "  Total Python caches removed: $($pycacheDirs.Count)" Cyan
} else {
    Log "  No Python cache directories found." DarkYellow
}

# 5. Generate summary
Log "`n[5/5] Generating cleanup summary..." Yellow
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Log "Cleanup completed successfully at $date" Green
Log "All details logged to: $logFile" Cyan
Log "==========================================================" Cyan
