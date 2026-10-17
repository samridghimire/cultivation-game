# PROF-012: an order's count fits the time it takes to gather it

**Why (QA-107):** a Qingshi Blacksmith gets orders for 2-3 Iron Swords, but Iron Essence is 1 of 21.5 weight at the
Village Herb Slope (about one essence per ~20 gather days), so a count-3 order cannot be filled in its 60 days and lapses.
13 of 17 blacksmith orders lapsed in the sim. Orders should never ask for more than a crafter can gather in time.

## Changes
1. `src/core/systems/exploration.gd`: add
   ```gdscript
   ## Expected units of `item_id` per gather day at the best gather place in `region_id` for `c`
   ## (PROF-012): GATHER_ROLLS rolls per gather, each hitting an entry by weight, (min+max)/2 units,
   ## divided by the place's gather_days. Seasonal entries count only in `season` ("" = all year).
   ## 0.0 when no gather place there yields it.
   static func gather_rate(c: CharacterData, data: GameData, item_id: String, region_id: String, season: String = "") -> float
   ```
   Use `gather_table_for(c, data, table, season)` (it already drops out-of-season entries and turns realm-locked ones
   into nothing). Ignore Fortune's extra rolls (use `GATHER_ROLLS`), so the cap is conservative.
2. `src/core/systems/commissions.gd`:
   - add `static func max_count(c, data, recipe: Dictionary, region_id: String, today: int, days: int) -> int`:
     returns a large number (e.g. 999) when `region_id == ""`. Otherwise, for each ingredient other than `spirit_stone`
     that the pack does not already cover for one craft: if a merchant near `region_id` sells it
     (use `Guidance.available_nearby` with the gather part failing, or simply: if `Guidance.available_nearby` is true and
     `Exploration.gather_rate(...) == 0.0`, treat it as bought: no cap), skip it; else
     `units_per_output = float(ing_count) / float(recipe.output.count)` and
     `fit = floori(rate * days * FILL_SHARE / units_per_output)` with `const FILL_SHARE := 0.5` (half the window spent
     gathering). Return the minimum `fit` over ingredients, but never below 1.
     Use the season of `today` (`Calendar.season_of(today)`) for the rate.
   - in `roll`: after picking the recipe and rolling `count`, `count = mini(count, max_count(c, data, recipe, region_id, today, int(r["days"])))`.
     Roll `count` with the rng exactly as today (same number of rng calls), so other seeded tests keep their results.
   - Update `roll`'s doc comment.
3. No data or save changes.

## Tests (tests/unit/test_commissions.gd)
- `gather_rate`: Qingshi `spirit_herb` > 0 and larger in spring than winter (it has a spring entry); `iron_essence` in
  Qingshi equals 3 * 1/21.5 / 3 (compute from the real table in the test, not a literal); an item no Qingshi place
  yields gives 0.0.
- A Qingshi Blacksmith whose only known recipe is iron_sword (output 1, 1+ iron essence): with a seeded rng that
  rolls count 3 without the cap, the order's count is now <= `max_count` and >= 1 (assert both), and its `reward` is
  computed from the capped count.
- A Qingshi Alchemist's qi_gathering_pill order is not capped (max_count >= 3).
- `region_id == ""` keeps today's behaviour (no cap).

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- Run `tools/godot.sh --headless --path . -s res://tests/sim/crafter_start.gd -- 10 180 --orders` before and after and
  paste the blacksmith rows' delivered/lapsed counts in the commit (expect fewer lapses; if C-151 has landed the rate
  will already be higher).
