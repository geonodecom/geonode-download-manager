# Install Geonode Download Manager under %LOCALAPPDATA%\geonode-download-manager and register Chromium native messaging hosts.
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$InstallDir = Join-Path $env:LOCALAPPDATA "geonode-download-manager"
$BundleDir = Join-Path $Root "build\windows\x64\runner\Release"
$HostSrc = Join-Path $Root "build\geonode-download-manager-host.exe"
$ManifestTemplate = Join-Path $Root "packaging\com.fhsinchy.geonode_download_manager.json"
$NativeHostName = "com.fhsinchy.geonode_download_manager"

if (-not (Test-Path (Join-Path $BundleDir "geonode-download-manager.exe"))) {
  Write-Host "Release bundle missing. Running build.ps1..."
  & (Join-Path $PSScriptRoot "build.ps1")
}

if (-not (Test-Path $HostSrc)) {
  throw "Missing $HostSrc — run tool/windows/build.ps1 first."
}

Write-Host "Installing to $InstallDir"
if (Test-Path $InstallDir) {
  Remove-Item -Recurse -Force $InstallDir
}
New-Item -ItemType Directory -Path $InstallDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $BundleDir "*") $InstallDir
Copy-Item -Force $HostSrc (Join-Path $InstallDir "geonode-download-manager-host.exe")

$HostPath = Join-Path $InstallDir "geonode-download-manager-host.exe"
$ManifestDir = Join-Path $InstallDir "NativeMessagingHosts"
New-Item -ItemType Directory -Path $ManifestDir -Force | Out-Null
$ManifestPath = Join-Path $ManifestDir "$NativeHostName.json"

$template = Get-Content -Raw $ManifestTemplate
# JSON path must use escaped backslashes
$jsonHostPath = $HostPath.Replace('\', '\\')
$manifest = $template.Replace('GEONODE_HOST_PATH', $jsonHostPath)
Set-Content -Path $ManifestPath -Value $manifest -Encoding UTF8

$RegistryKeys = @(
  "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$NativeHostName",
  "HKCU:\Software\Chromium\NativeMessagingHosts\$NativeHostName",
  "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$NativeHostName",
  "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\$NativeHostName"
)

foreach ($key in $RegistryKeys) {
  New-Item -Path $key -Force | Out-Null
  Set-ItemProperty -Path $key -Name "(default)" -Value $ManifestPath
  Write-Host "Registered $key"
}

# Start Menu shortcut
$StartMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$ShortcutPath = Join-Path $StartMenu "Geonode Download Manager.lnk"
$Wsh = New-Object -ComObject WScript.Shell
$Shortcut = $Wsh.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = Join-Path $InstallDir "geonode-download-manager.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "Geonode Download Manager"
$Shortcut.Save()
Write-Host "Start Menu shortcut: $ShortcutPath"

Write-Host "Installed Geonode Download Manager."
Write-Host "  App:      $(Join-Path $InstallDir 'geonode-download-manager.exe')"
Write-Host "  Host:     $(Join-Path $InstallDir 'geonode-download-manager-host.exe')"
Write-Host "  Manifest: $ManifestPath"
