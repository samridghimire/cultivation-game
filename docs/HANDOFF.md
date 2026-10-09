# Handoff notes

Short-lived context for the next session. Update or trim it when you finish a session; durable rules belong in CLAUDE.md.

## State on 2026-10-09 (planner, 08:15 UTC)
- 10 tasks landed since 06:20 (ENC-003, EXPL-001, WU-061/070/073/075, C-018/049, QA-046/050). Claimed: WE-002,
  GUIDE-015, C-046 (3h old), WU-074 (claimed before its dependency EXPL-002 exists; it may land partially). Reviewer (to
  4319bc4) fixed three small things in one commit and filed nothing.
- C-049's Bog Lily recipe scroll has no source: QA-051 adds a recipe-scroll obtainability test and fixes the gaps.
- New theme "a target and a payoff for exploring": GUIDE-016 + WU-078 (deeper paths announce themselves and are found),
  BOUNTY-001 (spec file) + WU-076 + C-052, TRAV-006 + C-051 + WU-080 (road encounters), LETTER-001 + C-053 + WU-081
  (letters from friends), WU-077 (first-hour screenshot pass at 1280x800), WU-079 (focus audit), C-055 (help pages).
- Local `main` was again diverged from origin/main (50/50); the planner worked on a branch made from origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 06:20 UTC)
- 16 tasks landed since 04:15 (REALM-002, WU-067/068/069/071, C-043/044, NS-007, QA-041/047, ITEM-002, GUIDE-014,
  SEASON-002/003, TRAV-004/005). Claimed: WU-070, QA-046, C-046. Reviewer (to e7f99aa) filed nothing.
- QA-041: from month 7 the curious sim only explores and runs missions, but its policy never crafts/travels/gifts, so
  QA-048 teaches it before we trust that. NS-007 says the first-hour section of tools/balance.sh took >35 min: QA-049.
- New theme "the long middle": ENC-003 (met encounters fade), EXPL-001/C-048 (deeper paths after N explore days),
  WE-002/C-047/WU-072 (festivals with a favor bonus), GUIDE-015/C-050 (discovery rumors), EXPL-002/WU-074 (region
  progress), MS-005, WU-073 (undiscovered mark), WU-075 (herb seasons in the inventory), C-049 (high-region seasons).
- Local `main` was a shallow clone that looked diverged; `git fetch --unshallow` fixed it (no reset needed).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 04:15 UTC)
- 14 tasks landed since the last planner run (GUIDE-012/013, RV-014, SEASON-001, TRAV-002/003, NS-006, WU-060/063/065/066, C-038/042,
  QA-039). REALM-002, WU-064 and QA-041 are claimed (~04:00). The reviewer's last run (to d098150) filed nothing.
- New theme: reward curiosity about places (GUIDE-014 unexplored roads, TRAV-005 + C-046 + WU-070 a discovery on the first
  exploration of each region, TRAV-004 sect home regions, WU-061 spec'd, QA-047 save/load check) and seasons worth noticing
  (SEASON-002 "in season now", SEASON-003 milestone, WU-067 spec'd, WU-071, C-044 spec'd). WU-068 (ChoiceMenu refit on
  resize, reviewer note), WU-069 (look at the breakthrough effect), C-045 (gear past Core Formation, NS-006 Follow-up),
  QA-045 (why the first Foundation year is so gentle, QA-039 Follow-up), QA-046 (refresh the drifted baseline).
- Local `main` had diverged from origin/main again (old PR-era history); reset to origin/main (backup branch kept locally).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 10:10 UTC)
- 14 tasks landed since 00:15 (WU-044/045/054/059/062, C-037/039/040/041, RV-013, MENTOR-001, SPAR-001, TRAV-001, QA-043).
  GUIDE-012, QA-040 and WU-061 are claimed.
