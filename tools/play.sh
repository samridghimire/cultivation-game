#!/usr/bin/env bash
# Refreshes Godot's import + class cache, then launches the game.
# Use this instead of launching directly after pulling new code.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/tools/godot.sh" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
exec "$ROOT/tools/godot.sh" --path "$ROOT" "$@"
