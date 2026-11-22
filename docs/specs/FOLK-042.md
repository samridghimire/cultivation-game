# FOLK-042: A sworn friend, actually reached

Role: systems. Reference: Stardew Valley's friendship arc (tea, gifts and a birthday carry a friend to the top tier within
about a year of steady attention), mechanics only; never its names, layout or art.

## Why
FOLK-040 (258488d) let the first liked birthday gift go past the gift cap up to favor 90 and taught the hints player to follow the
new "Grow closer: X's birthday in N days" line, but the measure did not move: **sworn_friend never in 10/10 seeds**, in every one
of the six starts (SIM-024 42a4a03). The commit could not say why: `first_hour_presses.gd --trace=<seed>` stops at the first friend,
so the weeks after Close friend (favor 60, day ~125) are invisible. Sworn friend (favor 85) is shown on the People card as the next
goal, so today the game promises something no steady player reaches.

## Part 1: see it (required, paste in the commit)
1. Add `--trace-friend=<seed>` to `tests/sim/first_hour_presses.gd` (keep `--trace` as it is): for that one seed, from the day the
   best friend reaches Close friend until day 730 or Sworn friend, print one line per week:
   `day, friend id, favor, days_to_birthday, tea cooldown left, liked item in bag (id or -), top 5 hint lines (short form), action taken`.
   Also print a line on the birthday itself, even if it falls mid-week.
2. Run it for seeds 1 and 2 on qingshi_village and paste the weeks around the first birthday after Close friend.
3. Name the cause in the commit message. Candidates to check, in this order:
   - the weekly step skips the exact birthday day (the hints sim acts once per 7 days; the birthday window is one day);
   - favor is below 80 on the birthday, so 90 cap is fine but the gain (liked x2, often +6..+10) leaves the friend under 85;
   - tea stops at `folk_visits.call_on.max_favor` 80 and nothing else moves favor between 80 and 85 except that one day a year;
   - the birthday line is outside the top 5 the sim acts on, or the liked item is not buyable in reach (C-407 is fixing data for that).

## Part 2: fix the smallest real cause
- **Sim-only cause** (the sim misses a day the player would not): make the hints player wait or travel so it is beside the friend
  on the birthday (a real player sees the line 14 days ahead). No rule change.
- **Rule cause** (a player who does everything still stalls under 85): planner default, a small balance call recorded under
  DESIGN.md "Planner default (FOLK-040...)": on the birthday the liked gift's gain is at least `acquaintance.birthday_min_gain`
  (new, optional, default 10; document in family.json `_doc`, validate int 0..30 next to `birthday_max_favor`), still capped at
  `birthday_max_favor` 90. A friend at tea's cap 80 then reaches 90 on one birthday. Do not raise tea's cap or the gift cap.
- If the cause is "no liked item in reach", stop and write it under Follow-ups naming the villagers (that is C-407's job).

Re-run SIM-024's six-start table (`first_hour_presses.gd --starts`, 10 seeds x 24 months) and paste close_friend and sworn_friend
before/after. Target: sworn_friend reached in >= 5/10 seeds in qingshi_village, and in at least 4 of the 6 starts. Refresh the
"friendship in every start" baseline section SIM-024 refreshed.

## Part 3: first lesson before Close friend
SIM-024 found `first_lesson` day == `close_friend` day in every seed of every start, although C-408 put lessons at tier 2 (Friend,
favor 40). Check with the same trace whether (a) the hints player never talks to a Friend with a lesson due (the "has a lesson for you"
line, GUIDE-218 `Folk.lessons_waiting`, is not acted on or not in the top 5), or (b) `due_lessons`/`tier_index` treat tier numbers off
by one (Acquaintance = 1, Friend = 2, Close friend = 3?). Fix (a) in the sim, (b) in folk.gd with a unit test (a Friend at favor 45
with a tier-2 lesson gets it on the next talk; a tier-3 lesson waits for favor 60). Paste the first_lesson column after.

## Tests
- `tests/unit/test_folk_birthday.gd` (or FOLK-040's test file): if Part 2 adds `birthday_min_gain`, a liked birthday gift at favor 80
  ends >= 85 and fires the Sworn friend tier-up; at favor 88 it ends at 90; a neutral gift on the birthday is still refused at 50+.
- Part 3 (b) unit test as above. GameData validation test for the new field if added.
- `tools/test.sh` green. This changes the sims' friendship numbers, not combat or economy: run `tools/balance.sh --check`
  only if Part 2 changes rules; if so, refresh only the sections that moved and explain them.

## Acceptance
- Commit pastes the trace excerpt, the named cause, and the before/after table.
- sworn_friend >= 5/10 seeds in qingshi_village, or a named cause under Follow-ups that is not this task's to fix.
- No SAVE_VERSION change (no new persistent state).
