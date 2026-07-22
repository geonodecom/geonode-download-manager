# Fetches yt-dlp and ffmpeg binaries for Android builds.
param(
    [string]$OutputRoot = "assets/bin/android"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$VersionsFile = Join-Path $Root "tool/deps/versions.json"
$Versions = Get-Content -Raw $VersionsFile | ConvertFrom-Json
$Android = $Versions.android

$Abis = @("arm64-v8a", "armeabi-v7a", "x86_64")
$Temp = Join-Path $env:TEMP "geonode-deps-android"
if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
New-Item -ItemType Directory -Force -Path $Temp | Out-Null

function Save-Url([string]$Url, [string]$Dest) {
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

function Extract-FromZip([string]$ZipPath, [string]$Dest) {
    $extractDir = Join-Path $Temp ([System.IO.Path]::GetRandomFileName())
    Expand-Archive -Path $ZipPath -DestinationPath $extractDir -Force
    $match = Get-ChildItem -Path $extractDir -Recurse -File |
        Where-Object {
            $_.Name -eq 'ffmpeg' -or $_.Name -eq 'ffmpeg.exe'
        } |
        Select-Object -First 1
    if ($null -eq $match) {
        # Some archives nest under ABI folders with only libs; try common paths.
        $match = Get-ChildItem -Path $extractDir -Recurse -File |
            Where-Object { $_.Name -like 'ffmpeg*' -and $_.Extension -in @('', '.exe') } |
            Select-Object -First 1
    }
    if ($null -eq $match) {
        Get-ChildItem -Path $extractDir -Recurse | Select-Object FullName | Format-Table | Out-String | Write-Host
        throw "Could not find ffmpeg executable in $ZipPath"
    }
    Copy-Item -Force $match.FullName $Dest
}

# yt-dlp (same script for all ABIs; requires Python on device or standalone wrapper)
$ytdlpTemp = Join-Path $Temp "yt-dlp"
Save-Url $Android.yt_dlp.url $ytdlpTemp

foreach ($abi in $Abis) {
    $targetDir = Join-Path $OutputRoot $abi
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    Copy-Item -Force $ytdlpTemp (Join-Path $targetDir "yt-dlp")
    Write-Host "Installed yt-dlp for $abi"

    $ffmpegConfig = $Android.ffmpeg.$abi
    if ($null -eq $ffmpegConfig) {
        throw "Missing ffmpeg config for $abi in versions.json"
    }

    $ffmpegZip = Join-Path $Temp "$abi-ffmpeg.zip"
    Save-Url $ffmpegConfig.url $ffmpegZip
    Extract-FromZip $ffmpegZip (Join-Path $targetDir $ffmpegConfig.filename)
    Write-Host "Installed ffmpeg for $abi"
}

foreach ($abi in $Abis) {
    foreach ($name in @("yt-dlp", "ffmpeg")) {
        $path = Join-Path $OutputRoot "$abi/$name"
        if (-not (Test-Path $path)) {
            throw "Missing required binary: $path"
        }
    }
}

Write-Host "Done. Android bundled tools are ready under $OutputRoot"
