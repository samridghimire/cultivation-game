# FOLK-003: A friend's tip (systems)

**Reference:** Immortal Life (friendly villagers tell you where the good herbs are this week) and Tale of Immortal (NPCs
who like you share information). Mechanics only.

## Why
WORLD-003/FOLK-001/WORLD-005 made villagers greet you, ask favours and marry, but favor itself still buys little in the
first hours besides gifts and marriage. A friend who tells you "the herb slope is thick with Spirit Grass after the rain"
turns friendship into a reason to go somewhere, and sends a new player out to gather with a clear payoff.

## Rule
When the player **chats** with a generated villager (`GameState.chat`) whose favor is at least `min_favor`, and no tip is
active, and the last tip was given at least `cooldown_days` ago, roll `chance`. On success the villager names one item
that a gather site in the current region (or, if none qualifies here, a region one route away) can yield this season, and
for `days` days every gather in that region whose season-filtered table contains the item adds `bonus` of that item to
what was found (even when the roll found nothing).
One tip at a time. The tip expires silently.

## Data (data/family.json, document in `_doc`, validate in `Folk.validate`)
```json
"folk_tips": {
  "min_favor": 30, "chance": 0.35, "cooldown_days": 20, "days": 10, "bonus": 2,
  "lines": [
    "{villager} leans in: \"After the last rain the {place_kind} in {region} is thick with {item}. Go before the others hear.\"",
    "... (3-5 lines; plain, no gendered words about {villager}) ..."
  ]
}
```
Validation: all numbers > 0, `chance` in (0, 1], `days` <= 60, `bonus` 1..5, `lines` non-empty, each line contains
`{item}`. Absent `folk_tips` = feature off (all functions return empty results).

## Code
`src/core/systems/folk.gd` (pure, static, rng passed in):
- `const TIP_KEY := "folk_tip"` (world flag; value `{region, item, until, npc_id}`), `const TIP_LAST_KEY := "folk_tip_last"` (int day).
- `static func tip_rules(data: GameData) -> Dictionary`
- `static func tip_candidates(c: CharacterData, data: GameData, region_id: String, season: String) -> Array[String]`:
  item ids (non-empty) from every `gather` place's `Exploration.gather_table_for(c, data, table, season)` in that region,
  skipping entries the player's realm can't find (`min_realm`), de-duplicated, sorted (determinism).
- `static func roll_tip(c, data, flags, region_id, neighbours: Array, favor: int, npc_id: String, today: int, season: String, rng) -> Dictionary`:
  returns `{}` or the new tip (and writes `flags[TIP_KEY]`, `flags[TIP_LAST_KEY]`). Order of checks: rules present,
  favor >= min_favor, no active tip (`active_tip(flags, today)` empty), cooldown, then `rng.randf() < chance`, then pick the
  region (here first; else the first neighbour, by route order, with candidates), then `rng.randi_range` over candidates.
  Roll the chance before picking so the rng stream doesn't depend on candidates.
- `static func active_tip(flags: Dictionary, today: int) -> Dictionary`: `{}` when absent or `today > until`.
- `static func tip_bonus(flags, today, region_id, season_table: Array) -> Dictionary`: `{item: bonus}` when the active tip
  is for `region_id` and `season_table` (already season/realm-filtered) has the item; else `{}`.
- `static func tip_line(data, tip: Dictionary, villager_name: String, line_index: int) -> String`: fills `{villager}`,
  `{item}` (the item's name), `{region}` (region name), `{place_kind}` ("herb slope" if the item is tagged herb, "ore
  tailings" if ore, else "gathering ground").

`src/autoload/game_state.gd`:
- in `chat()`, after the visit bonus and only for generated villagers (`Npcs.keeps_round` or whatever WORLD-002 uses to
  tell generated villagers from named NPCs; family members never give tips): call `Folk.roll_tip(...)` with the current
  region's route targets as neighbours; on a tip post `Folk.tip_line(...)` (category "info", line index = day % lines).
- in `gather(table, days)`: after the rain bonus, add `Folk.tip_bonus(world_flags, GameClock.total_days, current_region,
  Exploration.gather_table_for(player, data, table, season))` into `found`, and post once: "{villager}'s tip was good: +2
  Spirit Grass." (look up the name from `npcs` by the tip's npc_id; fall back to "Your friend").
- `func active_tip_text() -> String` for the UI: "" or "Tip: Spirit Grass in Misty Forest (4 days left)". WU follow-up
  shows it in the journal; no UI work in this task.
- Save: world_flags already save. Make sure a tip loaded from JSON has int `until` (`int(...)` on read, as FOLK-001 did).

## Tests
`tests/unit/test_folk.gd`:
- no tip below min_favor, while a tip is active, inside the cooldown; with `chance` forced to 1.0 a tip names an item from
  the region's season-filtered gather tables; falls back to a neighbour region when the current one has no gather place
  (e.g. a city region; build a tiny region set in the test if no data region qualifies); `{}` with no `folk_tips`.
- `tip_bonus` only for the tip's region and only when the table has the item; `active_tip` empty after `until`.
- determinism: same seed, same tip.
`tests/unit/test_game_session.gd`:
- chat with a generated villager at favor 40 and `chance` 1.0 (set on the loaded data in the test, restore it after)
  posts the tip line and sets the flag; a following gather in that region at a site that has the item adds the bonus
  even with a seeded rng that would otherwise find nothing; a family member never gives a tip.
- balance: the sims never chat, so `tools/balance.sh --check` should not move. Run it only if you change anything the sims
  call; say so in the commit.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. Commit `[FOLK-003] A friend's tip`. Follow-ups: WU (journal line + a small "tip"
marker on the gather site, like WU-402's "!"), C-275 (more tip lines).
