#!/usr/bin/env bash
# Runs the pinned Godot version, downloading it into .godot-bin/ if needed.
# Honors $GODOT if set. Usage: tools/godot.sh [godot args...]
set -euo pipefail

GODOT_VERSION="4.7.2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/.godot-bin"
BIN="$BIN_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"

# A fresh checkout has no class cache, so scripts using class_name fail until an import has run.
ensure_imported() {
  local bin="$1"; shift
  [[ -f "$ROOT/.godot/global_script_class_cache.cfg" ]] && return 0
  local a
  for a in "$@"; do [[ "$a" == "--import" ]] && return 0; done
  echo "Importing project (first run)..." >&2
  "$bin" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
}

if [[ -n "${GODOT:-}" ]]; then
  ensure_imported "$GODOT" "$@"
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

ensure_imported "$BIN" "$@"
exec "$BIN" "$@"
