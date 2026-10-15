# RIVAL-014: a successor rival

DESIGN.md "(RIVAL-014) A successor rival" default: when your named rival dies **not by your hand** (your own kill already
starts kin vengeance), a new young cultivator at your realm names you their rival some time later. Smallest version only.

## Data
`data/karma.json` `rival.successor_delay_days`: int >= 0, default 180; 0 disables successors. Add it to the `rival` object
(value 180), document it at the end of the `_doc` string ("successor_delay_days (RIVAL-014, int >= 0, default 180): days
after word of the rival's death (not by your hand) until a new rival names you; 0 = never"), and validate it where the other
`rival` keys are validated (grep `bitter_grudge` in `Rivals.validate` / `GameData._validate`).

## Core (src/core/systems/rivals.gd)
- `const SUCCESSOR_DAY_FLAG := "rival_successor_day"` and `const MEETING_FROM_FLAG := "rival_meeting_from"`.
- `static func successor_delay(data: GameData) -> int` = `int(rules(data).get("successor_delay_days", 180))`.
- `static func successor_due(flags: Dictionary, today: int) -> bool`: true when `flags.has(SUCCESSOR_DAY_FLAG)` and
  `today >= int(flags[SUCCESSOR_DAY_FLAG])`.
- `first_meeting_due`: the window starts at `int(flags.get(MEETING_FROM_FLAG, r.get("first_meeting_day", 10)))` instead of
  the fixed `first_meeting_day`, so a successor's first meeting can play years into the game. Old behaviour is unchanged when
  the flag is absent.
- `static func successor_line(rival: CharacterData, old_name: String) -> String`:
  `"Word spreads of %s, a young cultivator who means to take %s's place as your rival." % [rival.name, old_name]`.

## Game state (src/autoload/game_state.gd `_rival_news`, ~3021)
1. Where the death line posts (`death_line != ""`, i.e. not your own kill) and the delay is > 0, set
   `world_flags[Rivals.SUCCESSOR_DAY_FLAG] = GameClock.total_days + Rivals.successor_delay(data)` and
   `world_flags["rival_predecessor"] = dead.name`. Your own kill (death_line == "") sets nothing.
2. At the top of `_rival_news` (before the FIRST_MEETING_FLAG early return, because a successor must spawn even though the
   old rival was met), when `player.alive` and `Rivals.successor_due(world_flags, GameClock.total_days)`:
   `var heir := Rivals.spawn(player, npcs, data, rng, current_region)` (check the actual region var name), then erase
   `Rivals.SUCCESSOR_DAY_FLAG`, `Rivals.FIRST_MEETING_FLAG`, `Rivals.SEEN_REALM_FLAG`, `Rivals.SURPASSED_FLAG`,
   `"rival_death_news"`, and set `world_flags[Rivals.MEETING_FROM_FLAG] = GameClock.total_days`. Post
   `Rivals.successor_line(heir, String(world_flags.get("rival_predecessor", "your old rival")))` in category "world", then
   erase `"rival_predecessor"`.
3. All of these are `world_flags`, so saves need no format change (they round-trip already). Check that nothing else
   assumes `player.rival` never changes (grep `player.rival` and `npc_favor` caches; the new rival starts at favor 0).

## Tests
- tests/unit/test_rivals.gd: `successor_due` false without the flag / before the day, true on and after it;
  `first_meeting_due` honours `MEETING_FROM_FLAG`; `successor_line` wording; validation rejects -1 and "x".
- tests/unit/test_game_session.gd:
  - the rival dies of old age (set `alive = false`, `cause_of_death = "old age"`), run the monthly news: the successor day is
    set to today + 180; advancing past it gives `player.rival` a different living NPC id, posts the successor line once, and
    `Rivals.first_meeting_due` is true again;
  - the rival `cause_of_death = "slain by <player name>"`: no successor flag;
  - `successor_delay_days` 0 (override the loaded data): no successor flag;
  - a save round-trip (`to_save_dict` / load) keeps the due day.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Under ~250 changed lines.
