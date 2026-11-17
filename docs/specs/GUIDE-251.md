# GUIDE-251: The better pill one road away

**Role:** systems. **Reference:** Tale of Immortal's markets (mechanics only: prices differ by town, and it can pay to travel).

## Problem (QA-164 Follow-up)
`Guidance.qi_pill_offer_near` (src/core/systems/guidance.gd ~2754) returns the local offer whenever any local merchant
sells a usable qi pill, however poor its qi per stone. A far market one route away may sell a pill with far more qi per
stone, so the hint steers a saving player to the worse buy. QA-164's sim never travelled for a pill because of this.

## Build
1. In `qi_pill_offer` keep the best ratio in the returned dict: add `"qi_per_stone": float(qi) / price` (and keep
   `qi`-derived `days` as today). Callers that print the dict must not change wording.
2. `qi_pill_offer_near`: compute `here` and the nearest far offer (the existing `nearest_selling` search) both. Prefer
   the far one only when the trip pays for itself:
   - `count` pills bought far give `far_qi = count_far * qi_far`; bought here `here_qi = count_here * qi_here`
     (both limited by spare stones and bottleneck room, as today);
   - the round trip costs `2 * route_days * Cultivation.qi_per_day(c, data, <best density at home>)` of meditation qi;
   - choose far when `far_qi - trip_cost >= here_qi * 1.25` (constant `FAR_PILL_MARGIN := 1.25` with a doc comment).
   Otherwise return `here` as today. Keep the far dict shape (`region_id`, `where`).
3. Do not change `QI_BUY_KEEP`, reserves or the realm gate. No data changes.

## Tests (tests/unit/test_guidance*.gd: find the existing qi_pill_offer_near tests and extend that file)
- Local poor pill + far good pill within one route and enough spare stones -> the far offer (has `region_id`).
- Same, but too few stones for the trip to pay (small `spare`) -> the local offer.
- No local pill -> the far offer (unchanged behaviour).
- Build the cases with a test GameData fixture the existing tests use; do not rely on today's shop lists.

## Then
Re-run QA-164's arm: `simulate_curious_years.gd -- 10 36 --rogue --buy-qi --buy-qi-travel --arm-report` (the flag QA-164
added) and paste trips made, pills bought, stones spent and Foundation days next to QA-164's numbers in the commit.
This changes what the sim's buyer does, not a balance rule: no `tools/balance.sh --check` needed. tools/test.sh.
