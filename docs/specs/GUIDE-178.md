# GUIDE-178: Alchemy orders prefer ingredients from your own region

**Why (C-244 audit, seed-89 trace).** A Qingshi Alchemist gets orders for Bone-Setting Salves and Spirit Gathering Pills
that lapse: `qi_condensing_grass` and `purple_cloud_mushroom` grow only in Misty Forest (one route away, rare), and
`Commissions.roll` (src/core/systems/commissions.gd ~31) treats "one route away" as near enough, then `max_count` still
asks for 2-3.

## Code
1. `Guidance.available_nearby(c, data, item_id, region_id, today := -1, local_only := false)` and
   `Guidance.merchant_sells_nearby(data, item_id, region_id, local_only := false)` (guidance.gd ~1182/1190): with
   `local_only`, only `region_id` itself counts (gather places there, merchants there). Check what `_gatherable_items`
   covers (region only, or neighbours too) and make `local_only` mean the region alone in both halves. Defaults keep
   today's behaviour for every existing caller.
2. `Commissions._ingredients_near(c, data, recipe, region_id, today, local_only := false)` passes it through.
3. In `Commissions.roll`, when `region_id != ""`: build `local` (every short ingredient held, `spirit_stone`, or
   available with `local_only = true`) and `near` (today's test). Use `local` when not empty; else `near` when not empty,
   and then the order's count is 1; else all options (today's fallback, count as today).
   Keep the rng calls in the same order and number (one `randi_range` for the recipe, one for the count; clamp the count
   after rolling) so only the order contents change, not the rest of the rng stream.
4. No change to `max_count`, rewards, due days or `due_soon_hint`.

## Tests (tests/unit/test_commissions.gd)
- Qingshi Alchemist (rank 1) knowing `qi_gathering_pill` and `bone_setting_salve`: 40 rolls on fresh orders with
  `seeded_rng()` -> every order is `qi_gathering_pill`.
- Knowing only `bone_setting_salve` and `spirit_gathering_pill` in qingshi_village -> every order has count 1.
- The same character in misty_forest knowing `bone_setting_salve` -> count may exceed 1 (assert the rule's max is
  reachable over the rolls, or that it equals `min(rolled, max_count)` as today).
- `available_nearby(..., local_only = true)` for `qi_condensing_grass` from qingshi_village is false, from misty_forest true.

## Acceptance
ALL CHECKS PASSED. Run `tools/balance.sh --check` and refresh the sections this explains (crafter/curious sections with
alchemists). In the commit, paste the count of "lapsed" order lines in `simulate_curious_years.gd -- 1 36 --trace=89 --rogue`
before/after (C-244 saw two by m15).
