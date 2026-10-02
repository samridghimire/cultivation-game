# Cultivation Game: Agent Guide

A 2D top-down xianxia cultivation RPG built in **Godot 4.7 (GDScript)**, eventually shipping on Steam (Windows + Linux/Steam Deck).
The player starts as a mortal, cultivates through realms (Qi Refining → Foundation Establishment → …), may join a sect or stay rogue,
practices professions (Alchemist, Blacksmith, Talisman Master, Array Master, Doctor, …), and chooses a moral path (righteous ↔ demonic).

Read `docs/DESIGN.md` for the game vision and `docs/BACKLOG.md` for the work queue.

## Commands

```bash
tools/test.sh                 # REQUIRED before every commit: import + unit tests + scene smoke tests
tools/godot.sh --path .       # run the game (downloads pinned Godot into .godot-bin/ if $GODOT is unset)
tools/godot.sh --headless --path . -s res://tests/run_tests.gd   # unit tests only
```

`tools/test.sh` must print `ALL CHECKS PASSED`. Never commit with failing checks.

## Architecture

```
data/*.json            Content definitions (realms, sects, professions, items, deeds...). Add content here, not in code.
src/core/              Pure game logic. RefCounted classes and static functions. NO Nodes, NO signals, NO autoload access.
  game_data.gd         Loads + validates data/*.json into typed defs (src/core/defs/).
  character_data.gd    Plain character state + to_dict/from_dict.
  systems/*.gd         Rules: Cultivation, SpiritualRoots, Alignment, Professions, Sects, Items, Deeds, Effects,
                       Combat, Techniques, Exploration...
src/autoload/          Global singletons (Nodes):
  EventBus             Signals between systems and UI. EventBus.post(text, category) writes to the message log.
  GameState            Session owner (data, player, world_flags, rng). Player actions = thin wrappers over systems.
  GameClock            Day-based world time. Time only passes when actions take time.
  SaveManager          JSON saves in user://saves/. Bump SAVE_VERSION + add a migration on format changes.
  InputConfig          All input actions, keyboard AND gamepad (Steam Deck). Add new actions here.
src/world/             The world. Regions are built from data/regions.json (world.tscn is just Player + HUD).
                       Interactables are Area2D subclasses that return menu entries from get_options().
src/ui/                UI, mostly built in code. Shared look in UIStyle. HUD modals register via
                       hud._add_screen(action, screen); a screen needs open()/close() and a `closed` signal.
tests/unit/test_*.gd   Tests extend TestCase. Methods named test_* run automatically.
```

### Rules
1. **Logic goes in `src/core/systems`, never in scenes or UI.** UI/world code calls `GameState.<action>()`; GameState calls a system, posts messages, advances time, emits signals.
2. **Content is data-driven.** New realm/sect/item/profession/deed = JSON edit. If a new mechanic needs new JSON fields, document them in that file's `_doc` and validate them in `GameData._validate()`.
3. **Every system change gets unit tests.** Every new player action gets a GameState integration test (see `tests/unit/test_game_session.gd`).
4. **Determinism:** all randomness goes through a `RandomNumberGenerator` passed in (GameState.rng in-game, `seeded_rng()` in tests). Never use global `randf()`/`shuffle()` in core.
5. **Save compatibility:** new persistent state must be added to `to_dict`/`from_dict` (or `GameState.to_save_dict`) with defaults so older saves still load.
6. **Static typing everywhere** (`var x: int`, `-> void`). Tabs for indentation. `snake_case` files/functions, `PascalCase` classes. A `##` doc comment at the top of every script.
7. Placeholder art is drawn in `_draw()`. Don't add binary assets without a clear license; note the source in `docs/ASSETS.md`.
8. Keep the game controllable with a gamepad: every new menu must have keyboard/gamepad focus (`grab_focus`).

## Autonomous agent workflow

Agents (scheduled cloud routines, and local sessions) share this repo. Follow this exactly:

1. `git checkout main && git pull`.
2. Read `docs/BACKLOG.md`. Pick the **highest-priority task with status `todo`** that matches your role and isn't claimed by an open PR
   (`gh pr list` or check remote branches named `claude/<task-id>-*`).
3. Branch `claude/<task-id>-<short-slug>` from main.
4. Implement it, small and complete. If a task is too big, split it in BACKLOG.md and do the first part.
5. Run `tools/test.sh` until it passes. (A brand-new `class_name` is only visible after an import; test.sh imports first.)
6. Update `docs/BACKLOG.md`: set the task to `done` (or add follow-up tasks you discovered, with ids). Add a line to `docs/CHANGELOG.md`.
7. Commit, push, open a PR titled `[<task-id>] <title>` describing what changed and how it was tested.
8. Never force-push main, never rewrite history, never delete other agents' branches.

If something is ambiguous and it's a game-design decision (not a technical one), don't guess big. Implement the smallest
reasonable version, and add a question under "Open design questions" in `docs/DESIGN.md` for the human.
