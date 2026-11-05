# FEST-006: A festival contest (systems)

Reference: Stardew Valley's festival contests (egg hunt, fishing contest), mechanics only: once a year, a short
contest at the festival with a placing against named locals and a keepsake prize. No names, story or art from it.

## Why
The three festivals (Qingming at Azure Peak, Mid-Autumn at Fallen Star Market, Lantern at Qingshi) offer a stall,
a few encounters and one activity (FEST-003). Nothing there is a moment the player looks forward to. A contest
where you place against villagers you know, once a year, gives each festival a small peak.

## Data (data/world_events.json)
An optional `contest` block on a festival event (document it in the file's `_doc`, validate in `GameData._validate()`):

```json
"contest": {
  "name": "Lantern riddles",
  "text": "Riddles hang from the lanterns along the river; the villagers race to answer the most before the candles gutter.",
  "attribute": "comprehension",          // attributes.json id; the player's score uses it
  "profession": "",                       // optional professions.json id: +2 per rank to the score (e.g. "alchemist" for a herb-judging contest)
  "rivals": 3,                            // 2..4 villagers of the region compete (Folk.candidates order), fallback "a stranger"
  "prizes": [                             // index 0 = 1st place; 1..3 entries; validated items/effects keys
    {"items": {"paper_lantern": 1, "spirit_stone": 15}, "favor_all": 3, "renown": 2},
    {"items": {"sweet_rice_ball": 2}, "favor_all": 1},
    {"favor_all": 1}
  ],
  "win_text": "The old riddle-master hands you the red lantern: no one has answered so many in years.",
  "lose_text": "{winner} answers the last riddle before you and laughs as the crowd cheers."
}
```

Validation: `attribute` exists; `profession` empty or exists; `rivals` 2..4; `prizes` 1..3 entries, item ids exist,
`favor_all` 0..5, `renown` 0..5; `lose_text` may use `{winner}` only. Give all three festivals a contest
(this task writes them; C-306 adds more prize variety later):
- Lantern Festival (Qingshi): "Lantern riddles", comprehension.
- Mid-Autumn (Fallen Star Market): "Moon-cake judging" (taste and tell the fillings), spirit; profession `alchemist`.
- Qingming (Azure Peak): "Kite flying on the ridge", constitution.
Prizes: 1st 10-20 spirit stones plus one festival shop item, small favor; keep 1st place worth less than one week of
village work at rank 0 (compare data/professions.json income).

## Core (new `src/core/systems/festival_contest.gd`, `class_name FestivalContest`, RefCounted, static)
- `static func contest_of(data: GameData, event_id: String) -> Dictionary` ({} when none).
- `static func check(data: GameData, active: Array, c: CharacterData, event_id: String, region_id: String, flags: Dictionary, year: int) -> String`:
  "" or the reason (no contest, not here/not running, already entered this year: world flag `contest_<event_id>_<year>`).
- `static func run(data: GameData, c: CharacterData, event_id: String, rivals: Array[CharacterData], rng: RandomNumberGenerator) -> Dictionary`:
  player score = attribute value + 2 x profession rank (if set) + `rng.randi_range(0, 10)`; each rival's score =
  their attribute value (CharacterData of the NPC; 8 if missing) + `rng.randi_range(0, 10)`; ties go to the player.
  Returns `{"place": 1..rivals+1, "scores": [{"name", "score", "you": bool}] sorted high to low, "prize": Dictionary or {}, "text": String}`.
  Places beyond the prize list get no prize. `text` = win_text for 1st, lose_text with `{winner}` filled otherwise.
- `static func standings_lines(result: Dictionary) -> PackedStringArray`: "1. Mei Lan 17", "2. You 15", ... (max 5 lines).
- Pure: no Nodes, no GameState, rng passed in.

## GameState
- `func festival_contest_here() -> String`: the active festival event with a contest in this region ("" if none).
- `func check_festival_contest(event_id: String) -> String` and `func festival_contest(event_id: String) -> Dictionary`:
  picks rivals with `Folk.candidates(npcs, data, player, current_region)` (first `rivals`, fewer if the village is
  small), runs the contest with `rng`, sets the world flag, applies the prize (items, renown via `Renown.add`, +favor_all
  to every region villager via the same favor dict Folk uses), takes 0 days (the festival activity also takes 0),
  posts the text plus "You place 2nd of 4." in category "world", stores the result in `last_contest` (session only) and
  emits `EventBus.contest_finished(result)` (add the signal to EventBus).
- The year for the once-per-year flag: `GameClock` year from total_days (same math the calendar uses).

## World (smallest UI, WU-455 makes it nice)
The festival merchant (src/world/interactables/merchant.gd, where FEST-003's activity entry is added, ~line 41) adds
one more option when `festival_contest_here()` is set: "Enter the <contest name>" (disabled with the check reason).
On choose: call `GameState.festival_contest(event_id)`; the standings appear in the message log only.

## Calendar and hints
- VillageCalendar's festival entry text gains " (contest: Lantern riddles)" when the event has a contest.
- Guidance: while a festival with a contest runs in the player's region and they have not entered this year, the HUD
  "Next steps" gets one low-priority line: "The Lantern riddles are on at the festival stall today." (at most one).

## Tests (tests/unit/test_festival_contest.gd + an integration test in tests/unit/test_game_session.gd style)
- Data: every contest validates; a bad attribute / rivals 5 / unknown item is reported.
- `run`: seeded rng gives the same result twice; a player with attribute 30 always places 1st against 8-attribute
  rivals; ties go to the player; place beyond prizes gives {} prize; `{winner}` filled.
- `check`: not running, wrong region, already entered this year -> reasons; next year allowed again.
- GameState: start the Lantern Festival in Qingshi (WorldEvents test helpers), enter, prize items land in the
  inventory, flag set, second entry refused, favor of a Qingshi villager rose by favor_all for 1st place.
- Save: the world flag persists (world_flags already saved); no new CharacterData fields.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Balance check not needed (prizes are small, festival-only); say so in the
commit. Follow-ups for WU-455 (podium card).