- New: RV-014 (reviewer notes: spars burn no talismans and drain no lifespan; pointers "share" only a technique the senior
  knows better), TRAV-002/003 + WU-064 + C-043 (first sight of a region, backfilled visits for old saves), ITEM-002
  (`Items.has_known_source`, QA-043 Follow-up), WU-063 (breakthrough effect), WU-065 (Deck pass), WU-066 (spar report),
  WU-067 + C-044 (seasonal herbs, after SEASON-001), C-042 (corpse refiner fight, C-037 Follow-up), QA-044 (do pointers
  and spars matter?). C-039's Follow-up (a bare player is 0% vs Foundation foes) needs no task: nobody reaches Foundation bare.
- Local `main` had diverged from origin/main again (old squash history); reset to origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 00:15 UTC)
- 13 tasks landed since 22:15 (QA-029, SECT-004/005, WU-056/057/058, C-031, C-035, C-020, QA-038, RV-012, GUIDE-011,
  KARMA-001). The systems queue was empty. QA-021 is claimed (00:00).
- New theme: people you learn from (MENTOR-001 pointers, SPAR-001 spars; specs in docs/specs; UI WU-059, hints GUIDE-012,
  audit QA-040), visited regions (TRAV-001, WU-061), seasons (SEASON-001 seasonal herbs, WU-060 tint check, WU-062 season
  banner), lecture surfacing (GUIDE-013, C-041), reviewer notes as RV-013 (year review names the year that ended, "+0 qi"
  lecture line, core no longer reads src/world), C-039 (fair Foundation fights in the 3 starter regions), C-040 (rank
  `min_stage` for two HARD trials), REALM-002 (secret realm entry item), QA-041 (36-month curious sim), QA-042 (Core year sim).
- Local `main` was again unrelated to origin/main (shallow clone); reset to origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 20:15 UTC)
- 18 tasks landed since 18:15 (CMB-002, WU-036/039..043, C-022/023, GUIDE-008/009, GOAL-002/003, MSG-002, REL-011, QA-020/033/036).
  CMB-003 and C-024 are claimed (~20:04 / 19:26).
- New: RV-010/RV-011/MSG-003/CMB-004/YEAR-002 from the reviewer's notes, GOAL-004 (profession goal), GUIDE-010 (new roads
  notice); WU-044 (HUD goal line), WU-045 (inventory "sells at / used in"), WU-046/047 (hit sounds, line colors after CMB-003),
  WU-048..050, WU-053; C-025 (recipes for unused beast materials), C-028 (help: fights, selling), C-029 (quiet-day lines),
  C-030 (milestones); QA-037 (combat text audit), QA-038 (shop fuzz).
- Local `main` was again unrelated to origin/main; planner worked on a branch made from origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 18:15 UTC)
- 15 tasks landed since 16:20 (FH-030, CULT-001, MSG-001, STAT-002, WU-032..035, WU-037, WU-038, ECON-001b, C-016, C-019,
  C-021, QA-034). The first-hour audit's fix list is complete. CMB-002 and QA-033 are claimed (~18:05).
- New theme: fights with flavor (CMB-003, WU-043 spoils, WU-036 playback), loot worth money (C-023 beast materials,
  GUIDE-009 sell hint, WU-039 shop tabs, WU-040 sell all), goals past the first hour (GOAL-002 breakthrough odds in the
  journal, GOAL-003 mid-game goals, WU-041 days-to-next-layer on the HUD), fair gates (C-024: Foundation trials, the
  tournament_bout ring at QR1 vs a QR6 foe, vengeful_brother), MSG-002, QA-035 (economy sim monthly sect), QA-036.
- QA-029 (curious-player sim) is now the QA worker's top task: its Follow-ups should drive the next first-hour fixes.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 16:20 UTC)
- 16 tasks landed since 14:15 (CMB-001, BT-001, MED-001, EXP-001, YEAR-001, GUIDE-007, WU-024/027/028/029/030/031, C-017,
  RV-009, QA-028, QA-030). The "say what an action will do" theme is complete. ECON-001b is claimed (16:09).
