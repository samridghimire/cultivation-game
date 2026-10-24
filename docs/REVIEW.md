# Review log

The reviewer agent appends one entry per run. **Last reviewed commit** is where the next review starts
(`git log <sha>..origin/main`).

Last reviewed commit: 41ee758

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
- 2026-10-08 (reviewer): reviewed 1b1df8b..589ae9d (RV-009, QA-028, FH-030, ECON-001b, CULT-001, WU-032, QA-034, C-019,
  MSG-001, WU-033, WU-034, WU-038; [PLAN] commits skipped). Main green before and after (1198 -> 1200 tests). No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change. (This session's local main had diverged from origin with
  50 stale commits; reset to origin/main before reviewing, nothing pushed from it.)
  - Fixed in one [REVIEW] commit: FH-030's First goals section never went away for characters past Qi Refining on saves
    from before the Elder Mo flag / life stats (now shown only at realm index <= 1, test added); WU-034 labelled the
    last-stage option "until the next layer" though it stops at the bottleneck (now "until your bottleneck", test
    added); CULT-001 moved meditation_preview's doc comment onto days_to_next_stage; C-019's merchant `buy_tags` (and
    `stock_tags`) documented in regions.json `_doc`.
  - Notes, not filed: WU-038 reads LB/RB and PgUp/PgDn as raw keys in ShopScreen instead of InputConfig actions (they
    are also toggle_techniques/toggle_artifact, consumed by gui_input while the shop has focus; works, but not
    remappable). MSG-001's "Your path has shifted" is only checked after hostile acts, treating, devouring and
    patients, so a tier change from an item or encounter is announced at the next of those. Karma.act_sentence
    hard-codes the three act ids (unknown acts fall back to a generic sentence).
  - WU-032, WU-033, CULT-001, ECON-001b, RV-009, C-019: match specs, tests present.
