# Cultivation Game

A 2D top-down xianxia cultivation RPG made with Godot 4.7. Start as a mortal and choose your path: righteous, demonic, or rogue.

## Run it
1. Run `tools/install_hooks.sh` once after cloning. From then on every `git pull` refreshes Godot's import and class cache
   automatically.
2. Play with `tools/play.sh` (it refreshes the cache, then launches the game; it downloads Godot 4.7 if needed), or open
   `project.godot` in the Godot editor and press F5.

> **If menus and NPCs don't respond:** the class cache is stale (new scripts were pulled but the project wasn't re-imported).
> Run `tools/godot.sh --headless --path . --import` (or open the project in the editor once), then start the game again.

## Develop
- `tools/test.sh` runs every check (must pass before committing).
- `CLAUDE.md` explains the architecture and rules for AI agents and humans alike.
- `docs/DESIGN.md` is the vision. `docs/BACKLOG.md` is the work queue.
