#!/usr/bin/env sh
# Fetches aria2, yt-dlp, and ffmpeg for Linux x64 release builds.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
VERSIONS="$ROOT/tool/deps/versions.json"
OUTPUT_DIR="${1:-$ROOT/build/deps/linux-x64/bin}"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

mkdir -p "$OUTPUT_DIR"

read_json_url() {
	python3 - "$VERSIONS" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
keys = sys.argv[2].split(".")
node = data
for key in keys:
    node = node[key]
print(node["url"])
PY
}

read_json_filename() {
	python3 - "$VERSIONS" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
keys = sys.argv[2].split(".")
node = data
for key in keys:
    node = node[key]
print(node["filename"])
PY
}

download() {
	url="$1"
	dest="$2"
	echo "Downloading $url"
	curl -fsSL "$url" -o "$dest"
}

# yt-dlp script
ytdlp_url="$(read_json_url linux.yt_dlp)"
ytdlp_name="$(read_json_filename linux.yt_dlp)"
download "$ytdlp_url" "$TEMP/ytdlp"
install -m 755 "$TEMP/ytdlp" "$OUTPUT_DIR/$ytdlp_name"

# ffmpeg from tar.xz
ffmpeg_url="$(read_json_url linux.ffmpeg)"
ffmpeg_name="$(read_json_filename linux.ffmpeg)"
download "$ffmpeg_url" "$TEMP/ffmpeg.tar.xz"
mkdir -p "$TEMP/ffmpeg"
tar -xJf "$TEMP/ffmpeg.tar.xz" -C "$TEMP/ffmpeg"
ffmpeg_bin="$(find "$TEMP/ffmpeg" -type f -name ffmpeg | head -n 1)"
if [ -z "$ffmpeg_bin" ]; then
	echo "ffmpeg binary not found in archive" >&2
	exit 1
fi
install -m 755 "$ffmpeg_bin" "$OUTPUT_DIR/$ffmpeg_name"

# aria2c from tar.gz
aria_url="$(read_json_url linux.aria2)"
aria_name="$(read_json_filename linux.aria2)"
download "$aria_url" "$TEMP/aria2.tar.gz"
mkdir -p "$TEMP/aria2"
tar -xzf "$TEMP/aria2.tar.gz" -C "$TEMP/aria2"
aria_bin="$(find "$TEMP/aria2" -type f -name aria2c | head -n 1)"
if [ -z "$aria_bin" ]; then
	echo "aria2c binary not found in archive" >&2
	exit 1
fi
install -m 755 "$aria_bin" "$OUTPUT_DIR/$aria_name"

echo "Bundled tools written to $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
