# FOLK-052: Meditate beside a friend

Reference: Tale of Immortal's NPCs who cultivate beside you and grow closer for it; Stardew Valley's small daily
friendship actions (mechanics only, no names, story or art).

## Why
FOLK-050 made named friends cultivate on their own (Xiao Ling begins Qi Refining, others break through), but the only way to
share that is a one-time Congratulate. Spouses can dual-cultivate (`GameState.dual_cultivate`, `Family.dual_cultivate`); a
friend who cultivates should offer a lighter version: sit together at a meditation spot for a short session.

## Rules (data/family.json, new block `friend_meditation`, documented in `_doc`, validated in `GameData._validate()`)
```json
"friend_meditation": {"min_favor": 40, "days": 7, "qi_mult": 1.1, "favor": 2, "cooldown_days": 14}
```
- Eligible friend: a named NPC (`data.npcs.has(id)`), alive, `Npcs.region_of(npc, data) == current_region`, favor >= `min_favor`,
  realm index >= 1 (Qi Refining or above; a Mortal cannot meditate on qi), not the player's spouse (spouses already have
  dual cultivation), and not on cooldown (`world_flags["friend_med_<id>"]` holds the last day; cooldown from that day).
- The player must be able to cultivate (same checks `cultivate` uses: `_can_act()`, not at a bottleneck is NOT required,
  the normal cultivate path handles bottlenecks).
- Effect: the player meditates `days` days at the spot's density with qi x `qi_mult` (apply it the way `_cultivation_density`
  scales density: pass `location_density * qi_mult`), the friend gains favor `favor` (clamped by the usual 0..100), the
  cooldown flag is set. The friend's own qi is not touched (keeps the NPC sim deterministic and untouched).

## Code
1. `src/core/systems/folk.gd` (pure, static):
   - `static func meditation_friends(player: CharacterData, data: GameData, npcs: Dictionary, favor: Dictionary, flags: Dictionary, region: String, today: int) -> Array[String]`
     eligible ids sorted by favor desc, then id.
   - `static func meditation_block(player, data, npc: CharacterData, favor: int, flags: Dictionary, region: String, today: int) -> String`
     "" when allowed, else the reason ("Xiao Ling does not cultivate yet.", "...is not here.", "...needs to know you better
     (favor 31/40).", "You sat together N days ago; again in M days.").
2. `GameState.meditate_with_friend(npc_id: String, location_density: float) -> void`: checks `Folk.meditation_block`, posts the
   reason as a warning if blocked; otherwise sets the flag, adds favor, posts "You and <name> sit together in quiet
   cultivation. (<favor text>)" in "family" topic, emits `EventBus.npc_reaction(npc_id, "happy")`, then calls
   `cultivate(days, location_density * qi_mult, "Meditating with <name>")`. Do not duplicate cultivate's logic.
3. `src/world/interactables/meditation_spot.gd`: after `_dual_cultivation_options()`, one option per eligible friend (max 2):
   `{"label": "Meditate with <name> (7 days)", "description": "+10% qi, favor +2. Once every 14 days.", "action": GameState.meditate_with_friend.bind(id, qi_density), "keep_open": true}`.
   Read the numbers from data for the label/description.
4. Save: the cooldown lives in `world_flags` (already saved). No SAVE_VERSION change.

## Tests
- tests/unit/test_folk.gd (or a new test_friend_meditation.gd): eligibility (mortal friend blocked, low favor blocked with
  numbers, other region blocked, spouse excluded, cooldown blocks then frees on day+14), ordering.
- tests/unit/test_game_session.gd: `meditate_with_friend` gives more qi than `cultivate` for the same days/density (same seed),
  adds favor 2, sets the flag; a second call inside the cooldown changes nothing and posts a warning.
- Data validation test: a missing/invalid `friend_meditation` field fails `_validate()`.

## Acceptance
- At Qingshi's Meditation Rock with Xiao Ling at Qi Refining and favor 40+, the spot menu lists "Meditate with Xiao Ling (7 days)".
- `tools/test.sh` prints ALL CHECKS PASSED. No balance check needed (the sims never pick this option); say so in the commit.
- Follow-ups: WU-635 stages the scene.
