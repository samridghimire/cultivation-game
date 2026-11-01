# WILD-001: Beasts you can see (core)

Role: systems. Feeds WU-423 (drawing them) and C-287 (data for every wild region).
Reference: **Wandering Sword** (foes visible on the map, which you can walk up to or steer around) and **Tale of Immortal**
(wandering beasts as part of a living region). Mechanics only.

## Why
Outside Qingshi a region is a still picture: every fight comes from an Explore menu roll. Visible wildlife makes the wild
regions feel alive and lets the player choose fights. This is the smallest version: a few roamers per day per region,
fought through the existing combat path. Qingshi Village has none (the first hour is unchanged).

## Data (regions.json, per region, optional)
`roamers`: `{"count": [min, max], "enemies": [{"enemy": <enemies.json id>, "weight": > 0, "seasons": [optional list],
"min_realm": <optional realm id: below it the entry is skipped>}]}`. count 0..6, min <= max. Document in the regions.json
`_doc` and validate in `GameData._validate()` (or a `Wildlife.validate(data)` called from it, like `Scenery.validate`):
known enemy ids, weights > 0, known seasons, known realm ids, no lethal enemy with `tags` lacking "beast" (roamers are
beasts; bandits stay in encounters). Put **one** entry on misty_forest now so the feature is testable in game:
`{"count": [2, 3], "enemies": [{"enemy": "wild_boar", "weight": 3}, <one more non-lethal forest beast that already exists
in enemies.json>]}`. C-287 fills the other regions.

## Core: new `src/core/systems/wildlife.gd` (`class_name Wildlife`, RefCounted, static, `##` doc)
- `static func roamers(data: GameData, region_id: String, day: int, realm_index: int, flags: Dictionary) -> Array[Dictionary]`
  Today's roamers: `[{slot: int, enemy: String}]`. Deterministic per (region, day): build a local
  `RandomNumberGenerator` with `seed = hash("%s:%d" % [region_id, day])` (this is a pure derivation, not game randomness;
  say so in a comment, CLAUDE.md rule 4 is about not using global randf). Count from `count`, each enemy by weight among
  entries allowed by season (`Calendar.season_of(day)`) and `min_realm`. Skip slots whose world flag
  `roamer_down_<region>_<slot>` is active (FLAG-001 timed flags: use the existing timed-flag reader with `day`).
- `static func mark_down(flags: Dictionary, region_id: String, slot: int, day: int) -> void` sets that flag as a timed flag
  that ends at the start of the next day (use FLAG-001's setter; check `flag_days` semantics so it expires at day + 1).
- `static func threat(c: CharacterData, data: GameData, enemy_id: String) -> String`: reuse whatever labels the HUD
  "Fair fight: Wild Boar (Weak 99)" line uses (grep Guidance/Combat for the Weak/Fair/Dangerous/Deadly wording) so the
  world can show it; do not invent a new scale.

## GameState
- `func roamers_here() -> Array[Dictionary]` = `Wildlife.roamers(data, current_region, GameClock.total_days, realm index, world_flags)`.
- `func engage_roamer(slot: int) -> bool`: refuses (EventBus.post, returns false, no time) when the slot is not among
  today's roamers. Otherwise runs the same path `fight(enemy_id)` uses (Deadly lethal foes go through the existing
  threat-sense/flee rules exactly as an explored lethal foe would; do not bypass them), then `mark_down` on a win **or** a
  loss (the beast leaves either way), and emits a signal the world can listen to (add `EventBus.roamers_changed` or reuse a
  region-refresh signal if one exists). Time cost: whatever `fight()` costs today; do not add a new one.
- Save: nothing new (flags already persist).

## Tests
- tests/unit/test_wildlife.gd: same inputs give the same list; a different day can differ; count within [min, max];
  season filter and min_realm filter; a downed slot is absent the same day and back the next day; validation rejects an
  unknown enemy and a lethal non-beast.
- tests/unit/test_game_session.gd (or a new GameState test): `engage_roamer` on a valid slot fights (stats/log changes),
  marks the slot down; a second call on the same slot is refused and passes no time; a bad slot is refused.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. Misty Forest roamers are an optional extra fight source the sims never use, so no
balance run is needed; say so in the commit. Follow-ups: anything WU-423 needs that you left out.
