# FOLK-007: Friends, close friends

Role: systems. Reference: Immortal Life's affinity levels and Stardew-like friendship tiers (mechanic only: named tiers
of favor, a small moment the first time you reach one).

## Why
Favor with villagers already moves through chats, tea, gifts, requests, quarrels and companions, but it is an invisible
number: the player never learns that Xiao Ling now counts them a friend. A named tier and a one-time moment make the
village feel alive and give the favor systems a visible payoff.

## Data (data/family.json, documented in `_doc`, validated in `GameData._validate`)
```json
"folk_tiers": [
  {"min": 20, "name": "Acquaintance"},
  {"min": 40, "name": "Friend", "line": "{name} waves you over. \"You keep turning up when I need a hand. Come by for tea any time.\"", "gift": {"item": "<a cheap village item>", "count": 1}},
  {"min": 60, "name": "Close friend", "line": "...", "gift": {...}},
  {"min": 85, "name": "Sworn friend", "line": "...", "gift": {...}}
]
```
`min` strictly rising, 1..100; `name` non-empty; `line` optional with `{name}`; `gift` optional (item id must exist,
count 1..3). Below the first min the tier is "" (no tier). Pick gift items that are cheap and village-flavoured (look at
`folk_gifts`); the 85 tier may give something a little better (a pill a Qi Refining player would value).

## Rules (src/core/systems/folk.gd)
- `static func tier_index(data: GameData, favor: int) -> int` (-1 below the first tier) and
  `static func tier_name(data, favor) -> String`.
- `static func new_tiers(data, seen: Dictionary, favor_by_id: Dictionary, ids: Array) -> Array[Dictionary]`: for each
  generated villager id in `ids` whose current tier index is above `seen.get(id, -1)`, return `{id, tier}` for the highest
  newly reached tier only (a jump from 10 to 65 fires "Close friend" once, not three moments). Pure.
- `CharacterData.folk_tier_seen: Dictionary` (npc id -> highest tier index already celebrated), saved in to_dict/from_dict,
  default {} (old saves: on first check, seed `seen` with each villager's current tier *without* posting, so loading an old
  save never bursts out a dozen moments: store a `folk_tiers_seeded: bool` too, default false).
- Only tier-ups fire; falling below a tier never lowers `seen` (no repeat when favor dips and recovers).

## GameState
- `check_friendships() -> void`: run `Folk.new_tiers` over the living generated villagers the player knows (whatever set
  `npc_favor` covers that are not family and not named story NPCs; reuse the filter `Folk.visitor`/`folk_gifts` use),
  post each `line` (category "social"), add the gift, update `seen`. Call it at the same place `check_milestones` runs
  after an action (grep), so every favor source is covered without touching each one.
- `friendship_label(npc_id) -> String` for the UI ("Friend", "" if none). WU-418 shows it.

## Tests (tests/unit/test_folk_007.gd and test_game_session.gd)
- tier_index edges (19 -> -1, 20 -> 0, 100 -> last).
- new_tiers: 10 -> 65 returns only the "Close friend" index; already seen returns nothing; two villagers both rising.
- GameState: raising a villager's favor from 35 to 45 and running an action posts the Friend line once and gives the gift;
  a second action posts nothing; an old save (no `folk_tier_seen`) with a villager at 70 posts nothing on load/first check.
- Validation rejects non-rising mins and unknown gift items.

Balance: gifts are tiny and one-off; no `balance.sh --check` unless you give anything worth more than ~30 stones.
