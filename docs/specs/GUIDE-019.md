# GUIDE-019: Your first fighting style

**Role:** systems. **Size:** ~150 lines + tests.

## Why
QA-060 and C-068 found the same root cause behind two problems: the curious player knows **no combat technique**.
Bare, they win 0% against a Mist Wolf at Qi Refining stage 1, while a "typical" player (Iron Fist + Stone Skin + gear)
wins 81-99% (C-068's Follow-up). Pointers also refuse with "no technique they could correct" (QA-060).

The game does sell the cure: `Manual: Iron Fist` (15 stones, no tags) is stocked by Qingshi's untagged
**Wandering Merchant**. But the hints hide it:
- `Guidance._newcomer_hints` (src/core/systems/guidance.gd ~594-619) shows the generic `TECHNIQUE_HINT` ("Learn a
  technique from a manual. Merchants sell them.") only while `c.techniques.is_empty()`, and prefers the Elder Mo breathing
  line. Once Elder Mo teaches `basic_breathing` (kind "cultivation"), `c.techniques` is not empty and the hint is gone
  for good, though the player still has no way to fight.
- `Guidance.hints` (~73) shows `TECHNIQUE_HINT` only above Qi Refining with no techniques at all.
- `Combat.loss_advice` (src/core/systems/combat.gd ~323) never says "you know no fighting style".

## Changes

### 1. `Guidance.first_combat_manual(c, data, region_id) -> Dictionary`
New public static function in guidance.gd. Returns `{}` when the player knows any technique whose `kind == "combat"`.
Otherwise returns the cheapest combat-technique manual the player can learn (technique `min_realm` index <= `c.realm_index`)
that a **merchant in `region_id`** sells:
- walk `data.regions[region_id]["places"]` with `type == "merchant"`, skip merchants whose alignment bounds
  (`min_alignment`/`max_alignment` place keys, if present) exclude `c.alignment`;
- for each combat `TechniqueDef` with a non-empty `manual_item`, check
  `Items.merchant_sells(data, data.items[manual_item], place.get("stock_tags", []), int(place.get("max_price", 0)))`;
- pick the lowest `Items.buy_price`/item `price` (use whatever price helper `ShopScreen.unit_price` uses underneath, without
  reputation/renown), tie-break by item id.
- Return `{"item": item_id, "technique": tech_id, "merchant": place display_name, "price": int}`.
If nothing in this region sells one, return `{"item": ..., "technique": ..., "merchant": "", "price": ..., "source": Items.sources(data, item_id)[0]}`
for the cheapest combat manual with any known source (still learnable at the player's realm); `{}` if none at all.
Unknown `region_id` (e.g. "" in tests) = skip the region scan and go straight to the any-source fallback.

### 2. A hint that survives the breathing technique
- Add `static func first_combat_hint(c, data, region_id) -> String` built on (1):
  - merchant here: `"You know no fighting style. %s at the %s teaches %s for %d spirit stones."` (manual name, merchant
    display name, technique name, price);
  - elsewhere: `"You know no fighting style. Look for the %s (%s)."` (manual name, source);
  - `""` when (1) returns `{}`.
- In `_newcomer_hints`: keep the Elder Mo breathing line as it is. Replace the `TECHNIQUE_HINT` fallback at ~619 with
  `first_combat_hint` whenever it is non-empty (independently of `technique_done` / `breathing`), placed right after the
  Elder Mo line so it stays in the HUD's top hints (check `hints()` `limit` handling: it must survive the default limit 5
  for a fresh Qi Refining 1st Layer character in Qingshi; adjust ordering, not the limit).
- In `hints()` ~73: replace the `c.techniques.is_empty() and c.realm_index > NEWCOMER_MAX_REALM` branch with the same
  `first_combat_hint` when non-empty (pass `region_id`). Keep `TECHNIQUE_HINT` as the text when the helper returns ""
  but `c.techniques.is_empty()` (should be unreachable with today's data; keeps old behaviour).
- Grep tests for `TECHNIQUE_HINT` / "Learn a technique from a manual" and update the ones that change.

### 3. Loss advice
`Combat.loss_advice`: when the player knows no `kind == "combat"` technique, append
`" You know no fighting style yet; a technique manual would help."` (after the main advice, before the talisman note).
Keep it data-free (Combat must not call Guidance).

## Tests (tests/unit/test_guidance.gd, test_combat.gd)
- A fresh Qi Refining 1st Layer character in `qingshi_village`: `first_combat_manual` returns the Wandering Merchant and
  `manual_iron_fist` (read the expected cheapest combat manual from data in the test rather than hard-coding if another
  cheaper one exists), and the hint text names it.
- After learning `basic_breathing` only, the hint is still there; after learning `iron_fist`, it is gone (`{}` / "").
- `hints(...)` for that fresh character in Qingshi with default limit contains the first-combat line.
- A region whose merchants sell no combat manual (pick one from data, or region_id "") falls back to "Look for the ...".
- `loss_advice` for a bare player losing to `mist_wolf` contains "no fighting style"; with `iron_fist` known it does not.

## Acceptance
`tools/test.sh` passes. A new game in Qingshi, after talking to Elder Mo, still shows a HUD hint naming the Iron Fist
manual, the Wandering Merchant and its price until the player learns a combat technique.
Follow-ups for the planner (not this task): MENTOR-003 reuses `first_combat_hint` in the pointers refusal.
