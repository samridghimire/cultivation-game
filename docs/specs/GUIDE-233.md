# GUIDE-233: The first jobs on the Earning card, one beginner's-luck line

Role: systems. Reference: Stardew Valley's help-wanted board (mechanics only: one-off paid jobs listed next to the daily
routine). Size: one run.

## Why
- GUIDE-230 rightly limited "Earning here" rows to repeatable work, but now a newcomer in Qingshi never sees the three
  one-time headman chores on the card, although they are the best first money (8 stones + a pill, 12 stones, 2 pills).
  The planner's journal.png (2026-11-10) shows only "gathering ... 3 stones" and "Fishing ... 2 stones".
- The gathering row prints lowercase "gathering (Village Herb Slope)" while fishing prints "Fishing": in
  `Earnings.lines` (src/core/systems/earnings.gd ~204) the note "gathering" is not equal to the kind "gather", so it is
  not capitalized.
- Reviewer note on FISH-008: an empty first trip posts "A fish takes the bait, then it got away." and then "Beginner's
  luck: +1 X." (game_state.gd ~1404 and ~1428), which contradicts itself.

## Build
1. `Earnings.one_time_rows(c, data, flags, region_id, today) -> Array[Dictionary]`: for each `deed_giver` place in the
   region (same loop and hidden_by_flag rule as `earning_options`), every deed that pays stones or items with a sell
   value, is NOT repeatable (`Deeds.is_repeatable` false), has `effects.alignment >= 0`, passes `Deeds.check` (so done
   ones and blocked ones drop out). An `enemy` deed is allowed here but carries `"enemy": <name>` and the player's
   rated odds text if a helper exists (grep `fair_fight` / `odds_text` in guidance.gd); skip it if rated Deadly.
   Row: `{"kind": "job", "place": <place name>, "note": <deed name>, "stones": int, "items": {id: n}, "days": int}`.
   Max 2 rows, highest stones first.
2. `Earnings.lines` prints a job row as "Once: <deed name> (<place>): <N> stones[ + <item names>], <d> day(s)." and fix the
   capitalization so every kind's first word is capitalized ("Gathering (Village Herb Slope): about 3 stones a day.").
3. Journal "Earning here" card (src/ui/journal_screen.gd ~195): append the job lines after the per-day rows (the card
   already takes a PackedStringArray; build it where `earning` is built). The HUD short hint does not change.
4. Beginner's luck: in `GameState` fishing (~1404), when the trip got away AND `found` stays empty AND it is the first
   trip (`player.catch_log.is_empty()`), do not post the "got away" line; post one line instead:
   "A fish takes the bait and slips free, but a small one stays on the hook. Beginner's luck: +1 <name>." The
   "nothing bites" path likewise posts only the beginner's-luck line when the catch triggers. Keep the strings as
   constants in Fishing (core) so tests can match them.

## Tests
- tests/unit/test_earnings.gd: a fresh character in Qingshi gets the headman one-time jobs (up to 2 rows, stones
  descending); after setting `chore_herbs_done` that deed's row is gone; a negative-alignment one-time deed (rob,
  poison) never appears; lines() capitalizes "Gathering".
- tests/unit/test_game_session.gd (or the FISH-008 test file): seed a first trip that gets away (force
  `Fishing.got_away` via a seed loop as FISH-008's test does); the log has the beginner line and no "got away" line.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Render the default first-hour journal.png at 1280x720 and open it: the card
shows the gathering/fishing rows plus up to two "Once:" rows and fits the card.
