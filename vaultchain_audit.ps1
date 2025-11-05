# vaultchain_audit.ps1
# Audit onboarding: test, doc, archive, log-only

Start-Transcript -Path "$PSScriptRoot\audit_onboard.log" -Append
Write-Host "`n🔍 Audit onboarding started..." -ForegroundColor Cyan

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
    Write-Host "❌ Tests failed. Audit halted." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# Generate docs
python vc_toolkit.py doc

# Archive snapshot
python vc_toolkit.py archive audit_snapshot

Write-Host "`n✅ Audit onboarding complete. Logs saved to audit_onboard.log" -ForegroundColor Green
Stop-Transcript