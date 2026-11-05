# TRAVEL-001: Each road its own

Role: systems (core + GameState). Content fills more in C-303. Reference: Tale of Immortal / Wandering Sword travel, where
the road between two places has moments that belong to it (mechanics only, never their names, story or art).

## Today (checked by the planner 2026-11-05)
Road encounters already exist (TRAV-006): `Exploration.road_encounter` (src/core/systems/exploration.gd:265) rolls with
`regions.json road` {chance_per_day 0.08, max_chance 0.4, encounter_tags ["road"]} from a single global pool of 16 `road`
encounters, called from `GameState.travel` (src/autoload/game_state.gd ~657), which stores
`last_travel_road_encounter`. The pool ignores which road you are on: the Qingshi -> Misty Forest walk and the climb to Azure
Peak meet the same peddlers, and the destination's weather and the origin play no part (the `weather` gate is "ignored on
the road").

## Build
1. Data (encounters.json, document in `_doc`, validate in GameData._validate):
   - `road_regions` (optional, list of region ids, needs the `road` tag): the encounter is only eligible on a journey whose
     origin OR destination is one of them.
   - On the road the `weather` gate now applies to the DESTINATION's weather on the arrival day (Weather.of); update the
     `_doc` sentence that says it is ignored. Encounters without `weather` are unaffected.
2. Core: `Exploration.road_encounter(c, data, days, flags, rng, season, day, from_region := "", to_region := "")`. Filter
   with the existing `folk_ok`-style callable (or a new optional filter argument on `eligible_encounters`): `road_regions`
   must contain from/to when present; weather checked against `to_region`. A road-specific encounter (has `road_regions`)
   gets its weight x2 so it shows up when you take that road. Old call sites (sims) that pass no regions only see encounters
   without `road_regions` (keeps sim output stable; say so in a comment).
3. GameState.travel passes the origin and destination. Nothing else changes in the UI (WU-447 shows the road line).
4. Content in this task, 6 entries, plain genre voice: 2 on roads touching qingshi_village/misty_forest (a woodcutter who
   warns of the forest's great beast, a mushroom picker's lost basket), 2 touching azure_peak (pilgrims climbing to the sect;
   a loose stone stair: a constitution check, on_fail costs a day), 2 touching withered_bone_marsh (a ferryman who wants a coin; a
   fog-only will-o'-wisp that leads you astray, `weather: ["fog"]`, +1 day). Rewards in the band of the existing first-realm
   road encounters; non-lethal; no `{villager}`.

## Tests (test_exploration.gd or a new test_road_routes.gd)
- An encounter with `road_regions: ["azure_peak"]` rolls only on journeys to/from azure_peak (force max_chance via the loaded
  data in the test, rng seeded).
- Destination weather gates a `weather` road encounter; same seed, same result.
- Calls without regions never return a `road_regions` encounter.
- Validation: `road_regions` without the `road` tag, or with an unknown region id, is an error.
- test_game_session: travel Qingshi -> Misty Forest with chance forced to 1.0 and only route encounters eligible posts one.

## Acceptance
tools/test.sh green. Road rewards change slightly: run `tools/balance.sh --check` and refresh the sections that move.
