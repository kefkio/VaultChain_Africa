# vaultchain_deploy.ps1
# Deployment onboarding: test, deploy, simulate, archive, tag

Start-Transcript -Path "$PSScriptRoot\deploy_onboard.log" -Append
Write-Host "`n🚀 Deployment onboarding started..." -ForegroundColor Cyan

# Activate virtual environment
$venvPath = "$PSScriptRoot\venv\Scripts\Activate.ps1"
if (Test-Path $venvPath) {
    Write-Host "✅ Activating virtual environment..." -ForegroundColor Green
    & $venvPath
} else {
    Write-Host "❌ Virtual environment not found." -ForegroundColor Red
    exit 1
}

# Run tests
python vc_toolkit.py test
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Tests failed. Aborting deployment." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# Deploy contract
python vc_toolkit.py deploy backend/contracts/pool/PoolVaultERC4626.abi backend/contracts/pool/PoolVaultERC4626.bytecode

# Simulate transaction
python vc_toolkit.py simulate 0xYourContractAddress backend/contracts/pool/PoolVaultERC4626.abi 1000

# Archive project
python vc_toolkit.py archive v2

# Git tag and push
git tag "v2"
git push origin "v2"

Write-Host "`n✅ Deployment onboarding complete." -ForegroundColor Green
Stop-Transcript