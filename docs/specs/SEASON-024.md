# SEASON-024: season tasks a newcomer can finish

Role: systems (sim code + one audit test). Reference: Stardew Valley's community bundles (mechanics only): every
seasonal ask should be doable in that season by a player who tries.

## Problem
QA-215's `--season-tasks` policy (tests/sim/first_hour.gd `season_tasks`, ~1239-1300) finished only 1 of 6 year-1/2
season sets over 6 seeds x 24 months. Its follow-ups split the misses into:
- `autumn_market` / `winter_market` (sell_wanted): the sim never holds a wanted good;
- `summer_boats`, `spring_qingming`, `autumn_moon`, `winter_lanterns` (contest/festival): the monthly policy misses the
  festival day;
- `spring_petals`, `winter_iron`, `autumn_roach` (gather/catch): "no reachable table within 3 days";
- hunts: the policy only fights at 50%+ odds.
We don't yet know which are sim limits and which a real player can't do either.

## Part 1: the policy plays like a player (tests/sim/first_hour.gd)
1. Festivals/contests: check daily (not monthly) during a month that holds an open contest task's event; travel there
   so you arrive on the event day (use the event's `months`/`regions` as `SeasonTasks.where` does) and enter.
2. sell_wanted: when a stall within 3 route days wants something today (`Places.wanted_today`), buy it in the nearest
   shop that sells it if affordable (else gather/catch it when the place's table has it), travel and sell.
3. Hunts: take the hunt when `Combat.win_chance` >= 0.4 (was 0.5), healing first if injured.
Keep the memo key in `play_cached` in sync. Base output (without `--season-tasks`) must not change.

## Part 2: an audit test (tests/unit/test_season_tasks.gd)
For every task in data/season_tasks.json with `first_year: true` or in a year-1 set, at the first day of its season,
for a stage-0 Qi Refining character: `SeasonTasks.where(task, c, data, day)` is not "" and the place it names is within
6 route days of Qingshi (`Exploration`/route helpers). Tasks that fail go into a `KNOWN_UNREACHABLE` array in the test
with a comment each; the test fails if a task is unreachable and not listed, and also if a listed task becomes reachable
(so C-382 can empty the list).

## Run and report
`simulate_curious_years.gd -- 6 24 --season-tasks --season-report` before and after part 1: sets finished per season,
and per missed task the reason. Paste both tables in the commit. Under `Follow-ups:` list every task that stays out of
reach for content (C-382 picks them up).

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; sim base output unchanged; the commit has both tables and the unreachable list.
