# FOLK-021: Friends where they stand (systems)

Reference: Stardew Valley's heart events, which need the right place and weather, and Tale of Immortal's NPCs who teach
only when you are with them. Mechanics only.

Review notes (REVIEW.md 2026-11-07, 2nd run, and 2026-11-06) and the planner's 18:10 shot: Xiao Ling's rope-swing scene
("grey with rain now") played on a clear Dragon Boat Festival day; `check_friendships` tries every lesson NPC, so a lesson
can arrive while the teacher is in another region; FOLK-013's `any_villager` scenes need `Folk.is_villager` (already
checked: keep it); the friend card cannot show the gift's icon because `EventBus.friend_scene` sends only the item name.

## 1. Weather on friend scenes
- data/npcs.json `scenes[]` gets an optional `weather: [String]` (ids from `Weather.KINDS`:
  clear, cloudy, rain, snow, fog, storm). Document it in the file's `_doc`.
- `GameData._validate()`: `weather` must be a non-empty array of known weather ids.
- `Folk.scene_due(c, data, npc_id, favor, npc = null, region_id = "", weather = "")`: a scene with `weather` is skipped
  unless `weather` is in its list (so with the default "" a weather scene never plays). Skipped scenes stay unseen and the
  loop goes on to the next scene, so a waiting rain scene never blocks the later ones.
- `GameState._friend_scene` passes `Weather.of(data, current_region, GameClock.total_days)`.
- Tag the scenes whose text names weather: `xiao_ling_old_swing` (rain) and `villager_old_story` (read it; tag what it
  names); grep the other `scenes` texts for rain/snow/storm/fog/sun and tag any that need it. Do not rewrite texts.
- Update tests/unit/test_friend_scenes.gd: the swing scene is due at favor 40 only with "rain"; on "clear" the next
  scene of Xiao Ling (if any at that favor) or nothing.

## 2. Lessons only where the teacher is
- `GameState.check_friendships` (~4383) calls `_teach_lessons(id)` for every NPC with lessons. Add the guard inside
  `_teach_lessons`: skip unless `Npcs.region_of(npc, data) == current_region` (named NPCs have a home region). Talking
  to them (start_dialogue/chat) already implies presence, so those paths keep working.
- Test: a lesson-ready Hunter Ma (favor at the tier) with the player in misty_forest gets nothing from
  `check_friendships`; back in qingshi_village the lesson is taught once.

## 3. Signals the UI needs
- `EventBus.friend_scene` gains a 5th argument `gift_id: String` ("" when none). Update every `emit` and every connected
  method (hud.gd `_on_friend_scene`, the friend card's queue, tests, tests/sim/screenshot_first_hour.gd `--friend-scene`).
  Use `grep -rn "friend_scene" src tests` to find them all.
- New `signal lesson_taught(npc_id: String, npc_name: String, text: String, effect_line: String)` in event_bus.gd;
  `_teach_lessons` emits it after posting, with `effect_line` = the `Effects.apply` notes joined by ", " (may be "").
  No UI in this task (WU-479 shows a card); the existing log line stays.

## Acceptance
- tools/test.sh prints ALL CHECKS PASSED; the QA signal audits (no lambdas on the bus) still pass.
- No save change (scenes_seen and lessons_taught are unchanged). No balance run.
- Follow-ups for content if a scene text needs weather that no weather id covers.
