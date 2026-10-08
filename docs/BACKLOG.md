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
Next (planner 2026-10-08 18:15): the first-hour audit's fixes all landed (honest hints, first goals, confirms, number words,
item effects, inventory tabs, shop Max). Now: give fights flavor and pace (CMB-002/003, WU-036, WU-043), make loot worth
something (C-023 beast materials, GUIDE-009, WU-039/040), keep pointing the player at a goal after the first hour
(GOAL-002/003, WU-041), and fix the remaining unfair gates (C-022, C-024).
| id | role | status | task |
|---|---|---|---|
| CMB-002 | systems | todo | Techniques in the combat log, and a per-line hp trace for playback (WU-036). In `Combat.resolve` (combat.gd ~150): when the player strikes, name one of their combat techniques that has an `attack` bonus ("You strike with Iron Fist for 12."), rotating through them by round (`known[rounds % known.size()]`), **without drawing from `rng`** (draws would shift every fight and the balance baselines); none known -> current wording. Enemies with `techniques` in data/enemies.json likewise ("The Mist Wolf lunges with Moonlit Fang for 8."; plain "hits you" when none). Also add `"trace": Array` to the result: one `[player_hp, enemy_hp]` pair per `log` line (same length as `log`). Tests in test_combat.gd: technique names appear for a character who knows one, not for one who doesn't; trace length == log length and its last pair matches player_hp/enemy_hp; the same seed gives the same victory/rounds as before the change (compare against `resolve` with techniques removed from the names only, or assert `tools/balance.sh --check` unchanged in the commit message). |
| GUIDE-008 | systems | todo spec | New-feature notices (audit F31): body tempering, Dao contemplation, the spirit garden, the inner world and the rival are easy to miss. Add `Guidance.unlock_notices(c, data, flags) -> Array[Dictionary]` returning {id, text} for features that just became available and have not been announced (flag `notice_<id>`): body tempering available (BodyTempering can start a stage) -> "You are strong enough to temper your body at a meditation spot."; first Dao insight glimpsed -> "Contemplate your glimpsed insight at a meditation spot."; artifact function unsealable (spirit garden / inner world) -> "The Creation Artifact can unseal <function> (Artifact screen, O)."; rival assigned -> "<Rival> has named you a rival." GameState checks them after each action that advances time (where milestones are checked), posts each once (category "progress"), and sets the flag. Tests in test_guidance.gd per notice + once-only in test_game_session.gd. |
| GOAL-002 | systems | todo spec | The journal's Breakthrough section says your odds and how to raise them. *Spec:* in `Guidance._breakthrough_entries` (src/core/systems/guidance.gd ~592), when `Cultivation.can_attempt_breakthrough(c, data)` is true add a line `"Odds now: " + chance_text(c, data)` (tone normal) right after the bottleneck warning, and, when `pill_source_hint(c, data)` is not empty, a line `"To raise them: " + pill_source_hint(...)` (normal). Also when not yet at the bottleneck but within 30 days of it (`Cultivation.days_to_bottleneck` 1..30), add the pill_source_hint line as `"Prepare: " + ...` (dim) so the player buys the pill before they arrive. Never both lines twice; no line in the final realm. Tests in tests/unit/test_guidance.gd: a QR peak character (qi at the bottleneck, no pill) gets both lines and the odds line ends with `%.`; holding the right pill drops the "To raise them" line; a character 10 days short gets the "Prepare:" line, one 200 days short doesn't; no `{`/`_` ids in any line. |
| GUIDE-009 | systems | todo spec | Tell the player their loot is worth money ("make loot sellable"). *Spec:* new hint in `Guidance.hints` (src/core/systems/guidance.gd ~23), after the newcomer hints and before `_untried_hint`: `static func _sell_hint(c, data, region_id) -> String`. For every merchant place in `data.regions[region_id].places` (type `merchant`), compute the stones `c` would get selling everything `Items.buyback_ids(c, data, place.stock_tags, place.buy_tags)` returns, excluding equipped items and anything with a non-empty `Items.use_warning`-style lock if one exists (check CharacterData for equipped slots; never count `spirit_stone`), `sum(Items.sell_price * count)`. If the best merchant's total >= 50 stones (const SELL_HINT_MIN := 50) return "The <display_name> here would pay about N spirit stones for your <herbs and ore / goods>." (use the merchant's tags to name the goods: herb -> herbs, ore -> ore, beast_material -> beast materials, else goods; join two with " and "). "" otherwise or with no region_id. Hint text must name a place that exists in the region (QA-034's test_hint_honesty.gd checks names; extend it for this hint). Tests in test_guidance.gd: a character holding 10 of a herb in qingshi_village gets the hint naming the Wandering Merchant and the right total; below 50 stones no hint; in a region with no buyer no hint; equipped weapon not counted. |
| GOAL-003 | systems | todo | Goals after the first goals (mid-game direction). Once `Guidance.first_goals_done` (or realm_index >= 2), the journal gets a "Goals" section in place of First goals with up to 3 lines from `static func goals(c, data, flags, clan, density) -> PackedStringArray` in guidance.gd: (1) the next realm: "Reach <next realm>: about N days of meditation, then a breakthrough (<odds>%)." using `Cultivation.days_to_bottleneck` and `breakthrough_chance` (skip in the final realm); (2) in a sect: the next rank and what blocks it, from `Sects.check_promotion(c, data)` ("Become <rank>: <reason>"; "You can seek promotion at the sect hall." when ""); rogue: "Found a clan: <first missing requirement>" from the Clans founding check if not founded; (3) the pending milestone with the highest progress fraction from `Milestones.progress` ("<name> (3/5)"). No ids, no `%d`. Tests in test_guidance.gd: a QR3 newcomer still sees First goals and no Goals; a QR5 disciple with first goals done sees Goals with a realm line and a rank line; a rogue sees a clan line; a final-realm character has no realm line. |
| MSG-002 | systems | todo | Reputation and devoured qi say what they mean (MSG-001 and STAT-002 Follow-ups). (1) `Reputation._note` (reputation.gd ~138, "Azure Cloud Sect reputation +5") appends the resulting tier from `Reputation.tier(data, rep)`: "Azure Cloud Sect reputation +5 (now Friendly)", and when the tier name changed compared to before the change, the note says "... +5: you are now Friendly with the Azure Cloud Sect" instead (pass the old value in). (2) Devouring qi (devouring.gd ~55 `Cultivation.add_qi`) counts toward the `qi_gathered` life stat the same way Cultivation.cultivate records it (find the call STAT-002 added). Tests: reputation note wording with and without a tier change (test_reputation.gd), devouring increments qi_gathered (test_devouring.gd); no `%`/`{` in notes. |
| CMB-003 | systems | todo | After CMB-002: fights read with weight. In `Combat.resolve`'s log lines, describe each hit by its share of the target's max hp, without any rng draws: < 8% "a glancing blow", < 20% (plain, today's wording), < 35% "a solid blow", else "a crushing blow" (thresholds as consts with a `##` doc), e.g. "You strike with Iron Fist: a crushing blow for 31."; and replace the last line with a finishing line by outcome: enemy beaten -> "<Enemy> collapses." (beast tag or name lookup optional) / "<Enemy> yields." for `spar` or non-lethal cultivators; player beaten -> "You fall." (lethal) / "You are beaten down." (non-lethal); fled stays as is. Keep `trace` the same length as `log` (add the finishing line's pair). Tests in test_combat.gd: a fight with one huge hit logs "crushing", tiny hits log "glancing", the finishing line matches the outcome, victory/rounds for a fixed seed are unchanged vs before (compare a run with words stripped), trace length == log length. |
| WU-039 | world-ui | todo spec | Shop category tabs (WU-035 Follow-up). *Spec:* in src/ui/shop_screen.gd add the same tab row WU-035 put in src/ui/inventory_screen.gd (reuse `Items.CATEGORIES` / `Items.category(item)`; if the inventory builds its tab row in a helper, move that helper to UIStyle or a small shared static func so both screens use it, don't copy 40 lines). The row sits under the Buy/Sell tabs, filters whichever list is showing, shows only categories that have at least one row in the current list plus All, resets to All when switching Buy/Sell, and the empty text stays "Nothing for sale." / "You have nothing this merchant wants." for All and "Nothing here." for a category. Gamepad: ui_left/ui_right on the tab row (shoulders are taken). Focus: after a tab change, the first goods row. Tests in tests/unit/test_shop_screen.gd (or the existing shop test file): opening a merchant with herbs and pills shows tabs for both plus All; picking Pills filters the list to pills; switching to Sell resets to All; focus lands on the first row. Screens stay inside 1280x800 at 115% (test_ui_scale_fit). |
| WU-040 | world-ui | todo spec | "Sell all loot" in the shop's Sell tab. *Spec:* core first: `Items.bulk_sell_ids(c: CharacterData, data: GameData, stock_tags: Array, buy_tags: Array) -> Array` in items.gd = `buyback_ids` minus equipped items, manuals/scrolls (`Items.category` == the manuals category), breakthrough pills (effects.breakthrough_bonus > 0) and anything `Items.use_warning`/`Equipment.equip_warning` flags; plus `GameState.sell_all(ids: Array) -> int` that sells each full stack through the existing `sell_item` path (one message total: "You sell 14 items for 212 spirit stones.", not one per stack; returns stones). UI: a "Sell all loot (N stones)" button above the Sell list, hidden when the total is 0, using WU-032's arm-on-first-press confirm ("Press again to sell 14 items for 212 spirit stones"). Tests: bulk_sell_ids excludes an equipped sword, a manual and a breakthrough pill (test_items.gd); GameState.sell_all pays the sum of sell prices, posts one line and records stones_earned once per stone (test_game_session.gd); the button needs two presses (shop screen test). |
| WU-041 | world-ui | todo spec | Show the time to the next layer on the HUD. *Spec:* in src/ui/hud.gd's status refresh (~383-401, where "Qi: %d / %d" and the qi bar are set) add a small dim label under the qi bar: "~N days to the next layer here" from `GameState.days_to_next_stage(GameState.region_qi_density())` ("next stage" past Qi Refining; "Ready to break through" at a breakthrough bottleneck, which the existing `_bottleneck` hint already covers, so hide the new label then; hidden when -1 or > 3650). Refresh on the same signals as the qi bar. Keep it inside the status panel at 115% scale (test_ui_scale_fit) and hide it with the rest of the HUD behind modals (WU-028). Test in tests/unit/test_hud*.gd: a fresh QR1 character shows a number matching `GameState.days_to_next_stage`; at the bottleneck the label is hidden. |
| WU-043 | world-ui | todo | Spoils in the combat report. GameState already keeps `last_loss_advice` for the report (hud.gd ~484); add `last_fight_spoils: PackedStringArray` set wherever a won fight's rewards are applied (the Effects notes for enemy `rewards`: items with names and counts, stones, qi, alignment), cleared at the start of each fight. `CombatReport.show_fight` gets a 5th param and shows a "Spoils: 8 spirit stones, Wolf Pelt x1, 40 qi" line under the log on a win (nothing on a loss or spar without rewards). Tests: a won fight's report shows the spoils line naming the item, a lost fight shows none; GameState test that spoils are cleared between fights. |
| WU-036 | world-ui | todo | After CMB-002: combat playback. The combat report (src/ui/combat_report.gd) shows two hp bars (you / foe) and reveals log lines one at a time (~0.25 s each, faster setting-free), updating the bars from `result.trace`; accept/cancel or a "Skip" button shows everything at once; Continue is focused only after the reveal ends or is skipped. Respects a new Settings toggle "Animate fights" (default on, saved with settings; off = today's instant report). SFX hit sound per line if Audio has one (reuse; don't add assets). Tests: with animation on, after one tick fewer lines than the log are shown; skip shows all; with the setting off the report is complete at once; bars end at the result's hp. |
| WU-042 | world-ui | todo | After GUIDE-008: new-feature notices get a small banner (the milestone banner style, UIStyle.ACCENT, title "New", body = the notice text) besides the log line, queued like other banners (RV-002), at most one per action. Respect the HUD hint count setting: 0 hints = no banner (log line only). Test: a notice emits one banner; two notices in one action queue two; with hints 0 none. |
| C-023 | content | todo spec | Beast materials: loot you can sell and craft with (C-019 Follow-up, "make loot sellable"). *Spec:* (1) data/items.json: 8 materials tagged `beast_material` (plus `material`, whatever tag convention herbs/ores use; check `Items.category` so they land in Herbs & Ores or Other sensibly): Boar Hide (wild_boar, iron_back_boar; price ~6), Mist Wolf Pelt (mist_wolf; ~14), Fox Spirit Tail (mist_fox; ~30), Stone Ape Hide (stone_ape, moss_back_ape; ~25), Crane Feather (azure_crane; ~35), Eagle Talon (cloud_eagle; ~60), Blood-Eyed Wolf Fang (blood_eyed_wolf; ~70), Python Scale (jade_python; ~200). Names/descriptions in genre tone; prices scale with the beast's realm like herbs of that realm do. (2) Add 1 unit to each listed beast's `rewards.items` in data/enemies.json (deterministic, no rng change); keep the existing stones but cut them by about the material's sell value so total income per kill stays within +10% (ECON guard). (3) Buyers: add `beast_material` to the Wandering Merchant's `buy_tags` (qingshi_village) and to one merchant's `buy_tags` in each region that has beasts (regions.json). (4) Recipes: 3 uses in data/recipes.json: a forging recipe (Boar Hide armor or Wolf Pelt cloak, grade 1 gear), a talisman (Crane Feather in a speed talisman) and an alchemy pill using Fox Spirit Tail; ingredients and outputs priced so `Items.sell_price`'s crafted cap holds. (5) Re-run `tools/balance.sh` and tests/sim/simulate_economy.gd; paste income before/after for gathering and hunting in the commit; commit the baseline. Tests: data validation passes; add one test in test_items.gd that every `beast_material` item is a reward of at least one enemy and bought by at least one merchant. |
| C-022 | content | todo spec | QR sect rank trials at 1-4% (balance baseline: azure_sword_examiner 1%, blood_pit_gladiator 4%, pavilion_vault_guard 1%). Check at which realm/stage each trial actually opens (`Sects.check_promotion`, data/sects.json rank requirements) and measure there with simulate_combat.gd; if the typical player at the rank's requirement is under 40%, retune the trial enemy (they are trial-only foes; grep to confirm) to 45-70% there. Paste before/after; commit the new baseline. |
| C-024 | content | todo | Fair Foundation rank trials and the tournament ring (balance baseline): the Azure Cloud Sect's Foundation rank trial azure_pavilion_warden is 31% at entry and the Blood Lotus trial blood_pit_champion 23% (both forced); the `tournament_bout` encounter (data/encounters.json, min_realm qi_refining) throws a QR 1st Layer player into the ring against tournament_contender, a QR 6th Layer foe (0% at entry, 3% for the veteran on appearance), and the wounded-traveller `vengeful_brother` is 4% at entry. Like C-022: find each trial's real gate (sect rank requirements in data/sects.json, `Sects.check_promotion`) and measure there with tests/sim/simulate_combat.gd; trials -> 45-70% for the typical player at the gate (trial-only foes may be retuned; grep first). Tournament: add `min_stage` to the encounter (ENC-002) near the contender's stage, or lower the contender's stage so the typical player at the encounter's gate wins 40-60% (the Enter choice is optional, keep it a stretch). vengeful_brother: gate the encounter with `min_stage` so it is >= 40% at its gate. Paste before/after rows; commit the new baseline. |
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
| QA-029 | qa | todo spec | A "curious player" first-hour sim. tests/sim/first_hour.gd cultivates a month and explores once per month, so the baseline reports 3.7 log lines a month and 0-3 fights a year, which says nothing about how the first hours feel. Add a second policy (flag `--curious`, same seeds) that each month also explores weekly (`explore_many`), does one chore/deed it qualifies for, takes an enabled sect mission if in a sect, talks to the nearest named NPC once, and delivers commissions/errands it can. Print the same summary plus "distinct things done" (action kinds) per month. Add it to tools/balance.sh (commit the baseline) and a loose guard in test_first_hour_economy or a new test: the curious player is never killed for good, has no month with zero log lines after month 1, and reaches QR3 by month 12 in >= 7/10 seeds (adjust to what it measures and say so). Report anything surprising (stuck states, odd text) in the commit under Follow-ups. |
| QA-033 | qa | todo | Fuzz the states QA-030 couldn't reach (QA-030 Follow-up): a profile spawned while a secret realm's window is open (pick a realm the profile qualifies for; set the clock into its window) and one with a sect promotion trial available (contribution and realm met). Same checks as the other fuzz passes. Fix what fails or list it under Follow-ups. |
| QA-021 | qa | todo spec | Realm gap past Core. *Spec:* QA-018 found a veteran at the Nascent Soul / Soul Formation peak beats a plain next-realm foe 20-28% (target: near 0%, owner decision QA-007), because data/enemies.json `realm_training` has entries only up to realm index 4 and the last one is reused. Add entries for realm indices 5..9 continuing the curve (each step roughly +3 attack/defense, +12 max_hp over the previous, or whatever keeps the per-realm same-stage win rate 60-100% for the veteran in tests/sim/simulate_combat.gd), re-run the sim, then tighten the guard in tests/unit/test_combat_balance.gd to "< 10% one realm up" for every realm through Soul Formation. Re-check that NS-001's Nascent Soul foes keep their table (paste it) since they use realm_training index 4. Paste before/after veteran tables and commit the new balance baseline. Also, if simple, exclude manuals with no obtainable source (`Items.sources`) from `veteran_player()`. |
| QA-035 | qa | todo | Economy sim: sect months every month (ECON-001b Follow-up). tests/sim/simulate_economy.gd only runs sect months every 12 months, so mission cooldowns never bind and sect income can't be compared fairly with profession work (still 1.5-1.9x for Doctor/Beast Tamer). Make the sim run the sect policy month by month (respecting `Sects.mission_cooldown_left`, duty, stipends) for a sect life, keep the same seeds, print per-profession "sect stones / work stones" ratios, update tools/balance.sh's baseline. If any profession's ratio is still > 1.5x, list the top 3 mission ids by net stones under Follow-ups (the planner files the content retune); don't retune data in this task. Keep runtime under ~60 s. |
| QA-036 | qa | todo | Hint honesty for family hints (QA-034 Follow-up): extend tests/unit/test_hint_honesty.gd with a Qi Refining character who has a spouse and a child (use the people table the way test_game_session.gd's family tests build one) and a clan head: every family/household/clan hint and journal Household line names a person who exists in `people`, a place that exists, and an action the player can take (e.g. a training hint only when `Children.check_train` passes). Fix small lies in guidance.gd; list bigger ones under Follow-ups. |
| QA-020 | qa | todo | Gamepad-only pass on screens added since QA-008/QA-013 (family tree, auction, inner world/garden in the artifact screen, control remapping, respawn, tribulation, threat prompt, credits, sect balance window, journal, save toast must not take focus): extend test_focus_audit.gd and test_steam_deck_layout.gd to cover each, fix what fails. |
| QA-032 | qa | todo | Reconcile the newcomer guard with the sim's typical player (C-015 Follow-up): test_first_hour_economy's FH-024 guard (rank-0 missions must be Even/Weak for a weak test character) is so much weaker than simulate_combat.gd's typical player that cull_mist_wolves, patrol_misty_peaks and the sect-call missions stay TRIVIAL (100%). Measure both characters' win odds on every rank-0/1 mission, then either make the guard character match the typical player at that mission's gate or relax the guard to Weak/Even/Dangerous at the mission's min_stage; whichever you pick, the sect-call and wolf missions must land in 60-95% for the typical player (retune their enemy or add a min_stage in data/sects.json). Paste before/after. |

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
| FH-030 | systems | Honest newcomer hints (sect hint for Mortals, Elder Mo's free breathing lesson); First goals journal section. |
| CULT-001 | systems | `Cultivation.days_to_next_stage` / `progress_text`; meditation lines end with qi progress. |
| MSG-001 | systems | Grudge words, one-sentence hostile acts, favor thresholds, alignment tier names, contribution left. |
| STAT-002 | systems | `stones_earned` / `qi_gathered` life stats; year summary and epilogue lines. |
| WU-032 | world-ui | Confirms for sect join/leave, artifact feeds and risky item use/equip (`Items.use_warning`, `Equipment.equip_warning`). |
| WU-033 | world-ui | `Items.describe_effects` in core, covering every effect key. |
| WU-034 | world-ui | "Meditate until the next layer" at meditation spots and abodes. |
| WU-035 | world-ui | Inventory category tabs (`Items.category`). |
| WU-037 | world-ui | Help on F1 / H (keyboard only). |
| WU-038 | world-ui | Shop quantity Max and steps of 10. |
| ECON-001b | content | Sect stipends cut ~60%; long newcomer item errands; sim prints income per mission. |
| C-019 | content | Qingshi fixes: Elder Mo's directions, fewer empty days, no mortal bandit fight, merchant `buy_tags`. |
| C-021 | content | Weaker guardians for the first secret realm floors and trials (all >= 42% at entry). |
| C-016 | content | Beatable Core forced fights (Blood Lotus trial 49%, new star_vault_warden). |
| QA-034 | qa | Hint honesty audit test; no lies found. |
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
