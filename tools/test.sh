#!/usr/bin/env bash
# Full verification: import, unit tests, then boot each main scene headless and
# fail on any script/engine error. Run this before every commit.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_GODOT="$ROOT/tools/godot.sh"
cd "$ROOT"
status=0

echo "== Importing project"
"$RUN_GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== Unit tests"
"$RUN_GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee .godot/test_output.log
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then status=1; fi

echo "== Scene smoke tests"
for scene in res://src/ui/main_menu.tscn res://src/ui/character_creation.tscn res://src/world/world.tscn; do
  out="$("$RUN_GODOT" --headless --path . "$scene" --quit-after 30 2>&1)"
  if grep -E "SCRIPT ERROR|^ERROR|Parse Error" <<<"$out" >/dev/null; then
    echo "FAIL  $scene"
    echo "$out" | grep -E -A3 "SCRIPT ERROR|^ERROR|Parse Error"
    status=1
  else
    echo "ok    $scene"
  fi
done

if [[ $status -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit $status
