# GUIDE-121: Sect and trial hints lead with the action (the HUD shows only 120 characters)

## Why
WU-305 (on main) cuts every HUD hint line at `HUD.HINT_MAX_CHARS` (120) and appends "… (J)". The planner's 04:10 trace
(seed 53, 12 months, `--curious --trace --seed=53`) shows the sect line is 243-346 characters long and its first 120
characters are always the same preamble, so the HUD never shows which mission to take:

```
Earn 415 more sect contribution (missions, duties) to become Inner Disciple (it pays 6 stones a month). Gather Spi… (J)
Earn 147 more sect contribution (missions, duties) to become Inner Disciple (it pays 6 stones a month). 2 sect mis… (J)
The trial for Inner Disciple is open (it pays 6 stones a month). Attempt it at the Sect Recruitment Hall here. You face… (J)
```

The fix is word order, not new information: put the actionable clause first, the rank goal last.

## Files
- `src/core/systems/guidance.gd`: `hints()` (the Earn/missions merge, ~line 105), `_sect_hint` (~line 1328),
  `_mission_hint` (~line 1458), `_trial_odds_clause` (~line 1371).
- `tests/unit/test_guidance.gd`: update the tests that match the old text (grep `more sect contribution`,
  `The trial for`, `mission is ready`, `missions are ready`, `The best pays`, `It pays`), add the tests below.
- Do not touch `src/ui/hud.gd` beyond, optionally, using the new constant (see 4).

## Changes
1. **Merge order** in `hints()`: when both an "Earn ..." line and a missions text exist, the merged line is
   `missions + " " + earn_short` (missions first). `earn_short` drops "(missions, duties) " since the missions clause
   already says how: `"Earn %d more sect contribution to become %s%s."`. With no missions text the Earn line stays as today
   (with "(missions, duties)"). Keep the merged line at the same index the Earn line had.
   The merge currently finds the Earn line with `begins_with("Earn ")`; keep finding it that way before you rewrite it.
2. **`_mission_hint` ready case** (ready > 0 and a best mission):
   - ready == 1: `"Sect mission ready: <Name> (<C> contribution, <D>) at the <Hall> here."` using `_hall_where` for the
     place part (so far halls still read "at the <Hall> in <Region> (...)"). Then, if too_dangerous > 0:
     `" <N> more <is/are> too dangerous for you yet."`.
   - ready > 1: `"The best pays <C> contribution: <Name> (<D>), one of <ready> missions ready <hall_where>."` then the same
     too-dangerous sentence. Keep the literal `"The best pays "` (QA-134's sim and WU-291 look for it).
   - When `best_mission` returns "" (should not happen with ready > 0) keep today's "<N> sect missions are ready ..." text.
   - The cooling / too-dangerous / deliver branches are unchanged (they already start with the mission name).
3. **Trial line** (`_sect_hint` when `check_promotion` passes): build it as
   `"The trial for <Rank> is open <hall_where>: you face the <Enemy> (<label>, <N> in 100)." + rest + pays_sentence`, where
   - the face part comes from `_trial_odds_clause`; split that function into `_trial_face(c, data) -> String`
     (`"you face the %s (%s, %d in 100)"`, "" when `trial_odds < 0`) and the existing advice tail
     (`" Your injuries hold you back ..."`, `" A loss only injures you ..."`, `_payoff_sentence`), unchanged;
   - `pays_sentence` is `" The rank pays <stipend>."` built from the same `_stipend_clause` data (drop the parentheses: e.g.
     `" The rank pays 6 stones a month."`), "" when there is no stipend;
   - with no face part (odds unknown) fall back to `"The trial for <Rank> is open. Attempt it <hall_where>." + pays_sentence`.
   Example: `The trial for Inner Disciple is open at the Sect Recruitment Hall here: you face the Azure Cloud Sword Examiner
   (Risky, 50 in 100). The rank pays 6 stones a month.` (the odds end at character ~118).
4. Add `const HEADLINE_CHARS := 120  ## The HUD shows this many characters of a hint (HUD.HINT_MAX_CHARS, WU-305).` to
   Guidance for tests. Optionally make `HUD.HINT_MAX_CHARS` reference it; do not change the HUD's behaviour.

## Tests (tests/unit/test_guidance.gd)
- `test_sect_line_leads_with_ready_mission`: Azure Cloud outer disciple in qingshi_village at QR 1st layer with one ready
  mission (as GUIDE-102's test sets up) -> the hint containing "Sect mission ready: " starts with it, the mission name sits
  in `line.substr(0, Guidance.HEADLINE_CHARS)`, and the line ends with "to become Inner Disciple (it pays 6 stones a
  month)." and no longer contains "(missions, duties)".
- `test_sect_line_best_pays_first`: two ready missions -> the line begins with "The best pays " and the best mission's name
  is within the first 120 characters.
- `test_sect_line_deliver_first`: the GUIDE-120 deliver case -> the deliver mission name and "you have x of y" are within the
  first 120 characters.
- `test_trial_line_odds_in_headline`: open trial (GUIDE-085's setup) -> "in 100)" occurs before index 120 and the line ends
  with "The rank pays 6 stones a month."
- A rogue or a member with no missions still gets the plain "Earn N more sect contribution (missions, duties) ..." line.
Update the existing assertions that matched the old wording; do not delete them.

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- `tools/godot.sh --headless --path . -s res://tests/sim/simulate_first_hour.gd -- 1 12 --curious --trace --seed=53`
  shows sect lines that start with the mission or "The best pays", and the trial line's odds within its first 120
  characters. Paste two such lines in the commit message.
- Nothing else in the hint list changes (injury, gather and armor lines are GUIDE-122).
- tests/sim/screenshot_screens.gd (`--hint-shot`, ~line 1575-1590) uses "The best pays" and "You face the" as needles: the
  trial line now says "you face the" (lower case) — update that needle, and run
  `xvfb-run -a tools/godot.sh --path . -s res://tests/sim/screenshot_screens.gd -- --hint-shot` to confirm every case passes.
