#!/usr/bin/env sh
set -eu

missing=0
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
BUNDLED_BIN="$ROOT/build/deps/linux-x64/bin"

need_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$1" >&2
		missing=1
	fi
}

has_bundled() {
	[ -x "$BUNDLED_BIN/$1" ] || [ -x "$BUNDLED_BIN/${1}.exe" ]
}

need_download_tool() {
	name="$1"
	if has_bundled "$name"; then
		return 0
	fi
	if command -v "$name" >/dev/null 2>&1; then
		return 0
	fi
	printf 'Missing download tool: %s (run make fetch-deps or install on PATH)\n' "$name" >&2
	missing=1
}

need_command flutter
need_command dart
need_command clang++
need_command pkg-config

need_download_tool aria2c
need_download_tool yt-dlp
need_download_tool ffmpeg

if has_bundled yt-dlp && ! command -v python3 >/dev/null 2>&1; then
	printf 'Bundled yt-dlp requires python3 on Linux when not using a standalone build.\n' >&2
	missing=1
fi

if command -v pkg-config >/dev/null 2>&1; then
	if ! pkg-config --exists ayatana-appindicator3-0.1 &&
		! pkg-config --exists appindicator3-0.1; then
		printf 'Missing AppIndicator development package. Install libayatana-appindicator3-dev or libappindicator3-dev.\n' >&2
		missing=1
	fi
fi

if command -v clang++ >/dev/null 2>&1; then
	clangpp=$(readlink -f "$(command -v clang++)")
	clang_dir=$(dirname "$clangpp")
	if [ ! -x "$clang_dir/ld.lld" ] && [ ! -x "$clang_dir/ld" ]; then
		printf 'Missing linker next to clang++: %s\n' "$clang_dir" >&2
		printf 'Flutter native assets expect ld.lld or ld in that directory. On Ubuntu 26.04, install lld-21.\n' >&2
		missing=1
	fi
fi

exit "$missing"
