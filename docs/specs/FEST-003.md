# FEST-003: A festival activity anyone can join

Role: systems. Size: ~250 lines. Festivals (WE-002, FEST-002) today change prices, warm chats and stock stalls, but there is
nothing to *do*. This adds one activity per festival instance, open to mortals too. WU-100 adds the menu entry; C-065 writes
activities for the other two festivals.

## Data (data/world_events.json)
- Optional `activity` on any event (meant for festivals):
  `{"name": str, "text": str, "days": int >= 0, "effects": {Effects keys}, "bonus": {"attribute": attributes.json id, "min": int, "text": str, "effects": {Effects keys}}}` (`bonus` optional).
- Append to the file's `_doc`: what `activity` does, that it can be done once per festival instance, and that `bonus` applies when the attribute is at least `min`.
- Add one to `lantern_festival`:
  `{"name": "Float a lantern", "text": "You write a name on a paper lantern and set it on the river with the villagers. It drifts away among a hundred others.", "days": 0, "effects": {"qi": 15, "alignment": 2}, "bonus": {"attribute": "comprehension", "min": 12, "text": "Watching the lights follow the current, something about how qi finds its way settles in you.", "effects": {"breakthrough_bonus": 0.01}}}`
  (check `breakthrough_bonus` is the Effects key; effects.gd ~97.)

## WorldEvents (src/core/systems/world_events.gd)
- `static func activity_of(data: GameData, event_id: String) -> Dictionary` ({} when none).
- `static func check_activity(data: GameData, active: Array, c: CharacterData, event_id: String, region_id: String) -> String`:
  "" or "Nothing like that is going on." (no activity) / "The <name> is not happening here." (`instance_in` empty) /
  "You have already taken part this festival." (`instance["activity_done"]`). No realm requirement.
  Keep it separate from `check_join`'s `done` flag (a tournament and the activity do not block each other).
- `static func do_activity(data: GameData, active: Array, c: CharacterData, event_id: String, region_id: String, flags: Dictionary) -> Dictionary`:
  `{ok, reason, text, notes, days, bonus}`; sets `instance["activity_done"] = true` (instances live in `GameState.world_events`, which is
  saved — confirm the instance dict is saved as-is so the key survives save/load; if instances are rebuilt from a narrower dict, add the key there),
  applies `effects`, and when `int(c.attributes.get(bonus.attribute, 0)) >= bonus.min` appends `bonus.text` to `text` and applies `bonus.effects`.
- `validate`: `activity` needs non-empty name/text, `days >= 0`, a Dictionary `effects`; `bonus.attribute` must be an attributes.json id and `min` an int.

## GameState
- `func festival_activity_here() -> String` — the event id of an active event in `current_region` with an activity, or "" (first found, data order).
- `func check_festival_activity(event_id: String) -> String` and `func festival_activity(event_id: String) -> void`:
  `_can_act()`, do it, post `text` + " (notes)" with topic "world", `_pass_time(days)` when > 0, `LifeStats.add(player, "festival_activities")`, `player_changed`.
- Journal (Guidance, where WE-002 posts the festival line): when an activity is open here and not done, add "Festival: <activity name> at <region> (once this festival)."

## Tests
- tests/unit/test_world_events.gd: check_activity reasons (no activity, wrong region, done); do_activity applies effects once, bonus only at the
  attribute threshold (set `c.attributes["comprehension"]` 11 vs 12), `activity_done` set; validation errors for a bad attribute and a missing name;
  the instance with `activity_done` survives `GameState.to_save_dict`/`from_save_dict` (or the WorldEvents save helper).
- tests/unit/test_game_session.gd: during a forced lantern festival in Qingshi, `GameState.festival_activity("lantern_festival")` raises qi and the
  life stat; a second call is refused with the reason.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. A mortal (realm 0) can take part.
