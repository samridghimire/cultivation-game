# RIVAL-003: Meet your rival (the first weeks)

Role: systems. Planner, 2026-10-15 08:10.

## Why
Every new character gets a named rival at creation (`Rivals.spawn`, game_state.gd ~126), but the game marks the rival notice as
already seen ("a rival from the start is not news") and never introduces them. The rival only shows up through rare encounters
(`rival_sneers`, `rival_contest`, ...) or as a line on the character sheet. The genre's oldest hook, a proud peer of your own
age who started on the same day, is invisible during the first hour. This task stages one short meeting in the first weeks.

## Changes

### 1. data/karma.json `rival` block
Add `"first_meeting_day": 10` and `"first_meeting_window": 365` (days). Document both in the file's `_doc` (or the `rival`
block's doc line if there is one): the rival's first-meeting event (`rival_first_meeting` in data/dialogue/) plays once on or
after day `first_meeting_day` of a life and not after `first_meeting_day + first_meeting_window` (old saves past their first
year never get a "first" meeting). Validate in `GameData._validate()`: both ints >= 0 when present.

### 2. src/core/systems/rivals.gd
```gdscript
const FIRST_MEETING_EVENT := "rival_first_meeting"
const FIRST_MEETING_FLAG := "rival_met"

## True when the rival's first meeting should play now: the rival lives, the
## meeting has not played (world flag FIRST_MEETING_FLAG), and `today` is inside
## [first_meeting_day, first_meeting_day + first_meeting_window].
static func first_meeting_due(c: CharacterData, people: Dictionary, data: GameData, flags: Dictionary, today: int) -> bool
```
Use `rival_of(c, people)` (already exists). Defaults when the keys are missing: 10 and 365.

### 3. src/core/systems/dialogue.gd
- `format()` also fills `{rival}` and `{rival_realm}` from `ctx.get("rival")` (a CharacterData or null; "" when null).
  Update the header doc line ("Text may use ...").
- Choice labels go through `format` too if they don't already; check `view()`.

### 4. src/autoload/game_state.gd
- `_dialogue_ctx` adds `"rival": Rivals.rival_of(player, npcs)`.
- After time passes (the end of `_on_days_advanced` is fine, guarded by `_can_act()`), when
  `Rivals.first_meeting_due(player, npcs, data, world_flags, GameClock.total_days)` and not `in_dialogue()`, call
  `start_event(Rivals.FIRST_MEETING_EVENT, Rivals.FIRST_MEETING_FLAG)`. `start_event` emits `dialogue_requested`, which the HUD
  already answers by opening the dialogue window (that is how the intro event shows). If starting a dialogue from inside
  `days_advanced` turns out to clash with an action still posting (e.g. explore posts its encounter after the days pass), set
  `pending_event` instead and have the HUD call `GameState.start_pending_event()` after the action, the way it does at
  session start (hud.gd ~218); pick whichever works and say which in the commit body.
- Never during combat, a respawn, a tribulation or a pending encounter/threat choice: if any of those is active, wait for the
  next day advance (the check simply runs again).

### 5. data/dialogue/rival_first_meeting.json (a story event, no NPC; nodes name their own speaker)
Short, genre voice, 3 nodes at most. Sketch (rewrite freely):
- `meet` (speaker "{rival}"): "{rival}, a youth of your own age, blocks the path with a pack of hangers-on. 'So you are the
  one who woke on Meditation Rock the same morning I did. The elders say the heavens like a matching pair. I say only one of
  us climbs.'"
  - "Bow and say nothing." -> end, effects `{"qi": 20}` (text in a follow-up node: you swallow it and train harder).
  - "Then I will climb past you." -> end, effects `{"set_flag": "rival_vow"}`.
  - "Why not climb together?" -> end, a short scornful answer.
- Speaker uses `{rival}`; if `format` is not applied to `speaker`, apply it there too.
- No stones, no fights (a fight here would be unfair this early).
- `Dialogue.validate` must pass (GameData loads every file in data/dialogue/).

### 6. Help/notice
No new notice: the event itself is the introduction. Leave `notice_rival` as it is.

## Tests
- tests/unit/test_rivals.gd (or the nearest rival test file): `first_meeting_due` false before day 10, true on day 10 with a
  living rival, false when the flag is set, false when the rival is dead, false after day 375.
- tests/unit/test_dialogue.gd: `format("{rival} is {rival_realm}", ctx)` with a rival in ctx, and with none ("" both).
- tests/unit/test_game_session.gd: a new game; advance to day 10 (meditate or `GameClock.advance`, the way other session
  tests pass time); `GameState.dialogue_event == "rival_first_meeting"` (or `pending_event`, whichever path you chose) and
  `world_flags["rival_met"]`; finishing the dialogue and advancing more days never starts it again.
- Data test: `rival_first_meeting` exists and validates.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. A new character meets their rival in a dialogue window around day 10; loaded saves
older than a year never get it. Size: ~200 lines.
