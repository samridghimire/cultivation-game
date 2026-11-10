# GUIDE-222: Every Next-steps line fits on one line

Role: systems (Guidance + a small HUD call change). Reference: Stardew Valley's one-line quest log entries (mechanics only).

## Why
GUIDE-220 added `Guidance.short_hint` (42 chars) for the HUD's Next steps, but planner shots 2026-11-08 12:10 still show
two-line entries on day 1 in every region but Qingshi:
- `Goal: Talk to Elder Mo in Qingshi Village (10 days)` (hud.gd ~1172 goal line + `Guidance.goal_trip_note`, not shortened)
- `Easy fight: Chore for Headman Zhou: Wild Boar (99 in 100)` (Qingshi)
- `Easy fight: Wild Boar in Withered Bone Marsh (9 days, 99 in 100)` (Fallen Star Market)
GUIDE-220's Follow-ups also name the chores, qi pill and sect lines.

## Build
1. `data/regions.json`: optional `short_name` per region (<= 14 chars). Set: Qingshi Village -> "Qingshi", Fallen Star
   Market -> "Fallen Star", Withered Bone Marsh -> "Bone Marsh", Myriad Peaks Ridge -> "the Ridge"; others keep their
   name if it is already <= 14. Document in `_doc`, validate length in `GameData._validate()`.
   `Places.short_region_name(data, id) -> String` (falls back to the display name).
2. `Guidance.short_goal(goal_line: String, data: GameData) -> String`: the HUD goal line in <= 46 chars.
   Rules in order, stop when it fits: "(N days)" -> "· Nd"; full region names -> short names; "Talk to X in R" -> "See X in R";
   finally the GUIDE-220 word-boundary cut. Example: `Goal: See Elder Mo in Qingshi · 10d` .
   hud.gd: the Next steps panel uses `short_goal`; the journal keeps the full line.
3. `short_hint` rules for fight lines: `<Easy|Fair> fight: <rest> (<travel>, <odds> in 100)` keeps the label, the foe and
   the odds as `· N%`, and drops (in this order until it fits) the chore giver ("Chore for Headman Zhou: "), the region,
   the travel days. Example: `Easy fight: Wild Boar, Bone Marsh · 99%`.
4. Sweep: write a test helper that builds the hint lists for these states and finds every short line over 42 chars;
   add short forms (rewrite rules in `short_hint`, or a `short` argument to the builder) until none are left:
   fresh mortal on day 1 in each of the six regions; a Qi Refining 3rd layer Azure Cloud disciple in Azure Peak;
   a new Alchemist in Qingshi (crafter start); a player with an injury; a player with a qi pill in the bag.
   Short forms must keep the verb and the target (what to do and where), never end in "..." or a dangling word like "the".

## Tests (tests/unit/test_guidance*.gd)
- short_goal on the three example lines above gives <= 46 chars and keeps "Elder Mo"/"Qingshi".
- fight-line rewrites for the two examples.
- the sweep: every short hint <= 42 for every listed state.
- region short_name validation (too long fails).

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. Render `--region=fallen_star_market,azure_peak,withered_bone_marsh` and the default
first-hour run; every Next steps entry is one line. Hint/wording only: no `balance.sh --check`.
