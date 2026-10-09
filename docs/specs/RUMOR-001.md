# RUMOR-001: Merchant gossip from data

Role: systems. Size: ~200 lines. Follow-up of C-059 (content could not add the dying-explorer rumor: `GameState.hear_rumors`
only reads lines built in code). C-067 (content) fills the file afterwards.

## Data: new file data/rumors.json
```json
{
  "_doc": "Merchant gossip heard with 'Hear rumors' (RUMOR-001, Rumors). rumors: [{id (unique), text (non-empty), region (optional region id: only heard there; absent = everywhere), min_realm (optional realm id: only heard once the player has reached it), requires_flag (optional world flag that must be set), blocked_by_flag (optional world flag that hides it)}]. max_per_visit (int >= 1): at most this many data rumors are told per 'Hear rumors'.",
  "max_per_visit": 2,
  "rumors": [
    {"id": "drowned_sword_explorer", "region": "fallen_star_market", "min_realm": "qi_refining", "blocked_by_flag": "<the flag C-057's sword tomb map sets, grep sword_tomb_map_fragment in data/encounters.json; omit if none>", "text": "A wounded treasure hunter came down from the cliffs last month, muttering about a drowned sword and a map torn in two."},
    {"id": "village_old_well", "region": "qingshi_village", "text": "The well-keeper swears the old well hums at night, as if something below were breathing."},
    {"id": "late_tribulation_talk", "min_realm": "foundation_establishment", "text": "Travellers say a Core Formation cultivator was struck down by his tribulation on the Azure Peak. Prepare well before you try."}
  ]
}
```
Use real region ids (check data/regions.json). Keep the texts; the content worker adds more in C-067.

## GameData (src/core/game_data.gd)
- `var rumors: Dictionary = {}` (id -> dict) and `var rumor_rules: Dictionary = {}` (`max_per_visit`), loaded like `bounties`
  (~line 228). A missing file loads as empty (old checkouts and tests that build GameData by hand keep working).
- `_validate_rumors()` called next to `_validate_bounties()`: duplicate/empty id, empty text, unknown region, unknown
  min_realm, `max_per_visit` < 1. Error strings start with "rumors.json".

## Rumors (new src/core/systems/rumors.gd, `class_name Rumors`, RefCounted, `##` doc comment)
- `static func eligible(c: CharacterData, data: GameData, flags: Dictionary, region_id: String) -> Array[String]` — ids, sorted,
  passing region (absent or == region_id), min_realm (`Cultivation` has a realm-index helper; grep how `min_realm` is compared
  in Exploration/Bounties and reuse it), requires_flag (truthy), blocked_by_flag (not truthy).
- `static func lines(c: CharacterData, data: GameData, flags: Dictionary, region_id: String, day: int) -> PackedStringArray` —
  up to `max_per_visit` texts from `eligible`, starting at index `posmod(day, n)` and wrapping (deterministic, no rng; the next
  day tells different ones when there are more than max_per_visit).

## GameState.hear_rumors (src/autoload/game_state.gd ~2136)
After the discovery rumor loop, `extra.append_array(Rumors.lines(player, data, world_flags, current_region, GameClock.total_days))`.
Do not change what `WorldEvents.rumors` does with `extra`; check it does not truncate extra lines (if it does, say so and append
the data rumors after its output instead).

## Tests
- tests/unit/test_rumors.gd: region filter, min_realm filter, requires/blocked flags, rotation by day (3 eligible, max 2:
  day 0 -> [0,1], day 1 -> [1,2], day 2 -> [2,0]), empty data -> empty, validation errors (unknown region, empty text).
- tests/unit/test_game_session.gd (or the test that covers hear_rumors; grep `hear_rumors` in tests): a data rumor for the
  current region is posted; one for another region is not.
- The new class_name needs an import: tools/test.sh imports first.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; "Hear rumors" at the Fallen Star Market tells the explorer line.
