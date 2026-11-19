# GUIDE-267: Who wants the fight

Role: systems. Reference: Stardew Valley's help-wanted board (mechanics only: the job names who asked).
Source: planner shots 2026-11-19 00:10. Azure Peak's Next steps card reads "Easy fight: Stair Crag Goat · 100%", the
marsh "Easy fight: Boardwalk Leech Swarm · 100%", the market "Easy fight: Stray Warehouse Dog · 100%". These fights are
C-391/C-392 chores (deeds with an `enemy`, given by Hall Steward Qiu, the Reed Hall Overseer, the Porters' Foreman). The
short HUD form (`Guidance._short_fight`, guidance.gd ~785) drops "Chore for <giver>:" first, so a newcomer sees a beast name
with no beast on the map and no idea whom to ask.

## Change
1. `_short_fight`: keep the giver when the line came from a chore, in a short form: "Easy fight: Stair Crag Goat (ask Steward Qiu) · 100%".
   Drop order when it does not fit SHORT_HINT_CHARS (and SHORT_FAR_CHARS for another region): region first, then
   "(ask <giver>)" shortened to the giver's last word/title ("(ask Qiu)"), then the giver. Use the NPC/deed-giver display name
   the world uses (check how the chore's `context` maps to a place/NPC: data/regions.json place `deed_context` or similar).
2. New `Guidance.fight_target(c, data, flags, region_id, today) -> Dictionary` mirroring `goal_target`'s shape:
   `{"npc": id}` or `{"place": place_id}` for the first Easy/Fair fight entry the HUD shows when it is a chore in **this**
   region (the giver), `{"place": id}` for an explore fight at a place here; `{}` otherwise. Pure, no Nodes.
   WU-570 (world-ui) will use it for a second, smaller marker.
3. Long form (journal) unchanged except it already names the giver; check it does.

## Tests
- Azure Peak, mortal, day 0: the HUD short fight line contains "Qiu"; `fight_target` returns the steward's place/npc.
- Qingshi day 0: the Wild Boar chore line names Headman Zhou (or "Zhou") and fight_target points at him.
- A line too long for SHORT_HINT_CHARS loses the region before the giver.
- An explore fight (no chore) short line is unchanged.

## Acceptance
Render `-- --region=azure_peak,withered_bone_marsh,fallen_star_market` at 1280x800 and open them: each card names who to ask.
Wording only: no balance check. `tools/test.sh` green. < ~250 lines.
