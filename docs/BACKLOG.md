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
| RV-014 | systems | todo spec | Reviewer notes on SPAR-001 / MENTOR-001 (docs/REVIEW.md 2026-10-09). *Spec:* (1) A friendly spar is free. In `Combat.resolve` (src/core/systems/combat.gd ~160-171 shield/strike openers, ~216 escape talismans) skip readied combat talismans when `enemy.get("friendly", false)`, so `talismans_used` stays empty and `apply_outcome` burns nothing. In `GameState.fight_enemy` (game_state.gd ~2163) `drained` is 0 when `enemy.get("friendly", false)`: an evil weapon does not drink lifespan in a spar. Sect promotion trials (`spar` but not `friendly`) keep today's behaviour. (2) Pointers only count as "shared" when the senior knows the technique better: add `static func knows_better(c: CharacterData, npc: CharacterData, tech_id: String) -> bool` to src/core/systems/mentorship.gd (`Techniques.knows(npc, tech_id) and Techniques.level(npc, tech_id) > Techniques.level(c, tech_id)`) and use it for `shared` in both `pointer_technique` (~26) and `give_pointers` (~79). Tests next to the existing SPAR-001/MENTOR-001 tests: a spar with a readied strike and a readied shield talisman keeps both (count and readied state unchanged) and its log has no "You burn"/"You hurl" line; a spar wielding an item with `equip.lifespan_drain` leaves `Cultivation.years_left` unchanged (a real fight with it still drains); a promotion trial still burns a readied talisman; a senior who knows the technique at a level <= the player's gives `shared == false` and the normal practice days. |

