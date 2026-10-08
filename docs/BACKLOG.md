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
Next (planner 2026-10-08 20:15): fight flavor, sellable loot and mid-game goals landed (CMB-002, WU-036/039..043, C-023,
GOAL-002/003, GUIDE-008/009). Now: finish fight feel (CMB-003/004, WU-046/047 sounds and line colors), show the goal and what
loot is for (WU-044 HUD goal line, WU-045 inventory "sells at / used in", C-025 recipes for unused beast materials), clean up
the reviewer's notes from the last run (RV-010 notice burst on old saves, RV-011 sell-all keeps readied talismans, MSG-003),
and give quiet exploring days some texture (C-029).
| id | role | status | task |
|---|---|---|---|
| RV-010 | systems | todo spec | Feature notices on old saves and the hard-coded key (reviewer notes on GUIDE-008). *Spec:* (1) `GameState.load_save_dict` (game_state.gd ~2312): after `world_flags` is restored, if no key in `world_flags` begins with `"notice_"` (a save from before GUIDE-008), set `world_flags["notice_" + id] = true` for every notice `Guidance.unlock_notices(player, data, world_flags, npcs)` returns, **without posting** and without emitting `feature_unlocked`, so loading an old mid-game save no longer floods the log and queues a "New" banner per feature. Saves that already have any `notice_` flag are left alone (features unlocked since still announce). (2) guidance.gd ~392: core text must not name a key; change the artifact notice to "The Creation Artifact can unseal <function> on the Artifact screen." (the HUD key bar already shows the binding). Update any test that matched the old wording. Tests in test_game_session.gd: load a save dict built from a mid-game character (Qi Refining 3+, a glimpsed Dao insight) whose world_flags has no notice_ keys -> no "progress" post contains "temper your body" or "Contemplate" after load, and the flags are set; a save that has `notice_rival` but meets the body-tempering condition still gets the body-tempering notice on the next `player_changed`; the artifact notice text contains no "(". |
| RV-011 | systems | todo spec | "Sell all loot" keeps readied combat talismans (reviewer note on WU-040). *Spec:* `Items.bulk_sell_ids` (items.gd ~195) also skips every id in `c.readied_talismans` (the player readied it for the next fight; selling it silently unreadies it). Keep spare unworn equipment in the list (it is loot). Tests in test_items.gd: a character with 3 Fire Strike Talismans readied and 2 Swift Wind Talismans not readied, at a merchant whose tags buy talismans: bulk_sell_ids contains swift_wind_talisman but not fire_strike_talisman; `bulk_sell_total` excludes it. GameState.sell_all test unchanged. |
| MSG-003 | systems | todo spec | "Your path has shifted" after any alignment change (reviewer note on MSG-001: today `_announce_tier` (game_state.gd ~1135) only runs after hostile acts, treating, devouring and patients, so a tier change from a deed, item, encounter or mission is announced late or under the wrong action). *Spec:* connect `EventBus.player_changed.connect(_announce_tier)` next to `check_milestones` in `_ready` (game_state.gd ~78) and delete the five explicit `_announce_tier()` calls; make `_announce_tier` return early when `player == null`. `_announced_tier` is already seeded on load (~2314); also seed it in the new-game path (where `session_started` is emitted, ~117) so a fresh character never gets the line on its first action. Tests in test_game_session.gd: an encounter choice or deed that moves alignment across a tier boundary posts "Your path has shifted: you are now <tier>." exactly once (category "karma"); a change within a tier posts nothing; a new game and a load post nothing; existing hostile-act tests still pass. |
| GOAL-004 | systems | todo spec | A profession goal in the journal's Goals section (GOAL-003 Follow-up idea: crafters get no direction). *Spec:* in `Guidance.goals` (guidance.gd ~499), after the sect/clan line and before the milestone line: for the profession in `c.professions` with the highest rank (ties: most xp; skip professions at `Professions.max_rank(data)`), add "Become <next rank title>: <N> more xp (craft or work at a workshop)." where the title is `data.profession_rank_names[rank + 1] + " " + ProfessionDef.name` and N = `ceili(def.xp_to_next(rank) - Professions.xp_of(c, id))`. No line when the player has no profession. Keep the section at most 4 lines. Tests in test_guidance.gd: an Alchemist at rank 0 with 10 xp gets the line with the right next title and N; a max-rank crafter gets none; a character with no profession gets none; no `_` ids or `%` in any line. |
| CMB-003 | systems | todo | After CMB-002: fights read with weight. In `Combat.resolve`'s log lines, describe each hit by its share of the target's max hp, without any rng draws: < 8% "a glancing blow", < 20% (plain, today's wording), < 35% "a solid blow", else "a crushing blow" (thresholds as consts with a `##` doc), e.g. "You strike with Iron Fist: a crushing blow for 31."; and replace the last line with a finishing line by outcome: enemy beaten -> "<Enemy> collapses." (beast tag or name lookup optional) / "<Enemy> yields." for `spar` or non-lethal cultivators; player beaten -> "You fall." (lethal) / "You are beaten down." (non-lethal); fled stays as is. Keep `trace` the same length as `log` (add the finishing line's pair). Tests in test_combat.gd: a fight with one huge hit logs "crushing", tiny hits log "glancing", the finishing line matches the outcome, victory/rounds for a fixed seed are unchanged vs before (compare a run with words stripped), trace length == log length. |
| CMB-004 | systems | todo | After CMB-003: the trace steps with each opener (reviewer note on CMB-002). In `Combat.resolve` (combat.gd ~136-154) every pre-round line (form line, each shield talisman, each strike talisman, each ally blow) gets its own `trace` pair with the hp right after that line, instead of all of them sharing the hp after every opener, so WU-036's foe bar drops talisman by talisman. No rng change. Test in test_combat.gd: a character with two readied strike talismans and an ally: the trace pairs for the two talisman lines differ and each pair's enemy hp matches the number printed in its line; trace length == log length. |
| YEAR-002 | systems | todo | A seclusion that crosses two new years reviews both (reviewer note on YEAR-001: `GameClock` emits `year_changed` once with the last year, so the review is titled "Year N" but covers N-1 and N). Store `year_start_year: int` on CharacterData with the snapshot (default 0, to_dict/from_dict, no SAVE_VERSION bump needed), and when it is older than year - 1 title the review "Years <start>-<N>" (pass the span to `EventBus.year_reviewed` or build the title in GameState; keep the HUD banner working). Tests: a 400-day seclusion from mid-year 1 posts one review titled for both years; a normal year still says "Year N". |
| GUIDE-010 | systems | todo | New roads open (a GUIDE-008 notice): add to `Guidance.unlock_notices` one notice per region whose travel route `min_realm` (regions.json `routes`) the player now meets and that has a gate at all: id `road_<region_id>`, text "You are strong enough to travel to <Region name> (<days> days from <from region>)." using the shortest gated route; skip regions the player has already visited if a visited set exists (check GameState/world_flags for one; otherwise skip this check). New games pre-set the flags for routes already open (like `notice_rival`, game_state.gd ~113); RV-010's silent seeding covers old saves (do this after RV-010 or seed `road_` ids the same way). Tests in test_guidance.gd: a mortal gets no road notice; the same character at Qi Refining 1 gets one per qi_refining-gated destination; flags suppress it.
| WU-044 | world-ui | todo spec | The current goal on the HUD. *Spec:* a dim one-line label at the top of the hints panel in src/ui/hud.gd (`_refresh`, near where the hint lines are set, ~410-445): "Goal: " + the first line of `Guidance.goals(p, data, GameState.world_flags, GameState.clan, density)` once `Guidance.first_goals_done(...)` or realm_index >= 2, else the first unfinished First goal's text from `Guidance.first_goals` (the entry whose done flag is false; check the dict keys in guidance.gd ~474). Hidden when the HUD hint count setting is 0, when the text is empty, and behind modals like the rest of the HUD (WU-028). Clip to one line (`text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`) so the panel never grows; full text in `tooltip_text`. Refresh on the same signals as the hints. Tests in a tests/unit/test_hud*.gd file: a fresh character's goal line equals "Goal: " + its first unfinished first goal; a Qi Refining 5 disciple with first goals done shows the realm goal; hint count 0 hides it; the panel still fits at 1280x800 / 115% (test_ui_scale_fit). |
| WU-045 | world-ui | todo spec | Inventory says what loot is for. *Spec:* core first, in src/core/systems/items.gd: `static func buyers(data: GameData, item_id: String) -> Array[Dictionary]` = every merchant place in `data.regions` (type `merchant`) whose `stock_tags`+`buy_tags` would buy the item (reuse the tag test inside `buyback_ids`; extract a `static func merchant_buys(data, item_id, stock_tags, buy_tags) -> bool` rather than copying it), as `{region_id, region_name, place_name}` sorted with the player's current region first is NOT core's job: sort by region name; and `static func recipes_using(data: GameData, item_id: String) -> PackedStringArray` = names of recipes in `data.recipes` whose ingredients include the item, sorted. In src/ui/inventory_screen.gd `_show_details` (~211), after the "Market price" line add "Sells for <sell_price> each at <place> (<region>)" for up to 2 buyers, current region (`GameState.current_region`) first, then "and N more" if there are more; "No merchant buys this." when none and the item has a price; and "Used in: <recipe>, <recipe>" (max 3, then "...") when `recipes_using` is not empty. Skip both lines for equipment that is worn. Tests in test_items.gd: Mist Wolf Pelt's buyers include the Wandering Merchant in Qingshi Village; a herb's recipes_using names a recipe that uses it; an item no merchant buys returns []. Inventory test: selecting Boar Hide shows "Used in: Boar Hide Jerkin". |
| WU-048 | world-ui | todo | The main menu's Continue button says who you continue as: "Continue: <name>, <realm label>, age N" from the newest live slot's metadata (the same `SaveManager.list_slots()` fields the load screen shows; skip damaged / newer_version / fallen slots, as `_continue` already does). Keep the button one line (trim with ellipsis) and hide or disable it when no slot qualifies, as today. Test in the main menu or load-screen test file with a temp save: the label contains the character's name. |
| WU-049 | world-ui | todo | "Sell all loot" says what it sells: under the button in src/ui/shop_screen.gd (`_refresh_sell_all`, ~300) a dim wrapped line "Sells: 6 Mist Wolf Pelt, 3 Iron Essence, 2 Spirit Herb and 4 more kinds" (top 3 stacks by value from `Items.bulk_sell_ids` / `sell_price`, then the count of remaining kinds), hidden with the button. Keep the shop inside 1280x800 at 115%. Test in the shop screen test: the line names the most valuable stack and the count of the rest. |
| WU-053 | world-ui | todo | Spoils say what they are worth: in the combat report's spoils line (WU-043) each item reads "Mist Wolf Pelt x1 (sells for 7)" using `Items.sell_price`, skipped when the price is 0; stones and qi unchanged. Build the text in GameState where `last_fight_spoils` is filled (core-side wording, no UI maths). Test: a won fight against a mist wolf shows "(sells for N)" with N == Items.sell_price(data, "mist_wolf_pelt"). |
| WU-050 | world-ui | todo | Shop quantity-step keys through InputConfig (reviewer note on WU-038): src/ui/shop_screen.gd ~357-364 reads LB/RB and PgUp/PgDn (step the quantity by 10) as raw keys/buttons, so remapping doesn't reach them. Use `event.is_action_pressed("toggle_techniques")` / `("toggle_artifact")` (whatever InputConfig names LB/RB's actions; check input_config.gd) for the pad and Godot's built-in `ui_page_up` / `ui_page_down` for the keyboard, still consuming the event so the HUD doesn't open those screens behind the shop. The hint label (~125) builds its key names from `InputConfig.binding_label` instead of the literal "LB/RB or PgUp/PgDn". Test: an InputEventAction for the mapped action steps the quantity by 10 like the raw button did. |
| WU-046 | world-ui | todo | After CMB-003: hit sounds by blow weight. Add three procedural recipes to `Audio.RECIPES` (src/autoload/audio.gd): `hit_light` (short high noise tick), `hit` (mid thud), `hit_heavy` (low thud with noise, a bit longer); no assets. In src/ui/combat_report.gd `_reveal` (~139), pick the sound from the line: lines containing CMB-003's "crushing" word -> hit_heavy, "glancing" -> hit_light, other hit lines -> hit, the finishing line -> combat_win/combat_loss as today, other lines -> "press" as today. Put the blow words in consts in combat.gd if CMB-003 didn't (e.g. `Combat.BLOW_WORDS`) and read them from there rather than repeating string literals. Test: `_sound_for_line` (make it a static func) maps a crushing, a glancing and a plain hit line to the three names. |
| WU-047 | world-ui | todo | After CMB-003: combat report line colors. Render the log lines in src/ui/combat_report.gd with tones: your blows normal, blows that hit you `UIStyle` warning color, crushing blows (either way) the accent color, the finishing line larger/bold, talisman and ally lines dim-accent. Decide by the line's start ("You "/ foe name) and CMB-003's words; use a RichTextLabel with BBCode or one Label per line, whichever the report already uses for the reveal. Keep the reveal and Skip behaviour. Test: a won fight's report shows the finishing line with the large/bold style and an enemy hit line in the warning color (check the BBCode or the label's modulate). |
| C-024 | content | todo | Fair Foundation rank trials and the tournament ring (balance baseline): the Azure Cloud Sect's Foundation rank trial azure_pavilion_warden is 31% at entry and the Blood Lotus trial blood_pit_champion 23% (both forced); the `tournament_bout` encounter (data/encounters.json, min_realm qi_refining) throws a QR 1st Layer player into the ring against tournament_contender, a QR 6th Layer foe (0% at entry, 3% for the veteran on appearance), and the wounded-traveller `vengeful_brother` is 4% at entry. Like C-022: find each trial's real gate (sect rank requirements in data/sects.json, `Sects.check_promotion`) and measure there with tests/sim/simulate_combat.gd; trials -> 45-70% for the typical player at the gate (trial-only foes may be retuned; grep first). Tournament: add `min_stage` to the encounter (ENC-002) near the contender's stage, or lower the contender's stage so the typical player at the encounter's gate wins 40-60% (the Enter choice is optional, keep it a stretch). vengeful_brother: gate the encounter with `min_stage` so it is >= 40% at its gate. Paste before/after rows; commit the new baseline. |
| C-025 | content | todo spec | Uses for the unused beast materials (C-023 Follow-up: Mist Wolf Pelt, Stone Ape Hide, Cloud Eagle Talon, Blood-Eyed Wolf Fang and Jade Python Scale have no recipe). *Spec:* data/recipes.json, same shape as `boar_hide_jerkin` (line ~33): (1) blacksmith `wolf_pelt_cloak` (mist_wolf_pelt 3 + iron_essence 1, min_rank 0, armor grade 1, a little speed or hp; a new item in items.json); (2) blacksmith `stone_ape_bracers` (stone_ape_hide 2 + cold_iron 1, min_rank 1, armor grade 2); (3) blacksmith `eagle_talon_blade` (eagle_talon 2 + cold_iron 2, min_rank 2, weapon grade 2-3); (4) alchemist `wolf_fang_blood_pill` (blood_eyed_wolf_fang 1 + 2 of a Foundation herb, min_rank 2: a combat `buff` pill, attack +x% for some days, like the talisman buffs); (5) blacksmith `jade_scale_armor` (python_scale 3 + azure_crystal 1, min_rank 3, armor grade 3 for Core Formation). Look at existing grade 1-3 gear stats and prices in items.json and slot each new item between its neighbours (never better than the best buyable item of its grade by more than ~10%). Prices: output price below the sum of ingredient prices x ~2 (the crafted cap in `Items.sell_price` holds; run test_items/test_data_references). Recipes without `starter: true` need a scroll or rank unlock: check how other non-starter forge recipes are learned and follow the same pattern (or mark them starter like C-023 did). Names/descriptions in genre tone. Re-run `tools/balance.sh` and commit the baseline if it moved. Tests: data validation passes; the C-023 test that every beast_material has a reward source and a buyer stays green; add one assertion that every `beast_material` item is an ingredient of at least one recipe. |
| C-029 | content | todo spec | Quiet exploring days have texture (first-hour sim: 3.8 log lines a month; "You explore for 6 days and find nothing of note." is the commonest line). *Spec:* (1) data/regions.json: optional `quiet_lines: Array[String]` per region, 6-8 short present-tense scenes per region in genre tone that promise nothing and name no item/NPC/place that does not exist ("Mist pools in the hollows; somewhere a wolf calls and is answered."). Document it in the `_doc`; validate in `GameData._validate()` that it is an array of non-empty strings. (2) Small hook in src/core/systems/exploration.gd: `static func quiet_line(data: GameData, region_id: String, day: int) -> String` returns `quiet_lines[day % size]` (deterministic, **no rng draw**, so balance baselines don't move) or "". (3) GameState.explore_many (game_state.gd ~545) appends it: "You explore for 6 days and find nothing of note. <line>" when non-empty; `_explore_once`'s single-day "You search the area but find nothing." likewise. Tests in test_exploration.gd: quiet_line is stable for a day and differs across consecutive days for a region with >= 2 lines; "" for a region without; test_game_session: an explore_many with no encounters posts one line that ends with one of the region's quiet lines. `tools/balance.sh --check` unchanged except the first-hour line texts (paste). |
| C-028 | content | todo | Help pages for this week's features (data/help.json, same tone and length as the FH-022/C-013 pages): "Fights" (auto-resolved, techniques named in the log, the hp bars and Skip, "Animate fights" in Settings, spoils, why you lost advice, glancing/crushing blows once CMB-003 lands), "Selling loot" (which merchants buy what, `buy_tags`, the shop's Sell tab, Sell all loot and what it never sells: worn gear, manuals, breakthrough pills, readied talismans after RV-011), and a "Goals" paragraph on the Journal page (First goals, then Goals). Facts checked against the code/data; test_help_screen.gd stays green. |
| C-030 | content | todo | Milestones for the new life stats (STAT-002) and loot: in data/milestones.json add 3-4 `life_stat` milestones using existing keys only (check `LifeStats` KEYS): e.g. "Coin in the Purse" stones_earned 1,000, "Merchant's Eye" stones_earned 20,000, "Sea of Qi" qi_gathered 100,000, "Tireless Wanderer" encounters 50. Pick thresholds a typical player reaches in roughly year 1 / year 5 / year 10 (look at tests/sim/first_hour.gd output or the economy sim in docs/balance_baseline.txt and say what you based them on). Descriptions in the existing style. test_milestones / QA-026 tests stay green. |
| C-020 | content | todo | Help pages for systems that have none (audit C22; data/help.json has 0 mentions of taming, tempering, Dao, garden, inner world, bloodline, adoption): Spirit Beasts & taming, Body Tempering, Dao Insights, Creation Artifact functions (storage, appraisal, inner world, spirit garden), Clans & estates (founding requirements from data/family.json, buildings, heirs), Adoption & the orphanage. Same tone and length as the FH-022/C-013 pages, facts checked against the data files (numbers read from data, not invented). test_help_screen.gd stays green. |
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
| QA-037 | qa | todo spec | Combat text audit (CMB-002/003 put technique names and blow words in every log line). *Spec:* new tests/unit/test_combat_text.gd: for every enemy in `data.enemies`, build a typical player for the enemy's realm (reuse the typical/veteran builders in tests/sim/simulate_combat.gd if they are importable, else a CharacterData at the enemy's realm with Iron Fist + Stone Skin), run `Combat.resolve` with `seeded_rng()` 3 times (win and loss both occur for most foes), and assert for every log line: no `{`, `}`, `%d`, `%s`, no `_` inside a word (raw ids), no double spaces, starts with an upper-case letter, and that `trace.size() == log.size()`. Also run once with a readied strike talisman and once with an ally (if `allies` is easy to pass) to cover the opener lines. Fix wording bugs you find in combat.gd if they are one-liners; list anything bigger under Follow-ups. Keep the test under ~3 s. |
| QA-038 | qa | todo | Shop fuzz: for a mid-game character holding loot of every category (herbs, ores, beast materials, pills, a manual, a breakthrough pill, worn and spare equipment, readied talismans), open every merchant place in every region through the HUD's shop screen (as test_interactable_fuzz does for menus), switch Buy/Sell and every category tab, press Sell all twice, and check: no engine errors, stones gained == the total the button showed, nothing worn/manual/breakthrough pill (and readied talismans once RV-011 lands) was sold, the list and empty text are consistent, focus is on a row or the tab row after each step. Fix small bugs; list others under Follow-ups. |
| QA-021 | qa | todo spec | Realm gap past Core. *Spec:* QA-018 found a veteran at the Nascent Soul / Soul Formation peak beats a plain next-realm foe 20-28% (target: near 0%, owner decision QA-007), because data/enemies.json `realm_training` has entries only up to realm index 4 and the last one is reused. Add entries for realm indices 5..9 continuing the curve (each step roughly +3 attack/defense, +12 max_hp over the previous, or whatever keeps the per-realm same-stage win rate 60-100% for the veteran in tests/sim/simulate_combat.gd), re-run the sim, then tighten the guard in tests/unit/test_combat_balance.gd to "< 10% one realm up" for every realm through Soul Formation. Re-check that NS-001's Nascent Soul foes keep their table (paste it) since they use realm_training index 4. Paste before/after veteran tables and commit the new balance baseline. Also, if simple, exclude manuals with no obtainable source (`Items.sources`) from `veteran_player()`. |
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
