# GUIDE-125: Idle, thin-defence and practise hints lead with the action

## Why
QA-143's `--long-hints` tally, re-run by the planner on 8afd8bd (after GUIDE-122; 10 seeds x 12 months `--curious
--long-hints`), shows GUIDE-122 fixed the injury, gather and armor lines (only their tails are cut now). GUIDE-121
(claimed) fixes the sect and trial lines. Three other builders still put the action after the HUD's 120-character cut
(`HUD.HINT_MAX_CHARS`, WU-305; `Guidance.HEADLINE_CHARS` once GUIDE-121 lands):

```
x49 max 155  You have not cultivated in 2 months, 5 days. Spirit Spring (2x qi) would carry you to the next layer in about 3 months, 14 days.
x53 max 133  Practise Iron Fist on the Techniques screen: each level raises your odds in a fight (level 2 now, about 1 month, 9 days to level 3).
x4  max 295  Your defence is thin for Foundation foes: learn a body technique such as Stone Skin Tempering and wear armor before fighting cultivators. The Heavenforge Smithy in Fallen Star Market (10 days) sells B…
```

Same fix as GUIDE-121/122: word order, not new information.

## Files
- `src/core/systems/guidance.gd`: `idle_crafter_hint` (~line 407), `practice_hint` (~line 1907),
  `thin_defence_hint` (~line 146) and `_thin_defence_missing` (~line 197) only if you need a variant.
- `tests/unit/test_guidance.gd`: the tests that match the old text (grep `You have not cultivated`, `Your defence is thin`,
  `each level raises your odds`), plus the new tests below.
- `tests/sim/screenshot_screens.gd` ~line 1499 (`--hint-shot` needles "Your defence is thin", "You have not cultivated"):
  update needles if they no longer match.
- If `Guidance.HEADLINE_CHARS` is not on main yet (GUIDE-121), add `const HEADLINE_CHARS := 120` with the doc comment
  GUIDE-121's spec gives; if GUIDE-121 lands first, rebase onto it and use its constant.

## Changes
1. **Idle line** (`idle_crafter_hint`). When `best["rate"] > 0`:
   `"Meditate at %s: about %s to %s (you have not cultivated in %s)."` -> spot, days, `_next_step_name`, idle duration.
   For an unstamped old save (`last_meditated_day < 0`) the bracket reads `(you have not cultivated lately)`.
   When the rate is 0 keep today's bare sentence ("You have not cultivated in X." / "You have not cultivated lately.").
   Example: `Meditate at Spirit Spring (2x qi): about 3 months, 14 days to the next layer (you have not cultivated in 2
   months, 5 days).` Check `hints()` and any merge for code that finds this line by its prefix (grep `idle_crafter_hint`)
   and keep it finding the line (match on the function's result, not on text, if possible).
2. **Practise line** (`practice_hint`). Keep the prefix `"Practise %s on the Techniques screen: "` exactly
   (`_merge_practise_advice` and GUIDE-108's tests parse it). After it:
   - with `days > 0`: `"level %d in about %s (level %d now)"` (next level, duration, current level), else `"level %d now"`;
   - then the payoff as today (`"; at level %d you would beat %s about %d times in 100, now %d"`);
   - then `". Each level raises your odds in a fight."`.
   Example: `Practise Iron Fist on the Techniques screen: level 3 in about 1 month, 9 days (level 2 now). Each level raises
   your odds in a fight.` Read `_merge_practise_advice` (~line 1617) before changing anything: if it matches other parts
   of the old text (e.g. "each level raises your odds"), keep it working and keep its tests green.
3. **Thin defence line** (`thin_defence_hint`). Lead with the shop, then the body art:
   - start with `"Your defence is thin."` (keep this needle);
   - if armor is missing: append the existing shop clauses unchanged (they already start with `" The <shop> ... sells
     ... for N stones."`, local / far / loot cases); when none applies append `" Wear armor."`;
   - if the body art is missing: append `" Learn a body technique such as Stone Skin Tempering."` and then the existing
     source clause (`" <source> teaches one."` plus the sell-first clause) unchanged;
   - end with `" Foundation foes hit hard."`.
   Keep whatever the trailing `else:` branch after the body source does today (read ~line 160-195 first).
   Example: `Your defence is thin. The Heavenforge Smithy in Fallen Star Market (10 days) sells Boar Hide Jerkin for 70
   stones. Learn a body technique such as Stone Skin Tempering. ... Foundation foes hit hard.`
   `_thin_defence_missing` is also used by `empty_fair_fights_note`: leave it unchanged.

## Tests (tests/unit/test_guidance.gd)
- `test_idle_line_leads_with_spot`: GUIDE-057's idle setup with a meditation spot -> the line starts with "Meditate at ",
  the spot name ends before `HEADLINE_CHARS`, and it contains "(you have not cultivated in ". The rate-0 and old-save
  cases keep their tests (old save: contains "not cultivated lately").
- `test_practise_line_next_level_in_headline`: GUIDE-020's setup (Iron Fist level 2, days to next > 0) -> the line starts
  with "Practise Iron Fist on the Techniques screen: level 3 in about " and "(level 2 now)" ends before `HEADLINE_CHARS`.
- `test_thin_defence_shop_in_headline`: GUIDE-068/GUIDE-072's far-armor Foundation setup -> starts with "Your defence is
  thin. The ", and "stones." occurs before `HEADLINE_CHARS`; with armor equipped and no body art the line contains
  "Learn a body technique".
- Update every old assertion you broke; do not delete a test's intent.

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- `tools/godot.sh --headless --path . -s res://tests/sim/simulate_first_hour.gd -- 10 12 --curious --long-hints` no
  longer lists "You have not cultivated" or "Practise Iron Fist" keys whose cut-off holds the place or the level; paste
  the table's top 8 rows in the commit message.
- `xvfb-run -a tools/godot.sh --path . -s res://tests/sim/screenshot_screens.gd -- --hint-shot` still passes every case.
