# Dispatch dependency fetch to the platform-specific script.
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

if ($IsWindows -or $env:OS -match "Windows") {
    & (Join-Path $Root "tool/windows/fetch_deps.ps1") @args
    exit $LASTEXITCODE
}

Write-Host "Use tool/linux/fetch_deps.sh or tool/android/fetch_deps.ps1 on this platform." -ForegroundColor Yellow
exit 1