- 2026-10-08 (reviewer): reviewed 589ae9d..fd22b14 (STAT-002, C-021, WU-035, C-016, WU-037, CMB-002, WU-039, QA-033,
  WU-040, GUIDE-008, C-023, WU-043, WU-041, GOAL-002, REL-011, C-022, QA-036, GUIDE-009, WU-036, WU-042; [PLAN]
  skipped). Main green before and after (1244 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change.
  (Local main had diverged from origin again; reset to origin/main before reviewing.)
  - Fixed in one [REVIEW] commit: WU-036's test_combat_playback left the player's "Animate fights" setting off
    (Settings.set_value saves to user://), so running the tests flipped a real setting; it now restores the old value.
    GUIDE-009 test adds the spec's "no buyer in the region" case (misty_forest).
  - Notes, not filed: (1) GUIDE-008 only pre-sets `notice_rival` on a new game, so loading an older mid-game save posts
    every notice at once (body tempering, Dao, artifact functions, the old rival) and WU-042 queues a "New" banner for
    each. One-time burst. (2) The artifact notice hard-codes "(Artifact screen, O)" in core; wrong after a rebind.
    (3) CMB-002's trace gives every pre-round line (talismans, allies) the hp after all openers, so the foe bar drops
    in one step at the first round. Cosmetic. (4) WU-040 "Sell all loot" also sells readied talismans and unworn spare
    equipment at equipment-buying merchants (matches the spec's filter list). (5) GUIDE-009 skipped extending
    test_hint_honesty for the sell hint; the hint takes its name from the region's place display_name, so it is honest.
  - Data retunes C-016/C-021/C-022 only touch trial/guardian-only foes or add new ones (star_vault_warden,
    garden_poacher...); shared foes unchanged. C-023 keeps per-kill income level. REL-011 script refuses placeholder ids
    and keeps no secrets. STAT-002, WU-035/039, WU-041, WU-043, GOAL-002, QA-036, QA-033: match specs, tests present.
- 2026-10-08 (reviewer): reviewed fd22b14..d5121fd (MSG-002, GOAL-003, QA-020, CMB-003, C-024, RV-011, RV-010, C-025,
  WU-048, C-029, QA-037, WU-049, MSG-003, WU-053, GOAL-004, WU-050, C-030; [PLAN] skipped). Main green before and after
  (1264 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change. (Local clone was shallow and showed a
  false divergence; reset to origin/main.)
  - Fixed in one [REVIEW] commit: GOAL-004's profession goal told a Doctor to "craft or work at a workshop"; Doctor xp
    comes from treating patients, so it now says "treat patients at a clinic" (test added).
  - Notes, not filed: (1) WU-053 writes "+3 Mist Wolf Pelt (sells for 7)" where 7 is the per-item price; reads like
    the stack's worth when the count is above 1. (2) WU-050's "LB/RB or PgUp/PgDn" hint is built in ShopScreen._init,
    so a rebind made while the game runs shows the old buttons until the screen is rebuilt. (3) GOAL-003 hides the
    sect-rank line by matching Sects.check_promotion's "No trial" prefix; rewording that reason would show it.
    (4) CMB-003 says a named non-lethal foe "yields" (good for sect trials; also used for named bandits who are beaten
    but not killed).
  - MSG-003 resolves last review's note: the tier announcement now runs on player_changed and _announced_tier is set on
    new game and load. RV-010/RV-011 resolve the GUIDE-008 burst and the readied-talisman sell notes. C-024/C-025/C-030
    data: new gear and pill recipes use previously unused beast materials (test enforces it), baseline refreshed.
    WU-048, C-029 (deterministic quiet lines, validated), QA-020, QA-037, WU-049, MSG-002: match specs, tests present.
- 2026-10-08 (reviewer, 7th run): reviewed d5121fd..b241ba7 (C-028, CMB-004, WU-046/047/056/057, YEAR-002, GUIDE-010/011,
  QA-029/038, SECT-004/005, C-031, RV-012; [PLAN]/[REVIEW] commits skipped). Main green (1294 tests, ALL CHECKS PASSED).
  No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (`year_start_year` defaults to 0, `sect.lecture_month`
  is read only when present, `ambient_effects` setting is sanitized). No fixes needed; nothing filed.
  - RV-012 resolves note (3) from the last run (goals use `Sects.rank_requirement_reason`/`needs_trial`). CMB-004 now
    traces each talisman/ally opener line. SECT-004 adds `min_stage` to ranks (validated) but no rank uses it yet.
    C-031 gates 17 encounters by stage; baseline refreshed. QA-038 shop fuzz checks Sell all against protected goods.
  - Notes, not filed: (1) YEAR-002 titles a two-year review "Years <start+1>-<N>" (the spec said "<start>-<N>"); with
    `year_changed` carrying the new year, both "Year N" and the span name the year just begun, not the ones reviewed
    (e.g. year 1 is reviewed as "Year 2 of your journey"). A labeling call for the planner. (2) RV-010 only quiets
    notices for saves with no `notice_` flags, so a save made before GUIDE-010/011 announces every road, secret realm
    and clan notice it already qualifies for on its first action after load (a few banners for a Core save). Intended
    by test_save_with_some_notice_flags_still_announces_new_features; road notices also fire for roads already walked
    (there is no visited-region record). (3) `GameData._validate_world` reads `Ambient.KINDS` from src/world; harmless
    (a const), but core now depends on a world script. (4) A lecture at a bottleneck posts "(+0 qi)".
- 2026-10-09 (reviewer): reviewed b241ba7..8b0c9a3 (WU-058, KARMA-001, C-035, C-020, QA-021, WU-044, C-039, WU-045, WU-054,
  RV-013, C-040, MENTOR-001, SPAR-001, WU-062; [PLAN] commits skipped). Main green before and after (1316 tests). No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (`npc_action_days` defaults to {} in from_dict).
  - RV-013 resolves notes (1), (3) and (4) of the last run (review titles now name the year that ended; ambient kinds
    live in `Scenery.AMBIENT_KINDS`; a bottleneck lecture says so). WU-054 fixes the stacked-spoils price and the stale
    shop hint. KARMA-001, WU-045, WU-044, WU-058 (local rng seeded from the npc id, not GameState.rng), WU-062 and the
    data tasks (C-035 bully spar, C-039/C-040 stage gates, QA-021 realm training 5-9) match their specs, tests present.
  - Fixed (one [REVIEW] commit): SPAR-001 ignored `mentorship.spar.days` (the bout's fixed day was the only time spent;
    `after_spar` returned days that nobody used). `spar_with` now passes the remaining days; test sets days=3.
  - Notes, not filed: (1) a friendly spar still burns readied combat talismans and lets a life-drinking weapon drain
    lifespan (same as sect trial spars); a design call if spars should be fully free. (2) MENTOR-001's "shared" bonus
    applies whenever the senior knows the technique, even at a lower level than the player. (3) Pointers and spars have
    no menu entry until WU-059 lands.
- 2026-10-09 (reviewer, 2nd run): reviewed 8b0c9a3..d098150 (QA-043, C-041, C-037, TRAV-001, WU-059, QA-040, GUIDE-012,
  WU-060, RV-014, C-042, C-038, WU-066, GUIDE-013, WU-065, QA-039, and the owner's 660201c class-cache hooks; [PLAN]/[REVIEW]
  commits skipped). Main green before and after (1345 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  (`visited_regions` defaults to [] and older saves get the current region on load; new life stats default to 0).
  - RV-014 resolves notes (1) and (2) of the last run (friendly spars burn no talismans, no escape, no lifespan drain; the
    pointer bonus needs a teacher who knows the technique better). WU-059 resolves note (3). TRAV-001 also stops road
    notices for regions already walked (last-but-one run's note (2)).
  - Fixed (one [REVIEW] commit): C-038's Shen Wuya wine choice costs 10 stones but its label only said "(2 days)" and it
    vanished silently when you were broke; label now names the cost and the choice shows locked, like every other paid
    dialogue choice.
  - Notes, not filed: (1) TRAV-001 records visits on travel/start/load only; a respawn or anchor choice lands at a bound
    anchor, which you have visited already, so nothing is missed today. (2) WU-065's ChoiceMenu height is fitted once per
    rebuild; resizing the window with a menu open keeps the old cap until the menu is rebuilt. (3) Local `main` in this
    cloud clone had diverged (an old PR-era history); reset to origin/main before reviewing, nothing pushed from it.
- 2026-10-09 (reviewer, 3rd run): reviewed d098150..e7f99aa (TRAV-004, SEASON-001, NS-006, TRAV-002, WU-063, TRAV-003, WU-064,
  REALM-002, WU-067, C-043, QA-041, ITEM-002, WU-069, C-044, GUIDE-014, SEASON-002, WU-071, QA-047, TRAV-005; [PLAN]/[REVIEW]
  commits skipped). Main green before and after (1381 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  (new state lives in world_flags `discovered_<region>` and the already-saved `visited_regions`; TRAV-003 backfills old saves).
  - Every season-aware call site (explore, outlook, world map foes, gather) passes the current season; `seasons` is validated
    on gather entries and encounters. ITEM-002's `_gives` skips `requires`/costs, so sect-mission deliveries do not count as
    sources. REALM-002 consumes the entry item only on the first entry of an opening; no realm uses it yet.
  - Fixed (one [REVIEW] commit): WU-071 inserted `season_label`/`season_banner_subtitle` between `region_event_suffix` and
    its `##` doc comment (comment moved back); the date line read "Spring (0 days left)" on a season's last day, now
    "Spring (last day)" (test updated).
  - Notes, not filed: (1) TRAV-005 discoveries also fire once for old saves that explored the region long ago (flag is new);
    harmless, arguably nice. (2) SEASON-002's message and WU-071's banner both name the in-season herbs on a season change;
    a little repetitive, by spec. (3) TRAV-003 marks every sect-hall region visited for any sect member (noted in its
    Follow-ups); TRAV-004 already resolves it via sects.json home_region. (4) Local `main` had again diverged onto the
    old PR-era history; reset to origin/main, nothing pushed from it.
- 2026-10-09 (reviewer, 4th run): reviewed e7f99aa..4319bc4 (SEASON-003, NS-007, WU-068, QA-046, WU-070, WU-073, ENC-003,
  QA-050, WU-075, C-049; [PLAN]/[REVIEW] commits skipped). Main green before and after (1401 -> 1402 tests). No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (`seasonal_gathers` and `encounter_counts` default to empty).
  - ENC-003 checked: only plain non-fight encounters fade, the non-fight share is renormalised so fights keep their odds,
    herb finds are marked `repeatable`. WU-068 resolves the last run's note (2) on ChoiceMenu refits.
  - Fixed (one [REVIEW] commit): (1) WU-073's "waits to be found" map mark ignored the discovery's realm/alignment gate and
    could send a player to explore for something they cannot find; it now uses Exploration.discovery_for (test added).
    (2) WU-068 connected the root viewport's `size_changed` to `_fit_scroll.call_deferred`, a non-object callable that is not
    dropped when the menu is freed (the viewport outlives the HUD); now a method callable. (3) WU-075 put `season_lines`
    between `use_lines` and its `##` doc comment again (same slip as WU-071); moved back.
  - Notes, not filed: (1) SEASON-003 counts an autumn-only bonus entry (e.g. purple_cloud_mushroom, also gathered all year)
    as a "season-only herb" for Herbalist of Four Seasons; lenient, fine. (2) Local `main` was a shallow clone that git saw
    as diverged; unshallowed and fast-forwarded, nothing pushed from the old state.
- 2026-10-09 (reviewer, 5th run): reviewed 4319bc4..c1080aa (EXPL-001, C-018, WU-061, WE-002, GUIDE-015, EXPL-002, QA-049,
  C-045, MS-005, WU-079, GUIDE-016, QA-051, BOUNTY-001, WU-072; [PLAN]/[REVIEW] commits skipped). No BACKLOG/CHANGELOG
  edits by workers; main green after (1441 tests); no SAVE_VERSION change (`explore_days`, `bounty`, `bounty_cooldowns` default to empty).
  - WE-002 checked: `months` filter runs before the shared rng is touched and fixed-date events use their own seeded
    stream, so other events' rolls do not shift. WU-061 hides events/secret realms on unvisited regions, by spec.
  - Fixed (one [REVIEW] commit): (1) BOUNTY-001: a trail found near the bounty's last day passed the day (and the fight's
    own days) first, so the bounty lapsed mid-hunt and the win posted "Bounty claimed: 0 spirit stones"; the hunted
    bounty is now held through the fight, paid by id, and the explore day passes afterwards (test added). The hunt path also left a stale `pending_threat`/`pending_encounter`; now cleared like a normal
    explore. Bounty pay now counts toward `stones_earned`. (2) EXPL-002's "seen X of Y happenings" counted unmet
    encounters the player can never meet again (5 Qi Refining-only village encounters after Foundation, alignment-gated
    ones), so the journal line never cleared; unmet out-of-range encounters are left out (test replaced; the old one
    asserted the opposite). (3) WU-061 set the 12px "Unexplored" font and then overwrote it with 14px. (4) C-018: Lord
    Xuan is `male` in npcs.json but two dialogue labels said "her".
  - Notes, not filed: (1) GUIDE-015 sorts region ids with a non-stable sort_custom, so "then data order" is not
    guaranteed for the merchant rumor; cosmetic. (2) Month-end work (incl. festival rolls) runs per month of the
    player's age and only once per skipped month with the end day, so a long seclusion over October skips the Lantern
    Festival; acceptable. (3) Local `main` was again the old PR-era history; kept as `local-main-backup`, worked from
    origin/main, nothing pushed from it.
- 2026-10-09 (reviewer, 6th run): reviewed c1080aa..af043ad (WU-076, WU-078, WU-077, QA-032, C-048, LETTER-001, C-047,
  RENOWN-001, TRAV-006, WU-087, QA-053 part 1, c49865e conflict-marker fix, NEWS-001, C-057; [PLAN]/[REVIEW] skipped).
  No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (`renown`, `letters` default to empty; letter invitations
  are world flags). Main green before and after (1483 tests).
  - Main was briefly uncompilable: TRAV-006 landed `<<<<<<<` markers in game_data.gd and regions.json from its rebase
    onto RENOWN-001 (fixed by c49865e, keeping both sides; checked: no markers left anywhere). Workers must run
    tools/test.sh after the rebase in step 7, not only before it.
  - Fixed (one [REVIEW] commit): (1) TRAV-006: a road encounter kept `last_explore_discovery`/`last_explore_deep_path`
    from the last exploration, so a road choice encounter could open titled "Discovery: ..."/"Hidden path: ..." with the
    discovery chime; both are cleared before it. (2) GUIDE-016 (missed last run): a deeper path set
    `discovered_<region>`, using up a not-yet-met discovery and counting toward "Hidden places found". Only the
    discovery sets it now. Tests for both (they fail on the old code).
  - Note: before C-046 (landed during this review) only misty_forest had a `discovery`, so Seeker of Hidden Places
    was only reachable through the deeper-path bug; with C-046 every region has its own discovery.
  - Notes, not filed: (1) NEWS-001 raises spouses' and children's favor past `dual_cultivation.max_favor`/`max_child_favor`
    (+3 per major breakthrough); harmless. (2) LETTER-001's invitation bonus can lift favor above chat's 30 cap, by
    design. (3) WU-087: every on-screen NPC looks up the player group each physics frame; cheap enough for now.
- 2026-10-09 (reviewer, 7th run): reviewed af043ad..7950f03 (WU-082, WU-074, GUIDE-017, TRAV-007, WU-080, WU-083,
  QA-052, EXPL-003, C-046, MAT-001, C-055, WU-086, MISS-001, WU-081, WU-084; [PLAN]/[REVIEW] skipped).
  Main green before and after (1516 -> 1518 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  (`mission_losses` defaults to empty; `mastered_<region>` is a world flag, backfilled into `regions_mastered`).
  - Fixed (one [REVIEW] commit): (1) TRAV-007: the world map still drew each route's walking days after a flying sword
    shortened them (travel menu and arrival used the short days); the label now uses Exploration.travel_days, with a test.
    (2) MISS-001: top-level `loss_cooldown_days` was documented but not validated; negative is now a load error (tested).
  - Notes, not filed: (1) C-046 gives Qingshi Village a discovery, so a new character's very first exploration always
    finds the Founder's Well (a gentle fortune, no fight); fine for onboarding, but the first-hour sims now start from
    it. (2) TRAV-007 also lowers road-encounter odds, since road_chance uses the shortened days; reads as intended.
    (3) MAT-001's material_value cache is never invalidated; content is immutable after load, so only tests that edit
    recipes/prices after a material_value call could see stale values. (4) QA-052: every curious-sim death is the Mist
    Wolf of "Cull the Mist Wolves"; MISS-001 now cools it down after a loss, the min_stage/enemy tuning follow-up is
    still open for the planner.
- 2026-10-09 (reviewer, 8th run): reviewed 7950f03..8961cbd (GUIDE-018, WU-090, C-052, RENOWN-002, C-050, QA-054, WU-091,
  WU-088, BOUNTY-002, GIFT-001, WU-093, WU-094, RENOWN-003, WU-096, WU-097, WU-089, QA-055, C-051; [PLAN]/[REVIEW] skipped).
  Main green before and after (1546 -> 1547 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  (GUIDE-018's `letter_day` defaults to -1; gift tastes live in world_flags).
  - Fixed ([REVIEW] commits): (1) WU-096: the respawn lesson quoted Combat.win_chance (full HP, no allies) after a
    wounded tournament bout or a Karma ally strike; those deaths now carry no odds (test). "face it again" -> "this foe".
    (2) RENOWN-002 prefix made "Because your name is known here, Two farming families..." -> "Your name is known here: ".
    (3) RENOWN-003: bounty board % came from the rounded payout (5 stones at +10% read +20%); now the tier multiplier.
    (4) WU-091: test_hud_crowding saved ui_scale/hud_hints into the real settings file and never restored them or
    ended the session; fixed, and the prompt check re-measures the panel. (5) QA-055 left combat_finished's doc on
    combat_started. (6) C-051: walking away from the lost child cost a day; the day is on "Walk her home" now.
    (7) GIFT-001: a disliked gift (accepted even at the favor cap) still earned clan kindness, so cheap disliked gifts
    could farm clan standing; gated on taste >= 0. (8) QA-054 sim: lost-mission odds were read after the fight (the
    QA-055 bug, second copy), and artifact_lives -1 (uninitialised) counted as the last life.
  - Notes for the planner, not filed: (1) C-051's well_bandit rates ~83% at entry, above the spec's 40-75% band.
    (2) WU-088's "You lost this fight N ago" never expires and uses the rating colour, not the danger colour.
    (3) GIFT-001's taste hint threshold (favor 20) is hard-coded in GameState and the chat hint has no GameState test;
    WU-089's gift menu only marks tastes learned by gifting, so a chat-hinted taste still shows as neutral.
    (4) Taste world flags are ints (-1/1); fine with `flags.get(x, false)` callers that only test truthiness of +1,
    but -1 is truthy. (5) A region discovery with `min_renown` would lock itself out; nothing does that yet.
- 2026-10-09 (reviewer, 9th run): reviewed 8961cbd..3108c18 (FEST-002, C-053, YEAR-003, NEWS-002, WU-092, QA-053b, WU-095,
  C-058, DANGER-001, C-060, WU-104, WU-105, LETTER-003, NEWS-003, WU-101, QA-056; [PLAN]/[REVIEW] skipped).
  Main green before and after (1580 -> 1581 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  (LETTER-003's `letter_requests` defaults to []). DANGER-001 kept threat sensing on "Deadly"/"Dangerous" as specced;
  no other "Even" comparison changed meaning. Note: this checkout was a shallow clone; `git fetch --unshallow` first.
  - Fixed ([REVIEW] commit): (1) C-060: "Swallow the seed" had breakthrough_realm foundation_establishment, so an
    early-Foundation player (the encounter's stated reward band; min_realm has no cap) or a Qi Refining player with a
    pill waiting saw the choice disabled as "This pill is meant for..."; now a plain +5% next breakthrough (test).
    (2) FEST-002 and WU-104 each wedged a new function between an existing doc comment and its function
    (GameState._world_events_month, CombatReport.log_height); moved back.
  - Notes for the planner, not filed: (1) FEST-002's festival goods appear at every merchant in the region (Blood Lotus
    Apothecary, smithies, talisman stalls included) and ignore the merchant's max_price; fine for a festival, but a
    `stock_tags` gate would read better. (2) WU-105 left out " (likes N known)" (WU-101 has landed since; small
    follow-up using NPC.known_tastes_text's flag scan). (3) LETTER-003 posts "no longer waits" as "normal", not the
    family topic the spec asked for; answer_letter_request does not check you are in the asker's region (WU-099's NPC
    entry will imply it). QA-056 predates LETTER-003, so `letter_requests` has only test_letters' round-trip.
    (4) C-060 follow-up stands: the planted seed should give the lasting Azure Peak qi-density bonus the task asked
    for (needs a flag-driven density mechanic). (5) WU-104 caches the rating per combat_started; a multi-round
    tournament shows the last round's rating, which is the fight the report shows.
- 2026-10-09 (reviewer, 10th run): reviewed 3108c18..51025b4 (C-059, WU-099, FEST-003, C-064, WU-110, QA-048, SHOP-001,
  LETTER-002, LETTER-003b, C-066, WU-103, QA-058, RUMOR-001, WU-107, WU-106, C-067, C-061, QI-001, WU-108, WU-100; [PLAN]/[REVIEW] skipped).
  Main green before and after (1611 -> 1618 tests, new commits included). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  (SHOP-001's `shop_deals` defaults to {}, FEST-003's `activity_done` defaults to false; QA-058 covers both new fields).
  Note: the local main of this checkout had diverged from origin; `git reset --hard origin/main` first.
  - Fixed ([REVIEW] commit): (1) C-064 moved the sword madman bounty to Core Formation at 220 stones but its text still
    said "posts 130 stones". (2) C-061: Ancestor Incense gave +3 alignment for 8 stones, buyable without limit while
    Qingming lasts: 2.7 stones per point against Clear Heart Pill's 20, so a demonic cultivator could wash their path
    clean for a few hundred stones. Now +1 for 12 (still under the festival goods' 15-stone cap).
  - Notes for the planner, not filed: (1) FEST-003's activity has no menu entry yet (WU-100), so "Float a lantern" is
    (WU-100 has since added it to the merchant menu); activity `effects` are not run through any Effects key validation.
    (2) With data rumors always present, "The merchant shrugs: ... nothing worth gossiping about" is now followed by
    gossip every visit (WorldEvents.rumors adds it whenever no event is active); reword or drop when extras exist.
    (3) LETTER-002's family_writer counts a spouse in a sect even when that sect is the player's own and they share a
    region ("writes from {region}" to someone next door); fine for now. (4) C-059 locks Drowned Yin Palace behind the
    token for existing saves too, and the token is never consumed (consume_entry_item unset), as specced.
    (5) C-064 follow-up: re-run the bounty income sim for the Core Formation sword madman. (6) QI-001: the region
    qi_flags bonus is applied to the player's meditation, HUD and map, but not to Guidance.best_qi_in_region (journal's
    "best place to meditate") or to NPC/child cultivation (Npcs, Training call qi_density without flags); harmless at
    +10%, but pass flags through if more qi_flags land.
- 2026-10-14 (reviewer, 11th run): reviewed 51025b4..597d486 (GIFT-002, FEST-004, QA-059, WU-102, WU-109, RUMOR-002, EFF-001,
  WU-111, WU-115, QA-060, WU-112, SECRET-003, C-069, LETTER-005, QI-002, WU-114, C-068; [PLAN]/[REVIEW] skipped).
  Main green (tools/test.sh ALL CHECKS PASSED). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change and no new
  persistent state. No [REVIEW] fixes needed this run; nothing filed.
  - Checked: EFF-001's list-valued set_flag/clear_flag has no other reader of those keys outside Effects; QI-002 leaves no
    qi_density caller without flags in src; FEST-004's sold_by defaults every current event to herb stalls (no event sets
    stall_tags yet); SECRET-003/WU-114 notice fires only when a span crosses into the notice window, never while open.
  - Notes for the planner, not filed: (1) WU-111: when hear_rumors is refused by _can_act it returns [] and the Gossip
    window says "Nobody has anything to tell you." over the refusal message; harmless today. (2) C-069 moved Peach
    Blossom Grotto's offset_years 0 -> 2: an old save mid-opening sees the grotto close early (progress is per opening);
    acceptable. (3) FEST-004: the festival activity entry ("Float a lantern") still shows at every merchant, including
    stalls that do not sell the festival goods. (4) QA-060 follow-up stands (MENTOR-002/C-071): pointers never fire
    because a newcomer knows no technique; C-068 notes the same root cause behind C-063. C-068 closes the C-060
    follow-up (planted seed sets planted_guardian_seed, a qi_flags entry).
- 2026-10-15 (reviewer, 12th run): reviewed 597d486..e922009 (MENTOR-002, QA-061, C-072, C-076, WU-117, WU-118, GUIDE-019,
  FEST-005, QA-062, WU-116; [PLAN]/[REVIEW] skipped). Main green before and after. No BACKLOG/CHANGELOG edits by workers;
  no SAVE_VERSION change and no new persistent state.
  - Fixed ([REVIEW] commit): (1) C-072: Elder Mo's "Breathing alone will not win a fight" line kept showing after the
    player learned Iron Fist; it now also needs not_knows_technique iron_fist. (2) The "knows any combat technique" loop
    was written three times (Combat.loss_advice, Guidance.first_combat_manual, ShopScreen.is_first_combat_manual); now
    one Techniques.knows_kind(c, data, kind), with a unit test.
  - Notes for the planner, not filed: (1) GUIDE-019's first_combat_manual does not skip techniques with an activation
    (lifespan) cost, while QA-062's sim policy does; Iron Fist is cheapest today, so no player-facing effect yet.
    (2) C-072 recommends Stone Skin, a "body" technique, but the "no fighting style" hint/loss advice only count kind
    "combat", so learning Stone Skin alone does not quiet them; wording choice for the planner. (3) WU-116 follow-up
    stands: the milestone banner draws over an open combat report after the first death. (4) QA-062 follow-up: Mist Wolf
    still the top early killer even with a style (QA-057/C-063).
- 2026-10-15 (reviewer, 13th run): reviewed e922009..5329c38 (LOG-001, C-074, WU-119, LETTER-006, C-070, WU-123, QA-044,
  C-075, MENTOR-003, GUIDE-019b, REF-001, WU-120, WU-124; [PLAN]/[REVIEW] skipped). Main green before and after. No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change and no new persistent state. Nothing filed.
  - Fixed ([REVIEW] commit): WU-124: a banner already showing when the hold began still ended through finish_current(),
    which popped and played the next queued banner over the open combat report (e.g. a milestone queued during the
    fight). finish_current now hides and keeps the queue while held; unit test added.
  - Notes for the planner, not filed: (1) REF-001 changes behavior: a sect call whose mission is merely on cooldown now
    posts nothing (was "Your sect calls on its disciples again."); the commit says this is intended. (2) C-075 follow-up
    stands: the "coming" rumors keep playing after the realm/inheritance is found (no found flag to block on).
    (3) GUIDE-019b closes last run's notes (1) and (2). (4) tools/test.sh's unit suite now takes ~15 minutes on the cloud
    box; the sims are the likely cost, worth a look before it gets slower.
- 2026-10-15 (reviewer, 14th run): reviewed 5329c38..111cd0a (QA-063, GUIDE-020, WU-130, C-078, INH-001, MENTOR-004,
  QA-064, WU-131, C-080, EFF-002, RUMOR-003, GUIDE-021, QA-065, WU-127; [PLAN]/[REVIEW] skipped). Main green before and after. No BACKLOG/CHANGELOG edits by
  workers; no SAVE_VERSION change and no new persistent state. Nothing filed.
  - Fixed ([REVIEW] commit): (1) GUIDE-020's practice hint hard-coded the key "(Techniques, K)", wrong on a gamepad
    (LB); it now says "on the Techniques screen" (core can't read InputConfig). (2) EFF-002: the note always said
    "(level N)"; per the spec it now names the level only when one was gained (unit test added). (3) EFF-002 dead
    code: Techniques.train_best_combat (name-returning wrapper) had no caller; removed, train_best_combat_id kept.
  - Checked: WU-130/WU-131 sync on session_started before the first player_changed (new game and load), so loading
    never re-announces level-ups or goals; MENTOR-004's same-sect rule ignores rogues on either side; INH-001's
    min_stage is validated against the realm's stage count; GUIDE-021's fair_fights uses Combat.win_chance's own
    seeded rng and only runs when the journal is built (on demand, <= 8 ratings); RUMOR-003 closes last run's note (2).
  - Notes for the planner, not filed: (1) QA-064's baseline was taken before INH-001 raised the Rotting Pier trial to
    QR 5th Layer; re-run the sim to refresh it. (2) C-080's Elder Mo "practise" line only checks Iron Fist; a player
    whose first style is another manual (C-078's marsh/ridge stalls) gets GUIDE-020's hint but not Mo's line.
    (3) GUIDE-020 added a "Learn a fighting style" first goal; with WU-131 each tick now banners, so learning Iron Fist
    shows two goal ticks at once only as one banner (the last); fine, but the earlier tick is never named. (4) WU-127's screenshot note quotes the old "(Techniques, K)" hint text;
    the hint now reads "on the Techniques screen".
- 2026-10-15 (reviewer, 15th run): reviewed 111cd0a..f36edce (WU-126, WU-135, QA-067, GUIDE-023, GUIDE-024, WU-133;
  [PLAN]/[REVIEW] skipped). Main green before and after. No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  and no new persistent state. Nothing filed.
  - Fixed ([REVIEW] commit): WU-135's test connected a lambda to the EventBus autoload's breakthrough_details signal and
    never disconnected it, leaving a dangling handler for every later test; it now disconnects after the breakthrough.
  - Checked: WU-126's rating order matches Combat.label_for_chance and the sect's call is still pinned first after
    ordering; WU-133's row_fits measures with the button's own font size (18) and the detail pane rebuilds the same
    "name  price" base, so the suffix moves exactly when the row drops it; GUIDE-023 skips friendly spars and names no
    fairer fight against the foe just lost to; WU-135's banner details are cleared on every breakthrough_attempted.
  - Notes for the planner, not filed: (1) GUIDE-024's hint rates missions with 20 samples while the board (WU-126) and
    fair_fights use 40, so near 50% the hint can call a mission "too dangerous" that the board shows as Risky.
    (2) WU-126 computes win_chance twice per mission per open (ordered() then the label loop); the spec asked for once;
    worth folding into PERF-001. (3) WU-133 skipped its screenshot check (Follow-up); WU-136/WU-132 should cover the
    shop at 1280x720. (4) QA-067 follow-up stands: listed bounties are never exercised by the curious policy.
- 2026-10-15 (reviewer, 16th run): reviewed f36edce..039470a (FOUND-001, C-081, C-077, GUIDE-026, WU-129, FOUND-002,
  DLG-001, C-084, QA-066, QA-068; [PLAN]/[REVIEW] skipped). Main green before and after. No BACKLOG/CHANGELOG edits by
  workers; no SAVE_VERSION change and no new persistent state. Nothing filed.
  - Fixed ([REVIEW] commit): C-077's wandering boxer put `practice_days: 7` and `set_flag: beat_wandering_boxer` on the
    "Accept the bout" choice, and choice effects apply before the fight, so a loss still trained for 7 days and blocked the
    encounter forever ("beat" flag set). The spec says "on a win": both now sit in the spar enemy's rewards (applied on
    victory only), so a loss gives nothing and the boxer can be met again. Test updated + a new one pins it. Also: the old soldier
    called the player "boy" whatever their gender; now "youngster".
  - Checked: FOUND-002's Injuries.chance is the exact formula roll used (the breakthrough_failure table is never empty,
    so the preview is honest) and the qi loss uses the next realm's failure_qi_loss as Cultivation does; tribulation
    realms are left to the tribulation screen. FOUND-001's next_realm_pill keeps pill_source_hint's old behaviour.
    GUIDE-026 respects each deed_giver's hidden_by_flag and all three enemy deeds are righteous, so no demonic
    "fight you can win" is suggested. DLG-001's practice_pending matches GUIDE-020's practice_target. C-084 descriptions
    are validated in GameData. QA-068 restores hud_hints after each fuzz run.
  - Notes for the planner, not filed: (1) QA-066's test_play_logs_breakthrough_attempts says "seed 2 reaches
    Foundation", but `seen` is also satisfied by the Mortal -> Qi Refining breakthrough; it does not check Foundation.
    (2) QA-066's finding stands: median stones at the QR bottleneck (~170) are below the 300-stone Foundation pill, so
    FOUND-001's saving goal often shows a target out of reach; a balance decision (cheaper pill or base chance).
- 2026-10-15 (reviewer, 17th run): reviewed 039470a..17d6a3b (WU-125, QA-070, RIVAL-004, WU-138; [PLAN]/[REVIEW] skipped).
  Main green (1719 tests after). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change, no new persistent state. Nothing filed.
  - Fixed ([REVIEW] commit): WU-125 recomputed `Guidance.fair_fights` (combat sims) once per signal, and one time-taking
    action emits `days_advanced` and `player_changed` (often several), so it ran 2+ times per action; the signals now
    queue one deferred recompute per frame. (WU-138's Look Follow-up was fixed here too, but WU-141 landed the same change
    first; mine was dropped in the rebase.)
  - Checked: RIVAL-004's tones (warning ahead / normal behind / dim level; the journal has no "good" tone, so "normal" is
    the right stand-in), the line waits for `rival_met` and the fallen line too; WU-138's `is_rival` uses
    `Rivals.rival_of` (living only) and the danger color follows `relation() == "stronger"` as specced; QA-070 is sim-only
    and disconnects its bounty_claimed handler on every path.
  - Notes for the planner, not filed: (1) WU-138's label reads GameState in `_draw`, so an NPC already drawn when the
    first meeting plays shows " (rival)" only at its next redraw (approach or region reload); harmless. (2) QA-070's
    Follow-up stands: bounties are listed 3 times in 120 sim-months, so the HUD fair-fight line will almost always name a
    sect mission or nothing for rogues. (3) WU-139 (claimed) should reuse `Rivals.relation_text` as its spec says.
- 2026-10-15 (reviewer, 18th run): reviewed 17d6a3b..911fc1e (C-082, WU-139, PERF-001, C-086, QA-074, WU-137, WU-141,
  GUIDE-027, WU-143, FOUND-003, C-065, WU-140, RIVAL-005, C-083, RIVAL-006, CHOICE-001, QA-072, WU-136; [PLAN]/[REVIEW]
  skipped). Main green before and after (1745 tests after). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change;
  FOUND-003's `breakthrough_failures` is saved with default 0. Nothing filed.
  - Fixed ([REVIEW] commit): WU-137's realm card opened (deferred) on a successful breakthrough even when a tribulation
    came with it, so it covered the tribulation screen while its waves were still playing (both modals up, the card's
    8s timer running underneath). The card now waits in `_pending_realm_card` and opens when the tribulation screen
    closes; test_realm_card pins both paths. Also C-082's marsh vigil said "hear his own spirit" of anyone; now "their".
  - Checked: PERF-001's `fight_fingerprint` covers every CharacterData field `Combat.stats` and its helpers read
    (techniques with level, talismans with counts, buffs, injuries, companions, bloodline, body stage...), and
    win_chance never passes start_hp, so the cache is sound. RIVAL-005/006 match their specs (seen-realm seeded at the
    meeting and silently for old saves). CHOICE-001 validates unknown ids and values < 1. FOUND-003's bonus resets on
    success and shows in chance_breakdown; the world-event `activity_done` default fixes a real save round-trip diff.
    C-065's moon_cake exists; C-083's rating thresholds match `Combat.label_for_chance`.
  - Notes for the planner, not filed: (1) RIVAL-006 only checks after the player's own breakthrough, so a rival who
    is already a realm behind at the first meeting is not "surpassed" until the next one (spec'd that way; the optional
    monthly check in `_rival_news` would catch it). (2) C-088 still needs CHOICE-001's min_attributes in data.
- 2026-10-15 (reviewer, 19th run): reviewed 911fc1e..b54040f (WU-142, WU-132, GUIDE-028, C-085, C-089, QA-075, WU-144,
  WU-145, C-088, RIVAL-007, C-087, CHOICE-002, QA-076, WU-147; [PLAN]/[REVIEW] skipped). Main green before and after
  (1760 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change, no new persistent state. Nothing filed.
  - Fixed ([REVIEW] commit): C-087's herb-bid rival said "Mine is higher than whatever he offers" of the player, whose
    gender the game never sets; now "whatever this one offers".
  - Checked: CHOICE-002 validates unknown profession ids and ranks outside 1..max_rank, and the `check` tag is not yet
    shown anywhere (WU-146 does that). RIVAL-007's monthly `_check_rival_surpassed` is gated on the first meeting and
    the once-only flag, and now also runs `check_milestones`. C-087's `city` tag only matches Fallen Star Market,
    `marsh` both marsh regions, `azure_cliffs` Azure Peak. WU-144 matches its spec (tooltip lists every entry).
    WU-147's marks hide offers while a hunt runs elsewhere (by design); C-089's 3%/9% matches realms.json.
  - Notes for the planner, not filed: WU-144's commit says the `--win-shots` ellipsis check was not re-run.
- 2026-10-15 (reviewer, 20th run): reviewed b54040f..ea1a53f (WU-146, C-062, RIVAL-008, C-090, FOUND-004, FOUND-005,
  QA-078, WU-149, C-091, GUIDE-030, WU-148, WU-153, CHOICE-003, C-092, WU-150, GUIDE-029, RIVAL-009, QA-079, RIVAL-011,
  WU-152, C-094; [PLAN]/[REVIEW] skipped). Main green before and after. No BACKLOG/CHANGELOG edits by workers; no
  SAVE_VERSION change; new karma.json rival keys are validated. Nothing filed.
  - Fixed ([REVIEW] commit): (1) FOUND-004 switched the HUD's goal banner to `Guidance.active_goal_ladder`, which is
    empty once a ladder is complete, so the last goal of either ladder was never announced and "Your first goals are
    done" became unreachable; and on the Foundation breakthrough the new ladder was diffed against the old snapshot, so
    an abode or body stage claimed long before popped a "Goal done" banner. The HUD now follows
    `Guidance.goal_ladder_id` (first up to Qi Refining, foundation in Foundation, kept when finished), re-snapshots
    silently when the ladder changes, and names the finished ladder ("Your Foundation goals are done"). (2) WU-148's
    `last_surpassed_rival` was also set by RIVAL-007's monthly check, so the next successful breakthrough's realm card
    could say "You have surpassed X" months later; it is now cleared at the start of each attempt.
  - Checked: RIVAL-011's death line skips the player's own kill ("slain by") and posts once; RIVAL-008's overtake
    re-arms the surpassed flag and the spur caps at 0.95; CHOICE-003 only tags negative item deltas; GUIDE-030's
    explore fights reuse eligible_encounters and stay under FAIR_FIGHT_MAX_RATED; WU-149's lesson line matches
    chance_breakdown (failures counted before it posts).
- 2026-10-15 (reviewer, 21st run): reviewed ea1a53f..9740f37 (C-096, WU-151, RIVAL-010, QA-080, FOUND-006, EFF-003, WU-159, WU-157,
  WU-154, C-093, QA-081, C-097, WU-156; [PLAN]/[REVIEW] skipped). Main green before and after. No BACKLOG/CHANGELOG
  edits by workers; no SAVE_VERSION change (FOUND-006 stores its record in world_flags). Nothing filed.
  - Fixed ([REVIEW] commit): (1) C-097's help page said the tribulation heart demon comes for those "with many devoured
    victims on their conscience"; Tribulation.faces_heart_demon only checks alignment (realms.json heart_demon), so the
    line now says it comes for the deeply demonic, ignores armor and grows with how demonic you are. (2) C-096's
    forest_dying_rogue_begs_pill calls the rogue "he/his" but its grateful_npc had no gender, so the spawned NPC could be
    a woman; now `"gender": "male"`.
  - Checked: RIVAL-010's rival_attitude is validated (needs `rival`), skipped by region_progress, and only the explore
    roll passes the favor (outlook/road calls pass no rival, so they never offer them, as before). FOUND-006 skips spars
    and friendly fights and uses realm ids for NPC foes (Karma.npc_enemy). EFF-003 matches its spec; note
    Effects.check does not refuse a profession_xp-only effect for a profession not taken up (no data uses it yet;
    C-098 adds it to profession-gated choices only). WU-154's footer is not focusable. C-093's test now tries seeds 1..8
    for the curious-sim pill (acceptable: it still asserts the pill's odds).
  - Notes for the planner, not filed: QA-081 found the readiness line says "ok" at 56% survival for a bare demonic
    (-500) player with Stone Skin (the heart-demon wave), and its guard test only covers alignment 0. QA-080 found
    renowned requests pay 2.5x-25x a week of gathering; the content retune needs an intended ratio first.
- 2026-10-15 (reviewer): reviewed 9740f37..b2343fc (C-095, RIVAL-013, WU-155, QA-082, C-098, CORE-001, C-100, RIVAL-012,
  FOUND-007, WU-160, C-101, GUIDE-031, RIVAL-014, WU-161, QA-085, RIVAL-015; [PLAN] commits skipped). Main green before
  and after (1836 -> 1837 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (RIVAL-014's successor
  state lives in world_flags). The previous run's entry covered ea1a53f..55f04a0 but left the pointer at 9740f37.
  - Fixed ([REVIEW] commit): (1) C-100's rival_secret_realm_gate "Fight for the right to enter first" paid 250 spirit
    stones in `effects`, which choose_encounter applies before the duel, so a lost duel still paid more than sharing;
    the prize is gone (the duel costs you the realm), and a data test now forbids items on fight_rival choices. Its text
    also assumed the player belongs to a sect; reworded for rogues. (2) FOUND-007 put CLOSE_CALL_SHARE between
    tribulation_note and its `##` doc comment; moved.
  - Checked: RIVAL-013's line fires only when the rival's attitude changes (other NPCs' favor changes are no-ops).
    RIVAL-014 gives no successor after the player's own kill or before the first meeting, clears the per-rival flags,
    and Milestones.flag_count now skips the text flag `rival_predecessor` (the other world_flags loops already
    tolerate non-bool values). CORE-001's Golden Body = body_stage 4 matches body_tempering.json. GUIDE-031's echo
    filter is word-based and tested. WU-155/RIVAL-012: a bitter rival's challenge stays listed with check_spar's reason.
  - Process: RIVAL-015's code landed as "fixup spacing" (911d1e3) with a follow-up marker commit; the marker is enough
    for the planner, but workers should amend before landing, not after.
  - Notes, not filed: C-100's duel choices add rival_grudge 10, which equals bitter_grudge, so any one duel makes the
    rival bitter (refuses spars until amends). Intended? A design call for the planner.
- 2026-10-16 (reviewer): reviewed b2343fc..fccc922 (WU-162, C-099/C-104, WU-163, WU-164, GUIDE-033, QA-083, C-109,
  GUIDE-032, GUIDE-034, C-105, WU-165, QA-071, WU-167, RIVAL-016, WU-169, WU-166; [PLAN] commits skipped). The last
  run's range stopped at b2343fc although WU-162..164 and C-099/C-104 had landed before it, so they are covered here.
  Main green (1851 -> 1854 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change.
  - Fixed ([REVIEW] commit): (1) WU-164 made ChoiceMenu treat a `tone: "warning"` option like a refused one and show
    its `reason`, which enabled options don't have: the tribulation attempt's description (odds, risk, the close-call
    warning itself) went blank exactly when it was meant to be highlighted. Now only disabled options show the reason;
    the warning tone only tints the description. Test added. (2) RIVAL-016 kept the bout record in life stats only, so a
    RIVAL-014 successor rival inherited the dead rival's "bouts N won" and never got a "first time" line. The current
    rival's record now lives in world_flags (rival_bouts_won/lost), cleared on succession; the life stats stay lifetime
    totals. Saves from the last few hours show no record until the next bout.
  - Checked: GUIDE-033's rival bout respects attitude, check_spar and region, and is display-only. C-109's guard test
    covers every fight_rival choice. GUIDE-032 needs a shop pill for the next realm (returns "" otherwise). GUIDE-034's
    echo filter only drops exact repeats and the breakthrough hint. C-105 validates groups; WU-169 handles empty groups.
  - Notes for the planner, not filed: QA-083 found rival_spoils_gathering (bitter) never rolled in 20 sims although the
    rival is bitter in 24% of curious checkpoints; worth a check of its eligibility. QA-071: reed_hermit_hut claimed by
    0/10 seeds. GUIDE-033's away/bitter/cooldown test returns early when the fixture bout is not fair (weak test).
- 2026-10-16 (reviewer): reviewed fccc922..ac172f8 (C-108, GUIDE-035, WU-170, EFF-004, C-107, WU-171, NS-007, YEAR-004,
  C-110, WU-173, WU-175, WU-176, EPI-002, WU-174, C-111, QA-088; [PLAN] commits skipped). Main green (1867 tests before).
  No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change. Nothing to fix, nothing filed.
  - Checked: EFF-004's new refusal can't block existing content: every profession_xp choice in encounters.json already
    requires min_profession, and no item grants profession_xp. NS-007's body goal is right (body_stage 5 = stages[4],
    Indestructible Vajra Body, min_realm nascent_soul) and Nascent Soul enemies exist for the beat-a-foe goal; the
    older tests that used realm_index 4 as "past every ladder" moved to 5. C-108's successor branch keys on
    rival_meeting_from, which only succession sets. WU-173's odds use the same spar_enemy as spar_with, and the cached
    Combat.win_chance. EPI-002 and GUIDE-035 read the per-rival bout record from world_flags (as of the last review).
    C-111 (reed hermit Spirit 11 -> 10, the sim walks multi-hop routes) and QA-088 (test only) are sound.
  - Notes, not filed: the sheet's rival line (WU-174) names the region when no current region is passed, but the
    journal's (GUIDE-035) doesn't; harmless, since both callers pass the region. WU-176's label_visible(highlighted,
    highlighted) takes a parameter it never really uses.
- 2026-10-16 (reviewer): reviewed ac172f8..50042bb (WU-172, INH-002, WU-177, C-112, QA-089, C-113, SOUL-001, C-114,
  WU-178, WU-179, INH-003, QA-090, GRAT-001, C-115; [PLAN] commits skipped). Main green (1878 tests). No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change. Nothing filed.
  - Fixed ([REVIEW] commit): C-115's rival_soul_bitter_cairn said the cairn was for "those who fell in your sect's
    worst year", which reads wrong for a rogue cultivator; reworded to a sect-neutral war memorial.
  - Checked: SOUL-001 mirrors the Nascent ladder; its body row appears now that C-114 added a sixth stage (body_stage 6
    = stages[5], min_realm soul_formation) and Soul Formation enemies exist for the beat-a-foe goal. C-114 keeps total
    injury_resist under the cap and every item has a source (tested). C-112/C-115 duel choices pay no items and their
    stone costs go through Effects.check. INH-002's alignment messages only index min/max_alignment when present.
    INH-003's warning tone is only for an attemptable inheritance under a year from its deadline. GRAT-001's tiers
    read data/karma.json thresholds and skip the rival's grudge (left to the rival entry), like WU-178's People list.
    QA-089 removed the early return the last review flagged as a weak test.
  - Notes, not filed: QA-090 found the curious sim policy never explores the bitter spoils encounter's regions while
    the rival is bitter (a sim-policy gap, not a game bug). The Soul Formation goal "Claim two inheritances" counts
    lifetime claims, so it can be done on arrival.
- 2026-10-16 (reviewer): reviewed 50042bb..26efd67 (YEAR-005, C-106, GUIDE-037, WU-182, QA-084, C-118/C-119, WU-185,
  C-116, RENOWN-004, INH-004, QA-092; [PLAN] commits skipped). Main green (1887 test methods). No BACKLOG/CHANGELOG
  edits by workers; no SAVE_VERSION change. Nothing filed.
  - Fixed ([REVIEW] commit): C-119's mountain_last_sect_of_the_ridge offered to "guard the gate for a year" but the
    choice takes 30 days (a month; a year is 360); the label and texts now say a month.
  - Checked: RENOWN-004 grants choice renown only after a won fight for enemy choices (and validates 1..50); no content
    uses it yet. GUIDE-037's Rivals.where_text keeps both callers' behaviour (both pass the region). INH-004's
    time_left_text clamps at 0. C-118 foes all appear in C-119 encounters; C-116's help claims (kin grudges, yearly
    fade, amends) match karma.gd. QA-084/QA-092/WU-182 are sim/screenshot only.
  - Notes, not filed: WU-185 bands on the raw chance, so 89.6% reads "about 90% odds" with the middle-band lesson.
    A fight_rival choice with renown would grant it whatever the bout's outcome (no content does this).
- 2026-10-16 (reviewer): reviewed 26efd67..9206be9 (WU-183, C-103, SOUL-002, C-117, YEAR-006, WU-184, GRAT-002, QA-091,
  C-102, WU-186, C-120, WU-189, WU-158, VOID-001, RENOWN-005; [PLAN] commits skipped). Main green. No BACKLOG/CHANGELOG
  edits by workers; no SAVE_VERSION change. Nothing filed.
  - Fixed ([REVIEW] commit): WU-189 put low_artifact_warning between loss_text and its doc comment, so the old comment
    described the wrong function; loss_text has its comment back. C-117's sunken bell monk "eyed the soul infant fruit
    at your belt" even when you carry none (the give choice is correctly refused then); he now asks if you carry one.
  - Checked: SOUL-002's goal uses inheritances whose first stage needs soul_formation (three exist), so it can't be done
    on arrival. VOID-001's inheritance row is hidden (no void_refinement inheritance) and its body row too (6 body
    stages); Void Refinement foes exist for the beat-a-foe goal. RENOWN-005 only speaks for encounter-choice renown and
    defers to the tier line. C-120's corpse-refiner hunt is an enemy choice, so its renown waits on a won fight
    (RENOWN-004). C-117 costs go through check_choice (tested). GRAT-002 uses Karma.amends_cost and the NPC's region.
  - Notes, not filed: WU-158's banner now sits in the top 3-20% of the screen, over the HUD's top area while it shows.
- 2026-10-16 (reviewer): reviewed 9206be9..569a744 (C-121, GUIDE-036, WU-187, YEAR-007, C-122, INH-005, WU-181, WU-180,
  QA-093, GUIDE-040, C-126, WU-191, GUIDE-038, QA-086, WU-192, C-130, WU-188; [PLAN] commits skipped). Main green. No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change. Nothing filed.
  - Found: YEAR-007's renown_titles counted every tier crossed, so Known -> Respected -> Renowned in one region read
    "Your name became known in 3 places" and could meet C-130's four-places milestone in two regions. QA-20261016-1
    landed the same fix (Renown.add's first_title) while this review ran, so mine was dropped.
  - Fixed ([REVIEW] commit): GUIDE-036's test injected a pill, an auction lot and a recipe into the shared data() of
    test_guidance.gd; it now loads its own GameData.
  - Checked: INH-005 counts a loss once (lost_between keys on the deadline crossing, skips claimed ones). C-122's
    stages, foe and reward items validate; a 300-year deadline fits Void Refinement lifespans. GUIDE-036 only speaks
    when no shop sells the pill (Items.sources never returns empty). GUIDE-040, GUIDE-038 (format_rough) and C-126
    (drunk bully non-lethal; the guard now honours min_stage) are sound. WU-191's HUD line falls back to goals().
    WU-192's subtitle is a pure static with a null-safe player. QA-086/QA-093/WU-180/WU-181/WU-187/WU-188 are
    sims and shots only.
  - Notes, not filed: INH-005 also counts inheritances whose grounds the player never found or could not yet enter.
- 2026-10-16 (reviewer): reviewed 569a744..e673015 (QA-095, RENOWN-006, C-123, QA-20261016-1, EPI-003, WU-190, C-127,
  WU-194, GUIDE-041, WU-196, PROF-003, YEAR-008, C-131; [PLAN] commits skipped). Main green. No BACKLOG/CHANGELOG edits
  by workers; no SAVE_VERSION change (`profession_ranks` is a life stat, defaults to 0). Nothing filed.
  - Fixed ([REVIEW] commit): RENOWN-006's journal line put the next title's discount after the current one
    ("35 (Known). 15 more for Respected. Merchants there take 6 percent off."), reading as today's discount (Known is
    3%, and an unknown player has none). It now says "As Respected, merchants there take 6 percent off."
  - Checked: C-131's bigger output counts work with Items.sell_price (per-unit material value drops, so revenue is
    ~1.3x cost, not a windfall); Clear Heart now yields 4 pills (+3 alignment each) for 88 stones vs 60 each in shops,
    which is what crafting should feel like. PROF-003's work() applies exactly work_preview. YEAR-008 counts ranks in
    Professions.add_xp, so every source (work, crafting, commissions) is covered. QA-20261016-1 counts only a region's
    first title. EPI-003 picks the highest titled region. C-123's help text and stage test updated; WU-194 bands on the
    printed percent. C-127's guidance test helper strips the real void pill only from its own GameData.
  - Notes, not filed: C-127's recipe scroll comes from an inheritance that needs Void Refinement to enter, so its
    claimant can only brew the pill for sale. C-131's follow-up (array_master rank-0 array sells below cost) is open.
- 2026-10-16 (reviewer): reviewed e673015..37fd69d (WU-197, QA-096, WU-198, C-124, C-132, WU-199, C-125, WU-203, QA-087,
  INH-006, GUIDE-042, RENOWN-007, WU-202, C-133, GUIDE-044, QA-097; [PLAN]/claim commits skipped). Main green. No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-042's herb_here_hint was called from _untried_feature_hint, so it needed realm >= 1
    and day >= 60 and lost to "You know a recipe" (its test passed only because _veteran() is realm 1 with every life
    stat at 1). Per the spec it is now appended in hints() for any realm and day, skips recipes above the player's
    rank and names the gather place ("Spirit Herb grows at Village Herb Slope: ..."). Tests: a Mortal on day 0 hears it;
    a region with no gather place gives "".
  - Checked: INH-006 still posts the rival news for every loss and counts only known grounds. RENOWN-007's sources are
    read by Renown.gain (unknown keys give 0); patients is a fixed one-month session, so +2 a month is no farm. C-133's
    margin test now covers every profession's rank-0/1 recipes. C-124/C-125 encounter data is well-formed (duels
    grudge <= 5, rank-4 requires). WU-202's banner trims instead of wrapping. GUIDE-044 uses work_preview.
  - Notes, not filed: QA-097 finds Array Master still loses money even with gathered ingredients and shop-bought
    crafting is negative for Alchemist/Blacksmith/Beast Tamer (planner: PROF-004 / an array follow-up). C-133's
    Minor Spirit Gathering Array margin is 29 vs 28. The herb hint ignores seasons (it can say a summer herb grows here
    in winter).
- 2026-10-16 (reviewer): reviewed 37fd69d..e0dd610 (C-134, YEAR-009, WU-200, C-135, QA-098, QA-099, WU-205, WU-204,
  PROF-006, C-138, PROF-005, WU-206; [PLAN]/claim commits skipped). Main green (1945 tests). No BACKLOG/CHANGELOG edits
  by workers; no SAVE_VERSION change (`profession_stones` is a life stat, defaults to 0). Nothing filed.
  - Fixed ([REVIEW] commit): YEAR-009 counted every sale of a craftable item as craft income, so a character with no
    profession selling a looted sword or a bought pill heard "Your craft earned N spirit stones". Items.sell now counts
    a sale only if a recipe of a profession the seller practises makes the item (Items.crafted_by_own_profession);
    test extended. C-138's fox-kit tamer choice says you offer a pellet from your pouch but rewarded +1 pellet; the
    pellet reward is removed.
  - Checked: PROF-006's rank-0 requirement says "You need to practise X" for a non-practitioner and the validator
    accepts 0. PROF-005's STONE_VALUE only affects recipes that spend stones. C-135's pill is no_shop, its recipe scroll
    only at the legendary auction slot. WU-205's moved Workshop/Bounty Board don't overlap neighbours. WU-206 reuses
    GUIDE-042's _gatherable_items with the current region first.
  - Notes, not filed: C-138 (forest snared fox kit) is close to the older mountain_lost_fox_kit (snared silver kit).
    WU-206's "grows at" also reads for ores. The crafting screen now names gather places twice for a missing herb
    (ingredient line and the "where" block from Items.sources).
- 2026-10-16 (reviewer): reviewed e0dd610..5709257 (RIVAL-018, C-139, GUIDE-046, C-137, WU-195, QA-100, PROF-004, GUIDE-048,
  C-141, PROF-007, RIVAL-020, WU-201, QA-094, GUIDE-047; [PLAN]/claim commits skipped). Main green (1963 tests). No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (`rival_caught_up_realm` is a world flag, defaults to -1).
  Nothing filed.
  - Fixed ([REVIEW] commit): PROF-007 called the whole monthly roll on a first craft, so a Blacksmith with no open order
    who started alchemy also got an early blacksmith order (each new craft = a free extra roll for the others).
    Commissions.roll takes `only_prof` and the early roll passes the new craft; tests in test_commissions and
    test_game_session (it failed with 2 orders before the fix). WU-201's where block called herb_place without the
    day while the ingredient line used it, so out of season the two could name different places and the dedupe
    missed; both now get GameClock.total_days. C-139's help line said only Doctors take odd jobs; PROF-004 made that
    false, reworded.
  - Checked: PROF-004's work_profession pays exactly work_preview for a craft. C-137's array now nets positive when
    gathered. RIVAL-020 posts once per realm and needs the first meeting. GUIDE-047 only speaks when the herb hint is
    silent and skips Doctors (no recipes). C-141's guard covers every rank-0 ingredient.
  - Notes, not filed: herb_place's out-of-season fallback names only the first listed season. GUIDE-047's "short of
    stones" compares stones with the full shop cost of the cheapest recipe, so it can fire for a crafter holding the
    herbs but not the stones for the rest. WU-195's "Gathered herbs make it pay" also shows on ore/array recipes.
- 2026-10-16 (reviewer): reviewed 5709257..aa35b48 (WU-207, WU-208, YEAR-010, QA-101, WU-209, WU-210, C-128, WU-211,
  GUIDE-049 (+ its --hint-shot fix), C-144, GUIDE-052, C-142, WU-212; [PLAN]/claim commits skipped). Main green. No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (GUIDE-052 falls back for orders without "recipe").
  Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-052's due_soon_hint took the soonest order within 14 days and then went silent if
    the pack already filled it, hiding a later short order that is also due soon. It now picks the soonest order that
    is still short; test added.
  - Checked: YEAR-010 appends the rival line last and needs the first meeting and a living rival. GUIDE-049's rank
    gate applies to both the craft-now and herb hints per recipe's craft. C-128's six foes/encounters mirror the Void
    set (alignment gates -300 / -599 match their counterparts). C-144's new rank-1 starters (Paired-Flag array,
    Mist-Bone Cake, Wolfhide Brigandine) use reachable ingredients and the guard test covers all five crafts.
  - Notes, not filed: missing_line skips spirit stones, so an order short only of stones says "You have the
    ingredients". C-144 left recipe_spirit_gathering_pill's scroll redundant (the pill is now a starter). WU-209's
    margin wording logic lives in crafting_screen.gd (UI) rather than a system.
- 2026-10-16 (reviewer): reviewed aa35b48..1e438fc (C-129, WU-213, GUIDE-050, QA-103, GUIDE-051, QA-102, WU-214, QA-104,
  BI-001, PROF-009, PROF-008, WU-218, C-146, QA-105; [PLAN]/[REVIEW] commits skipped). Main green. No BACKLOG/CHANGELOG
  edits by workers; no SAVE_VERSION change (no new persistent state). Nothing filed.
  - Fixed ([REVIEW] commit): PROF-008 put _post_rank_up between _start_time_skip and its doc comment, so the "Remember
    the player's numbers" line documented the wrong function; moved back. PROF-009's available_nearby doc said "without
    leaving region_id" but a merchant in any region counts; doc now says so.
  - Checked: BI-001's body row needs body_stage >= 8 for stages[7] (body_stage counts stages reached) and realm 7 is
    body_integration. C-129's stone costs are gated by Effects.check; its enemy and dao ids load. GUIDE-050's shortfall
    uses recipe_margin's unit prices. GUIDE-051 picks the place with the nearest coming season. WU-218's joins read
    right with an empty seasonal note.
  - Notes, not filed: C-146's Iron Sword and Iron Scale Armor now take mostly spirit herbs (1 iron essence + 3/4 herbs),
    which reads oddly for a smith; a gatherable ore would fit better if one exists in the village. PROF-008's rank-up
    line only names recipes of the exact rank reached, so a two-rank jump skips the lower one. PROF-009 counts any
    merchant in the world as "nearby".
- 2026-10-16 (reviewer): reviewed 1e438fc..f27406e (C-143, WU-217, C-145, WU-193, GUIDE-053, WU-216, QA-106, WU-219,
  GUIDE-054, WU-221, GUIDE-055, WU-220, QA-107, WU-222, C-136; [PLAN]/[REVIEW] commits skipped). Main green. No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (no new persistent state). Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-054's Mortal crafter nudge still said "Meditate ... to begin cultivating (about 0
    days)" once the Mortal could already break through, next to the breakthrough hint; it is now silent then (test
    added). GUIDE-053 made goals() return more than the "up to 3 plain lines" its doc promised; doc updated.
  - Checked: WU-219's word cut keeps the hard cut for a single over-long word. GUIDE-055 lists year-round finds only
    when the table also has seasonal entries and never names an item twice. C-145 keeps the old scroll item for older
    saves. C-143's encounters are once-only (blocked_by_flag) and C-136's inheritance uses an existing region.
  - Notes, not filed: C-143's old alchemist's notes and C-145's Verdant Remnant treasure both teach Visceral Mending, so
    a player can get that scroll twice. GUIDE-053's next_recipe_line scans every item to find the scroll each call.
- 2026-10-17 (reviewer): reviewed f27406e..7144c97 (GUIDE-056, C-147, WU-223, PROF-010, C-148, PROF-011, WU-224,
  QA-20261017-1, MAHA-001, C-153, WU-230, WU-215, GUIDE-059, WU-225, C-151, PROF-012, WU-226; [PLAN]/[REVIEW] commits
  skipped). Main green before and after (2011 tests). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change
  (no new persistent state). Nothing filed.
  - Fixed ([REVIEW] commit): Text.plural (GUIDE-056/059) inflected the last word of "Kind: Title" names, so selling or
    storing two scrolls read "2 Manual: Iron Fists" / "Recipe Scroll: Great Vehicle Pills"; it now inflects the kind
    ("Manuals: Iron Fist"). Thunder-Scarred Jade and Celestial Fox Essence Blood got `plural` overrides like the other
    jades (QA-20261017-1 missed them). Tests added.
  - Checked: PROF-010's rank_up_line range (from_rank, rank] matches every _post_rank_up caller passing ranks_gained.
    PROF-012's max_count never drops below 1 and skips ingredients the pack covers or that are only bought. MAHA-001's
    hardcoded realm index 8 matches realms.json. C-151's quarry does not overlap other Qingshi places.
  - Notes, not filed: Guidance.goal_ladder's trailing `mahayana_goals_active` fallback is redundant (realm 8 already maps
    to "mahayana"). max_count lets each missing ingredient use the full FILL_SHARE of the window, so a two-gathered-
    ingredient order can still be tight.
- 2026-10-17 (reviewer): reviewed 7144c97..f07c93b (C-152, C-149, WU-227, WU-229, WU-228, QA-108, PROF-013, C-154,
  WU-231, WU-232, C-155, PROF-014, YEAR-011, QA-110; [PLAN]/[REVIEW] commits skipped). Main green before and after. No
  BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (commissions_lapsed is a LifeStats key, defaults to 0).
  Nothing new filed (the planner's C-161 covers the rest).
  - Fixed ([REVIEW] commit): forced (non-lethal, not a choice) fights that were walls, C-153's way.
    wild_great_vehicle_magistrate (C-148) got min_stage 3: 0% -> 35% (QA-110's FLAG). C-154's Ascent-Warden Arbiter was
    4% at its TT/2 gate and under 20% at every TT stage (late_gates only reaches Mahayana, so QA-110 missed it): foe
    stage 1 -> 0 and min_stage 2 -> 3, now 39%. C-152's Sutra Barge realm stage got min_stage 3 (guardian 0% -> 35%).
    C-155's bell label "(Spirit 64)" (and C-143's "(Comprehension 12)") repeated the "[Spirit 64]" tag the encounter
    window already prefixes; labels trimmed, test added that no choice label repeats its check tag.
  - C-161 (planner) covers the remaining inheritance guardians (8-11%); its row now says which parts are done.
  - Checked: PROF-013's lapse_text reads the order after expire() removed it (fine, it only reads the entry).
    PROF-014's estimate only runs when short_ingredient found a positive shortfall, so days >= 1. YEAR-011's line
    pluralises both counts. C-155's stone costs are gated by Effects.check.
  - Notes, not filed: every lethal Mahayana/TT foe is 0-5% at its realm's stage 0 (C-154's own follow-up); they are
    evadable, but late_gates should grow to tribulation_transcendence when C-157/C-158 land.
- 2026-10-17 (reviewer): reviewed f07c93b..f702631 (WU-235, GUIDE-060, WU-233, GUIDE-057, C-150, TT-001, WU-234,
  WU-237, PROF-015, QA-109, C-160, WU-238, WU-236, PROF-017, PROF-016, WU-239; [PLAN]/[REVIEW] commits skipped). Main
  green (2038 tests after the fix). No BACKLOG/CHANGELOG edits by workers; no SAVE_VERSION change (GUIDE-057's
  last_meditated_day defaults to -1). Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-057 stamped last_meditated_day with the day a meditation *began*, so right after a
    month or a year in seclusion a Qi Refining crafter was told "You have not cultivated in 1 month". It is now the day
    the cultivation ends (cultivate, dual cultivation, inner world), and only after dual/inner-world cultivation
    succeeds. Old saves (-1) read "You have not cultivated lately." instead of claiming years since day 0. Tests updated.
  - Checked: PROF-015's per-place max matches how one gather trip rolls every entry of a table. PROF-016's
    _stones_needed uses the same crafts count as short_ingredient; both callers handle "spirit_stone". GUIDE-060's
    recipe_scrolls keeps the first scroll in data order, as the old scans did. TT-001's ladder id 9 matches realms.json.
  - Notes, not filed: QA-109's shop-only talisman_paper and C-160's still-unwinnable rogue are in the planner's
    QA-114/GUIDE-065 queue.
- 2026-10-22 (reviewer): reviewed f702631..df910b9 (782b198 QA-114, 79663f7 WU-242, 2e64d73 C-161, 35c59cc GUIDE-062,
  df910b9 GUIDE-065; [REVIEW] commit skipped). Main green (2040 tests). No BACKLOG/CHANGELOG edits by workers; no save
  changes.
  - Fixed ([REVIEW] commit): GUIDE-065's thin-defence hint told a Foundation cultivator who already knew a body art to
    "learn a body technique ... and wear armor" (and one in armor to wear armor). It now names only what is missing;
    the spec's full line stays when both are. Test extended.
  - Checked: GUIDE-062's REALM_GOAL_TABLE body row uses body_stages[realm_index], matching the old hard-coded 5/6/7
    (soul/void/body realm indices in realms.json); goal texts unchanged; goal_ladder's fallback now also covers
    soul/void/body (harmless, those ids are named first). C-161's min_stage gates are in the realm stage the doc
    allows, baseline rows refreshed. WU-242 is sim-only. QA-114's numbers are clear and GUIDE-065 follows its text.
  - Filed RV-QA-115 (qa, P0): docs/balance_baseline.txt is stale on main (~1000 changed lines on --check), refresh
    it after checking for real regressions.
- 2026-10-22 (reviewer): reviewed df910b9..147a890 (9b3a988 WU-244, 08645d4 QA-112, 31a00d2 C-165, b714be7 C-166,
  7301934 WU-243, e5a2b4a GUIDE-066, a6adbaf GUIDE-067, cb62be7 WU-246, 147a890 WU-247; [PLAN] commit skipped). Main green.
  No BACKLOG/CHANGELOG edits by workers; no save changes. Nothing filed.
  - Fixed ([REVIEW] commit): WU-244's ShopScreen.upgrade_tag priced gear with no faction, so at a sect-affiliated
    merchant a Respected+ player who could afford an upgrade only at the discounted price got no "(upgrade)" mark. It
    now takes the shop's faction (the row price the player sees). Test extended.
  - Checked: GUIDE-067's table lookups call realm_goals exactly as the removed soul/void/... wrappers did; the new
    `index` column is pinned to realms.json by a test. GUIDE-066 skips any recipe with a gatherable or unsold
    shortfall and tests both paths. C-166's peddler choice is gated by check_choice on 8 stones (tested); C-165 is
    text only. QA-112's TT rows: the only forced fight wins 39%. WU-243/WU-246 are sim-only, WU-247 test-only.
  - Notes, not filed: GUIDE-066 quotes the item's base price, not the merchant's (reputation/world-event) price;
    upgrade_tag only compares attack/defense, so a lower-defense armor with more max_hp is never tagged.
- 2026-10-22 (reviewer): reviewed 147a890..26a9b5b (765226b RV-QA-115, 286bc33 C-168, 0b020b6 QA-113, d3e55f7 WU-248,
  6e5264a GUIDE-071, 970de24 ENC-006, 30a60ad WU-250, 26a9b5b QA-118; [PLAN]/[REVIEW] commits skipped). Main green
  (2054 tests). No BACKLOG/CHANGELOG edits by workers; no save changes. Nothing filed.
  - Fixed ([REVIEW] commit): ENC-006's `renown` effect is applied inside Effects (core, no signals), so a title it
    earned showed only as a note in the log and never raised the HUD renown banner that every other renown gain
    raises (renown_tier_reached). GameState now emits it after an encounter/choice whose effects crossed a tier.
    Test in test_renown_ui.gd.
  - Checked: ENC-006 validates 1..50 and is a no-op without a region (items/deeds never pass one; no content uses
    the key yet, C-167 will). GUIDE-071 only names items whose heal_injury matches or is "all", and falls back to
    the old wording without a region. WU-248 is a row suffix (tested). QA-113's numbers back CMB-010 (already
    planned); QA-118/WU-250 are sim-only, C-168 text only.
  - Notes, not filed: GUIDE-071 checks only the first injury, quotes the merchant's base price, and when the local
    clinic is unaffordable may point at a neighbouring region's clinic without checking its cost.
- 2026-10-22 (reviewer, 2nd run): reviewed 26a9b5b..fe1822e (db44262 GUIDE-068, 1c214d8 WU-249, 4517bd4 C-157,
  a5fa0be WU-251, 00cf914 GUIDE-070, ae2338f WU-252, 7f3ce78 C-167, 6a208a6 C-169, c72362a QA-117, 61e503e WU-240,
  5060f58 GUIDE-069, 2412461 CMB-010, fe1822e QA-116; [PLAN]/[REVIEW] commits skipped). Main green. No BACKLOG/CHANGELOG
  edits by workers; no save-format changes. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-069's GameState test computed `affordable_armor` before giving stones (dead line) and
    never asserted an armor was found; now it asserts one is.
  - Checked: GUIDE-070's sort (stones, chance, text) matches the spec, and every caller still reads correctly
    (pill_gap_note already picks the best payer). CMB-010 matches spec (indices 7-9 = index 6, doc updated). C-157's
    pill gates on Mahayana (tested) and its recipe is an auction lot. C-169's "ten days" matches regions.json.
    WU-249 keeps `_log_lines` and the RichTextLabel in sync (rebuilds on collapse, cap still enforced, tested).
    C-167's renown amounts are tested per choice; the ENC-006 banner fix covers them.
  - Notes, not filed: C-167's test skips road_lost_child's "carry her" choice (+5, needs CON 12). GUIDE-068/069 still
    quote the base item price, not the merchant's; GUIDE-072 (spec'd) covers Qingshi's empty "where".
- 2026-10-22 (reviewer, 3rd run): reviewed fe1822e..efde69a (88c1487 WU-253, faea659 WU-255, 2e166a5 WU-254, af914f0 GUIDE-072,
  7198e9b C-159, 9ebebd5 GUIDE-073, c8df013 GUIDE-075, cfdccdd C-171, 9073801 GUIDE-074, 8ece6ee GUIDE-080, 7cf29fe GUIDE-076,
  41f0f05 QA-120, 6428f6e C-175, efde69a WU-257; [PLAN]/[REVIEW] commits skipped). Main green (2088 tests). No
  BACKLOG/CHANGELOG edits by workers; no save-format changes. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-074's empty "Fights you can win" note told the player to "practise <X> past level N"
    even when X was already at its max level (Blood Demon Rage has max_level 1; the GUIDE-074 test itself asserted
    "past level 3" for it at level 2). It now skips mastered techniques and says only "grow a stage." when all are
    mastered; the test fighter uses iron_fist and a new test covers both cases.
  - Checked: GUIDE-073's merchant_price applies the place faction's reputation and the region's renown, like the shop
    (minus world events, as documented); affordable_armor/heal_source/buy hint use it. GUIDE-072's nearest_selling is a
    bounded Dijkstra over travellable routes; GUIDE-075/076 reuse it as spec'd. WU-254 rejects any lower stat. GUIDE-080's
    row matches spec (thin-defence hint kept, reason in commit). WU-257 restores the full hint on every _refresh.
    C-175 renown amounts tested per choice.
  - Notes, not filed: C-171 moved the arbiter's stage (0 -> 1) instead of its attack because attack/hp barely move the
    rate; it lands at 77%, under the 85-95% target (the commit explains). WU-257 did not re-run --pill-shot/--hint-shot
    (WU-258 takes new hint shots). heal_source's neighbouring-clinic step still skips cost (GUIDE-077 is filed).
- 2026-10-22 (reviewer, 4th run): reviewed efde69a..157a41d (b8e72fe WU-256, 3646d0d WU-263, 16bdd07 C-170, bd30d6c WU-260,
  80f6bac GUIDE-077, 2487888 WU-264, c0eea16 GUIDE-082, 036e5dc WU-265, fc46022 QA-121, d1ec540 WU-266, 737b9f9 WU-258,
  e15a897 WU-262, 157a41d C-163; [PLAN]/[REVIEW] commits skipped). Main green (2094 tests). No BACKLOG/CHANGELOG edits
  by workers; no save-format changes. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-077 appended "for your <injury>" after a clinic clause, so with two injuries the hint
    read "the Village Clinic in Qingshi Village (3 days) treats it for 80 stones for your Qi Deviation". A clinic clause
    now says "treats your <injury> for N stones"; item/merchant clauses keep the suffix. Test added.
  - Checked: GUIDE-077 matches spec (far-clinic pick skips it when the cost exceeds stones; local clinic handled first).
    WU-260's gear_elsewhere_line lives in Guidance, the note is a non-focusable label, hidden on the Sell tab (tested).
    WU-256 only reorders text; WU-264's audit covers it. GUIDE-082 test asserts the two-sentence form. C-163's test reads
    the recipe cost instead of a literal. QA-121, WU-258/262/263/265/266 are sim/screenshot-only.
  - Notes, not filed: heal_source picks the first injury with any source, so a far clinic for injury 1 wins over an
    owned item for injury 2 (dictionary order, as spec'd). A merchant clause with two injuries still reads
    "sells X for N stones for your <injury>". QA-121: the defence hint alone leaves 0/9 seeds at >=50% vs Foundation
    foes 60 days in (healing and a body art missing); for the planner.
- 2026-10-22 (reviewer, 5th run): reviewed 157a41d..be6f18b (ab1bb8a QA-119, 94392f1 C-172, 6c301eb GUIDE-081, b427f8e CMB-011,
  9237d4d QA-123, 347ff2d C-178, d47cc8e GUIDE-083, ba4a862 WU-267, 5dae9b5 GUIDE-084, 279b2ed WU-269, be6f18b QA-122;
  [PLAN]/[REVIEW] commits skipped). Main green (2107 tests). No BACKLOG/CHANGELOG edits by workers; no save-format changes. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-084 tacked the stipend after the sentence on the open-trial line ("Attempt it at a sect
    hall. (it pays 6 stones a month)"); it now reads "The trial for Inner Disciple is open (it pays 6 stones a month).
    Attempt it at a sect hall." (GUIDE-085's "The trial for Inner Disciple is open" match still holds). C-178's forest
    choice "Trade him a few stones for a skinning knife" paid the player 2 stones and gave no knife; relabelled to
    helping him carry pelts for 2 stones.
  - Checked: GUIDE-081 days_to_next matches Techniques.practice's rate (ceil, 0 at max). CMB-011 validated in GameData,
    applied once in enemy_stats before the flat bonuses. GUIDE-083 shares one Dijkstra with nearest_selling (hop limit
    kept there). WU-267 adds the to-level button first so _focus_first_action reaches it; HFlowContainer wraps. WU-269
    clamps in local coords from the canvas transform; world.gd only redraws near-edge labels when the camera moved.
  - Notes, not filed: WU-267 and WU-269 skipped their screenshots (WU-268 / follow-ups cover them). QA-122: a 10-stone
    Array Master can never afford the cheapest in-rank recipe (21); for the planner. "a %s" in _stipend_clause would
    read "a Elixir..." for a vowel-initial item (none in sect stipends today).
- 2026-10-22 (reviewer, 6th run): reviewed be6f18b..bdadd91 (6a2e214 WU-268, 0503b9b C-173, f4cc287 GUIDE-087, 8580848 WU-273,
  24628cd GUIDE-086, 4f134c7 QA-126, 324c890 GUIDE-091, 885d2ec GUIDE-085, bdadd91 GUIDE-078; [PLAN]/[REVIEW] commits
  skipped). Main green. No BACKLOG/CHANGELOG edits by workers; no save-format changes. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-086's practice hint hard-coded "you would beat a %s", so it read "beat a Iron-Back
    Boar" / "a Ice-Soul Spider"; it now uses Text.a and the test asserts the article form.
  - Checked: GUIDE-086 rates at most FAIR_FIGHT_EXPLORE_MAX foes on a copied character, and Combat.win_chance is cached,
    so the HUD refresh cost stays bounded. GUIDE-087 rates the trial first (it counts toward FAIR_FIGHT_MAX_RATED) only
    when check_promotion passes; GUIDE-085 reuses the same trial_opponent. GUIDE-091's qi_days_lost walks each day with
    the still-active multipliers (tested in test_injuries). QA-126 is sim-only plus a guard test. WU-268/273 are
    screenshot-only; C-173 is help text (clinic names match regions.json).
  - Notes, not filed: GUIDE-078's "barely pays" spend counts only the first bought-only ingredient, and its full recipe
    count even when some are owned (errs toward the warning). GUIDE-085's under-even clause says "practise or grow a
    stage" even when every style is mastered. QA-126: docs/balance_baseline.txt first-hour curious sections are stale,
    and the game itself still offers 0% rival duels with only the choice's fight label as warning; for the planner.
- 2026-10-22 (reviewer, 7th run): reviewed bdadd91..275a886 (1f468b9 WU-270, 852ca9c GUIDE-088, 93c4fb2 WU-272, d0e6f1a WU-274,
  18545f1 C-179, cdfb2f9 C-176, 24a2bfa WU-271, 7991253 C-180, a60bb90 QA-127, 553e1fa C-177, fc28516 WU-276, d93d849 GUIDE-092,
  2fd5f51 QA-111, f10b31a QA-129, 41678fe WU-278, e084bbe WU-279, d935e0f GUIDE-090, 80e370d WU-280,
  5618558 C-181, 275a886 ENC-007; [PLAN]/[REVIEW] commits skipped). Main green. No
  BACKLOG/CHANGELOG edits by workers; no save-format changes. Nothing filed.
  - Fixed ([REVIEW] commit): WU-270's Techniques payoff line hard-coded "beat a %s" (the same "a Iron-Back Boar" bug fixed
    in Guidance last run); it now uses Text.a and the test asserts the article form. WU-278 moved the name label to a
    child Node2D, but Interactable._refresh (on player_changed) still only redrew the parent, so an NPC turning into
    "(rival)" or changing danger color kept its stale label until the near-range or camera-edge redraw; _refresh now
    redraws the label layer too.
  - Checked: GUIDE-092's odds_unhurt rates a copied, healed character, and fight_fingerprint includes injuries, so the
    win_chance cache can't return the injured odds. GUIDE-088's sell_offer is the old _sell_hint body; the loot budget only
    feeds affordable_armor/_far_armor_clause. C-179 adds renown 3 to six help choices; C-177 power_mult is validated
    data. WU-278 spreads place and NPC labels together (tested). QA-111/127/129 and WU-271/272/276/279 are sim/screenshot-only.
  - Also checked: ENC-007 rates a choice only when it is enabled (win_chance is cached); GUIDE-090 reuses sell_offer
    and the shared _sell_first_clause; WU-280 marks via HUD.hints_changed and also on world _ready (scene reload per region).
  - Notes, not filed: the GUIDE-092 heal clause doesn't name where to heal (heal_source exists). WU-280 matches whole
    display_name, so an NPC ("Name (Qi Refining, ...)") is never marked even when the hint names them. For the planner.
- 2026-10-22 (reviewer, 8th run): reviewed 275a886..393b4e4 (1f467bc C-184, 8c67b18 QA-20261022-1, 5418691 C-185, 0298041 GUIDE-095,
  cd37b54 GUIDE-094, a9ebd78 C-187, 71ff891 GUIDE-093, ae3d076 WU-277, 2b5a5e6 GUIDE-096, 25890e7 QA-131, 1073b8d GUIDE-098,
  987c5a1 GUIDE-097, 393b4e4 WU-281; [PLAN]/[REVIEW] commits skipped). Main green. No BACKLOG/CHANGELOG edits by workers;
  no save-format changes. Nothing filed.
  - Fixed ([REVIEW] commit): WU-281's two new spread_on_screen tests never freed their NPC nodes (the rest of
    test_first_hour_labels.gd frees them); they now do.
  - Checked: GUIDE-094 drops the Gather line only when the idle nudge shows, and idle_crafter_hint already returns "" at a
    bottleneck, so a breakthrough-ready crafter still sees the breakthrough line. GUIDE-095 rates both now/next on the same
    healed copy. GUIDE-096 _keep_trial swaps the trial in for the last shown entry. GUIDE-098 records prev only where
    best_days improves, so first_hop walks the final shortest path; first_hop/hinted_region are unused until WU-283/GUIDE-100
    (both queued). WU-277's chance is only set for enabled fight choices (-1 otherwise, no suffix). C-184's village_boxer
    uses the existing enemy `spar` flag; C-184/C-187 encounters validate (test_encounter_choices).
  - Notes, not filed: WU-281 (like spread_labels) also dodges labels of hidden (unavailable) and highlighted nodes, so a
    label can lift away from one that isn't drawn; the hinted "!" badge isn't part of the rect either. WU-281's 1280x720
    screenshot re-run is still owed (its Follow-ups).
- 2026-10-22 (reviewer, 9th run): reviewed 393b4e4..f75f86d (cd17f87 WU-282, 43d4b24 C-182, 5c39e36 GUIDE-100, a8d8ae8 GUIDE-099,
  7caa1ea C-158, 76a3641 C-191, dbcd289 WU-283, 915b95c WU-284, ab250cb QA-130, 961ba59 GUIDE-101, 055f597 GUIDE-102,
  f75f86d WU-286). Main green. No save-format changes, no worker BACKLOG/CHANGELOG edits. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-102 put the best mission before the "(N more ... too dangerous for you yet)" clause, so
    the line read "...: Patrol (2 days) (1 more mission is too dangerous for you yet)." The count clause now stays on the
    count sentence and the best mission follows it. Regression test test_best_mission_after_too_dangerous_count.
  - Checked: WU-286's lethal flag comes from the mission's enemy, matching take_mission -> fight_enemy, and rank trials go
    through Sects.trial_opponent (lethal false), so "to the death" is right in both places. Per the spec, the odds now show
    without the appraising eye (Appraisal.danger_text stays for bounty/explore until WU-287). GUIDE-099 rates a healed copy
    (from_dict(to_dict())). GUIDE-100/101 _by_way_of drops the clause when the first hop is the destination.
  - Notes, not filed: WU-283 still marks the road when hinted_region names a region with no path (first_hop ""); then
    no route says "The hint points this way". WU-284 matches against data place names, while the world matches Interactable
    display_names, so a hint that names only an NPC marks the NPC but shows no HUD badge. WU-283/284/286 screenshots are
    still owed (their Follow-ups).
- 2026-10-22 (reviewer, 10th run): reviewed f75f86d..56b85f2 (bce24d0 GUIDE-105, 32291d1 QA-132, 4ffa9d0 GUIDE-103, 1367fc0 C-195,
  e220831 WU-285, 33762b6 C-188, cb21345 GUIDE-106, d8f1bd1 WU-287, cba3444 WU-288, 2a27718 QA-133, f3b60e6 C-197, 3a745a0 C-198,
  4b4a6df GUIDE-109, 25282c0 WU-289, 31a34bc QA-135, 5cd9e05 GUIDE-107, 56b85f2 WU-290; [PLAN]/[REVIEW] commits skipped).
  Main green. No save-format changes, no worker BACKLOG/CHANGELOG edits. Nothing filed.
  - Fixed ([REVIEW] commit): GUIDE-109 pluralized the item with a bare "s", so two snow lotuses read "2 Hundred-Year Snow
    Lotuss"; it now uses Items.item_plural (items.json `plural` + Text.plural). Regression test
    test_newcomer_herb_hint_plural_follows_item_plural.
  - Checked: GUIDE-105's "heal first" only fires when odds_unhurt (-1 when uninjured) reaches the same 0.5 line
    mission_too_dangerous uses. WU-287's lethal flags match the fights: bounty foes use the enemy's own flag, tournament and
    incursion foes come from WorldEvents.opponent (lethal false). GUIDE-107 _hall_where reuses nearest_selling/_far_where.
    GUIDE-103 names the breakthrough only below the last realm. C-195/197/198 content validates (test_encounter_choices).
  - Notes, not filed: GUIDE-106 calls fair_fights (up to FAIR_FIGHT_MAX_RATED x 40 simulated fights) for the untried road
    on every hints() call; worth folding into PERF-001. WU-285 leaves a hidden label's old screen_lift until the next spread.
- 2026-10-22 (reviewer, 11th run): reviewed 56b85f2..65d397e (95f80ee C-194, a2d4395 C-189, 25da799 GUIDE-104, 8d387f0 GUIDE-108,
  e2dfab6 WU-291, fc623d2 QA-137, ffb7c92 WU-241, 85fa6d7 WU-292, d77cfdb QA-136, 56323fa C-200, 65d397e WU-293; [PLAN]/[REVIEW]
  commits skipped). Main green. No save-format changes, no worker BACKLOG/CHANGELOG edits. Nothing filed.
  - Fixed ([REVIEW] commit): WU-291 preselected the best-pay mission only when it came before every other ready mission in
    the list (the loop broke on the first takeable one), so with a Weak mission listed above it the hint's mission was not
    selected. It also called Guidance.best_mission (which rates every mission's fight) once per label, O(n^2) fights per
    rebuild; it is now computed once and passed to label_for. Regression test test_best_pay_mission_preselected_below_the_top;
    test_trial_line_never_says_to_the_death no longer relies on a session left over from an earlier test.
  - Missed, caught by the planner (GUIDE-108b, P0): GUIDE-108's helper takes Array[String] but hints() passes a
    PackedStringArray, so it edits a copy and never reaches the game. Its wording ("the practice above") is right once
    wired: practice_hint comes from _newcomer_hints, before the mission hint. WU-293's region_marker_names mirrors
    World._build_npcs/_build_generated_npcs naming. WU-292 passes the player so an unreachable hinted region marks nothing.
    C-200's stag is non-lethal and joins QA032_BARE_DEADLY. QA-136/QA-137 only touch sims/tests.
  - Main went red after the reviewed range: two workers both landed C-201 (c3e0255, then 752addf), so sect_missions.json
    held two herb_hall_tithe entries; the first (no stone reward) failed test_item_missions_pay_at_least_the_items_cost
    (5e062ff then gave the first entry the same 22 stones, keeping the duplicate).
    9aae3a6 (a worker) removed one row; the [REVIEW] commit finishes C-205 (the spec's description) and adds
    test_data_unique_ids (DATA-001's validator still owed), which fails on any repeated
    id in a top-level data list (most tables load into id-keyed dictionaries, so duplicates silently overwrite).
    c3e0255/5828c50/752addf/5e062ff/9aae3a6/8737204 are otherwise left for the next review.
- 2026-10-23 (reviewer): reviewed 65d397e..89bc68f (C-201 x2, PERF-001, GUIDE-110/112/113/114/108b, WU-294..298, C-199,
  C-205, ENC-008, QA-128/139, DATA-001; [PLAN] commits skipped). Main green before and after (2197 tests). No
  BACKLOG/CHANGELOG edits by workers; no save-format changes.
  - ENC-008 (attribute checks): core roll on the passed rng (rng = null succeeds), on_fail validated (attribute, target,
    enemy, items), GameState applies on_fail's rival/renown/grateful keys. Its GameState test passed whichever way the
    roll went (qi only grows, target 1 = 90%); the [REVIEW] commit adds a deterministic both-outcomes check (rng probed,
    on_fail renown 3 vs success renown 5). No encounter uses `check` yet (ENC-009's content). A check choice that also
    fights shows the roll chance, not the fight odds; acceptable while none exists.
  - PERF-001: the cache key (data, region, realm, alignment) covers everything _scan_first_combat_manual reads.
  - GUIDE-113/114, GUIDE-108b: merges now return PackedStringArray and are reassigned in hints(); the sell merge matches
    both " Sell your" clauses (both mid-line). GUIDE-110/112, WU-294/296/297, DATA-001 (load_errors on any duplicate id
    in a top-level list, overlapping test_data_unique_ids, harmless) match their specs with tests. Nothing filed.
- 2026-10-23 (reviewer, 2nd run): reviewed 89bc68f..ddada62 (GUIDE-111/115/120, ENC-009, WU-299/300/301/306, QA-138, PERF-002,
  TOOL-001, C-202/203/209; [PLAN]/[REVIEW] commits skipped). Main green before and after. No BACKLOG/CHANGELOG edits by
  workers; no save-format changes.
  - Fixed ([REVIEW] commit): ENC-009 routes non-lethal foes the player would likely lose to through the FH-004 threat
    prompt, but the prompt and log were written for lethal foes: the log said "hungry for a kill" and, on the last life,
    the Fight option carried the final-death warning although losing a non-lethal fight never kills. Both now depend on
    the enemy's lethal flag. Regression test test_non_lethal_threat_never_warns_of_death.
  - Filed REV-030 (P0): GUIDE-111's "close" deliver test treats any held spirit stone as progress toward stone tithes (up
    to 960), and GUIDE-120/WU-306 say ores "grow at" a place.
  - Checked: WU-300's verdict is computed before on_fail replaces the choice. WU-299's qi_days_lost_for mirrors
    qi_days_lost per injury. GUIDE-115's feeds_cultivation is shared by bulk_sell_ids and the newcomer hint, so the
    shop total and Guidance.sell_offer stay in step. GUIDE-120's pick and clause match the spec. TOOL-001 skips the
    import when --import is passed or the class cache exists. C-209 (power_mult 0.6) answers ENC-009's follow-up.
  - Notes, not filed: WU-306's gather_place_for is called without `today`, so an out-of-season place still reads
    "grows ... here" on the board (the hint passes no season either).
- 2026-10-23 (reviewer, 3rd run): reviewed ddada62..9f32f92 (WU-302/303/305/308/310/312, GUIDE-117/118, REV-030, C-210/213/214,
  QA-141/142/143; [PLAN]/[REVIEW] commits skipped). Main green before and after (2223 tests). No BACKLOG/CHANGELOG edits
  by workers; no save-format changes. WU-305's empty claim commit (53ab40c) reached main (rebase without --no-keep-empty); harmless.
  - Fixed ([REVIEW] commit): GUIDE-117's payoff is rated unhurt (per spec, after GUIDE-095), but the sentence quoted that
    number as if it were the player's odds, so an injured player read "Iron Fist level 4 ... would make it about 15 in 100"
    while really lower. It now starts "Healed, ..." when the player is injured. Test
    test_trial_practice_payoff_says_healed_when_injured.
  - Checked: REV-030 (stone tithes close at half; ores "found at") matches the filed fix. WU-310's coloured lines index
    the hand-in items in requirement_lines' order (items first, then the foe); no data name contains "[" for BBCode.
    GUIDE-118 hides the herb hint only while a ready mission (check_mission == "") wants the herb. WU-305's cap cuts at
    a word boundary and the journal keeps the full line. QA-141/142/143 touch sims and the baseline only.
  - Notes, not filed: WU-308/WU-312's "Wanted by the sect" line also names missions on cooldown or above your rank
    (available_missions does not filter them); ShopScreen.sell_wanted_line reads GameState.world_flags from a static
    helper (UI, so allowed, but the inventory variant takes flags as a parameter).
- 2026-10-23 (reviewer, 4th run): reviewed 9f32f92..86d415e (C-206/207/211/215, GUIDE-121..125, WU-313..316, QA-134/144;
  [PLAN]/[REVIEW] commits skipped). Main green before and after (2239 tests). No BACKLOG/CHANGELOG edits by workers; no
  save-format changes.
  - Fixed ([REVIEW] commit): C-206's test_fighting_style_encounters asserted `gated >= plain * 0.0` for checked choices,
    which always passes; it now asserts the check trains on either outcome (gated > 0). WU-314 inserted buy_worth_line
    between sell_wanted_line and its `## WU-312` doc comment; the doc comments (and the orphaned "Equipped:" one, which
    belongs to compare_text) are back on their functions.
  - Checked: GUIDE-121/122/125's reordered hints: no other code string-matches the old wording (the first-hour sim's
    QA-134 policy calls best_mission directly, not the "The best pays" text); the trial stipend sentence trims
    _stipend_clause's " (it pays ...)" wrapper correctly. GUIDE-124's local spot is named only when denser than where
    the player stands, and the far spot only when it beats the local one by more than the round trip. WU-316's map "!"
    and hint_note skip the current region (hinted_region excludes it). C-206's on_fail outcomes cost days only.
  - Notes, not filed: WU-315 sets the hint label's mouse_filter to PASS even when no line was cut (harmless: the world
    has no mouse input). The thin-defence and injury hints still name Stone Skin Tempering in code (as before).
- 2026-10-23 (reviewer, 5th run): reviewed 86d415e..3c8c769 (WU-317/318/319/324, GUIDE-119/126/127/128, C-208/212/217/219,
  PERF-003, QA-140/146; [PLAN]/[REVIEW] commits skipped). Main green before and after. No BACKLOG/CHANGELOG edits by
  workers; no save-format changes (C-219's relabels are display text only; nothing stores place display names).
  - Fixed ([REVIEW] commit): GameData.plain_name's doc example still quoted the pre-C-219 "Cloud-Sea Cliff (2x qi)" label.
  - Checked: GUIDE-128's far_qi_offer reproduces the old far-clause rule exactly (same days_base, same same-region
    exclusion); the Travel line resolves through hinted_region (tested), and no UI/world code string-matches the old
    "Gather ..." prefix. GUIDE-126's pill pick excludes pills bigger than the qi left to the bottleneck and keeps the next
    realm pill's price plus 20 stones; WU-318's hinted_item matches its singular name inside the hint's plural. WU-319's
    note uses total density (matches C-219's labels). PERF-003's _hints_on reset is right (the fuzz instance is shared).
    C-217's encounters are non-lethal (sect_senior_tester has lethal false, spar true) and one-shot via their flags.
  - Notes, not filed: GUIDE-119's keep dict skips every copy of a needed item, not just the count the missions need
    (matches the spec). Guidance.sell_offer calls Sects.deliver_needs without world flags while the shop passes them, so
    a future deliver mission gated by requires_flag would make the hint total and the shop's sell-all differ (no mission
    uses requires_flag today). WU-324 found the WU-317 overlap is an NPC label vs a place label, which its guard does not
    cover (its own follow-up).
- 2026-10-23 (reviewer, 6th run): reviewed 3c8c769..e46c09d (GUIDE-129/130/131/132/133, WU-320/321/323/327, C-218/220/221/222,
  QA-148, QA-20261023-2; [PLAN]/[REVIEW] commits skipped). Main green before (ALL CHECKS PASSED). No BACKLOG/CHANGELOG
  edits by workers; no save-format changes. Nothing fixed or filed.
  - Checked: GUIDE-133 threads world flags through every sell_offer/deliver_needs caller (thin defence, armor, loot armor,
    sell hint), closing the gap noted last run; shop_screen.sell_wanted_line now takes flags instead of reading GameState.
    GUIDE-129's Sects.only_items_missing is the old deliver_needs condition verbatim, now shared with the inventory and
    shop "Wanted by the sect" lines. GUIDE-130 passes `today` to every gather_place_for/_deliver_clause caller (mission
    board uses GameClock.total_days). GUIDE-132 follows its spec: the claim line replaces "Save for", and both the qi-pill
    reserve and pill_gap_note drop while it shows; all three sects sell the same pill next_realm_pill picks, so the
    "As <rank> you could claim it" suffix names the right item. GUIDE-131/WU-320 cap qi at qi_to_bottleneck. QA-20261023-2's
    test changes keep the assertions meaningful (sure-win foe, meeting pushed out, count measured from after travel).
    C-218's captain is non-lethal and its odds test spans stages 4 and 6.
  - Notes, not filed: GUIDE-132 (per spec) also drops the stone reserve when the claim line shows with too little
    contribution ("you have N"), so the qi-pill hint may spend stones the player could have used on the pill.
    QA-148's follow-up is an owner balance question: contribution qi pills put 10/10 seeds past QR9 by month 12 (base
    2/10), so GUIDE-135 should not hint bulk contribution qi pills until F-005d is settled.
- 2026-10-23 (reviewer): reviewed e46c09d..ec4ffab (WU-325, WU-328, EFF-001, WU-326, PERF-004, C-224, GUIDE-137, QA-145,
  WU-309, WU-330, QA-149, C-227, C-225, C-228, WU-329; [PLAN]/[REVIEW] skipped). Main green before and after. No
  BACKLOG/CHANGELOG edits by workers; no save-format changes; no logic outside src/core.
  - EFF-001: `contribution` effect goes through Sects.add_contribution (month_earned, auto-promote), validated 1..500,
    documented in encounters.json _doc; rogues get nothing. GUIDE-137 resolves last run's GUIDE-132 note (reserve kept
    while the claim is short). WU-328/WU-330 reuse Guidance.sect_pill_claim/sect_pill_entry, no duplicated rules; the
    treasury opens focused on the pill button. WU-325 moves keep NPCs clear of place rects. C-228 foe is non-lethal.
  - Fixed: PERF-004's FirstHour.play_cached memo key lacked QA-145's new `far_qi` sim flag (a far-qi run could be
    served a cached normal run); added it and noted that every sim flag belongs in the key. Tightened GUIDE-137's test,
    which passed vacuously when an offer was empty: it now asserts the claimable case offers more than the short case keeps.
  - Nothing filed.
- 2026-10-23 (reviewer): reviewed ec4ffab..bda3229 (GUIDE-138/140/141/143/144/145, INJ-001, C-226/229/230, QA-147/150,
  WU-332/333/334/335, PERF-005; [PLAN] skipped). Main green. No worker touched BACKLOG/CHANGELOG.
  - GUIDE-143 (Qi Refining) and GUIDE-144 (thin-defence, Foundation) don't overlap (different realms). GUIDE-140 reuses
    Sects.deliver_needs. QA-150's qi_pill_cap and far_qi are in the play_cached key. PERF-005 lowers fuzz call floors
    to 10 for the two single-region profiles; acceptable since the region is asserted to exist.
  - Fixed: GUIDE-145's secret-realm hint required the full entry stones and entry item even after the player had
    entered this opening and lost the first guardian fight (re-entry is free then, SecretRealms.entry_cost /
    entry_item_needed), so the hint vanished exactly when the player was poorest. It now uses those helpers; test added.
  - Nothing filed.
- 2026-10-23 (reviewer): reviewed bda3229..19a5c27 (GUIDE-146/147, WU-331/336/337/340/341, QA-151/152, C-223/232;
  [PLAN]/[REVIEW] skipped). Main green before and after. No worker touched BACKLOG/CHANGELOG; no save-format changes;
  no logic outside src/core (WU-341's recharge_warning is a static display helper over CreationArtifact.recharge_cost).
  - GUIDE-147 follows its spec: the lives line now leads hints() and qi_pill_offer (the only "spare stones" spender)
    reserves the recharge price. WU-340 focuses the recharge button for gamepad. C-223's contribution is paid win or
    lose, per spec (effects resolve before the fight). GUIDE-146's outgrown_hint is bounded (4 foes/region, cached
    win_chance); its "hard home" test only asserts conditionally, which is weak but harmless.
  - Fixed: WU-340 and WU-341 inserted new functions between an existing `##` doc comment and its function
    (hud._refresh_lives, shop_screen.compare_text); moved the docs back and documented the new helpers.
  - Filed RV-015: C-232's newcomer hunt rates 0% for a fresh QR1 player with Iron Fist L1 (spec wanted >= 60%); only
    the typical player wins, so it joined QA032_BARE_DEADLY instead of being the safe first hunt it was meant to be.
  - Note: WU-336's empty claim commit (0c21046) landed on main; harmless, but rebase with --no-keep-empty drops it.
- 2026-10-23 (reviewer): reviewed 19a5c27..886d9a4 (GUIDE-148/149/150/152/153/157, RV-015, C-231, QA-153,
  WU-338/339/342/343; [PLAN] skipped). Main green before and after. No worker touched BACKLOG/CHANGELOG; no save-format
  changes; no logic outside src/core (GUIDE-149 only threads world_flags through GameState's injury_news calls).
  - GUIDE-148's fight_floor (0.5 / 0.7 lethal / 0.9 lethal at <= 1 life) is applied consistently to mission_too_dangerous,
    healed_wins and outgrown_hint. GUIDE-150's armor_hint_price mirrors armor_hint's branch order. RV-015 resolves last
    run's filing: den_wolf rates 65% for a bare QR1 newcomer, test added, removed from QA032_BARE_DEADLY.
  - Fixed: GUIDE-153's abode hint said "an anchor, though X here gathers qi faster" even for an abode without an
    anchor_id (all three abodes have one today, so latent); it now offers the storage instead, and the branch, which
    had no test, is covered (Azure Peak's cliff beats the waterfall cave). Re-indented C-231's new help.json line.
  - Notes, not filed: GUIDE-152's trial advice for a fighter with no combat technique at a realm's last stage ends
    at "A loss only injures you." with no lever; QA-153 suggests RATING_SAMPLES 200 (GUIDE-156 is already spec'd).
- 2026-10-23 (reviewer): reviewed 886d9a4..2950dde (QA-125, C-236/237, GUIDE-156/159/161, WU-347/348/349/350; [PLAN]
  skipped). Main green (ALL CHECKS PASSED). No worker touched BACKLOG/CHANGELOG; no save-format changes.
  - All five spec'd tasks match their specs. GUIDE-159 resolves last run's GUIDE-152 note (its test ran, not skipped).
    GUIDE-161 picks the cheapest claimable treasury heal via Sects.check_purchase, before the clinic; tests cover member,
    short contribution, rogue and held pill. C-236's audit test guards every mortal home fight with a max_realm.
    WU-348's method_note/is_faster_method compare via Techniques.method_rate_of (outgrown handled); GUIDE-156 adds an
    accuracy test against a 2000-sample estimate.
  - Notes, not filed: GUIDE-161 spends contribution on a heal without reserving for an unclaimed breakthrough pill
    (100 contribution, minor; no contribution reserve exists anywhere yet). WU-348's is_faster_method is a rule living in
    src/ui/mission_board.gd; fine as a display helper, but move it to Techniques if a system ever needs it. GUIDE-156
    makes the first-hour sim ~88% slower (worker's follow-up: cheaper win_chance).
  - Nothing fixed, nothing filed.
- 2026-10-23 (reviewer): reviewed 2950dde..f7ea31e (C-235/238/239/240/243, GUIDE-160/162/163/167, WU-346/351/353/354,
  QA-157; [PLAN]/[REVIEW] skipped). Main green (ALL CHECKS PASSED) before and after. No worker touched
  BACKLOG/CHANGELOG; no save-format changes; no logic outside src/core (WU-346/351/354 are display helpers).
  - GUIDE-167's duty_hint credits the mission's contribution before the month can roll over (take_mission completes,
    then passes time), so "covers it" with days <= days left is correct. GUIDE-162's typical_level matches
    combat_balance's 1 + 2/realm curve. GUIDE-163's "a, b and c" durations are tested. C-238's elk test pins 70-95%.
  - Fixed: C-240 committed a stray tests/unit/test_zz_scratch.gd.uid with no script (a worker's scratch test);
    removed it.
  - Note, not filed: WU-353's follow-up is real: the HUD's 120-char trial line cuts off before the practise advice,
    so GUIDE-162's level target only shows in the journal. Worth a guidance task (advice before the odds detail).
- 2026-10-24 (reviewer): reviewed f7ea31e..41ee758 (GUIDE-164/165/166/168/169/170, C-216/241/245, QA-156/158/159,
  WU-352/355/356/357/358/359/361; [PLAN]/[REVIEW] skipped). Main green (ALL CHECKS PASSED). No worker touched
  BACKLOG/CHANGELOG; no save-format changes; no new logic outside src/core (GUIDE-166 moves is_faster_method from
  MissionBoard into Techniques, resolving last run's note).
  - GUIDE-169 extracts _trial_lever from _trial_advice with the same branch order (injury and practice payoff still
    fall through to the old line), so the journal text is unchanged and the HUD line leads with the lever. GUIDE-170's
    rank gate reads ranks[min_rank].min_realm (ignores min_stage; fine, the clause is about unreachable realms).
    GUIDE-165 reserves the pill's cost before a treasury heal, resolving the GUIDE-161 note. GUIDE-168's clause needs a
    net saving of a year after the round trip; tests cover at-the-spot and too-young cases.
  - Notes, not filed: C-245 caps village_thief_caught at Qi Refining in cities too (it is tagged village+city); minor.
    C-245 leaves village_drunk_bully uncapped because outgrown_hint needs a home fight (worker's follow-up is right).
    C-241's line sits in the Goals help topic; there is no HUD page, acceptable.
  - Nothing fixed, nothing filed.
