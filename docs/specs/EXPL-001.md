# EXPL-001: Deeper paths (region familiarity)

**Why.** QA-041: months 7-36 offer nothing new. Reward a player who keeps exploring a region with encounters that only
open after you know the place: hidden valleys, a hermit who only shows himself to regulars, an old battlefield.

## Rules
- New `CharacterData.explore_days: Dictionary` (region id -> days spent exploring there, int), to_dict/from_dict default `{}`.
- `GameState._explore_once` (~575) adds 1 to `explore_days[current_region]` for every explore day, whatever it found
  (also when nothing was found). `Exploration.add_explore_day(c, region_id)` does the bookkeeping.
- New optional encounter key `"min_explores": int` (>= 1; document in data/encounters.json `_doc`, validate in GameData):
  the encounter is only eligible once the player has explored the **current region** at least that many days.
- `Exploration.eligible_encounters`, `roll_encounter` and `outlook` get a new trailing param `region_id: String = ""`;
  an entry with `min_explores` is skipped when `region_id == ""` or `familiarity(c, region_id) < min_explores`.
  Pass `current_region` from every GameState call site (`_explore_once`, `explore_outlook`, and wherever the world map's
  foe list calls outlook: grep `Exploration.outlook(` and `roll_encounter(` across src/ and tests/sim).
- `static func familiarity(c: CharacterData, region_id: String) -> int`.
- `static func next_deep_path(c: CharacterData, data: GameData, region_id: String) -> int`: the smallest `min_explores`
  above the current familiarity among encounters that share a tag with the region's `encounter_tags` and pass
  `realm_allows` + `alignment_allows` (ignore flags/seasons), or -1.
- `Guidance.journal` Opportunities: when `next_deep_path >= 0` for the current region, one line
  "<Region name>: explored N days. Something deeper waits after M." (tone "normal").
- Write one example in data/encounters.json: `misty_forest_hidden_valley` (tags ["forest"], kind "fortune",
  `min_explores: 20`, `blocked_by_flag: "found_hidden_valley"`, days 2): after weeks in the mist you notice the same
  crooked pine twice and follow the stream behind it into a hidden valley with a small spirit spring; effects: qi ~150
  (check a Qi Refining layer's qi_required in realms.json; about a third of a mid-layer), 2 qi_condensing_grass,
  `set_flag`. C-048 writes one per region later.

## Tests
- familiarity counts explore days per region (two regions kept apart); `explore_many(5)` with nothing happening adds 5.
- An encounter with min_explores 20 is not eligible at 19 days and is at 20; not eligible when `region_id` is "".
- `next_deep_path` is 20 for a fresh Misty Forest explorer, -1 once the count passes every deep path there.
- The journal line shows for misty_forest and is gone at 20+ days.
- Validator rejects `min_explores: 0` and a non-int.
- `explore_days` round-trips; an old dict without it loads as {}.

## Acceptance
`tools/test.sh` passes; under ~300 changed lines.
