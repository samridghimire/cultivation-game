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
Next (planner 2026-10-24 00:15): 13 tasks landed (GUIDE-163/164/166/167, WU-351/353/354, C-216/238/240/243, QA-156/157).
Review f7ea31e removed a stray scratch .uid; its note (HUD trial line cut before the advice) -> GUIDE-169.
QA-156: the treasury method brings Foundation only ~8% sooner, so GUIDE-158 is unblocked and spec'd.
Live claims: GUIDE-165 (two branches, 23:35 and 23:46), GUIDE-168, WU-356, QA-158.
00:10 trace `simulate_curious_years.gd -- 1 36 --trace=97`: QR9 at m24, Foundation at m29 (71% with the pill), never
leaves Qingshi; m36: 1370 stones, 6998 contribution, Core Disciple trial 0 in 100. The Qi Refining Drunk Bully, old boxer
and widow's thief keep coming at Foundation (1-round wins, 3 stones) -> C-245. The Core Forming Pill goal says "As Elder
you could claim it", but Elder needs Core Formation (-> GUIDE-170). The rank goal says "you can seek promotion" at
0 in 100 (-> GUIDE-171). Trial advice and the defence hint both name the same treasury manual (-> GUIDE-172).
| id | role | status | task |
|---|---|---|---|
| WU-356 | world-ui | todo | (GUIDE-160 had no shot.) `--hint-shot` case `hint_missions_last_stage_<size>.png`: an Azure Cloud member at Qi Refining 9th Layer (the realm's last stage) whose every ready mission is too dangerous and whose combat style is mastered (or none left to practise), so the mission line ends "break through to Foundation Establishment first." Assert that text in the HUD/journal line and that it never says "grow a stage". Restore on close. Pngs at 1280x720/800. |
| WU-357 | world-ui | todo | (GUIDE-159 had no shot.) `--hint-shot` case `hint_trial_no_style_<size>.png`: an Azure Cloud member at Qi Refining 9th Layer who knows no combat technique, with a promotion trial open and hopeless, so `_trial_advice` says "learn a combat technique such as <name>" (GUIDE-159). Assert that text in the journal's trial line, that it never says "practise", and that the capped HUD line keeps "combat technique". Restore on close. Pngs at 1280x720/800. |
| WU-358 | world-ui | todo | The busiest map details still fit. `--map-shot` case `map_market_<size>.png` with Fallen Star Market selected and visited (most merchants: WU-253's "Sells:" line runs longest there) and, if it has an abode, unclaimed so WU-346's abode line shows too. Open the pngs at 1280x720/800: if the details text clips or overflows its panel, make the details label wrap/scroll (autowrap + a ScrollContainer or fixed height, keeping gamepad focus behaviour) and say in the commit what changed. |
| WU-352 | world-ui | todo | (After GUIDE-163.) `--hint-shot` case `hint_qi_two_spots_<size>.png`: Azure Cloud member at Foundation Middle in qingshi_village, ~2200 qi short of the next stage (seed-89 m36 shape), so the gather line names Spirit Spring here and Cloud-Sea Cliff in Azure Peak. Assert the line's first duration reads with " and " (e.g. "1 month and 21 days"), both place names appear, and the capped HUD line (`hud.cap_hint`) keeps "Spirit Spring". Restore on close. Pngs at 1280x720/800. |
| WU-355 | world-ui | todo | (After GUIDE-167.) `--hint-shot` case `hint_duty_<size>.png`: member with duty 18/30, 3 days left and a short ready mission paying >= 12 contribution -> the HUD duty line names that mission and "covers it". Second check in the same case: no mission fits -> the line says "skips this month's stipend". Restore on close. Pngs at 1280x720/800. |
| WU-359 | world-ui | todo | (WU-354 took no shot: the sheet case is a rogue.) `--sheet-shot` (or the existing character sheet case in tests/sim/screenshot_screens.gd) adds a member case `sheet_member_<size>.png`: Azure Cloud Inner Disciple with 6998 contribution to spend and 7400 lifetime, so the sect section reads "Contribution: 6998 to spend (lifetime 7400)". Assert that text in the sheet label; open the pngs at 1280x720/800 and say in the commit that the sect section fits. Restore on close. |
| WU-360 | world-ui | todo | (After GUIDE-169.) The hint_practice_target shot (WU-353) also asserts that the capped HUD trial line (`hud.cap_hint`) contains "Iron Fist", which GUIDE-169's new order makes possible. Re-take the pngs at 1280x720/800 and say in the commit that the HUD line shows the advice. |
| WU-361 | world-ui | todo | (GUIDE-164 had no shot.) `--hint-shot` case `hint_body_art_target_<size>.png`: Azure Cloud member at Foundation Peak with Iron Fist at `Techniques.typical_level(data, c.realm_index, "iron_fist")`, Stone Skin Tempering at level 1, armor worn, Core Disciple trial open and hopeless, so the journal's trial line says "practise Stone Skin Tempering to level N (now 1)". Assert that text and that the line never says "practise Iron Fist". Restore on close. Pngs at 1280x720/800. |
| GUIDE-169 | systems | todo spec | A too-hard trial line leads with what to do, so the HUD's 120-char cap keeps the advice (WU-353 Follow-up, review f7ea31e note). Spec: [docs/specs/GUIDE-169.md](specs/GUIDE-169.md). |
| GUIDE-170 | systems | todo spec | The breakthrough pill's rank clause never names a rank you can't reach before the breakthrough. Seed-97 trace m36 (Foundation Early, Inner Disciple, 6998 contribution): "Save for a Core Forming Pill (+25 percent): 3000 stones ... As Elder you could claim it for 3200 contribution." Elder needs Core Formation Middle (data/sects.json), the realm the pill is for. *Spec:* in guidance.gd `sect_pill_rank_clause` (~1497) return "" when the entry's rank (`(data.sects[c.sect["id"]] as SectDef).ranks[min_rank]`) has a `min_realm` whose `data.realm_index_of` is > `c.realm_index`. Then grep the other users of `sect_pill_entry`/`min_rank` (the journal, `sect_pill_claim`, GUIDE-155's goal) for the same "As <rank>" promise and apply the same rule. Tests in test_guidance.gd: Foundation Early Inner Disciple, Core Forming Pill entry at the Elder rank -> no "As Elder" clause; a QR8 Outer Disciple with the Foundation pill at Inner Disciple (no realm gate) -> the clause stays ("As Inner Disciple you could claim it for 250 contribution."). Acceptance: ALL CHECKS PASSED. |
| GUIDE-158 | systems | todo spec | A hint that the sect treasury hands out a faster cultivation method (QA-156: claiming it is only ~8% sooner to Foundation, so no owner call needed). Spec: [docs/specs/GUIDE-158.md](specs/GUIDE-158.md). |
| GUIDE-171 | systems | todo | The rank goal stops saying "you can seek promotion" when the trial is hopeless. Seed-97 m36: "Become Core Disciple: you can seek promotion at the sect hall. The trial: the Sword Pavilion Warden (Deadly, 0 in 100)." Find that goal (grep "you can seek promotion" in guidance.gd; GUIDE-154 added the trial clause). When `trial_odds(c, data)` is >= 0 and < 0.2, say "Become Core Disciple: you have what the rank asks, but the trial (the Sword Pavilion Warden, Deadly, 0 in 100) is beyond you yet." and keep today's text otherwise. Grep tests for the old opening first. Tests: odds 0.0 -> new text; odds 0.6 -> "you can seek promotion" stays. |
| GUIDE-172 | systems | todo | (After GUIDE-169.) The trial advice and the thin-defence hint stop naming the same treasury manual twice. Seed-97 m36 hints: "Your defence is thin. Claim Manual: Stone Skin Tempering from your sect treasury (45 contribution, you have 6998)..." and the trial line "...learn a body technique such as Stone Skin Tempering and wear armor first: Manual: Stone Skin Tempering (your sect treasury, 45 contribution)". In `_trial_advice`'s GUIDE-152 branch (or `_trial_lever` after GUIDE-169), skip the ": <source>" part when `c.realm_index == THIN_DEFENCE_REALM` and `_body_manual_treasury(c, data)` is not empty (the defence hint, which `hints` always shows in that state, already names it). Keep "such as Stone Skin Tempering" so WU-345's shot assertion holds. Tests: Foundation member, no body art, treasury sells Stone Skin -> trial advice has no "(your sect treasury"; rogue with a merchant source -> the source stays. |
| GUIDE-173 | systems | todo | The mission line says what else a mission pays. Seed-97 m36 (6998 contribution unspent): "The best pays 80 contribution: Cull the Mist Wolves (5 days), ..." while that mission also gives 100 qi, and others give 75-350 stones (data/sect_missions.json `rewards`). Where the line is built (grep "The best pays" in guidance.gd), after "N contribution" add the mission's other rewards: " and N spirit stones" for `rewards.items.spirit_stone`, " and N qi" for `rewards.qi` (both when both; nothing for alignment/reputation/other items). Keep `best_mission`'s ranking unchanged. Tests in test_guidance.gd: a member whose best mission is cull_mist_wolves -> "80 contribution and 100 qi"; deliver_cold_iron -> "and 75 spirit stones"; escort_mortal_villagers (no stones/qi) -> unchanged. Grep tests and the `--hint-shot` cases for the old "pays N contribution:" text first. |
| GUIDE-165 | systems | todo spec | (Review 2950dde note on GUIDE-161.) The treasury heal keeps the Foundation pill claim. `_heal_source_for` (guidance.gd ~683) suggests claiming a treasury heal whenever `Sects.check_purchase` passes, even when that leaves too little contribution for the Foundation pill claim GUIDE-132/137 point at. *Spec:* find how GUIDE-137 reserves the claim (grep `sect_pill_claim`, `sect_pill_entry` and "reserve" in guidance.gd) and reuse that test: while the pill is still to claim, skip a treasury heal when `Sects.contribution_balance(c) - heal_cost < pill_cost` and fall through to the clinic/other sources exactly as today. Tests in test_guidance.gd: balance 300, Meridian Mending Pill 100, pill claim 250 still to claim -> no treasury clause; balance 400 -> treasury clause; pill already held or used -> treasury clause at 300. Acceptance: ALL CHECKS PASSED. |
| GUIDE-168 | systems | todo | The realm goal names the faster spot. Seed-89 trace m36: "Reach Core Formation: about 12 years of meditation, then a breakthrough" for a Foundation Middle Azure Cloud member at Qingshi's Spirit Spring (2x), while the sect's own Cloud-Sea Cliff in Azure Peak (5x, 10 days away) would make it about 5. In the goal line (guidance.gd ~2840): when `best_qi_reachable` (the spot GUIDE-128's `far_qi_offer` uses) cuts the remaining days to the next realm by >= one year net of the round trip, add " (about <format_rough> at <place> in <region>)" before ", then a breakthrough". Tests: Qingshi member at Foundation Early -> goal names Cloud-Sea Cliff; same player standing at the cliff -> no clause; a Qi Refining 1st Layer player (saving < 1 year) -> no clause. Same spot and math as the gather line, so no pacing change beyond GUIDE-128's (QA-145). |
| C-245 | content | todo spec | Qi Refining village beats stop at Qi Refining. Seed-97 trace: at Foundation (360 hp) the Drunk Bully Disciple (`village_drunk_bully`, a QR2 foe, 1-round wins) came at m31 and m35 after m9/m21/m25/m27; the old boxer (`village_old_boxer_spar`, QR2 spar) at m15/m19/m26/m34; the widow's thief (`village_thief_caught`, 3 stones) at m17/m22/m24. *Spec:* in data/encounters.json add `"max_realm": "qi_refining"` to those three, the way C-234/C-236 capped `village_lost_coin` and the mortal-foe fights (read those commits: `git log --oneline -- data/encounters.json | grep -E "C-234|C-236"`). Then list every other `village`/`city`-tagged encounter whose enemy is Qi Refining tier or whose only reward is <= 5 stones or a common herb and that has no `max_realm`; cap the ones a Foundation cultivator would plainly outgrow and paste the list (capped / kept and why) in the commit. Check that Qingshi still offers Foundation players enough beats: count the village encounters a Foundation Early player can meet before/after (a scratch test or the exploration sim) and paste both numbers; if fewer than 6 remain, say so under Follow-ups. Update any test that pins these encounters at Foundation. Acceptance: ALL CHECKS PASSED. |
| C-241 | content | todo | (After WU-351.) Help: the HUD/interface page in data/help.json adds "Sect members see their contribution next to their spirit stones; spend it at the sect treasury on the mission board." Check against WU-351 on main. |
| C-242 | content | todo | (After GUIDE-167.) Help: the sect page adds "Near the month's end, if your duty falls short, the hint names a mission that covers it. Missing the duty only skips that month's stipend." Check against GUIDE-167 on main. |
| C-246 | content | todo | (GUIDE-164 is on main.) Help: the practice paragraph C-243 added in data/help.json also says "If your combat style is already trained that far, it names your body art instead." Check against GUIDE-164's `_body_art_below_typical` wording; update help tests that pin the page. |
| C-244 | content | todo | Alchemy orders that cannot be filled. Seed-89 trace: "The order for 3 Bone-Setting Salves lapsed. You were short o..." (m11) and "The order for 3 Spirit Gathering Pills lapsed" (m15) for a Qingshi Alchemist. For each recipe a rank-0/1 Alchemist gets orders for (data/recipes.json + PROF-001/PROF-012's order rules in src/core/systems/professions.gd), list its ingredients and whether each is gatherable in qingshi_village (data/regions.json gather places, seasons) or sold by the Wandering Merchant there. Paste the table in the commit. For a recipe with an ingredient neither gatherable nor sold in Qingshi, lower its order count to 1 or keep it out of rank-0 orders the way PROF-012 does (data only if a field exists; otherwise a Follow-up). |
| C-204 | content | todo | (QA-135 Follow-up.) Talisman Master income: the crafter sim now shows d365 592 stones (30 crafts a month) against Array 176, Blacksmith and Beast Tamer lower. Compare the per-craft margin (sell price - bought ingredient cost, and gathered-ingredient days) of the first three Talisman recipes with the first three of the other crafts (tests/sim/crafter_start.gd output, `tools/balance.sh --section 'crafter crafts'`). If Talisman's margin per day is > 2x the next best, raise one ingredient's need or lower one sell price so it lands within 1.5x, and refresh that baseline section; otherwise change nothing and say why the sim's number is fine. |
| C-247 | content | todo | (After GUIDE-158.) Help: the sect treasury page says "When the treasury hands out a method that gathers qi faster than yours, the hint names it once you can spare the contribution (it keeps enough for your breakthrough pill)." Check against GUIDE-158 on main. |
| QA-155 | qa | todo spec | Does following the body-art hint fix the Foundation trial? (18:10 trace seed 79: the curious sim never spends contribution, so "Your sect treasury sells Manual: Stone Skin Tempering for 45 contribution" shows from m06 to m36 with 511-1869 contribution, and at Foundation Peak the Core Disciple trial is 5 in 100.) *Spec:* add `--body-art` to tests/sim/first_hour.gd (and the `play_cached` memo key): when the thin-defence or treasury line names a body-art manual the player can buy (sect treasury with contribution, or a merchant here with stones), buy it, learn it (GameState action), and give it the practice time the sim gives the combat style. Run `simulate_curious_years.gd -- 10 36` with and without `--body-art` and print per seed: the day the art was learned, Core Disciple trial odds at the first month it opens (or m36), fights lost and injuries in months 13-36. Answer in the commit: median trial odds with/without, and whether the art alone lifts it over 50 in 100 (QA-125's breakdown, if landed, says which other piece matters). Sim only. |
| QA-160 | qa | todo | (QA-157 Follow-up: `tools/balance.sh --check` was red on main in the curious sections before QA-157 refreshed them.) Run `tools/balance.sh --check` on main. For each section that differs, find the landed commit that explains it (`git log` on the files the section's sim reads) and refresh only sections whose diff is explained by a landed change; list any unexplained diff under Follow-ups with the section name. Then add a short note to docs/AGENTS.md or the CLAUDE.md worker loop step 5 (whichever already mentions balance.sh; if neither, CLAUDE.md step 5) that workers touching data/*.json or guidance text run `tools/balance.sh --check` and refresh the sections their change explains. |
| QA-158 | qa | todo spec | The rogue path, three curious years without a sect. Every trace joins Azure Cloud in month 1 (tests/sim/first_hour.gd ~155 joins the first accepting sect), so the rogue playthrough DESIGN.md's first pillar promises is unmeasured. *Spec:* add `static var stay_rogue := false` to first_hour.gd (and to `play_cached`'s memo key, as QA-150/152 did) that skips that join loop; `--rogue` in simulate_curious_years.gd (also with `--trace=`) and simulate_first_hour.gd sets it. Run `simulate_curious_years.gd -- 10 36` base vs `--rogue` and print per arm: QR9 median day, seeds at Foundation by m36 and the Foundation median day, stones at m12/m36, fights won/lost, artifact lives spent, final deaths. Then `-- 1 36 --trace=89 --rogue`: paste its month lines m12/m24/m36 and the final "Hints now"/"Goals now" block in the commit. Follow-ups: any advice a rogue gets that only a sect member can act on, any 3+ month stretch with no new kind of action, and any lever a rogue lacks that a member has (pill claim, lecture, treasury body art) with what replaces it. No balance changes here; base output must not change. |
| QA-159 | qa | todo | (GUIDE-156 Follow-up.) What do 120 rating samples cost in play? Extend tests/sim/profile_days.gd (or add `--hints` to it): build a Foundation Middle Azure Cloud member in Qingshi (seed-89 m36 shape: Iron Fist, Stone Skin, 7773 contribution, Core Disciple trial open), clear `Combat._chance_cache` (as after a stage-up or technique level) and time `Guidance.hints(...)` with the HUD's arguments, plus `Guidance.journal(...)` if that is a separate call; print ms cold and warm and `Combat._sim_count` per call. If a cold refresh takes > 50 ms here, list the callers that rated the most matchups (count per enemy id) as Follow-ups, e.g. odds computed for missions the line never names. No change outside tests/sim. |
| QA-124 | qa | todo | (QA-111 is on main: reuse its `_walk_for_order`.) The crafter sim buys where the hint points (GUIDE-076 Follow-up: tests/sim/crafter_start.gd only buys in the region it stands in, but the buy hint now names a market up to two routes away). When the buy hint names another region and the crafter can afford paper + the recipe's stones, travel there (GameState travel, days pass), buy, travel back. Re-run `-- 10 365 --prof=talisman_master` and `--prof=array_master` starting in misty_forest (`--region=` if the sim has it; add it if not): never-crafted seeds and crafts per seed, before/after. Refresh only the crafter crafts sections that changed. |

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
| GUIDE-135 | systems | blocked | (After QA-148; its Follow-ups decide the wording and reserve.) A hint to spend sect contribution ("Spend contribution: the sect treasury sells Superior Qi Gathering Pills for 40, about N days of meditation each (you have 1346)."), mirroring GUIDE-126's `qi_pill_offer` (usable qi only, keep the breakthrough pill's contribution while it is still to claim). If QA-148 flags a large pacing change (QR9 > ~30% sooner), this task becomes blocked on the owner (F-005d) instead; the planner will say which. *Planner 12:15: QA-148 says it is: contribution qi pills put 10/10 seeds past QR9 by month 12 (base 2/10). Blocked on F-005d; QA-150 measures a capped version for the owner.* *Planner 16:15: QA-150: cap 2/month ~12% sooner, cap 4 ~19%; proposed default for the owner is a 2-a-month hint.* |
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
| QA-156 | qa | Sim `--sect-method`: claiming the x1.6 treasury method (~day 900) brings the Foundation median only ~8% sooner; GUIDE-158 unblocked. |
| GUIDE-166 | systems | `Techniques.is_faster_method` replaces `MissionBoard.is_faster_method` (no behaviour change). |
| C-216 | content | Help: the world map lists a visited region's merchant goods and claimable abode. |
| GUIDE-164 | systems | Practice advice names the body art's target level when the combat style is already at its typical level. |
| C-243 | content | Help: from Foundation the practice hint names the typical level ("to level N (now M)"). |
| C-238 | content | Moon-Ridge Elk (Foundation stage 0, non-lethal, typical player 79%) for the fold's "Keep watch". |
| WU-354 | world-ui | Character sheet: "Contribution: M to spend (lifetime L)" for members. |
| C-240 | content | Three one-shot Foundation encounters in Qingshi (newborn, the Peak rogue's plea, the humming well); beggar child stops at Qi Refining. |
| WU-353 | world-ui | `--hint-shot` hint_practice_target: journal trial line names "practise Iron Fist to level 5 (now 2)"; HUD cap cuts it (-> GUIDE-169). |
| WU-351 | world-ui | HUD status shows "Spirit Stones: N   Contribution: M" for members (`HUD.currency_line`). |
| GUIDE-167 | systems | The sect duty reminder names the mission that covers it, or that missing it skips the stipend. |
| GUIDE-163 | systems | Durations join with "and" ("1 month and 21 days", "1 year, 2 months and 3 days"). |
| QA-157 | qa | Curious sim claims the Foundation pill with contribution when it can; baselines refreshed. |
| WU-311 | world-ui | Closed as a duplicate: WU-253 already shows "Sells: <merchant>: <goods>" on the world map (WU-346's worker). |
| WU-346 | world-ui | World map details for a visited region name an unclaimed cave abode, its price and qi. |
| GUIDE-162 | systems | From Foundation, practise advice names the typical level ("practise Iron Fist to level 5 (now 2)"); `Techniques.typical_level`. |
| GUIDE-160 | systems | The missions-too-dangerous line at a realm's last stage ends "break through to <next realm> first." |
| C-239 | content | Help: the sect treasury hands out the sect's own method; its row compares qi rates. |
| C-235 | content | Help: hopeless trials point at the treasury body art; the abode hint names place, price and qi. |
| GUIDE-156 | systems | RATING_SAMPLES 40 -> 120 (200 made the sim 2.7x slower); ratings within 5 points of 2000 samples. |
| WU-350 | world-ui | `--hint-shot` hint_abode: journal and capped HUD line name the Waterfall Cave and its price. |
| WU-349 | world-ui | `--hint-shot` hint_heal_treasury: the HUD names the treasury Meridian Mending Pill, never the clinic. |
| WU-348 | world-ui | Treasury and shop method rows show qi xN through <realm> vs yours, tagged "(faster qi)". |
| GUIDE-161 | systems | The injury hint names the cheapest claimable sect-treasury heal before the clinic. |
| C-237 | content | The hopeful youths' sect-hall choice also gives renown 1, so it pays a rogue too. |
| GUIDE-159 | systems | Trial advice for a fighter with no combat technique says learn one (naming the first manual). |
| WU-347 | world-ui | `--hint-shot` long-sect case repaired (den wolf mission put on cooldown); the full run passes. |
| C-236 | content | village_boar and city_alley_thugs stop at Qi Refining; audit test guards mortal home fights. |
| QA-125 | qa | Foundation entry gap, one lever at a time: practised techniques +55..68 points, gear second; Stone Skin L1 alone does nothing. |
| RV-015 | content | den_wolf power_mult 0.5, attack -1: a bare QR1 newcomer rates 65% on Drive Off the Den Wolves. |
| GUIDE-152 | systems | Trial advice at a last stage names the missing body art or armor instead of "grow a stage". |
| GUIDE-157 | systems | The thin-defence line leads with the treasury body art when contribution pays for it. |
| GUIDE-153 | systems | The abode hint names the abode, its price, travel days and whether it gathers qi faster. |
| GUIDE-154 | systems | The rank goal appends the trial foe and its odds. |
| GUIDE-155 | systems | The pill-saving goal adds what selling materials here would bring. |
| C-231 | content | Help: the one-life recharge hint and the fights-to-the-death rule. |
| C-233 | content | village_lost_coin stops at Qi Refining; three repeatable Foundation village encounters. |
| C-234 | content | Audit: forest_herbs stops at Foundation; test that no small-change repeatable lacks max_realm. |
| WU-339 | world-ui | `--missions-shot` missions_low_lives: Cull the Mist Wolves warns it could be the end. |
| WU-342 | world-ui | `--artifact-shot`: one life opens Lives & Anchors with recharge focused. |
| WU-343 | world-ui | `--shop-shot` recharge warning at one life, none at three. |
| WU-344 | world-ui | `--missions-shot` den wolf hunt is Weak (98%) for a bare newcomer. |
| WU-345 | world-ui | `--hint-shot` hint_trial_peak: Stone Skin Tempering named, no "grow a stage". |
| QA-154 | qa | Hinted missions after GUIDE-148/RV-015: 0/20 final deaths, 16 lethal losses vs base 15. |
| QA-153 | qa | `--rating-check`: rated odds are honest by band (gaps <= 4.3 points); 40 samples err 2.1 points on average, 9-11 on Mist Wolf matchups. |
| GUIDE-149 | systems | The unaffordable-clinic clause adds the sell-loot clause when selling covers the gap. |
| GUIDE-150 | systems | `qi_pill_offer` reserves the price of the armor the armor line names (`armor_hint_price`). |
| GUIDE-148 | systems | `Guidance.fight_floor`: 0.5 non-lethal, 0.7 lethal, 0.9 lethal at low lives; missions, healed_wins and outgrown_hint use it. |
| WU-338 | world-ui | `--hint-shot` hint_low_lives: the lives line leads, no spare-stones line. |
| C-223 | content | The Senior's Test pays 15 contribution to sect members, win or lose. |
| WU-341 | world-ui | `ShopScreen.recharge_warning`: a buy that leaves less than the recharge price at low lives is flagged. |
| C-232 | content | `drive_off_den_wolves`: a non-lethal first hunt (typical player 85%; bare newcomer 0%, see RV-015). |
| QA-152 | qa | `--deaths/--recharge/--hint-missions`: 0/20 final deaths by m12 (base), 1/20 with hint missions; lethal losses are Mist Wolf missions, median rated 72%. |
| WU-340 | world-ui | Gold "!" beside Lives when the lives line leads; the artifact screen opens on Lives & Anchors with recharge focused at low lives. |
| WU-337 | world-ui | Repaired the two failing `--hint-shot` asserts (mastered Iron Fist on the shot character, undone on close). |
| GUIDE-147 | systems | At low lives the recharge line leads `hints()` and `qi_pill_offer` keeps the recharge price. |
| QA-151 | qa | Far-qi trip: 78% of post-move fights >= 95%, no extra injuries or deaths; worth about one Foundation stage at m24/m36. |
| WU-336 | world-ui | `--hint-shot` hint_thin_treasury: the thin-defence line names the sect treasury, capped line keeps its opening. |
| WU-331 | world-ui | `--hint-shot` hint_clinic_short: capped clinic line keeps price and "(you have 19)", clinic gold marker. |
| GUIDE-146 | systems | `Guidance.outgrown_hint`: when every home fight is >= 95%, name a 40-85% fight one route away. |
| PERF-005 | systems | Single-region fuzz profiles walk only their region (secret-realm 14.7 -> 4.8 s, promotion trial 18.1 -> 4.5 s). |
| C-230 | content | Help: the secret realm hint names where, the cost and how long it is open. |
| WU-334 | world-ui | `--hint-shot` far-qi case asserts the world-map hint mark (run-time load of the map script). |
| WU-335 | world-ui | `--hint-shot`: `show_journal` lambda becomes the member method `_show_journal`. |
| QA-147 | qa | First-hour sim `--odds-bands`: no month is stably "always easy" in year one; Misty Forest rogue 8% at m12. |
| WU-333 | world-ui | `--breakthrough-shots` bs_d_sect_claim: the window says "Claim a Foundation Establishment Pill". |
| GUIDE-145 | systems | The secret-realm hint names where it is, entry cost and days open (reviewer: free re-entry kept). |
| WU-332 | world-ui | `--hint-shot` hint_sect_herbs: no "Use your Spirit Herb", Core Disciple rank line, mission name kept. |
| GUIDE-144 | systems | The thin-defence line names the sect treasury first when it can pay for the body art. |
| C-226 | content | Help: injuries heal with time; the hint names the clinic price. |
| C-229 | content | Help: the sect treasury sells body arts. |
| INJ-001 | systems | `Guidance.injury_news`: a new injury's multipliers, duration and heal source as a second danger line. |
| GUIDE-138 | systems | The injury hint names an unaffordable clinic's price "(you have N)". |
| QA-150 | qa | `--qi-pill-cap=N`: cap 2/month keeps QR9 within 15% of base, cap 4 within 30%; uncapped 10/10 seeds at QR9. |
| GUIDE-143 | systems | Hint: the sect treasury sells a body art you can buy now (`Guidance.treasury_body_art_hint`). |
| GUIDE-141 | systems | The rank line says when the next rank also needs a realm ("... and reach Foundation Establishment"). |
| GUIDE-140 | systems | The Use-your-herb hint leaves partial stacks a sect deliver mission needs (`Sects.deliver_needs`). |
| WU-329 | world-ui | `--hint-shot` herb-away and road cases set up for today's hint order; both pass at 720/800. |
| C-228 | content | Black Ferry Ringleader bounty in Qingshi for QR 8th-9th layers (50%/53% with Iron Fist L5, 70 stones). |
| C-225 | content | No injury retune: QA-149 shows first-breakthrough injuries are rare (1 seed in 20). |
| C-227 | content | Help: a sect disciple can claim the breakthrough pill for contribution. |
| QA-149 | qa | First-hour sim `--injury-origins`: 3/20 seeds hurt in 120 days (1 by breakthrough, 2 by fights). |
| WU-330 | world-ui | The breakthrough window names the sect pill claim (`Guidance.sect_pill_rank_clause`). |
| WU-309 | world-ui | `--hint-shot` long sect case: the capped sect line keeps the mission name. |
| QA-145 | qa | First-hour sim `--far-qi`: following the far-qi offer brings QR9 median day 872 -> 568, Foundation in 6/10 seeds by m12. |
| GUIDE-137 | systems | The qi-pill hint keeps the stone reserve while the sect pill claim is not yet affordable. |
| C-224 | content | Help: the sect treasury sells the Foundation Establishment Pill from Inner Disciple. |
| PERF-004 | systems | First-hour tests share sim runs (test_first_hour.gd 41 s -> 21 s). |
| WU-326 | world-ui | `--travel-shot` busy-region case: Fallen Star Market road notes stay within 90 characters. |
| EFF-001 | systems | A `contribution` effect key for sect members (rogues get nothing). |
| WU-328 | world-ui | The sect treasury opens on, and marks, the breakthrough pill the claim goal names. |
| WU-325 | world-ui | Guard test: no NPC label overlaps a place label; moved five npc spots/NPCs. |
| C-222 | content | Help: each road names the qi and places at its far end. |
| WU-323 | world-ui | `--hint-shot` far-qi case: the Travel line leads, capped, with road marker and map region. |
| QA-148 | qa | First-hour sim `--spend-contribution`: contribution qi pills put 10/10 seeds past QR9 by m12 (base 2/10); owner call (F-005d). |
| GUIDE-133 | systems | `Guidance.sell_offer` passes world flags to `deliver_needs`. |
| GUIDE-132 | systems | The goals point an Inner Disciple at the breakthrough pill in the sect treasury (`sect_pill_claim`). |
| WU-327 | world-ui | The sect treasury details say what a qi pill is worth (`MissionBoard.shop_detail_lines`). |
| C-221 | content | Help: qi differs by region, the hint says when to travel. |
| C-220 | content | Help: spare stones buy qi pills, keeping enough for the breakthrough pill. |
| QA-20261023-2 | qa | Three seed-sensitive tests made deterministic under TEST_SEED_SALT. |
| GUIDE-130 | systems | Out-of-season herbs no longer read "grows here" on the board and in deliver hints. |
| WU-320 | world-ui | The qi worth line says when only part of a pill's qi fits before the breakthrough. |
| WU-321 | world-ui | The meditation spot names the faster spot elsewhere (`far_qi_offer` line). |
| GUIDE-129 | systems | "Wanted by the sect" lines name only missions blocked just by items (`Sects.only_items_missing`). |
| C-218 | content | Salt-Road Captain bounty in Qingshi for the QR 5th-7th layers (57% at QR5, 90% at QR7 with Iron Fist L3). |
| GUIDE-131 | systems | The Use-your hint counts only qi that fits before the bottleneck (`Guidance.usable_qi`). |
| GUIDE-128 | systems | The Gather line leads with the trip when a far spot saves 30+ days (`Guidance.far_qi_offer`). |
| WU-324 | world-ui | Guard: no two place labels overlap in any region (none did; the WU-317 overlap is an NPC label). |
| QA-146 | qa | First-hour sim prints contribution (m12 median 1346), stage at m12, bottleneck stones and bounties. |
| C-217 | content | Two Qingshi encounters for the QR 5th-7th layers (The Cart in the Ford, The Senior's Test). |
| WU-319 | world-ui | Each road says the qi at the other end and, once visited, what is there (`TravelPoint.destination_note`). |
| GUIDE-126 | systems | Hint: spare stones buy qi pills, keeping the next realm pill's price (`Guidance.qi_pill_offer`). |
| GUIDE-119 | systems | Sell all loot keeps what your sect's deliver missions need (`Sects.deliver_needs`). |
| PERF-003 | systems | Fuzz tests no longer inherit HUD hints (fuzz 299 s -> 158 s, test.sh 9m16); runner prints slowest files. |
| C-219 | content | Meditation labels state the total qi (Cloud-Sea Cliff 5x, Heaven-Facing Ledge 8x, Yin Gathering Altar 2.9x). |
| QA-140 | qa | Curious sim sells loot and buys armor where the hint points: armor barely changes first-year fights (GEAR-001). |
| C-212 | content | Help: the clinic says how many days of cultivation each treatment saves. |
| GUIDE-127 | systems | Headline guard: every canonical hint's action ends before `HEADLINE_CHARS` (`test_hint_actions_fit_headline`). |
| C-208 | content | Help: the mission board marks the best-pay mission. |
| WU-317 | world-ui | First-hour pngs re-audit: nothing clipped; only transient prompt/toast overlaps (no code change). |
| WU-318 | world-ui | The shop selects and marks the item the HUD's first hint names. |
| GUIDE-125 | systems | Idle, practise and thin-defence hints lead with the action. |
| WU-315 | world-ui | A capped HUD hint shows its full text as a tooltip on hover. |
| QA-144 | qa | `--buy-qi`: spare stones on qi pills bring QR3 16% and QR9 13% sooner (GUIDE-126 next). |
| WU-314 | world-ui | The shop's Buy tab says what a qi item is worth in meditation. |
| C-215 | content | Help: mission board requirement colours and the shop's sell warning. |
| WU-316 | world-ui | The world map marks the region the HUD's first hint points to (gold "!"). |
| C-211 | content | Help: chance choices and what a failed attempt costs. |
| WU-313 | world-ui | `--hint-shot` asserts the capped clinic and sell-armor lines keep their action. |
| GUIDE-124 | systems | The Gather line names the better meditation spot in the region you stand in. |
| QA-134 | qa | Curious sim takes the mission the sect hint names (`--one-mission`): more fights, no faster Inner Disciple. |
| GUIDE-123 | systems | Spar practice matches the hint's practice_days (no code change needed beyond the test). |
| GUIDE-121 | systems | Sect and trial hints lead with the action; `Guidance.HEADLINE_CHARS`. |
| GUIDE-122 | systems | Injury, gather and armor hints lead with the action (only their tails are cut now). |
| C-207 | content | Help: a slow stage's hint names a better meditation spot. |
| C-206 | content | Runaway mule, Old Alchemist's Notes and the wolf-lunge test are chance checks; failure costs days, never life. |
| WU-310 | world-ui | Mission board requirement lines in colour (met green, unmet red); `--missions-shot` deliver case. |
| QA-143 | qa | `--long-hints` tallies hint lines over the HUD cap (sect, trial, armor, injury, gather lines lost their action). |
| WU-312 | world-ui | The shop's Sell tab says when a sect mission wants the item. |
| GUIDE-118 | systems | The use-your-herb hint leaves the herbs a ready sect mission wants. |
| C-214 | content | Help: deliver missions show held counts; the Inventory marks wanted items. |
| C-213 | content | Help: a long hint ends with "… (J)"; press J for the whole line. |
| QA-142 | qa | Balance baseline refreshed: stale, not nondeterministic (curious QR3 200 -> 213, QR9 606 -> 689). |
| REV-030 | systems | Stone tithes are not "close" below half; ores read "found at". |
| WU-303 | world-ui | Sell-all confirmation lists the cultivation items it keeps. |
| QA-141 | qa | Curious sim skips missions under 40 in 100 (`--blind-missions`): injuries halved, ~2 fewer Inner Disciple promotions. |
| GUIDE-117 | systems | The open-trial clause says what one more level of the best unmastered style would do (`Guidance.trial_practice_payoff`). |
| WU-308 | world-ui | Inventory details: "Wanted by the sect: <mission> (N for C contribution)" (`InventoryScreen.wanted_by_sect_line`). |
| WU-305 | world-ui | HUD hint lines are capped at 120 characters with "… (J)"; the journal keeps the full text (the cap hides the action: GUIDE-121/122). |
| C-210 | content | Help: deliver missions show in your hints with how many you hold. |
| WU-302 | world-ui | `--clinic-shot`: the clinic menu with one and two injuries fits at 720/800. |
| GUIDE-120 | systems | The deliver clause names the mission with the fewest missing units you cannot gather here, and where a missing item grows. |
| GUIDE-115 | systems | Sell all loot keeps what feeds your cultivation (`Items.feeds_cultivation`). |
| WU-306 | world-ui | Mission board: deliver missions read "<name> (x/y)" and requirement lines say where the item grows (`Guidance.gather_place_for`). |
| C-209 | content | The drunk bully fights like a drunk (`power_mult` 0.6): 0% -> 78% for a QR 2nd-4th layer newcomer with Iron Fist L1/L2. |
| TOOL-001 | systems | `tools/godot.sh` imports the project on first run, so sims work in a fresh container. |
| WU-301 | world-ui | `--hint-shot` passes again (best-pays and far-qi cases set up for today's hints). |
| QA-138 | qa | Curious sim spars when the hint names a partner (`--no-spar-hint`): 10 bouts, no faster first year (spar gain vs hint: GUIDE-123). |
| WU-300 | world-ui | Check choices' results say whether the check passed (`Exploration.check_verdict`); `--encounter-shot` check cases. |
| PERF-002 | systems | `tests/sim/profile_days.gd`: a simulated year is ~1.1 s (NPC `_live` ~63%), no single cost to cut; no code change (next: PERF-003). |
| C-203 | content | Help: what a friendly spar is worth. |
| GUIDE-108b | systems | One practise advice reaches the game: `_merge_practise_advice` returns the PackedStringArray. |
| C-205 | content | The single herb_hall_tithe row has the spec's description (finished by the reviewer, dd14454). |
| DATA-001 | systems | GameData reports duplicate ids per data file (`_check_unique_ids`). |
| GUIDE-110 | systems | A safe mission on cooldown reads "ready again in N days", not "too dangerous". |
| GUIDE-112 | systems | The spar hint says what a bout is worth (`Mentorship.spar_terms`). |
| GUIDE-111 | systems | Deliver missions you are close to are named with "you have x of y" (pick: GUIDE-120). |
| GUIDE-113 | systems | A slow stage names the faster meditation spot in the same line, only when the trip pays. |
| GUIDE-114 | systems | One sell advice, not two (`_merge_sell_advice`). |
| ENC-008 | systems | Encounter choices may carry a chance `check` with an `on_fail` outcome (content: C-206; UI: WU-300). |
| ENC-009 | systems | Non-lethal forced fights below `sense_below_chance` (0.2) are sensed, with a choice to slip away. |
| WU-294 | world-ui | A label hidden after a spread drops its screen lift. |
| WU-295 | world-ui | `--bounty-shot`: Fallen Star Market bounty board fits at 720/800. |
| WU-296 | world-ui | Inventory details show what a qi item is worth in days of meditation. |
| WU-297 | world-ui | `--hint-shot` NPC badge case; the badge matches NPCs named by realm (the WU-288 case fails: WU-301). |
| WU-298 | world-ui | `--missions-shot` shows a "(best pay)" mission at 720/800. |
| WU-299 | world-ui | The clinic says how much cultivation each treatment saves (`Injuries.qi_days_lost_for`; shot: WU-302). |
| C-202 | content | Help: a resting mission's hint says when it is ready. |
| QA-139 | qa | The 2 in 100 drunk-bully fight is data, not a bug (no power_mult: C-209); `--forced` tally in the first-hour sim. |
| QA-128 | qa | Curious sim heals (items, then clinic; `--no-heal`): 8 treatments, Inner Disciple median day 692 vs 746. |
| C-201 | content | Tithe to the Herb Hall: an Azure Cloud deliver mission for 3 Spirit Herbs (35 contribution, 22 stones); it landed twice (duplicate id: C-205, DATA-001). | 
| PERF-001 | systems | NPC menus: `Guidance.first_combat_manual` memoised by (data, region, realm, alignment); mentor options ~300 ms -> < 1 ms. | 
| C-199 | content | Help: eat qi herbs and pills from the Inventory. | 
| WU-293 | world-ui | The HUD hint badge also shows when the first hint names only an NPC (`Interactable.region_marker_names`; shot: WU-297). | 
| C-200 | content | Drive Off the Fog-Antler Stag: an Azure Cloud hunt mission from the QR 5th layer (57/80% at the 5th layer with Iron Fist L2/L3). | 
| QA-136 | qa | Curious sim attempts open sect trials at >= 70% odds (`--no-trial`): Inner Disciple within a year in 2/10 seeds; most trials open at Even/Weak odds. | 
| WU-292 | world-ui | The road wears the hint marker only when a route leads toward the hinted region. | 
| WU-241 | world-ui | `--inherit-shot` adds the Terrace of the Last Stair; menu and journal fit at 720/800. | 
| QA-137 | qa | Sim and old-age test loops skip the monthly autosave: the slowest tests 1.5-3 s faster each; test.sh ~7 min (next: PERF-002). | 
| WU-291 | world-ui | The mission board marks the hint's best mission "(best pay)" and selects it first (`MissionBoard.label_for`; shot: WU-298). | 
| GUIDE-108 | systems | One practise advice, not two (helper only: it does not reach the game, GUIDE-108b). | 
| GUIDE-104 | systems | Open sect trial at 0 in 100: no change (QA-133: the injury, already explained by GUIDE-092). |
| C-189 | content | Help: missions and bounties show your odds; "to the death" can kill. |
| C-194 | content | Help: Next steps hints name the best-paying ready mission. |
| WU-290 | world-ui | `--missions-shot`: mission board list and Ranks tab at 1280x720/800; odds labels fit. |
| GUIDE-107 | systems | Sect hints name the hall and where it is (`_hall_where`). |
| QA-135 | qa | Crafter baselines refreshed after QA-130 (Talisman d365 592 stones, Array 176; C-204 reviews Talisman income). |
| WU-289 | world-ui | `--hint-shot` road marker, route note and clinic badge cases at 720/800; fit. |
| GUIDE-109 | systems | The use-your-herb hint says how much qi and how many days of meditation it is worth. |
| C-198 | content | Two QR 7th layer+ encounters: an elder's carriage, a hunted spirit fox. |
| C-197 | content | The Mist Python (QR 7th layer+): enemy, Misty Forest bounty and encounter. |
| QA-133 | qa | The open trial's 0 in 100 at QR 9th layer was Broken Bones; GUIDE-092 already says so. |
| WU-288 | world-ui | `--hint-shot` best-mission sect line: wraps in the journal at 720/800. |
| WU-287 | world-ui | Bounty board and tournament entries show odds (`UIStyle.odds_text`; Fallen Star Market shot: WU-295). |
| GUIDE-106 | systems | The unexplored-road hint says how far and whether you can win there. |
| C-188 | content | Help: the road out wears the gold marker when the first hint names another region. |
| WU-285 | world-ui | spread_on_screen skips undrawn labels; drawn_label_rect includes the hinted "!" badge (the 1280x720 re-shoot moved to WU-289). |
| C-195 | content | A first-year forest bounty: the Fog-Antler Stag (QR 5th layer+, new non-lethal foe, 54/74% at the 5th layer with Iron Fist L2/L3). |
| GUIDE-103 | systems | At a realm's last layer the qi lines speak of "the Foundation Establishment breakthrough" (Guidance._next_step_name). |
| QA-132 | qa | Fuzz test calls each option once (labels with digits masked): fuzz file ~275 s -> ~148 s, more options reached. |
| GUIDE-105 | systems | The too-dangerous missions line says heal first / grow a stage first / practise <style> first. |
| WU-286 | world-ui | Mission board Defeat/trial/list lines show odds like encounter choices (UIStyle.odds_text). |
| GUIDE-102 | systems | The sect hint names the best ready mission ("The best pays N contribution: <mission>"); Guidance.best_mission. |
| GUIDE-101 | systems | The far-clinic clause names the way ("by way of ..."). |
| QA-130 | qa | Talisman Master's empty purse was a crafter-sim policy bug (bought other crafts' ingredients); fixed, d365 stones 0 -> 376. |
| WU-284 | world-ui | The HUD's first hint wears the gold "!" when it names a place in the region. |
| WU-283 | world-ui | The road out wears the hint marker when the first hint names another region; the route toward it says "The hint points this way." |
| C-191 | content | Two road encounters for the middle QR layers: a caravan guard job (new non-lethal caravan_raider) and a fallen rogue's satchel. |
| C-186 | content | Closed by the planner, no change: QA-130 found a sim policy cause, not data. |
| C-158 | content | Terrace of the Last Stair: a Tribulation Transcendence inheritance in Azure Peak (arbiter 44% at the gate). |
| GUIDE-099 | systems | The empty Fights-you-can-win note says "heal your injuries first" when healing would open a fight. |
| GUIDE-100 | systems | Far-shop lines say "by way of <region>" when the route is not direct (`Guidance._far_where`). |
| C-182 | content | Help: encounter fight choices show odds; rival duels never kill. |
| WU-282 | world-ui | `--encounter-shot` result cases clear queued popups first. |
| WU-281 | world-ui | Labels pushed together by the screen-edge clamp stop overlapping (`Interactable.spread_on_screen`; 720 re-shoot: WU-285). |
| GUIDE-097 | systems | The trial clause says "grow a stage first" when every combat style is mastered. |
| GUIDE-098 | systems | `Guidance.first_hop` and `hinted_region`: which road the hint points down. |
| QA-131 | qa | Crafter baselines refreshed (Talisman Master crafts 46 -> 61, d365 purse 79 -> 0). |
| GUIDE-096 | systems | An open sect trial is always kept in Fights you can win. |
| WU-277 | world-ui | Encounter fight choices show odds (`EncounterWindow.fight_suffix`). |
| GUIDE-093 | systems | The stipend clause says "an" before a vowel. |
| C-187 | content | Misty Forest encounters: spilled herb basket, snared wolf cub (QR 3rd layer+). |
| GUIDE-094 | systems | The idle-cultivation hint replaces the "Gather N more qi" line. |
| GUIDE-095 | systems | The practice payoff is rated unhurt. |
| C-185 | content | Help explains the gold "!" marker. |
| QA-20261022-1 | qa | Mentor menu tests find the spar entry by NPC name (self-filed fix; slow fuzz test: QA-132). |
| C-184 | content | Qingshi encounters: an outer disciple's chore swap, an old boxer's spar (QR 3rd layer+). |
| ENC-007 | systems | Encounter choices carry `chance`/`lethal` (`Exploration.choice_foe`, rival fights via `people`). |
| GUIDE-092 | systems | The trial hint says "Your injuries hold you back: healed, you would win about N in 100" (`Guidance.odds_unhurt`). |
| GUIDE-090 | systems | The thin-defence hint counts what your loot would sell for. |
| WU-280 | world-ui | A gold "!" marks the place the HUD's first hint names (`Interactable.hinted_names`, `HUD.first_hint`). |
| WU-279 | world-ui | `--techniques-shot --payoff` pngs: the "At level 2 you would beat ..." line fits at 720/800. |
| WU-278 | world-ui | Labels draw on a z_index 10 layer; places and NPCs spread together (well/NPC overlap at the screen edge left: WU-281). |
| WU-276 | world-ui | `--encounter-shot` covers `village_boxing_yard` and `forest_hunter_wolf_lunge` (popup over the log: WU-282). |
| WU-271 | world-ui | `--hint-shot` cases for the open sect trial and the "Sell your ..." armor line. |
| C-181 | content | Help: injuries slow cultivation and weaken you in fights (also C-183). |
| C-183 | content | Help: when a fight looks hopeless, check whether healing first would win it (landed with C-181). |
| C-180 | content | Help: a promotion trial is a spar that can injure but never kills. |
| C-177 | content | Ascent-Warden Arbiter `power_mult` 0.95: late gate 77% -> 87%. |
| QA-129 | qa | First-hour curious baseline refreshed: QR3 day 239 -> 200, fights lost 4 -> 3. |
| QA-127 | qa | Crafter sim takes odd jobs when the hint says so: no Array seed stays stuck; Talisman purse still ~0 from d180 (QA-130). |
| QA-111 | qa | Crafter sim `--walk` for order herbs: walking does not raise the delivered share (trips cost more than orders pay). |
| GUIDE-089 | systems | The open-trial stipend sits inside the sentence (fixed by review a616a41; no worker commit). |
| C-176 | content | Help: a fighting style's first levels come quickly; the "Practice to level N" button. |
| C-179 | content | Six helping choices in Fallen Star Market and Azure Peak give renown 3. |
| WU-274 | world-ui | Focus audit for the Techniques screen: no gaps. |
| WU-272 | world-ui | First-hour pngs re-run: edge labels whole; the well label overlaps an NPC and "Sect" hides behind the workshop (WU-278). |
| GUIDE-088 | systems | The armor hint counts what your loot would sell for (`sell_offer`, `budget`). |
| WU-270 | world-ui | Techniques details show "At level N you would beat a <foe> ..." (pngs: WU-279). |
| GUIDE-078 | systems | The buy-ingredient hint warns when buying makes the craft barely pay. |
| GUIDE-085 | systems | The open sect-trial hint gives your odds (`Guidance.trial_odds`). |
| GUIDE-091 | systems | The injury hint says how much cultivation waiting costs (`Injuries.qi_days_lost`). |
| QA-126 | qa | First-year 0% fights came from the sim accepting rival duels and hopeless bounty hunts blind (67 -> 4); encounter odds on screen: ENC-007/WU-277. |
| GUIDE-086 | systems | The practice hint names the fight the next level opens (`Guidance.practice_payoff`). |
| WU-273 | world-ui | --techniques-shot case; Practice button visible and focused at 720/800 and 115%. |
| GUIDE-087 | systems | "Fights you can win" lists an open sect trial (kind "trial"). |
| C-173 | content | Help's Injuries and Healing page names the clinics and salves. |
| WU-268 | world-ui | --hint-shot hint_long: practice days, far-qi distance and stipend lines wrap at 720/800 (the open-trial wording: GUIDE-089). |
| QA-122 | qa | Crafter sim buys only when it can also pay the recipe's stones; Array seeds 4/5 never craft on a 10-stone purse (QA-127). |
| WU-269 | world-ui | World labels are clamped inside the visible screen (pngs not re-run: WU-272). |
| GUIDE-084 | systems | The sect-rank hint says what the next rank pays. |
| WU-267 | world-ui | Techniques screen: "Practice to level N (X days)" button; the mastery line shows the days (pngs: WU-273). |
| GUIDE-083 | systems | The better-qi hint says how far the spot is (Guidance.route_days). |
| C-178 | content | Two first-hour encounters that train your fighting style (boxing yard, hunter's wolf lunge). |
| QA-123 | qa | --practise sim: Iron Fist level 3 by month 3, but ~70 days later QR3 and no earlier Mist Wolf win. |
| CMB-011 | systems | Optional per-enemy `power_mult` (0.5-1.5) scales hp/attack/defense; validated; no enemy uses it yet (C-177). |
| GUIDE-081 | systems | The practice hint says how many days the next level takes (`Techniques.days_to_next`). |
| C-172 | content | Help explains an empty "Fights you can win" and that paying fights are listed first. |
| QA-119 | qa | Crafter sim counts road encounters: an in-village crafter meets none (road_talisman_peddler 0/10 seeds); QA-124 puts it on the road. |
| C-163 | content | Minor Spirit Gathering Array 6 -> 3 stones: never-crafted Array seeds 4 -> 2 of 10. |
| WU-262 | world-ui | First-hour screenshots at 720/800: nothing clipped in windows; the combat report no longer covers later shots (world-edge labels: WU-269). |
| WU-258 | world-ui | --hint-shot: empty fair-fights note and far-armor line fit in HUD and journal. |
| WU-266 | world-ui | tt_pill_b_hint after WU-257: the HUD shows the wrapped pill hint at 720/800; no code change. |
| QA-121 | qa | Foundation +60 days: 0/9 seeds rated >=50% vs their foes even with --defence (injuries, no body art); QA-125 follows heal + body art. |
| WU-265 | world-ui | World map: the Sells line is above the fold at 720/800; no UI change. |
| GUIDE-082 | systems | The far-market armor hint reads as two sentences. |
| WU-264 | world-ui | Focus audit: the world map keeps focus and its details follow the region; no bug. |
| GUIDE-077 | systems | The injury hint looks past the first injury and checks a far clinic's cost. |
| WU-260 | world-ui | The shop says where weapons and armor are sold when it sells none (`gear_elsewhere_line`). |
| C-170 | content | Help says helping travellers and villagers raises renown. |
| WU-263 | world-ui | --shop-shot: Heavenforge Smithy "(upgrade)" tags fit at 1280x720/800; no UI change. |
| WU-256 | world-ui | The world map puts "Sells:" above "Places:" (pngs not re-run: WU-265). |
| WU-257 | world-ui | The HUD keeps a short hint (first sentence + "(J)") instead of hiding them all (pngs not re-run: WU-258/WU-266). |
| C-175 | content | Helping choices of four Qingshi/Misty Forest encounters give renown 3. |
| QA-120 | qa | Late realms after CMB-010: no foe crossed wall -> free; late forced arbiters 48-79%; rival baseline refreshed. |
| GUIDE-076 | systems | The buy-ingredient hint names the nearest market that sells the bought-only ingredient. |
| GUIDE-080 | systems | The Foundation goal ladder asks for a body art and armor. |
| GUIDE-074 | systems | An empty "Fights you can win" says why (thin defence, or practise your style). |
| C-171 | content | Ascent-Warden Arbiter forced fight 96% -> 77% (stage 1; finer knob: CMB-011). |
| GUIDE-075 | systems | The armor hint names the nearest market that sells armor (shared _far_armor_clause). |
| GUIDE-073 | systems | Hints quote the price the shop will charge (sect reputation and renown applied). |
| GUIDE-072 | systems | The thin-defence hint points to the nearest market (Guidance.nearest_selling, 2 hops) when this region sells no armor or body manual. |
| C-159 | content | Help says crafting orders fit what you can gather nearby, and Old Quarry Tailings yields iron. |
| C-164 | content | No change needed: gathered Talisman income is already 2.02/day, bought 0.19 (C-159's check). |
| WU-254 | world-ui | The shop's "(upgrade)" mark weighs every equip stat (none lower, one higher). |
| WU-255 | world-ui | --encounter-shot: the carver's helping choice shows "+5 renown" in the HUD log; fits. |
| WU-253 | world-ui | The world map's region details say what each merchant sells (Guidance.merchant_goods/market_lines). |
| QA-116 | qa | Curious sim follows the thin-defence hint (--defence): rogue at Foundation won 2/8 -> 13/23; 9/9 seeds travelled for gear. |
| CMB-010 | systems | Late realms' Peak is winnable again (Body Integration/Mahayana/TT Peak 49/34/20% -> 76/76/78%). |
| GUIDE-069 | systems | A Qi Refining fighter (stage 3+) with no armor hears about an affordable one sold here. |
| WU-240 | world-ui | --pill-shot: the Heavenly Tribulation Pill window and no-pill hint (the hint is too tall for the HUD; WU-257). |
| QA-117 | qa | Crafter sim follows the buy hint: Talisman never-crafted 2 -> 0/10; Array still 4/10 (purse, C-163). |
| C-169 | content | Help says Qingshi sells no gear and Fallen Star Market (ten days) does. |
| C-167 | content | Road encounters' helping choices raise renown (carver 5, cart 3, lost child 3/5). |
| WU-252 | world-ui | --hint-shot: buy-ingredient and longest thin-defence lines fit (HUD hides hints while injured; WU-257). |
| GUIDE-070 | systems | "Fights you can win" lists paying fights first (bounties listed 2 -> 12). |
| RV-QA-115 | qa | Balance baseline refreshed (small RNG drift only; no flagged rows). |
| C-168 | content | Help says where bought-only ingredients (talisman paper) come from. |
| QA-113 | qa | Peak curve sim: late realms fall off (Body Integration Peak 49%, Mahayana 34%, TT 20%); proposal -> CMB-010. |
| WU-248 | world-ui | Body-art manual rows in the shop say "(defence)". |
| GUIDE-071 | systems | The injury hint says where to heal (owned item, clinic here, merchant, nearby clinic). |
| ENC-006 | systems | Encounter effect `renown` raises local renown in the current region. |
| WU-250 | world-ui | --encounter-shot covers C-166's road encounters; nothing clipped. |
| QA-118 | qa | Road encounters fire for the curious player (27/30 seeds in 36 months); the plain policy never travels. |
| GUIDE-068 | systems | The thin-defence hint names a merchant's armor and a body-art manual source; Qingshi sells no armor. |
| WU-249 | world-ui | Repeated HUD log lines collapse into one with (xN). |
| C-157 | content | Heavenly Tribulation Pill: Tribulation Transcendence breakthrough pill, recipe and auction scroll. |
| WU-251 | world-ui | Focus audit for the road talisman peddler. |
| QA-112 | qa | Late gates sim covers Tribulation Transcendence (only forced TT fight wins 39%; five lethal hunters 0-1%, all slippable). |
| WU-244 | world-ui | The shop marks upgrades: "(upgrade)" on affordable better gear, accent colour on body-art manuals at Foundation+. |
| C-165 | content | Help explains defence at Foundation (body art, armor, heal first). |
| C-166 | content | Three road encounters in the first hours: talisman peddler, milestone carver, rain shelter. |
| WU-243 | world-ui | --hint-shot: the thin-defence and idle-crafter lines fit the HUD and journal (no UI change needed). |
| GUIDE-066 | systems | A crafter out of a bought-only ingredient hears where to buy it (Guidance.buy_ingredient_hint, merchant_selling). |
| GUIDE-067 | systems | goal_ladder_id and goal_ladder read the late ladders from REALM_GOAL_TABLE. |
| WU-246 | world-ui | --first-hour adds workshop, shop, journal and mission board on day 1 and month 1 at Steam Deck sizes; all fit. |
| WU-247 | world-ui | Focus audit: the shop upgrade row buys with ui_accept; an empty crafting screen keeps focus. |
| C-156 | content | The Verdant Remnant gives the Blood Demon Pill scroll instead of a second Visceral Mending one. |
| GUIDE-065 | systems | A thin-defence Foundation cultivator hears about body arts and armor (names only what is missing). |
| GUIDE-062 | systems | One generic realm goal ladder (REALM_GOAL_TABLE) for soul/void/body/mahayana/tribulation. |
| C-161 | content | Three late inheritance guardians wait a stage (win% at the gate 8-11 -> 31-42). |
| WU-242 | world-ui | --tt-foes: the Lightning-Tithe Sovereign threat prompt, lost fight and log fit. |
| QA-114 | qa | Foundation entry gap: the curious player lacks a body art, armor and healing (rogue 0% vs typical 82%). |
| WU-239 | world-ui | Focus audit: Tribulation bell with its gate missed and the Door Ajar grounds menu. |
| PROF-016 | systems | An order short only of spirit stones says so. |
| PROF-017 | systems | Crafting margin wording moves to Alchemy.margin_line. |
| WU-236 | world-ui | --tt-shot: TT goals on screen; the HUD goal line wraps. |
| WU-238 | world-ui | --encounter-shot: the three TT choice encounters fit. |
| C-160 | content | Roadside rogue waits a stage and is rarer (35 -> 12 fights; still 0 wins, rated 5%). |
| QA-109 | qa | crafter_start --prof=<id> and a "crafter crafts" baseline section for every craft. |
| PROF-015 | systems | An order with two gathered ingredients fits the window (Exploration.best_gather_place). |
| WU-237 | world-ui | Inheritance stage names drop the doubled "the" (Inheritances.stage_title). |
| WU-234 | world-ui | --year-shot: the orders line and the longest lapse text fit. |
| TT-001 | systems | Goals at Tribulation Transcendence. |
| C-150 | content | Crafted goods keep markup 1.3 (1.6/1.8/2.0 all break the income guards; recorded in the _doc). |
| GUIDE-057 | systems | A Qi Refining crafter who stops meditating hears about it (last_meditated_day). |
| WU-233 | world-ui | --workshop-shot: the gathering estimate fits the HUD hint and journal Commissions. |
| GUIDE-060 | systems | One recipe-scroll lookup built at load (GameData.scroll_for_recipe). |
| WU-235 | world-ui | Focus audit for the Old Quarry Tailings, Sutra Barge grounds and a Mahayana encounter. |
| QA-110 | qa | late_gates sim covers Soul Formation to Mahayana and inheritance guardians; flags forced fights under 20%. |
| YEAR-011 | systems | The year in review counts crafting orders filled and lapsed. |
| PROF-014 | systems | An open order says how long its short ingredient takes to gather. |
| C-155 | content | Three Tribulation Transcendence choice encounters: bell, cairn, elder waiting for the sky. |
| WU-232 | world-ui | --inherit-shot adds the Mahayana Sutra Barge (menu and journal fit). |
| WU-231 | world-ui | --pill-shot hides the milestone banner over the hint panel. |
| C-154 | content | Six Tribulation Transcendence foes with their fight encounters. |
| PROF-013 | systems | A lapsed order says what you were short (Commissions.short_ingredient, lapse_text). |
| QA-108 | qa | crafter_start sim follows the Mortal nudge: Qi Refining by day 120 in 10/10 seeds. |
| WU-228 | world-ui | --encounter-shot: the three Mahayana choice encounters fit. |
| WU-229 | world-ui | --maha-shot: the Mahayana goal ladder fits the HUD and journal. |
| PROF-011 | systems | "Nearby" means nearby: an order's merchant counts only in the region or one route away. |
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
