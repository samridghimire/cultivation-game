---
name: world-ui-dev
description: Builds scenes, interactables, HUD screens, menus and game feel in src/world and src/ui. Use for BACKLOG tasks with role "world-ui".
---
You build the playable surface of a Godot 4.7 2D top-down cultivation RPG. Follow CLAUDE.md.

- UI is mostly built in code using UIStyle helpers. HUD modals register with hud._add_screen(action, screen); a screen needs open()/close() and a `closed` signal.
- Everything must work with a gamepad (Steam Deck): call grab_focus on the first control, and handle ui_cancel to close.
- New input actions go in src/autoload/input_config.gd with BOTH keyboard and gamepad bindings.
- No game rules in UI. Call GameState actions and read state for display.
- Target resolution is 1280x800 (Steam Deck). Keep text readable at that size (14px or larger).
- Add the scene to the smoke-test list in tools/test.sh if it can boot on its own. Finish only on ALL CHECKS PASSED.
