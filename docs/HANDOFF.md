# Handoff notes

Short-lived context for the next session. Update or trim it when you finish a session; durable rules belong in CLAUDE.md.

## State on 2026-10-04 (end of session)
- **main is green** (`tools/test.sh`: 758 tests, ALL CHECKS PASSED) and **there are no open PRs**. Every agent PR up to #157 is merged; #152 was closed as a duplicate of #151.
- BACKLOG.md statuses are accurate. The highest-value *Ready* tasks left: DEM-001 (devouring), LW-001 (world events), C-009 (first hour in Qingshi Village), C-010 (medicine content), RIV-002/003 (rivals, revenge ambushes), UI-002b, UI-009b, BODY-001c (body tempering at abodes).

## Waiting on the owner (don't decide these yourself)
- **F-005d, cultivation pacing**: a sensible player reaches Core Formation at age ~20, so lifespan and pills barely matter. See the DESIGN.md open question. `tests/sim/simulate_life.gd -- 20 1.0 1 real` shows it.
- **QA-007g / QA-007f, enemy tuning**: several foes sit far from the 60-85% win-rate target at their own realm. Run `tests/sim/simulate_combat.gd` before and after changing anything.

## Tools added this session
- `TEST_ONLY=<substring> tools/godot.sh --headless --path . -s res://tests/run_tests.gd` runs one test file.
- The runner reseeds `GameState.rng` per test. `TEST_SEED_SALT=x` changes the seeds, so a test that fails under some salt is flaky; fix it rather than the seed.
- `FUZZ_LOG=1 TEST_ONLY=fuzz ...` prints every option the interactable fuzz invokes and every message posted. Grep the messages for odd wording.
- `xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 --resolution 1280x800 -s res://tests/sim/screenshot_regions.gd` saves a PNG of every region (software GL works in the cloud container), so art and layout can be checked by eye.
- New guard tests: `test_interactable_fuzz.gd` (every menu option in every region), `test_data_references.gd` (broken ids, unset flags), `test_steam_deck_layout.gd` (screens fit 1280x800), and a no-shared-key-or-button test in `test_help_screen.gd`.

## Lessons from merging many agent PRs at once
- Nearly every PR conflicts on `docs/BACKLOG.md` and `docs/CHANGELOG.md`. Merge main into the PR branch, never rebase. Keep both sides' rows and lines, and check for **duplicate task ids** (agents often reuse an id; rename the newer one).
- After merging, rerun the full checks. Typical breakages were tests made stale by a newer rule (clans need an abode seat, tougher enemies since QA-007d, the intro story event at session start, choice encounters must set their `blocked_by_flag` on every choice) and two places placed at the same map position.
