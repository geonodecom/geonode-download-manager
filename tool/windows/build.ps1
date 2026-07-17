# Build GeoNode Download Manager for Windows (release) and geonode-download-manager-host.exe
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

Write-Host "Building Flutter Windows release..."
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release

Write-Host "Building geonode-download-manager-host..."
$HostOut = Join-Path $Root "build\geonode-download-manager-host-cli"
dart build cli -t bin/geonode_download_manager_host.dart -o $HostOut

$HostBin = Join-Path $HostOut "bundle\bin\geonode_download_manager_host.exe"
if (-not (Test-Path $HostBin)) {
  # Older/dart layout may omit .exe in path listing
  $alt = Get-ChildItem -Path (Join-Path $HostOut "bundle\bin") -Filter "geonode_download_manager_host*" | Select-Object -First 1
  if ($null -eq $alt) { throw "geonode-download-manager-host binary not found under $HostOut" }
  $HostBin = $alt.FullName
}

$HostCopy = Join-Path $Root "build\geonode-download-manager-host.exe"
Copy-Item -Force $HostBin $HostCopy
Write-Host "Built: $HostCopy"
Write-Host "App bundle: $(Join-Path $Root 'build\windows\x64\runner\Release')"
