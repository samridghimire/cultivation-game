# SECT-034: The new disciple's first days, told plainly

Role: systems. Reference: Tale of Immortal's sect panel and new-disciple flow (mechanics only: every sect screen says
exactly what the next rank asks and what a rank gives). Size: ~250 lines with tests. Hint/wording change: no
`tools/balance.sh --check` (the sim part only adds actions a member already could take; paste the numbers asked below).

Planner shot 2026-11-23 sect_promote.png: "Promoted: Outer Disciple / Your standing in the sect rises / Next rank: a trial
awaits". The card names no perks (the rank has a stipend/duty, but `promotion_summary.perks_new` only lists treasury
unlocks) and no trial foe (`rank_needs` skips trials, so the WU-603 card falls back to "a trial awaits").

## 1. promotion_summary says what the rank gives and what the next asks (src/core/systems/sects.gd)
- `promotion_summary(c, data)`: `perks_new` = the `perks` of the current rank's row from `ladder(c, data)` (stipend,
  duty, treasury unlocks, same wording SECT-033 already builds). Keep the key names; rank 0 keeps an empty list.
- `next_needs`: `", ".join(rank_needs(c, data))`, then, when `needs_trial(c, data)`, append
  `"win a trial against <enemy name>"` (enemy `name` from data.enemies[trial_enemy(c, data)]). If both are empty
  and a next rank exists, leave it "" (the card keeps its fallback). Do not change `rank_needs` itself (many hints use it).
- Check `src/ui/sect_card.gd` `open_promotion` still reads well with the longer line (it wraps; no UI change expected).

## 2. The lecture is open all month, so say so
The lecture can be attended any day of the month once (`check_lecture`). SECT-033's `month_status["lecture"]` says
"<name> today" and `Guidance.hall_services` says "Lecture: <name>, today", which reads as "only today".
- Both now say `"<name>: open this month (<N>d left)"` while unattended, where N = days to the month's end
  (use GameClock's month length via the same helper `duty_days_left` uses; add a small static helper in Sects if needed:
  `Sects.days_left_in_month(total_days) -> int`), "attended" once attended this month (month_status) and
  `"<name>: next month"` (hall_services) as now.
- Update the tests in test_sect_status.gd / test_sect_report.gd that pin the old text.

## 3. The report hint leads Next steps
Reviewer note (2026-11-22): `report_hint` is appended after the due-commission line, not first as SECT-032 asked.
In `Guidance.hints` (find where `report_hint` is added) insert it at index 0 of the hint list (after urgent lifespan /
injury lines, which stay first). Test: a member with `reported: false` and a due commission gets the report line first.

## 4. "ask Qiu" keeps the title
`Guidance` ~948 (GUIDE-267) shrinks a chore giver from the full name straight to its last word ("Hall Steward Qiu" ->
"Qiu"), so at Azure Peak the HUD said "Easy fight: Stair Crag Goat (ask Qiu)" with no Qiu in sight. Make the `asks`
list drop leading words one at a time ("Hall Steward Qiu" -> "Steward Qiu" -> "Qiu") before the place clauses.
Test: with a short width the line reads "(ask Steward Qiu)" when it fits and "(ask Qiu)" only when that does not.

## 5. The hints player reports and listens (tests/sim)
SECT-032 Follow-up: the hints player (tests/sim/first_hour.gd, and quiet_stretches.gd if it has its own copy) has no
branch for the report hint. Add: on a line starting "Report at the" -> if in the sect's home region call
`GameState.report_to_sect()` (or the session helper the sim uses), else travel there (reuse the sim's existing
"walk to region" branch). Also: once per month, when a member stands in their home region and
`Sects.check_lecture(...) == ""`, attend the lecture (`attend_lecture`). Paste in the commit for 3 seeds of
`first_hour.gd` with the Azure sect start the sim already supports (or `--sect=azure_cloud_sect` if a flag exists):
day reported, lectures attended in year 1, and day of first promotion, before/after.

## 6. Small doc fix
GUIDE-286 reviewer note: `_entry_choice_open`'s doc says entry nodes count, but the code only accepts nodes linked from
another node. Make the doc match the code (one line).

## Tests (tests/unit/test_sect_status.gd unless noted)
- promotion to a rank with a stipend lists the stipend in `perks_new`; a rank gated by a trial gives
  `next_needs` containing "win a trial against <name>"; top rank -> "".
- month_status lecture: unattended on day 3 of a 30-day month -> ": open this month (27d left)" (match your helper);
  attended -> "attended".
- hall_services lecture row wording (test_sect_report.gd).
- report hint first (test_sect_report.gd).
- "(ask Steward Qiu)" shrink (the GUIDE-267 test file; grep `GUIDE-267` in tests/unit).

## Acceptance
- `--sect-promote` shot (render it at 1280x800 and open it): the card lists the new rank's stipend/duty and
  "Next rank: ... win a trial against <foe>".
- tools/test.sh passes.
