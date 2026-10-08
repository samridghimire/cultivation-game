# PROF-001: Crafting commissions (core)

**Why:** professions are a pillar, but crafting only pays its material cost x1.3 at a merchant (Items.sell_price) and the
economy sim (QA-006b) shows gathering out-earns every profession ~8x. Commissions give a crafter a reason to craft: each
month a buyer orders a few of something the player can already make, for about twice its material value plus profession xp.
Smallest version: no accept step, no penalty for ignoring an order (that would be a design call).

## Data: data/recipes.json
Add a top-level block next to `alchemy` and document it in `_doc`:
```json
"commissions": {"per_profession": 1, "count": [1, 3], "reward_mult": 2.0, "xp_fraction": 0.5, "days": 60}
```
- `per_profession`: most open orders per profession at a time.
- `count`: [min, max] units ordered.
- `reward_mult`: stones = ceil(Items.material_value(output item) x count x reward_mult), at least 1.
- `xp_fraction`: profession xp on delivery = recipe `xp` x xp_fraction x count.
- `days`: an order lapses this many days after it is posted.

GameData: `var commissions: Dictionary = {}` loaded with `crafting.get("commissions", {})` (game_data.gd ~272).
`_validate()`: when the block exists, `per_profession` int >= 1, `count` two ints 1 <= min <= max, `reward_mult` >= 1.0,
`xp_fraction` >= 0, `days` int >= 1. Add a test for one bad value in the GameData validation tests.

## Save: src/core/character_data.gd
`var commissions: Array[Dictionary] = []` with a `##` comment. Each entry:
`{"profession": id, "recipe": id, "item": id, "count": int, "reward": int, "xp": float, "due_day": int}`.
to_dict: deep copy. from_dict: default `[]` (no SAVE_VERSION bump; older saves load with none).

## Rules: src/core/systems/commissions.gd (new, `class_name Commissions`, `##` doc at top)
- `static func rules(data) -> Dictionary` = `data.commissions`.
- `static func roll(c, data, rng, today: int) -> Array[Dictionary]`: for each profession id in `c.professions` (sorted, for
  determinism) that has known recipes (`Alchemy.known_recipes(c, data, prof_id)`) whose `min_rank <= Professions.rank_of`,
  and fewer than `per_profession` open orders for it: pick one such recipe with `rng`, skip recipes whose output item has
  `material_value < 0`, roll count, compute reward/xp, set `due_day = today + days`, append to `c.commissions` and return
  the new entries. Empty if `rules` is empty.
- `static func check_deliver(c, data, index: int) -> String`: "" or "No such order." / "You need N more <item name>."
- `static func deliver(c, data, index: int) -> Dictionary` {ok, reason, stones, xp, ranks_gained, item, count}: removes the
  items, adds `spirit_stone`, `Professions.add_xp`, erases the order, `LifeStats.add(c, "commissions_done")` (add the key
  to LifeStats.KEYS and LABELS: "Commissions filled").
- `static func expire(c, today: int) -> Array[Dictionary]`: removes and returns orders with `due_day < today`.
- `static func describe(c, data, entry: Dictionary, today: int) -> String`:
  "3 Qi Gathering Pills for 54 spirit stones and 30 alchemist xp, 41 days left (you have 1)".

## GameState (src/autoload/game_state.gd)
- In the month loop of `_on_days_advanced` (~2313, next to `_sect_factions_month()`), call `_commissions_month()`: roll and
  post each new order, topic "trade", category "progress":
  "A buyer at the workshop orders 3 Qi Gathering Pills for 54 spirit stones (60 days)."
- After the loop, `Commissions.expire(player, GameClock.total_days)`; post "The order for 3 Qi Gathering Pills lapsed." (info).
- `func deliver_commission(index: int) -> void`: `_can_act()`, check, deliver, post "You deliver 3 Qi Gathering Pills: +54
  spirit stones, +30 xp." plus a rank-up line like `work_profession`, emit `EventBus.player_changed`. No time passes.
  Sect members also gain contribution as in `work_profession` (xp / 2, or xp if favored profession).
- `func commission_lines() -> PackedStringArray` (describe each, for the UI).

## Guidance
`Guidance.journal`: a "Commissions" section with one entry per open order (`describe`), tone "warning" when <= 7 days
left, else "normal". Pass `today` (already a parameter).

## Tests
tests/unit/test_commissions.gd (seeded_rng):
- roll gives nothing for a character with no professions, one order for a rank-0 alchemist who knows the starter recipes,
  and no second order while one is open (`per_profession` 1).
- reward = ceil(material_value x count x 2.0); xp = recipe xp x 0.5 x count.
- check_deliver reports the shortfall; deliver with the items pays, removes items, erases the order, adds xp and the stat.
- expire removes only orders past due_day.
- to_dict/from_dict round-trips orders; from_dict without the key gives [].
tests/unit/test_game_session.gd: a session whose player has the alchemist profession gets an order after cultivating past a
month boundary; giving them the items and calling `deliver_commission(0)` raises stones and posts one message.

## Out of scope
The workshop menu entry and journal rendering of orders (WU-013), commission content tuning (ECON-001 re-runs the sim).

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; under ~400 changed lines; commit `[PROF-001] Crafting commissions`.
