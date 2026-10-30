# FARM-001: A field plot in the village (systems)

**Reference:** Immortal Life (a cozy cultivation life sim where you plant, wait out the seasons and harvest). Mechanics only.
**Why:** the first hours have gathering, fishing and crafting, but nothing you *grow*. The Spirit Garden (ART-004) only opens at
Foundation. A mortal-sized version in Qingshi gives the first year a small, steady loop that the weather and seasons already
feed (WEATHER-002/003, SEASON-001), and gives alchemists a way to stock spirit herbs.

## Data
`data/regions.json`: new place type `field_plot` (document it in `_doc` next to `fishing`; validate in `GameData._validate()`):
```json
{"type": "field_plot", "display_name": "Farmer Tian's Spare Field", "pos": [1080, 330], "size": [80, 50], "color": "7a5a36",
 "plots": 2, "rent": 6, "rent_days": 90,
 "plants": {"spirit_herb": {"days": 24, "yield": [2, 3]}, "dew_grass": {"days": 20, "yield": [2, 4]},
            "qi_condensing_grass": {"days": 45, "yield": [1, 2]}},
 "rain_bonus_days": 1, "frozen_seasons": ["winter"]}
```
Place it in qingshi_village near Farmer Tian (1000, 400): pick a spot outside every solid landmark, npc spot and label
(check the region shot). Validation: plots 1..4, rent >= 0, rent_days >= 1, every `plants` key is an item, days >= 1,
yield [min, max] with 1 <= min <= max, rain_bonus_days 0..3, frozen_seasons a subset of the four seasons. Only one
`field_plot` per region (validate).

## State
`CharacterData.field_plots: Dictionary` = `{place_key: {"paid_until": int (day), "crops": [{"item": String, "days_left": int}]}}`
where `place_key` is `"<region_id>:<display_name>"`. Add to `to_dict`/`from_dict` with default `{}` (old saves load; no
SAVE_VERSION bump needed if from_dict defaults it, otherwise bump and add a fixture per CLAUDE.md rule 5).

## System: `src/core/systems/field_plots.gd` (`class_name FieldPlots`, pure static, like `SpiritGarden`)
- `static func place_def(data: GameData, region_id: String) -> Dictionary` the region's field_plot place or {}.
- `static func key(region_id: String, place: Dictionary) -> String`.
- `static func rented(c, key, today) -> bool` (paid_until > today).
- `static func check_rent(c, place, today) -> String` ("" ok; "You cannot afford the rent (6 spirit stones)."; already rented).
- `static func rent(c, region_id, place, today) -> Dictionary` {ok, reason}: pays `rent` stones, sets paid_until = today + rent_days
  (renting again while rented extends from paid_until; allowed within 10 days of expiry only).
- `static func check_plant(c, place, key, item_id, today) -> String` / `plant(...) -> Dictionary`: needs rent, the item in the
  inventory, a free plot (`crops.size() < plots`), the item in `plants`. Removes one item.
- `static func advance(c, data, world_days: int, today: int, weather_of: Callable) -> Array[String]`: for each rented plot's
  crop, for each of the `world_days` days ending at today: no growth on a frozen season day, otherwise 1 day plus
  `rain_bonus_days` on a rain day (`weather_of.call(region_id, day) -> String`, GameState passes `Weather.of`). Clamp at 0;
  returns the "<region>:<item>" entries that just reached 0. When rent lapses, crops stop growing but stay (they wait for you).
- `static func harvest(c, data, key, place, rng) -> Dictionary` {ok, items: {item: count}}: every crop at days_left 0 is
  removed and yields `rng.randi_range(min, max)` (+1 if the player's Wood root is 50+ — the element of growth; keep this in a
  `wood_bonus` field, default 1, validated 0..2).
- `static func describe(c, data, key, place, today) -> PackedStringArray` e.g. "Spirit Herb: ready", "Dew Grass: 6 days
  (frozen in winter)", "Rent paid until Year 1, Month 4" (use the existing date helper GameClock/Weather use for text, or
  pass a formatter).

## GameState
`rent_field()`, `plant_field(item_id)`, `harvest_field()`: thin wrappers that post to the log (topic "trade" or the one
gathering uses), take 0 days for rent and harvest and 1 hour-free action for planting (0 days). Call `FieldPlots.advance`
from `_on_days_advanced` next to `SpiritGarden.advance`, and post "Your Spirit Herb in Farmer Tian's Spare Field is ready."
once per crop that becomes ready.

## World/UI (small, in the same task)
`src/world/interactables/field_plot.gd` (extends Interactable; register the type where `fishing` is registered):
`get_options()` returns Rent (with price and length), Plant <herb> for each carried plantable herb (disabled with the
`check_plant` reason), Harvest (when something is ready), and the describe() lines as the description. Art: reuse the
`field` PixelLandmark at the place rect plus one sprout glyph per growing crop (a green 2x3 pixel sprout; a full plant when
ready); vector fallback = a brown rect with rows. Gamepad focus works through the existing interact menu.

## Tests (`tests/unit/test_field_plots.gd` + one in `test_game_session.gd`)
- rent pays and sets paid_until; can't afford; renewal only near expiry.
- plant needs rent, the item, a free plot; removes the item.
- advance: clear days count 1, rain days 1 + rain_bonus_days, winter days 0; lapsed rent stops growth.
- harvest yields within range with `seeded_rng()`, Wood 50+ adds `wood_bonus`; nothing ready = ok false.
- validation rejects a bad plants item and two field_plots in one region.
- GameState: rent, plant, advance 30 days, harvest -> inventory has the herb; save/load round-trip keeps `field_plots`.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. Sims never rent a plot, so no balance run (say so in the commit). Commit message lists
Follow-ups (likely: more plantable herbs in content, a journal line, a plot in a second region).
