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
Next (planner 2026-10-08 22:15): fight feel, loot worth and the journal's goals landed (CMB-004, WU-046..053, GOAL-004,
C-024/025/028..030, RV-010/011, MSG-003, YEAR-002). Now: show the goal on the HUD and what loot is for (WU-044/045), make the
first months after a breakthrough fair (C-031 stage gates for Foundation/Core exploration fights, verified by QA-039) and announce
what a breakthrough or rank opens (GUIDE-010/011), give sect life and the world more texture (SECT-005 lectures, C-035/C-037
choice encounters, WU-056..058 seasons, ambient effects, idle NPCs), and clear the reviewer's notes (RV-012, WU-054, KARMA-001).
| id | role | status | task |
|---|---|---|---|
| RV-012 | systems | todo spec | Sect-rank goal without string matching (reviewer note on GOAL-003). *Spec:* `Guidance.goals` (guidance.gd ~511-519) hides the rank line by testing `reason.begins_with("No trial")`, which breaks silently if `Sects.check_promotion` is reworded. In src/core/systems/sects.gd add two public helpers: `static func needs_trial(c: CharacterData, data: GameData) -> bool` (= `next_rank(c, data) >= 0 and trial_enemy(c, data) != ""`) and `static func rank_requirement_reason(c: CharacterData, data: GameData) -> String` (= "" when `next_rank` < 0, else `_rank_requirement_reason(c, data, next_rank(c, data))`). Rewrite the goals block: `var need := Sects.rank_requirement_reason(c, data)`; if `need != ""` append "Become <rank>: <need>"; elif `Sects.needs_trial(c, data)` append "Become <rank>: you can seek promotion at the sect hall." (only when `check_promotion` is ""); else nothing (auto_promote handles trial-free ranks). Output must be identical to today for every case. `grep -rn "No trial" src tests` and switch any other text match to the helpers. Tests in test_sects.gd: needs_trial is false for a rogue, at the top rank and for a trial-free next rank, true for a trial rank; rank_requirement_reason names the missing contribution. test_guidance.gd: a disciple short of contribution for a trial-free rank gets "Become <rank>: ... contribution ..."; one who meets it gets no rank line; one at a trial rank with requirements met gets "you can seek promotion". |
| SECT-004 | systems | todo spec | Sect ranks can need a stage, not just a realm (C-024 Follow-up: trials were retuned because Foundation ranks opened at Foundation 1st Layer). *Spec:* sects.json ranks get optional `min_stage` (int, default 0, a stage index within the rank's `min_realm`; ignored when `min_realm` is absent/mortal). (1) `Sects._rank_requirement_reason` (sects.gd ~169): after the realm check, if `c.realm_index == min_realm and c.stage < min_stage` return "%s needs a cultivator of %s or above." with `data.realms[min_realm].stage_label(min_stage)` (same wording as missions, sects.gd ~442); also use stage_label in the realm-too-low message when min_stage > 0. (2) `Sects.validate_ranks` (~300): error when min_stage < 0 or >= `data.realms[min_realm].stage_count()`, message like the mission one (~527). (3) Document `min_stage` in sects.json `_doc` next to min_realm. (4) tests/sim/combat_balance.gd `_add_sect_trials` (~233): add `"stage": int(rank.get("min_stage", 0))` to the appearance so the sim rates trials at their real gate (encounters/missions already pass a stage). Don't change any rank data in this task (content may use it later); the balance baseline must not change. Tests in test_sects.gd: a rank with min_realm foundation_establishment + min_stage 3 refuses a Foundation 1st Layer disciple with the stage label in the reason and accepts at 4th Layer (stage 3); auto_promote stops at it; check_promotion returns the reason; validation flags min_stage 99. |
| GUIDE-011 | systems | todo spec | "New" notices for what a breakthrough or rank opens (same mechanism as GUIDE-008/GUIDE-010, so WU-042 shows a banner). *Spec:* in `Guidance.unlock_notices` (guidance.gd ~378) add an optional last param `clan: ClanData = null` and pass `clan` from both GameState call sites (game_state.gd ~2344 and ~2420). New notices, each through `_add_notice` (id without the `notice_` prefix): (a) `promotion_<sect_id>_<rank>` when `Sects.check_promotion(c, data) == ""` and the next rank has a trial: "You may challenge the <rank name> trial at the <sect name> hall."; (b) `clan` when `clan == null` and `Clans.check_found(c, null, data) == ""`: "You can found a clan of your own at your cave abode."; (c) one per secret realm in `data.secret_realms` whose `min_realm` index <= c.realm_index <= its `max_realm` index, id `secret_realm_<id>`: "The <name> admits cultivators of your realm (<region name>; opens every <period_years> years)." (read the region name from data.regions; skip if the realm is unknown). Do (c) also for inheritance grounds only if data.inheritances has a simple realm gate field (check inheritances.gd `check_attempt`; skip otherwise and say so in the commit). New games: pre-set the flags for anything already true at creation (like `notice_rival`, game_state.gd ~113); RV-010's silent seeding covers old saves only when they have no notice_ flags at all, so an older mid-game save will announce (c) once for its current realm: acceptable, note it. Core text names no keys. Tests in test_guidance.gd: a Qi Refining 1 rogue gets no promotion/clan notice and gets a secret-realm notice only for realms whose min_realm is qi_refining (check data); a Foundation disciple meeting a trial rank's requirements gets the promotion notice, and not after its flag is set; a Foundation character with an abode and enough stones gets the clan notice, and not when `clan` is passed. |
| SECT-005 | systems | todo | The elder's monthly lecture (sect life texture; smallest version, tunable). sects.json per sect optional `lecture: {"name": "Elder Feng's sword lecture", "days": 2, "qi_days": 6, "insight_chance": 0.05, "insights": ["sword_dao"]}` (document in `_doc`, validate in Sects.validate or GameData: days >= 1, qi_days >= 0, chance 0..1, insight ids exist in data/dao.json). Core in sects.gd: `check_lecture(c, data, total_days) -> String` (rogues, wrong sect, already attended this month via `c.sect.get("lecture_month", -1) == Calendar.month index of total_days` (use year*12+month), else "") and `attend_lecture(c, data, rng, total_days) -> Dictionary` {qi, insight_id} giving qi = qi_days x the player's daily qi rate at the sect hall's density (reuse Cultivation's per-day gain helper; grep how meditation computes it) and, on `rng.randf() < insight_chance + comprehension bonus 0.005 per point above 10`, glimpse the first listed insight not yet known via Dao's existing glimpse function. `lecture_month` lives in the saved sect dict (default -1, older saves load). GameState.attend_lecture() posts "You attend <name>. (+N qi)" and a line for the insight, advances `days`. Sect hall menu entry "Attend <name> (2 days)" disabled with the reason. Content: give the Azure Cloud Sect, Blood Lotus Sect and Myriad Treasure Pavilion one lecture each fitting their path. Tests: once per month, rogue refused, qi matches the rate, an insight with a seeded rng forcing success; GameState integration test in test_game_session.gd. |
| KARMA-001 | systems | todo | Hostile-act sentences from data (reviewer note on MSG-001: `Karma.act_sentence`, karma.gd ~149, hard-codes rob/humiliate/kill and unknown acts fall back to "You act against X."). Add an optional per-act `sentence` template to data/karma.json `acts` with `{name}` and `{stones}` placeholders (`{stones}` -> "N spirit stone(s)", pluralised), document it in `_doc`, validate in GameData (a string containing `{name}`), give the three acts today's exact sentences, and make act_sentence take `data` (update callers) and use the template, falling back to the current generic line. Tests: the three sentences are unchanged; a test act with a template and stones renders "1 spirit stone"/"5 spirit stones"; validation flags a template without `{name}`. |
| WU-044 | world-ui | todo spec | The current goal on the HUD. *Spec:* a dim one-line label at the top of the hints panel in src/ui/hud.gd (`_refresh`, near where the hint lines are set, ~410-445): "Goal: " + the first line of `Guidance.goals(p, data, GameState.world_flags, GameState.clan, density)` once `Guidance.first_goals_done(...)` or realm_index >= 2, else the first unfinished First goal's text from `Guidance.first_goals` (the entry whose done flag is false; check the dict keys in guidance.gd ~474). Hidden when the HUD hint count setting is 0, when the text is empty, and behind modals like the rest of the HUD (WU-028). Clip to one line (`text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`) so the panel never grows; full text in `tooltip_text`. Refresh on the same signals as the hints. Tests in a tests/unit/test_hud*.gd file: a fresh character's goal line equals "Goal: " + its first unfinished first goal; a Qi Refining 5 disciple with first goals done shows the realm goal; hint count 0 hides it; the panel still fits at 1280x800 / 115% (test_ui_scale_fit). |
| WU-045 | world-ui | todo spec | Inventory says what loot is for. *Spec:* core first, in src/core/systems/items.gd: `static func buyers(data: GameData, item_id: String) -> Array[Dictionary]` = every merchant place in `data.regions` (type `merchant`) whose `stock_tags`+`buy_tags` would buy the item (reuse the tag test inside `buyback_ids`; extract a `static func merchant_buys(data, item_id, stock_tags, buy_tags) -> bool` rather than copying it), as `{region_id, region_name, place_name}` sorted with the player's current region first is NOT core's job: sort by region name; and `static func recipes_using(data: GameData, item_id: String) -> PackedStringArray` = names of recipes in `data.recipes` whose ingredients include the item, sorted. In src/ui/inventory_screen.gd `_show_details` (~211), after the "Market price" line add "Sells for <sell_price> each at <place> (<region>)" for up to 2 buyers, current region (`GameState.current_region`) first, then "and N more" if there are more; "No merchant buys this." when none and the item has a price; and "Used in: <recipe>, <recipe>" (max 3, then "...") when `recipes_using` is not empty. Skip both lines for equipment that is worn. Tests in test_items.gd: Mist Wolf Pelt's buyers include the Wandering Merchant in Qingshi Village; a herb's recipes_using names a recipe that uses it; an item no merchant buys returns []. Inventory test: selecting Boar Hide shows "Used in: Boar Hide Jerkin". |
| WU-054 | world-ui | todo spec | Reviewer notes on WU-053/WU-050. *Spec:* (1) Spoils worth: game_state.gd ~2066 writes "+3 Mist Wolf Pelt (sells for 7)" where 7 is the per-item price. Make it "(sells for 7 each)" when the count is above 1 and keep "(sells for 7)" for a single item (the count is in the `worth` key built at ~2062; store the count alongside the price instead of re-parsing the note). (2) Shop hint: shop_screen.gd ~131 builds the "Left/Right: change quantity. LB/RB or PgUp/PgDn: by 10" label once in `_init`, so a rebind in Settings while the game runs shows the old buttons. Keep a reference to the label and refresh its text in `open()` (~150) and on `InputConfig.controls_changed` (input_config.gd ~61). Tests: a combat-spoils test (extend the WU-053 one, test_game_session.gd ~271) for a 3-pelt drop reads "each", a 1-item drop doesn't; a shop test rebinds `toggle_techniques` via InputConfig, reopens the shop and finds the new key's label in the hint (restore the binding afterwards, as WU-036's test restores its setting). |
| WU-056 | world-ui | todo spec | Seasons you can see. *Spec:* core: in src/core/calendar.gd add `static func season_of(total_days: int) -> String` ("Spring" months 1-3, "Summer" 4-6, "Autumn" 7-9, "Winter" 10-12) and `static func season_tint(season: String) -> Color` (subtle multipliers close to white, e.g. Spring Color(1.0, 1.0, 0.98), Summer Color(1.0, 0.98, 0.92), Autumn Color(1.0, 0.93, 0.85), Winter Color(0.88, 0.92, 1.0)). Don't change `format_date` (many texts and tests use it). World: src/world/world.gd adds a `CanvasModulate` child in `_ready` whose color is `Calendar.season_tint(Calendar.season_of(GameClock.total_days))`, updated on `GameClock.days_advanced` and on region change, tweening over 0.6 s when the season changes (no tween on load). The CanvasModulate must not tint the HUD (HUD is a CanvasLayer; check). HUD: the date label shows " · <Season>" after the date (find where hud.gd sets it). Tests (unit, core): month 1 -> Spring, month 4 -> Summer, month 12 -> Winter, day 359 -> Winter, tints differ per season; a world test: after advancing 120 days the CanvasModulate color equals the Summer tint. Screenshot check with tests/sim/screenshot_regions.gd if you can (attach nothing; just look). |
| WU-057 | world-ui | todo | Ambient particles by region and season (after WU-056): a `CPUParticles2D` layer in world.gd, drawn with no texture (small squares/circles via `scale_amount` and `color`), chosen from optional regions.json `map.ambient` ({"spring": "petals", "autumn": "leaves", "winter": "snow", "any": "mist" ...}, validated in GameData against a fixed list: petals, leaves, snow, mist, embers, fireflies; document in `_doc`). Each kind is a small preset in a new src/world/ambient.gd (amount <= 40, slow drift, low alpha so places and labels stay readable). Give each of the 7 regions sensible kinds (village petals in spring, forest fireflies in summer, marsh mist any season, Myriad Peaks snow in winter...). A Settings toggle "Ambient effects" (default on, saved like "Animate fights") turns it off for the Steam Deck. Tests: every region's ambient kinds validate; toggling the setting removes the emitter; a region with no `ambient` has none. |
| WU-058 | world-ui | todo | NPCs that breathe: named and generated NPCs in src/world/interactables/npc.gd get an idle bob (1-2 px, phase offset from a hash of the npc id so they don't move in sync) and an occasional slow step within 10 px of their home spot, using a local `RandomNumberGenerator` seeded from the npc id (never the global rng, never GameState.rng). Stop moving while the interaction menu is open and while a modal is up (`EventBus.ui_modal_changed`). The interaction Area2D and name label move with the sprite; the home spot stays the position saved/used by WU-023's label spacing. Keep it cheap (`_process` only when visible on screen; VisibleOnScreenNotifier2D). Tests: after 10 s of simulated `_process` an NPC stays within 10 px of home; two NPCs have different phases; interact still works after moving (fuzz test stays green). |
| C-031 | content | todo spec | Fair fights at Foundation and Core entry (balance baseline 2026-10-08: a typical player who has just reached Foundation Establishment wins 1-32% of most Foundation exploration fights, so the first Foundation months are sensed threats and beatings). *Spec:* same method as C-014 (Qi Refining cliff): add `min_stage` (ENC-002) to these encounters in data/encounters.json so the typical player wins >= 40% at the gate in `tests/sim/simulate_combat.gd` (the sim rates encounters at their min_stage): marsh_blood_eyed_wolf (29% at entry), ruins_guardian (26%), forest_demonic_ambush and marsh_demonic_hunter (32%), wild_flame_fox (24%), marsh_drowned_yin_ghost (18%), ruins_bronze_puppet (7%), mountain_iron_rhino and tide_rhino_stampede (6%), forest_ice_spider (5%), wild_sword_madman (3%), wild_blood_lotus_executioner and incursion_raiders (2%), and the Core ones mountain_thunderwing_roc (30%), mountain_bear_king (24%), wild_blood_lotus_elder (16%), ruins_ghost_king (5%). Don't change the enemies themselves (they also guard secret realm floors and trials). A foe that can't reach 40% even at the realm's last stage keeps `min_stage` = last stage and is listed in the commit. Leave wounded_traveller_sect_elder (a choice) alone unless the choice can be gated the same way. Then check each region still has at least one Foundation fight >= 50% at Foundation 1st Layer (from the sim's appearance table); if a region has none, say which under Follow-ups (don't add enemies here). Paste the before/after rows in the commit, run `tools/balance.sh` and commit the new docs/balance_baseline.txt. |
| C-035 | content | todo | First-realm choice encounters where newcomers go after joining a sect: five Qi Refining choice encounters (C-017's format: 2-3 choices, alignment and favor/reputation consequences, `blocked_by_flag` set on every choice, `min_stage` where a fight needs it so it is >= 50% for the typical player at its gate) using the tags of Azure Peak and Fallen Star Market (check data/regions.json `encounter_tags`): e.g. a junior disciple bullied by an outer disciple, a stall selling a "fake" pill that is real, a lost spirit fox kit, a gambling den for spirit stones, a dying rogue's map fragment that points to a secret realm entrance already in the data. Rewards in line with C-017's. Tests: test_data_references / test_encounter_choices stay green; run the combat sim for any fight and paste the rows. |
| C-020 | content | todo | Help pages for systems that have none (audit C22; data/help.json has 0 mentions of taming, tempering, Dao, garden, inner world, bloodline, adoption): Spirit Beasts & taming, Body Tempering, Dao Insights, Creation Artifact functions (storage, appraisal, inner world, spirit garden), Clans & estates (founding requirements from data/family.json, buildings, heirs), Adoption & the orphanage. Same tone and length as the FH-022/C-013 pages, facts checked against the data files (numbers read from data, not invented). test_help_screen.gd stays green. |
| C-037 | content | todo | Foundation-realm choice encounters (mid-game texture after C-031 thins the early Foundation fights): five choice encounters at min_realm foundation_establishment across wild, city and marsh tags: a righteous/demonic dilemma each (spare or devour a defeated demonic cultivator's disciple, report a smuggler to the sect or take a cut, ...), `blocked_by_flag` on every choice, any fight >= 50% at its gate in simulate_combat.gd, rewards that matter at Foundation (Foundation pills, profound_iron, a recipe scroll). Same validation and tests as C-035. |
| C-038 | content | todo | Two mid-game people for the sect regions (like C-011/NS-004): one righteous Foundation Establishment NPC at Azure Peak and one shady Core Formation broker at Fallen Star Market in data/npcs.json with dialogue files in data/dialogue/, each with a favor reward and an `errands` entry (GUIDE-003) asking for something a Foundation player can gather or craft (check `Items.sources`, e.g. a beast material from C-023/C-025 or a Foundation herb). Favor rewards sized like C-011's. Placement must keep clear of places and HUD panels (WU-017/WU-023 tests). Errand turn-ins covered by test_npc_errand_turn_ins. |
| C-018 | content | todo | After NS-006: two Soul Formation people (NS-004 Follow-up) in data/npcs.json + dialogue files, like NS-004 (one righteous, one demonic), each with a favor reward and an errand for a Soul Formation herb that NS-006 makes gatherable; and Ye Zhuoran (NS-004) mentions the flawless Soul Infant pill (NS-002b) in one dialogue line. Errand turn-ins covered by test_npc_errand_turn_ins. |

## P1: Steam release basics
| id | role | status | task |
|---|---|---|---|

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
| QA-038 | qa | todo | Shop fuzz: for a mid-game character holding loot of every category (herbs, ores, beast materials, pills, a manual, a breakthrough pill, worn and spare equipment, readied talismans), open every merchant place in every region through the HUD's shop screen (as test_interactable_fuzz does for menus), switch Buy/Sell and every category tab, press Sell all twice, and check: no engine errors, stones gained == the total the button showed, nothing worn/manual/breakthrough pill (and readied talismans once RV-011 lands) was sold, the list and empty text are consistent, focus is on a row or the tab row after each step. Fix small bugs; list others under Follow-ups. |
| QA-021 | qa | todo spec | Realm gap past Core. *Spec:* QA-018 found a veteran at the Nascent Soul / Soul Formation peak beats a plain next-realm foe 20-28% (target: near 0%, owner decision QA-007), because data/enemies.json `realm_training` has entries only up to realm index 4 and the last one is reused. Add entries for realm indices 5..9 continuing the curve (each step roughly +3 attack/defense, +12 max_hp over the previous, or whatever keeps the per-realm same-stage win rate 60-100% for the veteran in tests/sim/simulate_combat.gd), re-run the sim, then tighten the guard in tests/unit/test_combat_balance.gd to "< 10% one realm up" for every realm through Soul Formation. Re-check that NS-001's Nascent Soul foes keep their table (paste it) since they use realm_training index 4. Paste before/after veteran tables and commit the new balance baseline. Also, if simple, exclude manuals with no obtainable source (`Items.sources`) from `veteran_player()`. |
| QA-039 | qa | todo spec | A "first Foundation year" sim (verifies C-031). *Spec:* tests/sim/simulate_first_hour.gd or a new tests/sim/simulate_foundation_year.gd: for seeds 1-10 build the sim's typical player (combat_balance.gd builders) at Foundation Establishment 1st Layer with qi 0, a rogue and a sect disciple variant, start in each Foundation-friendly region in turn, and for 12 months: explore weekly (`GameState.explore_many` or the Exploration calls the first-hour sim uses), meditate the rest, answer sensed threats with "slip away", take one sect mission a month if in a sect. Print per seed: fights won/lost/evaded, injuries, artifact lives spent, stones +/- and the stage reached; then medians. Add it to tools/balance.sh and commit the baseline. Guard (new test or in test_first_hour_economy.gd, loose): no artifact life spent in the first year in >= 8/10 seeds, and the median win share of fought fights >= 50% (if it measures lower before C-031 lands, put the guard at what it measures and say so; C-031 then tightens it). Under ~60 s. |
| QA-035 | qa | todo | Economy sim: sect months every month (ECON-001b Follow-up). tests/sim/simulate_economy.gd only runs sect months every 12 months, so mission cooldowns never bind and sect income can't be compared fairly with profession work (still 1.5-1.9x for Doctor/Beast Tamer). Make the sim run the sect policy month by month (respecting `Sects.mission_cooldown_left`, duty, stipends) for a sect life, keep the same seeds, print per-profession "sect stones / work stones" ratios, update tools/balance.sh's baseline. If any profession's ratio is still > 1.5x, list the top 3 mission ids by net stones under Follow-ups (the planner files the content retune); don't retune data in this task. Keep runtime under ~60 s. |
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
| GUIDE-010 | systems | "New roads open" notice when a gated travel route opens. |
| RV-010 | systems | Old saves seed feature notices silently; the artifact notice names no key. |
| RV-011 | systems | "Sell all loot" keeps readied combat talismans. |
| MSG-003 | systems | "Your path has shifted" after any alignment change (checked on player_changed). |
| GOAL-004 | systems | Profession goal in the journal Goals section (Doctors: treat patients, reviewer fix). |
| CMB-004 | systems | Combat trace steps with each opener line. |
| YEAR-002 | systems | A seclusion across two new years reviews both ("Years A-N"; `year_start_year`). |
| WU-046 | world-ui | Hit sounds by blow weight. |
| WU-047 | world-ui | Combat report line colors. |
| WU-048 | world-ui | Main menu "Continue: <name>, <realm>, age N". |
| WU-049 | world-ui | "Sell all loot" previews what it sells. |
| WU-050 | world-ui | Shop quantity-step keys through InputConfig. |
| WU-053 | world-ui | Spoils line says what each item sells for. |
| C-024 | content | Fair Foundation rank trials, tournament ring and vengeful brother. |
| C-025 | content | Recipes for the unused beast materials; baseline refreshed. |
| C-028 | content | Help pages for fights, selling loot and journal goals. |
| C-029 | content | Quiet exploring days have texture (regions.json `quiet_lines`). |
| C-030 | content | Milestones for stones earned, qi gathered and encounters. |
| QA-037 | qa | Combat text audit test (every enemy, talisman and ally lines); no bugs found. |
| CMB-003 | systems | Blows described by weight (glancing / solid / crushing); finishing lines by outcome. |
| CMB-002 | systems | Attack techniques named in combat log lines; per-line `trace` of [player_hp, enemy_hp]. |
| WU-039 | world-ui | Shop category tabs. |
| QA-033 | qa | Fuzz profiles: open secret realm window, pending sect promotion trial; nothing found. |
| WU-040 | world-ui | "Sell all loot" in the shop (`Items.bulk_sell_ids`, `GameState.sell_all`). |
| GUIDE-008 | systems | `Guidance.unlock_notices` (body tempering, Dao, artifact functions, rival), posted once. |
| C-023 | content | 8 beast materials dropped by 10 beasts, 4 buyers, 3 recipes; income per kill level. |
| WU-043 | world-ui | Spoils line in the combat report. |
| WU-041 | world-ui | HUD "~N days to the next layer here". |
| GOAL-002 | systems | Journal breakthrough odds, "To raise them" and "Prepare" pill lines. |
| REL-011 | qa | tools/steam/ vdf templates, tools/steam_upload.sh, docs/RELEASE.md. |
| C-022 | content | Qi Refining sect rank trials 45-52% at entry. |
| QA-036 | qa | Household hint honesty; `Training.has_options` fixes the rootless-child lie. |
| GUIDE-009 | systems | Sell hint naming the best merchant and the stones it would pay. |
| WU-036 | world-ui | Combat playback: hp bars, line-by-line reveal, Skip, "Animate fights" setting. |
| WU-042 | world-ui | "New" banner for feature notices (`EventBus.feature_unlocked`). |
| MSG-002 | systems | Reputation notes name the tier; devoured qi counts as qi gathered. |
| GOAL-003 | systems | `Guidance.goals`: Goals journal section after the first goals. |
| QA-020 | qa | Focus audit and Deck layout cover the screens added since QA-013; no fixes needed. |
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