## P0: Playable and fun (the first hours)
Next (planner 2026-10-09 10:10): pointers, spars, visited regions, the season banner, fair first Foundation fights and
late trials landed (14 tasks). Now: reviewer notes on spars/pointers (RV-014), surfacing pointers and the lecture
(GUIDE-012/013), a first sight of each new region (TRAV-002/003, WU-064, C-043) and the unexplored map (WU-061),
seasonal herbs (SEASON-001, WU-067, C-044), a breakthrough you can see (WU-063), the spar report (WU-066), a Deck
pass on the newest menus (WU-065), a fight for the corpse refiner choice (C-042), and the three-year curious sim
(QA-041, QA-044) to find the next dull stretch.
| id | role | status | task |
|---|---|---|---|
| GUIDE-012 | systems | todo | After MENTOR-001/SPAR-001: surface them. In `Guidance` hints (the newcomer/try-something list, see GUIDE-007 "Try something new"), add "<Name> (<realm>) here could point out flaws in your <Tech>." when an NPC in the current region (`Npcs.in_region`) passes `Mentorship.check_pointers`, at most one such hint, preferring the highest favor; and a journal Opportunities line per region NPC that passes it ("Ask <Name> for pointers (<region>)"), max 3. A "Never sparred" entry in GUIDE-007's untried list when some NPC here passes `check_spar` and the player has never sparred (no `spar:` key in `npc_action_days`). Hint honesty: extend QA-034's hint audit (test_hint_honesty or similar) so each new hint is only shown when the action would succeed. |
| GUIDE-013 | systems | todo spec | Surface the elder's lecture (SECT-005 has no hint, journal line or record). When `Sects.check_lecture(c, data, total_days) == ""`: a journal Opportunities line "Attend <lecture name> at the <sect> hall (once a month)" and, for disciples who have not attended this month, one HUD hint "Your sect's elder lectures this month; attend at the sect hall." (honest: only when the check passes). New LifeStats key `lectures_attended` (+1 in `Sects.attend_lecture` or GameState.attend_lecture) shown in the sheet's life record if that list is data-driven, and a milestone `{"id": "attentive_disciple", "name": "Attentive Disciple", "description": "Attend 12 sect lectures.", "check": {"type": "life_stat", "stat": "lectures_attended", "min": 12}}`. Tests: journal/hint appear only when attendable, vanish after attending; the stat counts; milestone at 12. |
| SEASON-001 | systems | todo spec | Seasonal herbs and encounters (after WU-056's `Calendar.season_of`). Optional `"seasons": ["spring", ...]` on region gather-table entries and on encounters (data/regions.json, data/encounters.json; document in both `_doc`s; validate the names against the four seasons `Calendar.season_of` returns). `Exploration.gather_table_for` and `eligible_encounters`/`outlook`/`roll_encounter` take an optional `season: String = ""` ("" = ignore, so existing callers and sims keep working) and skip out-of-season entries; GameState passes `Calendar.season_of(GameClock.total_days)`. `Items.sources` notes "(spring)" etc. for seasonal sources if it lists gather sources. No content changes here beyond one example: give one existing common herb entry in Qingshi Village a second, richer spring-only entry. Tests: an out-of-season entry never rolls over 200 seeded rolls, an in-season one can; validator rejects "monsoon"; "" season keeps today's tables. |
| TRAV-002 | systems | todo spec | First sight of a new region. *Spec:* optional `"first_visit": "<1-3 sentences>"` on a region in data/regions.json (document it in `_doc`; `GameData._validate_world` rejects a non-String or empty value). In `GameState.travel` (game_state.gd ~504) keep the bool returned by `Exploration.visit(player, region_id)` in a new `var last_arrival_first_visit: bool = false` (set before `region_changed` is emitted; reset to false on new game and load, and on a respawn that moves you). When it is true and the region has `first_visit`, post that text with `EventBus.post(text, "info")` right after the "you arrive at" line. Write the `first_visit` line for Misty Forest only (C-043 writes the rest). Tests in test_game_session.gd: the first travel to misty_forest posts the line and sets the flag; travelling away and back does not post it again and the flag is false; a region without the field posts nothing extra; the validator rejects `"first_visit": ""`. |
| TRAV-003 | systems | todo | Older saves remember more places (TRAV-001 only backfills the current region, so once WU-061 lands a veteran's map calls their own sect and abode "Unexplored"). Add `static func backfill_visited(c: CharacterData, data: GameData, npcs: Dictionary) -> void` to src/core/systems/exploration.gd that visits `data.start_region`, the region of the player's abode (`c.abode`, abodes are listed per region in regions.json), the region whose places include the sect hall of `c.sect`, every region holding one of the player's bound anchors, and the regions where living spouses/children live (if NPCs store a region). Call it from `GameState.from_save_dict` (~2428) instead of the single `Exploration.visit` when `visited_regions` is empty. Test: a save dict without `visited_regions`, with an abode in misty_forest and a sect, loads with start, abode and sect regions visited; a save that has a list is left untouched. |
| REALM-002 | systems | todo | Secret realm entry can need an item (C-035 Follow-up: the rogue's map only flavours the rift). Optional `"entry_item": "<item id>"` and `"consume_entry_item": bool` on a secret realm in data/secret_realms.json (document in `_doc`, validate the item exists). `SecretRealms.check_enter` returns "You need <item name> to find the way in." without it; entering consumes it when flagged. Journal Opportunities says "(needs <item>)" for such realms. No content change beyond the docs; C-035's author can wire the map later. Tests: refused without, allowed with, consumed once when flagged, kept when not. |
| ITEM-002 | systems | todo | Can this item really be had? (QA-043 Follow-up: `Items.sources()` always falls back to "Found exploring", so it can't say an item is unobtainable.) Add `static func has_known_source(data: GameData, item_id: String) -> bool` in src/core/systems/items.gd: true when any merchant stocks it, a recipe makes it, a gather table/enemy reward/encounter or choice effect/mission/inheritance/secret realm/errand or favor reward/auction lot gives it. Refactor `sources` so both use the same scan and only `sources` appends the fallback. If tests/sim/combat_balance.gd `veteran_player()` (QA-043) hand-rolled its own check, switch it to this. Tests: a gathered herb, a crafted pill and a merchant item are true; an item added to a test GameData with no source is false; a test lists every technique manual and breakthrough pill without a known source (if any exist today, keep them in an explicit known list in the test and name them under Follow-ups). |
| WU-063 | world-ui | todo spec | A breakthrough you can see. *Spec:* in src/world/player.gd add `func celebrate(success: bool) -> void`, connected in `_ready` to `EventBus.breakthrough_attempted(success, realm_name)` (the signal hud.gd `_on_breakthrough` uses). It starts a 1.6 s effect drawn in `_draw()` (placeholder art, no assets): on success an expanding gold ring (UIStyle.ACCENT) from radius 8 to 90 px that fades out, 16 short rays turning outward, and the aura (`_draw_aura`, ~134) drawn brighter for the duration; on failure a dull red ring that contracts and a 0.3 s sideways shake of the body drawing (offset the drawn sprite only, never `position`, so collisions and the camera are untouched). If it fires during the time-skip overlay it simply plays under it. Tests (tests/unit, like the WU-058 idle-NPC tests): `celebrate(true)` starts the effect and it is over after 1.6 s of `_process` steps; `celebrate(false)` never changes `position`; a second call restarts the timer. Capture one frame with the screenshot tooling if it can render the world and say in the commit whether you looked. |
| WU-064 | world-ui | todo spec | The arrival card marks a first visit (after TRAV-002). *Spec:* in src/ui/hud.gd `_on_arrival` (~663), when `GameState.last_arrival_first_visit` is true the banner subtitle starts with "First visit · " before "Qi xN · Danger: X" and the hold time is 1.5x `Banner.HOLD_SECONDS` (`announce` takes `hold`); otherwise unchanged. If the region has a `first_visit` line it is already in the log (TRAV-002); don't repeat it on the card. Tests: with the flag set the subtitle starts with "First visit"; after a second trip it does not; the respawn guard (no card while the respawn screen is up) still holds. |
| WU-060 | world-ui | todo spec | Season tint check (WU-056 Follow-up: no screenshot check was done). Extend tests/sim/screenshot_regions.gd with a `--season=<name>` (or loop all four) option that sets the clock to the middle of that season before capturing, capture every region in all four seasons, and look at them: text and NPC labels must stay readable, winter must not wash out pale place art, autumn must not muddy the marsh. Tune `Calendar.season_tint` (calendar.gd ~37) and the ambient particle amount per season if anything reads badly. List what you changed (or "no change needed") in the commit with the screenshot paths. Don't commit the PNGs. |
| WU-061 | world-ui | todo | World map shows where you have been (after TRAV-001): regions not in `visited_regions` draw dimmer with "Unexplored" under the name and no foes/marks list (the current region is always visited); visited ones look as today. Travel options to an unvisited region add "(never visited)" to their description. Tests: a fresh character's map marks every region but the start as unexplored; after travelling, that region is not. |
| WU-066 | world-ui | todo | The spar report reads like a spar. Add `var last_fight_friendly: bool` to GameState, set in `fight_enemy` from `enemy.get("friendly", false)`. When it is set, the combat report (src/ui/combat_report.gd `show_fight` / title) reads "Friendly spar: <name>", the loss advice line is replaced by "No harm done. You can spar again in N days." (N from `data.family.mentorship.spar.cooldown_days` or whatever key SPAR-001 uses) and the spoils line is hidden. Tests: a friendly loss shows "Friendly spar" and no loss advice; a real loss is unchanged. |
| WU-065 | world-ui | todo | Deck-size pass for the newest menus (after GUIDE-012): at 1280x800 and UI scale 115%, capture with tests/sim/screenshot_screens.gd the NPC menu of a senior NPC with pointer and spar entries (use a long technique name), the sect hall menu with the lecture entry, the journal with a full Opportunities section (pointers, lecture, secret realm) and the combat report after a spar. Fix any clipping or overflow (wrap or ellipsize labels; the disabled-reason line must stay readable), add these captures to the script's list, and list what you changed (or "no change needed") in the commit. Don't commit PNGs. |
| WU-067 | world-ui | todo | Gather sites name their seasonal herbs (after SEASON-001): the gather place's menu description adds "In season: <herb>" for in-season seasonal entries and "Out of season: <herb> (<season>)" for the others. Use the core helper SEASON-001 adds, or add `Exploration.seasonal_entries(table: Array, season: String) -> Dictionary` (in/out lists) in core if it didn't. Tests: Qingshi's spring entry reads "In season" in spring and "(spring)" in autumn; a table with no seasonal entries adds nothing. |
| C-042 | content | todo spec | Fight the corpse refiner (C-037 Follow-up). *Spec:* in data/encounters.json `marsh_corpse_refiner_captive` add a choice before "Slip away": "Smash the refiner's puppets and free her", `"enemy": "corpse_refiner_puppets"`, and `set_flag met_marsh_captive`. First check how an `enemy` on a choice handles its effects (see `city_red_door` "Kick the door in" and the choice code in Exploration/GameState): if effects apply whether you win or lose, keep only alignment +10 and the flag on the choice and put the loot in the enemy's rewards. New enemy `corpse_refiner_puppets` in data/enemies.json (compare `drowned_venom_husk`, ~line 42): name "Corpse Puppet Trio", foundation_establishment stage 0, `lethal: false`, tags ["undead"], rewards qi ~2500, spirit_stone 60, recipe_jade_marrow_pill 1, alignment 15. Tune with tests/sim/simulate_combat.gd so the typical player at Foundation 1st Layer wins 55-75% (paste the row in the commit) and refresh the baseline with tools/balance.sh. If the sim does not rate choice enemies, say so under Follow-ups. |
| C-038 | content | todo | Two mid-game people for the sect regions (like C-011/NS-004): one righteous Foundation Establishment NPC at Azure Peak and one shady Core Formation broker at Fallen Star Market in data/npcs.json with dialogue files in data/dialogue/, each with a favor reward and an `errands` entry (GUIDE-003) asking for something a Foundation player can gather or craft (check `Items.sources`, e.g. a beast material from C-023/C-025 or a Foundation herb). Favor rewards sized like C-011's. Placement must keep clear of places and HUD panels (WU-017/WU-023 tests). Errand turn-ins covered by test_npc_errand_turn_ins. |
| C-043 | content | todo | First-visit lines for the other regions (after TRAV-002): a `first_visit` text in data/regions.json (1-3 sentences, second person, present tense, genre voice, no game numbers) for Qingshi Village, Fallen Star Market, Azure Peak, Withered Bone Marsh and Myriad Peaks Ridge, true to each region's `description` and places, each hinting at one thing to do there (a sect gate, a market, a danger). |
| C-044 | content | todo | Seasonal herbs (after SEASON-001): one richer gather entry per season in a region that fits (spring in Qingshi Village is SEASON-001's example; summer in Misty Forest, autumn in Withered Bone Marsh, winter on Azure Peak or Myriad Peaks Ridge), reusing existing herbs where they fit or at most two new herbs in data/items.json that have a real use (a recipe, and a merchant whose `buy_tags` takes them). Optionally two season-only encounters (e.g. a winter snow-lotus fortune). Add a line to the seasons help page saying some herbs only grow in one season. Check gather income stays in RV-009's range (tools/balance.sh economy section) and paste before/after. |
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
| QA-039 | qa | todo spec | A "first Foundation year" sim (verifies C-031). *Spec:* tests/sim/simulate_first_hour.gd or a new tests/sim/simulate_foundation_year.gd: for seeds 1-10 build the sim's typical player (combat_balance.gd builders) at Foundation Establishment 1st Layer with qi 0, a rogue and a sect disciple variant, start in each Foundation-friendly region in turn, and for 12 months: explore weekly (`GameState.explore_many` or the Exploration calls the first-hour sim uses), meditate the rest, answer sensed threats with "slip away", take one sect mission a month if in a sect. Print per seed: fights won/lost/evaded, injuries, artifact lives spent, stones +/- and the stage reached; then medians. Add it to tools/balance.sh and commit the baseline. Guard (new test or in test_first_hour_economy.gd, loose): no artifact life spent in the first year in >= 8/10 seeds, and the median win share of fought fights >= 50% (if it measures lower before C-031 lands, put the guard at what it measures and say so; C-031 then tightens it). Under ~60 s. |
| QA-041 | qa | todo spec | Three curious years (QA-029 Follow-up: the curious player does only ~2.3 kinds of action a month). *Spec:* in tests/sim/first_hour.gd (curious policy) add a `--months=N` option (default 12) and run 36 months for seeds 1-10. Per seed and per 6-month block print: distinct action kinds, the first month each feature was first used (sect mission, crafting, profession work, secret realm, gift/chat, breakthrough attempt, commission, and pointers/spar/sect lecture when the curious policy can use them), stones held, realm label; then medians. Flag every block where the median distinct kinds is <= 2 or no new feature was used, and list in Follow-ups the 3 longest "nothing new" stretches with what the player was doing (meditating? exploring?) and the likely cause (gate too high, money short, no hint). Add the 36-month run to tools/balance.sh as its own section and commit the baseline. No data or code fixes in this task (the planner files them). Keep it under ~90 s. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each Core-friendly region (Myriad Peaks Ridge and whichever regions list Core encounters), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent, tribulation not included; medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. Can share code with QA-039 if it has landed (pass the realm as an argument). |
| QA-044 | qa | todo | Do pointers and spars matter? (after QA-041 and GUIDE-012): in tests/sim/first_hour.gd add a curious-policy switch that never uses pointers/spars, run 12 months for seeds 1-10 with and without, and print median technique levels and fights won at months 6 and 12. Under Follow-ups say whether pointers/spars meaningfully speed the first year (or are too strong: more than ~2 extra technique levels by month 12), with numbers. No data changes. |
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
