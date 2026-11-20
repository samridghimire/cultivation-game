# FOLK-035: Lend a hand (a first friend in the first month)

Role: systems. Reference games: **Stardew Valley** (friendship grows from small daily kindnesses, not only gifts) and
**Immortal Life** (helping villagers with their daily routines). Mechanics only: no names, story or art.

## Why
SIM-017 (f79c617) measured the hints player: the first Acquaintance (favor 20) comes at a median **day 328 / 130 presses**
and nobody reaches the Friend tier (favor 40) in a year. Chatting costs 3 days for +2 favor and stops at favor 30
(`family.json acquaintance.chat_days / chat_favor / chat_max_favor`); gifts cost ~10 stones per favor. Friends gate
lessons, teachers, spars, festivals and courtship, so the village's best content sits behind a wall a newcomer never
climbs. GFX-219 (e7b34da) now shows villagers at their work: let the player join in.

## Rules (data in `data/family.json`, new block `lend_a_hand`, documented in the file's `_doc`)
```json
"lend_a_hand": {"days": 1, "cooldown_days": 7, "favor": 4, "max_favor": 45,
  "verbs": {"sweep": "sweeping the yard", "hoe": "turning the soil", "fish": "mending nets and fishing",
            "read": "sorting scrolls", "hawk": "minding the stall", "chop": "splitting firewood", "sit": "keeping them company",
            "": "with their chores"},
  "yields": {"hoe": {"item": "<an existing cheap vegetable/herb id>", "count": 1},
             "fish": {"item": "<an existing common pond fish id>", "count": 1},
             "chop": {"item": "<an existing firewood/wood id, or omit>", "count": 1}}}
```
Pick real item ids that already exist in data/items.json (cheap, price <= 3); omit a yield rather than invent an item.
- Who: any **named** NPC (an id in data/npcs.json) who is alive, in the player's current region today, not hostile to
  you, not your own spouse/child (family has its own actions), and not a sect elder of a sect you are not in
  (reuse whatever check the chat path uses for "can't approach"). Generated villagers are out of scope.
- Cooldown: once per `cooldown_days` per NPC. Store the last day in `world_flags["lend_<npc_id>"] = total_days`
  (world_flags is already saved; no SAVE_VERSION bump).
- Gain: `favor` + the same Charisma bonus as `Family.chat_gain` (reuse the step), at least 1, then the festival /
  clan / karma scaling exactly as `GameState.chat` does it, capped so lending never raises favor above `max_favor`.
  At or above `max_favor` the option still shows but is disabled with the reason "{name} is glad of the help, but
  friendship now grows from what you share, not chores." (keeps gifts and deeds meaningful past Friend).
- Time: `days` (1) pass through GameClock like other actions (`_can_act()` first).
- Yield: if the NPC's `activity` has a `yields` entry, add the item.
- Everything else a chat triggers that is about *meeting* someone (`_note_teacher_seen`, `_friend_scene`,
  `_teach_lessons`, tier-up gifts from `folk_tiers`) also runs after a lend, so a tier reached by lending pays out the same.

## Code
- `src/core/systems/folk.gd` (pure, static):
  - `lend_verb(data: GameData, npc_id: String) -> String`
  - `lend_check(c: CharacterData, npc: CharacterData, data: GameData, flags: Dictionary, today: int, favor: int) -> String`
    ("" when allowed; reasons: not here / too soon ("Again in N days") / at max_favor / not approachable)
  - `lend_gain(c: CharacterData, data: GameData, favor: int) -> int` (before festival/clan/karma scaling)
  - `lend_yield(data: GameData, npc_id: String) -> Dictionary` ({} or {item, count})
- `src/core/game_data.gd` `_validate()`: the block's ints >= 0 (days >= 1, cooldown_days >= 1), verbs keys are
  `PlaceLooks.ACTIVITIES` or "", yields items exist in items.json, `max_favor` > `acquaintance.chat_max_favor`.
- `src/autoload/game_state.gd`: `func lend_a_hand(npc_id: String) -> void`, modelled on `chat()` (~line 2343):
  post "You spend the day with {name}, {verb}. ({favor progress})" (+ " They send you off with {item}." on a yield).
- `src/world/interactables/npc.gd` `_acquaintance_options()`: an entry "Lend a hand ({verb}, 1 day, favor N)" next to
  Chat, disabled with the lend_check reason (use `_entry(label, reason, callable)` like Chat does). Gamepad focus is
  already handled by the choice menu.
- `src/core/systems/guidance.gd`: while the player has **no** villager at the Acquaintance tier yet, a today/hint line
  "Make a friend: lend {name} a hand ({verb}, 1 day, favor X/20)" for the best candidate in the current region
  (highest favor under 20 that `lend_check` allows). It is honest, repeatable work, so it fits the GUIDE-230 default.
  Keep it below fight/goal lines in priority; one line at most.

## Tests
- `tests/unit/test_folk.gd` (or a new `test_lend_a_hand.gd`): verb fallback "", cooldown (day 0 ok, day 6 blocked
  with "Again in 1 day", day 7 ok), max_favor cap and disabled reason, Charisma bonus, yield only for tagged
  activities, not-in-region refused, validation errors for a bad yield item / bad verb key.
- `tests/unit/test_game_session.gd`: `lend_a_hand("elder_mo")` in Qingshi advances 1 day, raises favor by the gain,
  sets the flag, and a second call the same day posts a warning and changes nothing; reaching favor 20 by lending
  fires the same tier-up as chatting.
- Guidance: the hint appears for a fresh Qingshi character and disappears once any villager reaches favor 20.

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- In a fresh Qingshi game, Elder Mo / Hunter Ma show "Lend a hand" in their menu; one press gives +4 favor and a day passes.
- Favor is not measured by `tools/balance.sh`, so no balance check; SIM-021 teaches the hints sim the new line and
  re-measures first-friend presses.
- Follow-ups in the commit message: anything that looked off in the numbers (too fast/slow).
