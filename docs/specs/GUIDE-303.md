# GUIDE-303: Home while the season calls

Role: systems. Reference: Stardew Valley's season bundles and the letters that pull you back to town (mechanics only).
Hint ranking + sim policy; no balance values change, so no `tools/balance.sh --check`.

## Why
SIM-040 (ada70c0) made `home_call_hint` fire for a sect disciple (max_route_days 12) and taught the hints sim to act on
"Home to Qingshi (". But in `--firsts 6 12` the line sits 5th-6th in Next steps, below the lend/tea/trial lines, and the
sim's first-actionable-line policy takes those every week: first trip home 1/6 seeds (day 354), first congratulation and
first full season set still never. GUIDE-301 (7ec72e6) added a "Goal: Qi Refining Nth Layer in about N days at <place>
(xD)" line for the dead second half-year, but the sim does not act on it.

## Changes
1. **Ranking** (`src/core/systems/guidance.gd`, `hints()` ~1097-1215). Today `home_call` is appended in the GUIDE-294
   friends block. Move it so that, **when `home_call_hint` returns a line**, it sits directly after the sect block
   (after `lecture_here`, the thin-defence and method-offer lines) and **above every lend-a-hand, tea, congratulate,
   friend-meditation and trial/pointer line** (find where the "Tea at <name>'s" (~709) and "Help <name> with" (~4737)
   lines are inserted and make sure home_call precedes them; if they are added before line ~1179 by an earlier block, insert
   home_call before that block instead). It stays below breakthrough, urgent due commissions, duty and lecture-here lines.
   `home_call_hint` already only fires while the season window is open and tasks remain, so no new gate is needed.
2. **Sim acts on the stage goal** (`tests/sim/first_hour.gd`, `_act_on_hint` ~2534). Add a branch for lines starting
   `"Goal: "` that match `stage_goal_hint`'s format (copy the exact prefix from `Guidance.stage_goal_hint` ~2032; build a
   helper that parses the place name): if the named place is in another region, travel there (`gs.travel`), meditate there
   in 7-day blocks until the stage changes or 30 days pass, then return to the sect home region if the player is a member.
   If the place is in this region, just meditate. Log the action in the `--firsts-trace` output like the other branches.
3. Keep the GUIDE-301 line out of the first two Next-steps rows while a lecture line leads (GUIDE-297's rule); add a test
   only if your move changes that.

## Tests (tests/unit/test_guidance*.gd, whichever holds home_call tests)
- Season window open, open catch task, a tea-ready friend and a lend-a-hand offer: `hints()` lists "Home to Qingshi (" before
  both the "Tea at" and the "Help" lines.
- Same setup with an open breakthrough line: the breakthrough line still comes first.
- Season window closed: no home line, tea/lend order unchanged (regression).

## Measure
Run `--firsts 6 12` (simulate_first_hour.gd, see SIM-040's commit for the command) before and after on the same main and paste
the rows for first trip home, first congratulation, first full season set, first stage up after day 180, and the five longest
dead stretches. Target: first trip home in >= 4/6 seeds before day 200; dead stretches after day 200 shorter in >= 3/6 seeds.
If missed, say which line the sim took instead under `Follow-ups:`.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; the before/after table is in the commit message; under ~250 changed lines.
