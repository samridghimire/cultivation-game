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
Next (planner 2026-10-09 04:15): spars/pointers surfaced, the lecture surfaced, seasonal herbs, first sight of a region,
the breakthrough effect, the spar report, the Deck pass, the corpse refiner fight and the Foundation-year sim landed (14
tasks). Now: reward curiosity about places (WU-061 unexplored map, GUIDE-014 roads you haven't taken, TRAV-005 + C-046 a
discovery on your first exploration of each region, TRAV-004 sect home regions, C-043 first-visit lines) and make the
seasons worth noticing (SEASON-002 "in season now" news and journal, WU-067/WU-071, C-044 seasonal herbs, SEASON-003
milestone). QA: why the first Foundation year is so gentle (QA-045, QA-039 Follow-up), a fresh balance baseline (QA-046),
and the three curious years (QA-041, claimed) to find the next dull stretch.
| id | role | status | task |
|---|---|---|---|
| GUIDE-014 | systems | todo spec | Roads you haven't taken (after TRAV-001; independent of WU-061). *Spec:* in src/core/systems/guidance.gd add `static func unexplored_routes(c: CharacterData, data: GameData, region_id: String) -> Array[Dictionary]`: the entries of `Exploration.routes(c, data, region_id)` with `ok == true` whose `to` is not `Exploration.visited(c, to)`, sorted by `days` then name. (1) `journal()` (~667): in Opportunities, one line per entry, max 2: "Unexplored: <Name> (<days> days' road)" with tone "normal"; skip when `region_id == ""`. (2) `hints()` (~23): in the "try something new" part (GUIDE-007), one hint "You have never been to <Name>; the road from here is open." for the first entry, only when the player has no other untried-feature hint queued ahead of it (it must never push out a newcomer hint; put it last) and only from day 10 of the game on (`today >= 10`, using the `today` param `hints()` already takes; `today == -1` means unknown, then skip). Routes blocked by `check_travel` (realm gates) never appear. Tests in tests/unit/test_guidance.gd (or wherever GUIDE-012's tests live): a fresh character in qingshi_village gets "Unexplored: Misty Forest" (or whichever routes are open at Mortal; read data/regions.json) and the hint at today=10 but not today=5; after `Exploration.visit(c, "misty_forest")` that line is gone; a realm-gated route (one with a min realm above the character) never shows; at most 2 journal lines. Extend the hint-honesty audit (QA-034's test) so the hint only appears when `Exploration.check_travel` is ok. |
| SEASON-002 | systems | todo spec | "In season now" (after SEASON-001). *Spec:* (1) src/core/systems/exploration.gd: `static func seasonal_highlights(data: GameData, season: String) -> Array[Dictionary]`: for each region in data.regions (in data order), each place with `type == "gather"`, each `gather_table` entry with a non-empty `seasons` containing `season` and a non-empty `item`: `{"item": id, "item_name": data.items[id].name, "place": place.display_name, "region": region_id, "region_name": name}`; dedupe on item+place. (2) GameState `_on_days_advanced` (game_state.gd ~2549): compute `Calendar.season_of(GameClock.total_days - days)` and `Calendar.season_of(GameClock.total_days)`; when they differ and highlights for the new season are non-empty, post one line with `EventBus.post(text, "info")` under topic "cultivation": "<Season capitalized> has come. In season now: <Herb> at <Place> (<Region>)" joining up to 3 highlights with "; " and ending with "." (prefer regions the player has visited, then data order). A long seclusion that crosses several seasons posts only the final season's line. (3) `Guidance.journal` Opportunities: up to 2 lines "In season: <Herb> at <Place> (<Region>)" for highlights of `Calendar.season_of(today)` in visited regions (skip when today < 0), tone "normal". Tests: highlights("spring") contains SEASON-001's Qingshi spirit_herb entry and highlights("autumn") does not; a 1-day advance across the spring/summer boundary posts exactly one "Summer has come" line only if summer highlights exist (build a test GameData if needed); no line when the season does not change; journal shows the spring line in spring for a player who visited qingshi_village and not in autumn. |
| TRAV-005 | systems | todo spec | A discovery on your first exploration of a region. *Spec:* optional `"discovery": "<encounter id>"` on a region in data/regions.json and optional `"discovery_only": true` on an encounter in data/encounters.json (document both in the `_doc`s). `GameData._validate_world`: the discovery id must exist in encounters; an encounter with `discovery_only` must be some region's discovery. `Exploration.eligible_encounters` (~120) skips `discovery_only` entries, so they never roll at random. New `static func discovery_for(c: CharacterData, data: GameData, region_id: String, flags: Dictionary) -> Dictionary` in exploration.gd: returns the region's discovery encounter dict when the region has one, `flags` lacks `"discovered_" + region_id`, and the encounter passes `realm_allows` and `alignment_allows`; else {}. In `GameState.explore` (~575), before `roll_encounter`, if `discovery_for(...)` is non-empty use it as the encounter (same resolve/choice path as a rolled one) and set `world_flags["discovered_" + region_id] = true`; `explore_many` stops on it like any event. Write one example: a Misty Forest `misty_forest_hollow_shrine` fortune encounter (an old herb-gatherer's shrine in a hollow tree: 2 spirit_herb and a little qi, text in genre voice, `discovery_only: true`) and set it as misty_forest's discovery. C-046 writes the rest. Tests in test_game_session.gd: the first explore in misty_forest yields the shrine and sets the flag; the second explore never yields it (over 50 seeded explores); the shrine never appears from `roll_encounter` in another region; a region without `discovery` explores as before; the validator rejects an unknown discovery id and an orphan `discovery_only` encounter; the flag survives save/load (world_flags already saved, assert it). |
| TRAV-004 | systems | todo | Sects have a home region (TRAV-003 Follow-up: sect halls are generic, so `backfill_visited` marks every region with a hall). Optional `"home_region": "<region id>"` on a sect in data/sects.json (document in `_doc`, validate the region exists). Set it for the three sects from their descriptions and the regions' places: azure_cloud_sect -> azure_peak, blood_lotus_sect -> withered_bone_marsh, myriad_treasure_pavilion -> fallen_star_market (check each region's description first; if one clearly fits better, use it and say so in the commit). `Exploration.backfill_visited` visits the player's sect's `home_region` instead of every region with a sect hall when it is set (keep the hall fallback when it isn't). Add `static func home_region(data: GameData, sect_id: String) -> String` to Sects for WU-061/UI use. Tests: a save without `visited_regions` in the Azure Cloud Sect loads with azure_peak visited and not fallen_star_market (unless start/abode/anchor puts it there); the validator rejects an unknown home_region. |
| SEASON-003 | systems | todo | Herbalist of Four Seasons (after SEASON-001). New `CharacterData.seasonal_gathers: Array[String]` (seasons in which the player gathered a season-only entry; to_dict/from_dict with default []). In `GameState.gather` (~839) when the rolled entry had a non-empty `seasons`, append the current season if missing (have `Exploration.gather` return the chosen entry's `seasons`, or compare against `Exploration.in_season`; pick the smaller change). New LifeStats key `seasons_gathered` synced from the list's size (like regions_visited, life_stats.gd ~97) and a milestone in data/milestones.json `{"id": "four_seasons_herbalist", "name": "Herbalist of Four Seasons", "description": "Gather a herb that grows in only one season, in each of the four seasons.", "check": {"type": "life_stat", "stat": "seasons_gathered", "min": 4}}`. Tests: gathering Qingshi's spring entry in spring records "spring" once (twice gathered still one); a normal entry records nothing; old saves load with []; milestone at 4. |
| ITEM-002 | systems | todo | Can this item really be had? (QA-043 Follow-up: `Items.sources()` always falls back to "Found exploring", so it can't say an item is unobtainable.) Add `static func has_known_source(data: GameData, item_id: String) -> bool` in src/core/systems/items.gd: true when any merchant stocks it, a recipe makes it, a gather table/enemy reward/encounter or choice effect/mission/inheritance/secret realm/errand or favor reward/auction lot gives it. Refactor `sources` so both use the same scan and only `sources` appends the fallback. If tests/sim/combat_balance.gd `veteran_player()` (QA-043) hand-rolled its own check, switch it to this. Tests: a gathered herb, a crafted pill and a merchant item are true; an item added to a test GameData with no source is false; a test lists every technique manual and breakthrough pill without a known source (if any exist today, keep them in an explicit known list in the test and name them under Follow-ups). |
| REALM-002 | systems | todo | Secret realm entry can need an item (C-035 Follow-up: the rogue's map only flavours the rift). Optional `"entry_item": "<item id>"` and `"consume_entry_item": bool` on a secret realm in data/secret_realms.json (document in `_doc`, validate the item exists). `SecretRealms.check_enter` returns "You need <item name> to find the way in." without it; entering consumes it when flagged. Journal Opportunities says "(needs <item>)" for such realms. No content change beyond the docs; C-035's author can wire the map later. Tests: refused without, allowed with, consumed once when flagged, kept when not. |
| WU-064 | world-ui | todo spec | The arrival card marks a first visit (after TRAV-002). *Spec:* in src/ui/hud.gd `_on_arrival` (~663), when `GameState.last_arrival_first_visit` is true the banner subtitle starts with "First visit · " before "Qi xN · Danger: X" and the hold time is 1.5x `Banner.HOLD_SECONDS` (`announce` takes `hold`); otherwise unchanged. If the region has a `first_visit` line it is already in the log (TRAV-002); don't repeat it on the card. Tests: with the flag set the subtitle starts with "First visit"; after a second trip it does not; the respawn guard (no card while the respawn screen is up) still holds. |
| WU-061 | world-ui | todo spec | World map shows where you have been (TRAV-001 landed). *Spec:* in the world map screen (src/ui/, find the screen WU-030/UI-008b draw region nodes and the "current region foes" list in), regions where `not Exploration.visited(GameState.player, id)` draw their node at ~45% alpha with "Unexplored" (dim, smaller font) under the name, and show no foes list and no marks (sect, abode, events, secret realms) except a travel route line; the current region is always visited. Travel options (the travel place's `get_options()` in src/world/) to an unvisited region add "(never visited)" to their description line (WU-027 `description`). Tests: a fresh character's map marks every region but the start as unexplored (find the node/label by name); after `GameState.travel` to misty_forest it is not; the travel option to an unvisited region has "(never visited)" in its description and not after visiting. Run tests/sim/screenshot_screens.gd on the map and look at it; say in the commit whether the dim regions stay legible. |
| WU-068 | world-ui | todo spec | ChoiceMenu refits when the window or UI scale changes (reviewer note on WU-065). *Spec:* src/ui/choice_menu.gd `_fit_scroll` (~90) only runs on `_rebuild`. In `_ready` connect `get_viewport().size_changed` to `_fit_scroll` (deferred), and if Settings emits a UI-scale change signal (check src/autoload or src/ui/settings_screen.gd for how UI scale is applied), connect that too; disconnect nothing (the menu lives with the HUD). Test (tests/unit, like WU-065's): open a menu with many options, shrink the viewport size (`get_tree().root.size` or `get_viewport().size`), await two frames, and assert the scroll's `custom_minimum_size.y` dropped to the new room (viewport height - MENU_MARGIN, min 160); growing it back restores it. |
| WU-067 | world-ui | todo spec | Gather sites name their seasonal herbs (SEASON-001 landed). *Spec:* in the gather place's `get_options()`/description (src/world/, the interactable for `type == "gather"`), append "In season: <Herb>[, <Herb>]" for entries of its `gather_table` with a `seasons` list containing `Calendar.season_of(GameClock.total_days)` and "Out of season: <Herb> (<season>)" for other seasonal entries, using `Exploration.in_season(entry, season)` (exploration.gd ~325). If no core helper lists them, add `static func seasonal_entries(table: Array, season: String) -> Dictionary` (`{"in": [item ids], "out": [[item id, first season]]}`, deduped) to exploration.gd with a unit test. Tests: Qingshi's Village Herb Slope reads "In season: Spirit Herb" in spring and "Out of season: Spirit Herb (spring)" in autumn; the Misty Forest Herb Patch (no seasonal entries) adds nothing. |
| WU-069 | world-ui | todo | Look at the new effects (WU-063 Follow-up: no frame was captured). Add captures to tests/sim/screenshot_screens.gd (or screenshot_regions.gd if only it renders the world): the player mid-way (0.5 s) through `celebrate(true)` and `celebrate(false)`, and the arrival card after a first visit (once WU-064 lands; skip that capture if it hasn't). Look at them at 1280x800: the gold ring must not hide the player or NPC name labels for long, the failure shake must read as a stumble. Tune sizes/alpha in src/world/player.gd if needed and list the changes (or "no change needed") in the commit. Don't commit PNGs. |
| WU-070 | world-ui | todo | Discoveries look special (after TRAV-005). When `GameState.explore` used a region's discovery (TRAV-005; expose it as `GameState.last_explore_discovery: bool`, set per explore, if TRAV-005 didn't), the encounter/choice window's title reads "Discovery: <encounter name>" with UIStyle.ACCENT, a short chime from the Audio autoload (reuse an existing positive cue), and the explore result line in the log starts "A discovery: ". Tests: the first Misty Forest explore opens the window with the "Discovery:" title; a normal encounter's title is unchanged. |
| WU-071 | world-ui | todo | Season line with what's in season (after SEASON-002). The HUD date line (hud.gd ~404 "<date> · <season>") adds " (N days left)" when N <= 10 days remain in the season (use Calendar; add `static func days_left_in_season(total_days: int) -> int` in src/core/calendar.gd with a unit test if missing). The WU-062 season banner's subtitle names up to 2 in-season herbs from `Exploration.seasonal_highlights` ("In season: Spirit Herb at Village Herb Slope") when there are any. Tests: the date line text near a season's end and not mid-season; the banner subtitle with and without highlights. |
| C-043 | content | todo spec | First-visit lines for the other regions (TRAV-002 landed; Misty Forest's line is the model). *Spec:* add `"first_visit"` in data/regions.json for qingshi_village, fallen_star_market, azure_peak, withered_bone_marsh and myriad_peaks_ridge: 1-3 sentences, second person, present tense, genre voice, no game numbers or UI words, true to the region's `description` and places, each hinting at one thing to do there (Qingshi: the elder and the herb slope; Fallen Star: the market stalls and the auction; Azure Peak: the sect on the clouds and the herb terraces; the marsh: danger and corpse-refiners; the ridge: realm-old beasts and the high meditation spots). Note: qingshi_village is the start region, so its line is only seen by a character who starts elsewhere or by TRAV-002's rules; check `GameState` new-game code and say in the commit whether it is ever shown (if never, still write it for future starts). Test: a data test (test_data or the TRAV-002 validator test) that every region has a non-empty `first_visit`. |
| C-044 | content | todo spec | Seasonal herbs (SEASON-001 landed: `"seasons": [...]` on gather-table entries and encounters). *Spec:* one richer season-only gather entry per season where it fits: summer in Misty Forest's Herb Patch, autumn in Withered Bone Marsh's gather site, winter on Azure Peak (one of its three gather sites) or Myriad Peaks Ridge; reuse existing herbs (e.g. qi_condensing_grass, purple_cloud_mushroom, a marsh herb) at 2-3x their normal weight or a higher `max`, or add at most two new herbs in data/items.json that have a real use (a recipe in data/recipes.json and a merchant whose `buy_tags` takes them). Add two season-only encounters in data/encounters.json (a winter snow-lotus fortune on the mountain tags and one spring or summer one), each with `"seasons"`. Add a line to the seasons help page (data/help*.json, C-041) saying some herbs and fortunes come only in one season. Run tools/balance.sh's economy section before and after and paste gather income per region-month; it must stay in RV-009's range (no region-season more than ~1.3x today's best). |
| NS-007 | content | todo | Realm-appropriate fights for NS-005's three Soul Formation inheritance grounds (NS-006 landed): the combat baseline rates their trial foes (ancient_puppet_guardian, azure_law_enforcer, soul_reaping_old_monster) TRIVIAL (100% at entry). Point their fight stages (data/inheritances.json) at NS-006's soul_formation enemies where the theme fits (heavenly_mandate_elder for the righteous one, ghost_banner_lord for the demonic one, a construct for the puppet) or add three guardian enemies at soul_formation stage 0-1, `lethal: false`, and check with tests/sim/simulate_combat.gd that a Soul Formation veteran wins 50-90% (paste the rows). Refresh the baseline with tools/balance.sh. |
| C-046 | content | todo | Discoveries for every region (after TRAV-005): one `discovery_only` encounter per region that has none (Qingshi Village, Fallen Star Market, Azure Peak, Withered Bone Marsh, Myriad Peaks Ridge) and set each region's `discovery`. Each is a small fortune or a choice (no forced lethal fight), true to the region, rewarding curiosity with something useful at that region's realm (a herb or material, a little qi, a recipe scroll, a hint flag for a later encounter); keep stone rewards modest (<= one week of that region's gather income). Use `min_realm` only if the region itself is realm-gated. Tests come from TRAV-005's validator; add a data test that every region has a discovery. |
| C-018 | content | todo | Two Soul Formation people (NS-004 Follow-up; NS-006 landed) in data/npcs.json + dialogue files, like NS-004 (one righteous, one demonic), each with a favor reward and an errand for a Soul Formation herb or material that NS-006/NS-002 makes obtainable (check `Items.sources`); and Ye Zhuoran (NS-004) mentions the flawless Soul Infant pill (NS-002b) in one dialogue line. Place them in Myriad Peaks Ridge clear of places and HUD panels (WU-017/WU-023 tests). Errand turn-ins covered by test_npc_errand_turn_ins. |
| C-045 | content | todo | Gear past Core Formation (NS-006 Follow-up: the best non-demonic gear is grade 4, so the sim's typical player fights Nascent Soul and Soul Formation foes in Core gear; tests/sim/combat_balance.gd `best_gear` allows grade <= realm_index + 1). Add a grade-5 weapon and armor (Nascent Soul) and a grade-6 weapon and armor (Soul Formation) to data/items.json (righteous or neutral; stats on the curve: grade 4 is attack 40 / defense 25 + max_hp 170, the demonic grade-5 banner is attack 85 with a lifespan cost; aim ~60 / 35 + 240 for grade 5 and ~85 / 48 + 330 for grade 6), Blacksmith recipes for them in data/recipes.json using NS-002/NS-006 materials, recipe scrolls as rewards of NS-006 enemies or a Myriad Peaks Ridge merchant at a steep price. Then run simulate_combat.gd: the NS-001/NS-006 foes' entry rates will rise; keep the "same curve" (entry 10-75%, peak 75-100%) by retuning enemies if needed, paste before/after rows, refresh the baseline. |

## P1: Steam release basics
| id | role | status | task |
|---|---|---|---|

## P2: After Core Formation (content runs out)
Late content keeps going in parallel (NS-007, C-018, C-045 sit in the P0 table for now). Pacing itself stays the owner's call (F-005d).
| id | role | status | task |
|---|---|---|---|

## P4: QA and tooling
| id | role | status | task |
|---|---|---|---|
| QA-041 | qa | todo spec | Three curious years (QA-029 Follow-up: the curious player does only ~2.3 kinds of action a month). *Spec:* in tests/sim/first_hour.gd (curious policy) add a `--months=N` option (default 12) and run 36 months for seeds 1-10. Per seed and per 6-month block print: distinct action kinds, the first month each feature was first used (sect mission, crafting, profession work, secret realm, gift/chat, breakthrough attempt, commission, and pointers/spar/sect lecture when the curious policy can use them), stones held, realm label; then medians. Flag every block where the median distinct kinds is <= 2 or no new feature was used, and list in Follow-ups the 3 longest "nothing new" stretches with what the player was doing (meditating? exploring?) and the likely cause (gate too high, money short, no hint). Add the 36-month run to tools/balance.sh as its own section and commit the baseline. No data or code fixes in this task (the planner files them). Keep it under ~90 s. |
| QA-045 | qa | todo spec | Why is the first Foundation year so gentle? (QA-039 Follow-up: 107/120 runs spent no artifact life, median win share 100%, 0 injuries; DESIGN.md's QA-007 target is ~60-85% against a foe of your own realm and stage.) *Spec:* extend the QA-039 sim (tests/sim/simulate_foundation_year.gd or wherever it landed) with `--threats=slip|fight` (default slip, today's behaviour). For seeds 1-10 and both policies print per region: encounters met, fights fought, fights evaded via sensed threats, the median stage reached by month 3/6/12, and a histogram of the rated odds (Combat sim helper the combat baseline uses) of every fight actually fought (<50%, 50-75%, 75-95%, >95%). Answer in the commit body, with numbers: (a) are fights rare or just easy? (b) do C-031's stage gates leave only foes the player has already outgrown by the time they appear? (c) does the player outgrow the region within months (stage climbs fast)? List under Follow-ups the 3 data changes you would make (enemy ids or gate stages), without making them. Add the `fight` run as its own tools/balance.sh section and refresh only that section. Keep it under ~60 s. |
| QA-046 | qa | todo | Refresh the drifted balance baseline (QA-039 Follow-up: `tools/balance.sh --check` shows sections of docs/balance_baseline.txt out of date). Run tools/balance.sh, and for each section that changed, name the commit(s) that changed it (`git log -- data/<file>` since the baseline's last update) and whether the change was intended (a retune in that task's commit message) or a surprise. Commit the refreshed baseline; any surprise goes under Follow-ups with the section, the numbers before/after and the suspected commit. If `--check` is not run by tools/test.sh and takes < 20 s, say whether it should be. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates). *Spec:* reuse QA-039's sim with the realm as an argument (`--realm=core_formation`): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each region whose encounters include Core Formation fights (Myriad Peaks Ridge and any other; list them from data), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent (tribulation not included) and medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. If QA-045 has landed, include its `--threats` switch and odds histogram. |
| QA-044 | qa | todo | Do pointers and spars matter? (after QA-041; GUIDE-012 landed): in tests/sim/first_hour.gd add a curious-policy switch that never uses pointers/spars, run 12 months for seeds 1-10 with and without, and print median technique levels and fights won at months 6 and 12. Under Follow-ups say whether pointers/spars meaningfully speed the first year (or are too strong: more than ~2 extra technique levels by month 12), with numbers. No data changes. |
| QA-047 | qa | todo | First sights survive save/load (after TRAV-005; TRAV-002/003 landed). A test (test_game_session.gd or a new test_first_visits.gd) that: starts a new game, travels to misty_forest (first_visit line posted, `last_arrival_first_visit` true), saves to a dict and loads it, explores once (the TRAV-005 discovery fires once), saves and loads again, travels away and back (no first_visit line, no discovery), and loads a pre-TRAV-001 fixture save from tests/fixtures/saves/ to check `backfill_visited` marked its start/abode regions and that travelling to an unvisited one still posts its first_visit line. Fix any bug you find in the same commit, or name it under Follow-ups if it is large. |
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
| GUIDE-012 | systems | Pointers and spars in hints, the untried list and journal Opportunities. |
| WU-060 | world-ui | Season tint check: 6 regions x 4 seasons captured, no change needed. |
| RV-014 | systems | Friendly spars burn no talismans and drain no lifespan; pointers "share" only with a better teacher. |
| C-042 | content | Fight the corpse refiner's puppets in the marsh captive encounter (69% at entry). |
| C-038 | content | Bai Qingwu (Azure Peak) and Shen Wuya (Fallen Star Market) with errands. |
| WU-066 | world-ui | Spar report titled "Friendly spar", no loss advice or spoils. |
| GUIDE-013 | systems | Lecture in journal and hints, `lectures_attended`, Attentive Disciple milestone. |
| WU-065 | world-ui | Deck pass on the newest menus; ChoiceMenu button list scrolls. |
| QA-039 | qa | First Foundation year sim and guard (107/120 runs spend no life). |
| SEASON-001 | systems | Seasonal gather entries and encounters (`seasons`), season-aware exploration. |
| NS-006 | content | Soul Formation pack: 6 enemies, 10 encounters. |
| TRAV-002 | systems | `first_visit` region text, `last_arrival_first_visit`; Misty Forest written. |
| WU-063 | world-ui | Breakthrough effect: gold ring and rays, or a red ring and a stumble. |
| TRAV-003 | systems | `Exploration.backfill_visited` for saves without visited regions. |
| QA-040 | qa | Pointers and spar audit: cooldowns across save/load, dead NPCs, favor caps, no stones/injury on a spar loss. | |
| WU-059 | world-ui | NPC menu: "Ask <name> for pointers" and "Spar with <name>", refusals as disabled reasons. | |
| TRAV-001 | systems | `visited_regions`, `Exploration.visit/visited`, regions_visited stat, Far Traveller milestone. | |
| C-037 | content | Five Foundation choice encounters (righteous / demonic / walk away). | |
| C-041 | content | Help pages for the lecture, seasons, stage-gated ranks and "New" notices. | |
| QA-043 | qa | Veteran in the combat sim only uses obtainable technique manuals; ratings unchanged. | |
| WU-062 | world-ui | Season-change banner and chime. | |
| SPAR-001 | systems | Friendly spars (no stones, no injury, technique practice, favor on a win). | |
| MENTOR-001 | systems | Pointers from a senior NPC (`data/family.json` mentorship, `npc_action_days`). | |
| C-040 | content | Azure Cloud Elder and Pavilion Senior Steward ranks need Middle Stage; trials 65-68% at the gate. | |
| RV-013 | systems | Year reviews name the year that ended; bottleneck lecture line; `Scenery.AMBIENT_KINDS`. | |
| WU-054 | world-ui | "sells for N each" on stacked spoils; shop quantity hint refreshes. | |
| WU-045 | world-ui | Inventory says which merchants buy loot and what it is used in. | |
| C-039 | content | Three Foundation stage-0 foes in the starter regions (69-72% at entry). | |
| WU-044 | world-ui | The current goal on the HUD. | |
| QA-021 | qa | `realm_training` for realms 5-9; veteran one realm up < 10% through Soul Formation. |
| QA-029 | qa | Curious-player first-hour sim (`first_hour.gd` curious policy, baseline section). |
| SECT-004 | systems | Sect ranks can need a stage (`min_stage`, validated); no rank uses it yet. |
| SECT-005 | systems | The elder's monthly lecture at the sect hall (qi, Dao insight chance). |
| WU-056 | world-ui | Seasons you can see (`Calendar.season_of` / `season_tint`). |
| C-031 | content | 17 Foundation/Core exploration fights gated by stage; baseline refreshed. |
| QA-038 | qa | Shop fuzz: every merchant, tab, category and Sell all; no bugs found. |
| RV-012 | systems | `Sects.needs_trial` / `rank_requirement_reason`; no string matching in goals. |
| GUIDE-011 | systems | "New" notices for what a breakthrough or rank opens (roads, secret realms, clan, promotion). |
| WU-057 | world-ui | Ambient particles by region and season (`map.ambient`, Settings toggle). |
| WU-058 | world-ui | NPCs idle-bob and wander a little. |
| KARMA-001 | systems | Hostile-act sentences from data/karma.json. |
| C-035 | content | Sect-region choice encounters for Qi Refining newcomers. |
| C-020 | content | Help pages for beasts, tempering, Dao, artifact powers, clans and adoption. |
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
