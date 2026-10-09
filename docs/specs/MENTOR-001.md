# MENTOR-001: Ask a senior for pointers (systems)

Genre staple: a stronger cultivator who likes you glances at your forms and points out a flaw, saving you weeks of practice.
Smallest version, everything tunable in `data/family.json`.

## Data (`data/family.json`)
Add a top-level `"mentorship"` object and document it in the file's `_doc`:
```json
"mentorship": {
  "pointers": {"min_favor": 20, "cooldown_days": 30, "days": 1, "practice_days": 15, "shared_multiplier": 2.0},
  "spar": {"min_favor": 10, "cooldown_days": 7, "days": 1, "practice_days": 3, "win_favor": 2, "max_realm_gap": 1}
}
```
(`spar` is for SPAR-001; add both now so the validator is written once.) Validate in `Family.validate` (family.gd ~312): every
number present and >= 0, `shared_multiplier` >= 1, `min_favor` <= 100. A missing `mentorship` block is allowed (feature off).

## State (`src/core/character_data.gd`)
`var npc_action_days: Dictionary = {}  # "pointers:<npc_id>" / "spar:<npc_id>" -> GameClock day last done`
Add to `to_dict`/`from_dict` with default `{}` (no SAVE_VERSION bump: old saves load with an empty dict).

## Core: new `src/core/systems/mentorship.gd` (`class_name Mentorship`, RefCounted, static funcs, `##` header)
- `static func is_senior(c: CharacterData, npc: CharacterData) -> bool`: `npc.realm_index > c.realm_index`, or equal realm
  and `npc.stage > c.stage`.
- `static func pointer_technique(c: CharacterData, npc: CharacterData, data: GameData) -> String`: among techniques `c` knows
  that are not mastered (`Techniques.is_mastered`), prefer the one the NPC also knows (if several, the one the NPC has at the
  highest level, ties by id); else the lowest-level known unmastered technique (ties by id); "" when none.
- `static func cooldown_left(c: CharacterData, key: String, cooldown: int, today: int) -> int`: days until `key` may be used
  again (0 = ready, also when never used).
- `static func check_pointers(c, npc, favor: int, data, today: int) -> String` (typed params): reasons, in this order,
  first match wins:
  - npc null / dead → "They are not here."
  - `npc.age_years() < data.family.get("adult_age", 16)` → "<Name> is too young to teach anyone."
  - not `is_senior` → "<Name> is no stronger than you; there is nothing to learn from them yet."
  - favor < min_favor → "<Name> does not know you well enough (favor N/20)."
  - cooldown → "<Name> already pointed out your flaws recently (N days)."
  - `pointer_technique == ""` → "You have no technique they could correct."
- `static func give_pointers(c, npc, favor, data, today: int) -> Dictionary`: `{ok, reason, tech_id, tech_name, shared: bool,
  days, levels_gained: int}`. Calls `Techniques.practice(c, data, tech_id, int(practice_days * (shared_multiplier if shared
  else 1.0)))` and records `c.npc_action_days["pointers:" + npc.id] = today`. Read `Techniques.practice`'s return keys
  (techniques.gd ~62) for the levels gained.

## GameState (`src/autoload/game_state.gd`, next to `chat` ~1017)
`func ask_pointers(npc_id: String) -> void`: `EventBus.topic = "family"`, `_can_act()`, check, post the reason as "warning" on
failure (and emit `player_changed`, like `chat`). On success post, category "progress":
"<Name> watches your <Tech> and points out a flaw." + (" You both know this art; the advice cuts deep." if shared) +
(" <Tech> reaches level N." when a level was gained), then `_pass_time(result["days"])`.
Also `func check_pointers(npc_id: String) -> String` for the UI (WU-059).

## Tests
- `tests/unit/test_mentorship.gd`: is_senior (higher realm, same realm higher stage, equal = false); pointer_technique prefers
  a shared technique, falls back to the lowest-level one, skips mastered, "" with no techniques; every check reason above;
  give_pointers adds xp equal to practice_days (x2 shared) days' worth, records the day, then the cooldown reason appears and
  clears after cooldown_days; validator rejects a negative number.
- `tests/unit/test_game_session.gd`: integration test: a Qi Refining 2 player with Iron Fist, a Foundation NPC with favor 25:
  `ask_pointers` raises Iron Fist xp, advances the clock by 1 day, posts the message; a second call warns.
- Save round-trip keeps `npc_action_days`.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. No UI in this task (WU-059 adds the NPC menu entry).
