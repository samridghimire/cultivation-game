# SECT-039: The first promotion within the first season (the balance half)

Role: systems. Reference: Tale of Immortal's outer-disciple climb (mechanics only: an engaged new disciple earns their
first rank in a few months by reporting, listening, doing missions and passing one exam). Size: ~150-300 lines (data,
sim, tests); **needs `tools/balance.sh --check`** (data change) and a refreshed `sect year` section.

## Why
SECT-036 part 1 (139b270) fixed the late report (report now leads the Goal row; hints player reports on day 0 at
azure_cloud_sect and myriad_treasure_pavilion) but left the balance untouched. Its measured blockers (sect_year.gd,
seeds 1-3):
1. Contribution reaches ~250 only at day ~260-330 (4-6 missions a year). Rank-1 thresholds are 500 (Inner Disciple),
   400 (Blood Disciple), 600 (Steward): only azure seeds 2-3 meet them, at year end.
2. Trial odds when contribution is met: `azure_sword_examiner` rates 0-13 in 100; `blood_pit_gladiator` (stage 2)
   29-53 in 100 (stage 0 + attack -1 gave 29-53 too). `pavilion_vault_guard` not measured.
3. The blood_lotus hints player never reports (the sim cannot reach the Withered Bone Marsh hall).
4. 0 lectures attended in all runs, even after part 1's branch fix.

Until these move, no player sees a stipend, duty, rank perks or the WU-609 trial card in year 1.

## Do, in this order
1. **Lectures (4).** Find why the hints player never attends: is the "Lecture:" line ever the top hint for a reported
   member in the home region during a lecture month? Trace one seed (`sect_year.gd --trace` or a print in first_hour.gd
   ~2701). If Guidance never surfaces the lecture while it is open, that is a game bug: make the open lecture rank
   above routine hints (mission board, meditate) for a member in the home region (guidance.gd), with a unit test.
   If only the sim misses it (e.g. it is away on a mission), fix first_hour.gd.
2. **Blood Lotus report (3).** Find why the hints player cannot reach the marsh hall (path, region gate, hint text
   mismatch). Fix the sim; if a player would also be stuck (no hint names the way), fix Guidance too.
3. **Contribution (1).** Set rank-1 `contribution` in data/sects.json to **250** for all three start-region sects
   (keep their order: Blood Lotus a little lower is fine, e.g. azure 300 / blood 250 / pavilion 300, never below 250).
   If the sim still meets it after day 180, raise the contribution of `min_rank: 0` missions of those sects by up to
   50% (say which missions). Don't touch ranks 2+.
4. **Trials (2).** For each rank-1 trial foe, tune with `power_mult` (already used by other enemies, e.g.
   `caravan_raider` 0.6) so the hints player rates **50-85 in 100** on the day contribution is met (median of seeds
   1-3). Print the odds per seed. Keep `lethal: false`. Don't change the techniques of the foes or the player.
5. Run `sect_year.gd` seeds 1-3 before and after; paste both tables in the commit.

## Target
Every start-region sect's first promotion by **day 180 after joining in at least 2 of 3 seeds**, stipend paid in at
least 2 months of year 1, at least 1 lecture attended per seed. If a target is missed, name the remaining blocker
under `Follow-ups:`.

## Record
- DESIGN.md "Current systems" under Sects: "first promotion: ~N days for an engaged disciple" (one line).
- `tools/balance.sh --check`, then refresh `sect year` and any moved section with one sentence per moved line.

## Tests
- Guidance: a reported member in the home region during an open lecture month gets the lecture line above the mission
  board line (test_sect_goals.gd or test_guidance*.gd), if step 1 found a game bug.
- Existing sect tests read thresholds from data, not literals (fix any that hardcode 500/400/600).
- A test that each start-region sect's rank-1 trial foe has `lethal: false` and a `power_mult` <= 1.

## Acceptance
- Before/after table and per-seed trial odds in the commit; targets met or blockers named.
- `tools/balance.sh --check` run, sections refreshed.
- tools/test.sh ALL CHECKS PASSED.
