#!/usr/bin/env bash
# Installs local git hooks that re-import the Godot project after every pull, merge or
# branch switch. Without this, launching the game straight after `git pull` can fail:
# Godot's class cache (.godot/global_script_class_cache.cfg, not in git) won't know new
# `class_name` scripts, so scripts like hud.gd fail to parse and menus stop working.
# Usage: tools/install_hooks.sh   (run once per clone)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$(git -C "$ROOT" rev-parse --git-path hooks)"
mkdir -p "$HOOKS"
for hook in post-merge post-checkout post-rewrite; do
  cat > "$HOOKS/$hook" <<'HOOK'
#!/usr/bin/env bash
# Installed by tools/install_hooks.sh: refresh Godot's import + class cache in the background.
ROOT="$(git rev-parse --show-toplevel)"
( "$ROOT/tools/godot.sh" --headless --path "$ROOT" --import >"$ROOT/.godot-bin/last_import.log" 2>&1 & ) >/dev/null 2>&1
exit 0
HOOK
  chmod +x "$HOOKS/$hook"
done
echo "Installed post-merge/post-checkout/post-rewrite hooks in $HOOKS"
