# GUIDE-202: The village life you'd miss (hints + a weather forecast)

Role: systems. Reference: Immortal Life's day planner (you know what the village offers today and tomorrow).

## Why
The village systems built this week (field plot FARM-001, fishing FISH-001, home meals FISH-002, friends' visits WORLD-007,
quarrels FOLK-004) are only found by walking into them. The Next-steps list never mentions them, and weather is only known on
the day. Weather is deterministic (`Weather.of(data, region_id, day)`), so tomorrow is knowable.

## What
1. `Weather.forecast(data: GameData, region_id: String, today: int, days: int = 2) -> Array[String]`: the kinds for
   today+1..today+days (pure; no rng). Tests: matches `Weather.of` for those days; a region without weather -> all "clear".
2. In `Guidance` (src/core/systems/guidance.gd), low-priority newcomer lines (after the goal/fight/technique lines; each at
   most one line, each only in a region that has the thing):
   - **field**: the region has a `field_plot` place, the player carries a plantable item (`FieldPlots.plantable(place)`) and
     has a free (or unrented) plot: "Plant your Spirit Herb in Farmer Tian's Spare Field (6 stones a season): ready in about 24
     days." When a crop is ready: "Your Dew Grass is ready to harvest at Farmer Tian's Spare Field." (ready beats plant).
   - **meal**: the player is injured (Injuries) and holds the ingredients of a `home_meals` entry: "Cook Fish Stew at a
     workshop: it eases your injury by N days." (read the meal's `shorten_injury`).
   - **forecast**: when tomorrow's weather has an effect the player would care about (Weather `effects_text` non-empty for
     that kind): "Tomorrow looks like rain: herbs grow thick and fish bite." Use `Weather.effects_text`/`effect_note` wording,
     do not duplicate strings.
   - **visitor**: if `GameState.visitor_today` finds a friend today, the hint names them and where ("Xiao Ling has come to see
     you by the Meditation Rock."). If the visitor helper lives only in GameState, add a pure `Folk.visitor` call path through
     Guidance's inputs (it already gets npcs/flags/today in `village_lines`).
   Reuse WU-407's `Guidance.village_lines` data where it already computes these; don't compute twice.
3. The HUD status card's weather text gains the forecast: "Spring · Clear (tomorrow: Rain)" (find where the status line builds
   the weather label; a one-line change in hud.gd is fine for a systems worker).

## Tests (tests/unit/test_guidance*.gd, test_weather.gd)
- forecast as above.
- field line: carries spirit_herb in Qingshi with no plot -> plant line with the rent; a ready crop -> harvest line; elsewhere
  (no field_plot) -> nothing.
- meal line only when injured and holding the ingredients.
- forecast line only when tomorrow's kind has effects.
- Ordering: these lines never push the realm goal or the fight line out of the top 3 (assert the first line is unchanged).
Hint wording only: no `tools/balance.sh --check`. Under ~350 lines.
