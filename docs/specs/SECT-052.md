# SECT-052: Outer and inner contest records kept apart

Reference: Tale of Immortal's sect tournaments by tier (mechanics only).

## Why (reviewer note 2026-11-26)
SECT-045 added an inner-sect contest for rank 2+, but `CharacterData.last_contest_year`, `sect["contest_year"]` and
`CharacterData.contest_record` are shared by both contests:
- `Sects.contest_check` (src/core/systems/sects.gd ~871) says "already entered" for the inner contest if the player entered the
  outer contest earlier the same year and was promoted since.
- `contest_record_line` counts "of M" rounds from the current rank's contest but `best_round` from whichever was entered.
- `contest_win_line` says "Won the <sect> contest" for an inner win.

## Change
1. Contest kind: `static func contest_kind(c, data) -> String` returns "inner" when `is_inner_contest(c, data)`, else "outer".
2. Entry per kind: replace the year checks with `c.contest_years: Dictionary` (`{"outer": year, "inner": year}`, default {}).
   `enter_contest(c, data, total_days)` writes `c.contest_years[kind]`; keep writing `sect["contest_year"]` and
   `last_contest_year` for "outer" only so nothing else breaks. `contest_check`'s already_entered uses the current kind's year.
   (Grep all callers of `enter_contest` and add the `data` argument.)
3. Record per kind: `c.contest_record` becomes `{"outer": {best_round, last_year, sect}, "inner": {...}}`.
   `record_contest(c, data, rounds_won, rounds, total_days)` writes the current kind. `contest_record(c, kind := "")` reads
   the given kind (current kind when "" needs data: add `data` param). `contest_record_line` shows the current kind's record
   ("Inner-sect contest record: ..." for inner). `contest_win_line` names the latest full win across kinds:
   "Won the <sect> inner-sect contest in year N" for inner. LifeStats `contest_wins` / `contest_rounds_won` stay totals.
4. Save: in `CharacterData.from_dict`, an old flat `contest_record` (has "best_round" at the top level) becomes
   `{"outer": <old>}`; `contest_years` defaults to `{"outer": last_contest_year}` when absent and last_contest_year >= 0.
   Bump `SaveManager.SAVE_VERSION`, add a migration note, and add a fixture save of the new version to
   tests/fixtures/saves/ (CLAUDE.md rule 5).
5. UI callers (journal Sect page, hall overview, champion card) keep using the same functions; fix their call signatures only.

## Tests (tests/unit/test_sects*.gd, test_save_fixtures.gd)
- Enter the outer contest in month M, get promoted to rank 2, the inner contest in its month of the same year is open.
- Entering the inner contest twice in one year is refused; the outer record is unchanged by an inner contest.
- `contest_record_line` for a rank-2 player with only an outer record returns "" (nothing entered at this tier).
- `contest_win_line` names the inner contest after an inner full win.
- from_dict of an old flat record keeps best_round/last_year under "outer"; the fixture loads.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED; no balance numbers change (no balance check needed). Under ~250 lines.