- A first-hour audit found: the first sect hint points a mortal at the Blood Lotus Sect (the only sect that takes mortals),
  the technique hint at a manual a newcomer can't afford, no clear first goal, no confirms on leave sect / feed artifact /
  burn-lifespan pills, the Qingshi merchant buys nothing, and raw numbers in grudge/favor/alignment messages.
- New: FH-030 (spec), CULT-001, MSG-001, STAT-002, CMB-002, GUIDE-008; WU-032 (spec), WU-033..038; C-019 (spec), C-020..022;
  QA-033, QA-034.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 14:15 UTC)
- 14 tasks landed since 12:20 (GUIDE-004/005/006, RECAP-001 + WU-025, MS-004, WU-021/022/023/026, C-015, NS-002b, NS-004,
  QA-031). Systems and world-ui queues were empty again; restocked around one theme: say what an action will do before the
  player picks it (BT-001 breakthrough odds, MED-001 meditation preview, EXP-001 explore outlook, all shown via WU-027's
  ChoiceMenu `description` in WU-029/WU-030), plus WU-028 (hide HUD behind modals), YEAR-001 + WU-031 (yearly recap),
  GUIDE-007 (untried features), C-016/C-017/C-018, QA-032.
- RV-009 has a WIP branch (claimed 10:26, never landed); the row tells the next content worker to start from d814d2d.
- origin/main history was rewritten at some point: a fresh clone's local `main` can be unrelated to origin/main. Reset to
  origin/main (`git reset --hard origin/main` on a clean tree) before working.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 12:20 UTC)
- 17 tasks landed since 10:20 (RV-005b/006, ENC-002 + C-014 min_stage gating, GUIDE-003, MS-003, PROF-002, SF-002, C-013,
  QA-027, REL-005 export presets, WU-015..020). Systems and world-ui queues were empty again; restocked.
- RV-009 (gathering trips come back empty) is still unclaimed and stays the content worker's top task.
- New: C-015 (fair fights where they appear, spec; supersedes QA-007f), MS-004 (backfill veteran milestone counters),
  GUIDE-005 (outgrown cultivation method hint), CMB-001 + WU-024 (why you lost), WU-021 (screenshot every screen, spec),
  WU-022 (gamepad-readable disabled reasons), WU-023 (NPC labels vs places), GUIDE-004/006, RECAP-001 + WU-025, WU-026
  (text size), REL-011 (Steam upload prep), QA-030 (mid-game fuzz), QA-031 (save round-trip soak).
- Workers can now run fast: keep >= 6 per role. The owner's three urgent questions (pacing, first fights, ascension) are
  still open.

## State on 2026-10-08 (planner, 10:20 UTC)
- 21 tasks landed since 06:15 (RV-001/004/005/007, PROF-001 + WU-013 commissions, C-011 errands, C-012, LW-002c, ART-008,
  WE-001, WU-010..014, NS-005, QA-024..026, QA-007g, ECON-001). Systems and world-ui queues had run dry; restocked.
- New: ENC-002 (encounter `min_stage`, sim measures missions at their real gate) -> C-014 (gate the 0-14% Qi Refining
  cliff); GUIDE-003 (journal Opportunities + Errands, spec), RV-005b (herb bonus no longer blocks the realm pill), SF-002,
  PROF-002, MS-003; WU-015 (journal on the gamepad's left trigger), WU-016..020; QA-027 (sim covers realm/inheritance/
  event foes), QA-028, QA-029 (a "curious player" first-hour sim); C-013 help pages, ECON-001b, NS-007.
- RV-009 (gathering trips come back empty ~50-88%) is the content worker's top task.

## State on 2026-10-08 (planner, 06:15 UTC)
- 20 tasks landed since 04:15 (journal, milestones UI/progress, epilogue, music, title art, sect clashes, NS-003 region,
  RV-002/RV-003...). Reviewer fixes RV-001, RV-004..RV-007 are on top.
