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
Next (planner 2026-10-15 06:10): 13 tasks landed (GUIDE-020/021, INH-001, EFF-002, MENTOR-004, RUMOR-003, WU-127/130/131,
C-078/080, QA-064/065). "From a style to a win" is nearly closed: the claimed GUIDE-023/024, WU-125/126/129, C-063 finish it,
and WU-132 screenshots it. QA-065: a newcomer who loses the headman's boar chore is never told to try again (GUIDE-026 puts
open chore fights into "Fights you can win"). QA-064: attribute trials block most early inheritances, and attributes never
grow (C-082). The reviewer says tools/test.sh takes ~15 minutes; QA-068 is now the qa top so every worker lands faster.
New theme **the road to Foundation**, the next big moment after the first win: save for the pill (FOUND-001), know the risk
(FOUND-002), a breakthrough window to take your pill and see the odds (WU-134, spec file), and what the new realm brings
(WU-135). QA-066 measures it; its numbers decide the balance tasks that follow.
| id | role | status | task |
|---|---|---|---|
| GUIDE-024 | systems | todo spec | The mission hint stops steering newcomers into deadly fights (QA-052/QA-062: the Mist Wolf mission is the top early killer, and `Guidance._mission_hint` (guidance.gd ~483) counts it as "ready" at any odds). Count a fight mission (one with an `enemy`) as ready only when `Combat.win_chance(c, data, enemy, 20) >= 0.5` (Risky or better; 20 samples to keep hints cheap); when some ready-by-rules fight missions are excluded, append " (%d more %s too dangerous for you yet)". If every mission is excluded, say "The sect's missions are too dangerous for you yet; practise your techniques first." Tests in tests/unit/test_guidance.gd: a bare Qi Refining 1st Layer disciple of a sect with the Mist Wolf mission sees it excluded; a strong Foundation character sees it counted. Check the time `tools/test.sh` takes does not grow noticeably (the hint runs often; if it does, cache by `c.realm_index`/`c.stage`/technique levels in a static dict). |
| GUIDE-023 | systems | todo | After a loss, a fight you can win (after GUIDE-021). In GameState, where a lost fight posts `Combat.loss_advice` (grep `loss_advice` in src/autoload/game_state.gd), append " A fairer fight: <text>." with the first entry of `Guidance.fair_fights(player, data, world_flags, GameClock.total_days, current_region)` when the list is non-empty and the lost foe is not that entry's foe. Keep the sentence builder static in Guidance (`static func fairer_fight_note(entries: Array, lost_enemy_name: String) -> String`) and unit-test it (empty list, same foe, different foe); one GameState integration test in tests/unit/test_game_session.gd: lose a fight with a fair mission available, the posted advice contains "A fairer fight". |
| GUIDE-026 | systems | todo spec | Open chore fights count as fights you can win (QA-065: the default newcomer lost the headman's boar chore at 82% on day 14 and was never pointed back; the chore stays open). *Spec:* src/core/systems/guidance.gd `fair_fights` (~908): after the sect missions and before the bounties, rate open deed fights in `region_id`: for each place in `data.regions[region_id]` places with `type == "deed_giver"` and a `deed_context` (skip it when its `hidden_by_flag` is set in `flags`), for each deed in `Deeds.available(data, context, flags)` that has an `enemy` and `Deeds.check(c, data, deed, flags, today) == ""`, call `_rate_fight(found, c, data, enemy, "deed", "%s: %s" % [place display_name, deed name])`, counting toward `FAIR_FIGHT_MAX_RATED` like missions. Update the doc comment (kind "mission" \| "deed" \| "bounty"). Check how regions expose places (grep `deed_context` in src/core) and reuse that accessor. Tests in tests/unit/test_guidance.gd: a Qi Refining 3rd Layer character with Iron Fist level 3 in qingshi_village with no flags gets an entry whose text starts "Headman Zhou: Drive off the wild boar"; with `chore_boar_done` set it is gone; a character too weak (Mortal, no technique) gets no deed entry. Acceptance: test.sh green; GUIDE-023 and WU-125 pick it up with no change. |
| FOUND-001 | systems | todo spec | Saving for the Foundation pill (the road to Foundation). Today the pill's source shows only at the bottleneck or after a failure (`Guidance.pill_source_hint`). *Spec:* src/core/systems/guidance.gd: (1) factor the item search out of `pill_source_hint` into `static func next_realm_pill(c: CharacterData, data: GameData) -> Dictionary` (the cheapest buyable breakthrough item for the next realm, {} if none or final realm); `pill_source_hint` keeps its exact output. (2) In `goals()` (~720), right after the "Reach <realm>" line, when `c.realm_index == 1` (Qi Refining) and `c.stage >= 6` (7th Layer+), no pill is held or taken (`c.breakthrough_pill == ""` and `breakthrough_items(c, data).is_empty()`) and `next_realm_pill` is not empty, add "Save for a <pill name> (+N percent): <price> stones, you have <stones>. <source>." where <source> is `Items.sources(data, id)[0]`; when stones >= price say "you can afford it now" instead of "you have N". Use `Text.a` the way pill_source_hint does if it reads better. Use "percent", not a percent sign (journal text forbids it). Only the next realm's pill; nothing for Mortal. Tests (tests/unit/test_guidance.gd): QR 6th Layer gets no line; QR 7th Layer with 20 stones gets the line with "you have 20"; with 400 stones "afford it now"; holding a foundation_establishment_pill: no line; Foundation Establishment character: no Qi Refining pill line (later realms are out of scope). |
| FOUND-002 | systems | todo spec | Know the risk before a breakthrough (the road to Foundation). *Spec:* (1) src/core/systems/injuries.gd: extract the chance math of `roll` (~33-34) into `static func chance(c: CharacterData, data: GameData, source: String, scale: float = 1.0) -> float` (clamped 0..1) and use it inside `roll` (same rng draws, so seeded tests stay identical). (2) src/core/systems/guidance.gd: `static func breakthrough_risk_text(c: CharacterData, data: GameData) -> String`: "" in the final realm, when not at the bottleneck, or when the next realm has a tribulation (`Tribulation.has_tribulation(data, c.realm_index + 1)`; the tribulation screen covers it). Else "If it fails, you lose <N> percent of your qi (about <qi lost, rounded, with Guidance._commas>) and have a <M> in 100 chance of an injury." from the next realm's `failure_qi_loss` and `Injuries.chance(c, data, "breakthrough_failure")`; drop the injury clause when M is 0. (3) src/world/interactables/meditation_spot.gd (~22): append it as a new line of the attempt option's description when not "". Tests: test_injuries (chance equals the old formula for fortune 10 and 15, and with a body-tempering resistance), test_guidance (QR 9th Layer at the bottleneck: text names 30 percent and the injury chance; a Core Formation bottleneck (tribulation): ""; not at a bottleneck: ""). |
| PERF-001 | systems | todo | Faster fair-fight ratings (after QA-068 names the cost). `Guidance.fair_fights` simulates up to 8 x 40 fights and runs from the journal, the HUD (WU-125) and the loss advice (GUIDE-023). If QA-068's timing shows `Combat.win_chance` among the slowest paths, cache its result in a static Dictionary keyed by enemy id + a cheap fingerprint of the player's fight stats (realm, stage, technique levels, equipment ids, buffs, injuries) with a size cap (clear at 256 entries); keep results identical for the same inputs. Test: two calls with the same character return the same value and the second does not re-simulate (count simulations through a static counter); changing a technique level changes the key. If QA-068 shows win_chance is not a hotspot, land only the measured numbers (a short note in docs/balance_baseline.txt) as `[PERF-001] Not needed: <numbers>`. |
| WU-125 | world-ui | todo spec | The best fair fight on the HUD (after GUIDE-021). *Spec:* one low-priority status-panel line "Fair fight: <text of Guidance.fair_fights(...)[0]>" in src/ui/hud.gd, added the same way as the region/hunt lines that WU-091 lets the layout drop first. `fair_fights` runs combat sims, so cache it: recompute only in a `_refresh_fair_fight()` connected to `EventBus.player_changed`, `session_started` and the day-change signal the HUD already uses for the season (not in `_process`). Hidden when hints are off (the same setting the hint lines honour) or the list is empty. Static builder `static func fair_fight_line(entries: Array) -> String` ("" for an empty list). Tests in the HUD test file: the builder for 0 and 2 entries; the WU-091 layout test still passes. |
| WU-129 | world-ui | todo | Inheritance trials say what they need up front (after INH-001). In the inheritance ground's menu (grep `inheritance` in src/world/interactables/), the attempt option and its disabled reason already come from `Inheritances.check_attempt`; add the next trial's requirement to the option label: realm trials "(needs <realm stage label>)", attribute trials "(needs <Attribute> <min>, yours <n>)", fight trials "(<enemy name>: <Combat.danger_label>)". Keep the logic in a static helper on the interactable (`static func trial_note(c, data, inheritance_id) -> String`) and test it for each test kind with the Reed Hermit hut. |
| WU-126 | world-ui | todo | The mission board puts fair fights first. In src/ui/mission_board.gd, order the mission list: missions you can take now, then by rating for fight missions (Weak, Even, Risky, Dangerous, Deadly via `Combat.label_for_chance(Combat.win_chance(...))`, compute each once per open), non-fight missions after takeable fights, unavailable ones last (keep data order inside each group). Keep the ordering in a static function (`static func ordered(c, data, flags, ids: Array[String]) -> Array[String]`) and test it: an Even fight sorts before a Dangerous one, an unavailable mission sorts last. Focus still lands on the first row (test_focus_audit). |
| WU-132 | world-ui | todo | Screenshot pass over "from a style to a win" (after GUIDE-021, WU-125, WU-126, WU-129; like WU-127). Shots at 1280x800 and 1280x720 with `tests/sim/screenshot_screens.gd`: the journal's "Fights you can win" section, the HUD with the fair-fight line and the goal line both present, the mission board ordered by rating, an inheritance ground menu with trial notes, the Wandering Merchant's scroll mark (WU-120). Fix small clipping only; list verdicts in the commit body and bigger problems under Follow-ups. Don't commit PNGs. |
| WU-133 | world-ui | todo spec | A wider shop list (WU-127 Follow-up: long manual names with a price and "(fighting style)" are clipped to an ellipsis). *Spec:* src/ui/shop_screen.gd: give the item list about 60% of the panel width instead of today's split (find the HBox/size_flags_stretch_ratio that sets it), and move the "(fighting style)" suffix out of the row text into the detail pane's first line when the row would still not fit at 1280x720 (measure with the row font's `get_string_size`; keep the suffix in the row when it fits). Keep the ellipsis + tooltip from WU-127 as the last resort. Test (tests/unit/test_shop_screen.gd or the existing shop test): at a 1280x720 viewport, the Wandering Merchant's Iron Fist manual row shows its full name and price (no ellipsis). Check with `tests/sim/screenshot_screens.gd -- --style-shots` at both sizes and list verdicts in the commit body. |
| WU-134 | world-ui | todo spec | The breakthrough window (the road to Foundation, after FOUND-002). *Spec:* [docs/specs/WU-134.md](specs/WU-134.md). A window before a Foundation+ breakthrough without a tribulation: the chance and its terms, the risk line, "Take <pill>" buttons for held breakthrough pills, the pill source when none is held, and Attempt / Not yet (focus never starts on Attempt). |
| WU-135 | world-ui | todo spec | What the new realm brings (the road to Foundation). *Spec:* src/autoload/game_state.gd `attempt_breakthrough` (~284): read `Cultivation.lifespan_years(player, data)` before the roll; on success post "Your lifespan grows to <new> years (+<gain>)." (progress) right after the "Breakthrough!" line when the gain is > 0, and tell the HUD: emit a new `EventBus.breakthrough_details(text: String)` signal ("Lifespan +80 years") before `breakthrough_attempted`; src/ui/hud.gd stores it and `_on_breakthrough` uses it as the banner subtitle when non-empty (then clears it), else today's text. Also in the same success branch, post the qi rate change: "Your qi gathers <x> times faster." from `Cultivation.qi_per_day` before/after, rounded to one decimal, only when the ratio >= 1.5. Tests (tests/unit/test_game_session.gd): a QR 9th Layer player at the bottleneck with a seeded rng that succeeds (or breakthrough_bonus 0.99) posts the lifespan line with the right numbers; a failed attempt posts neither line. |
| WU-136 | world-ui | todo | Focus audit of the newest windows (after WU-134; like WU-123): the breakthrough window, the mission board's new order (WU-126), the inheritance menu's trial notes (WU-129), the shop list (WU-133). Every button reachable by d-pad, focus on open, B/Esc closes; add any new window to tests/unit/test_focus_audit.gd's list. Fix small problems; list verdicts in the commit body. |
| C-063 | content | todo spec | The Mist Wolf mission is never Dangerous at its gate (three claims expired without landing; this is now a test-first task). *Spec:* (1) Add a test in tests/unit/test_sects.gd: for every sect mission with `min_rank` 0 and an `enemy`, build a typical player at its gate (the realm from `min_realm`, stage `min_stage`, with Iron Fist and Stone Skin at level 1, the way tests/unit/test_combat_balance.gd or tests/sim/combat_balance.gd builds a typical player; reuse its helper if one is callable) and assert `Combat.win_chance(c, data, enemy) >= 0.5`. (2) Run tools/test.sh. If it passes, commit just the test and say so. If a mission fails, raise only that mission's `min_stage` in data/sect_missions.json to the lowest stage that passes (do not touch enemies or `realm_training`) and list before/after in the commit body. Nothing else. |
| C-065 | content | todo | Festival activities (after FEST-003). Give qingming_festival and mid_autumn_festival an `activity` like FEST-003's Lantern one: Qingming "Sweep the ancestors' graves" (alignment +3, a little qi; bonus at Spirit >= 12: a whisper from the departed, small `breakthrough_bonus` 0.01), Mid-Autumn "Moon-viewing on the market roof" (qi; bonus at Charisma >= 12: a stranger's moon cake and favor... use items, e.g. 1 moon_cake). Small rewards, no stones beyond 5. Tests: data test that every festival has an activity. |
| C-077 | content | todo spec | Encounters that train your technique (after EFF-002). Add 4 once-only or long-cooldown encounters to data/encounters.json for the first year: Qingshi Village "An old soldier corrects your stance" (`practice_days` 5), Misty Forest "Wolf tracks in the snow" (winter; watch a hunt, `practice_days` 3), the road from Qingshi "A wandering boxer's challenge" (non-lethal fight you win ~70% with Iron Fist level 1, paste the simulate_combat.gd row; reward `practice_days` 7 on a win), Azure Peak "Disciples sparring by the stream" (`practice_days` 4, min_realm qi_refining). Text in the genre voice of nearby encounters; no stones. Tests: the data test that walks every effect block passes (EFF-001). |
| C-079 | content | todo spec | Layer gates on the first inheritances (after INH-001). Use `min_stage` on the realm trials of fist_saint_grave and village_founder_well so a typical player at the gate wins the final fight about 40%+ (`tools/godot.sh --headless --path . -s res://tests/sim/simulate_combat.gd` against grave_guardian_ape and well_bandit at QR stages 1-6; pick the lowest stage reaching 40%). Update the stage texts if they describe the gate. Paste before/after rates in the commit body. Test: the inheritance data test passes. |
| C-081 | content | todo | A Qi Refining bounty in the marsh (fair fights for rogues: GUIDE-021 lists bounties, and Withered Bone Marsh has only Foundation ones). Add one `min_realm` qi_refining bounty in data/bounties.json for withered_bone_marsh on an existing marsh enemy (or a new one in data/enemies.json in the style of the marsh's foes), with `min_stage` so a typical player (Iron Fist + Stone Skin) at the gate wins 60-80%; paste the simulate_combat.gd row. Pay like the iron_back_boar bounty (no more). Test: the bounty data test passes; a data test that every region with a qi_refining-gated encounter has a qi_refining bounty, if that holds after your change (else skip and say which region lacks one). |
| C-082 | content | todo spec | Attributes that can grow a little (QA-064 Follow-up: Constitution 11 blocks the Fist Saint's grave for 6/10 seeds, Spirit 11 blocks the Reed Hermit's hut for 8/10, Comprehension 10 blocks the Rusted Sword mound for 4/10, and attributes never change after creation). Keep the trial minimums. *Spec:* add 3 once-only encounters to data/encounters.json using the existing `attributes` effect (see the valley guardian's seed, `"attributes": {"fortune": 1}`): Misty Forest "A waterfall's weight" (stand under it for days: constitution +1, `days` 5, min_realm qi_refining), Withered Bone Marsh "A night among the reeds" (spirit +1, min_realm qi_refining), Fallen Star Market "A game of weiqi with a blind elder" (comprehension +1, a choice that needs nothing; the other choice declines). Each once-only (use the flag pattern other once-only encounters use), weight like the rarer encounters of its region so a player who explores the region a few months usually meets it in the first two years. Genre voice of nearby encounters; no stones. Tests: EFF-001's effect-walk test passes; add a test in tests/unit/test_encounters.gd (or the nearest data test) that each of the three exists, raises its attribute by exactly 1 and cannot repeat. Paste in the commit body how many months of exploring the region it takes on average to meet each (expected value from the weights). |
| C-083 | content | todo | Help pages for "from a style to a win" (after WU-125 and GUIDE-026; like C-070): add or extend pages in the help data (grep C-070's pages) for practising a fighting style (the practise hint, technique levels, the level-up banner), "Fights you can win" (journal, HUD line, what Even/Risky mean, open chores count), inheritance trials and their requirements (WU-129), and encounters that train your technique (C-077). Plain, short, second person. Test: the help data test passes. |
| C-062 | content | todo | Requests for the renowned (after RENOWN-002). One `min_renown` encounter per region besides the two RENOWN-002 wrote (Fallen Star Market, Azure Peak, Withered Bone Marsh, Myriad Peaks Ridge), once-only, fitting the region (a guild master asks you to escort a shipment; an elder of a minor sect asks you to judge a duel; marsh villagers beg you to end a corpse refiner; a ridge beast clan asks for a truce), gated at the region's realm, rewards about a week of the region's gather income plus favor/renown; any fight 45-75% at its gate (paste simulate_combat.gd rows). Tests: data test that every region has a min_renown encounter. |

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
| QA-068 | qa | todo spec | Make tools/test.sh fast again (reviewer, 13th run: the unit suite takes ~15 minutes on the cloud box, which slows every worker). *Spec:* (1) tests/run_tests.gd: time each test file and each test method (`Time.get_ticks_msec()`), and at the end print "Slowest tests:" with the 15 slowest methods and their ms (always, so future runs see it). (2) Run the suite once and paste the top 15 into the commit body. (3) Cut the top offenders without losing what they assert: fewer seeds or simulated days where the assertion holds with fewer (e.g. a 36-month sim asserting "no crash" can run 12), smaller `Combat.win_chance` sample counts in tests that only need a direction, shared setup built once per file instead of per method. Never skip, delete or weaken an assertion's meaning; if a slow test needs its length, leave it and say so. (4) Goal: the unit suite under 8 minutes; report before/after total time in the commit body. Name anything in game code that is the real cost (e.g. `Guidance.fair_fights` or `Combat.win_chance`) under Follow-ups (PERF-001 waits on it). |
| QA-066 | qa | todo spec | The first Foundation breakthrough (the next big moment after the first win; the curious sim reaches Foundation in years 2-3). *Spec:* in tests/sim/simulate_curious_years.gd (seeds 1-10, 36 months), record per seed: the day the player first reached Qi Refining 9th Layer's bottleneck (`Cultivation.is_at_bottleneck`), each Foundation breakthrough attempt (day, chance from `Cultivation.breakthrough_chance`, pill used if any, success, injury), stones on hand at the bottleneck, and the day of success (-1 if none). Print a per-seed table and the medians: days stuck at the bottleneck, attempts, and the share of attempts made with a pill. Add it as its own section of docs/balance_baseline.txt via tools/balance.sh. Follow-ups: if the median wait at the bottleneck is over 120 days or attempts are mostly below 50%, say what stops the player (no stones for the pill, no source, low odds) and the change you would make. No data changes. |
| QA-069 | qa | todo spec | The default newcomer tries a lost chore again (QA-065 Follow-up). *Spec:* tests/sim/simulate_first_hour.gd: in the default policy, once a month when the player is in qingshi_village and not injured, retry any headman chore with an `enemy` whose deed is still open (flag not set) when `Combat.win_chance` for its enemy is >= 0.7 (the "Even" line), the way the policy does the chores at day 0. Re-run seeds 1-10 (12 months) and update the first-hour section of docs/balance_baseline.txt; paste before/after first-win days in the commit body (seed 10 should now win). After GUIDE-026 lands, note in the commit body whether the chore also appears in `Guidance.fair_fights` for seed 10 when it is retried. No data changes. |
| QA-045 | qa | todo spec | Why is the first Foundation year so gentle? (QA-039 Follow-up: 107/120 runs spent no artifact life, median win share 100%, 0 injuries; DESIGN.md's QA-007 target is ~60-85% against a foe of your own realm and stage.) *Spec:* extend the QA-039 sim (tests/sim/simulate_foundation_year.gd or wherever it landed) with `--threats=slip|fight` (default slip, today's behaviour). For seeds 1-10 and both policies print per region: encounters met, fights fought, fights evaded via sensed threats, the median stage reached by month 3/6/12, and a histogram of the rated odds (Combat sim helper the combat baseline uses) of every fight actually fought (<50%, 50-75%, 75-95%, >95%). Answer in the commit body, with numbers: (a) are fights rare or just easy? (b) do C-031's stage gates leave only foes the player has already outgrown by the time they appear? (c) does the player outgrow the region within months (stage climbs fast)? List under Follow-ups the 3 data changes you would make (enemy ids or gate stages), without making them. Add the `fight` run as its own tools/balance.sh section and refresh only that section. Keep it under ~60 s. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates). *Spec:* reuse QA-039's sim with the realm as an argument (`--realm=core_formation`): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each region whose encounters include Core Formation fights (Myriad Peaks Ridge and any other; list them from data), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent (tribulation not included) and medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. If QA-045 has landed, include its `--threats` switch and odds histogram. |
| QA-035 | qa | todo | Economy sim: sect months every month (ECON-001b Follow-up). tests/sim/simulate_economy.gd only runs sect months every 12 months, so mission cooldowns never bind and sect income can't be compared fairly with profession work (still 1.5-1.9x for Doctor/Beast Tamer). Make the sim run the sect policy month by month (respecting `Sects.mission_cooldown_left`, duty, stipends) for a sect life, keep the same seeds, print per-profession "sect stones / work stones" ratios, update tools/balance.sh's baseline. If any profession's ratio is still > 1.5x, list the top 3 mission ids by net stones under Follow-ups (the planner files the content retune); don't retune data in this task. Also paste the economy section before/after ENC-003 (fading encounters; its commit skipped that comparison) and say whether income moved. Keep runtime under ~60 s. |
| QA-057 | qa | todo | Curious sim after C-063 (after C-063 and QA-062 land; skip the re-run QA-062 already did and only add what C-063 changed). Re-run tests/sim/simulate_curious_years.gd for seeds 1-10 and compare with QA-054's numbers (deaths 20, early-ending seeds 0): deaths, the death log's top 3 killers, and months to the first sect mission. If the Mist Wolf is no longer the top killer, name the new one with its rated odds at the fatal take. Refresh that tools/balance.sh section. Follow-ups: the data change you would make for the new top killer (no data change here). |
| QA-067 | qa | todo | Do "fights you can win" win? (after GUIDE-021): in the curious sim (tests/sim/first_hour.gd, 12 months, seeds 1-10) log each month's `Guidance.fair_fights` list; when the policy takes a fight that was on it, record the rated chance and the outcome. Print entries shown per month (median), months with an empty list, and the actual win rate of listed fights taken vs their mean rated chance. Follow-ups if the actual rate is more than 10 points below the rated one (sample size `win_chance` uses is 40). No data changes. |

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
|---|---|---|
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
