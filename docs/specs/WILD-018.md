# WILD-018: Beasts for a Foundation cultivator

Role: systems. Reference: Tale of Immortal's region danger tiers (a region's wildlife steps up with your realm), mechanics only.

## Why
Planner shots 2026-11-06 06:10 (`screenshot_first_hour.gd -- --great --region=azure_peak,misty_forest`, a Foundation Early
player): the Misty Forest shows only Mist Foxes "(Weak)" and the HUD's best fight is "Wild Boar roams here (Weak, 100 in 100)".
C-308 gave encounters `max_realm` and Foundation twins, but roamers have only `min_realm`, so a Foundation player still walks
through a map of Qi Refining beasts. QA-196 Follow-up: the combat sim rates the four return beasts at their parent's
`min_realm` (Mortal for three), so "typical odds: broken_crown_crane 100%" is wrong.

## Spec
1. **`max_realm` on a roamer entry.** data/regions.json `roamers.enemies[]` entries take optional `max_realm` (realm id):
   the entry is skipped when `realm_index > realm_index_of(max_realm)`, exactly like `min_realm` in
   `Wildlife.roamers` (src/core/systems/wildlife.gd ~29). Validate in GameData (known realm id, not below the entry's
   `min_realm`). Document in regions.json `_doc` next to the roamers `min_realm` text.
2. **Empty-pool fallback.** If every entry is filtered out for a region, `roamers` returns [] (as today); no crash in the
   world builder, fair_fights or the bounty roamer (`bounty_roamer`): add a unit test with a region whose only entry has
   `max_realm: "mortal"` and a Qi Refining character.
3. **Return beast realm.** `roamers.great.return` takes optional `min_realm` (realm id). When the return slot is active
   (`_great_walks` / `active_great_enemy` path), that `min_realm` gates it instead of the parent's; absent = the parent's
   (old data unchanged). Validate. tests/sim/combat_balance.gd's usage scan (QA-196) rates a return beast at its own
   `min_realm` when set. Data: give the four return beasts (`scarred_old_tusker`, `old_bog_king_toad`,
   `broken_crown_crane`, `cracked_horn_ram`) a `min_realm` that matches their enemies.json realm (read each enemy's
   `realm`/stats; e.g. a beast built for Qi Refining gets `qi_refining`).
4. **Data (small, so the field is used):** in misty_forest and azure_peak roamers, set `max_realm: "qi_refining"` on the
   weakest beasts (wild_boar, mist_fox in misty_forest; the weakest one or two at azure_peak) and add one Foundation entry per
   region from enemies that C-308 already made (e.g. Mist-Shrouded Leopard / Grey-Fang Alpha in misty_forest, Moon-Ridge Elk
   at azure_peak) with `min_realm: "foundation_establishment"`, only if the enemy has the `beast` tag and is not lethal
   (roamer validation). C-312 does the rest of the regions.
5. Save format: none (all data-derived).

## Tests (tests/unit/test_wildlife.gd or the existing roamer test file)
- An entry with `max_realm: qi_refining` appears for a Qi Refining character and not for a Foundation one (same region/day).
- GameData rejects an unknown `max_realm` and a `max_realm` below `min_realm`.
- A return beast with its own `min_realm` walks for a character at that realm even if the parent's `min_realm` is higher,
  and not below it.
- Integration (test_game_session.gd style): a Foundation player in misty_forest gets no wild_boar / mist_fox in
  `Wildlife.roamers` across 14 days.

## Acceptance
- `tools/test.sh` ALL CHECKS PASSED.
- This changes what the sims meet: run `tools/balance.sh --check` and refresh the combat and foundation-year sections; in the
  commit, give the foundation-year rated-odds histogram before/after (`simulate_foundation_year` 6 seeds, `--threats=fight`,
  as C-308 did) and the corrected return-beast rows.
