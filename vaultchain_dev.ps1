# vaultchain_dev.ps1
# Developer onboarding: scaffold, test, doc, Git commit

Start-Transcript -Path "$PSScriptRoot\dev_onboard.log" -Append
Write-Host "`n👨‍💻 Developer onboarding started..." -ForegroundColor Cyan

# Activate virtual environment
$venvPath = "$PSScriptRoot\venv\Scripts\Activate.ps1"
if (Test-Path $venvPath) {
    Write-Host "✅ Activating virtual environment..." -ForegroundColor Green
    & $venvPath
} else {
    Write-Host "❌ Virtual environment not found." -ForegroundColor Red
    exit 1
}

# Scaffold contracts
python vc_toolkit.py scaffold --force

# Run tests
python vc_toolkit.py test
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Tests failed. Aborting Git update." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# Generate docs
python vc_toolkit.py doc

# Git commit
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -am "👨‍💻 Dev onboarding: scaffold + test + doc [$timestamp]"
git push

Write-Host "`n✅ Developer onboarding complete." -ForegroundColor Green
Stop-Transcript