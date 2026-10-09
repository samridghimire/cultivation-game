# BOUNTY-001: Bounties (core)

Why: QA-041's curious sim says months 7-36 are explore + sect mission only, and exploring is a random draw. A bounty gives
the player a chosen target ("hunt the Mist Wolf Alpha in the Misty Forest for 120 stones") that turns exploring a region
into a hunt with a payout. Small loop, reuses enemies, regions and the explore path. This task is the core and GameState
API only; WU-076 adds the board place in the world, C-052 writes the full list.

## Data: new `data/bounties.json`
```json
{
  "_doc": "Bounties posted on bounty boards (BOUNTY-001). ...",
  "hunt_chance": 0.3,
  "max_active": 1,
  "offers": 3,
  "bounties": [
    {"id": "mist_wolf_alpha_bounty", "enemy": "<an enemy id>", "region": "misty_forest",
     "min_realm": "qi_refining", "min_stage": 3, "max_realm": "qi_refining",
     "reward_stones": 60, "days": 60, "cooldown_days": 120,
     "text": "Hunters of Qingshi offer 60 stones for the pelt of the wolf that took three goats."}
  ]
}
```
- `enemy` must exist in data/enemies.json, `region` in regions.json; `min_realm`/`max_realm` realm ids (optional,
  `max_realm` absent = no cap); `min_stage` optional (needs `min_realm`, same meaning as encounters' ENC-002 field);
  `reward_stones` > 0; `days` (how long the hunt stays open) >= 7; `cooldown_days` >= 0; `text` non-empty.
- Validate all of it in `GameData._validate()` (follow how encounters are validated) and load it like the other files
  (`GameData.bounties: Dictionary` id -> Dictionary, plus `bounty_config: Dictionary` for the top-level numbers with the
  defaults above when absent).
- Write the `_doc` in full (every field). Add **3** bounties to start with: one Qi Refining (Misty Forest), one Foundation
  (Withered Bone Marsh or Azure Peak), one Core Formation (Myriad Peaks Ridge). Pick enemies that already appear in that
  region's encounters (grep encounters.json for the enemy id and check the encounter's tags overlap the region's
  `encounter_tags`). Reward: about 1.5x one week of that region's gather income (look at docs/balance_baseline.txt's
  economy section; say in the commit what you used).

## State: CharacterData
- `bounty: Dictionary = {}`: the active hunt `{"id": String, "until_day": int}` (empty = none).
- `bounty_cooldowns: Dictionary = {}`: bounty id -> first day it can be taken again.
- Add both to `to_dict`/`from_dict` with defaults (old saves load with no bounty). No SAVE_VERSION bump needed (same as
  `explore_days`), but add both keys to tests/unit/test_save_data.gd's round trip like EXPL-001 did.

## System: `src/core/systems/bounties.gd` (`class_name Bounties`, RefCounted, static funcs, `##` docs)
- `static func offers(c: CharacterData, data: GameData, today: int) -> Array[Dictionary]`: bounties (data order) whose
  realm/stage gate the character meets (reuse `Exploration.realm_allows` if it takes a Dictionary with
  min_realm/max_realm/min_stage; otherwise write a small helper), not on cooldown (`today < bounty_cooldowns[id]`), not
  the active one, and whose region exists. At most `offers` entries.
- `static func check_take(c, data, bounty_id, today) -> String`: "" or the reason ("You are already on a hunt.",
  "That bounty is not posted for you.", "Posted again in N days.").
- `static func take(c, data, bounty_id, today) -> void`: sets `c.bounty = {id, until_day: today + days}`.
- `static func active(c, data, today) -> Dictionary`: the active bounty's def merged with `until_day`, or {} (also {} when
  expired: `today > until_day`).
- `static func expire(c, data, today) -> String`: if the active bounty ran out, clears it, sets its cooldown and returns
  its id (else "").
- `static func hunt_roll(c, data, region_id, today, rng) -> String`: the active bounty's enemy id when its region is
  `region_id` and `rng.randf() < hunt_chance`, else "".
- `static func complete(c, data, today) -> int`: pays `reward_stones` (c.spirit_stones or however stones are stored;
  grep an existing reward), sets the cooldown (`today + cooldown_days`), clears `c.bounty`, `LifeStats.add(c,
  "bounties_done")`, returns the stones paid.
- `static func abandon(c, data, today) -> void`: clears it and starts the cooldown.

## GameState (src/autoload/game_state.gd)
- `func take_bounty(bounty_id: String) -> void`: check, take, post "You take the bounty: <text> (<days> days)." Takes no
  time. Emit `EventBus.player_changed` like other actions.
- `func abandon_bounty() -> void`.
- In `_explore_once`, after the discovery check and **before** `Exploration.roll_encounter`: if there is no discovery and
  `Bounties.hunt_roll(...)` returns an enemy id, post "You pick up the trail of the <enemy name> from your bounty."
  ("danger"), pass 1 day (`_pass_time(1)`), then:
  - if `Exploration.should_evade(player, data, enemy_id)` (Deadly): post "The <enemy> is far beyond you. You lose the
    trail." ("warning") and keep the bounty;
  - else `var won := fight(enemy_id)`; if `won`: `Bounties.complete`, post "Bounty claimed: <stones> spirit stones." 
    ("progress"). A lost fight keeps the bounty open.
  - return `{"event": "fight"}` so explore_many stops.
  The player chose this fight, so a Dangerous lethal foe is fought directly (no threat prompt); the board (WU-076) shows
  the odds before taking it.
- On day advance (where other daily/monthly expiries run, e.g. near `SectFactions.expire_calls` or the commissions lapse),
  call `Bounties.expire` and post "Your bounty on the <enemy> has lapsed." when it returns an id.
- Journal: in `Guidance.journal` Opportunities, when a bounty is active: "Bounty: <enemy name> in <region name>
  (<N> days left, <stones> stones)." tone "normal".

## LifeStats / milestone
- New stat key `bounties_done`. Add a milestone in data/milestones.json `bounty_hunter` "Bounty Hunter", "Claim five
  bounties.", life_stat bounties_done min 5.

## Tests (new tests/unit/test_bounties.gd + one in tests/unit/test_game_session.gd)
- Validator rejects an unknown enemy, unknown region, reward 0, days < 7 (build bad dicts the way other validator tests do).
- `offers`: a fresh Qi Refining 4th Layer character sees the Qi Refining bounty and not the Core one; a Core Formation
  character does not see the Qi Refining one when it has `max_realm`; a bounty on cooldown is not offered.
- `check_take` refuses a second hunt; `take` + `active`; `expire` after `until_day` clears and sets the cooldown.
- `hunt_roll` with `seeded_rng()`: only in the bounty's region; returns "" with no active bounty.
- `complete` pays stones, sets the cooldown, counts `bounties_done`.
- GameState integration: take a bounty, set `hunt_chance` to 1.0 in the loaded data (or the config dict) in the test, travel
  to (or set `current_region`) the region, explore once with a player strong enough to win: the bounty is cleared and the
  stones went up; with a too-weak player against a Deadly foe the bounty stays and no fight happens.
- Save round trip of `bounty` / `bounty_cooldowns`.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; no world/UI changes (WU-076 does those). Follow-ups: anything about rewards that
felt off.
