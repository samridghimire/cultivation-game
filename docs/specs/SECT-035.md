# SECT-035: The first month in the sect, as goals

Role: systems. After SECT-034 (the hints player must be able to report and attend lectures, or the goal row stalls the sims).
Reference: Tale of Immortal's new-disciple tasks (mechanics only: a short checklist that teaches the sect's loop:
report, listen, take a mission, rise). Size: ~250 lines with tests.

## Why
After "Join a sect" the goal row jumps to the road ladder ("Walk to Misty Forest", "Visit Fallen Star Market", "Beat a
great beast"): nothing in Next steps teaches a new disciple what the sect is for. WU-602..WU-605 show the sect, but the
goal row, which players follow most, never points at it.

## Design
A new ladder `sect` in src/core/systems/guidance.gd, same shape as `road_goals` (rows `{text, done}`):
1. `"Report at <hall> in <home region>"` - done when `not Sects.needs_report(c)`.
2. `"Attend <lecture name>"` - done when `LifeStats.get_stat(c, "lectures_attended") >= 1`; row omitted when the sect has
   no lecture.
3. `"Finish a sect mission (board at <hall>)"` - done when the player has finished one sect mission (find the life stat or
   sect counter `Sects.do_mission` bumps; if none exists add `LifeStats.add(c, "sect_missions")` in `do_mission`, and
   count `contribution > 0` as done for older saves so veterans are never dragged back).
4. `"Rise to <rank 1 name>: <rank_needs joined>"` (plus SECT-034's trial wording) - done when `rank >= 1`.

- `static func sect_goals(c, data, flags, today := 0) -> Array[Dictionary]` ([] for rogues).
- `static func sect_goals_active(c, data, flags) -> bool`: member, `c.realm_index <= 2` (before Foundation), and any row
  not done. Never active for rogues; leaving the sect ends it.
- Order in `active_goal_ladder`: right after the first-goals check, before `foundation_goals_active` and the road ladder.
  Add `"sect"` to `goal_ladder(id, ...)` and to `goal_ladder_id` so the HUD's ladder-change detection (hud.gd ~1803) works.
- Next steps section in `Guidance` (~5860): a "Sect goals" block like "Road goals" while `sect_goals_active`; hide the road
  block while the sect block shows (as the road block already yields to foundation goals).
- `goal_target` (WU-567 focus marker): for the sect ladder, rows 1 and 3 point at `{"place": <hall display name>}` when the
  player is in the home region; otherwise `{}`.
- Journal: if journal_screen lists ladders by id, add the "Sect goals" title for `sect` (one line).

## Edge cases
- A member whose sect has no `home_region`: row 1 says "Report at the sect hall"; it is done at once if `needs_report` is
  false (old saves: missing key = reported).
- Joining at Foundation or later: never active (realm gate).
- First goals still open (Qi Refining newcomer who joined early): first goals keep the row until done, as today.
- The hints player (SECT-034) must follow every row: row 3 -> take a mission it can do (the sim already takes missions;
  check), row 4 -> nothing new (contribution comes from missions).

## Tests (tests/unit/test_sect_goals.gd)
- fresh Azure member (not reported): ladder active, first unfinished row is the report row naming the hall and Azure Peak.
- reported + lecture attended + mission done + rank 1: inactive; `active_goal_ladder` falls through to road/foundation.
- rogue: [] and inactive. Foundation member: inactive.
- old save shape (no `reported` key, contribution 50, rank 0): rows 1 and 3 done.
- `goal_ladder_id` returns "sect" while active.

## Acceptance
- Paste `first_hour_presses.gd` for the default start (Qingshi) and `quiet_stretches.gd --days=365 --hints-only` for seeds
  1-3 before/after: no stretch grows by more than 10 days. If one does, the hints player is missing a branch; fix it.
- Render `--sect-report=azure_cloud_sect` (or `--sect-join`) and open it: the HUD goal row reads the sect goal once the card
  closes (describe it in the commit).
- tools/test.sh passes. No balance check (goal wording + sim actions a member could already take).
