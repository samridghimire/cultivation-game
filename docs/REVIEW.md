# Review log

The reviewer agent appends one entry per run. **Last reviewed commit** is where the next review starts
(`git log <sha>..origin/main`).

Last reviewed commit: 3c067b3

## Entries
- 2026-10-07: baseline set by the owner's session after the switch to planner/worker/reviewer. Main green (890 tests).
- 2026-10-07 (reviewer): reviewed b71190a..94480a0 (1396d1e agent team v2, 5a96250 C-005b, 94480a0 FH-001; [PLAN] commits skipped).
  Main green (890 tests). No BACKLOG/CHANGELOG edits by workers; no save-format changes.
  - C-005b: data valid and wired (deed_context on Peddler Hei, max_alignment deed gate supported). Bug: Blood Lotus Scout's
    kill reward was alignment -5 while every other Blood Lotus foe rewards positive alignment. Fixed to +10.
  - FH-001: matches spec (region id is `qingshi_village`, spec said `qingshi`; worker picked the right one). Bug: the
    "Use your <item>" newcomer hint could recommend a Blood Essence Pill (burns lifespan) or Blood Demon Pill (demonic).
    Fixed: harmful items (burn_lifespan or negative alignment) are skipped; test added. Spec step 4 (days-estimate
    wording) was optional and not done. Older saves lack `talked_elder_mo`, so the Elder Mo hint shows once more; harmless.
  - FH-004 (b7f586d, landed mid-review): matches spec, tests cover sense/flee/fight/Deadly/non-lethal. Note: until FH-004b
    adds the prompt, nothing answers `threat_sensed`, so lethal Dangerous foes met while exploring are effectively always
    skipped (pending_threat is cleared by the next explore). Only explore/encounter paths clear `pending_threat`; FH-004b's
    prompt should be modal so a stale threat can't be fought after travelling.
  - Fixed in one [REVIEW] commit; nothing filed. Main green (895+ tests).
- 2026-10-08 (reviewer): reviewed f313ee5..1cf2753 (FH-010, FH-011, QA-017, FH-002, FH-003, FH-004b, FH-015, FH-020, FH-005,
  FH-006, FH-012, FH-013, REL-001, QA-016, REL-002, FH-014, FH-021, FH-022, LW-002; [PLAN] commits skipped). Main green
  (947 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (FH-003's `deed_days` defaults to {}).
  - REL-002 bug (save loss): `SaveManager.current_slot` and the autosave were never reset between characters. Load
    character A from slot1, return to the menu, start a new character B: B's final death overwrote A's slot1 (and A's
    autosave) with a dead B. Fixed: SaveManager resets current_slot / autosave day on `session_started` (load_game sets
    the slot afterwards), and a final death only overwrites the autosave if this session wrote it or it holds a
    character of the same name. Test added. REL-002 had no test for the cross-character case.
  - FH-003, FH-004b, FH-002, LW-002, REL-001: match specs, tests present. LW-002 only reserves spouses/descendants from
    recruitment; other known NPCs (companions with favor) can be recruited, acceptable for part 1.
  - Fixed in one [REVIEW] commit; nothing filed.
- 2026-10-08 (reviewer, 2nd run): reviewed 1cf2753..6c7e35d (36 task commits: REL-003/004/007/009/010, QA-018/019/023/006b,
  LW-003/003b, FH-024/025/026, WU-001..009, STAT-001, GOAL-001, NS-001/002/003, GUIDE-001, SECT-003, EPI-001, ECON-002;
  [PLAN] commits skipped). Main green before and after (1020 -> 1024 tests). No BACKLOG/CHANGELOG edits by workers; no
  SAVE_VERSION change (`life_stats` and `milestones` default to {} / []). Two empty `claim` commits landed on main (RV-008).
  - Fixed (2 [REVIEW] commits): loading re-announced milestones (a month-end autosave is written before
    `check_milestones` runs; pre-GOAL-001 saves got a burst) -> awarded silently on load and re-synced to Steam; sect
    trial spars counted as fights won/lost; one AudioStreamPlayer meant every chime/click cut off breakthrough,
    lightning and combat sounds -> 6-voice pool, click before the action; arrival card over the final-death screen;
    "Saved" toast over the death screen; world events only expired at month end, so ended tournaments stayed joinable
    with the full prize for up to a month -> daily expiry; Cloud-Sea Aerie abode had no anchor_id; harvest_rogue_cultivator
    missed FH-026's x1.5 reward for its Foundation gate; stale "each bout tougher" doc. Tests added for each core fix.
  - Filed P0 RV-001..RV-008: save data-loss edges (newer-version save falls back to older .bak; crash between renames
    hides the slot), banner queue (milestones hide "Breakthrough!"), credits not gamepad-scrollable + missing third-party
    notices, journal tone/regressions/duplicate duty line, breakthrough pills not realm-gated (cheap pills beat NS-002's),
    tests that can't fail (world events, QA-019 tautology, economy sim buying for unavailable missions), NS-003 text
    mismatches, and the missing claim-cleanup workflow / over-broad cleanup script / empty claim commits.
- 2026-10-08 (reviewer, 3rd run): reviewed 6c7e35d..3c067b3 (REL-008, LW-002b/c, QA-022/024/025, MS-002, RV-001..005,
  RV-007, C-011, C-012, PROF-001, WU-011/012/014, ART-008, WE-001, NS-005; [PLAN], claim and earlier [REVIEW] commits
  skipped). Main green before and after (1071 -> 1074 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION
  change (`commissions` defaults to []; legacy `show_hints=false` maps to `hud_hints=0`).
  - Fixed in one [REVIEW] commit: (1) RV-005 tied breakthrough pills to their realm, but the HUD hint and journal still
    recommended every held breakthrough pill (a Core Forming Pill to a Qi Refining cultivator, a second pill after one
    was taken); Guidance now lists only pills Effects.check accepts. (2) PROF-001 paid material value x2 per unit even
    for items shops sell cheaper (22 recipes; Jade Marrow Pill bought for 600 paid 1100), so orders could be filled from
    a shop for stones plus free profession xp and sect contribution. New `commissions.max_price_fraction` (0.8) caps
    the per-unit reward below the shop price. Tests added for both.
  - RV-001/002/003/004/007 resolve their findings. LW-002b/c, MS-002, ART-008, WU-011/012/014, C-011/012, NS-005 match
    their specs.
  - Notes, not filed: `_expire_sect_calls` is flag bookkeeping in GameState (belongs in SectFactions); a clash while the
    call mission is on cooldown posts "calls on its senior disciples", which reads oddly for a senior. Sect clashes can
    kill the player's spouse/descendants in sects (only recruitment reserves them); acceptable as world drama but worth
    a design check. Commissions can't be delivered in-game until WU-013 lands.
