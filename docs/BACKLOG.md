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
| RV-009 | content | todo spec | ECON-001 made gathering trips mostly empty instead of less lucrative. It raised the "nothing" weight so that (counting min_realm-locked entries, which turn into "nothing") a roll misses 73-96% of the time at the higher places and lengthened their gather_days to 15-20; with GATHER_ROLLS = 3 a pre-Core player now comes back from a 20-day Thunder-Struck Terraces trip with nothing ~88% of the time (Cloud-Sea Orchid Terraces ~68%, Frost Ledge ~57%, Crystal Vein ~53%). *Spec:* (1) `git show ad67cb0 -- data/regions.json` and restore the pre-ECON-001 `""` weights and gather_days. (2) Take the income cut instead through lower `value` of the herbs/ores those tables yield in data/items.json (merchant buy-back is derived from value; check `Items.sell_price`) and/or smaller min/max per find. Don't lower the value of anything a recipe's `material_value` or a shop price for the first hour depends on without re-running test_first_hour_economy. (3) Keep ECON-001's target: in tests/sim/simulate_economy.gd profession work within ~1.5x of gathering for every profession. (4) New test in tests/unit/test_gathering.gd (or the nearest gather test): for every gather place in data/regions.json and the lowest realm at which at least one of its entries is unlocked, a single roll's chance of finding something (`Exploration.gather_table_for` weights) is >= 0.5. (5) test_first_hour_economy / test_obtainability green; re-run `tools/balance.sh` and commit the new baseline. Paste before/after sim rows. |

