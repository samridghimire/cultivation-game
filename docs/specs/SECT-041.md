# SECT-041: Missions at a disciple's pace

Role: systems. Reference: Tale of Immortal's outer-disciple chores (mechanics only: a new disciple always has a few sect
jobs within reach, and doing them steadily is the main road to the first rank).

## Why
SECT-039 lowered rank-1 contribution to 300/250/300 and raised rank-0 mission contribution x1.5, yet the hints player's first
promotion lands on day 245-350 (azure 309/245/252, blood 262/283/262, pavilion 256/262/348). Its worker found the limit is
mission pace: 4-11 missions a year. A sect offers 6-9 rank-0 missions (data/sect_missions.json, `min_rank` 0, mortal/qi_refining),
each worth 30-195 contribution with a 15-45-day `cooldown_days`, so on paper ~30 a year are possible. Something stops them.

## Step 1: measure (tests/sim/sect_year.gd)
Add a `--mission-report` flag. For each seed (1-3) x sect (azure_cloud_sect, blood_lotus_sect, myriad_treasure_pavilion),
for every rank-0 mission the member can see, count the days in the first 365 by the reason it was NOT taken that day:
- `cooldown` (Sects/GameState cooldown still running), `loss_cooldown`, `items` (requires.items missing:
  `Sects.only_items_missing`), `odds` (fight mission rated under the sim's threshold), `realm` (min_realm/min_stage),
  `away` (player not in the hall's region), `flag` (requires_flag unset), `taken` (taken that day), `other` (the hints player
  chose another action although the mission was available).
Print one table per sect: mission id, taken count, then the reason counts. Paste the three tables in the commit.

## Step 2: fix the biggest cause (pick by the numbers, smallest change)
- `away` or `other` dominate -> guidance: for an unpromoted member whose rank-1 contribution is not met, a ready mission at
  the hall (or "Return to <hall> for missions: N ready" when away and the hall is <= 3 route days) ranks above gathering/tea
  hints. Reuse the SECT-035 goal row wording family. No data change.
- `items` dominates -> the hint names where the items come from (existing "Wanted by the sect" line, GUIDE-129), and the
  hints-player sim gathers them; if one cheap gather mission needs an item no shop near the hall sells, lower its count by 1-2.
- `cooldown` dominates (the player is ready but every mission is cooling) -> shorten rank-0 `cooldown_days` to 10-20
  for the 1-4-day missions only, never below `days` x 2.
- `odds` dominates -> leave foes alone (QA-007 territory); report it under Follow-ups instead.
Target: first promotion (hints player, seeds 1-3) by about day 180 in at least 6 of 9 runs, and no run later than day 270.
Never lower rank-1 contribution below 250 (SECT-039 floor).

## Tests
- Data validation still passes; if guidance changes: a Guidance unit test that an unpromoted member away from the hall with
  2 ready missions gets the return line, and a promoted (rank-1) or rogue player does not.
- If cooldowns change: a Sects test reads the new value from data (never hard-coded).

## Acceptance
- Commit pastes step 1's tables, the change made and why, and first-promotion days per seed x sect before/after.
- `tools/balance.sh --check` run; refresh the sect-year section (and any other section the change explains); unexplained
  diffs under Follow-ups.
