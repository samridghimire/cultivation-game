# ITEM-003: Realm-gated pills (Cloud-Mist and Earth Marrow)

**Why.** QA-158/QA-161 traces: at Qi Refining 8th Layer the top hint is "Buy Cloud-Mist Qi Pills ... 198 stones, about
1 year, 3 months and 8 days of meditation each". `cloud_mist_qi_pill` (data/items.json ~223: qi 5000, price 220) says it
"pours a season of cultivation into a **Foundation** cultivator's dantian", and `earth_marrow_essence_pill` (qi 40000)
"feeds a **formed core**". Nothing enforces either, so a Qi Refining player buys more than a year of cultivation for
~200 stones. This task makes the item text true. It is not a pacing retune (F-005d stays open): it only stops two pills
working below the realm they were written for.

## Data
- data/items.json: new optional field on usable items, `min_realm` (realm id). Below that realm the item cannot be used.
  Document it in the file's `_doc` ("min_realm (optional realm id, usable items only): below it Items.use refuses").
- Set `"min_realm": "foundation_establishment"` on `cloud_mist_qi_pill` and `"min_realm": "core_formation"` on
  `earth_marrow_essence_pill`. Touch no other item (C-252 audits the rest).

## Code
1. `Items.realm_block(c: CharacterData, data: GameData, item_id: String) -> String` in src/core/systems/items.gd:
   "" when the item has no `min_realm` or `c.realm_index >= data.realm_index_of(min_realm)`, else
   "Only a cultivator of the <Realm name> realm can draw on the <item name>." (same shape as
   `Clans.check_found`'s realm reason).
2. `Items.use`: after the "You have none left." check, return `{ok: false, reason: realm_block(...)}` when it is not "".
   The pill is not consumed. Crafting, buying and selling stay allowed (an alchemist can still sell them).
3. `Guidance.qi_pill_offer` (guidance.gd ~1478): skip items whose `realm_block` is not "".
   Also the "Use your <item> (Inventory, I)" hint (~2637): skip held items whose `realm_block` is not "".
   Grep `feeds_cultivation(` and `"qi", 0` in src/core for any other place that recommends using a qi item, and apply
   the same skip there (list them in the commit).
4. `GameData._validate()`: `min_realm`, when present, must be a String naming a realm in data/realms.json, and only on an
   item with `usable: true` (error text like the other item checks).

## Tests
- tests/unit/test_items.gd: a QR8 character holding a Cloud-Mist pill -> `Items.use` fails with the realm reason and the
  count is unchanged; the same character at Foundation Early -> ok, qi rose. Earth Marrow at Foundation -> refused.
- tests/unit/test_guidance.gd: a QR8 character with ~1500 stones in a region whose merchant sells Cloud-Mist (find it:
  `Items.merchant_sells` over data/regions.json merchants; seed-89 saw it offered in qingshi_village) -> `qi_pill_offer`
  never returns `cloud_mist_qi_pill`; at Foundation Early with the same stones it may (assert whichever pill the data
  picks, and that Cloud-Mist is eligible).
- A GameData validation test: `min_realm: "nope"` is rejected; `min_realm` on a non-usable item is rejected.
- Grep tests and `--hint-shot` cases for "Cloud-Mist" and update assertions that pinned it at Qi Refining.

## Acceptance
- ALL CHECKS PASSED.
- `tools/balance.sh --check`: refresh only sections whose diff this explains (curious/buy-qi/qi-pill sections). Paste in
  the commit `simulate_curious_years.gd -- 10 36 --rogue --buy-qi --arm-report` Foundation-by-m36 and median day before/after.
