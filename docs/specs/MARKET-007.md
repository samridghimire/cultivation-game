# MARKET-007: Something new on market day (systems)

Reference: Stardew Valley's travelling cart (a stall that comes on set days with a small, changing stock of things
you cannot always buy). Mechanics only.

## Why
Qingshi's Travelling Market Stall (MARKET-002) opens on days 10 and 25 but always sells the same three things
(`stock_tags: ["purple_cloud_mushroom", "qi_condensing_grass", "sweet_rice_ball"]`). Once seen, there is no reason to
come back. CAL-005 named the weekdays so players can plan days; market days should be worth planning for.

## Data (regions.json, `merchant` places only)
New optional field on a place: `rotating_stock: {pool: [{item: items.json id, weight > 0}], count: int 1..6}`.
- On each day the place is open, `count` distinct items are picked from `pool` by weight. The pick is deterministic per
  (place display_name, day), so a save/load or reopening the shop shows the same wares, and the next open day differs.
- Today's picks are **added** to the place's `stock_tags` (an item id in `stock_tags` already works:
  `Items.merchant_sells` ~line 104). Two traps in `merchant_sells`: an item above the place's `max_price` and an item
  carrying a `data.restricted_item_tags` tag are refused before the id check. Validation therefore requires every pool
  item to have `price > 0`, to fit the place's `max_price` (if any), and to carry no restricted tag (or make the id check
  win for pool items; pick one and test it).
- Document the field in regions.json `_doc` next to `open_days`. Validate in GameData (where `open_days` is validated,
  game_data.gd ~641): pool non-empty, every item a known items.json id, weights > 0, count 1..min(6, pool size),
  only on `merchant` places.
- Give the Qingshi Travelling Market Stall a pool of ~10 existing items, count 3: things a first-year player wants but
  cannot buy in Qingshi, priced at or under ~120 stones (e.g. a combat or body manual sold only in Fallen Star Market,
  a Qi Gathering Pill, a cheap talisman, seeds, a fishing bait, a rare spice). **No armor or weapons** (owner question
  GEAR-001 keeps armor out of Qingshi). Keep its three fixed `stock_tags`.

## Core
`src/core/systems/places.gd` (pure, static, typed):
- `static func rotating_picks(place: Dictionary, today: int) -> Array[String]` returns [] when the place has no
  `rotating_stock` or is closed today. Seed a local `RandomNumberGenerator` with `hash(String(place display_name)) ^ today`
  (a local seeded rng is deterministic; never the global one), weighted pick without replacement.
- `static func stock_tags_today(place: Dictionary, today: int) -> Array` = `stock_tags` + `rotating_picks`.

## Wiring
- world.gd builds merchants with `stock_tags` (~line 498); a merchant with `rotating_stock` keeps the place dict (or the pool)
  and passes `Places.stock_tags_today(place, GameClock.total_days)` to `EventBus.shop_requested` in `merchant.gd`
  `get_options()` (compute at click time, so a day that passes while standing there is right).
- Guidance: `Places.hint_line` (journal "Market day in 3 days: Travelling Market Stall") appends "(new wares each time)"
  when the place has `rotating_stock`; on the day itself: "Market day today: Travelling Market Stall sells Iron Fist
  Manual, Qi Gathering Pill, Bamboo Talisman". Keep it one line.
- Village calendar (VillageCalendar, Y): the market-day entry for that place (check how `open_days` places appear; add
  them as an entry if they do not) gets the same "new wares each time" note. Do not list future picks (they are a
  surprise until the day).

## Tests (tests/unit/test_places.gd or a new test_market_rotation.gd)
- Same place + day gives the same picks; two open days give different picks for a 10-item pool (check a few days).
- `count` distinct items, all from the pool; closed day gives [].
- Weight 0 or unknown item id fails validation (GameData error text).
- Real data: Qingshi's stall has a valid pool, no item tagged weapon/armor, every pool item priced <= 120.
- GameState integration (test_game_session.gd style): advance to day 10, the stall's options pass stock tags that
  include the three fixed tags and three pool items.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. No balance check needed unless a pool item is cheaper than anywhere else
(say so under Follow-ups). Follow-up for content: C-299 adds more carts (Fallen Star Market's night stall, the marsh).
