# GATHER-001: Herb lore

Role: systems. Reference: Immortal Life's gathering skill (practice makes better harvests); mirrors our FISH-003.

## Why
Gathering is the first-hour money and crafting loop (Village Herb Slope, Old Quarry Tailings, tips, weather), but the
hundredth trip is exactly as good as the first. Fishing got a skill (FISH-003); gathering should too, so daily village
life has visible progress.

## Rules (new `src/core/systems/herb_lore.gd`, `class_name HerbLore`, pure static, rng passed in)
- `CharacterData.gather_xp: int` (to_dict/from_dict, default 0; no SAVE_VERSION bump needed, like fishing_xp).
- Each `GameState.gather` trip adds `HerbLore.xp_gain(table, found)`: 1, or 2 if anything rare was found (rare = a
  non-empty table entry with weight <= 2, same rule as `Fishing.is_rare`; share the helper if it is trivial to move).
  A trip that found nothing still gives 1.
- Ranks (data, not code): a top-level `herb_lore` block in `data/regions.json` (where the gather tables live; FISH-003
  kept its constants in code, this one goes in data). Fields: `ranks` [{min, name}]
  (0 Novice, 15 Forager, 50 Herbalist, 120 Herb Sage), `xp_cap` 120, `bonus_chance_max` 0.35, `rare_mult_max` 1.5.
  Document in `_doc`, validate in `GameData._validate()` (ranks ascending, chances 0..1, mult >= 1).
- `HerbLore.bonus_chance(xp) = bonus_chance_max * min(xp, cap) / cap`: after the roll, for each found stack one extra
  unit with that chance (one rng draw per stack, drawn only when xp > 0 so seeded runs at xp 0 don't shift).
- `HerbLore.skill_table(table, xp)`: rare entries' weight x `1 + (rare_mult_max - 1) * min(xp, cap) / cap`; at xp 0 the
  table is returned unchanged (same draws as today).
- Rank-up message like fishing: "Your herb lore has improved: Forager." (progress category).
- Order inside `GameState.gather`: skill_table before `Exploration.gather`, bonus after the roll and before the weather
  herb penalty/bonus, so a storm still takes its unit.

## Surfacing (small, systems-side)
- `Guidance.village_lines` (journal Around the village): "Herb lore: Forager (32/50)" once xp > 0.
- Character sheet: `src/ui/character_sheet.gd` ~line 243 prints "Fishing: <rank> (xp)"; add "Herb lore: <rank> (xp)"
  right before it the same way (one line of UI is fine for a systems task).

## Tests (tests/unit/test_herb_lore.gd + test_game_session.gd)
- rank_name at 0/14/15/50/120/999; bonus_chance 0 at xp 0 and max at cap; skill_table unchanged at 0 and rare weight
  x1.5 at cap; xp_gain 1/2.
- GameState.gather adds xp, saves/loads `gather_xp`, posts the rank-up once, and at xp 0 yields exactly what it did
  before (seeded rng, compare with a copy of the old expectation in an existing gather test).
- Validation rejects descending ranks.

## Balance
Sims gather, so this changes numbers: run `tools/balance.sh --check`, refresh the sections it explains, and list
unexplained diffs under Follow-ups. Expected: crafter and village arms earn a little more after the first months.
