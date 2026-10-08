#!/usr/bin/env bash
# Exports release builds for Windows and Linux into build/<platform>/.
# Downloads the export templates for the pinned Godot version if missing.
# Not part of tools/test.sh (the templates are large). Usage: tools/export.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_VERSION="$(grep -m1 '^GODOT_VERSION=' "$ROOT/tools/godot.sh" | cut -d'"' -f2)"
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable"

if [[ ! -f "$TEMPLATE_DIR/version.txt" ]]; then
  mkdir -p "$ROOT/.godot-bin" "$TEMPLATE_DIR"
  zip="$ROOT/.godot-bin/templates.tpz"
  echo "Downloading export templates ${GODOT_VERSION}..." >&2
  curl -fsSL -o "$zip" "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  tmp="$(mktemp -d)"
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$zip" "$tmp"
  cp -r "$tmp"/templates/* "$TEMPLATE_DIR"/
  rm -rf "$tmp" "$zip"
fi

mkdir -p "$ROOT/build/windows" "$ROOT/build/linux"
"$ROOT/tools/godot.sh" --headless --path "$ROOT" --import
"$ROOT/tools/godot.sh" --headless --path "$ROOT" --export-release "Windows Desktop" "$ROOT/build/windows/CultivationGame.exe"
"$ROOT/tools/godot.sh" --headless --path "$ROOT" --export-release "Linux" "$ROOT/build/linux/CultivationGame.x86_64"
