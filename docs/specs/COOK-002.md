# COOK-002: Meals that carry you through the day

Role: systems. Reference: Immortal Life's cooking (a meal is a small buff for the day ahead, not just healing).

## Why
FISH-002 added Fish Stew and Eel Congee, but they only shorten an injury. A healthy player has no reason to fish or cook.
Follow-ups asked for a Family Home cook entry.

## What
1. `home_meals` entries may carry `buff` {name, days (1-7), mults {stat: fraction}} using the existing `Buffs` shape
   (src/core/systems/buffs.gd, `Buffs.validate_effect`); fractions capped at +0.15 per stat in validation. Document in
   recipes.json `_doc`; validate in Cooking/GameData. Eating applies it through `Buffs.add` (cooking produces the dish item;
   find where the dish is *used*: if the dish item's `effects` run through Effects, put the buff in the item's effect as a
   `buff` effect via `Buffs.add_from_effect` instead; pick whichever path the dish already uses and say so in the commit).
2. Data: Fish Stew +10% defense 3 days ("Warm belly"); Eel Congee +10% attack 3 days ("Eel's vigour"); a new **Herb Porridge**
   (spirit_herb 1 + sweet_rice_ball 1, +5% qi_gain? only if Buffs supports a non-combat key; otherwise +8% hp 3 days). Keep the
   existing `shorten_injury` on the two fish dishes.
3. Cook at the Family Home too: `family_home` place menu gets the same "Cook ..." entries as the workshop (reuse the workshop's
   option builder; GameState.cook_meal already exists).
4. The buff shows where buffs show today (character sheet / HUD buff line via `Buffs.describe`), and the dish's item
   description says what it gives (generated from the data, not hand-written, so it can't drift).

## Tests
- validation: a meal buff above +0.15 or days 0/8 is an error; a valid one passes.
- eating Fish Stew adds the buff with 3 days; `Buffs.pass_days(3)` removes it; injury shortening still works.
- Family Home menu lists the cook entries (GameState integration test in test_game_session.gd).
Sims never cook: no balance run (say so in the commit). Under ~300 lines.
