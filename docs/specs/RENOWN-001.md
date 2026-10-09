# RENOWN-001: Local renown (core)

**Why.** Exploring now has targets (bounties, discoveries, deeper paths), but nothing remembers that you are the one who
cleared the marsh wolf or found the shrine. Renown gives staying in a region a payoff: the people there know your name,
merchants give you a little off, and the journal says so. Smallest version: renown only rises, from a few clear sources,
and only gives a buy discount and a title. (Infamy for demonic acts is an open question, see the end.)

## Data: `data/regions.json` top-level `"renown"` block
```json
"renown": {
  "sources": {"bounty": 15, "discovery": 5, "deep_path": 5, "righteous_deed": 3},
  "tiers": [
    {"min": 0,   "title": "",            "buy_mult": 1.0},
    {"min": 20,  "title": "Known",       "buy_mult": 0.97},
    {"min": 50,  "title": "Respected",   "buy_mult": 0.94},
    {"min": 100, "title": "Renowned",    "buy_mult": 0.9}
  ],
  "max": 150
}
```
- Document it in the file's `_doc` (every field). GameData loads it into `data.renown: Dictionary` (default `{}` = no renown
  at all: every function below returns 0 / 1.0 / "" and nothing is posted).
- Validate in `GameData._validate()`: `sources` values are ints >= 0; `tiers` non-empty, first `min` is 0, `min` strictly
  rising, `buy_mult` in (0, 1], `title` a String; `max` int > 0.

## State: `CharacterData.renown: Dictionary = {}` (region id -> int)
`to_dict`/`from_dict` with default `{}`; add it to tests/unit/test_save_data.gd's round trip like `explore_days`.
No SAVE_VERSION bump (new key with a default).

## System: `src/core/systems/renown.gd` (`class_name Renown`, RefCounted, static funcs, `##` doc on top and on each func)
- `static func value(c: CharacterData, region_id: String) -> int`
- `static func gain(c: CharacterData, data: GameData, region_id: String, source: String) -> Dictionary`: adds
  `data.renown.sources[source]` (unknown source or empty config = 0), capped at `max`. Returns
  `{"gained": int, "new_tier": String}`; `new_tier` is the tier title when this gain crossed into a higher tier with a
  non-empty title, else "".
- `static func tier(data: GameData, value: int) -> Dictionary`: the highest tier whose `min` <= value ({} when no config).
- `static func title(c, data, region_id) -> String`: the tier's title ("" at tier 0).
- `static func buy_multiplier(c, data, region_id) -> float`: the tier's `buy_mult` (1.0 without config).
- `static func describe(c, data) -> PackedStringArray`: one line per region with a non-empty title, data order:
  "<Region>: Respected (54)".

## GameState hooks (src/autoload/game_state.gd)
Add one helper `func _gain_renown(source: String) -> void` that calls `Renown.gain(player, data, current_region, source)`
and, when `new_tier` != "", posts `"Your name is %s in %s now." % [new_tier.to_lower(), region name]` ("progress").
Call it from:
1. **bounty**: in `_hunt_bounty_foe` right after `Bounties.complete` pays (the bounty's region is the current region).
2. **discovery**: in `_explore_once` where `world_flags["discovered_" + current_region] = true` is set (~line 598).
3. **deep_path**: where GUIDE-016's hidden-path encounter is picked in `_explore_once` (grep `last_explore_deep_path`).
4. **righteous_deed**: in `perform_deed` after a successful `Deeds.perform`, only when the deed raised alignment (find the
   alignment change in `result` or the deed def; grep how `Reputation.on_witnessed` gets `alignment_delta`). Deeds with
   cooldowns already stop farming.

**Prices.** Renown lowers **buy** prices only, in the current region. Find how `shop_screen.unit_price` and `Items.buy` use
`market_mult` (GameState.market_multiplier()). If the same multiplier also scales sell prices, do NOT fold renown into it;
add `func buy_multiplier() -> float: return market_multiplier() * Renown.buy_multiplier(player, data, current_region)` and
pass it only on the buy path (GameState.buy_item and the shop screen's buy price/max quantity). Sell prices must not change.

**Journal.** In `Guidance.journal` (Opportunities or the section the region lines use, e.g. next to EXPL-002's region progress
line): for the current region, "Your name in <Region>: <Title> (merchants give you N% off)." when the title is non-empty,
else nothing. N = round((1 - buy_mult) * 100).

**Life stat / milestone (small).** In data/milestones.json add `renowned_name` "A Name in the World", "Become Renowned in
any region." using a life stat `best_renown` (max over regions, synced in `_gain_renown` with LifeStats' max/set helper;
grep how `regions_visited` is synced) with min 100.

## Tests (tests/unit/test_renown.gd + one in test_game_session.gd)
- gain adds the source amount, caps at `max`, unknown source adds 0; empty `data.renown` gives 0 / 1.0 / "".
- tier crossing: 15 -> +15 = 30 returns new_tier "Known"; a gain that stays in the tier returns "".
- buy_multiplier per tier; `describe` lists only titled regions.
- validator rejects a tier list whose first min is not 0, a non-rising min, and buy_mult 0 or > 1.
- GameState: winning a bounty fight (force `hunt_chance` 1.0 and a weak bounty foe like BOUNTY-001's tests) raises the
  region's renown by 15; a shop buy at "Known" costs 3% less (rounding as `Reputation.buy_price` rounds), a sell price is
  unchanged; save round trip keeps `renown`.

## Acceptance
`tools/test.sh` green; renown visible in the journal after one bounty + one discovery in Misty Forest (20 = Known).
Follow-ups for the planner: WU-084 shows renown on the sheet and world map; infamy for demonic acts is an open question.

## Open design question (add to DESIGN.md if you think it matters; do not build it)
Should demonic acts in a region (robbing, killing NPCs there) build *infamy* that makes merchants refuse you or guards
attack? Default for now: renown only rises; infamy is not built.
