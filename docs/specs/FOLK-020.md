# FOLK-020: Friends who teach

Role: systems. Reference: Stardew Valley's friendship rewards (a villager who likes you mails you a recipe) and Tale of
Immortal's NPCs who pass on a skill to someone they trust. Mechanics only, never names, story or art.

## Why
Friendship tiers (family.json `folk_tiers`) already give a one-off gift and FOLK-013/C-316 friend scenes add warmth, but a
close villager never changes how you play. The first hours should make befriending Elder Mo, Xiao Ling or Hunter Ma feel
worth it: each named villager teaches one lasting thing once you are close.

## Data (npcs.json)
Optional per named NPC: `lessons`: `[{tier: int (index into family.json folk_tiers, >= 1), text: String (1-2 sentences,
<= 220 chars, may use {name} and {player}), effects: Dictionary (Effects keys, see below)}]`, at most 2 per NPC, tiers
strictly rising.

Allowed effect keys (everything else is a validation error, so lessons stay small and lasting): `learn_recipe`,
`learn_technique`, `profession_xp`, `attributes` (each value 1..2), `dao_insight`, `practice_days` (1..10), `items`.
Document the field in npcs.json `_doc` and validate it in `GameData._validate()` (tier in range, text non-empty and short,
effects pass `Effects.validate` and use only the allowed keys).

Put ONE placeholder lesson in data so the feature is testable end to end: Hunter Ma at tier 2 (Close friend) with
`{"practice_days": 5}` and a 1-sentence text about reading tracks and footwork. C-321 writes the real lessons.

## Core (src/core/systems/folk.gd)
- `static func lessons_of(data: GameData, npc_id: String) -> Array` (the list or []).
- `static func due_lessons(data: GameData, npc_id: String, tier: int, taught: Dictionary) -> Array[Dictionary]`: lessons
  with `tier <= tier` whose key `"<npc_id>:<index>"` is not in `taught`. Pure.
- `static func lesson_line(lesson: Dictionary, npc_name: String, player_name: String) -> String`.

## State
`CharacterData.lessons_taught: Dictionary` (`"<npc_id>:<index>" -> day`), in `to_dict`/`from_dict` with default `{}`.
No SAVE_VERSION bump needed (default handles old saves); add a line to the every-field save test.

## GameState
In the existing tier-up hook (`game_state.gd` ~4282, where `Folk.new_tiers` hands out the tier gift) and also once in
`chat()` / when a named NPC's dialogue opens (so a player who was already at the tier before this feature still gets it):
for each `Folk.due_lessons(...)`, apply `Effects.apply`, record it in `lessons_taught`, post the line with category
`"people"` and a second "progress" line naming what was learned (reuse the Effects result strings). One lesson per NPC
per day at most; never during a festival contest card (queue like friend scenes do, `_pending_friend_scenes`).
Add `func lessons_for(npc_id) -> Array[Dictionary]` returning `[{tier_name, taught: bool, text_if_taught}]` for UI (WU-477).

## Tests (tests/unit/test_folk_lessons.gd + one in test_game_session.gd)
- `due_lessons` returns nothing below the tier, the lesson at the tier, nothing once taught.
- Validation rejects tier 0, an unknown effect key (e.g. `qi`), `attributes` of 3, a 300-char text, falling tiers.
- GameState: Hunter Ma at favor just below Close friend -> gift raises it -> practice days applied once, `lessons_taught`
  saved and reloaded, a second chat does not teach again; a save made before the feature with favor already at Close
  friend teaches on the next chat.

## Acceptance
- `tools/test.sh` ALL CHECKS PASSED. No balance run (one placeholder lesson; C-321 decides the real ones).
- Follow-ups: list any named NPC whose dialogue path skipped the hook.
