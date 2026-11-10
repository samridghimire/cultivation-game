# SEASON-007: Incense at the restored shrine

Role: systems. Planner default (small; DESIGN.md "Open design questions" (SEASON-007)). Reference: Stardew Valley's restored
community center giving a lasting daily benefit, mechanics only.

## Why
SEASON-006/GFX-081: four finished seasons restore Qingshi's Old Shrine (+5% qi in Qingshi), but the restored shrine's menu is
only a disabled "need" line, so a year's work ends in a number. Give it something to do every day.

## Spec
1. data/season_tasks.json `restoration` gains optional `incense`: `{item (items.json id), flag (unique world flag),
   days (int 1..3), bonus (0 < b <= 0.1), text (non-empty)}`; validate in GameData (SeasonTasks.validate or wherever
   restoration is validated) and document in the file's `_doc`. Data: `{"item": "village_mugwort", "flag":
   "shrine_incense", "days": 1, "bonus": 0.05, "text": "Incense smoke curls from the old shrine."}`; add the flag with the same
   bonus to qingshi_village `qi_flags` (the validator checks it like `qi_flag`). If region qi_flags only accept plain bools,
   make the qi lookup use `Effects.flag_active(flags, key, today)` so a timed flag `{"until": day}` works (check
   `GameState.region_qi_density` and its core helper; keep plain flags working).
2. Core: `SeasonTasks.can_offer_incense(c, data, flags, day) -> String` ("" = ok; else a reason: "The shrine is not restored
   yet.", "You have no Village Mugwort.", "Incense already burns today.") and `SeasonTasks.offer_incense(c, data, flags, day)
   -> String` (spends 1 item, sets `flags[flag] = {"until": day + days}`, returns the line).
3. GameState: `offer_incense() -> bool`, takes no time, posts the text plus "(+5% qi in Qingshi today)" with category
   "progress", emits player_changed. The Shrine interactable (src/world/interactables/shrine.gd `get_options`) shows
   "Light incense (1 Village Mugwort)" when restored (disabled with the reason when it can't), else the existing need line.
   Keep the menu focusable (an enabled first entry grabs focus as the other interactables do).
4. Today page (`Guidance.today_lines`): when restored and incense is not burning, one line "The old shrine is restored: light
   incense for +5% qi today."; when burning, "Incense burns at the old shrine (+5% qi)."
5. No save bump (world flags).

## Tests
- unit: can_offer reasons (not restored, no item, already burning), offer spends the item and sets the timed flag; qi density
  of qingshi_village is x(1.05 shrine) x(1.05 incense) on that day and back to x1.05 the next day.
- GameState integration: restored player with mugwort -> offer_incense true, item gone, message posted; second call false.
- validation: unknown item, bonus 0.2, qi_flags missing the incense flag -> errors.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. No balance run (sims do no season tasks); say so in the commit.
