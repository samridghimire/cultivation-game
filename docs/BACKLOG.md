# Backlog

Work queue for agents, owned by the **planner** (see docs/AGENTS.md). Workers pick the top `todo` task for their role and never edit this file.
Status: `todo` (add `spec` when a detailed spec exists) | `done` | `blocked` (needs a human answer, link the question). A task is claimed while a branch `claude/<id>-*` exists.
Roles: `systems` (core rules + tests), `content` (data/*.json + small hooks), `world-ui` (scenes, UI, UX), `qa` (tests, bugs, balance).
Tables are in priority order: take the first unclaimed `todo` row for your role whose dependencies are on main.
Long specs live in docs/specs/<id>.md. Tasks finished before 2026-10-07 are in docs/BACKLOG_DONE.md.
Many leftover `claude/*` branches from the old PR flow point at tasks already done; they are not claims on any open task.

## P0: Reviewer fixes
Filed by the reviewer (see docs/REVIEW.md). Take these before other work for your role.
| id | role | status | task |
|---|---|---|---|

## P0: Playable and fun (the first hours)
Next (audit 2026-10-08 16:20): the first hour still misleads (the first sect hint points a mortal at the demonic sect, the
technique hint at a manual they can't afford), has no clear first goal, and costly actions (leave sect, feed artifact, burn
lifespan) fire on one press. Then: say what numbers mean in messages, give fights some flavor and pace, and make loot sellable.
| id | role | status | task |
|---|---|---|---|
| FH-030 | systems | todo spec | Honest newcomer hints (sect hint for Mortals, Elder Mo teaches breathing for free) and a "First goals" journal section. [spec](specs/FH-030.md) |
| CULT-001 | systems | todo spec | Progress in cultivation messages and a days-to-next-stage helper. *Spec:* (1) `static func days_to_next_stage(c: CharacterData, data: GameData, density: float = 1.0) -> int` in src/core/systems/cultivation.gd (`##` doc): days of meditation at `density` until the next stage (or the realm's bottleneck if the next step is a breakthrough), -1 when already at the bottleneck or qi_per_day <= 0; compute from `qi_per_day` and the qi still needed (reuse what `days_to_bottleneck` does; no simulation loop). (2) `static func progress_text(c, data) -> String` -> "450/900 qi to the 2nd Layer" (or "ready to break through to Foundation Establishment" at the bottleneck; use `realm_label`-style names, never ids). (3) GameState.cultivate's result line (game_state.gd ~158, "You cultivate for 1 month and gather 150 qi.") gets " (<progress_text>)" appended; same for the seclusion/abode path if it posts its own line. (4) `GameState.days_to_next_stage(density: float) -> int` wrapper using the same density helper as `meditation_preview` (`_cultivation_density`). Tests in test_cultivation.gd: days match a hand calculation at two densities, -1 at the bottleneck, progress text at a stage and at the bottleneck, no `%`/`{`; test_game_session.gd: the meditation line contains "qi to". |
| MSG-001 | systems | todo spec | Say what numbers mean in messages (audit D). *Spec:* (1) `Karma.grudge_word(value: int) -> String` ("a slight" < 20, "a bitter grudge" < 60, "a blood feud" otherwise; put thresholds in data/karma.json with `_doc` + validation) and use it in game_state.gd ~508 ("Your old grudge (%d) ...") and wherever the karma ledger prints "Name (37)" (karma.gd ~356); the ledger must never fall back to a raw npc id (use "someone long gone"). (2) Hostile acts (game_state.gd ~1080, "Rob: Li Wei.") -> one sentence per act: "You rob Li Wei of N spirit stones." / "You humiliate Li Wei before onlookers." / "You kill Li Wei." (use the data the act already returns). (3) Favor gains (game_state.gd ~978/998/1019, "+N favor") append the next threshold: "(favor 25; 40 to court)" using the thresholds in data/family.json; at max just "(favor N)". (4) Alignment deltas (effects.gd ~77 "Alignment +15", game_state.gd ~1602/1616/2047): append the resulting tier name from Alignment (e.g. "Alignment +15, now Upright") and post "Your path has shifted: you are now <Tier>." once when the tier changes (one shared helper in GameState, not copy-paste). (5) "(%d left)" after a contribution purchase (game_state.gd ~1740) -> "(N contribution left)". Tests: each helper in its system's test file; one test_game_session.gd check per message kind that the posted line has the new wording and no `%`/`{`/raw ids. |
| STAT-002 | systems | todo | Track spirit stones earned and qi gathered (YEAR-001 Follow-up). Add `stones_earned` and `qi_gathered` to `LifeStats.KEYS`/`LABELS` (src/core/systems/life_stats.gd). Stones: add `LifeStats.record_stones(c, amount)` (positive only) and call it from the income paths: Professions work (~professions.gd:46), Commissions delivery (~commissions.gd:95), Items sell (~items.gd:161), sect stipends (~sects.gd:287), karma repayments (~karma.gd:119/197) and Effects item grants of `spirit_stone` (~effects.gd:86, covers deeds/encounters/dialogue). Not the starting stones, not loans/transfers between your own storage. Qi: GameState.cultivate and qi effects. `year_summary` gets a line "You earned N spirit stones." when > 0, and `LifeStats.epilogue` a "Spirit stones earned" line. Save-compatible (missing keys read 0). Tests: each source increments once (one test per path in its own test file or a new test_life_stats_income.gd), selling twice counts twice, buying doesn't count, year summary/epilogue lines. |
| CMB-002 | systems | todo | Techniques in the combat log, and a per-line hp trace for playback (WU-036). In `Combat.resolve` (combat.gd ~150): when the player strikes, name one of their combat techniques that has an `attack` bonus ("You strike with Iron Fist for 12."), rotating through them by round (`known[rounds % known.size()]`), **without drawing from `rng`** (draws would shift every fight and the balance baselines); none known -> current wording. Enemies with `techniques` in data/enemies.json likewise ("The Mist Wolf lunges with Moonlit Fang for 8."; plain "hits you" when none). Also add `"trace": Array` to the result: one `[player_hp, enemy_hp]` pair per `log` line (same length as `log`). Tests in test_combat.gd: technique names appear for a character who knows one, not for one who doesn't; trace length == log length and its last pair matches player_hp/enemy_hp; the same seed gives the same victory/rounds as before the change (compare against `resolve` with techniques removed from the names only, or assert `tools/balance.sh --check` unchanged in the commit message). |
| GUIDE-008 | systems | todo | New-feature notices (audit F31): body tempering, Dao contemplation, the spirit garden, the inner world and the rival are easy to miss. Add `Guidance.unlock_notices(c, data, flags) -> Array[Dictionary]` returning {id, text} for features that just became available and have not been announced (flag `notice_<id>`): body tempering available (BodyTempering can start a stage) -> "You are strong enough to temper your body at a meditation spot."; first Dao insight glimpsed -> "Contemplate your glimpsed insight at a meditation spot."; artifact function unsealable (spirit garden / inner world) -> "The Creation Artifact can unseal <function> (Artifact screen, O)."; rival assigned -> "<Rival> has named you a rival." GameState checks them after each action that advances time (where milestones are checked), posts each once (category "progress"), and sets the flag. Tests in test_guidance.gd per notice + once-only in test_game_session.gd. |
| WU-032 | world-ui | todo spec | Confirm before costly or irreversible actions: leave/join a sect, feed the artifact, burn-lifespan items, blood-bound equipment. [spec](specs/WU-032.md) |
| WU-033 | world-ui | todo spec | Item effects described in full, in core. *Spec:* move `InventoryScreen.describe_effects` (src/ui/inventory_screen.gd:94) into `Items.describe_effects(effects: Dictionary, data: GameData) -> PackedStringArray` in src/core/systems/items.gd (keep a thin forwarder or update both callers: inventory_screen.gd and shop_screen.gd ~257), and add the missing effect kinds Effects applies (effects.gd ~81-118): `learn_recipe` ("Teaches the recipe: <recipe name>"), `dao_insight` ("A glimpse of <Dao name>"), `attributes` ("+N Comprehension" etc., names from data/attributes.json), `buff` ("+X% attack for N days"), `bloodline`, `reputation` ("+N standing with <sect>"); never print ids. Tests in test_items.gd: every effect key used by any item in data/items.json produces at least one line (iterate the data, so new keys fail loudly), and no line contains `_` ids, `%` or `{`. |
| WU-034 | world-ui | todo | After CULT-001: "Meditate until the next layer (~N days)" option at meditation spots and abodes (above the 1-month entry), using `GameState.days_to_next_stage(density)`; hidden when -1 or > 365 days; label uses "next stage" for post-Qi-Refining realms; description = `GameState.meditation_preview(days, density)`. Uses the same time-skip overlay as the other meditation entries. Test: a fresh QR1 character at Meditation Rock gets the option, it advances the clock by the shown days (±1) and the stage goes up by one. |
| WU-035 | world-ui | todo | Inventory category tabs (audit C17): All / Pills / Herbs & Ores / Equipment / Talismans / Manuals & Scrolls / Other, from item `type`/tags in data/items.json (check what fields exist; add `Items.category(item: Dictionary) -> String` in core with a test). Tabs switch with the gamepad shoulder buttons (LB/RB actions in InputConfig if present, otherwise ui_left/ui_right on the tab bar), the selected tab is remembered while the game runs, and an empty tab shows "Nothing here." Shop Buy/Sell lists get the same filter only if it fits in ~60 lines; else note it under Follow-ups. Tests: category for one item of each kind; switching tabs filters the list; focus lands on the first item. |
| WU-036 | world-ui | todo | After CMB-002: combat playback. The combat report (src/ui/combat_report.gd) shows two hp bars (you / foe) and reveals log lines one at a time (~0.25 s each, faster setting-free), updating the bars from `result.trace`; accept/cancel or a "Skip" button shows everything at once; Continue is focused only after the reveal ends or is skipped. Respects a new Settings toggle "Animate fights" (default on, saved with settings; off = today's instant report). SFX hit sound per line if Audio has one (reuse; don't add assets). Tests: with animation on, after one tick fewer lines than the log are shown; skip shows all; with the setting off the report is complete at once; bars end at the result's hp. |
| WU-037 | world-ui | todo | Help on a key (audit C21): new InputConfig action `toggle_help` (keyboard F1 and H if H is free; gamepad: Back/Select if free, else none) opening the help screen the pause menu opens, through `hud._add_screen`; add it to the HUD key bar `KEY_HINTS` (hud.gd ~25) and the Controls page; remappable like the others (UI-003c). Tests: the action exists with a keyboard binding, no shared key/button (test_help_screen.gd's guard), pressing it opens help and closing returns focus. |
| WU-038 | world-ui | todo | Shop quantity: "Max" and ±10 steps on the Buy and Sell quantity stepper (src/ui/shop_screen.gd ~86-93, ~239-243); Max = what you can afford / what you hold / stock. Gamepad: LB/RB (or whatever the stepper uses) step by 10. Tests: Max on sell selects the held count; Max on buy is capped by stones; ±10 clamps to 1..max. |
| ECON-001b | content | todo | Sect missions out-earn everything (ECON-001 Follow-up: ~900k stones a life in tests/sim/simulate_economy.gd vs ~250-370k for profession work or gathering). After RV-009 lands: re-run the sim and lower the stone rewards of the missions that dominate (the sim can print income per mission id; add that if it doesn't) until missions are within ~1.5x of profession work, keeping ECON-002's guard (item missions pay >= 1.2x their hand-ins) and the newcomer missions' first-hour value (test_first_hour_economy). Paste before/after rows; commit the new balance baseline. |
| C-019 | content | todo spec | Qingshi Village first-hour fixes: Elder Mo's directions, fewer empty village days, no mortal forced bandit fight in the forest, the Wandering Merchant buys common loot; re-run the first-hour baseline. [spec](specs/C-019.md) |
| C-021 | content | todo | Winnable first secret realms and trials (audit B7, docs/balance_baseline.txt): Peach Blossom Grotto's forced iron_back_boar floor is 14% for a player entering Qi Refining, the Founder's Well trial (bandit_lord) 42%, and Verdant Remnant's rogue_cultivator / stone_ape floors 0%. These are the first adventures a newcomer sees. For each floor/trial: target >= 40% for the typical player at the realm's real gate (a floor's or trial's `min_stage` if the data supports one, else add it like ENC-002 did for encounters; if the system has no stage gate for floors, prefer a new weaker floor-1 guardian enemy over retuning a foe used elsewhere). Measure with tests/sim/simulate_combat.gd; paste before/after rows; commit the new tools/balance.sh baseline. |
| C-016 | content | todo | Forced fights still off the curve (C-015 Follow-ups, docs/balance_baseline.txt): the Blood Lotus Sect rank trial `blood_lotus_ancestor_puppet` is 31% at Core Formation entry (forced; target >= 40% at the trial's gate, keep <= 95% at the peak), and three secret realm guardians are 0% at their realm's `min_realm` (blood_lotus_elder on Fallen Star Vault floor 3, jade_python on Sunken Sword Tomb floor 3, cloud_devouring_condor on Skyfall Thunder Pavilion floor 3). Floors show their danger label before you delve, so a hard last floor is fine, but each must be beatable (>= 40% at entry) by a player at the secret realm's `max_realm`; check that with tests/sim/simulate_combat.gd and fix only what fails (prefer a new guardian enemy over retuning a foe used elsewhere). Paste before/after rows and commit the new tools/balance.sh baseline. |
| C-022 | content | todo | QR sect rank trials at 1-4% (balance baseline: azure_sword_examiner 1%, blood_pit_gladiator 4%, pavilion_vault_guard 1%). Check at which realm/stage each trial actually opens (`Sects.check_promotion`, data/sects.json rank requirements) and measure there with simulate_combat.gd; if the typical player at the rank's requirement is under 40%, retune the trial enemy (they are trial-only foes; grep to confirm) to 45-70% there. Paste before/after; commit the new baseline. |
| C-020 | content | todo | Help pages for systems that have none (audit C22; data/help.json has 0 mentions of taming, tempering, Dao, garden, inner world, bloodline, adoption): Spirit Beasts & taming, Body Tempering, Dao Insights, Creation Artifact functions (storage, appraisal, inner world, spirit garden), Clans & estates (founding requirements from data/family.json, buildings, heirs), Adoption & the orphanage. Same tone and length as the FH-022/C-013 pages, facts checked against the data files (numbers read from data, not invented). test_help_screen.gd stays green. |
| C-018 | content | todo | After NS-006: two Soul Formation people (NS-004 Follow-up) in data/npcs.json + dialogue files, like NS-004 (one righteous, one demonic), each with a favor reward and an errand for a Soul Formation herb that NS-006 makes gatherable; and Ye Zhuoran (NS-004) mentions the flawless Soul Infant pill (NS-002b) in one dialogue line. Errand turn-ins covered by test_npc_errand_turn_ins. |

## P1: Steam release basics
| id | role | status | task |
|---|---|---|---|
| REL-011 | qa | todo | Steam upload prep (REL-005 Follow-up): tools/steam/ with an app_build.vdf and depot_build vdfs for Windows and Linux depots that point at build/<platform>/ (app/depot ids as obvious placeholders, e.g. 0000000, read from env vars STEAM_APP_ID / STEAM_DEPOT_*), and tools/steam_upload.sh that runs tools/export.sh then `steamcmd +login "$STEAM_USER" +run_app_build ...`, refusing to run when the env vars are unset. No secrets in the repo. A docs/RELEASE.md page: what the owner must fill in (app id, depot ids, steamcmd login with Steam Guard) and the commands. Unit test: the vdf files parse as key/values and name both depots. |

## P2: After Core Formation (content runs out)
Late content keeps going in parallel. Pacing itself stays the owner's call (F-005d).
| id | role | status | task |
|---|---|---|---|
| NS-006 | content | todo | Soul Formation content pack, like NS-001 (docs/specs/NS-001.md, same method and sim table in the commit): 6 enemies at soul_formation stages 0-3 (beast, righteous non-lethal, demonic, construct mix) and 10 encounters at min_realm soul_formation (6 fights, 3 alignment choice encounters with blocked_by_flag, 1 fortune), using Myriad Peaks Ridge's tags. Tune with simulate_combat.gd to the same curve as NS-001. Check whether `realm_training` covers the soul_formation index (QA-021 extends it) and say so in the commit. |
| NS-007 | content | todo | Realm-appropriate fights for NS-005's three Soul Formation inheritance grounds: the combat baseline rates their trial foes (ancient_puppet_guardian, azure_law_enforcer, soul_reaping_old_monster) TRIVIAL (100% at entry). After NS-006 lands, point their fight stages at NS-006's soul_formation enemies (or add three guardian enemies at soul_formation stage 0-1, `lethal: false`) and check with the combat sim that a Soul Formation veteran wins 50-90%. Depends on NS-006. |

## P4: QA and tooling
| id | role | status | task |
|---|---|---|---|
| QA-021 | qa | todo spec | Realm gap past Core. *Spec:* QA-018 found a veteran at the Nascent Soul / Soul Formation peak beats a plain next-realm foe 20-28% (target: near 0%, owner decision QA-007), because data/enemies.json `realm_training` has entries only up to realm index 4 and the last one is reused. Add entries for realm indices 5..9 continuing the curve (each step roughly +3 attack/defense, +12 max_hp over the previous, or whatever keeps the per-realm same-stage win rate 60-100% for the veteran in tests/sim/simulate_combat.gd), re-run the sim, then tighten the guard in tests/unit/test_combat_balance.gd to "< 10% one realm up" for every realm through Soul Formation. Re-check that NS-001's Nascent Soul foes keep their table (paste it) since they use realm_training index 4. Paste before/after veteran tables and commit the new balance baseline. Also, if simple, exclude manuals with no obtainable source (`Items.sources`) from `veteran_player()`. |
| QA-029 | qa | todo spec | A "curious player" first-hour sim. tests/sim/first_hour.gd cultivates a month and explores once per month, so the baseline reports 3.7 log lines a month and 0-3 fights a year, which says nothing about how the first hours feel. Add a second policy (flag `--curious`, same seeds) that each month also explores weekly (`explore_many`), does one chore/deed it qualifies for, takes an enabled sect mission if in a sect, talks to the nearest named NPC once, and delivers commissions/errands it can. Print the same summary plus "distinct things done" (action kinds) per month. Add it to tools/balance.sh (commit the baseline) and a loose guard in test_first_hour_economy or a new test: the curious player is never killed for good, has no month with zero log lines after month 1, and reaches QR3 by month 12 in >= 7/10 seeds (adjust to what it measures and say so). Report anything surprising (stuck states, odd text) in the commit under Follow-ups. |
| QA-020 | qa | todo | Gamepad-only pass on screens added since QA-008/QA-013 (family tree, auction, inner world/garden in the artifact screen, control remapping, respawn, tribulation, threat prompt, credits, sect balance window, journal, save toast must not take focus): extend test_focus_audit.gd and test_steam_deck_layout.gd to cover each, fix what fails. |
| QA-032 | qa | todo | Reconcile the newcomer guard with the sim's typical player (C-015 Follow-up): test_first_hour_economy's FH-024 guard (rank-0 missions must be Even/Weak for a weak test character) is so much weaker than simulate_combat.gd's typical player that cull_mist_wolves, patrol_misty_peaks and the sect-call missions stay TRIVIAL (100%). Measure both characters' win odds on every rank-0/1 mission, then either make the guard character match the typical player at that mission's gate or relax the guard to Weak/Even/Dangerous at the mission's min_stage; whichever you pick, the sect-call and wolf missions must land in 60-95% for the typical player (retune their enemy or add a min_stage in data/sects.json). Paste before/after. |
| QA-033 | qa | todo | Fuzz the states QA-030 couldn't reach (QA-030 Follow-up): a profile spawned while a secret realm's window is open (pick a realm the profile qualifies for; set the clock into its window) and one with a sect promotion trial available (contribution and realm met). Same checks as the other fuzz passes. Fix what fails or list it under Follow-ups. |
| QA-034 | qa | todo | Hint honesty audit (after FH-030): for fresh characters (both genders, 5 root rolls via seeded_rng) and for a QR3 rogue and a QR3 sect disciple, every line `Guidance.hints` returns must be actionable: a hint naming a merchant item -> the player can afford one; naming a sect -> `Sects.check_join` passes or the hint says what is missing; naming a person/place -> it exists in data/npcs.json or data/regions.json; naming a key -> InputConfig has it. Implement as tests/unit/test_hint_honesty.gd; fix small lies in guidance.gd, list bigger ones under Follow-ups. |

## Blocked (waiting on the owner, see DESIGN.md "Open design questions")
| id | role | status | task |
|---|---|---|---|
| F-005d | qa | blocked | Progression is far too fast (F-005c sim, seed 1, 200 lives): a sensible player (best reachable spot, Azure Cloud Sect) reaches Foundation at ~17, Core Formation at ~20, Nascent Soul at ~28, Void Refinement at ~92 and Tribulation Transcendence at ~800, with zero old-age deaths; Heavenly Roots hit Void Refinement at ~38. Even the bare density-1.0 sim reaches Core Formation at 40. Breakthrough pills never matter (no one can afford one before Foundation). Needs the target pacing from the owner (DESIGN.md open question), then rescale realms.json qi_required/base_qi_per_day and re-run `simulate_life.gd -- 200 1.0 1 real`. |
| C-009b | content | blocked | (LW-002b also found Qi Refining 3rd-5th layer players have low win odds in general.) Soften the first realm's fights so a newcomer with a starter technique wins ~50% against a 1st-layer beast (enemies.json `realm_training[1]` for stages 0-2, a starter beast between the bandit and the Mist Wolf, grade-1 gear at the Qingshi merchant). Blocked on the DESIGN.md question "(C-009) The first fights". |
| END-001 | systems | blocked | An ending: at Tribulation Transcendence Peak a final Ascension tribulation, then an epilogue screen summing up the life (age, realm, alignment, deeds, clan, descendants). Blocked on the DESIGN.md question "(END-001) Ascension". |
| REL-006 | systems | blocked | Legacy after final death: offer "Continue as your heir" (Clans heir / designate_heir, game_state.gd ~1186) besides "Return to Main Menu". Blocked on the DESIGN.md question "Permadeath, or reincarnation / legacy system on death?". |
| SECT-001 | systems | blocked | Founding your own sect (roadmap item 3). Blocked on the DESIGN.md question "Founding your own sect". Default if approved: unlocks at Nascent Soul, needs a mountain-gate place, and reuses the clan treasury/buildings model (FAM-005/FAM-006) with disciples recruited from generated NPCs. |
| STORY-001 | content | blocked | Main story act 1 around the Creation Artifact (who made it, who hunts it). Blocked on the DESIGN.md question "Main story / Creation Artifact origin". Until answered, ART-006 keeps the origin vague. |
| DEM-002 | systems | blocked | Separate demonic progression tree (blood refining, soul devouring, corpse puppets) parallel to methods. Blocked on DESIGN.md question "Should evil paths include demonic cultivation techniques as a separate progression tree?". Default if approved: demonic methods via CM-001 + DEM-001 devouring, then a tree of unlockable demonic arts paid with "blood essence" gained from devouring. |
| ART-007 | systems | blocked | Artifact recharge cost curve: cost_growth 2.0 compounds over the whole life (life 10 costs 51,200, life 13 costs 409,600), so long-lived cultivators always run out (QA-006). Waiting on the DESIGN.md question "(QA-006) Artifact recharge cost"; default proposal: base_cost scales with realm and cost_growth applies only to lives bought within the current major realm. |

## Done
Tasks finished since the 2026-10-07 archive. The planner moves rows here from `[ID]` commits on main.
| id | role | task |
|---|---|---|
| RV-009 | content | Gather rolls find something >= 54% again; income cut through rarer valuable finds and single-unit yields. |
| QA-028 | qa | Journal coverage with a busy sect disciple; no bugs found. |
| WU-029 | world-ui | Meditation/abode menu descriptions (preview, breakthrough odds, pill hint). |
| WU-028 | world-ui | HUD panels hide behind modals; character sheet button row. |
| WU-030 | world-ui | Explore outlook descriptions; current region foes on the world map. |
| WU-031 | world-ui | Yearly recap banner card and Settings toggle. |
| QA-030 | qa | Interactable fuzz pass with a mid-game family head; placeholder check on all passes. |
| GUIDE-007 | systems | "Try something new" hint (explore, craft a known recipe, open secret realm). |
| YEAR-001 | systems | `LifeStats.year_summary`, year snapshot on CharacterData, `EventBus.year_reviewed`. |
| WU-027 | world-ui | ChoiceMenu description/reason line; reasons moved out of labels. |
| WU-024 | world-ui | Loss advice in the combat report; help page line. |
| C-017 | content | Seven first-hour village/forest choice encounters. |
| EXP-001 | systems | `Exploration.outlook`, `Guidance.outlook_text`, `GameState.explore_outlook`. |
| MED-001 | systems | `Cultivation.preview`, `Guidance.meditation_preview`, `GameState.meditation_preview`. |
| BT-001 | systems | `Cultivation.chance_breakdown`, `Guidance.chance_text` / `pill_source_hint`, tip after a failed breakthrough. |
| CMB-001 | systems | `Combat.loss_advice` posted after a lost fight. |
| QA-031 | qa | 50-year save round-trip soak sim; world events and the eligible-NPC pool are stable across save/load. |
| WU-021 | world-ui | tests/sim/screenshot_screens.gd (21 screens); opaque modal panels. |
| C-015 | content | Fair forced fights where they appear (rogue/stone-ape missions, enforcer, blood merchant vault). |
| WU-026 | world-ui | UI Scale fit test at 115%; shop names clipped. |
| GUIDE-005 | systems | Outgrown cultivation method warning (hint + journal). |
| MS-004 | systems | `LifeStats.backfill` for veterans' secret realm / inheritance milestones. |
| GUIDE-004 | systems | Journal Household section; joinable events in other regions. |
| WU-025 | world-ui | Recap lines on the arrival card after a load. |
| WU-023 | world-ui | NPC name labels keep clear of places. |
| NS-002b | content | Flawless Soul Infant / Spirit Severing pills; Soul Formation recipe in the Chaos Alchemist reward. |
| NS-004 | content | Patriarch Lin, Old Monster Gui and Ye Zhuoran with favor rewards and errands. |
| WU-022 | world-ui | ChoiceMenu description line shows disabled options' reasons; disabled options focusable. |
| RECAP-001 | systems | `Guidance.recap` posted on load. |
| GUIDE-006 | systems | Hint toward a reachable meditation spot >= 1.5x better. |
| RV-006 | qa | Tournament/newcomer tests that can fail; tournament bouts scale by round; economy sim skips unavailable missions. |
| RV-005b | systems | `CharacterData.breakthrough_pill`: a herb's bonus no longer blocks the realm pill. |
| SF-002 | systems | `SectFactions.expire_calls`; "calls on its disciples again" for cooldowns. |
| WU-018 | world-ui | `Commissions.short_label`; shortfall moved to the option's reason. |
| WU-019 | world-ui | The sect's call first on the mission board with days left (`SectFactions.call_days_left`). |
| QA-027 | qa | Combat sim rates secret realm, inheritance, world event and sect trial fights; every enemy appears. |
| WU-020 | world-ui | Family screen on F / right trigger. |
| WU-017 | world-ui | Places moved out from behind the HUD panels in all six regions. |
| ENC-002 | systems | Encounter `min_stage`; the combat sim rates fights at their real gate. |
| MS-003 | systems | Four milestones for skipped features; `flag_count` check type; new LifeStats keys. |
| C-013 | content | Six help pages (commissions, favors, world events, sect's call, journal, appraisal). |
| GUIDE-003 | systems | Journal Opportunities and Errands; `errands` list in data/npcs.json. |
| PROF-002 | systems | Commission delivery hint and 7-day lapse warning. |
| C-014 | content | Qi Refining cliff encounters gated by `min_stage` (each >= 40% at its gate). |
| WU-015 | world-ui | Journal on the left trigger; LT/RT on the pad key bar. |
| WU-016 | world-ui | Character sheet Adventures section. |
| REL-005 | qa | Windows/Linux export presets and tools/export.sh. |
| QA-007f | content | Superseded by C-015 (Foundation/Core encounters are no longer 100% on entry since QA-007g/ENC-002). |
| QA-007g | content | Purge-the-demonic-cultivator mission gated at Foundation stage 1; named foes re-checked on the curve. |
| ECON-001 | content | Gathering income cut so profession work is within 0.5-1.6x of gathering (miss rates fixed by RV-009). |
| WU-013 | world-ui | Deliver entries for commissions in the workshop menu; help line. |
| QA-026 | qa | Milestone emit-once, bounded progress and clean journal text tests. |
| WU-010 | world-ui | Music crossfade on mood change. |
| NS-005 | content | Three late methods (to Mahayana / Tribulation Transcendence) from Soul Formation inheritance grounds. |
| C-011 | content | Five favor errands for named NPCs. |
| WU-014 | world-ui | HUD hint count setting (0-3). |
| WE-001 | systems | Tournament / incursion life stats and two milestones. |
| WU-011 | world-ui | World map marks joinable events in the current region. |
| QA-024 | qa | tools/balance.sh and docs/balance_baseline.txt. |
| ART-008 | systems | Appraisal shows win odds on danger labels. |
| WU-012 | world-ui | Rival line on the character sheet. |
| QA-025 | qa | Combat sim "on appearance" column; forced Nascent Soul fights >= 15% for the veteran. |
| RV-004 | world-ui | Journal tone colors, peak-realm line, pill/sect lines, duty dedupe. |
| LW-002c | systems | Sect's call lapses after 30 days; juniors told it's for seniors. |
| PROF-001 | systems | Crafting commissions (core, journal section, saved). |
| RV-005 | systems | Breakthrough pills tied to their realm, one per attempt. |
| C-012 | content | Workshops in three more regions; beast tide defence fight. |
| RV-007 | content | NS-003 text mismatches fixed; thunder_patriarch_puppet enemy. |
| RV-001 | systems | Save data-loss edges: newer saves kept, copied backups, presence cleared. |
| RV-008 | planner | Hourly cleanup-claims workflow added; cleanup script only deletes stale claim branches; `--force-rebase` documented. |
| RV-003 | world-ui | Credits scroll with the gamepad and list third-party license notices. |
| RV-002 | world-ui | Banner queue: milestone banners no longer hide "Breakthrough!". |
| QA-022 | qa | First-hour sim prints fights won/lost/fled; tighter log-volume and first-year-losses guards. |
| MS-002 | systems | Milestone progress ("Battle-Hardened (4/25)") on the sheet and in the journal. |
| LW-002b | systems | Righteous and demonic sects clash monthly; the player's sect posts a call mission. |
| REL-008 | world-ui | Procedural ambient music per mood on a Music bus. |
| ECON-002 | content | Sect item missions pay at least 1.2x their hand-in items (14 missions raised, guard test). |
| WU-005 | world-ui | HUD "(you can enter)" for joinable world events; rival danger on explore-site event entries. |
| WU-008 | world-ui | Title screen painted backdrop (ink-wash ridges, mist, moon). |
| REL-010 | systems | Autosave on suspend / focus loss, rate-limited. |
| EPI-001 | systems | `LifeStats.epilogue` lines for the final-death screen. |
| QA-023 | qa | Saves from a newer build refused; bad-file robustness tests. |
| WU-006 | world-ui | Milestones section on the character sheet and a milestone banner. |
| SECT-003 | systems | Sect duty reminders in the last 7 days of the month. |
| GUIDE-001 | systems | `Guidance.journal` sectioned "what can I do now?" entries. |
| WU-009 | world-ui | No arrival card while the respawn screen is up. |
| NS-003 | content | Myriad Peaks Ridge, a sixth region for Core Formation+. |
| FH-026 | content | Rank-1 rogue and stone ape missions gated to Foundation Establishment. |
| WU-004 | world-ui | Life record and epilogue on the final-death screen. |
| WU-007 | world-ui | Journal screen (J / pause menu). |
| QA-006b | qa | Economy sim with crafting, gathering, missions, gear and clinics; Core Forming Pill affordable at the Foundation peak in ~2/3 of lives. |
| FH-024 | content | Newcomer-safe sect missions: rank-0 Mist Wolf and rogue missions gated to Even/Weak, with a guard test. |
| FH-025 | systems | Explore for a week: `explore_many` stops when something happens; quiet days summed in one line. |
| WU-001 | world-ui | Save feedback toast (Saved / Autosaved). |
| STAT-001 | systems | Life record (`LifeStats` on CharacterData) on the character sheet. |
| WU-002 | world-ui | Sect hall "Balance of power" window and the sect rank line on the sheet. |
| QA-019 | qa | Newcomer path test from Elder Mo to the first mission; no bugs found. |
| REL-007 | systems | Atomic saves with a .bak fallback; damaged slots listed. |
| WU-003 | world-ui | Arrival card with qi density and danger on travel. |
| NS-001 | content | Nascent Soul pack part 1: 8 enemies, 15 encounters. |
| NS-002 | content | Soul Infant and Spirit Severing pills, recipes, herbs and scroll sources. |
| GOAL-001 | systems | Milestones (16 in data/milestones.json), saved and posted. |
| REL-009 | systems | Platform autoload: Steam achievements/rich presence stubs wired to milestones. |
| LW-003b | systems | Tournament bouts carry hp from bout to bout. |
| LW-003 | systems | Joinable world events: sect tournament bracket and demonic incursion defence. |
| FH-003 | systems | Deed cooldowns (`cooldown_days`, `once`, CharacterData.deed_days). |
| FH-004b | world-ui | Threat prompt: slip away or fight a sensed Dangerous foe. |
| FH-015 | world-ui | Companion Release button; no "0 rounds" in combat summaries. |
| FH-020 | content | Qingshi economy: Village Herb Slope, Village Herb Seller, a newcomer mission per sect. |
| FH-005 | systems | Far-off world event news dropped from the log (Exploration.is_nearby). |
| FH-006 | systems | Unique generated NPC names. |
| FH-012 | world-ui | Key hints built from InputConfig bindings, keyboard/gamepad aware. |
| FH-013 | world-ui | Character creation shows talent vs average; Reroll focuses Begin. |
| REL-001 | systems | Autosave slot (travel, breakthrough, monthly, window close) with a setting. |
| QA-016 | qa | First-hour guard sim and tests. |
| REL-002 | systems | Final death stays final (fallen slots can't be loaded). |
| FH-014 | world-ui | Crafting screen lists where missing ingredients come from (Items.sources). |
| FH-021 | content | Newcomer fight fixes, damaged_meridians gated, one-time story encounters. |
| FH-022 | content | Ten help pages for the first hours. |
| LW-002 | systems | NPC sects as living factions, part 1 (strength + recruitment). |
| REL-004 | world-ui | Procedural SFX autoload with SFX/Master buses. |
| REL-003 | world-ui | Credits screen with the Godot license. |
| QA-018 | qa | Veteran loadout per realm in the combat sim; late-realm guards. |
| FH-002 | systems | Seclusion and meditation stop at a bottleneck instead of wasting the rest of the span. |
| QA-017 | qa | Exploit audit test for deeds and repeatable choice encounters (known offenders listed until FH-003). |
| FH-011 | world-ui | New games start beside Meditation Rock and the wake text points to Elder Mo. |
| FH-010 | world-ui | Menu clarity: sect join reasons, Court/Propose hidden at low favor, anchor bind/release guards, "to the death" fight labels. |
| FH-004 | systems | Dangerous lethal foes are sensed and offered (pending_threat, threat_sensed, face_threat). |
| FH-001 | systems | Newcomer hints first (Elder Mo, qi pills, chores, techniques, sects); HUD shows two hints. |
| C-005b | content | Withered Bone Marsh follow-ups: three marsh foes with realm-gated encounters, a marsh_captive deed context (free/sell/ransom) and Peddler Hei with dialogue. |
