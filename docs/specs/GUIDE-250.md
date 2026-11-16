# GUIDE-250: the away fair fight, whatever home costs

Role: systems. Reference: Tale of Immortal's "next challenge" readout (mechanics only).
Hint-only change: no `tools/balance.sh --check`.

## Problem
GUIDE-249 (fixed by the reviewer in 399a34b) rates Fair explore fights one road away when the current region has no
Fair entry. The search gets only the budget left after home: `_away_explore_fights(..., FAIR_FIGHT_MAX_RATED - rated)`
in `src/core/systems/guidance.gd` (`fair_fights`, ~5467-5566). At stages where home already rated 8 candidates
(missions, chores, chores one road away, bounties, roamer, 2 explore fights) the budget is 0 and the away search finds
nothing, so the HUD still offers "Easy fight: Wild Boar 99%" while a Fair foe waits one road away (reviewer note
2026-11-16: "What's left").

## Change
1. Add `const FAIR_FIGHT_AWAY_RESERVE := 4` (doc comment: ratings the away search may always spend when home has no
   Fair entry; each rating is 40 simulated fights).
2. In `fair_fights`, call the away search whenever `region_id != "" and not _has_fair_entry(found)` (drop the
   `rated < FAIR_FIGHT_MAX_RATED` guard) with budget `maxi(FAIR_FIGHT_MAX_RATED - rated, FAIR_FIGHT_AWAY_RESERVE)`.
3. In `_away_explore_fights`, skip a foe without rating it (no budget used) when `Combat._odds_kind(c, data, foe) == "far"`
   (src/core/systems/combat.gd ~363; make it public as `Combat.odds_kind` and keep `_odds_kind` as a thin alias or update
   its callers) or when the foe's realm is below the player's realm (always Easy). Both are cheap stat checks; only the
   rest go through `Combat.win_chance`.
4. Keep every other behaviour (nearest road first, `FAIR_FIGHT_EXPLORE_MAX` kept entries, `_lift_away_fair`).

## Tests (tests/unit/test_guidance.gd or the file GUIDE-249's tests live in)
- A fresh Qingshi starter with Iron Fist and an iron sword, stages 0..8 of Qi Refining: for every stage where a brute-force
  scan (rate every eligible explore foe of every region one open route away with `Combat.win_chance`) finds a Fair foe,
  `fair_fights` returns at least one entry with `days > 0` among the first `FAIR_FIGHTS_MAX`. Assert the scan finds at
  least one such stage, so the test can't pass vacuously.
- Budget: with home candidates stubbed to use the whole `FAIR_FIGHT_MAX_RATED` (give the player open chores/bounties, or
  call the helper directly with budget computed as in step 2), the away search still rates up to the reserve.
- Timing guard: one `fair_fights` call at stage 3 stays under the existing hint-refresh budget if a timing test exists
  (grep `usec` in tests/unit/test_guidance*.gd); otherwise note the measured msec in the commit.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Commit lists, for stages 0..8, the HUD fight line before and after.
