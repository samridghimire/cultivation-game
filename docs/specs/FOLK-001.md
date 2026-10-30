# FOLK-001: Neighbours ask small favours

Role: systems. Reference: **Immortal Life** (villagers post small daily requests you fill from what you gather) and
**Tale of Immortal** (NPCs ask favours and remember who helped). Mechanics only.

## Why
Villagers now keep a round (WORLD-001), say what they are doing (WORLD-002), greet you by favor (WORLD-003) and like you
more when you help them in a happening (C-268). But favor with a villager can only be raised by luck (a happening) or
by spending stones on gifts. A small, readable loop "a neighbour asks for 2 Spirit Grass -> you gather it -> they thank
you, you get a little reward and favor" gives the first hour a cozy goal that uses gathering, and makes the village feel
like it knows you.

## Reuse, don't rebuild
LETTER-003 already has in-person item requests: `CharacterData.letter_requests` entries
`{npc_id, item, count, until, favor, effects}`, `Letters.open_request/check_answer/answer/expire_requests/request_lines/
requests_in_region`, GameState `letter_request/check_letter_request/answer_letter_request`, the NPC menu option that hands
the items over (npc.gd `_letter_options()`), the journal lines and the month-end expiry (game_state.gd ~3136-3150).
**Folk requests are letter requests with `"source": "folk"`.** No new save field (old entries without `source` read as
`"letter"`), so no SAVE_VERSION bump.

## Data: data/family.json `folk_requests` (document in `_doc`, validate in `Folk.validate` / `GameData._validate()`)
```json
"folk_requests": {
  "monthly_chance": 0.5,
  "min_favor": 0,
  "days": 20,
  "max_open": 2,
  "asks": [
    {"item": "spirit_grass", "count": [2, 4], "favor": 6, "stones": [3, 6],
     "text": "{villager} asks if you could bring {count} {item}; their mother's cough is back."},
    ...
  ]
}
```
- `monthly_chance` 0..1, `min_favor` int (-100..100), `days` >= 1, `max_open` >= 1 (folk requests open at once).
- each ask: `item` (an items.json id that can be **gathered or bought in at least one region**; validate it appears in some
  gather_table or merchant stock, see `Exploration.gather_rate` / shop stock helpers; if a stock check is awkward, gather
  tables only), `count` [min, max] ints >= 1, `favor` int 1..15, `stones` [min, max] ints >= 0, `text` non-empty with
  `{villager}`, `{count}`, `{item}`; optional `regions` (list of region ids; absent = any region), optional `seasons`
  (Calendar season ids).
- Write 6 asks yourself (systems may write the first data; the content role adds more in C-273): herbs from Qingshi's
  gather tables (check the ids in data/regions.json), Boar Hide, an ore, a cheap pill (Qi Gathering Pill), a meal-type or
  common item if one exists. Keep rewards small: stones about the item's sell value x count + 2..4.

## Core: `src/core/systems/folk.gd`
- `static func monthly_request(c: CharacterData, npcs: Dictionary, data: GameData, rng: RandomNumberGenerator, region_id: String, favor: Dictionary, today: int) -> Dictionary`
  - returns {} when: no `folk_requests`; the player already has `max_open` open folk requests; the rng roll
    `rng.randf() >= monthly_chance`; no eligible villager; no eligible ask.
  - eligible villager: `Folk.candidates(npcs, data, c, region_id)` (living generated adults of the region, not family,
    not rival) with `favor.get(id, 0) >= min_favor` and no open request of any source (`Letters.open_request(...)` empty).
    Pick with the rng.
  - eligible ask: `regions` absent or contains region_id; `seasons` absent or contains `Calendar.season_of(today)`.
    Pick with the rng; roll count and stones with `rng.randi_range`.
  - appends `{"npc_id", "item", "count", "until": today + days, "favor", "effects": {"items": {"spirit_stone": stones}}, "source": "folk", "text": <filled text>}`
    to `c.letter_requests` (stones are the `spirit_stone` item, paid through the `items` key of `Effects.apply`), and returns that entry.
  - `{villager}` = the villager's name, `{item}` = `Items.item_plural(data, item, count)`, `{count}` = the number.
- `Letters.request_lines`: for `source == "folk"` write "<Name> asked you for 2 Spirit Grass (N days left; they are in <Region>)."
  instead of "in a letter". `Letters.check_answer`'s "No letter from them..." becomes "They have not asked you for anything."
  when no request is open (both sources; update tests that pin the old text).
- Expiry: unchanged (no penalty). A folk request whose villager dies is dropped by the existing paths (check
  `request_lines` skips dead askers; also make `expire_requests` drop requests whose asker is dead or missing if it does not).

## GameState
- In the month-end block next to `Letters.monthly` (~3136): call `Folk.monthly_request(player, npcs, data, rng, current_region, npc_favor, GameClock.total_days)`;
  if non-empty, post its `text` plus " (Give it to them in person within 20 days.)" in category `"info"` with topic `family`.
- Answering uses the existing `answer_letter_request(npc_id)`: favor and effects already apply. Make sure the success
  message reads well for a folk request ("You give Wu Lan 3 Spirit Grass. They press 5 spirit stones into your hand.";
  keep the letter wording for letters). Favor for folk villagers must go through the same cap as C-268's `villager_favor`
  if one applies (`Folk.FAVOR_LIMIT` is for happenings; requests may go above it up to 100).
- Sims: the first-hour/curious sims never answer requests; the month-end roll consumes rng, so **run
  `tools/balance.sh --check`** and refresh the baseline sections that move only because of the extra rng draw (say so in
  the commit). To keep the draw stable, roll `monthly_chance` first and return early before any other draw.

## Tests (tests/unit/test_folk.gd, test_letters.gd, test_game_session.gd)
- `monthly_request`: chance 0 -> {}; chance 1 -> an entry with source folk, until = today + days, count/stones within
  range, text has the villager's name and no `{`; respects `max_open`; skips family, the rival and a villager with an open
  request; `regions`/`seasons` filters; min_favor filter; deterministic for a seeded rng.
- `request_lines` wording for both sources.
- Validation: missing `{villager}` in text, count min > max, unknown item, favor out of range each produce an error.
- GameState integration: force a request (set chance 1 in a test copy of the data, or append the entry directly), give the
  player the items, `answer_letter_request(id)` removes the items, adds the stones and the favor, posts the folk wording;
  without the items it posts the warning and changes nothing.

## Acceptance
- In a new game, within a few months in Qingshi a villager asks for something; the journal lists it; walking to them and
  choosing the existing answer option hands it over and pays out.
- `tools/test.sh` prints ALL CHECKS PASSED; balance baseline refreshed with an explanation.
- UI (a "!" over the asker and the greeting bubble mentioning the request) is WU-402, not this task.
