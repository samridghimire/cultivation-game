# SPAR-001: Friendly spar with an NPC (systems)

Crossing hands with a friend: a non-lethal bout that sharpens your techniques win or lose, and earns a little respect if you win.
Depends on MENTOR-001 (shares `data/family.json` `mentorship.spar`, `CharacterData.npc_action_days` and `Mentorship.cooldown_left`).

## Core (`src/core/systems/mentorship.gd`)
- `static func check_spar(c: CharacterData, npc: CharacterData, favor: int, data: GameData, today: int, people: Dictionary = {}) -> String`,
  reasons in order: npc null/dead → "They are not here."; npc a child (adult_age as in MENTOR-001) → "<Name> is too young.";
  `c.realm_index < 1` → "You need to cultivate before you can spar."; `npc.realm_index < 1` → "<Name> does not cultivate.";
  `abs(npc.realm_index - c.realm_index) > max_realm_gap` → "<Name> would not cross hands with someone so far from their own
  realm."; favor < min_favor → "<Name> does not know you well enough (favor N/10)."; cooldown → "You sparred with <Name>
  recently (N days)."
- `static func spar_enemy(npc: CharacterData, data: GameData) -> Dictionary`: `Karma.npc_enemy(npc, data)` plus
  `"spar": true` (no stones taken, already handled in combat.gd ~305) and `"friendly": true`.
- `static func after_spar(c: CharacterData, npc: CharacterData, data: GameData, won: bool, today: int) -> Dictionary`:
  practices every technique `c` knows that is not mastered and is not a cultivation method (check `TechniqueDef`'s kind/type
  field, the same test `Techniques.main_method` uses) for `practice_days` days each; records `"spar:" + npc.id`; returns
  `{favor: (win_favor if won else 0), practiced: PackedStringArray of technique names, levels: PackedStringArray of
  "<Tech> reaches level N"}`.

## Combat (`src/core/systems/combat.gd` ~306-311)
A defeat in an enemy with `"friendly": true` rolls no injury (sect trials keep their current behaviour: they set `spar` but
not `friendly`). Add one test in test_combat.gd: a friendly defeat never injures over 50 seeded fights.

## GameState
`func spar_with(npc_id: String) -> void` (next to `ask_pointers`): topic "family"; `_can_act()`; check (warning on failure);
`var won := fight_enemy(Mentorship.spar_enemy(npc, data))` (game_state.gd ~2052; read it first: it posts the combat report and
passes the fight's day). Then `after_spar`; add the favor via `npc_favor` capped at 100; post "You spar with <Name>. <Won:
'You win the bout.' / 'They win the bout.'> Your <techs> grow sharper." plus level lines, category "progress". Spars must not
count in LifeStats fights won/lost: check how sect trial spars are excluded (grep `spar` in game_state.gd / life_stats.gd) and
make sure the `spar` flag covers this too. Also `func check_spar(npc_id: String) -> String` for the UI.

## Tests
test_mentorship.gd: each check reason; spar_enemy has spar/friendly/lethal false; after_spar practices only non-method
unmastered techniques, gives favor only on a win, records the cooldown. test_game_session.gd: a QR3 player with Iron Fist
spars a QR4 NPC at favor 15: clock advances, no stones lost on a loss (seeded so it loses: or set the NPC very strong within
one realm), fights_won/lost unchanged, Iron Fist xp up; second spar the same day warns.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. UI entry is WU-059.
