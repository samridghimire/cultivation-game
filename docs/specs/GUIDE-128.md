# GUIDE-128: The Gather line leads with the trip when a far spot is much faster

## Why
Planner trace 2026-10-23 08:10 (seed 61, `-- 1 12 --curious --trace --seed=61`): at Foundation Early in Qingshi the line is
"Gather 18628 more qi to reach the next stage: about 4 months, 13 days at Spirit Spring (2x qi) here, 1 month, 24 days at
Cloud-Sea Cliff (2x qi) in Azure Peak (10 days away)." The HUD cap (120 chars) cuts it before Azure Peak (QA-143 tally:
x20 + x3 + x2 lines cut at "...Cloud-Sea Cliff (2x qi) in Azure Peak (10 days away)."), so the one reason to leave Qingshi
never shows. The player never leaves Qingshi in any of the last six traces.

## Changes (src/core/systems/guidance.gd)
1. Extract the far-spot computation from `_merge_better_qi` into
   `static func far_qi_offer(c: CharacterData, data: GameData, region_id: String, flags: Dictionary = {}) -> Dictionary`
   returning `{region, region_name, place, away, days_far, days_here}` or `{}`, with today's rule (`days_base - days_best >
   2 * away`, `days_base` = days at the best spot here, or where you stand when there is none). `_merge_better_qi` calls it,
   so its output is unchanged except for step 2. WU-321 and WU-323 reuse it.
2. When the offer saves at least `FAR_QI_LEAD_DAYS := 30` days net of the round trip
   (`days_here_best - days_far - 2 * away >= 30`), the Gather line becomes
   `"Travel to Azure Peak (10 days): Cloud-Sea Cliff gathers the <step> in about 1 month, 24 days, against 4 months, 13 days at Spirit Spring here."`
   - `<step>` = `_next_step_name(c, data, "next stage")` style wording the line uses today ("next stage", "next layer",
     "Foundation Establishment breakthrough"); reuse what the Gather line already says after "to reach ".
   - Use `GameData.plain_name()` for both place names (drops "(2x qi)", which is misleading anyway: Cloud-Sea Cliff is 5x
     Qingshi's qi; C-219 fixes the labels).
   - When there is no better spot here, the tail is ", against <T> where you stand."
   - Below 30 days saved, keep today's text exactly.
3. The Travel line keeps its position in `hints()` (where the Gather line was). `hinted_region()` must still find the
   region (it looks for region names; check that "Travel to Azure Peak" resolves to azure_peak so the road marker WU-283
   and map mark WU-316 follow it; add a test).

## Tests (tests/unit/test_guidance.gd)
- Foundation Early, qi 0, in qingshi_village, rogue: a hint starts "Travel to Azure Peak (" and its first 120 chars contain
  "Cloud-Sea Cliff" and "in about".
- `hinted_region(data, that_line, "qingshi_village") == "azure_peak"`.
- QR 1st layer in qingshi_village (stage needs few days): the line is today's "Gather ..." text (update nothing).
- Standing in azure_peak: no Travel line.
- Add the Foundation case to `test_hint_actions_fit_headline`.
- Existing tests at lines ~373 and ~3763 that match " at Cloud-Sea Cliff (2x qi) in Azure Peak": update only the ones the
  new rule changes, and say which in the commit.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Paste the Foundation line before/after in the commit.
