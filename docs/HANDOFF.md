# Handoff notes

Short-lived context for the next session. Update or trim it when you finish a session; durable rules belong in CLAUDE.md.

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
- New guard tests: `test_interactable_fuzz.gd` (every menu option in every region), `test_data_references.gd` (broken ids, unset flags), `test_steam_deck_layout.gd` (screens fit 1280x800), and a no-shared-key-or-button test in `test_help_screen.gd`.

## Lessons from this session
- After squash-merging a PR from the session branch, reset the branch to origin/main before the next task (`git fetch origin main && git checkout -B <branch> origin/main`), or the next PR conflicts with the squashed copy of the old commits.
- `tools/test.sh | tail` hides the exit status; check for `ALL CHECKS PASSED` before committing.

## Lessons from merging many agent PRs at once
- Nearly every PR conflicts on `docs/BACKLOG.md` and `docs/CHANGELOG.md`. Merge main into the PR branch, never rebase. Keep both sides' rows and lines, and check for **duplicate task ids** (agents often reuse an id; rename the newer one).
- After merging, rerun the full checks. Typical breakages were tests made stale by a newer rule (clans need an abode seat, tougher enemies since QA-007d, the intro story event at session start, choice encounters must set their `blocked_by_flag` on every choice) and two places placed at the same map position.
