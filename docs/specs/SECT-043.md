# SECT-043: The contest, measured and fair

Reference: Tale of Immortal's sect grand competitions (mechanics only: a bracket that gets harder each round, a prize per round,
once a year). Role: systems. Size: ~250 lines.

## Why
SECT-038 landed the yearly outer-sect contest, but its Follow-ups say the foes' odds were never measured (40-90 in 100 guessed for a
4-6 month rank-0 disciple), and the reviewer found that leaving and rejoining a sect resets `sect.contest_year`, so a player can
enter twice in one year (paying only the leave penalty). The contest should feel like a ladder: the first bout winnable, the last a
stretch.

## Part 1: measure
- In `tests/sim/sect_year.gd` add `--contest-odds`. For each sect and seed, on the first day of the sect's contest month
  (`Sects.contest_def(c, data)["month"]`) in the run, print one line:
  `contest <sect> seed <n> day <d> rank <r> realm <realm name>: r1 <foe> <pct>, r2 <foe> <pct>, r3 <foe> <pct>`
  where pct = `Combat.win_chance(c, data, Sects.trial_opponent(data, foe)) * 100`, rounded. If the character can't enter
  (`Sects.check_contest` != "", e.g. rank too high), print the reason instead. Seeds 1-3, all three sects.
- Paste the table (before) in the commit message.

## Part 2: tune (data only, plus one optional field)
Targets for that first contest, median over seeds 1-3 per sect: round 1 >= 70, round 2 45-65, round 3 (when present) 20-45 in 100.
- Add an optional `power_mults` array to each sect's `contest` block in `data/sects.json` (same length as `foes`, floats in
  [0.4, 2.0], default 1.0 each). Document it in the sects.json `_doc` and validate it in `GameData._validate()`
  (length must equal `foes`, each value in range; error text names the sect).
- `Sects.contest_round` returns the mult as `power_mult` in its dict (1.0 when absent). In `GameState.enter_sect_contest`, scale
  the opponent the same way `power_mult` already scales trial foes (see how `data/enemies.json` `power_mult` is read in
  `game_data.gd` ~line 1024 and applied; reuse that helper rather than writing a new scaling formula). Do not edit the shared
  foes in enemies.json: they are used elsewhere (drunk_bully_disciple, village_boxer, caravan_raider...).
- Re-run `--contest-odds` and paste the after table. Adjust mults until the targets hold; if a target cannot be reached with
  mults in range, say so under Follow-ups rather than widening the range.

## Part 3: one entry per year, even after rejoining
- `CharacterData`: new `var last_contest_year: int = -1`, saved in `to_dict` / read in `from_dict` with default -1 (no
  SAVE_VERSION bump: the default means "never entered"; on load, if it is -1 and `sect.contest_year` exists, use that).
- `Sects.enter_contest` sets both `sect.contest_year` and `c.last_contest_year`; `check_contest` refuses when either equals the
  current year (same message: "You have already entered this year's contest.").

## Tests (tests/unit/test_sects.gd or the existing contest test file)
- `power_mults` missing -> every round's `power_mult` is 1.0; present -> returned per round.
- Validation: wrong length and out-of-range values each produce a load error.
- Enter, leave the sect, rejoin (any sect with a contest, same year) -> `check_contest` refuses; next year -> allowed.
- `last_contest_year` survives `to_dict`/`from_dict`; an old dict without it loads as -1.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. This changes balance numbers: run `tools/balance.sh --check` and refresh only sections
the change explains. Commit `[SECT-043] The contest, measured and fair` with both odds tables.