- New "playable and fun" group: PROF-001 (crafting commissions, spec in docs/specs/PROF-001.md) + WU-013 (its UI), C-011
  (favor errands in named NPCs' dialogue), C-012 (workshops in 3 more regions, beast tide defence), LW-002c (sect call
  deadline), ART-008 (appraisal shows win %), WE-001, WU-010..014, QA-026.
- RV-008 done: .github/workflows/cleanup-claims.yml is on main (hourly), the script only deletes stale *claim* branches, and
  workers rebase with `--force-rebase` so empty claim commits stop landing.
- New open questions in DESIGN.md: (RV-005) one breakthrough pill per attempt, (PROF-001) lapsed commissions.

## State on 2026-10-08 (planner, 04:15 UTC)
- 13 more tasks landed (FH-024/025, WU-001..003, STAT-001, GOAL-001, REL-007, REL-009, QA-019, NS-001/002, LW-003b). The
  reviewer's last reviewed commit is 1cf2753, so these are not reviewed yet.
- New: GUIDE-001 + WU-007 (journal, spec in docs/specs/GUIDE-001.md), SECT-003 (duty reminders), FH-026 (rank-1 rogue
  missions were Deadly through Qi Refining), WU-009 (no arrival card over the respawn screen), EPI-001 + WU-004 (epilogue),
  MS-002 (milestone progress), REL-010 (save on Steam Deck suspend), NS-002b/NS-006 (late content), QA-025.
- The cloud clone's local `main` can be an unrelated shallow history; work from `origin/main` (e.g. a local branch made from
  it) and push `HEAD:main`.

## State on 2026-10-08 (planner, 02:30 UTC)
- 19 tasks landed in two and a half hours (all FH-* first-hour tasks, REL-001..004, LW-002 part 1, LW-003, QA-016, QA-018).
  Workers are fast: keep every role stocked with ~6 ready tasks and spec the top ones.
- New task groups: FH-024/025 (newcomer-safe missions, explore for a week), STAT-001 + GOAL-001 + REL-009 (life record,
  milestones, Steam platform stub), REL-007 (crash-safe saves), WU-001..008 (save toast, sect standings, arrival card,
  epilogue, joinable-event markers, milestones UI, journal, title art), QA-019..024.
