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
Next (planner 2026-10-17 02:10): 14 tasks landed (C-152, C-149, WU-227, WU-226, PROF-012, C-151, WU-225, GUIDE-059, WU-215,
WU-230, C-153, MAHA-001, QA-20261017-1, WU-224). No new review entry (last reviewed f27406e; its note on a doubled Visceral
Mending scroll is C-156, its note on GUIDE-053's scroll scan is GUIDE-060). Live claims: PROF-011, WU-229, QA-108, C-150 (22:26,
expires with the 4h cleanup). **Orders you can see coming**: PROF-012 and C-151 made orders fit the ground; now a lapse says what
you were short (PROF-013), an open order says how many gathering days it still needs (PROF-014) and the year review counts filled
and lapsed orders (YEAR-011). QA-111 (ready: PROF-012 and C-151 are on main) measures the delivered share. QA-108 (claimed) then
decides GUIDE-057. One realm up: C-154 (Tribulation Transcendence foes), then C-155, C-157 (the last breakthrough pill), C-158
(inheritance) and TT-001 (goals). Screens: WU-228, WU-231, WU-232, WU-235 now; WU-233/234/236 after their systems tasks.
| id | role | status | task |
|---|---|---|---|
| PROF-011 | systems | todo spec | "Nearby" means nearby (review note on PROF-009: `Guidance.available_nearby` counts a merchant in ANY region, so an order can still ask for something sold only three regions away). *Spec:* src/core/systems/guidance.gd `available_nearby` (~393): a merchant counts only in `region_id` itself or a region one route away (read region `routes` in data/regions.json for the neighbour ids; reuse an existing neighbour helper in guidance.gd/exploration.gd if one exists, grep "routes"). Update the doc comment. When `region_id` is "" keep today's any-region behaviour. Do NOT change `source_phrase` ("sold by merchants" stays world-wide). Tests in tests/unit/test_commissions.gd or test_guidance.gd: an item sold only by a far merchant is not nearby from Qingshi but is from that merchant's region; the existing PROF-009 tests stay green. |
| PROF-013 | systems | todo spec | A lapsed order says what you were short (QA-107: 13 of 17 orders lapsed with only "The order for 2 Iron Swords lapsed."). *Spec:* src/core/systems/commissions.gd: factor the ingredient loop of `missing_line` into `static func short_ingredient(c, data, entry) -> String` (first non-stone ingredient the remaining crafts need more of, "" if none; `missing_line` calls it, behaviour unchanged). Add `static func lapse_text(c, data, order) -> String`: "The order for N <plural> lapsed." plus " You were short of <ingredient plural>." when `short_ingredient` names one, " You had the ingredients but never crafted them." when none is short and the pack holds fewer than N of the output, nothing extra otherwise. Use `Items.item_plural` as GUIDE-059 does. src/autoload/game_state.gd ~3028: post `Commissions.lapse_text(...)` instead of the inline format (same "info" category). Also `LifeStats.add(player, "commissions_lapsed")` per lapsed order there (YEAR-011 reads it; check `LifeStats` has no key whitelist, else add it). Tests in tests/unit/test_commissions.gd: short ingredient named; all ingredients held but not crafted; output held (no suffix); a GameState integration test that advancing past `due_day` posts the new text and bumps `commissions_lapsed`. |
| PROF-014 | systems | todo spec | An open order says how long its ingredients take to gather (PROF-012 Follow-up idea: `Exploration.gather_rate` exists but the player never sees it). *Spec:* src/core/systems/commissions.gd `missing_line` (~227): when the short ingredient (use PROF-013's `short_ingredient` if it has landed, else the existing loop) is gatherable in `region_id` (`Exploration.gather_rate(c, data, id, region_id, Calendar.season_of(today)) > 0`), append " (about <Calendar.format_duration(ceili(short_units / rate))> of gathering)" before the final period, where short_units = per-craft need x crafts - held. Do not change the line when the rate is 0 (bought or far away). `due_soon_hint` inherits it. If the estimate exceeds the order's days left, the line ends "... of gathering, longer than the order has)." instead. Tests (tests/unit/test_commissions.gd): a Qingshi iron order shows the estimate; a bought-only ingredient shows none; an estimate past the deadline uses the "longer than the order has" wording. Keep the journal line under ~110 characters for the longest real case (assert in a test with the longest gatherable ingredient name). |
| YEAR-011 | systems | todo spec | The year in review counts your orders (PROF-013 adds `commissions_lapsed`; `commissions_done` already exists). *Spec:* src/core/systems/life_stats.gd `year_summary`: after the crafted-items line, when filled + lapsed > 0: "You filled N crafting order(s)." / "You filled N crafting order(s) and let M lapse." / "You let M crafting order(s) lapse." (singular/plural like the lines around it). The summary keeps its existing cap/ordering rules (read how many lines the banner shows; if it caps at 4, this line ranks below craft earnings). If PROF-013 has not landed, add the `commissions_lapsed` counter in `Commissions.expire`'s GameState caller yourself. Tests next to YEAR-009's in tests/unit/test_life_stats.gd (or wherever year_summary is tested): filled only, lapsed only, both, neither. |
| GUIDE-060 | systems | todo spec | One scroll lookup, built once (review note on GUIDE-053: `Guidance.next_recipe_line` scans every item each call to find a recipe's scroll). *Spec:* src/core/game_data.gd: after items load, build `var recipe_scrolls: Dictionary` (recipe id -> first item id whose `effects.learn_recipe` is it, in data order) and `func scroll_for_recipe(recipe_id: String) -> String` ("" if none). Replace the scans: grep `learn_recipe` in src/core and src/ui (guidance.gd next_recipe_line ~1489 and any other loop that maps a recipe to its scroll); leave loops that do something else. No behaviour change: existing tests stay green; add one test that `scroll_for_recipe` matches the old scan for every recipe in the real data. |
| GUIDE-057 | systems | todo spec | A Qi Refining crafter who stops meditating hears about it (GUIDE-054 Follow-up). **Start only after QA-108 lands, and only if QA-108 shows the crafter stalls in Qi Refining** (realm d365 no higher than d180 in >= 3/10 seeds); otherwise land nothing and note it in your summary. *Spec:* src/core/character_data.gd: `var last_meditated_day: int = -1`, saved in to_dict/from_dict with default -1 (no SAVE_VERSION bump: the default is safe). Set it in GameState wherever a day of cultivation happens (meditate, seclusion, time skip that cultivates; grep `Cultivation.cultivate` callers in game_state.gd). src/core/systems/guidance.gd: `idle_crafter_hint(c, data, region_id, today)`: when c practises a profession, `c.realm_index == 1` (Qi Refining), and `today - max(last_meditated_day, 0) >= IDLE_CULTIVATION_DAYS` (const 30): "You have not cultivated in N days. <best spot> would carry you to the next layer in about M days." (reuse mortal_crafter_hint's spot and day-estimate code; factor a shared helper rather than copy). Put it where mortal_crafter_hint sits in `hints`. Tests in test_guidance.gd: shown at 30 idle days, hidden at 29, hidden for a non-crafter, hidden at Foundation; a GameState test that meditating resets it; a save round-trip keeps the field and an old dict without it loads -1. |
| TT-001 | systems | todo | Goals at Tribulation Transcendence (MAHA-001's pattern one realm up: `git show $(git log --format=%h --grep='MAHA-001\]' -1)`; start only after C-154 is on main). guidance.gd: `tribulation_goals` / `tribulation_goals_active`: "Reach Tribulation Transcendence Middle", "Win a fight against a Tribulation Transcendence foe" (`beat_realm_flag("tribulation_transcendence")`), the inheritance row only when `_has_realm_inheritance`; `goal_ladder_id` realm_index 9 -> "tribulation", ladder name "Tribulation Transcendence", journal section "Tribulation Transcendence goals". No ascension goal (END-001 is blocked). Tests next to MAHA-001's; any test that uses realm_index 9 as "past every ladder" needs another way to say it (there is no realm 10: assert the TT ladder instead). |
| WU-228 | world-ui | todo spec | C-149's Mahayana choice encounters on screen. *Spec:* extend `--encounter-shot` (tests/sim/screenshot_screens.gd, WU-217's Body Integration cases are the pattern) with the C-149 encounter that has the longest choice labels (read data/encounters.json; likely the vow lamp with its Spirit 60 gate): one shot with the gate missed (Spirit below 60) and one met, both at 1280x720 and 1280x800. Check every choice label and the "[Spirit 60]" tag fit the window without clipping; fix in src/ui/encounter_window.gd if not (wrap, not shrink). |
| WU-229 | world-ui | todo | MAHA-001's Mahayana goal ladder on screen (after MAHA-001; WU-193's `--body-shot` pattern): HUD goals and the journal section at 1280x720 and 1280x800; fix clipping. |
| WU-231 | world-ui | todo spec | WU-226 Follow-up: the `pill_b_hint` shot shows a Milestone banner over the hint panel. *Spec:* tests/sim/screenshot_screens.gd `--pill-shot` (~346): hide `hud._banner` after the player change that triggers the milestone (the existing `hide_banner` closure pattern at ~263, but call it deferred / after one `process_frame` so the banner raised by `player_changed` is the one hidden). Re-run `--pill-shot` at 1280x720 and 1280x800, check both PNGs show the hint panel unobstructed. Test-tool change only. |
| WU-232 | world-ui | todo spec | C-152's Mahayana inheritance on screen (WU-225's `--inherit-shot` pattern). *Spec:* add a second case to `--inherit-shot` in tests/sim/screenshot_screens.gd: a Mahayana Early player in Myriad Peaks Ridge at the Sutra Barge of the Great Vehicle grounds (read data/inheritances.json for its id and place) with stage 1 open and the comprehension 28 gate missed; shoot the grounds menu and the journal Opportunities line at 1280x720 and 1280x800. Fix clipping in src/ui if any (wrap, not shrink). |
| WU-235 | world-ui | todo | Focus audit for the newest menus (WU-212's pattern in tests/unit/test_focus_audit.gd): the Old Quarry Tailings gather menu, the Sutra Barge inheritance grounds menu, and one C-149 Mahayana encounter window with a gated choice. Each must grab focus on open and be fully navigable by ui_down/ui_accept; fix any that are not. |
| WU-233 | world-ui | todo | PROF-014's gathering estimate on screen (after PROF-014): `--workshop-shot` journal Commissions page and the HUD due-soon hint with the longest real line ("longer than the order has" case) at 1280x720 and 1280x800; fix clipping. |
| WU-234 | world-ui | todo | The lapse line and YEAR-011's orders line on screen (after PROF-013 and YEAR-011): `--year-shot` with a filled-and-lapsed line among four long lines, and the message log with PROF-013's longest lapse text, at 1280x720 and 1280x800; fix clipping. |
| WU-236 | world-ui | todo | TT-001's Tribulation Transcendence goal ladder on screen (after TT-001; WU-229's pattern): HUD goal line and journal section at 1280x720 and 1280x800; fix clipping. |
| C-150 | content | todo spec | A crafted good is worth more than its herbs (QA-105: crafted goods fetch about the raw value of the herbs they eat, Alchemist +16%, and the crafted sale cap binds 100% for Talisman Master 8.7 vs 19.4 and Array Master 13 vs 40). Planner call: raise data/recipes.json `alchemy.crafted_sell_markup` from 1.3. *Spec:* run `tools/balance.sh --section "profession income"` on main and paste the rows. Then try markup 1.6, 1.8 and 2.0 (scratch runs of tests/sim/profession_income.gd, with `--breakdown`) and pick the HIGHEST value where (1) every "bought ingredients" row stays below that profession's odd-jobs row (buying and crafting must not become a money press), and (2) no row's per-day exceeds 2.2 (gathering is 2.24). Commit that value, update the `_doc` text if it states 1.3, refresh only the profession income baseline section, and paste the before/after rows for the three markups tried. tests/unit/test_items_and_deeds.gd reads the markup from data, so it should stay green; fix any test that hard-codes 1.3. If even 1.6 breaks (1), keep 1.3 and say why in the commit with the numbers. |
| C-154 | content | todo spec | Six Tribulation Transcendence foes (C-148's pattern one realm up: `git show 4f9a43f -- data/enemies.json data/encounters.json`). *Spec:* six data/enemies.json entries with realm `tribulation_transcendence`, mirroring the six Mahayana archetypes one for one (same role and stat offsets relative to their realm, qi reward ~x1.6 and stones ~x1.4 of each Mahayana counterpart, drops from existing late items only, new names in the genre's voice: heavenly-lightning wardens, ascension-seekers, old monsters hiding from their tribulation). At least one is `non_lethal` (C-155/C-158 need a non-lethal guardian). One plain fight encounter each in the late regions (Myriad Peaks Ridge and wherever C-148 put its encounters), `min_realm: tribulation_transcendence`. Respect C-153's lesson: a foe that cannot be slipped (not sensed/evadable) gets `min_stage` 1 or later. Run tests/sim/simulate_combat.gd for the new foes and paste typical-player entry/peak/veteran win% in the commit; target entry 0-10%, peak 50-95% like C-148's. Tests: data validation passes; one test that each new encounter references an existing enemy. |
| C-155 | content | todo | Three Tribulation Transcendence choice encounters (after C-154; C-129/C-149's pattern): once-only, each with a righteous, a neutral/costly and a demonic way; one attribute-gated choice, one cost choice, one fight with a C-154 foe; voice: cultivators on the last step before ascension (no ascension itself, END-001 is the owner's). Tests like C-129's. |
| C-156 | content | todo spec | The Visceral Mending scroll is handed out twice (review note: C-143's Old Alchemist's Notes teach it, and the Verdant Remnant secret realm also gives `recipe_visceral_mending_pill`). *Spec:* in data/secret_realms.json `verdant_remnant`, replace that scroll with an alchemist recipe scroll of min_rank <= 2 that no encounter or secret realm gives yet (check every `recipe_` id against data/encounters.json, secret_realms.json, inheritances.json, auctions.json and merchant stock; name your pick and its other sources in the commit). Keep `recipe_visceral_mending_pill` in items.json (older saves). Update any test that asserts the remnant's loot. |
| C-157 | content | todo spec | The last breakthrough pill: a Tribulation Transcendence pill (C-147's pattern: `git show 66dd676`). *Spec:* data/items.json `tribulation_transcendence_pill` + `flawless_tribulation_transcendence_pill` with `breakthrough_realm: "tribulation_transcendence"`, chance bonus and price one step above the Great Vehicle Pill's (same ratio C-147 used over the Body-Void Union Pill); data/recipes.json alchemist recipe at the top rank (match C-147's min_rank or +0 if already max) using existing late ingredients only; a recipe scroll item sold as a rare lot in data/auctions.json (Fallen Star Market, like C-147's). Add the pill to tests/sim/simulate_economy.gd and simulate_life.gd where C-147 added the Mahayana pill. Tests in tests/unit/test_breakthrough_pills.gd like C-147's (pill only works for TT, flawless beats plain). New name in the genre's voice (not "Ascension": END-001 is the owner's). |
| C-158 | content | todo | A Tribulation Transcendence inheritance (after C-154; C-152's pattern one realm up: `git show bd74224`): data/inheritances.json grounds in a late region, a TT gate, an attribute gate ~32, a non-lethal C-154 guardian, reward ~2x C-152's in stones plus an existing late recipe and materials; tests like C-152's. |
| C-159 | content | todo | Help catches up with orders (PROF-012/C-151): the crafting-orders help page (grep data/help.json or wherever C-139/C-142 edited help) says order sizes fit what you can gather nearby in the time given, and that Qingshi's Old Quarry Tailings yields iron for a smith. Two sentences, plain words; update any help test. |
| QA-108 | qa | todo spec | Re-run the crafter's first year after GUIDE-054 (Mortal crafter nudge). *Spec:* tests/sim/crafter_start.gd: when the top hint (Guidance.hints limit 1, as `_top_hint_is_cultivation` reads it) is GUIDE-054's "You are still a mortal" line, the crafter meditates that step instead of gathering or crafting (today `_gather_for_order` / `_gather_hinted` run first whatever the top hint says). Run `-- 10 365` and paste before/after medians: stones d180/d365, crafts, realm d90/d180/d365, meditate share, cult-hint steps. Target: Qi Refining by day 120 in >= 8/10 seeds while d365 stones stay >= ~60% of today's 463. If missed, say by how much under Follow-ups (e.g. a sooner `MORTAL_CRAFTER_NUDGE_DAY`). Refresh the crafter baseline section. |
| QA-109 | qa | todo spec | Every craft's first year after GUIDE-054 (QA-104 ran only the Alchemist). *Spec:* tests/sim/crafter_start.gd: add `--prof=<id>` (default alchemist) for alchemist, blacksmith, talisman_master, array_master, beast_tamer (read data/professions.json for ids; skip one with no rank-0 recipe and say so). Same policy as QA-108's (if QA-108 has not landed, use today's policy and say so). Run `-- 10 365 --prof=X` for each and paste one median row per craft: stones d90/d180/d365, crafts, delivered/taken orders, rank d365, realm d180/d365, meditate share. Flag any craft that ends the year below 200 stones or still Mortal in >= 3/10 seeds, with the likely cause (no gatherable ingredient nearby, orders lapse, sale cap) under Follow-ups. Add a short `crafter crafts` section to tools/balance.sh (keep it under ~60 s; fewer seeds if needed) and refresh only it. |
| QA-111 | qa | todo spec | Orders after PROF-011/PROF-012/C-151 (QA-107 Follow-up). Start after at least two of those three are on main; say which ones were. *Spec:* tests/sim/crafter_start.gd: let the crafter walk to a neighbouring region (one route, use GameState travel so days pass) to gather an order ingredient that `Guidance.herb_place` names there, and walk back to deliver; only for an open order still short. Run `-- 10 180 --orders` for an Alchemist and (with QA-109's switch if landed) a Blacksmith and paste delivered/lapsed/open counts and median stones before/after. Answer: what share of orders is now delivered, and is a lapse ever the order's fault rather than the policy's? Rule or number changes go under Follow-ups. Refresh the crafter baseline section only if its default output changed. |
| QA-110 | qa | todo spec | Mahayana fight gates (QA-106's table one realm up; C-148, C-149, C-152 are on main). *Spec:* extend tests/sim/late_gates.gd to `mahayana`: list every fight encounter, encounter choice and inheritance guardian with a Mahayana foe, its min_realm/min_stage gate, whether it is sensed/evadable or forced, and the typical player's win% at that gate (200 fights). Flag forced fights under 20% that are not sensed/evadable and propose min_stage values under Follow-ups without changing data (C-153 is how the content worker applies them). Add the Mahayana rows to the late gates baseline section and refresh only that section. |

## P1: Steam release basics
| id | role | status | task |
|---|---|---|---|

## P2: After Core Formation (content runs out)
Late content keeps going in parallel (C-045 sits in the P0 table for now). Pacing itself stays the owner's call (F-005d).
| id | role | status | task |
|---|---|---|---|

## P4: QA and tooling
| id | role | status | task |
|---|---|---|---|
| QA-045 | qa | todo spec | Why is the first Foundation year so gentle? (QA-039 Follow-up: 107/120 runs spent no artifact life, median win share 100%, 0 injuries; DESIGN.md's QA-007 target is ~60-85% against a foe of your own realm and stage.) *Spec:* extend the QA-039 sim (tests/sim/simulate_foundation_year.gd or wherever it landed) with `--threats=slip|fight` (default slip, today's behaviour). For seeds 1-10 and both policies print per region: encounters met, fights fought, fights evaded via sensed threats, the median stage reached by month 3/6/12, and a histogram of the rated odds (Combat sim helper the combat baseline uses) of every fight actually fought (<50%, 50-75%, 75-95%, >95%). Answer in the commit body, with numbers: (a) are fights rare or just easy? (b) do C-031's stage gates leave only foes the player has already outgrown by the time they appear? (c) does the player outgrow the region within months (stage climbs fast)? List under Follow-ups the 3 data changes you would make (enemy ids or gate stages), without making them. Add the `fight` run as its own tools/balance.sh section and refresh only that section. Keep it under ~60 s. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates). *Spec:* reuse QA-039's sim with the realm as an argument (`--realm=core_formation`): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each region whose encounters include Core Formation fights (Myriad Peaks Ridge and any other; list them from data), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent (tribulation not included) and medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. If QA-045 has landed, include its `--threats` switch and odds histogram. |
| QA-035 | qa | todo | Economy sim: sect months every month (ECON-001b Follow-up). tests/sim/simulate_economy.gd only runs sect months every 12 months, so mission cooldowns never bind and sect income can't be compared fairly with profession work (still 1.5-1.9x for Doctor/Beast Tamer). Make the sim run the sect policy month by month (respecting `Sects.mission_cooldown_left`, duty, stipends) for a sect life, keep the same seeds, print per-profession "sect stones / work stones" ratios, update tools/balance.sh's baseline. If any profession's ratio is still > 1.5x, list the top 3 mission ids by net stones under Follow-ups (the planner files the content retune); don't retune data in this task. Also paste the economy section before/after ENC-003 (fading encounters; its commit skipped that comparison) and say whether income moved. Keep runtime under ~60 s. |

## Blocked (waiting on the owner, see DESIGN.md "Open design questions")
| id | role | status | task |
|---|---|---|---|
| F-005d | qa | blocked | Progression is far too fast (F-005c sim, seed 1, 200 lives): a sensible player (best reachable spot, Azure Cloud Sect) reaches Foundation at ~17, Core Formation at ~20, Nascent Soul at ~28, Void Refinement at ~92 and Tribulation Transcendence at ~800, with zero old-age deaths; Heavenly Roots hit Void Refinement at ~38. Even the bare density-1.0 sim reaches Core Formation at 40. Breakthrough pills never matter (no one can afford one before Foundation). Needs the target pacing from the owner (DESIGN.md open question), then rescale realms.json qi_required/base_qi_per_day and re-run `simulate_life.gd -- 200 1.0 1 real`. |
| C-009b | content | blocked | (LW-002b also found Qi Refining 3rd-5th layer players have low win odds in general.) Soften the first realm's fights so a newcomer with a starter technique wins ~50% against a 1st-layer beast (enemies.json `realm_training[1]` for stages 0-2, a starter beast between the bandit and the Mist Wolf, grade-1 gear at the Qingshi merchant). Blocked on the DESIGN.md question "(C-009) The first fights". QA-032 adds: a bare newcomer (no combat technique) wins 0% against wolves at stage 1; one option is a starter strike technique for every sect disciple. |
| END-001 | systems | blocked | An ending: at Tribulation Transcendence Peak a final Ascension tribulation, then an epilogue screen summing up the life (age, realm, alignment, deeds, clan, descendants). Blocked on the DESIGN.md question "(END-001) Ascension". |
| REL-006 | systems | blocked | Legacy after final death: offer "Continue as your heir" (Clans heir / designate_heir, game_state.gd ~1186) besides "Return to Main Menu". Blocked on the DESIGN.md question "Permadeath, or reincarnation / legacy system on death?". |
| SECT-001 | systems | blocked | Founding your own sect (roadmap item 3). Blocked on the DESIGN.md question "Founding your own sect". Default if approved: unlocks at Nascent Soul, needs a mountain-gate place, and reuses the clan treasury/buildings model (FAM-005/FAM-006) with disciples recruited from generated NPCs. |
| STORY-001 | content | blocked | Main story act 1 around the Creation Artifact (who made it, who hunts it). Blocked on the DESIGN.md question "Main story / Creation Artifact origin". Until answered, ART-006 keeps the origin vague. |
| DEM-002 | systems | blocked | Separate demonic progression tree (blood refining, soul devouring, corpse puppets) parallel to methods. Blocked on DESIGN.md question "Should evil paths include demonic cultivation techniques as a separate progression tree?". Default if approved: demonic methods via CM-001 + DEM-001 devouring, then a tree of unlockable demonic arts paid with "blood essence" gained from devouring. |
| ART-007 | systems | blocked | Artifact recharge cost curve: cost_growth 2.0 compounds over the whole life (life 10 costs 51,200, life 13 costs 409,600), so long-lived cultivators always run out (QA-006). Waiting on the DESIGN.md question "(QA-006) Artifact recharge cost"; default proposal: base_cost scales with realm and cost_growth applies only to lives bought within the current major realm. |

## Done
Tasks finished since the 2026-10-07 archive. The planner moves rows here from `[ID]` commits on main.
| id | role | task |
| C-152 | content | A Mahayana inheritance: Sutra Barge of the Great Vehicle (Myriad Peaks Ridge). |
| C-149 | content | Three Mahayana choice encounters: vow lamp, last-river ferryman, the ancestor who would not ascend. |
| WU-227 | world-ui | --gather-note: the Old Quarry Tailings place and menu fit at 1280x720 and 1280x800. |
| WU-226 | world-ui | --pill-shot: the Great Vehicle Pill breakthrough window and no-pill hint fit. |
| PROF-012 | systems | An order's count fits the time it takes to gather it (Exploration.gather_rate, Commissions.max_count). |
| C-151 | content | Old Quarry Tailings in Qingshi yields iron; Iron Sword/Armor back on ore (gathered Blacksmith 1.13 -> 1.84/day). |
| WU-225 | world-ui | --inherit-shot: the Hollow of the Unbroken Body menu and journal Opportunities line fit. |
| GUIDE-059 | systems | Item counts are pluralised in the message log and order texts. |
| WU-215 | world-ui | --hint-shot: the broke-crafter odd-jobs line fits. |
| WU-230 | world-ui | Plural item names in the shop sell-all summary, sect stipend line and map letter mark. |
| C-153 | content | Late hunters you cannot slip away from meet you a stage later (win% 3-31 -> 31-56). |
| MAHA-001 | systems | Goals at Mahayana. |
| QA-20261017-1 | qa | Mass-noun items keep their name in the plural ("3 Cold Iron"); 12 items.json plural overrides. |
| WU-224 | world-ui | --workshop-shot: the longest order label cuts at a whole word and fits. |
| C-148 | content | Six Mahayana foes, each with a fight encounter. |
| PROF-010 | systems | A two-rank jump names every recipe it opens. |
| WU-223 | world-ui | --gather-note: the Village Herb Slope note wraps inside the menu in every season. |
| C-147 | content | Great Vehicle Pill, a Mahayana breakthrough pill (Alchemist rank 10; scroll at the Fallen Star auction). |
| GUIDE-056 | systems | Item names are pluralised in requirement reasons (Text.plural, items.json `plural`). |
| C-136 | content | A Body Integration inheritance: Hollow of the Unbroken Body. |
| WU-222 | world-ui | --goal-shot: the journal's "Next recipe" goal line fits. |
| QA-107 | qa | Crafter sim --orders: orders lapse because one ingredient is rare or a region away, not the reward or the sim's policy. |
| WU-220 | world-ui | --hint-shot: the Mortal nudge fits the HUD hint panel. |
| GUIDE-055 | systems | A gather site's note also lists what grows there all year. |
| WU-221 | world-ui | --encounter-shot: C-143's three crafter encounters fit. |
| GUIDE-054 | systems | A Mortal crafter hears that they have not begun cultivating. |
| WU-219 | world-ui | The workshop order label cuts at a word boundary. |
| QA-106 | qa | Late-realm fight gates table: three non-lethal hunters can't be slipped and win 3-31% at their gate. |
| WU-216 | world-ui | --rankup-shot: a craft's rank-up lines fit the message log. |
| GUIDE-051 | systems | herb_place's out-of-season fallback names the next season the herb grows in. |
| QA-102 | qa | Crafter-start sim follows the order line: a hint-following Alchemist ends month 6 with 241 stones vs the curious 69; orders rarely delivered. |
| WU-214 | world-ui | --workshop-shot: the journal Commissions section with the "Needs <item>: <where>." line fits. |
| QA-104 | qa | A crafter's first year: keeps earning (463 stones at d365) but is still Mortal in 8/10 seeds; no hint ever says meditate. |
| BI-001 | systems | Goals at Body Integration. |
| PROF-009 | systems | Orders prefer something you can gather or buy nearby. |
| PROF-008 | systems | A craft's rank-up says what it opens. |
| WU-218 | world-ui | A new crafter's first hour on screen (--crafter) and two wording fixes. |
| C-146 | content | Blacksmith and Array Master crafting beats odd jobs when gathered. |
| QA-105 | qa | --breakdown for the profession income sim: crafting days and the crafted sell cap are why gathering beats crafting. |
| C-143 | content | Three first-year crafter encounters: herb cache, old alchemist's notes, broken forge. |
| WU-217 | world-ui | --encounter-shot: the Body Integration choice encounters fit, gates missed and met. |
| C-145 | content | The redundant Spirit Gathering Pill scroll is no longer handed out. |
| WU-193 | world-ui | --body-shot: the Body Integration goal ladder fits at 1280x800 and 1280x720. |
| GUIDE-053 | systems | The journal's profession goal names the next recipe to learn. |
| QA-103 | qa | The curious QR9 slowdown (476 -> 577 days) came from QA-087's sim-policy change, not the game; QR9 in 12 months is one seed. |
| GUIDE-050 | systems | The odd-jobs hint counts only the stones you still lack (Alchemy.shortfall_cost). |
| WU-213 | world-ui | --year-shot: the year review with the rival line fits at 1280x720 and 1280x800. |
| C-129 | content | Three Body Integration choice encounters (drowned god, one-body arbiter, bone court petition). |
| WU-212 | world-ui | Focus audit: workshop with odd jobs and an order, crafting after the last ingredient, herb gather site. |
| C-142 | content | The crafting help says gathering or filling orders is what makes an early craft pay. |
| GUIDE-052 | systems | An open order says what you are missing and where it grows (journal and HUD). |
| C-144 | content | Every craft has a rank-1 recipe within reach of Qingshi (array, beast tamer, blacksmith starters; Spirit Gathering Pill is a starter). |
| GUIDE-049 | systems | The crafter hints fade at rank 2, not after 5 crafts: a new Alchemist ends month 6 with 262 stones (was 56). |
| WU-211 | world-ui | --hint-shot: the HUD hint panel with the longest crafter hints fits at 1280x800 and 1280x720. |
| C-128 | content | Six Body Integration foes, each with a fight encounter. |
| WU-210 | world-ui | --rival-shot: the caught-up notice and the journal Household line fit. |
| WU-209 | world-ui | Workshop "1 recipe" label; honest "Gathered materials" margin hint. |
| QA-101 | qa | Profession income sim has an odd-jobs row: odd jobs 0.78-1.10/day beat gathered Blacksmith (0.51) and Array Master (0.60) crafting. |
| YEAR-010 | systems | The year in review says where your rival stands. |
| GUIDE-048 | systems | The herb hint and the crafting screen respect seasons and name the region. |
| PROF-007 | systems | A new crafter's first order comes the day they start (only for the new craft, review fix). |
| RIVAL-020 | systems | Catching up with your rival is news (once per realm). |
| GUIDE-047 | systems | A broke crafter hears about odd jobs in their own craft. |
| WU-195 | world-ui | The workshop says what work pays; the crafting screen says what a recipe costs and sells for. |
| PROF-004 | world-ui | Crafters can take odd jobs in their own craft at the workshop. |
| WU-201 | world-ui | --craft-shots for every craft; one place per missing ingredient, "found at" for non-herbs. |
| WU-207 | world-ui | --rival-shot: the journal's rival reach lines fit at 1280x800 and 1280x720. |
| WU-208 | world-ui | --workshop-shot: a practised Alchemist with an open order and odd jobs fits at 1280x720. |
| C-137 | content | The Minor Spirit Gathering Array pays when gathered (0.60 stones/day, was -0.18). |
| C-141 | content | Guard test: every rank-0 recipe ingredient is within reach of Qingshi (no data change needed). |
| C-140 | content | The professions help page names a crafter's odd jobs (done by review 4e412f5). |
| QA-094 | qa | Balance baseline refreshed; curious QR9 median slowed 476 -> 577 days (QA-103). |
| QA-100 | qa | Crafter-start sim: a new Alchemist is ahead at day 30-90 but stops earning at ~day 60 once the herb hint fades. |
| GUIDE-046 | systems | The herb hint looks one region further (regions a short walk away). |
| C-139 | content | Help pages catch up with odd jobs, gathered herbs, the "Used in" line and craft renown. |
| RIVAL-018 | systems | The journal says which realm to reach before challenging a rival who is far ahead. |
| WU-206 | world-ui | The crafting screen names where a missing herb grows (Guidance.herb_place). |
| PROF-005 | systems | Material value counts the spirit stones a recipe spends (1 per stone). |
| C-138 | content | A Beast Tamer choice in the first hours: The Snared Fox Kit. |
| PROF-006 | systems | A choice can ask only that you practise a craft (min_profession rank 0); C-134's choices open to Apprentices. |
| WU-204 | world-ui | Banner shots with the longest real arrival subtitle and milestone. |
| WU-205 | world-ui | Workshop and Bounty Board no longer hide under the HUD at the village spawn view. |
| QA-099 | qa | The sims no longer leak a resource at exit. |
| QA-098 | qa | The sims buy Void Refinement and Body Integration pills. |
| C-135 | content | Body-Void Union Pill: a Body Integration breakthrough pill. |
| WU-200 | world-ui | Year-review shot with the newest lines (realm change, lost inheritance, name spread, crafts). |
|---|---|---|
| YEAR-009 | systems | The year in review says what your craft earned (work, commissions, crafted sales). |
| C-134 | content | Three first-hours encounters with blacksmith, talisman/array and alchemist (Spirit 12, a fight) choices. |
| QA-097 | qa | Profession income sim crafts instead of working: bought ingredients lose money, gathered Alchemist 1.52/day, Array Master -0.18. |
| GUIDE-044 | systems | The newcomer's workshop hint names the Doctor's monthly pay. |
| C-133 | content | Every profession's first recipes pay (Minor Spirit Gathering Array costs 28, sells 29). |
| WU-202 | world-ui | The notice banner's subtitle stays one line (ellipsis past 960 px). |
| RENOWN-007 | systems | A delivered commission (+5) or a patients session (+2) spreads your name. |
| GUIDE-042 | systems | A crafter hears where the herbs for their recipes grow in the region. |
| INH-006 | systems | The year in review only mourns inheritances you knew about. |
| QA-087 | qa | Rival sim challenges only listed bouts: 7 won, 0 lost; first win in 1/10 seeds in 36 months. |
| WU-203 | world-ui | A gather site says which of your recipes its herbs feed ("Used in: ..."). |
| C-125 | content | Rank-4 blacksmith, talisman and array master choices at Nascent Soul. |
| WU-199 | world-ui | Place labels already stay inside the map (WU-160 clamp); closed as not needed. |
| C-132 | content | Odd jobs pay three times as much (Doctor 15 a month at rank 0); professions now pay 0.78-1.10 stones/day. |
| C-124 | content | Three once-only Void Refinement rival encounters (friendly, proud, bitter), each with a duel and a peaceful way out. |
| WU-198 | world-ui | The epilogue's "Known as Renowned in ..." line fits at 1280x800 and 1280x720. |
| QA-096 | qa | Curious sim --trace=<seed>: seed 7 no longer stalls (QR7 at month 13, Foundation at month 28). |
| WU-197 | world-ui | --banner-shot: the notice banner sits clear of the HUD vitals, Goal line and hints. |
| C-131 | content | An Alchemist's first four pills sell for 1.2-1.3x their herb cost. |
| YEAR-008 | systems | The year in review says your profession grew a rank. |
| PROF-003 | systems | Professions.work_preview and Alchemy.recipe_margin: what work and a craft pay. |
| WU-196 | world-ui | --renown-shot: arrival banner and journal renown lines fit at 1280x800 and 1280x720. |
| GUIDE-041 | systems | "Try something new" hints start in the third month (day 60) instead of day 180. |
| WU-194 | world-ui | The death lesson bands on the rounded odds it prints. |
| C-127 | content | Void Piercing Pill: a Void Refinement breakthrough pill, recipe from the Space Folder inheritance. |
| WU-190 | world-ui | --encounter-shot: encounter windows with attribute, profession and enemy choices fit. |
| EPI-003 | systems | The epilogue names your fame ("Known as <title> in <region>"). |
| QA-20261016-1 | qa | Renown titles count places, not tiers climbed (one town can no longer earn Known Across the Land). |
| C-123 | content | Voidwalker Body: a seventh body tempering stage for Void Refinement. |
| RENOWN-006 | systems | The journal says how close your next renown title is. |
| QA-095 | qa | Curious sim buys a life at 1x recharge cost at <= 1 life: no seed ends early in 36 months (final deaths 2 -> 0). |
| WU-188 | world-ui | Void Refinement ladder shot (--void-shot): HUD goal line and journal fit at 1280x800 and 1280x720. |
| C-130 | content | Milestones "A Name Spoken" (1 renown title) and "Known Across the Land" (4). |
| WU-192 | world-ui | The arrival banner says "Known here: <title>" where your name has a title. |
| QA-086 | qa | Quiet-stretch sim: a meditate-and-explore newcomer goes up to 60 days with nothing new (median 7); curious median 2, max 34. |
| GUIDE-038 | systems | Long waits read in months or years ("about 24 years"), not thousands of days. |
| WU-191 | world-ui | The HUD Goal line follows the realm's goal ladder. |
| C-126 | content | The Drunk Bully is non-lethal: losing to him leaves you beaten, not dead. |
| GUIDE-040 | systems | The low-lives hint is honest about the stones you hold and an empty artifact. |
| QA-093 | qa | Profession income sim: professions pay 0.26-0.37 stones/day vs 2.24 for gathering; crafting from bought herbs loses money. |
| WU-180 | world-ui | Journal shot with debts, a grudge and an inheritance deadline: fits at 1280x800 and 1280x720. |
| WU-181 | world-ui | The first-hour combat shot uses a real seeded fight (Victory: Wild Boar, Rated: Weak). |
| INH-005 | systems | The year in review remembers an inheritance lost to rivals. |
| C-122 | content | A Void Refinement inheritance: Door Ajar of the Space Folder. |
| GUIDE-036 | systems | A "Save for" goal names a source (a recipe or an auction) for a breakthrough pill no shop sells. |
| VOID-001 | systems | Void Refinement goal ladder in the journal and HUD. |
| RENOWN-005 | systems | Renown from an encounter choice posts "Word of it spreads through X (renown +N)". |
| GRAT-002 | systems | The journal's grudge line names the amends cost and where to make them. |
| YEAR-007 | systems | The year in review says in how many places your name became known. |
| WU-158 | world-ui | Newest windows checked at 1280x720; the notice banner moved to the top fifth so it no longer covers window titles. |
| WU-187 | world-ui | Shots of the respawn screen (98% odds, long foe name) and a four-line year review; both fit at 1280x800 and 1280x720. |
| WU-189 | world-ui | The mission board warns when a risky lethal fight meets a nearly empty Creation Artifact. |
| WU-184 | world-ui | Soul Formation shot: HUD and journal goal ladder fit at 1280x720 and 800. |
| WU-186 | world-ui | Focus audit: journal debts/inheritance/Soul Formation lines, sheet People list, inheritance grounds menu. |
| C-102 | content | Renowned requests retuned to about a week of the best ordinary income (1.5-2.2x a sect mission). |
| C-120 | content | Renown on four honourable encounter choices. |
| C-121 | content | One help page, "Debts and Grudges", replaces two overlapping ones. |
| QA-091 | qa | Curious-years sim prints a per-foe table, fight origins and artifact lives; deaths are volume, not rating mismatches. |
| YEAR-006 | systems | The year in review says when the Creation Artifact pulled you back from death. |
| C-117 | content | Three once-only Nascent Soul encounters where you give up a fruit or stones for a Dao insight, practice or renown. |
| SOUL-002 | systems | The Soul Formation inheritance goal names a Soul Formation inheritance (not "claim two", done on arrival). |
| C-103 | content | Rank-3 profession choices at Core Formation (beast tamer truce, alchemist crater pill, doctor ferryman). |
| WU-183 | world-ui | `--late-realms` sheet shot with "(owes you)", "(holds a grudge)" and a rival "a slight": fits at 1280x800/720, no fix. |
| QA-092 | qa | The curious sim walks to forest/marsh/mountain while its rival is bitter: rival_spoils_gathering met 0 -> 3 seeds. |
| INH-004 | systems | Inheritance status text uses the "N months left before rivals arrive" wording. |
| RENOWN-004 | systems | Encounter choices may carry `renown` 1..50 (validated), granted after the choice (after a won fight for enemy choices). |
| C-116 | content | Help page "Debts and Grudges" (overlaps the older "Karma, Grudges and Debts": C-121). |
| WU-185 | world-ui | The respawn screen's lesson depends on the odds: "still fell" at >= 90%, "either way" at 50-90%, "grow stronger" below. |
| C-119 | content | Ten Void Refinement encounters: 6 fights, 3 once-only alignment forks, 1 dao fortune (landed with C-118). |
| C-118 | content | Six Void Refinement foes; sim entry 2-42%, peak 54-98%. |
| WU-182 | world-ui | Year-in-review banner shot with four long lines fits at 1280x800/720. |
| QA-084 | qa | renowned_pay.gd compares each renowned request with a week of gathering, profession work and sect missions; C-102 gets the numbers. |
| GUIDE-037 | systems | `Rivals.where_text`: one rule for naming the rival's region on the sheet and in the journal. |
| C-106 | content | Three once-only Core Formation encounters where you give up a salve, stones or a lotus seed for a lasting gain. |
| YEAR-005 | systems | The year in review leads with survived tribulations and claimed inheritances. |
| C-115 | content | Three once-only Soul Formation rival encounters, one per attitude (reviewer reworded the bitter cairn). |
| GRAT-001 | systems | Journal "Debts and grudges": who owes you (gifts, allies in their region) and who may ambush you. |
| QA-090 | qa | The curious sim never explores the bitter-spoils regions while the rival is bitter (0 days); the encounter is fine. |
| INH-003 | systems | Opportunities lines say how long an inheritance waits ("3 months left", warning under a year). |
| WU-179 | world-ui | The sheet's rival line reads in words ("a slight"), no raw favor/grudge numbers. |
| WU-178 | world-ui | The sheet's People list shows "(owes you)" and "(holds a grudge)", even at favor 0. |
| C-114 | content | Starfire Body: a sixth body tempering stage for Soul Formation. |
| SOUL-001 | systems | Soul Formation goal ladder in journal and HUD. |
| C-113 | content | Help on inheritance trials. |
| QA-089 | qa | GUIDE-033's rival bout tests build a fair bout for certain and can no longer skip. |
| C-112 | content | Three once-only Nascent Soul rival encounters, one per attitude, each with a duel and a peaceful choice. |
| WU-177 | world-ui | `--death-shot`: the final-death screen with clan, children, a met rival and 8 life-record lines fits at 1280x800 and 1280x720. |
| INH-002 | systems | A failed attribute trial says "needs N, you have M". |
| WU-172 | world-ui | `--late-realms` meets a rival in another region with a bout record; the Rival line wraps without clipping. |
| QA-088 | qa | Regression test: the three rival-attitude encounters are eligible in their regions (8-13% of the pool); QA-083's 0 is the sim's doing. |
| C-111 | content | Silence of the Reeds Spirit 11 -> 10; the inheritance sim walks multi-hop routes. Reed hermit claimed 0/10 -> 4/10. |
| WU-174 | world-ui | The sheet's rival line names the rival's region when it is not yours. |
| EPI-002 | systems | The epilogue names your rival, their realm, whether they fell, and the bout record. |
| WU-176 | world-ui | The current interact target no longer draws its own label under the prompt. |
| WU-175 | world-ui | First-hour shots re-checked against WU-157: 3 items fixed, edge labels and the staged combat report remain (HANDOFF). |
| WU-173 | world-ui | The spar / rival challenge option shows its odds ("Even, 52 in 100"). |
| C-110 | content | Milestones Crossed Hands (1 bout won) and A Worthy Rival (10). |
| YEAR-004 | systems | The year in review counts bouts with your rival. |
| NS-007 | systems | Nascent Soul goal ladder (Middle stage, a Nascent Soul foe, an inheritance, Vajra Body) in journal and HUD. |
| WU-171 | world-ui | Focus audit: title separator menu, tinted option, disabled rival challenge, tagged encounter window; no fixes needed. |
| RIVAL-017 | systems | Done by the reviewer (07e4932): the bout record lives in world_flags per current rival and is cleared on succession. |
| C-107 | content | Help: a rival answers any challenge unless bitter, the bout record, successors. |
| EFF-004 | systems | `Effects.check` refuses `profession_xp` for a profession not taken up. |
| WU-170 | world-ui | `--late-realms` shots reach the sheet's later lines (life record, strongest foe); Rival section not met in the shot (WU-172). |
| GUIDE-035 | systems | The journal's rival line names the rival's region when it is not yours. |
| C-108 | content | A successor rival's first meeting (flag `rival_meeting_from`): the newcomer means to take the fallen rival's place. |
| WU-166 | world-ui | The sheet's rival line ends with the bout record. |
| WU-169 | world-ui | Help list shows group headers. |
| RIVAL-016 | systems | LifeStats `rival_bouts_won/lost`, a first-win line, `Rivals.bout_record_text` on the journal rival line. |
| WU-167 | world-ui | Sheet Next steps shows 3 hints plus "More in the Journal". |
| QA-071 | qa | Early-inheritances baseline refreshed: reed_hermit_hut claimed 0/10 (Silence of the Reeds blocks, C-111). |
| WU-165 | world-ui | HUD status/log panels fade to 0.35 over the player and nearby place labels. |
| C-105 | content | Help pages in six groups (`groups` + per-page `group`, validated). |
| GUIDE-034 | systems | Journal Next steps skips hints that repeat a Goals line. |
| GUIDE-032 | systems | "Save for" pill goal in the last three stages of any realm (Qi Refining keeps 6+). |
| C-109 | content | Rival duel choices add rival_grudge 5 (not 10); guard test against one duel making the rival bitter. |
| QA-083 | qa | Rival sim prints attitudes: default policy 100% proud; curious 50/26/24; rival_spoils_gathering never met (QA-088). |
| GUIDE-033 | systems | `fair_fights` lists the rival bout (kind "rival") when fair, in region, not bitter. |
| WU-164 | world-ui | Tribulation attempt option tinted for "close" / "would not survive"; tribulation screen uses CLOSE_CALL_SHARE. | 
| WU-163 | world-ui | `--late-realms` shots (Foundation Peak, Core Early) fit at 1280x800/720; duplicates noted (GUIDE-034, WU-170). | 
| C-099 | content | Help page "Rival Moods". | 
| C-104 | content | Help page "Goals". | 
| WU-162 | world-ui | NPC menu test: a bitter rival's Challenge entry is disabled with RIVAL-012's reason (no code change). | 
| RIVAL-015 | systems | Hint: a bitter rival will not cross hands, make amends (cost). Code landed as 911d1e3 "fixup spacing". | 
| QA-085 | qa | tests/sim/first_fights_truth.gd: the boar is rated 100%, wins 100%; the WU-157 defeat shot was staged. No foe off by >15 points. | 
| WU-161 | world-ui | ChoiceMenu: separator under the title so it never reads as an option. | 
| RIVAL-014 | systems | A successor rival 180 days after your rival dies (not by your hand); first meeting replays; `flag_count` ignores text flags. | 
| GUIDE-031 | systems | `Guidance.drop_goal_echoes`: HUD hints that repeat the goal are dropped; first goal names Qingshi Village. | 
| C-101 | content | Three once-only Foundation give-up encounters (cliff pill, array recipe stones, marsh crystal). | 
| WU-160 | world-ui | `Interactable.clamp_labels` keeps place labels inside the map's left/right edges (HUD overlap: WU-165). | 
| FOUND-007 | systems | `Guidance.CLOSE_CALL_SHARE` 0.9: the readiness line says "close" (bare + Stone Skin at -500 no longer reads ok). | 
| RIVAL-012 | systems | `check_spar` skips the favor check for your rival; a bitter rival refuses ("They want a real fight."). | 
| C-100 | content | Three Core Formation rival encounters (boast, secret realm gate, tribulation question). | 
| CORE-001 | systems | Journal "Core Formation goals" ladder (Middle, a Core foe, a secret realm floor, Golden Body). | 
| C-098 | content | `profession_xp` on all seven profession-gated choices (15 at rank 1, 30 at rank 2); data test. | 
| QA-082 | qa | Fair-fights sim counts explore entries: 101 listed, 24 taken, 100% won; no follow-ups. | 
| WU-155 | world-ui | The rival's menu reads "Challenge your rival X to a bout"; "X accepts your challenge." (bitter-rival test waits for RIVAL-012, see WU-162). |
| RIVAL-013 | systems | `Rivals.attitude_change_line`, posted after gifts, chats, spars, karma acts, letters and rival encounter choices. |
| C-095 | content | Rank-2 profession choices on three Foundation encounters (array master, talisman master, blacksmith). |
| WU-157 | world-ui | First-hour screenshots: all fit at 1280x800; findings in HANDOFF (edge labels, Goal/hint repeat, explore header). |
| WU-159 | world-ui | Sheet: "Strongest foe beaten: <realm>" from the beat_realm flags. |
| WU-156 | world-ui | Test: the longest tagged choice fits at 1280x800 and 1280x720; no layout change needed. |
| C-097 | content | Tribulation help page explains the readiness line. |
| QA-081 | qa | tests/sim/readiness_truth.gd + guard test: the verdict matches survival except bare+Stone Skin at alignment -500 (says ok, 56%). |
| C-093 | content | rival_shares_insight / rival_spoils_gathering / rival_public_challenge by attitude. |
| WU-154 | world-ui | Encounter window footer explains bracketed tags and names the Help key. |
| EFF-003 | systems | `profession_xp` effect (trains professions already taken up; validated 1..500). |
| FOUND-006 | systems | `beat_realm_<id>` world flags; Foundation goal "Win a fight against a Foundation foe". |
| QA-080 | qa | tests/sim/renowned_pay.gd: renowned requests pay 2.5-25x a week of gathering (village dispute 1.5x). |
| RIVAL-010 | systems | Encounters can require `rival_attitude` (friendly/bitter/proud); the roll passes the rival's favor. |
| WU-151 | world-ui | The rival's attitude on the sheet and in Look; their label turns warning-colored while bitter. |
| C-096 | content | Three once-only Qi Refining encounters (forest, village, marsh) with choices that cost items. |
| C-094 | content | Help page "Choices and Checks". |
| WU-152 | world-ui | Focus audit: encounter with check/locked/all-locked choices, world map with a bounty, breakthrough window with lessons; no fixes needed. |
| RIVAL-011 | systems | One news line when your rival dies (none for your own kill). |
| QA-079 | qa | Every balance baseline section refreshed on 5992328; no regression flags. |
| RIVAL-009 | systems | `Rivals.attitude`: bitter (grudge >= `bitter_grudge`), friendly (favor >= `friendly_favor`) or proud; journal wording. |
| GUIDE-029 | systems | `Guidance.pill_gap_note`: under the Save-for goal, which fair fights pay toward the Foundation pill. |
| WU-150 | world-ui | The HUD fair-fight line drops its percent when it would not fit (checked by font measurement). |
| C-092 | content | Rival follow-ups: sparring reward, rival help page. |
| CHOICE-003 | systems | Choice tags also name alignment requirements and item costs. |
| WU-153 | world-ui | Tribulation readiness on the breakthrough attempt option. |
| WU-148 | world-ui | The realm card names the rival a breakthrough just passed (reviewer: cleared per attempt). |
| GUIDE-030 | systems | `fair_fights` rates up to 2 exploration foes of the region when fewer than 3 fights were found (kind "explore"). |
| C-091 | content | Attribute checks (Spirit, Fortune, Charisma, Constitution 12) on four first-year encounters. |
| WU-149 | world-ui | A failed major breakthrough posts the lesson it taught you. |
| QA-078 | qa | tests/sim/rival_story.gd; fix: a mortal rival counted as "surpassed" on day 15. Now surpassed in 3/10 default runs (median day 648). |
| FOUND-005 | systems | `Guidance.tribulation_note`: on the last stage before a tribulation, waves, likely damage vs hp, and whether you would survive. |
| FOUND-004 | systems | Journal "Foundation goals" ladder; the HUD goal banner follows both ladders (reviewer fixed the last-goal announcement). |
| C-090 | content | Rank-1 profession choices on four encounters (doctor, blacksmith, alchemist, beast tamer). |
| RIVAL-008 | systems | Surpassing spurs the rival's diligence (`spurred_diligence` 0.1, cap 0.95); overtaking you again clears `rival_surpassed`. |
| C-062 | content | Four `min_renown` requests: caravan escort, duel judge, marsh corpse refiner, ridge beast truce; data test per region. |
| WU-146 | world-ui | Encounter choices read "[Comprehension 12] ..." from the `check` tag. |
| WU-147 | world-ui | World map marks your bounty hunt, else up to 2 takeable offers per region. |
| QA-076 | qa | `--wait-for-pill=N`: waiting up to 120 days closes the pill gap for every short seed; 1/9 attempts under 50%. |
| QA-077 | qa | Answered in QA-076's commit: bounties still listed 3 times in 120 months (GUIDE-028 did not raise it). |
| QA-073 | qa | Not needed: unit suite already 408 s (QA-068 + PERF-001), under the 420 s goal. |
| CHOICE-002 | systems | `requires.min_profession`, validation, `check` tag on `Exploration.choices`. |
| C-087 | content | Three Foundation rival encounters (herb bid, rival cornered by a wolf, terrace challenge). |
| RIVAL-007 | systems | Monthly `_rival_news` also checks for surpassing a rival already behind. |
| C-088 | content | "Answer better than {rival}" at the sect lecture (Comprehension 12). |
| WU-145 | world-ui | `--breakthrough-shots`: everything fits at 1280x720; 720p button test added. |
| WU-144 | world-ui | HUD line "Fair fight: <enemy> (<rating> <pct>)", full entries in the tooltip (720p shot not re-run: WU-150). |
| QA-075 | qa | Curious sim does chore fights rated >= 70%: deeds listed 1, taken 1, won 1. |
| C-089 | content | Help: "Your Rival" page and the lessons of failed breakthroughs. |
| C-085 | content | Guard test: every region with a Qi Refining fight has a Qi Refining bounty; new ridge stone ape bounty. |
| GUIDE-028 | systems | `fair_fights` rates every local/nearby takeable bounty, not just the first. |
| WU-132 | world-ui | `--win-shots` screenshot pass: nothing clipped at 1280x800/720; HUD fair-fight line ellipsizes (WU-144). |
| WU-142 | world-ui | Breakthrough window shows stones held against the pill price. |
| WU-136 | world-ui | Focus audit: breakthrough window, mission board, realm card, shop list; no fixes, test added. |
| QA-072 | qa | Curious sim saves for and takes the Foundation pill: pill share 0% -> 42%, attempts under 50% 10/15 -> 5/14; 3 seeds still 130-190 short (QA-076). |
| CHOICE-001 | systems | Encounter choices take `requires.min_attributes`. |
| RIVAL-006 | systems | `Rivals.surpassed`, `rival_surpassed` flag, one-time line, surpass_the_rival milestone. |
| C-083 | content | Help pages: style practice, fair fights, inheritance trials. |
| RIVAL-005 | systems | Word of the rival's major breakthroughs (`rival_seen_realm`). |
| WU-140 | world-ui | Breakthrough window shows the next realm's description (`realm_blurb`). |
| C-065 | content | Festival activities for Qingming (grave sweeping) and Mid-Autumn (moon viewing). |
| FOUND-003 | systems | Failed major breakthroughs add `failure_bonus` 0.03 (cap 0.09), reset on success; `breakthrough_failures` saved. |
| WU-143 | world-ui | World map mark "Your rival: <name> (<relation>)". |
| GUIDE-027 | systems | `Combat.RATING_SAMPLES` (40) everywhere; mission hint agrees with the board. |
| WU-141 | world-ui | Look at your rival says where you stand. |
| WU-137 | world-ui | `RealmCard` at a major breakthrough (waits for the tribulation screen: reviewer fix). |
| QA-074 | qa | QA-066 test filters attempts to Qi Refining -> Foundation. |
| C-086 | content | Three first-year rival encounters (herb seller's pill, wounded rival in Misty Forest, sect lecture). |
| PERF-001 | systems | `Combat.win_chance` memoised by `fight_fingerprint`, cleared at 256 entries; hint builders not timed. |
| WU-139 | world-ui | The sheet's rival line appears only after the first meeting, worded by `Rivals.relation_text`. |
| C-082 | content | Three once-only Qi Refining encounters raise Constitution, Spirit or Comprehension by 1. |
| WU-138 | world-ui | NPC label " (rival)" after the meeting (danger color while a realm ahead); Look says "Your rival.". |
| RIVAL-004 | systems | `Rivals.relation_text`; journal "Rival: <name>, <realm> (<relation>)" after the meeting, or "(fallen)". |
| QA-070 | qa | Curious sim takes bounties rated >= 70%: 3 listed in 120 months, all won; deeds listed 12, taken 0 (GUIDE-028, QA-075). |
| WU-125 | world-ui | HUD "Fair fight:" status line, cached, dropped first by the layout fit. |
| DLG-001 | systems | Dialogue condition `practice_pending`; Elder Mo's practise line for any fighting style. |
| GUIDE-026 | systems | `fair_fights` rates open chore fights (kind "deed"). |
| FOUND-002 | systems | `Injuries.chance`; `Guidance.breakthrough_risk_text` on the meditation attempt option. |
| RIVAL-003 | systems | `Rivals.first_meeting_due`, `rival_first_meeting` story event around day 10, `{rival}` in dialogue, `rival_met` flag. |
| WU-129 | world-ui | Inheritance attempt label names the next trial's need (`trial_note`). |
| WU-134 | world-ui | Breakthrough window: chance terms, risk, Take <pill>, pill source, Attempt / Not yet. |
| C-063 | content | Rank-0 fight missions >= 81% at their gate for a typical player (guard test; no data change). |
| C-077 | content | Four first-year encounters that train your technique; wandering boxer spar 70% at entry. |
| C-084 | content | A `description` for every realm (validated, < 220 chars). |
| QA-066 | qa | Foundation breakthrough sim: 45 days at the bottleneck, 2 attempts, 11/16 under 50%, no pill bought (300 vs ~170 stones). |
| QA-068 | qa | Per-test timing and "Slowest tests"; fuzz files run without HUD hints; unit suite 971 s -> 531 s. |
| QA-069 | qa | Default newcomer retries an open chore at >= 70%; seed 10 now wins on day 141. |
| QA-057 | qa | Not needed: C-063 changed no data, and QA-062 already re-ran the curious sim. |
| WU-126 | world-ui | `MissionBoard.ordered`: takeable fights by rating first, then other takeable missions, unavailable last. |
| WU-135 | world-ui | Breakthrough posts the lifespan and qi-rate gain; banner subtitle "Lifespan +N years" (`EventBus.breakthrough_details`). |
| QA-067 | qa | Fair-fights sim: median 1 listed fight a month; listed fights won 83/88 (94%) vs 98% rated. Bounties untested (QA-070). |
| GUIDE-023 | systems | `Guidance.fairer_fight_note`: loss advice names a fairer fight. |
| GUIDE-024 | systems | Mission hint counts a fight mission as ready only at >= 50% and says how many are too dangerous. |
| WU-133 | world-ui | Shop list ~60% of the panel; "(fighting style)" moves to the detail pane when a row would not fit (`ShopScreen.row_fits`). |
| FOUND-001 | systems | "Save for a <pill>" journal goal from Qi Refining 7th Layer; `Guidance.next_realm_pill`. |
| C-081 | content | Marsh corpse puppet bounty (Qi Refining 6th Layer, 40 stones, 69% at the gate). |
| C-079 | content | Not needed: grave guardian ape 49% and well bandit 77% at layer 1 (measured during C-081). |
| GUIDE-021 | systems | `Guidance.fair_fights` and the journal's "Fights you can win". |
| QA-065 | qa | `--trace`/`--seed` in simulate_first_hour; seed 10 lost the boar chore once and the default policy never retries (QA-069). |
| WU-127 | world-ui | `--style-shots` screenshot pass; shop rows ellipsize with a tooltip (wider list: WU-133). |
| RUMOR-003 | systems | Rumors take `about_inheritance` / `about_secret_realm` and go quiet once found, entered or past. |
| EFF-002 | systems | `practice_days` effect via `Techniques.train_best_combat`. |
| C-080 | content | Elder Mo's "practise" node; new dialogue condition `max_technique_level`. |
| WU-131 | world-ui | "Goal done" banner when a first goal ticks off. |
| QA-064 | qa | tests/sim/early_inheritances.gd: founder well 10/10 claimed, sword mound 6, fist saint 4, reed hut 0 (attribute trials block: C-082). |
| MENTOR-004 | systems | `same_sect_min_favor` (5) on pointers and spars from your own sect's seniors. |
| INH-001 | systems | Realm trials take `min_stage`; the Rotting Pier needs Qi Refining 5th Layer. |
| C-078 | content | A first fighting style for sale in every region with a merchant (marsh: Cloud-Parting Palm; ridge: Burning Cinder Fist). |
| WU-130 | world-ui | Banner when a technique levels up. |
| GUIDE-020 | systems | `Guidance.practice_hint`, `Techniques.practice_target`, a "Learn a fighting style" first goal, a practise nudge in loss advice. |
| QA-063 | qa | first_win_day/first_style_day in the first-hour sim: median first win day 14 (the headman's boar), curious first style day 39. |
| WU-124 | world-ui | `Banner.set_held`: banners queue while the combat report, respawn, tribulation or death screen is open. |
| WU-120 | world-ui | `Merchant.shows_manual_mark`: scroll mark over the merchant selling your first fighting style. |
| REF-001 | systems | `SectFactions.start_call` owns the sect-call flags; a call mission on cooldown posts nothing. |
| GUIDE-019b | systems | `first_combat_manual` skips lifespan-burning arts; body-art wording in the hint and loss advice. |
| MENTOR-003 | systems | Pointer refusals name the first fighting style, chats/gifts and a known like. |
| C-075 | content | Five rumors hint at the upcoming secret realms and inheritances (cannot hide yet: RUMOR-003). |
| QA-044 | qa | Pointers/spars add ~1 technique level and 2 wins by month 12, nothing by month 6 (MENTOR-004). |
| WU-123 | world-ui | Focus audit of gossip, friend's-price shop, notice banner, People request: no fixes needed. |
| C-070 | content | Help pages: gossip, friend's price, festival activities, qi-rich regions, first fighting style, secret-realm word, letters. |
| LETTER-006 | systems | Family letter kinds take `favor`; spouse and child letters give +2, capped. |
| QA-062 | qa | Curious sim buys and practises the first combat manual: pointers 0 -> 169 successful months, deaths 23 -> 22. |
| WU-119 | world-ui | Techniques screen shows the first-fighting-style hint while no combat technique is known. |
| C-074 | content | Hut of the Reed Hermit: Qi Refining inheritance in Withered Bone Marsh, year 3 (Drowned Reed Step). |
| LOG-001 | systems | A mission fight posts one "Sect mission: X. You face ..." line. |
| WU-116 | world-ui | First-hour screenshot pass (`--first-hour`), nothing clipped at 1280x800/720. |
| FEST-005 | systems | `festival_activity_here(stock_tags)`: festival activity only at fitting stalls. |
| GUIDE-019 | systems | `Guidance.first_combat_manual/first_combat_hint`; loss advice says when no fighting style is known. |
| WU-118 | world-ui | Shop rows say (fighting style)/(known); compare text names the technique; first manual in accent. |
| WU-117 | world-ui | No gossip window when hear_rumors refuses. |
| C-076 | content | Bounty pay: sword madman 220 -> 100, drunk bully 30 -> 20. |
| C-072 | content | Elder Mo's 'fighting' node points to Iron Fist at the Wandering Merchant and Stone Skin at the Azure Cloud shop. |
| QA-061 | qa | Bounty income sim for the drunk bully and Core sword madman: both pay well over gathering. |
| GIFT-002 | systems | Taste-hint favor in data/family.json, taste flags compared as ints, chat-hint test. |
| FEST-004 | systems | Festival goods only at merchants whose stock_tags meet the event's `stall_tags` (`WorldEvents.sold_by`). |
| QA-059 | qa | Log-noise sim: ~25 lines/month, no template over 4/month, no topic over 60/month. |
| WU-102 | world-ui | Shop header and map show a friend's price and days left. |
| WU-109 | world-ui | Map info and HUD region line name the active qi_flags reasons. |
| RUMOR-002 | systems | Shrug only without gossip, duplicate rumor ids reported, journal festival line says ask a merchant. |
| EFF-001 | systems | `Effects.validate`, set_flag/clear_flag lists, test walks every data effect block. |
| WU-111 | world-ui | Read-only Gossip window for merchant rumors; `hear_rumors` returns its lines. |
| WU-115 | world-ui | People list: "(asked for X, N days left)". |
| QA-060 | qa | pointer_reasons sim; gift policy fix; pointers blocked by favor 20 and no technique known. |
| WU-112 | world-ui | Screenshot pass; shop title wraps. |
| SECRET-003 | systems | `notice_days` and `SecretRealms.notice_news`: word a month before a realm opens. |
| C-069 | content | Peach Blossom Grotto opens in year 2; Mound of the Rusted Sword inheritance (year 2, Metal Edge Sword Art). |
| LETTER-005 | systems | Family living in the player's region do not write. |
| QI-002 | systems | qi_flags passed to best_qi_in_region, NPC and child cultivation. |
| WU-114 | world-ui | Notice banner + chime and "(opens in N days)" on the map. |
| C-068 | content | Planting the guardian's seed sets planted_guardian_seed (+10% Azure Peak qi). |
| MENTOR-002 | systems | Pointers min_favor 20 -> 10; "no technique" reason says find a manual. C-071 closed with it. |
| WU-100 | world-ui | Merchant menu "Float a lantern (festival)" while a festival activity runs here. |
| WU-108 | world-ui | Gift list marks the item from a told taste hint. |
| QI-001 | systems | Region `qi_flags`: deeds (the planted guardian seed) raise a region's qi density; meditation, HUD and map use it. |
| C-061 | content | Festival goods for Qingming and Mid-Autumn (Ancestor Incense toned down by the reviewer). |
| C-067 | content | Twelve rumors in data/rumors.json, every region, three realm-gated. |
| WU-106 | world-ui | "(likes N known)" on the sheet's People list (`Family.known_tastes`). |
| WU-107 | world-ui | Mission board's lost-fight line fades with the cooldown. |
| RUMOR-001 | systems | data/rumors.json and `Rumors.lines`: merchant gossip from data, gated by region, realm and flags. |
| QA-058 | qa | Save checks for letter requests and friend's prices. |
| WU-103 | world-ui | Focus audit: bounty board, letter answer, festival, gift tastes, people list. |
| C-066 | content | Four more letter kinds that ask for something. |
| LETTER-003b | systems | Request expiry under the family topic; letters answered only in the asker's region. |
| LETTER-002 | systems | Spouses and children away (and parents) write home (`from: family`). |
| SHOP-001 | systems | A merchant friend's letter gives a price cut in their region for a while (`shop_deals`). |
| QA-048 | qa | Curious sim tries crafting, work, gifts, spars, lectures, secret realms, travel; pointers never fire, months 13-36 bring nothing new. |
| WU-110 | world-ui | World map "Letter:" mark where an asker lives. |
| C-064 | content | Second Qingshi bounty; sword madman and rhino bounties gated higher. |
| FEST-003 | systems | Festival `activity` anyone can join once per festival (Lantern Festival), with an attribute bonus. |
| WU-099 | world-ui | NPC menu "Give <item> (they asked in a letter)", with the reason when you lack it. |
| C-059 | content | Yin King Gate Token: the Drowned Yin Palace needs it (marsh ferryman encounter or an auction lot). Rumor part moved to RUMOR-001/C-067. |
| QA-056 | qa | Save round-trip and fixture checks for renown, bounties, tastes, letters and festivals. |
| WU-101 | world-ui | "Look" names the gift tastes you have learned and the told hint. |
| NEWS-003 | systems | Named NPCs with dialogue files greet the renowned (shared 30-day flag with chat). |
| LETTER-003 | systems | Letter requests (`letters.kinds[].request`, `CharacterData.letter_requests`), answered in person, journal lines, expiry. |
| WU-105 | world-ui | "People you know" on the character sheet (top 6 by favor, family and dead excluded). |
| WU-104 | world-ui | The combat report opens with "Rated: ... before the fight." (not for spars). |
| C-060 | content | Misty Forest's second deep path: the old valley guardian and its seed (plant or swallow). |
| DANGER-001 | systems | "Risky" rating (50-70%) between Even and Dangerous, amber, help page and mission board text. |
| C-058 | content | Gift tastes (likes/dislikes) for every named NPC. |
| WU-095 | world-ui | "Lives N" on the HUD, warning at 1, "Final life" at 0. |
| QA-053b | qa | Bounty-hunter economy sim (Misty Forest bounty sized right) and refreshed combat/economy baselines. |
| WU-092 | world-ui | Bounty board hunts say "(here)" or "(N days away)". |
| NEWS-002 | systems | Renowned players are greeted when chatting (regions.json `renown.greetings`, once per NPC per 30 days, never family). |
| YEAR-003 | systems | Year review line for hidden places found, bounties claimed and regions mastered. |
| C-053 | content | Eight more letter kinds (rival, lecture elder, pill request, merchant, wedding, mourning, Dao hint, road tea). |
| FEST-002 | systems | Festival `shop_items` sold by the region's merchants (Moon Cake, Paper Lantern), marked "(festival)". |
| C-051 | content | Eight road encounters across the realms (fights 63-83% at entry). |
| QA-055 | qa | Rated odds match 500 real fights; the Mist Wolf deaths were genuine 30-43% losses. `EventBus.combat_started`. |
| WU-089 | world-ui | Gift list marks liked/disliked items and sorts liked first. |
| WU-097 | world-ui | Festival awnings beside merchants while a festival runs. |
| WU-096 | world-ui | Respawn screen names the pre-fight odds of the fatal fight and the recharge price. |
| RENOWN-003 | systems | Renown tiers raise bounty pay ("+N% for your name"). |
| WU-094 | world-ui | "A request for the renowned" window title and message prefix. |
| WU-093 | world-ui | Screenshot pass over journal, sheet, map, bounty board, shop, mission board; nothing to fix. |
| GIFT-001 | systems | npcs.json likes/dislikes: liked gifts worth more, disliked cost favor; taste flags and a chat hint. |
| BOUNTY-002 | systems | Boards list local, then neighbouring, then other hunts. |
| WU-088 | world-ui | Mission board says "You lost this fight N days ago." |
| WU-091 | world-ui | HUD status panel drops low-priority lines to clear the log; layout test at 100% and 115%. |
| QA-054 | qa | Curious sim avoids lost and Dangerous missions and recharges the artifact: early-ending seeds 10 -> 0, deaths 40 -> 20. |
| MISS-001 | systems | A lost mission fight cools the mission down 7 days (`loss_cooldown_days`), recorded in `mission_losses`, and says so. |
| RENOWN-002 | systems | Encounters may carry `min_renown`; two renowned requests (land dispute, wolf den). |
| GUIDE-018 | systems | Load recap names the hunt, the newest letter and the best renown title. |
| MAT-001 | systems | `Items.material_value` memoised per item. |
| WU-086 | world-ui | Warnings.final_death_warning on fights that could end the life; lives line says death is final at 0. |
| WU-081 | world-ui | Journal Letters section and a letter banner. |
| WU-084 | world-ui | Renown on the sheet, map, shop header, and a tier banner. |
| WU-090 | world-ui | Map says "Mastered"; region_mastered banner. |
| C-046 | content | A discovery in every region (Founder's Well, Buried Stall, Sword Scar, Lantern Cairn, Fallen Beast King). |
| C-052 | content | 11 bounties, every region posts at least one. |
| C-055 | content | Help pages: region familiarity, herb seasons, bounties, festivals. |
| C-050 | content | Data test: every discovery has a rumor that does not name it. |
| EXPL-003 | systems | `Exploration.mastered`: a fully known region is mastered (flag, message, Master of Many Lands milestone). |
| QA-052 | qa | Curious-sim death log: all 40 deaths in 10 seeds are the Mist Wolf cull mission, retried at 18-35% odds. |
| WU-083 | world-ui | Crafting screen lists ready recipes first with "(ready)". |
| WU-080 | world-ui | Arrival card waits for a road encounter; travel options say whether roads are quiet or busy. |
| TRAV-007 | systems | regions.json `travel_speed`: flying sword / riding the wind shortens journeys from Foundation. |
| GUIDE-017 | systems | `Guidance.craftable_now` / `workshop_place`: journal and HUD name a recipe you can craft now. |
| WU-074 | world-ui | World map: explored days, seen N of M happenings, when deeper paths open. |
| WU-082 | world-ui | Hunt line on the HUD, quarry note on Explore, "Bounty claimed" banner. |
| C-057 | content | Sunken Sword Tomb needs a map fragment (dying explorer encounter, auction lot). |
| NEWS-001 | systems | Major breakthroughs raise favor of known NPCs and own-sect reputation (family.json `breakthrough_news`). |
| QA-053 | qa | Part 1: `SaveManager.autosave_enabled`, sims never write autosaves (parts 2-3 still open as QA-053b). |
| WU-087 | world-ui | NPC labels lift apart, realm suffix only up close, prompt backdrop, inventory/fight log shrink to content. |
| TRAV-006 | systems | regions.json `road` block; `Exploration.road_encounter`; caravan fire and overturned cart. |
| RENOWN-001 | systems | Local renown per region: titles, buy discount, journal line, milestone. |
| C-047 | content | Qingming and Mid-Autumn festivals, festival_spring/autumn/winter encounters. |
| LETTER-001 | systems | Monthly letters from the best-liked NPC (gift, news, visit invitation); `CharacterData.letters`. |
| C-048 | content | A deeper path for every region (15-30 explore days). |
| QA-032 | qa | Rank-0/1 hunts and sect calls at min_stage 1: typical player wins 60-95% (test). |
| WU-077 | world-ui | tests/sim/screenshot_first_hour.gd: first-hour screens at 1280x800; nothing needed fixing. |
| WU-078 | world-ui | Explore options show days explored and when a deeper path opens; "Hidden path: <name>" window title. |
| WU-076 | world-ui | `bounty_board` place in Qingshi Village and Fallen Star Market: Hunt options with danger text, Abandon. |
| WU-072 | world-ui | Festival banner and chime, "Festival: <name>" on the HUD and map, "(festival: favor x2)" on Chat/Give gift. |
| BOUNTY-001 | systems | data/bounties.json (3), `Bounties`, take/abandon, the quarry's trail while exploring, Bounty Hunter milestone. |
| QA-051 | qa | Every recipe scroll has a known source (test); the bog lily scroll was already sold. |
| GUIDE-016 | systems | `open_deep_paths`/`deep_path_for`: an opened deeper path is announced and found on the next explore. |
| WU-079 | world-ui | Focus audit: encounter/discovery window, Controls page, log topic filter, sheet with a companion. |
| MS-005 | systems | `discoveries` life stat and the Seeker of Hidden Places milestone. |
| C-045 | content | Grade 5-6 weapons and armor with recipes and manuals from late foes or the smithy. |
| QA-049 | qa | tools/balance.sh economy 8 -> 2 min, `--section`, per-section timing (sims still write saves: QA-053). |
| EXPL-002 | systems | `Exploration.region_progress`, journal "seen N of M happenings", Wanderer of Many Roads milestone. |
| GUIDE-015 | systems | Region `discovery_rumor`; journal "Rumor:" line and merchant gossip until discovered. |
| WE-002 | systems | Festivals: world events with fixed `months`, `festival`, `favor_mult`; Lantern Festival in Qingshi. |
| WU-061 | world-ui | World map dims unvisited regions ("Unexplored"); travel says "(never visited)". |
| C-018 | content | Soul Formation people on Myriad Peaks Ridge (Xuan Moying, Lan Zhiyuan, Wen Qingxu) with errands. |
| EXPL-001 | systems | `explore_days`, encounter `min_explores`, `Exploration.familiarity/next_deep_path`; Misty Forest hidden valley. |
| C-049 | content | Myriad Peaks Ridge spring/winter herbs, autumn bog lily + Bog Lily Qi Pill, an autumn ridge fortune. |
| WU-075 | world-ui | Inventory "Richest in <Season> at <Place>" lines (`Exploration.seasonal_sources`). |
| QA-050 | qa | Discoveries survive save/load, old fixtures get the shrine once, realm-gated discoveries wait. |
| ENC-003 | systems | Met non-fight encounters fade (`encounter_counts`, `repeatable`); fight share unchanged. |
| WU-073 | world-ui | World map "Something here waits to be found" mark (gate-aware after the review). |
| WU-070 | world-ui | "Discovery: <name>" window title, chime and log prefix. |
| QA-046 | qa | Balance baseline refreshed; drift explained, no surprises (balance.sh ~9 min). |
| WU-068 | world-ui | ChoiceMenu refits on window resize and UI scale changes. |
| NS-007 | content | Soul Formation inheritance trials fight Soul Formation foes (entry 10-21%, peak 76-92%). |
| SEASON-003 | systems | `seasonal_gathers`, `seasons_gathered` stat, Herbalist of Four Seasons milestone. |
| TRAV-004 | systems | Sect `home_region` (validated), `Sects.home_region`; backfill visits only the home region. |
| TRAV-005 | systems | Region `discovery` / encounter `discovery_only`; Misty Forest hollow shrine on the first explore. |
| QA-047 | qa | First-visit lines survive save/load; old fixture backfills visited regions. No bugs found. |
| WU-071 | world-ui | HUD date line "(N days left)" near a season's end; season banner names in-season herbs. |
| SEASON-002 | systems | `Exploration.seasonal_highlights` / `season_news`; season-change line; journal "In season" lines. |
| GUIDE-014 | systems | `Guidance.unexplored_routes`; journal "Unexplored:" lines and a hint from day 10. |
| C-044 | content | Season-only herbs (summer forest, autumn bog, winter Frost Ledge) and two seasonal fortunes. |
| WU-069 | world-ui | Captures of the breakthrough effects and first-visit arrival card; no tuning needed. |
| ITEM-002 | systems | `Items.has_known_source` shares one scan with `sources`; every manual and pill has a source. |
| QA-041 | qa | Three curious years sim (`simulate_curious_years.gd`): median 2 kinds a month from month 7. |
| C-043 | content | First-visit lines for the other five regions; data test that every region has one. |
| WU-067 | world-ui | Gather sites name in-season and out-of-season herbs (`Exploration.seasonal_entries`). |
| REALM-002 | systems | Secret realm `entry_item` / `consume_entry_item`; journal "(needs <item>)". |
| WU-064 | world-ui | Arrival card says "First visit" and holds longer. |
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
