# Backward-compatible entry point. Prefer tool/android/fetch_deps.ps1
& (Join-Path $PSScriptRoot "fetch_deps.ps1") @args
