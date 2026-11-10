# SEASON-012: The season in review

Role: systems (core summary + GameState hook + one HUD banner call). Reference: Stardew Valley's end-of-season
recap (mechanics only: a short look back when a season ends). Size: ~200 lines with tests.

## Why
The first hours now hold season tasks, festivals, hens, the shrine/well/jetty projects, great-beast trails, friends and
taught dishes, but nothing ever looks back on them: a season ends silently and only the year review (YEAR-001,
`LifeStats.year_summary`, shown by `hud._on_year_reviewed` as a banner) sums anything up, once a year. A short recap at
each season's end tells the player what they did and what is coming.

## Build
1. `CharacterData.season_start_stats: Dictionary = {}` (life_stats at the last season start) and
   `season_start_day: int = -1`, in `to_dict`/`from_dict` with those defaults (no SAVE_VERSION bump: the defaults
   mean "no snapshot yet", exactly like `year_start_stats`).
2. `LifeStats.season_summary(before: Dictionary, after: Dictionary, extras: Dictionary) -> PackedStringArray`, pure,
   at most 4 lines, most important first, empty-delta lines skipped:
   - `extras.tasks_done` / `extras.tasks_total` (from `SeasonTasks` for the ended season, Qingshi only):
     "Village tasks: 3 of 3 done." (or "2 of 3 done.")
   - `extras.project_line` (String, "" when no stage was repaired this season): e.g. "The old shrine: stage 2 of 4."
     Build it in GameState from `SeasonTasks.project_index` before/after; keep the wording generic so the content
     worker can reword.
   - fights: "You won 4 fights and lost 1." (`fights_won` / `fights_lost`, game_state.gd ~3921), great beasts ("You brought down a great beast."), `harvests`, `foraged`, `items_crafted`,
     `festival_activities` ("You joined 2 festival events."), `missions_done`, `breakthroughs` ("You broke through
     twice."). Pick in that priority until 3 lines are used; then
   - `extras.coming` (String): the next season's first fixed-date festival from the calendar, "Coming: the Dragon Boat
     Festival in month 5." ("" when none).
   A season with no deltas, no tasks and no project returns `["A quiet season."]` plus the coming line.
3. GameState: in `_on_days_advanced`, when `SeasonTasks.season_name(day)` (or the calendar's season index) differs
   from the season of `player.season_start_day`, build the summary for the season that ended (if several seasons
   passed in one time skip, only the last one ended is reviewed, and the stats delta still covers the whole span),
   post each line to the log under category "progress", emit `EventBus.season_reviewed(season: String, year: int,
   lines: PackedStringArray)`, then snapshot (`season_start_stats = life_stats.duplicate()`, `season_start_day = day`).
   A save with `season_start_day == -1` only snapshots (no recap on the first change after loading an old save).
   **Winter:** the winter -> spring change is also the new year; skip the season banner then (the year review shows),
   but still post the winter lines to the log and snapshot.
   New game: snapshot at session start.
4. EventBus: `signal season_reviewed(season: String, year: int, lines: PackedStringArray)` with a `##` doc line, placed
   at the end of the season signals block (keep the doc comment order intact; the reviewer fixed a misplaced one last
   run).
5. HUD: connect `season_reviewed` the way `_on_year_reviewed` works (same `yearly_recap` setting, same deferred flush
   so a time-skip overlay or death screen goes first): `_banner.announce("Spring of Year 1 is over", "\n".join(lines),
   UIStyle.ACCENT, 4.0)`. If a year review is pending in the same flush, show only the year review.

## Tests
- `tests/unit/test_life_stats.gd`: season_summary with deltas in every listed key (priority and the 4-line cap),
  quiet season, tasks 3/3 and 2/3, coming line present/absent.
- `tests/unit/test_game_session.gd`: start a session, add `fights_won`, advance days across the spring -> summer
  boundary: one `season_reviewed` emission with "Spring" and the fight line; advance across two boundaries in one
  call: one emission for the last ended season; winter -> spring: no `season_reviewed` emission (year review only)
  but the log has the winter line; an old save dict without the new keys loads and the first boundary emits nothing.
- CharacterData round-trip of the two new fields.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. No balance values change: no `balance.sh --check`.
Follow-ups for the planner: a world-ui card for the recap if the banner is too small for 4 lines; content to reword
the project and quiet lines.
