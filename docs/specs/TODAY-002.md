# TODAY-002: An arrival that says what it means, once

Role: systems. Reference: Stardew Valley's morning TV/news line (one clear sentence of what today holds), mechanics only.

## Why
Planner shots 2026-11-06 12:10 (`screenshot_first_hour.gd -- --great --region=qingshi_village,azure_peak,misty_forest`,
1280x800):
- A new game's log opens with "Today in Qingshi Village: 1 thing by the path. (x2)": the arrival line is posted twice on
  day 1 (WU-464 now folds it into "(x2)", but it is still posted twice). "1 thing by the path" says nothing.
- In Misty Forest the log reads "Fat Fog-Antler Stags run in Misty Forest this spring." / "Today in Misty Forest: ..." /
  "Fat Fog-Antler Stags run in Misty Forest this spring." again three days later: the in-season line (WILD-013) is posted on
  every arrival all season.

## Spec
1. **Posted once.** Find why `GameState._post_arrival_line()` (src/autoload/game_state.gd ~681) runs twice for a new game
   (start_session ~155 calls it; check whether `region_changed`/the world builder, `travel`, or the HUD's first refresh posts
   it again, and whether tests/sim/screenshot_first_hour.gd calls a GameState travel to the start region). Fix the cause in
   game code (not in the screenshot script) so a new game posts it once; guard with `world_flags["arrival_day"]` /
   `["arrival_region"]`: if both already equal today and this region, do not post again.
2. **Name the find.** `Guidance._forage_phrase` (src/core/systems/guidance.gd ~220) names what lies by the path, using item
   names from `Foraging.unpicked(...)`: 1 pickup -> "Village Mugwort by the path"; 2 -> "Village Mugwort and Dew Grass by the
   path"; 3+ -> "Village Mugwort, Dew Grass and 2 more by the path" (distinct names, rarest first: lowest forage weight in
   the region's `forage.items`, ties by name; same name twice counts once in the names but in the "N more"). Keep it under
   ~60 chars: if longer, fall back to "<rarest> and N more by the path". `today_lines` (~239) uses the same phrase if it
   has a forage line (grep `_forage_phrase`).
3. **In-season line once a season per region.** The `Wildlife.season_clause` post in `_post_arrival_line` happens only the
   first time the player arrives in that region in the current season: keep a world flag `season_line_seen`
   = {region_id: season key "<year>-<season>"} (overwritten per region, so it stays small); post and set it when the key
   differs. Today page (`today_lines` ~282) keeps showing the clause every day (it is a page, not a log).
4. No save-format bump (world flag defaults to {}).

## Tests (tests/unit)
- arrival phrase: 1, 2, 3 and 5 pickups (names, rarest first, "N more"), and the long-name fallback; 0 pickups -> "".
- GameState integration (test_game_session.gd style): new session posts the arrival line exactly once (count
  EventBus history lines starting "Today in"); travel away and back on the same day posts it again for the new region;
  the in-season line is posted on the first arrival of a season and not on the second arrival in that season, and again
  after the season changes.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. No balance run (text only). The commit says which code path posted the line twice.
