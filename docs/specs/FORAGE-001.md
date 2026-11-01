# FORAGE-001: Things to pick up on the way (core)

Role: systems. Feeds WU-427 (drawing them) and C-288 (data for every region).
Reference: **Immortal Life** and the farming-sim genre (daily forageables you see and pick as you walk), the same
"visible, daily, deterministic" pattern as WILD-001's roamers. Mechanics only.

## Why
Gathering today is a menu at a gather place that costs 3 days. Walking around a region gives nothing. A few visible herbs,
mushrooms or stones to pick as you pass make every walk worth something and give the map texture. Smallest version: a few
small pickups per region per day, worth little, no time cost.

## Data (regions.json, per region, optional)
`forage`: `{"count": [min, max], "items": [{"item": <items.json id>, "weight": > 0, "min": int >= 1 (default 1),
"max": int >= min (default 1), "seasons": [optional list], "min_realm": <optional realm id>}]}`, count 0..8, min <= max.
Document in the regions.json `_doc`, validate in a `Foraging.validate(data)` called from `GameData._validate()` (like
`Wildlife.validate`): known item ids, weights > 0, count range, seasons valid. Put **one small test entry** in
qingshi_village (count [2, 3], dew_grass / spirit_herb) so the feature is live; C-288 fills the rest.

## Core: `src/core/systems/foraging.gd` (`class_name Foraging`, static, RefCounted rules only)
- `static func nodes(data: GameData, region_id: String, day: int, realm_index: int, flags: Dictionary) -> Array[Dictionary]`
  -> `[{slot: int, item: String, amount: int}]`, deterministic per region and day with a local rng seeded
  `hash("forage:%s:%d" % [region_id, day])` (never GameState.rng), season and min_realm filtered like `Wildlife.roamers`;
  slots whose picked flag is active today are left out.
- `static func flag_key(region_id: String, slot: int) -> String` (`forage_<region>_<slot>`), set with the same timed-flag
  helper roamers use (`Effects` flag that expires at the end of the day), so it saves with world_flags for free.
- `static func validate(data: GameData) -> PackedStringArray`.

## GameState
- `forage_here() -> Array[Dictionary]` (current region, today).
- `pick_forage(slot: int) -> bool`: false if the slot is not in `forage_here()`. Adds the item, sets the flag, posts
  "You pick 2 Dew Grass by the path." (category `world`), adds 1 herb-lore xp when the item is tagged `herb` and HerbLore
  exists, increments life stat `foraged` ("Things picked up on the way"), emits `EventBus.forage_changed` (new signal).
  **Takes no time** (a stoop, not an action); `_can_act()` still applies. Rain's `herb_bonus_chance` does not apply.
- No save change: flags already persist; no new CharacterData field.

## Tests (tests/unit/test_foraging.gd + one in test_game_session.gd)
- Same region/day gives the same nodes; a different day differs (across a few days); seasons/min_realm respected.
- Picking adds the item once; a second pick of the same slot returns false; the slot is gone from `forage_here()`
  until the next day, then nodes come back.
- Validation rejects an unknown item, weight 0, count [3, 1].
- Time does not advance on pick.

## Acceptance
`tools/test.sh` green. Balance: only the Qingshi test entry is new data and no sim picks forage, so no `balance.sh --check`.
Follow-ups: list any economy concern for C-288 (the value per day the Qingshi entry adds).
