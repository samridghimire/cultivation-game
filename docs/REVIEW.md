# Review log

The reviewer agent appends one entry per run. **Last reviewed commit** is where the next review starts
(`git log <sha>..origin/main`).

Last reviewed commit: 1b1df8b

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
- 2026-10-08 (reviewer, 4th run): reviewed 3c067b3..9f0fade (WU-010, QA-026, WU-013, ECON-001, QA-007g; [REVIEW] commits skipped).
  Main green (1079 tests). No BACKLOG/CHANGELOG edits by workers; no persistent-state or SAVE_VERSION changes. WU-010,
  QA-026, WU-013 and QA-007g match their specs; no code fixes needed.
  - Filed P0 RV-009: ECON-001 hit its income target by making gather rolls miss 73-96% of the time at the higher
    places (min_realm-locked entries count as misses), so a pre-Core 20-day Thunder-Struck Terraces trip finds nothing
    ~88% of the time. Cut income through item value / yields instead, and add a miss-chance test.
  - QA-007g: purge_demonic_cultivator gated at Foundation stage 1 (69% win). Rogue Cultivator now 87%, slightly above
    the 60-85% band; acceptable.
  - WU-010: swapping players on each mood change and killing the running tween handles rapid region hops; focus pause
    covers both players. WU-013: entries are index-bound but the menu rebuilds after each `keep_open` action, so the
    indices stay valid after a delivery; gamepad focus comes from ChoiceMenu.
  - Notes, not filed: a disabled Deliver label repeats the count ("(you have 0) (You need 3 more ...)") and gets long
    on narrow screens; QA-026's "disciple" journal case holds no missions, so the missions section is not exercised.
- 2026-10-08 (reviewer, 5th run): reviewed 9f0fade..de04a40 (RV-006, RV-005b, SF-002, WU-018, WU-019, QA-027, WU-020,
  WU-017, ENC-002, MS-003, C-013; [PLAN]/[REVIEW] commits skipped). Main green before and after (1099 tests). No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (`breakthrough_pill` defaults to "", new LifeStats keys
  default to 0).
  - Fixed in one [REVIEW] commit: WU-020 put Family on the right trigger (a JOY_AXES entry), but
    `InputConfig.binding_label` only read gamepad buttons, so the HUD key bar silently dropped "family" for pad players,
    and `HelpScreen.JOY_AXIS_NAMES` had no trigger names (Controls page: "Axis 5"). It now falls back to the axis name
    and the triggers read LT / RT; test added. WU-015 (journal on LT) gets this for free.
  - RV-006 fixes the tournament round scaling and the tautological tests; RV-005b, SF-002, WU-018/019, ENC-002, MS-003
    match their specs. MS-003 counts errands with a `flag_count` check on errand_*_done flags (no GUIDE-003 dependency).
  - Notes, not filed: (1) RV-005b: a save made after taking a realm pill but before the attempt loads with
    `breakthrough_pill = ""`, so one extra realm pill can be stacked once; harmless. (2) WU-018 moved the delivery
    shortfall into a tooltip, which gamepads never show, but the label's "(have n/m)" carries the same information.
    (3) QA-027 found jade_python, blood_lotus_elder and cloud_devouring_condor unbeatable at min_realm and four
    inheritance foes TRIVIAL; it is in the commit's Follow-ups for the planner (balance, not a bug). (4) MS-003's
    milestones count only from now on: veterans who already cleared floors/claimed inheritances must do it again.
- 2026-10-08 (reviewer, 6th run): reviewed de04a40..ba0f095 (GUIDE-003, PROF-002, C-014, WU-015, WU-016, REL-005,
  GUIDE-006, RECAP-001, WU-022, NS-004, NS-002b, WU-023, QA-20261008-1, WU-025, GUIDE-004; [PLAN]/[REVIEW] skipped).
  Main green (1125 tests). No BACKLOG/CHANGELOG edits by workers; no persistent-state or SAVE_VERSION changes.
  - Fixed in one [REVIEW] commit: GUIDE-004's journal line read "Your Fields Boar has outgrown you" when the player has
    outgrown the beast; now "You have outgrown your Fields Boar"; test tightened.
  - Checked: every errand's asked/done flag is set by its NPC dialogue and the named herbs are gatherable where the
    text says; PROF-002 lapse warnings fire once per order (crossing the 7-day mark); WU-022 disabled options are
    focusable but inert and initial focus still skips them; WU-015 LT label works through the RT fallback from the
    last review; NS-002b flawless pills mirror the Foundation one (breakthrough_realm set).
  - Notes, not filed: (1) GUIDE-006 ignores the sect hall bonus and sect-only grounds when comparing qi (hint only).
    (2) WU-025 clears `load_recap` only when a HUD boots; if a quick-load doesn't rebuild the HUD the card can
    show late, harmless. (3) Most menu options still carry the reason only in the label, not in `reason`, so
    WU-022's description line is blank for them; fine since the label already says it.
- 2026-10-08 (reviewer, 7th run): reviewed ba0f095..1b1df8b (GUIDE-005, MS-004 (landed after the last review's
  range), WU-026, C-015, WU-021, QA-031, CMB-001, BT-001, MED-001, EXP-001, C-017, WU-024, WU-027, YEAR-001,
  GUIDE-007, QA-030, WU-031, WU-030; [PLAN]/[REVIEW] skipped). Main green before and after (1171 tests). No
  BACKLOG/CHANGELOG edits by workers; YEAR-001's `year_start_stats`/`year_start_realm` default to {}/"" (no
  SAVE_VERSION bump needed; the first new year after loading an old save only stores a snapshot).
  - Fixed in one [REVIEW] commit: (1) WU-031 changed `HUD._showing_skip` from `static var` to an instance var, so a
    time-skip overlay showing when travel reloads the world scene was dropped (the UI-010 behaviour). Restored, with a
    regression test that rebuilds the HUD. (2) BT-001 `pill_source_hint` ran `String.capitalize()` over "a <pill>",
    which rewrites hyphenated/camel names; now upper-cases only the first letter.
  - Checked: BT-001 `breakthrough_chance` = clamp(sum of `chance_breakdown`), unchanged maths; MED-001 previews on a
    `to_dict` copy (no side effects); EXP-001 outlook uses the same tags + world-event tags as exploring, and the
    "slip away" note matches the Deadly+lethal evade rule; WU-027 kept a `reason` on every option it stripped from
    labels (secret realm and inheritance included); QA-031 tops up the eligible-NPC pool every day pass (cheap when
    full; perf sim still fine).
  - Notes, not filed: (1) YEAR-001: a seclusion that crosses two new years emits `year_changed` once, so the review
    covers both years under one "Year N" title; MS-004's backfill on load can also inflate the first review's floor
    count for veterans. Cosmetic. (2) CMB-001 computes advice after `apply_outcome`, so a fresh injury already
    weakens the player's stats in the comparison; harmless. (3) MED-001's preview is not shown anywhere yet; WU-029
    (todo) wires it into the meditation menu. (4) C-017's Follow-ups ask for a first-hour sim re-run (tools/balance.sh).
