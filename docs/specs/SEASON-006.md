# SEASON-006: The year's work restores the shrine

Role: systems. Reference: Stardew Valley's community bundles restoring a building room by room, mechanics only.

## Why
SEASON-005 gives three village tasks per season with a one-off reward, but finishing them leads nowhere. A long goal the
village can see grow makes the first year feel like it builds something.

## Design (planner default, small; recorded in DESIGN.md "Current systems")
Qingshi's old roadside shrine is in ruins. Each season whose three tasks you finish adds one stage to its repair. Four
stages (any four completed seasons, not necessarily in a row or in one year) restore it. The restored shrine raises
Qingshi's qi density a little and the village says so. The stages are data, so other villages can get their own later.

## Spec
1. **Data.** data/season_tasks.json gets a top-level `restoration`: `{"region": "qingshi_village", "name": "the old
   shrine", "stages": [{"flag": "shrine_stage_1", "text": "..."}, ... 4 entries], "qi_flag": {"flag": "shrine_restored",
   "bonus": 0.05, "text": "the restored shrine"}}`. Document it in the file's `_doc`; validate in SeasonTasks.validate
   (region exists, 1..8 stages, non-empty unique flags and texts, bonus 0 < b <= 0.1). Absent = no restoration.
2. **Core (src/core/systems/season_tasks.gd).** When `note()` marks a season `done`, it also appends the season key to a new
   CharacterData field `seasons_completed: Array[String]` (unique; to_dict/from_dict with default []), and returns one more
   line: the next stage's `text` (stage index = number of completed seasons, capped at the stage count). New pure functions:
   `restoration_stage(c, data) -> int` (0..stages), `restoration_flags(c, data) -> Array[String]` (flags of the stages
   reached, plus `qi_flag.flag` once all stages are reached). GameState, where it pays the season reward, sets those world
   flags (true) so the existing region `qi_flags` mechanism and the world builder can read them.
3. **Qi.** data/regions.json qingshi_village gets `"qi_flags": [{"flag": "shrine_restored", "bonus": 0.05, "text": "the
   restored shrine"}]` (the mechanism exists: QI-001, region_qi_density). Use the same numbers as `restoration.qi_flag`
   (the validator checks the region lists that flag).
4. **Seen in the game.** `Guidance.today_lines` (or the season-task lines WU-462 shows) gets one line while the shrine is
   unfinished and a season set is still open: "The old shrine: 1 of 4 stages repaired." After the last stage the message log
   says the shrine stands again and names the qi gain. Drawing the shrine is GFX-081 (world-ui), not this task: only expose
   `restoration_stage` for it.
5. Save: `seasons_completed` defaults to [] (older saves start at stage 0). No SAVE_VERSION bump needed if from_dict
   defaults it; if you bump, add the fixture save (CLAUDE.md rule 5).

## Tests
- Completing a season set twice in the same season counts once; completing spring and summer gives stage 2 and both flags.
- Four completed seasons set `shrine_restored`; standing in Qingshi, `GameState.region_qi_density()` (game_state.gd ~2907, current region) is 1.05x the value before.
- Validation rejects an unknown region and a bonus of 0.5.
- Save round-trip keeps `seasons_completed`; a dict without it loads as [].
- GameState integration test: finish a season's three tasks through the real actions (or `SeasonTasks.note` + the GameState
  reward path) and see the stage line posted.

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. A +5% qi in one village after a year of tasks does not change the balance sims (the sims do
not do season tasks): no `--check` run; say so in the commit.
