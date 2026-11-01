# WILD-006: A great beast once a week (core)

Reference: Tale of Immortal's roaming elite monsters and Immortal Life's weekly routine (a reason to plan your week).
Mechanics only; no names, story or art. Role: systems. Size target: under ~350 changed lines.

## Idea
Each wild region with `roamers` may name one **great beast** that walks its map one day in every 7. It is a stronger
non-lethal beast with better spoils, it is announced the day before (CAL-003 reminder) and shows on the calendar, so a
player plans: eat a meal, bring a friend's technique, travel the day before. Content (C-291) adds the beasts; this task
builds the rule with one test entry.

## Data (data/regions.json, document in the `_doc` next to `roamers`)
```
"roamers": { "count": [2, 4], "enemies": [...],
  "great": { "enemy": "<enemies.json id>", "weekday": 0..6 (optional, default: hash(region_id) % 7),
             "min_realm": "<realm id>" (optional), "seasons": [...] (optional) } }
```
- Validate in `Wildlife.validate` (called from GameData._validate): enemy exists, is tagged `beast`, is **not**
  `lethal`; weekday int 0-6; min_realm a realm id; seasons valid.
- Add one entry for testing in **misty_forest** pointing at an existing stronger non-lethal beast there (e.g. the
  fog_antler_stag or whichever existing enemy fits; content will replace it). Do not invent new enemies in this task.

## Core (src/core/systems/wildlife.gd)
- `const GREAT_SLOT := 101`.
- `static func great_day(region_id: String, def: Dictionary) -> int` (0-6): `def.weekday` or `hash(region_id) % 7`
  (non-negative).
- `static func great_roamer(c: CharacterData, data: GameData, region_id: String, day: int, flags: Dictionary) -> Dictionary`:
  `{slot: 101, enemy, temper: "wary", great: true}` when `day % 7 == great_day`, in season, realm >= min_realm, and
  `flag_key(region_id, 101)` is not active; else `{}`. Pure, no rng.
- `static func next_great_day(data, region_id, from_day: int, realm_index: int) -> int` (-1 when the region has none):
  the first day >= from_day whose weekday matches and which is in season (look ahead at most 7*4*... cap 400 days).
- Spoils: the great beast's win gives the enemy's normal rewards **x2** (stones and item drops). Find where WILD-004/
  WU-423 resolve a map-beast fight (GameState, e.g. `fight_roamer`) and apply the multiplier when slot == 101. Record the
  hunt as usual and set a `life_stats` counter `great_beasts` (+1).
- GameState: wherever the world asks for today's roamers (`roamers_here()` or equivalent) append `great_roamer(...)`
  when not empty, the same way WILD-003 appends `bounty_roamer`. A great beast that is also the bounty quarry: show it once
  (the great entry wins).

## Calendar and reminders (src/core/systems/village_calendar.gd)
- `upcoming()` lists a `great_beast` entry for each **explored** region whose great day falls in the window
  ("A great Fog-Antler Stag walks Misty Forest"). Reuse the existing kind/icon plumbing; if a new kind needs an icon, add
  a fallback to an existing one and note `Follow-ups:` for world-ui.
- CAL-003's morning reminder: "Tomorrow: a great <beast> walks <region>." for the current region and its direct routes only.

## Tests (tests/unit/test_wildlife*.gd + test_game_session.gd)
- great_day is stable and in 0-6; great_roamer appears only on that weekday, not after `mark_down` for slot 101, not out
  of season / below min_realm; validation rejects a lethal or non-beast great enemy.
- next_great_day returns a matching day; -1 for a region without `great`.
- GameState integration: on Misty Forest's great day the roamers list includes slot 101; winning gives 2x stones of the
  same fight's normal reward (seeded rng, compare against the enemy's reward table) and bumps `great_beasts`.
- Calendar: the great-beast entry appears for an explored region and not for an unexplored one; the reminder fires the
  day before.

## Save compatibility
Uses existing timed flags and `life_stats` (defaults 0). No SAVE_VERSION bump.

## Balance
A weekly x2 reward changes what the village sim could earn but no sim fights map roamers yet; no `--check` needed.
Say so in the commit. Follow-ups for world-ui (WU-430 draws it bigger with a mark) and content (C-291 fills one per region).
