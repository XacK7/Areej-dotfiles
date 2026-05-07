# Push current branch to origin, then trigger update on the Areej machine.
# Usage: .\deploy.ps1
#        $env:AREEJ_HOST = "user@host"; .\deploy.ps1

$ErrorActionPreference = "Stop"

$Host_ = if ($env:AREEJ_HOST) { $env:AREEJ_HOST } else { "areej@192.168.1.9" }
$Branch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Deploy: pushing '$Branch' to origin, then updating $Host_"
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

git diff-index --quiet HEAD --
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Working tree has uncommitted changes. Commit first." -ForegroundColor Red
    git status --short
    exit 1
}

Write-Host "[1/2] git push origin $Branch"
git push origin $Branch
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "[2/2] ssh $Host_ './Areej-dotfiles/update.sh'"
ssh $Host_ "cd ~/Areej-dotfiles && ./update.sh"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host "  Deployed."
Write-Host "===================================================" -ForegroundColor Green
