# GUIDE-252: No hitch on the first HUD refresh

**Role:** systems. **Reference:** none (performance, Steam Deck readiness).

## Problem (QA-226 Follow-up)
`Guidance.fair_fights` (src/core/systems/guidance.gd ~5477) for a Foundation stage-3 player in Qingshi takes 160-210 ms
on a cold `Combat.win_chance` cache (warm: 4-6 ms). The first Next-steps refresh after loading a save or entering a
region therefore hitches for a frame of ~0.2 s, worse on a Deck. Budget: <= 30 ms cold.

## Build
1. Measure first: add `tests/sim/profile_fair_fights.gd` (headless; like tests/sim/profile_days.gd) printing cold and warm
   ms and `Combat` simulation counts (`win_chance`'s sim counter, see combat.gd ~435) for: a fresh mortal in Qingshi, a
   Qi Refining 5 in Misty Forest, a Foundation 3 in Qingshi and in Azure Peak. Paste the table in the commit.
2. Cut the cold cost, in this order, stopping when every case is <= 30 ms:
   a. Rate cheapest-first and stop early: `FAIR_FIGHT_MAX_RATED` (8) rates every candidate; skip foes whose realm gap
      alone decides the band (two or more major realms below or above: rate them by `Combat.odds_kind` shortcuts, no sim),
      using the same rule `Combat.rate` already uses for "well below you" (combat.gd ~394) if one exists.
   b. A smaller cold sample count for hint-only ratings: pass `samples` (e.g. 24 instead of `RATING_SAMPLES`) to
      `win_chance` from `_rate_fight` when the call comes from fair_fights, and keep the full count for the threat prompt
      and menus (the numbers a player reads as "N in 100"). The hint only needs the band.
   c. If still over: memoise `fair_fights` per (fight fingerprint, region, day) in a static dict cleared on a new session.
3. Do not change which fights are found for the existing tests' fixtures; any change in the chosen band must be explained.

## Tests
- Existing fair_fights tests still pass unchanged.
- New: a Foundation-3 fixture runs `fair_fights` with a cleared cache and asserts the `win_chance` simulation counter
  stays under a bound (pick it from your measurement, e.g. 40% of today's count). Counters, not wall-clock, so CI is stable.

## Acceptance
The profile table before/after in the commit, every case <= 30 ms cold on the container. tools/test.sh. No balance
check needed (no rule numbers change; ratings for display keep the full sample count).
