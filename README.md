<p align="center">
  <strong>Fast, opinionated download manager powered by aria2.</strong>
</p>

## Status

GeoNode Download Manager is a Linux-first Flutter desktop app with Windows support. The app uses
system `aria2c` as its download engine and focuses on fast segmented downloads,
simple queueing, robust resume, and useful download details.

## Features

- Material 3 Flutter desktop UI
- Local aria2 process managed by GeoNode Download Manager
- One-active-download queue by default
- Pause, resume, retry, remove, and reorder
- SQLite-backed history, queue, and settings
- Download details with aria2 piece map
- System tray integration
- Chromium extension handoff through a native messaging host

## Requirements

### Common

- Flutter 3.41+
- Dart 3.11+
- `aria2c` 1.37+ on `PATH` (or set a custom path in Settings)

### Linux

- Linux desktop build dependencies for Flutter
- AppIndicator/Ayatana development headers for tray support
- `lld-21` or another linker available next to `clang++`

On Debian/Ubuntu-like systems:

```sh
sudo apt install aria2 clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev libayatana-appindicator3-dev lld-21
```

On Fedora:

```sh
sudo dnf install aria2 clang cmake ninja-build pkgconf-pkg-config gtk3-devel libstdc++-devel libayatana-appindicator-gtk3-devel lld
```

### Windows

- [Visual Studio](https://visualstudio.microsoft.com/) with the **Desktop development with C++** workload
- Windows Developer Mode enabled (Flutter plugin symlinks), or equivalent symlink privilege
- `aria2c.exe` on `PATH` (for example via [Scoop](https://scoop.sh/) `scoop install aria2` or [Chocolatey](https://chocolatey.org/) `choco install aria2`)

## Development

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

### Linux

```sh
make run
# or
flutter run -d linux
```

The Makefile also provides:

```sh
make run          # debug launch through Flutter
make run-log      # debug launch and write stdout/stderr to the user state dir
make run-verbose  # debug launch with verbose Flutter logs
make build-debug
make run-debug-bundle
```

### Windows

```powershell
flutter run -d windows
```

## Chromium Extension

### Linux

`make install` installs the GeoNode Download Manager app, the `geonode-download-manager-host` native messaging bridge,
and native host manifests for Google Chrome, Chromium, and Brave.

### Windows

`tool/windows/install.ps1` installs under `%LOCALAPPDATA%\geonode-download-manager`, copies
`geonode-download-manager-host.exe`, writes the native messaging manifest, and registers HKCU
keys for Chrome, Chromium, Edge, and Brave.

To use the extension during development:

1. Install GeoNode Download Manager (`make install` on Linux, or `powershell -File tool/windows/install.ps1` on Windows).
2. Open `chrome://extensions`, `edge://extensions`, or `brave://extensions`.
3. Enable Developer mode.
4. Choose **Load unpacked** and select `extensions/chrome`.

The extension adds a **Download with GeoNode** link context-menu item. Automatic
download capture is off by default and can be enabled from the extension popup.
Manual captures can launch GeoNode Download Manager when needed. Automatic captures only hand off to
an already-running GeoNode Download Manager instance; if GeoNode Download Manager is unavailable, the extension falls
back to the browser download and shows a notification.

On Windows, the running app publishes a loopback TCP endpoint file at
`%LOCALAPPDATA%\geonode-download-manager\extension-endpoint.json` for `geonode-download-manager-host`. Linux continues
to use a Unix domain socket under `$XDG_RUNTIME_DIR`.

## Build

### Linux

```sh
make build
```

The release bundle is written to `build/linux/x64/release/bundle/`.

### Windows

```powershell
powershell -File tool/windows/build.ps1
```

The release bundle is written to `build/windows/x64/runner/Release/`.
`build/geonode-download-manager-host.exe` is produced for native messaging.

## Install Locally

### Linux

```sh
make install
```

This builds and installs the release bundle under `~/.local/share/geonode-download-manager`, creates
`~/.local/bin/geonode-download-manager`, installs the desktop entry and icon, and installs the
native messaging host.

If you already ran `make build`, install the existing build without rebuilding:

```sh
make install-built
```

To uninstall:

```sh
make uninstall
```

### Windows

```powershell
powershell -File tool/windows/install.ps1
```

This installs to `%LOCALAPPDATA%\geonode-download-manager`, creates a Start Menu shortcut, and
registers native messaging hosts for Chrome, Chromium, Edge, and Brave.

To uninstall:

```powershell
powershell -File tool/windows/uninstall.ps1
```

## License

[MIT](LICENSE)
