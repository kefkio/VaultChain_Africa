# ================================
# VaultChainAfrica Deployment Script
# ================================
# Author: Kefa — Tax & Treasury Digitization Lead
# Purpose: Modular deployment with transcript logging and error hygiene

# --- Stage 0: Setup ---
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = "vc_automation/logs/deploy_log_$timestamp.txt"
New-Item -ItemType File -Path $logPath -Force | Out-Null
Write-Output "=== VaultChainAfrica Deployment Started at $timestamp ===" | Tee-Object -FilePath $logPath -Append

# --- Stage 1: Clean & Build ---
Write-Output "`n[Stage 1] Cleaning and building contracts..." | Tee-Object -FilePath $logPath -Append
forge clean | Tee-Object -FilePath $logPath -Append
forge build | Tee-Object -FilePath $logPath -Append

# --- Stage 2: Run Tests ---
Write-Output "`n[Stage 2] Running tests..." | Tee-Object -FilePath $logPath -Append
forge test -vv | Tee-Object -FilePath $logPath -Append

# --- Stage 3: Deploy Contracts ---
Write-Output "`n[Stage 3] Deploying contracts..." | Tee-Object -FilePath $logPath -Append
$rpcUrl = "http://127.0.0.1:8545"
$chainId = 31337
$deployCmd = "forge script script/Deploy.s.sol --rpc-url $rpcUrl --broadcast --chain-id $chainId"
Invoke-Expression $deployCmd | Tee-Object -FilePath $logPath -Append

# --- Stage 4: Validate Deployment Summary ---
$summaryPath = "vc_automation/deployments/$chainId/deployment_summary_$timestamp.json"
if (Test-Path $summaryPath) {
    Write-Output "`n[Stage 4] Deployment summary found: $summaryPath" | Tee-Object -FilePath $logPath -Append
} else {
    Write-Output "`n[Stage 4] ❌ No deployment summary found. Check Deploy.s.sol for missing console logs." | Tee-Object -FilePath $logPath -Append
}

# --- Final Stage ---
Write-Output "`n✅ Deployment completed. Full log stored at $logPath" | Tee-Object -FilePath $logPath -Append

Set-Alias vdeploy "$PWD\vaultchain_deploy.ps1"