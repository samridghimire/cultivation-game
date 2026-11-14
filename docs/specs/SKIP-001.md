# SKIP-001: Meditation that wakes for the day you'd hate to miss

Role: systems. Reference: Tale of Immortal (closed-door cultivation is broken off by events the player cares about) and
Stardew Valley's calendar (you never sleep through a festival). Mechanics only.

## Problem
`GameState.cultivate(days)` (src/autoload/game_state.gd ~201) runs the whole span unless the bottleneck ends it. The
quiet-stretches sim (docs/balance_baseline.txt "quiet stretches") shows the default player meditating through 60-day
stretches with nothing new, and a player who picks a month of meditation sleeps straight through a festival, a market day
of a timed place, a great-beast day or a crop ripening. The calendar already knows all of these:
`VillageCalendar.upcoming(data, npcs, favor, active_events, region_id, start, span, c, flags)` returns dated entries
`{day, kind, text, region}`.

## Build
1. New pure static in src/core/systems/village_calendar.gd:
   `static func wake_day(data, npcs, favor, active_events, region_id, start: int, span: int, c: CharacterData, flags: Dictionary) -> Dictionary`
   - Returns the first entry in (start, start + span) (strictly after today, so a skip started on the day itself is
     not cut to 0) whose kind is in `WAKE_KINDS := ["festival_day", "festival_active", "hunt", "field", "rent", "request", "secret_realm", "event", "birthday"]`
     and whose region is `region_id` or "" (anywhere), as `{day, kind, text}`; `{}` when none.
   - Skip `hunt` entries that `_beast_matters(...)` says don't matter to the player (reuse the LOG-005 rule) so a beast
     the player has no hunt for doesn't wake them.
   - Do NOT wake for `market`, `forage`, `season`, `almanac`, `festival_month` (too frequent / not a single day).
2. In `GameState.cultivate` (and so `cultivate_in_seclusion`, which calls it) only when `asked >= 7`: compute
   `wake := VillageCalendar.wake_day(...)` for the span the bottleneck passes settled; if not empty and
   `wake.day - today < days`, set `days = wake.day - today` (>= 1), `ends_early = true`, and after the cultivate line post
   one info line: `"You open your eyes: %s." % wake.text` (lower-case the first letter of text if needed; keep it
   <= 90 chars). The bottleneck line keeps priority when both apply (whichever comes first wins; post only that one's line).
   - Recompute `density` for the shortened span the same way the bottleneck shortening does.
3. A player-facing off switch is not needed now; note it under Follow-ups if you think it is.
4. Save: nothing new (the calendar is computed).

## Tests
tests/unit/test_village_calendar.gd (or a new tests/unit/test_wake_day.gd):
- a festival day 10 days ahead in this region -> wake_day returns it for span 30, `{}` for span 5;
- a festival in another region -> `{}`; a market day -> `{}`;
- an entry on `start` itself is ignored;
- a great beast with no hunt task / trail -> `{}`, with one -> its day.
tests/unit/test_game_session.gd (GameState integration):
- meditate 30 days with a festival 6 days ahead in the region -> exactly 6 days pass and the "You open your eyes" line is
  posted; meditate 5 days in the same setup -> 5 days pass (under 7 days never interrupted);
- the bottleneck 3 days ahead and a festival 6 days ahead -> 3 days, only the bottleneck line.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. This changes how many days pass per meditation, so run
`tools/balance.sh --check` and refresh the "quiet stretches" and "first hour" sections; explain the diffs in the commit.
