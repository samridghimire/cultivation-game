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
Next (planner 2026-10-16 00:10): 16 tasks landed (GUIDE-032..035, RIVAL-016, EFF-004, WU-165..167, WU-169/170, C-105, C-108,
C-109, QA-071, QA-083). No new review entry. Live claims: NS-007, WU-171, C-107 (WU-158's 20:10 claim expires with the 4h cleanup).
New: **the rivalry remembered** (YEAR-004 the year review counts bouts, EPI-002 the epilogue names your rival, RIVAL-017 a
successor's record starts at zero, WU-173 a challenge shows its odds, WU-174 the sheet says where your rival is, WU-172 the sheet
shot meets the rival, C-110 bout milestones, C-112 the rival at Nascent Soul, QA-088 why the bitter "spoiled herbs" encounter never
shows, QA-089 GUIDE-033's test can't skip); **reachable goals** (INH-002 a failed trial says what you have, C-111 the reed hermit's
inheritance is claimable, C-113 help on inheritance trials, GUIDE-036 a "Save for" goal names a pill no shop sells, SOUL-001 Soul
Formation goals); **the first hour, looked at again** (WU-175 re-shoot after this week's HUD changes, WU-176 the place label under
the interact prompt, WU-177 the death screen with the rival line).
Next (planner 2026-10-15 22:10): 18 tasks landed (RIVAL-012/014/015, CORE-001, FOUND-007, GUIDE-031, WU-160..164, C-098..101,
C-104, QA-082, QA-085). No new review entry. Live claims: GUIDE-032, GUIDE-033, WU-158, QA-083. New: **the rivalry you can keep
score of** (RIVAL-016 a bout record, WU-166 shows it, GUIDE-035 where your rival is, C-107 help, C-108 a successor's first
meeting reads right, QA-087 bouts in the rival sim); **less noise, easier to find** (GUIDE-034 journal duplicates from WU-163,
WU-165 HUD panels fade over the player and labels from WU-160's Follow-up, WU-167 a shorter Next steps list on the sheet, C-105 +
WU-169 help pages in groups, WU-170 late-realm sheet shot from WU-163, WU-171 focus audit); **is the first year ever dull?**
(QA-086 quiet stretches); C-109 one duel no longer makes the rival bitter (reviewer note); later realms (NS-007 Nascent Soul goals, C-106 Core give-up encounters, EFF-004 profession_xp guard).
| id | role | status | task |
|---|---|---|---|
| YEAR-004 | systems | todo spec | The year in review counts your bouts with the rival (RIVAL-016's stats never reach the yearly banner). *Spec:* src/core/systems/life_stats.gd `year_summary` (~147): right after the fights line, when `_delta(before, after, "rival_bouts_won") + _delta(..., "rival_bouts_lost") > 0`, append "You crossed hands with your rival %d time%s and won %d." (singular "time" for 1). It counts toward the 4-line cap like the others (keep the existing order otherwise; the realm line stays first). No GameState change: `year_start_stats` already snapshots every life_stats key, and old snapshots without the keys give delta 0. Tests (tests/unit/test_life_stats.gd, next to the existing year_summary tests): before {} / after {rival_bouts_won: 2, rival_bouts_lost: 1} -> the line "You crossed hands with your rival 3 times and won 2."; 1 bout lost -> "1 time and won 0."; no bouts -> no rival line and a quiet year still reads "A quiet year of cultivation."; with realm + fights + rival + adventures + crafted the output is still 4 lines. |
| EPI-002 | systems | todo spec | The epilogue remembers your rival (the final-death screen sums up a life but never names the rivalry). *Spec:* src/core/systems/life_stats.gd `epilogue` (~75): add optional params last, `people: Dictionary = {}, flags: Dictionary = {}`. After the sect/rogue line (before Clan), when `flags.get(Rivals.FIRST_MEETING_FLAG, false)` and `people` holds `c.rival`: append "Rival: <name>, <Cultivation.realm_label(rival)>" plus ", fallen" when not alive, plus "; " + `Rivals.bout_record_text(c)` when not empty (after RIVAL-017 lands, call it the way RIVAL-017 says). src/ui/hud.gd ~698: pass `GameState.npcs` and `GameState.world_flags` (grep the real names). Also src/core/systems/guidance.gd `_rival_entry` ~1354: the fallen line becomes "Rival: %s (fallen; <record>)" when the record is not empty. Tests (test_life_stats.gd): a met living rival with bouts 2/1 -> a line "Rival: <name>, <realm>; bouts 2 won, 1 lost"; met and dead -> contains ", fallen"; rival not met (flag false) -> no Rival line; default params -> output unchanged from today (same line count as before for the existing epilogue test). test_guidance.gd: fallen rival with a record -> "(fallen; bouts ...)". |
| INH-002 | systems | todo spec | A failed inheritance trial says what you have (QA-071: the reed hermit's Spirit 11 trial blocks 8/10 players; the journal says "Your Spirit is not enough (needs 11)." with no idea how far off you are). *Spec:* src/core/systems/inheritances.gd `check_attempt` ~81: "Your %s is not enough (needs %d, you have %d)." using `c.attribute(attr)`. Look at the realm and alignment tests in the same match block: give the alignment one the same shape ("needs %d, you have %d") if it lacks it; leave the realm wording if it already names the realm. grep tests for the old strings ("is not enough (needs") and update them. Tests (tests/unit/test_inheritances.gd): Spirit 9 vs min 11 -> exactly "Your Spirit is not enough (needs 11, you have 9)."; Spirit 11 -> passes; the journal Opportunities line (Guidance) carries the new reason. |
| RIVAL-017 | systems | todo spec | A successor rival's bout record starts at zero (RIVAL-016 counts lifetime LifeStats, so a new rival inherits the old one's 7-2 and the first-win line never fires for them). *Spec:* src/autoload/game_state.gd spar path (where RIVAL-016 adds `rival_bouts_won/lost`): also add 1 to the int world flag `"rival_bouts_won_" + npc.id` / `"rival_bouts_lost_" + npc.id`; post the first-win line when that per-rival flag becomes 1 (not the lifetime stat). src/core/systems/rivals.gd `bout_record_text(c, flags: Dictionary = {})`: with flags, read the two per-rival ints for `c.rival`; when neither key exists and `flags` has no `rival_predecessor` (a save from before this task, first rival), fall back to the lifetime LifeStats so old saves keep their record; without flags keep today's behaviour. Update callers (Guidance `_rival_entry`, character_sheet `rival_line`, and EPI-002's line if it landed) to pass flags. Check every loop over world_flags tolerates int values (Milestones.flag_count, LifeStats.backfill/sync_discoveries use `flags[key]` truthiness; an int 0 never occurs, 1+ is truthy and their prefixes do not match, but confirm `rival_bouts_*` matches no `discovered_`/`mastered_`/flag_count prefix in data/milestones.json). LifeStats lifetime keys and labels stay as they are. Tests (test_rivals.gd + test_game_session.gd): per-rival flags 3/1 -> "bouts 3 won, 1 lost"; flags empty dict but lifetime 2/0 and no predecessor -> "bouts 2 won, 0 lost"; predecessor flag set and no per-rival keys -> ""; GameState: win a bout against a successor whose predecessor had wins -> first-win line posted once. |
| GUIDE-036 | systems | todo | A "Save for" goal for a pill no shop sells (GUIDE-032 made the goal fire at any realm, but `next_realm_pill` returns {} when no shop sells the next realm's pill, so from Foundation or Core upward the goal silently vanishes). In src/core/systems/guidance.gd, when `pill_saving_goal`'s stage condition holds but no shop pill exists, find a breakthrough pill for realm_index + 1 the way `next_realm_pill` identifies them (grep its item test) and name a source in this order: a recipe in data.recipes that makes it -> "Brew a <pill> for <realm> (Alchemist)" (or "Find an alchemist to brew..." when the player is not one; keep it to one line), an auction lot in data/auctions.json -> "Bid for a <pill> at the <auction house region> auction", else "". Return it from a new `pill_source_goal(c, data) -> String` used where the Save-for goal is shown (journal Goals and the goal ladder; do not double up with the Save-for line). Tests: Foundation late stage, no shop sells the Core pill but a recipe does -> the Brew line; a shop sells it -> "" (Save for wins); early stage -> "". |
| SOUL-001 | systems | todo | Goals at Soul Formation (after NS-007; same pattern one realm up, realm id `soul_formation`). `soul_goals` / `soul_goals_active` in src/core/systems/guidance.gd like NS-007's: "Reach Soul Formation Middle", "Win a fight against a Soul Formation foe" (`beat_realm_flag("soul_formation")`), "Survive 4 Heavenly Tribulations" (LifeStats `tribulations_survived` >= 4), plus the next body tempering stage after NS-007's if one exists (else drop the row). Wire it into `goal_ladder_id`/`goal_ladder`, the journal section "Soul Formation goals" and the HUD goal banner exactly as NS-007 does. Tests like NS-007's. |
| WU-173 | world-ui | todo spec | A challenge shows its odds before you take it (the NPC menu says "Challenge your rival X to a bout" with no hint whether you can win; the journal rates the same bout). *Spec:* src/world/interactables/npc.gd ~328: when the spar/challenge option is enabled, append " (%s, %d in 100)" % [Combat.label_for_chance(chance), roundi(chance * 100)] with `chance := Combat.win_chance(p, GameState.data, Mentorship.spar_enemy(npc, GameState.data))` (same rating Guidance `_rate_fight` uses), for the rival challenge and for ordinary spars. Disabled options keep their reason and no odds. Put the label building in `static func spar_label(npc_name: String, is_rival: bool, chance: float) -> String` (chance < 0 -> no odds) so it is testable. Tests (the NPC menu test that WU-155/WU-162 extended): spar_label("Lin", true, 0.52) == "Challenge your rival Lin to a bout (<label for 0.52>, 52 in 100)"; spar_label("Lin", false, -1.0) == "Spar with Lin"; the rival's menu entry contains " in 100)". Check the longest label still fits a ChoiceMenu row at 1280x720 (WU-156's measurement helper). |
| WU-174 | world-ui | todo spec | The sheet says where your rival is (GUIDE-035 put the region in the journal only). *Spec:* src/ui/character_sheet.gd `rival_line` (~292): add an optional last param `region_id: String = ""`; when `Npcs.region_of(r, data)` is not empty and differs from region_id, insert ", in <Exploration.region_name(data, rival_region)>" after the realm label, the same wording as Guidance `_rival_entry`. The caller passes the current region (grep how the sheet or GameState names it, e.g. `GameState.region_id`). Tests next to the rival_line tests: rival elsewhere -> contains ", in <region name>"; same region -> no ", in "; default param -> unchanged. |
| WU-175 | world-ui | todo spec | The first hour, looked at again (WU-157 looked on 2026-10-15; since then WU-160 labels, WU-161 menu titles, WU-165 panel fade, WU-167 shorter Next steps, GUIDE-031/034 fewer repeats landed). *Spec:* run tests/sim/screenshot_first_hour.gd (header says how; 1280x800 and, if it has the option, 1280x720), open every PNG with the Read tool, and check WU-157's list in docs/HANDOFF.md "First-hour screenshot look" item by item: fixed or still there. Fix only small layout bugs (a clipped label, a wrong margin) in this task; anything needing a design or world-layout call goes under Follow-ups with the shot name. Replace that HANDOFF section with the new findings (dated). Acceptance: the commit body lists each WU-157 item with fixed/still there. |
| WU-172 | world-ui | todo | The late-realm sheet shot meets the rival (WU-170 Follow-up: the Rival section never appeared). In tests/sim/screenshot_screens.gd `--late-realms`, give the session a rival NPC at the character's realm, set `Rivals.FIRST_MEETING_FLAG` and a bout record (the LifeStats keys, plus RIVAL-017's per-rival flags if landed), re-shoot the sheet at 1280x800 and 1280x720, open the PNGs and fix any clipping of the rival line (it is the longest line on the sheet now: attitude, grudge, favor, record). Paste findings in the commit. |
| WU-176 | world-ui | todo | The place label hides under the interact prompt (WU-157: "Wandering Merchant" sits under the player sprite and the interact prompt). Find where the interact prompt is drawn (grep "prompt" in src/world/player.gd / src/ui/hud.gd) and where Interactable draws its label; while an interactable is the current interact target and the prompt is showing, do not draw that interactable's own label (the prompt already names it; redraw on target change). Put the decision in a static helper (`Interactable.label_visible(is_target: bool, prompt_shown: bool) -> bool`) and test it. Acceptance: standing at the Qingshi merchant shows one name, not two overlapping. |
| WU-177 | world-ui | todo | The death screen with the rival line fits (after EPI-002: the epilogue gains a line). Add a final-death shot to tests/sim/screenshot_screens.gd if it has none (a dead player with a clan, children, a met rival with a bout record and 8 life-record lines), shoot it at 1280x800 and 1280x720, open the PNGs, and fix clipping (e.g. let the epilogue label scroll or lower `max_stats` when it would not fit; measure with the font like WU-150). Paste findings in the commit. |
| C-110 | content | todo spec | Milestones for your rival bouts (RIVAL-016 added the stats; nothing celebrates them). *Spec:* data/milestones.json: add {"id": "crossed_hands", "name": "Crossed Hands", "description": "Win a bout against your rival.", "check": {"type": "life_stat", "stat": "rival_bouts_won", "min": 1}} and {"id": "worthy_rival", "name": "A Worthy Rival", "description": "Win ten bouts against your rival.", "check": {"type": "life_stat", "stat": "rival_bouts_won", "min": 10}}, next to `surpass_the_rival`. Milestone ids double as Steam achievement ids (src/autoload/platform.gd): if docs/RELEASE.md or any file lists the achievement ids, add the two there too. grep tests for a hard-coded milestone count and update it. Tests: the milestone data test passes; a character with rival_bouts_won 1 newly reaches crossed_hands, not worthy_rival. |
| C-111 | content | todo spec | Make the Reed Hermit's inheritance claimable (QA-071: 0/10 curious seeds claim it in 36 months; Silence of the Reeds needs Spirit 11, and attributes rarely grow). *Spec:* run tests/sim/early_inheritances.gd (seeds 1-10, 36 months) and note reed_hermit_hut's passable/claimed/median month and its final fight odds. In data/inheritances.json lower Silence of the Reeds' `min` from 11 to 10 (DESIGN: an attribute gate is meant as a talent check, not a wall). Re-run; if claimed is still < 3/10 and the blocker is now The Hermit's Shade, soften `reed_hermit_shade` in data/enemies.json (its stats, 10-15% at a time) until the curious policy's final-fight odds are ~50-70%. Target: claimed by >= 3/10 seeds. Refresh only that baseline section in docs/balance_baseline.txt and paste before/after in the commit body. Data tests must still pass. |
| C-112 | content | todo | Your rival at Nascent Soul (C-100's pattern one realm up). data/encounters.json: 3 once-only encounters with `min_realm` nascent_soul, `rival: "any"`, `requires_flag: "rival_met"`, one per attitude where it fits (`rival_attitude` friendly / proud / bitter, RIVAL-010), in regions whose tags reach Nascent Soul entries. Each with a `fight_rival` choice (rival_grudge at most 5, no items on that choice: both have data tests) and a peaceful choice. Uses {rival}. Tests: the existing rival/encounter data tests pass; a new test checks the three are once-only and gated at Nascent Soul. |
| C-113 | content | todo | Help on inheritance trials. data/help.json: find the page that covers inheritances (grep "inheritance"); add or extend it: the four trial kinds (realm, attribute, alignment, fight), that each inheritance appears after some years and is lost at a deadline or when someone else claims it, that attribute trials are talent checks (attributes rise only from rare encounters), and that the journal's Opportunities line names the trial that stops you. Group "world" (C-105). Plain words. Help data test. |
| NS-007 | systems | todo | Goals at Nascent Soul (CORE-001's pattern one realm up). src/core/systems/guidance.gd: `nascent_goals` / `nascent_goals_active` like `core_goals` (~883): "Reach Nascent Soul Middle", "Win a fight against a Nascent Soul foe" (`beat_realm_flag("nascent_soul")`), "Claim an inheritance" (LifeStats `inheritances_claimed` >= 1), "Temper your body to its next stage" (pick the body_tempering.json stage after Golden Body if it exists, else drop the row). Wire it into `journal_entries` (section "Nascent Soul goals") and the goal ladder used by the HUD goal banner (~932, `current_ladder` or its name). Tests like CORE-001's. | |
| WU-158 | world-ui | todo | The newest windows at 1280x720 by eye (WU-150 could not view the 720p `--win-shots` PNGs). Run tests/sim/screenshot_screens.gd with its 720p/`--win-shots` option (see the script header) and open the PNGs with the Read tool: HUD with the fair-fight line, journal with Foundation goals and the tribulation line, encounter window with tagged choices, breakthrough window. Same report/fix rules as WU-157. |
| WU-171 | world-ui | todo | Focus audit of what landed since WU-152: ChoiceMenu with its title separator (WU-161), the tinted tribulation attempt option (WU-164), the NPC menu with a disabled rival challenge (WU-162), the encounter footer (WU-154). Extend tests/unit/test_focus_audit.gd: each opens with a focused control and d-pad down reaches every enabled option. Fix only what fails. | |
| C-106 | content | todo spec | Encounters where you give something up, at Core Formation (C-101's pattern one realm up). *Spec:* data/encounters.json: 3 once-only Core Formation encounters in three different Core regions (list regions whose encounter_tags reach Core Formation entries, e.g. Myriad Peaks Ridge), each with one choice that costs an item or stones (`requires.item`/cost fields the C-096/C-101 entries use; copy their shape) for a lasting gain (dao insight, attribute +1 at most once across the three, a technique level, renown), one plain choice and a walk-away; the costly choice's tag must show the cost (CHOICE-003). Costs sized for Core Formation (look at C-101's numbers and the Core pill prices). Tests: like C-101's data test (once-only, gate, cost tag present). | |
| C-103 | content | todo | Encounters a profession can answer, at Core Formation (C-095's pattern one realm up). Give 3 Core Formation encounters (existing ones, or new once-only ones in Myriad Peaks Ridge or another Core region) a `requires.min_profession` choice at rank 3 (alchemist, doctor, beast tamer or formation crafts not used by C-095), each also with `profession_xp` 40-60 (EFF-003), rewarding a little better than the best plain choice. Tests like C-095's. |
| C-102 | content | todo | Retune the renowned requests (after QA-084). Using QA-084's table, set each C-062 request's best choice to about 1-2x a week of the best ordinary income at its realm and region (work or a sect mission, whichever QA-084 says is higher); keep the village dispute. Paste before/after stones per request in the commit; re-run tests/sim/renowned_pay.gd. |

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
| QA-088 | qa | todo spec | Why does the bitter rival's "spoiled herbs" encounter never show? (QA-083 Follow-up: rival_spoils_gathering was met 0 times although the rival is bitter in 24% of curious checkpoints.) *Spec:* write a unit test that builds a Qi Refining character with a met, bitter rival (grudge >= `rival.bitter_grudge`, `rival_met` flag) standing in a region tagged forest and asks Exploration for the encounters eligible there (grep the pool/eligibility function Exploration uses, and how RIVAL-010 passes favor and attitude). If rival_spoils_gathering is not eligible, find the cause (a tag like "herbs" no region has, `rival: "any"` vs attitude evaluation, or a missing favor/people argument on the explore path; `rival_met` is the right flag name) and fix it in data or code; also check rival_shares_insight and rival_public_challenge the same way. If it is eligible, compute its share of the pool (weight / total weight) and say whether weight 2 is simply too rare. Keep the test as a regression test. Re-run tests/sim/rival_story.gd and paste the C-093 counts before/after (refresh only that baseline section). |
| QA-089 | qa | todo | GUIDE-033's test can't skip (GUIDE-033 Follow-up: the cooldown/away/bitter test in tests/unit/test_guidance.gd returns early when the fixture bout is not in the fair band). Build the player and rival with fixed stats (realm/stage, techniques, gear; or a fixed enemy dict if the rating path allows) so the bout rates inside the fair band for certain, assert that first, and drop the early return. The test must fail if `fair_fights` stops listing the rival. |
| QA-084 | qa | todo spec | What should a renowned request pay? (QA-080 Follow-up: they pay 2.5-25x a week of *gathering*, but gathering may be the stingy side.) *Spec:* extend tests/sim/renowned_pay.gd: per C-062 request, next to the gather week, print a week of profession work (`Professions.work` for 7 days at rank 1 with attribute 10, for the profession that pays best in that region) and the median net stones of the sect missions available at that realm (data/sect_missions.json, rewards valued like the sim values items). Print the ratios against the best of the three. Commit body: the table and a recommended stones value per request for 1-2x a week of the best income (C-102 applies it). No data changes. |
| QA-086 | qa | todo spec | Is the first year ever dull? (playable-and-fun check: nobody measures stretches where nothing new happens.) *Spec:* tests/sim/simulate_first_hour.gd (or first_hour.gd, wherever the curious/default policies live): add `--quiet` that, for seeds 1-10 and both policies over 365 days, snapshots each day: realm/stage, technique levels, `c.life_stats` values, distinct item ids held, `c.milestones`, encounter ids seen (whatever flag/stat records them), NPCs with favor > 0, regions visited, goal ladder done count. A day is "new" when any of those grew/changed upward. Print per policy: median and max quiet stretch (days in a row with nothing new), new-day count per month (12 numbers, median over seeds), and the 3 longest stretches with the policy's main activity in them (meditate/gather/explore/work, from its own action log). New balance.sh section + docs/balance_baseline.txt section, no guard test needed (sim only). Follow-ups: name the month/activity where stretches cluster (e.g. "months 4-6, meditating to the layer 4 bottleneck") so content/systems can fill it. | |
| QA-087 | qa | todo | Bouts with the rival in the rival sim (after RIVAL-016 and GUIDE-033). tests/sim/rival_story.gd: the curious policy challenges its rival when GUIDE-033 lists the bout (and the rival is in its region); print per seed bouts won/lost (from the new LifeStats keys) and the month of the first win. Refresh only that baseline section (paste before/after). Follow-up if the first win never comes in 36 months for most seeds. | |
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
|---|---|---|
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