- Claim branches are not being deleted after landing (remote branch deletion is refused by the agents' permissions). A
  `claude/<id>-*` branch for a task in Done is not a claim. Only the owner can clean them up.

## State on 2026-10-07 (planner, 23:30 UTC)
- BACKLOG.md was rebuilt: 242 finished rows moved to docs/BACKLOG_DONE.md; new task groups FH-* (first hour), REL-* (Steam
  basics: autosave, final death, audio, credits, export), NS-* (content past Core Formation), QA-016..020. Specs in docs/specs/.
- Audits found the first hour's HUD hint only says "gather qi", the Qingshi workshop has no ingredients, lethal 15-50% fights are
  forced, and content stops at Core Formation. The owner's three most urgent questions are at the top of DESIGN.md's open list.

## State on 2026-10-07 (evening)
- **New team design:** an Opus planner, an Opus reviewer and six Sonnet workers. Workers land straight on main and there are no
  PRs. See docs/AGENTS.md. The old PR/integrator flow piled up ~200 PRs that the owner merged by hand.
- main is green (890 tests). Fixed: the load screen logged an engine error whenever a save existed (UIStyle.button connected an
  empty Callable). Cloud runners have no saves, so the tests missed it; test_load_screen_with_saves.gd now covers it.
- Workers must not edit BACKLOG.md or CHANGELOG.md; the planner keeps them in sync from `[ID]` commit subjects.
- docs/REVIEW.md tracks the last commit the reviewer checked.

## State on 2026-10-04 (second session, in progress)
- **main is green** (`tools/test.sh`: 823 tests, ALL CHECKS PASSED). PRs #159-#184 are merged (one task per PR, squash-merged). No open PRs.
- Done this session: G-005d, W-004g/h, QA-007e, G-008f, ART-005b, G-006b, BODY-001c, FAM-005d, G-011b/c, AUC-001b, UI-010b, DEM-001, LW-001/LW-001b, UI-008b, UI-009b, C-009, C-010, RIV-002/003, W-006b/c, VIS-004/005, W-005e, FAM-004c, FAM-008b, FAM-006b/c, FAM-007d.
- Next good tasks: FAM-009d, FAM-010, FAM-011, FAM-013b, G-006c, W-005c/f, ART-003b/c/d, BEAST-001b/c/d, UI-002b, UI-003c, QA-014.
- New since the last handoff: sect ranks need trial fights (every rank above the first), world events roll monthly, the player has a named rival (CharacterData.rival), grudge holders ambush on the road, devouring after beating a `cultivator`-tagged enemy, an `inheritance` and an `auction` place type.

## Waiting on the owner (don't decide these yourself)
- **C-009, the first fights**: a newcomer with a starter technique and an iron sword beats a Mist Wolf ~4% of the time (QA-007d realm_training). See the DESIGN.md open question.
- **F-005d, cultivation pacing**: a sensible player reaches Core Formation at age ~20, so lifespan and pills barely matter. See the DESIGN.md open question. `tests/sim/simulate_life.gd -- 20 1.0 1 real` shows it.
- **QA-007g / QA-007f, enemy tuning**: several foes sit far from the 60-85% win-rate target at their own realm. Run `tests/sim/simulate_combat.gd` before and after changing anything.

## Tools added this session
- `TEST_ONLY=<substring> tools/godot.sh --headless --path . -s res://tests/run_tests.gd` runs one test file.
- The runner reseeds `GameState.rng` per test. `TEST_SEED_SALT=x` changes the seeds, so a test that fails under some salt is flaky; fix it rather than the seed.
- `FUZZ_LOG=1 TEST_ONLY=fuzz ...` prints every option the interactable fuzz invokes and every message posted. Grep the messages for odd wording.
- `xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 --resolution 1280x800 -s res://tests/sim/screenshot_regions.gd` saves a PNG of every region (software GL works in the cloud container), so art and layout can be checked by eye.
- Same command with `-s res://tests/sim/screenshot_screens.gd` saves a PNG of every HUD screen for a mid-game character (`user://screenshots/screens/`), to eyeball layout at 1280x800 (WU-021).
- `tools/balance.sh` (about 5 minutes) runs the first-hour (seeds 1-10), combat and economy sims with fixed seeds and rewrites `docs/balance_baseline.txt`; `tools/balance.sh --check` diffs a fresh run against it and exits 1 on any change. Not part of test.sh: after tuning data/*.json, re-run it and commit the new baseline with your change.
- New guard tests: `test_interactable_fuzz.gd` (every menu option in every region), `test_data_references.gd` (broken ids, unset flags), `test_steam_deck_layout.gd` (screens fit 1280x800), and a no-shared-key-or-button test in `test_help_screen.gd`.

## Lessons from this session
- After squash-merging a PR from the session branch, reset the branch to origin/main before the next task (`git fetch origin main && git checkout -B <branch> origin/main`), or the next PR conflicts with the squashed copy of the old commits.
- `tools/test.sh | tail` hides the exit status; check for `ALL CHECKS PASSED` before committing.

## Lessons from merging many agent PRs at once
- Nearly every PR conflicts on `docs/BACKLOG.md` and `docs/CHANGELOG.md`. Merge main into the PR branch, never rebase. Keep both sides' rows and lines, and check for **duplicate task ids** (agents often reuse an id; rename the newer one).
- After merging, rerun the full checks. Typical breakages were tests made stale by a newer rule (clans need an abode seat, tougher enemies since QA-007d, the intro story event at session start, choice encounters must set their `blocked_by_flag` on every choice) and two places placed at the same map position.
