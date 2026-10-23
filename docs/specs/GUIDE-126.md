# GUIDE-126: Spare stones buy qi pills (hint)

## Why
QA-144 (b7a9d04) measured the curious player buying qi pills with stones above a reserve (10 seeds x 12 months):
QR3 median day 252 -> 211 (-16%), QR9 718 -> 626 (-13%), Inner Disciple 5/10 -> 6/10 seeds, fights unchanged, stones at
m12 228 -> 154. That is below the 30% pacing flag, so the hint goes ahead. Today the player ends the year with 230-430
unspent stones and nothing says the Wandering Merchant in Qingshi sells 15-stone Qi Gathering Pills.

## Changes
1. `src/core/systems/cultivation.gd`: add
   `static func qi_to_bottleneck(c: CharacterData, data: GameData) -> float` = qi still needed to fill the realm up to its
   bottleneck (0.0 at the bottleneck): `qi_required(c.stage) - c.qi` plus `qi_required(s)` for every later stage of the
   realm. Make `days_to_bottleneck` use it (no behaviour change). Unit test in tests/unit/test_cultivation.gd: at QR 1st
   layer with qi 0 it equals the sum of every stage's qi_required; at the bottleneck it is 0.
2. `src/core/systems/guidance.gd`: add
   `const QI_BUY_KEEP := 20  ## Stones the qi-pill hint leaves for the clinic (GUIDE-126).`
   `static func qi_pill_offer(c: CharacterData, data: GameData, region_id: String, flags: Dictionary = {}) -> Dictionary`
   returning `{item_id, name, merchant, price, count, days}` or `{}`:
   - `{}` when `region_id` is not a region, the player is a Mortal (`c.realm_index < 1`) or at the bottleneck.
   - reserve = `next_realm_pill_price(c, data)` when `_pill_goal_applies(c, data)`, else 0;
     spare = stones - reserve - QI_BUY_KEEP; `{}` when spare <= 0.
   - room = `Cultivation.qi_to_bottleneck(c, data)`.
   - among the region's `merchant` places, the item with the most qi per stone where `effects.qi > 0`,
     `Items.feeds_cultivation(data, id)` is true (it already excludes harmful pills; check), `effects.qi <= room`, and
     `Items.merchant_sells(data, item, place.stock_tags, place.max_price)`; price = `_place_price(c, data, region_id, id, place)`.
   - count = `mini(spare / price, int(room / qi))`; `{}` when count < 1.
   - days = `maxi(1, ceili(qi / Cultivation.qi_per_day(c, data, best_qi_in_region(...).density)))` per pill (as the
     Use-your hint computes it); `{}` if the rate is 0.
3. Hint, in `_newcomer_hints` right after the "Use your ..." loop, only when that loop added nothing (a held qi item is
   used first):
   `"Buy Qi Gathering Pills with spare stones: the Wandering Merchant here sells them for 15 stones, about 11 days of meditation each."`
   i.e. `"Buy %s with spare stones: the %s here sells them for %d stones, about %s of meditation each." % [plural name
   (Items.item_plural), merchant display_name, price, Calendar.format_duration(days)]`. Keep the action within
   `HEADLINE_CHARS` (add this case to `test_hint_actions_fit_headline`).
4. Do not add it to the journal or goals; nothing else changes.

## Tests (tests/unit/test_guidance.gd)
- QR 3rd layer in qingshi_village with 200 stones: the offer names qi_gathering_pill (or whatever is best per stone
  among items that fit; assert with the data, not a literal if the data differs) and a hint starts "Buy ".
- Same with 30 stones: no offer, no hint (spare = 10 < price 15).
- QR 8th layer (last three stages, no pill held) with 320 stones: reserve 300 + 20 keeps the hint silent; with 400 stones
  it speaks and count * price <= 80.
- Holding a Qi Gathering Pill: the Use-your hint speaks, the Buy hint does not.
- At the bottleneck: no offer.
- A region with no merchant (pick one from data): no offer.
- Room: with room 500, an item with qi 7000 (Bog Lily Qi Pill, if Qingshi sells it) is not chosen.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. Paste the hint for a QR 3rd layer Qingshi player with 200 stones in the commit.
Follow-ups go in the commit message (the planner adds the help line, C-220).
