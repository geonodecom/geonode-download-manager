#!/usr/bin/env sh
set -eu

missing=0

need_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$1" >&2
		missing=1
	fi
}

need_command flutter
need_command dart
need_command clang++
need_command pkg-config
need_command aria2c

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
