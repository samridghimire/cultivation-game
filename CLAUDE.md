# Cultivation Game: Agent Guide

A 2D top-down xianxia cultivation RPG built in **Godot 4.7 (GDScript)**, eventually shipping on Steam (Windows + Linux/Steam Deck).
The player starts as a mortal, cultivates through realms (Qi Refining → Foundation Establishment → …), may join a sect or stay rogue,
practices professions (Alchemist, Blacksmith, Talisman Master, Array Master, Doctor, …), and chooses a moral path (righteous ↔ demonic).

Read `docs/DESIGN.md` for the game vision, `docs/BACKLOG.md` for the work queue and `docs/HANDOFF.md` for notes from the last session.

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
tests/unit/test_*.gd   Tests extend TestCase. Methods named test_* run automatically (they may `await` frames, see test_focus_audit.gd).
```

### Rules
1. **Logic goes in `src/core/systems`, never in scenes or UI.** UI/world code calls `GameState.<action>()`; GameState calls a system, posts messages, advances time, emits signals.
2. **Content is data-driven.** New realm/sect/item/profession/deed = JSON edit. If a new mechanic needs new JSON fields, document them in that file's `_doc` and validate them in `GameData._validate()`.
3. **Every system change gets unit tests.** Every new player action gets a GameState integration test (see `tests/unit/test_game_session.gd`).
4. **Determinism:** all randomness goes through a `RandomNumberGenerator` passed in (GameState.rng in-game, `seeded_rng()` in tests). Never use global `randf()`/`shuffle()` in core.
5. **Save compatibility:** new persistent state must be added to `to_dict`/`from_dict` (or `GameState.to_save_dict`) with defaults so older saves still load.
   When you bump `SaveManager.SAVE_VERSION`, add a fixture save of the new version to `tests/fixtures/saves/` (keep the old ones);
   `tests/unit/test_save_fixtures.gd` loads every fixture.
6. **Static typing everywhere** (`var x: int`, `-> void`). Tabs for indentation. `snake_case` files/functions, `PascalCase` classes. A `##` doc comment at the top of every script.
7. Placeholder art is drawn in `_draw()`. Don't add binary assets without a clear license; note the source in `docs/ASSETS.md`.
8. Keep the game controllable with a gamepad: every new menu must have keyboard/gamepad focus (`grab_focus`).

## Autonomous agent workflow

The team is described in `docs/AGENTS.md`: an **Opus planner** writes task specs, **Sonnet workers** build, test and land work
directly on `main`, and an **Opus reviewer** reviews what landed. There are **no pull requests and no merge queue**.

### Worker loop (Sonnet)
1. `git checkout main && git pull`.
2. Pick the top `todo` task for your role in `docs/BACKLOG.md` (tables are in priority order) that is **not done and not claimed**:
   - not done: `git log origin/main --oneline | grep -F "[<task-id>]"` finds nothing (the planner may lag behind main);
   - not claimed: no remote branch `claude/<task-id>-*` exists (`git fetch --prune && git branch -r`).
   Prefer tasks marked `spec` (the planner wrote a detailed spec for them, sometimes in `docs/specs/<task-id>.md`).
3. **Claim it** with a timestamped claim commit: `git checkout -b claude/<task-id>-<slug>`,
   `git commit --allow-empty -m "claim <task-id>"`, `git push -u origin HEAD`. Do this before writing code.
4. Implement it, small and complete, with tests. **Do not edit `docs/BACKLOG.md` or `docs/CHANGELOG.md`**. The planner keeps
   them, which avoids the merge conflicts that used to block everything. Put follow-up ideas in your commit message under
   `Follow-ups:`.
5. Run `tools/test.sh` until it prints `ALL CHECKS PASSED`. (A brand-new `class_name` is only visible after an import; test.sh imports first.)
6. Commit with the subject `[<task-id>] <title>` (the planner marks tasks done by finding that id on main).
7. **Land it on main yourself:** `git fetch origin main && git rebase --no-keep-empty origin/main` (this also drops the empty
   claim commit), run `tools/test.sh` again, then `git push origin HEAD:main`.
   - **The cloud git proxy often prints `HTTP 403` / "remote end hung up" even when the push succeeded.** Always verify with
     `git fetch origin main && git log origin/main --oneline -3` before retrying.
   - If main moved and the push was really rejected, repeat this step (up to 5 times).
   - If a rebase conflict is in code you didn't touch, resolve it keeping both sides' intent, then re-test.
8. Don't delete your claim branch. The cloud can't delete branches (403); `.github/workflows/cleanup-claims.yml` removes claims
   hourly once their task is on main or the claim is 4h old. Move on to your next task.
9. If you can't get the task green in this run, don't land it. Say why in your final summary; the claim expires after 4h.

Never force-push main, never rewrite main's history, never delete another agent's branch, and never create scheduled tasks,
reminders or "check-ins".

If something is ambiguous and it's a game-design decision (not a technical one), don't guess big. Implement the smallest
reasonable version, and add a question under "Open design questions" in `docs/DESIGN.md` for the human.
