# SECT-036: The first promotion within the first season

Role: systems. Reference: Tale of Immortal's outer-disciple climb (mechanics only: an engaged new disciple earns their
first rank in a few months by reporting, listening, doing missions and passing one exam). Size: ~300 lines with sim and
tests; needs `tools/balance.sh --check` (data change), refresh the `sect year` section.

## Why
SIM-028 (dacc10d, `tests/sim/sect_year.gd`, seeds 1-3, the three joinable start-region sects) found that **nobody reaches
rank 1 in the first year**: rank 0 at day 365 with 265-455 contribution (Inner Disciple needs 500 + a trial; Blood
Disciple 400; Steward 600), the hall report only happens 190-240 days after joining (in the sect's own home region),
and 0 lectures are attended in all 9 runs. With rank 0 there is no stipend and no duty, so the whole sect loop the last
two days of work built (SECT-032..035, WU-602..608) is never exercised by the sims, and probably not by players either.

## Part 1: the hints player (tests/sim/first_hour.gd)
1. Lectures: the hints branch at first_hour.gd ~2683 matches `"lectures this month"`, but SECT-034 reworded the line to
   "<lecture>: open this month (Nd left)". Match on what Guidance now emits (prefer a stable check such as
   `Sects.check_lecture(c, data, day) == ""` when a sect line is shown, not a string match).
2. The late report: find why a member standing in the sect's home region only reports ~200 days after joining
   (GUIDE-289 taught the hints player to walk and report; is the "Report at" line outranked by other hints, or missing
   from the top line until the first goals are done?). Fix it where it is wrong: if Guidance ranks the report hint
   below routine hints for a member who has not reported, that is a game bug (players see the same order); fix it in
   guidance.gd so the report line leads (SECT-034 meant it to). Paste the cause in the commit.
3. Trials: when `Sects.needs_trial(c, data)` and `Sects.check_promotion(c, data) == ""`, the hints player attempts the
   trial (`gs.attempt_promotion_trial()`) if the rated odds (`Combat.win_chance`) are >= 0.5, else keeps training.
   Print the trial odds the first time the contribution is met.

## Part 2: measure, then the smallest balance fix
Run `sect_year.gd` (seeds 1-3) after Part 1 and paste the table. Target: **every sect's first promotion by day 180 after
joining in at least 2 of 3 seeds**, and stipend paid in at least 2 months of year 1.
- If contribution is the blocker: lower rank-1 `contribution` in data/sects.json (no lower than 250) and/or raise the
  contribution of the early (min_rank 0) sect missions; say which and why.
- If the trial is the blocker (odds < 50% when contribution is met): lower that trial enemy one step (enemies.json
  stats, or point the rank at a weaker existing foe); rank-1 trials must stay a real fight (rated 50-85 in 100 for the
  hints player at the day contribution is met).
- Don't touch ranks 2+ or realm pacing (F-005d is the owner's).
Record the new numbers in DESIGN.md "Current systems" under Sects ("first promotion: ~N days for an engaged disciple").

## Tests
- tests/unit: the hints-player lecture branch is not string-bound (if you factor a helper, test it); a guidance test that
  an unreported member's top hint in the home region is the report line (test_sect_goals.gd or test_guidance*.gd).
- Existing sect tests stay green (contribution numbers in tests may need updating: keep them reading from data).

## Acceptance
- `sect_year.gd` before/after table in the commit; target met or the remaining blocker named under Follow-ups.
- `tools/balance.sh --check` run; `sect year` (and any moved section) refreshed with one sentence per moved line.
- tools/test.sh ALL CHECKS PASSED.