## P0: Playable and fun (the first hours)
Next: fights that are fair where they appear (no 0% forced fights, no 100% chores), tell the player *why* they lost and
where to go next, gamepad players can read every disabled option's reason, and a look at every screen at 1280x800.
| id | role | status | task |
|---|---|---|---|
| C-015 | content | todo spec | Fair fights where they appear (follow-ups of C-014, ENC-002, QA-027; supersedes QA-007f, whose 100% rows are gone). [spec](specs/C-015.md) |
| MS-004 | systems | todo spec | Veterans' MS-003 milestones count their past (reviewer note): `realm_floors_cleared` and `inheritances_claimed` only count from MS-003 on. *Spec:* add `static func backfill(c: CharacterData, data: GameData, flags: Dictionary) -> void` to src/core/systems/life_stats.gd (`##` doc): sets `realm_floors_cleared` to max(current, sum of `int(entry["floor"])` over `c.secret_realms` values) and `inheritances_claimed` to max(current, the number of ids in `c.inheritances` that are secret realm ids in `data.secret_realms`, plus the inheritance grounds in `data.inheritances` the player claimed). Read inheritances.gd ~120-140 to see how a ground claim by the player is recorded (it calls `LifeStats.add(c, "inheritances_claimed")` there; if the claim is stored on `c.inheritances` too, don't double count: count unique ids). Never lowers a value; idempotent. Call it in `GameState.load_save_dict` (game_state.gd ~2266) just before `Milestones.award(...)`, so the milestones are awarded silently on load. Tests (test_life_stats.gd or the nearest): a character with `secret_realms = {"verdant_remnant": {"opening": 0, "floor": 2}}` and one inherited realm id backfills to 2 / 1; calling it twice changes nothing; a higher existing count is kept; a GameState load of such a save awards "Into the Secret Realm" without posting a message (see how test_milestones checks silent awards). |
| GUIDE-005 | systems | todo spec | Tell the player when their cultivation method is holding them back. Today `Techniques.is_outgrown` silently drops qi gathering to `method_over_cap_rate` and nothing says so. *Spec:* (1) New `static func _method_hint(c, data) -> String` in src/core/systems/guidance.gd: if `Techniques.is_outgrown(c, data, Techniques.main_method(c, data))`: "Your <method> teaches nothing past <cap realm>: qi gathering has fallen to x<rate>. Switch to a better method (techniques screen)" plus, if a known method is not outgrown and has a higher `method_rate_of`, " - you know the <name>." else, if some method manual in data/items.json teaches a method whose max_realm is beyond the player's realm (or has none) and `Items.sources(data, item_id)` is non-empty, " Look for the <manual name> (<first source>)." (2) Also when the method is not yet outgrown but the next breakthrough would outgrow it (`c.realm_index + 1 > realm_index_of(max_realm)`) and the player is at the bottleneck: "Your <method> stops at <cap realm>; find a new one before you break through." (3) Put it in `hints()` right after the cultivation hint (it is urgent: count it in the journal's `urgent` like injuries so it shows as a warning). Check how manuals reference methods (grep `teaches` or `technique` in items.json and Items). Tests in test_guidance.gd: an outgrown starter-method character gets the hint naming the cap realm and rate; with a known better method it names that method; a fresh character gets none; no `%`/`{` in the line. |
| CMB-001 | systems | todo spec | Say why a fight was lost. New players lose forced fights and get only "You are defeated by X". *Spec:* new `static func loss_advice(c: CharacterData, data: GameData, enemy: Dictionary, result: Dictionary) -> String` in src/core/systems/combat.gd (`##` doc), "" on a victory/draw/escape. Compare `stats(c, data)` with `enemy_stats(enemy, data)` and pick the biggest gap, one sentence each: realm gap (enemy realm index > player's, or same realm and enemy stage >= player stage + 3) -> "<Foe> is far above you; grow stronger before facing it again."; enemy damage per hit (`base_damage(e.attack, p.defense)`) >= 25% of your max hp -> "<Foe> hits too hard for your defense: armor or a defense technique (Stone Skin) would help."; your damage per hit < 10% of its max hp -> "You barely scratch <foe>: a better weapon or training your attack technique would help."; else "<Foe> was the stronger fighter today; practice your techniques and come back." Append " Readied talismans can turn a fight." when the player owns a combat talisman item that is not readied (CombatTalismans). Post it as a second line after a lost fight wherever the fight result is logged in GameState (grep `Combat.resolve(` in game_state.gd; one shared helper, not copy-paste), category "combat" or whatever the defeat line uses. Tests in test_combat.gd: each branch with a hand-built enemy dict; "" on victory; one GameState integration test where a forced fight is lost and the advice line is in EventBus history. |
| WU-021 | world-ui | todo spec | Look at every screen at 1280x800 the way WU-017 looked at regions. [spec](specs/WU-021.md) |
| WU-022 | world-ui | todo spec | Gamepad players can read disabled options' reasons. ChoiceMenu (src/ui/choice_menu.gd ~50-75) puts `option["reason"]` in `tooltip_text`, which a gamepad never shows, and `_focus_first` skips disabled buttons. *Spec:* (1) Add a description `Label` under the button list (UIStyle.label, size 14, dim color, autowrap, fixed height of two lines so the menu doesn't jump) that shows the focused button's reason when it has one, else empty. Connect each button's `focus_entered` and `mouse_entered` to update it. (2) Make disabled buttons focusable (`focus_mode = FOCUS_ALL`) so the d-pad can land on them and read why; `_focus_first` keeps preferring the first enabled one. Pressing a disabled button must do nothing (check that `pressed` isn't emitted; add a guard in `_choose` if `option.get("disabled")`). (3) Where an option's label has the reason appended in brackets (secret_realm_entrance.gd ~65 `label += " [%s]"`, inheritance_grounds.gd ~39), keep the label as is (short labels are fine) but also pass `"reason"`. Tests (test_focus_audit.gd style): open a ChoiceMenu with one enabled and one disabled option with a reason; focus the disabled one -> the description label shows the reason; pressing ui_accept on it doesn't call the action; the menu still fits test_steam_deck_layout. |
| WU-023 | world-ui | todo spec | NPC name labels overlap place labels (WU-017 Follow-up). `Npcs.spot_positions` (npcs.gd ~337) puts NPCs beyond the region's `npc_spots` on a ring around the player's start, which can land on places. *Spec:* add an `avoid: Array[Vector2] = []` parameter: ring positions closer than 90 px to any avoid point (or to an already chosen spot) are skipped and the next angle/radius tried (cap the search, e.g. 64 candidates, then accept). world.gd (~203) passes every place `pos` of the region (and the Family Home pos). Also check the six regions' `npc_spots` in data/regions.json against place positions with the same 90 px rule and move offenders. Re-run the region screenshot tool (docs/HANDOFF.md Tools) and say what you looked at. Tests in test_npcs.gd: with avoid points on the ring, no returned spot is within 90 px of one; count is always honored; old call sites without `avoid` behave as before. Extend the layout test (grep test_place_overlap) with the npc_spots rule. |
| GUIDE-006 | systems | todo | Point the player at better qi. Cultivation speed depends heavily on where you meditate, and nothing tells you a better spot exists. In guidance.gd add a hint: when the best `qi_density` among meditation spots / abodes the player can use in regions they can travel to (respect any min_realm or sect gating; check Exploration/Abodes for the density lookup and how travel is gated) is >= 1.5x the density where they are now, "Meditation at <place> in <region> gathers qi x<ratio> faster than here." Show it at most when not at a bottleneck and after the newcomer hints. Tests: a character in Qingshi gets the hint naming the best spot; standing at the best spot gives none. |
| RECAP-001 | systems | todo | "Where you left off" on load. Players coming back to a save see an empty log. Add `Guidance.recap(c, data, flags, today, region_id, ...) -> PackedStringArray` (2-3 lines: "<name>, <realm label>, age N, in <region>." + the first journal "Next steps" line + the first warning-tone journal line if different) and post them in `GameState.load_save_dict` after `EventBus.clear_history()` as category info. Tests: a loaded save has the recap as the first log lines; no `%`/`{`. |
| GUIDE-004 | systems | todo | Journal "Household" section and events elsewhere: (1) children of training age who can be taught or trained now (Training / Children checks), spirit garden plots ready to harvest (SpiritGarden), a companion beast that can be fed or has outgrown you (Beasts), a pregnancy's days left; (2) joinable world events in *other* regions ("Sect Tournament in Azure Peak: you can enter, N days left"), dim when the check fails; the current-region lines stay as they are. Core only (Guidance.journal), the journal screen shows new sections automatically; check it. Tests: each line appears with the state set up and not without. |
| WU-024 | world-ui | todo | After CMB-001: the combat report (src/ui/combat_report.gd) shows the loss advice line under the result in the warning color, and the newcomer help page on fighting (data/help.json) mentions it. Test: a lost fight's report contains the advice. |
| WU-025 | world-ui | todo | After RECAP-001: show the recap lines in the arrival card (WU-003) when a save is loaded, so returning players see them; not over the respawn or death screens (see WU-009). Test: loading a save shows the card with the recap. |
| WU-026 | world-ui | todo | UI scale setting for the Steam Deck and big screens: Settings gets "Text size" (100% / 115% / 130%) applied through the root window's `content_scale_factor` (or the theme's default font size if that breaks layout; say which), saved with the other settings. test_steam_deck_layout must pass at 100%; add a test that the setting round-trips and every HUD screen still fits 1280x800 at 115% (fix what doesn't, or cap the option at what fits and say so). |
| ECON-001b | content | todo | Sect missions out-earn everything (ECON-001 Follow-up: ~900k stones a life in tests/sim/simulate_economy.gd vs ~250-370k for profession work or gathering). After RV-009 lands: re-run the sim and lower the stone rewards of the missions that dominate (the sim can print income per mission id; add that if it doesn't) until missions are within ~1.5x of profession work, keeping ECON-002's guard (item missions pay >= 1.2x their hand-ins) and the newcomer missions' first-hour value (test_first_hour_economy). Paste before/after rows; commit the new balance baseline. |

## P1: Steam release basics
| id | role | status | task |
|---|---|---|---|
| REL-011 | qa | todo | Steam upload prep (REL-005 Follow-up): tools/steam/ with an app_build.vdf and depot_build vdfs for Windows and Linux depots that point at build/<platform>/ (app/depot ids as obvious placeholders, e.g. 0000000, read from env vars STEAM_APP_ID / STEAM_DEPOT_*), and tools/steam_upload.sh that runs tools/export.sh then `steamcmd +login "$STEAM_USER" +run_app_build ...`, refusing to run when the env vars are unset. No secrets in the repo. A docs/RELEASE.md page: what the owner must fill in (app id, depot ids, steamcmd login with Steam Guard) and the commands. Unit test: the vdf files parse as key/values and name both depots. |

## P2: After Core Formation (content runs out)
Late content keeps going in parallel. Pacing itself stays the owner's call (F-005d).
| id | role | status | task |
|---|---|---|---|
| NS-004 | content | todo | Late-game people: 3 named NPCs at Nascent Soul+ in data/npcs.json with dialogue files (a righteous sect patriarch, a demonic old monster, a wandering neutral alchemist) with favor-gated rewards (a late method manual, a pill recipe, word of a secret realm) and righteous/neutral/demonic branches, placed in Myriad Peaks Ridge (NS-003) or Azure Peak / the marsh. Give each a favor errand in C-011's shape and add it to data/npcs.json `errands` so GUIDE-003's journal lists it. |
| NS-002b | content | todo | NS-002 Follow-ups: (1) flawless variants of `nascent_soul_pill` and `soul_formation_pill`, shaped like `flawless_foundation_establishment_pill` (check how the existing flawless pill is produced) and with `breakthrough_realm` set (RV-005). (2) The Drowned Yin Palace caps at nascent_soul, so a Soul Formation player can only get `recipe_soul_formation_pill` from sect shops: add it to a reward table reachable at soul_formation (a late inheritance in data/inheritances.json, or a NS-001 fortune encounter). test_obtainability and test_data_references must pass. |
| NS-006 | content | todo | Soul Formation content pack, like NS-001 (docs/specs/NS-001.md, same method and sim table in the commit): 6 enemies at soul_formation stages 0-3 (beast, righteous non-lethal, demonic, construct mix) and 10 encounters at min_realm soul_formation (6 fights, 3 alignment choice encounters with blocked_by_flag, 1 fortune), using Myriad Peaks Ridge's tags. Tune with simulate_combat.gd to the same curve as NS-001. Check whether `realm_training` covers the soul_formation index (QA-021 extends it) and say so in the commit. |
| NS-007 | content | todo | Realm-appropriate fights for NS-005's three Soul Formation inheritance grounds: the combat baseline rates their trial foes (ancient_puppet_guardian, azure_law_enforcer, soul_reaping_old_monster) TRIVIAL (100% at entry). After NS-006 lands, point their fight stages at NS-006's soul_formation enemies (or add three guardian enemies at soul_formation stage 0-1, `lethal: false`) and check with the combat sim that a Soul Formation veteran wins 50-90%. Depends on NS-006. |

## P4: QA and tooling
| id | role | status | task |
|---|---|---|---|
| QA-021 | qa | todo spec | Realm gap past Core. *Spec:* QA-018 found a veteran at the Nascent Soul / Soul Formation peak beats a plain next-realm foe 20-28% (target: near 0%, owner decision QA-007), because data/enemies.json `realm_training` has entries only up to realm index 4 and the last one is reused. Add entries for realm indices 5..9 continuing the curve (each step roughly +3 attack/defense, +12 max_hp over the previous, or whatever keeps the per-realm same-stage win rate 60-100% for the veteran in tests/sim/simulate_combat.gd), re-run the sim, then tighten the guard in tests/unit/test_combat_balance.gd to "< 10% one realm up" for every realm through Soul Formation. Re-check that NS-001's Nascent Soul foes keep their table (paste it) since they use realm_training index 4. Paste before/after veteran tables and commit the new balance baseline. Also, if simple, exclude manuals with no obtainable source (`Items.sources`) from `veteran_player()`. |
| QA-028 | qa | todo spec | Journal coverage with real content (QA-026 gap; GUIDE-003 is on main): a sect disciple who has an enabled mission, an active sect's call (flag + day key), an open commission, an asked errand (`errands` in data/npcs.json, asked flag set) and an open secret realm; assert each section ("Sect", "Commissions", "Errands", "Opportunities") appears, no line has `%`, `{` or `<null>`, and no text is repeated across two sections of `Guidance.journal`. Fix what fails (small core fixes are in scope; anything bigger goes under Follow-ups). |
| QA-029 | qa | todo spec | A "curious player" first-hour sim. tests/sim/first_hour.gd cultivates a month and explores once per month, so the baseline reports 3.7 log lines a month and 0-3 fights a year, which says nothing about how the first hours feel. Add a second policy (flag `--curious`, same seeds) that each month also explores weekly (`explore_many`), does one chore/deed it qualifies for, takes an enabled sect mission if in a sect, talks to the nearest named NPC once, and delivers commissions/errands it can. Print the same summary plus "distinct things done" (action kinds) per month. Add it to tools/balance.sh (commit the baseline) and a loose guard in test_first_hour_economy or a new test: the curious player is never killed for good, has no month with zero log lines after month 1, and reaches QR3 by month 12 in >= 7/10 seeds (adjust to what it measures and say so). Report anything surprising (stuck states, odd text) in the commit under Follow-ups. |
| QA-030 | qa | todo | Interactable fuzz with a mid-game character. test_interactable_fuzz.gd invokes every menu option in every region with a fresh character, so menus that only appear later (abode arrays, clan estate, children, companions, sect ranks, inheritance trials, spirit garden) are never exercised. Add a second pass with a built-up character (Foundation Establishment, sect inner disciple, married with two children, a founded clan with an estate, an abode, a companion beast, a known secret realm open, 5000 spirit stones); build it with the real GameState/system calls where practical. Same checks (no errors, no `%`/`{`/`<null>` in messages). Fix what fails or list it under Follow-ups. |
| QA-031 | qa | todo | Save round-trip soak: a 50-year headless run (reuse the long-session sim's driver, QA-014) that every 5 years does `to_save_dict` -> JSON string -> `load_save_dict` -> `to_save_dict` and asserts the two dicts are equal (report the first differing key path), then keeps playing from the loaded state. Catches state that isn't saved or loads differently. Keep it under ~20 s for test.sh or put it in tests/sim and run it from tools/balance.sh; say which. |
| QA-020 | qa | todo | Gamepad-only pass on screens added since QA-008/QA-013 (family tree, auction, inner world/garden in the artifact screen, control remapping, respawn, tribulation, threat prompt, credits, sect balance window, journal, save toast must not take focus): extend test_focus_audit.gd and test_steam_deck_layout.gd to cover each, fix what fails. |

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
