#!/usr/bin/env bash
# Runs the pinned Godot version, downloading it into .godot-bin/ if needed.
# Honors $GODOT if set. Usage: tools/godot.sh [godot args...]
set -euo pipefail

GODOT_VERSION="4.7.2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/.godot-bin"
BIN="$BIN_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"

if [[ -n "${GODOT:-}" ]]; then
  exec "$GODOT" "$@"
fi

if [[ ! -x "$BIN" ]]; then
  mkdir -p "$BIN_DIR"
  url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  echo "Downloading Godot ${GODOT_VERSION}..." >&2
  curl -fsSL -o "$BIN_DIR/godot.zip" "$url"
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$BIN_DIR/godot.zip" "$BIN_DIR"
  rm "$BIN_DIR/godot.zip"
  chmod +x "$BIN"
fi

exec "$BIN" "$@"
