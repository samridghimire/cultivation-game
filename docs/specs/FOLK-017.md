# FOLK-017: Villagers keep their own days

Role: systems. Reference: Stardew Valley's villager schedules and Tale of Immortal's NPCs who live their own lives
(mechanics only: no names, story or art). Today every named villager stands on one `pos` forever. After this task a
named villager stands somewhere that fits the day: at work on ordinary days, at the market stall on market days, under
an eave when it rains, at the festival square on a festival day.

Time is day-based (no hours), so a "schedule" is one spot per day, picked by rules, not a timetable.

## Data: `data/npcs.json`
Optional per-NPC `spots` (document it in the file's `_doc`, validate in `GameData._validate()`):
```json
"spots": {
  "work":     [x, y],          // optional; default = pos
  "market":   [x, y],          // optional; on the region's market days
  "rain":     [x, y],          // optional; when today's weather is rain or storm
  "festival": [x, y],          // optional; on a festival day in this region (default: near the region's festival_square)
  "rest_weekday": "Earthday"   // optional weekday name (CAL-005 names); on that day the villager stays at pos (home)
}
```
Validation: every point inside the region map bounds; `rest_weekday` one of the 7 weekday names; `spots` only on NPCs
with a `region`. Unknown keys are an error.

Give spots to the named Qingshi villagers (Elder Mo, Xiao Ling, Hunter Ma, Farmer Tian, Headman Zhou and any other
named Qingshi NPC): work spots by their trade (Farmer Tian at his field, Hunter Ma by the bounty board, Elder Mo at the
Meditation Rock), a market spot near the Wandering Merchant / market stall for 2-3 of them, rain spots under a house
eave, one rest weekday each for 2-3. Keep every spot 40 px off places' interaction points and gates (reuse the
GFX-082/GFX-085 clearance helpers if they are reachable from core; otherwise check distance to places in the test).

## Core: `src/core/systems/folk.gd`
```gdscript
## Where a named NPC stands today: {pos: Vector2, why: String} (why in "home", "work", "market", "rain", "festival", "rest").
static func spot_for(data: GameData, npc_def: Dictionary, day: int, weather: String, flags: Dictionary) -> Dictionary
```
Priority: festival (a festival of the NPC's region is running today: VillageCalendar / festival defs already know this)
> rain (weather kind `rain` or `storm`) > rest_weekday > market (a day on which any place of the region with `open_days`
is open, `Places.is_open`, the same check the calendar uses) > work > pos. A missing optional spot falls through to the next rule. Festival with no `festival` spot: the
region's `festival_square` plus a small seeded offset (seed = hash(npc id) + day, `seeded` RNG, never global randf), or
fall through when the region has no square. Pure function, no Nodes.

## World hook (small)
`src/world/interactables/npc.gd` (and wherever the region spawns named NPCs): at spawn and on `GameClock` day change
(bound method, not a lambda: QA-201's audit), set `home` from `GameState.npc_spot(npc_id)` (a thin GameState wrapper
over `Folk.spot_for` with today's weather and flags). If the NPC is on screen when the day changes, it walks to the new
home at its walk speed instead of jumping (a simple move_toward on `home`; reduce_motion: jump). Wander stays around the
new home. Generated villagers are unchanged.

## Tests (`tests/unit/test_folk.gd` or a new `test_folk_spots.gd`)
- Validation: a spot outside the map and an unknown weekday each produce an error; the shipped data validates.
- `spot_for`: a market day returns market; rain beats market; festival beats rain; rest weekday returns pos;
  a villager with no spots always returns pos with why "home".
- Same inputs give the same festival offset (determinism).
- Every named Qingshi spot is >= 40 px from every place in Qingshi.
- GameState integration: on a Qingshi market day the named villager with a market spot is placed there after
  `start_session` (check the NPC node's `home` in a world test, or `GameState.npc_spot` if the world is not built).

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Render `screenshot_first_hour.gd` default and `-- --festival` (and a rainy
day with `-- --rain`) at 1280x800 and describe in the commit where the villagers stand. No balance run (no numbers change).
Follow-ups go in the commit message (e.g. spots for other regions' named NPCs: a content task).
