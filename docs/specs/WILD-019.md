# WILD-019: Great beasts you have outgrown step aside

Role: systems. Reference: Tale of Immortal's region danger tiers (a region's big monsters step up with your realm),
mechanics only.

## Why
Planner shot 2026-11-06 12:10 (`--great --region=misty_forest`, a Foundation Early player): "Great Old Tusker (Weak)" walks
the forest, the Today line headlines "the Old Tusker roams" and the calendar marks its day, though it is a Qi Refining beast
the player beats 100 in 100. WILD-018 gave roamers `max_realm` and return beasts their own `min_realm`, but the great-beast
slot has no upper bound, and a Foundation player who never fought the first beast can never meet the return beast.

## Spec (src/core/systems/wildlife.gd, data/regions.json `_doc`, GameData/Wildlife.validate)
1. `roamers.great` and `roamers.great.return` take optional `max_realm` (realm id; validated: known, not below that level's
   `min_realm`). Document both in the regions.json `_doc` sentence for `great`.
2. One helper decides the slot's beast for a character: `static func great_enemy_for(c: CharacterData, data: GameData,
   region_id: String) -> String` (returns "" when nothing walks for this character):
   - first beast if `c` has not beaten it (`c.great_beasts`) and `c.realm_index <= max_realm` (or no max_realm);
   - otherwise the `return` beast if there is one and `c` is within its `min_realm`..`max_realm` (absent = no bound). The
     return beast now also walks for a player who outgrew the first beast without beating it (the first one's trophy stays
     unearned; that is fine);
   - otherwise "".
   With `c == null` (old callers / sims without a character) keep today's behaviour.
3. `_great_walks`, `active_great_enemy`, `rumor_of`, `next_great_day`, `tracks_today`, `great_roamer` and `bait_item` go
   through it, so the world, the Today line, GUIDE-209's arrival line, the calendar (VillageCalendar), tracks (WILD-012),
   bait (WILD-015) and the journal road goal (GOAL-008/011/012) all agree. `rumor_of` returns the return beast's rumor when
   the return beast is the one that walks for `c`.
4. No data change in this task (C-317 sets `max_realm` and retunes the return beasts), so existing play is unchanged until then.

## Tests (tests/unit/test_wildlife*.gd or a new test_great_tiers.gd)
With a fixture region (or real data plus a patched copy of the def):
- first beast with max_realm qi_refining: a qi_refining player meets it; a foundation player does not, and meets the return
  beast instead (if its min_realm allows); next_great_day / tracks_today agree; rumor_of gives the return's rumor.
- a foundation player who has beaten the first beast and is above the return's max_realm: nothing walks, next_great_day -1,
  arrival line has no "roams".
- validation rejects an unknown max_realm and one below min_realm.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED. No balance run needed (no data change); say so in the commit.
