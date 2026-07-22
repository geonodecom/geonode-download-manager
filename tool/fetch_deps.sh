#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tool/linux/fetch_deps.sh" "$@"
