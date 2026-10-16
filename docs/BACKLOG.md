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
Next (planner 2026-10-16 10:10): 15 tasks landed (RENOWN-006, QA-095, WU-188, C-130, WU-192, QA-086, GUIDE-038, WU-191, C-126,
GUIDE-040, QA-093, WU-180, WU-181, INH-005, C-122). Review 26efd67..9206be9: two text fixes by the reviewer, nothing filed. Live claims: EPI-003,
WU-190, C-123, C-127, QA-094. **The first years no longer end runs** (QA-095: with a life bought at 1 life left and the non-lethal Drunk
Bully, no curious seed ends early in 36 months); QA-096 asks why seed 7 still stalls 23 months at Qi Refining 7th Layer. **Professions
pay** (QA-093: 0.26-0.37 stones/day vs 2.24 for gathering, and an Alchemist's first pills sell for less than their herbs): C-131 makes
the four losing alchemist recipes pay, C-132 triples odd-job pay, PROF-003 + WU-195 show the numbers at the workshop, YEAR-008 puts rank-ups
in the year review, GUIDE-042 points a crafter to their herbs, QA-097 re-measures. **Quiet months** (QA-086: up to 60 days with nothing new):
GUIDE-041 starts "try something new" at day 60 instead of 180. Reviewer notes: WU-194 (death lesson band), WU-197 (banner over the HUD).
Shots: WU-196 renown, WU-198 epilogue fame. QA-093's work-income truncation only bites under ~5 days, and in-game work is always a month, so
it was not filed.
Next (planner 2026-10-16 08:10): 14 tasks landed (GUIDE-036, VOID-001, RENOWN-005, GRAT-002, YEAR-007, WU-158, WU-184, WU-186,
WU-187, WU-189, C-102, C-120, C-121, QA-091). Review 50042bb..26efd67: one text fix by the reviewer, nothing filed. Live claims: INH-005,
WU-181, C-122, QA-093, QA-094. **The first years still end runs** (QA-091: 2 of 10 curious players spend every artifact life by month
28-31; deaths are volume, not bad ratings): C-126 makes the Drunk Bully non-lethal (his own bounty sends him home "with a sore head"),
GUIDE-040 makes the low-lives hint honest about the stones you hold and an empty artifact, QA-095 re-measures with a policy that buys a
life when it can. **Read the HUD at a glance** (GUIDE-038 long waits in months/years, not "8709 days"; WU-191 the HUD Goal line follows
the realm's goal ladder, WU-184 Follow-up). **Renown you can see** (WU-192 the arrival banner says what a region calls you, EPI-003 the
epilogue names your fame, C-130 renown milestones). **One realm up** (C-127 a Void Refinement breakthrough pill, GUIDE-036 Follow-up;
C-128/C-129 Body Integration foes and encounters, then BI-001 goals and WU-193 the shot). WU-190 adds the missing encounter-window shot
(WU-158 Follow-up). The profession-pay retune waits for QA-093's numbers.
Next (planner 2026-10-16 06:10): 14 tasks landed (QA-084, WU-182, C-118, C-119, WU-185, C-116, RENOWN-004, INH-004, QA-092,
WU-183, C-103, SOUL-002, C-117, YEAR-006). No new review entry (last reviewed 50042bb). Live claims: GRAT-002, WU-186, QA-091
(GUIDE-036, WU-180, WU-181 from 02:06-03:16 expire with the 4h cleanup if nothing lands). New: **Void Refinement** is now a realm with
content, so VOID-001 (spec'd) gives it goals and C-122 (inheritance), C-123 (body stage), C-124 (rival), C-125 (profession
choices) fill its rows; **renown you can see** (RENOWN-005 a gain says so, C-120 spec'd, YEAR-007 and INH-005 in the year review); **the
deadly first years** (WU-189 a risky mission warns at 1 life, WU-187 shots of the new death lines); **professions pay?**
(QA-093: work pays ~3 stones a week vs 12-54 for a mission); cleanup C-121 (one debts help page), QA-094 (baselines after QA-092).
C-102 now carries QA-084's numbers.
| id | role | status | task |
|---|---|---|---|
| EPI-003 | systems | todo spec | The epilogue names your fame (renown is now earned from bounties, discoveries and honourable choices but the final-death epilogue never mentions it). *Spec:* src/core/systems/life_stats.gd `epilogue` (~76): after the "Path:" line, when some region has a renown title, append "Known as %s in %s" with the title and region name of the region with the highest `Renown.value` (ties: first in `data.regions` order; use `Renown.title`, skip regions whose title is ""). No line when no region has a title. Tests in tests/unit/test_life_stats.gd next to the epilogue tests: renown {qingshi_village: 0} -> no "Known as"; values in two regions -> the higher one's title and name (pick values from the regions.json renown tiers, not literals: read `data.renown["tiers"]`); a tie -> the first region in data order. |
| GUIDE-041 | systems | todo spec | "Try something new" from the third month (QA-086: a meditate-and-explore newcomer goes up to 60 days with nothing new in months 2-4 and 9-13, but `_untried_feature_hint` stays silent until day 180). *Spec:* src/core/systems/guidance.gd ~149: `UNTRIED_MIN_DAYS` 180 -> 60; update its doc comment ("GUIDE-007; GUIDE-041 after QA-086"). Nothing else changes (the realm_index >= 1 gate and the hint order stay). Grep tests/unit for `UNTRIED_MIN_DAYS` and literal 180/181 day values near untried/explore-the-wilds hints and fix any test that relied on 180 (use the constant, not a literal). Tests (test_guidance or wherever `_untried_hint` is tested): Qi Refining 1st layer, 0 encounters, today 60 -> hints contain "Explore the wilds"; today 59 -> it does not; a Mortal at day 200 -> it does not. Acceptance: tools/test.sh green; `tools/balance.sh --check` sections that move only because a hint appears earlier may be refreshed (paste before/after in the commit). |
| PROF-003 | systems | todo spec | What a day of work or a craft pays, as pure helpers (QA-093: crafting from bought herbs loses money and nothing in the game says so; WU-195 shows these). *Spec:* src/core/systems/professions.gd: `static func work_preview(c: CharacterData, data: GameData, prof_id: String, days: int) -> Dictionary` returning `{"xp": float, "income": int}` with exactly the formulas `work` uses today (~43-44); make `work` call it so the two can never drift. src/core/systems/alchemy.gd (where recipes live): `static func recipe_margin(data: GameData, recipe_id: String) -> Dictionary` returning `{"cost": int, "value": int}`: cost = sum of ingredient count x data.items price (spirit_stone counts 1 each), value = output count x `Items.sell_price(data, output_item)`; unknown recipe -> {cost 0, value 0}. `##` doc comments on both. Tests: work_preview matches what work() then pays and adds (same c, two copies); qi_gathering_pill margin today = {cost 16, value 14} (assert against the formula, not the literal, so C-131 does not break it, plus one literal check for a recipe C-131 will not touch, e.g. iron_sword {24, 30}). No UI. |
| YEAR-008 | systems | todo spec | The year in review says your profession grew (professions are a pillar but the year review never mentions them). *Spec:* src/core/systems/professions.gd `add_xp` (~24): after the loop, `if gained > 0: LifeStats.add(c, "profession_ranks", gained)` (covers work, crafting, commissions and patients). src/core/systems/life_stats.gd `year_summary` (~188): after the crafted line, `var ranks := _delta(before, after, "profession_ranks")`; when > 0 append "You rose a rank in your profession." (1) or "You rose %d ranks in your professions." (2+). If `lines()` (the sheet's life record) lists keys explicitly, add "Profession ranks gained" next to items crafted. Old saves: missing key reads 0 (get_stat). Tests: add_xp that crosses a rank adds 1 (two ranks -> 2); year_summary with delta 1 and 3; a delta of 0 adds no line and a year with only rank-ups is not "A quiet year". |
| GUIDE-042 | systems | todo | A crafter hears where their herbs grow (start after C-131). When the player has a crafting profession (Alchemist first) and knows a starter recipe they cannot craft now, and an ingredient of it is gatherable in the current region (use the same gather tables Exploration/gather places use; grep `gather` in src/core/systems), add one hint: "Spirit Herb grows here: gather it to refine Qi Gathering Pills (they sell for more than the herbs cost)." Only when the craft-now hint (GUIDE-017) does not fire; at most one such hint; fades after CRAFT_HINT_MAX_CRAFTS crafts. Tests: shows in Qingshi with the alchemist starter recipe and no herbs; silent with the herbs in hand; silent with no profession. |
| BI-001 | systems | todo | Goals at Body Integration (VOID-001's pattern one realm up; start only after C-128 and C-129 are on main). guidance.gd: `body_integration_goals` / `body_integration_goals_active` like `void_goals` (~1038): "Reach Body Integration Middle", "Win a fight against a Body Integration foe" (`beat_realm_flag("body_integration")`), the inheritance row only when `_has_realm_inheritance(data, "body_integration")`, a body row only when a stage past the Void one exists. `goal_ladder_id` realm_index 7 -> "body", `goal_ladder`, `active_goal_ladder`, hud.gd's ladder names map ("Body Integration"), journal section "Body Integration goals". Tests next to VOID-001's; any test that uses realm_index 7 as "past every ladder" moves to 8. |
| WU-190 | world-ui | todo spec | An encounter-window shot (WU-158 Follow-up: screenshot_screens.gd has no shot of the encounter window with tagged choices). *Spec:* tests/sim/screenshot_screens.gd: add `--encounter-shot` following the existing flag pattern (header comment, arg parse): open the HUD's encounter window on a real encounter from data/encounters.json that has an attribute-gated choice, a `min_profession` choice and an enemy choice (find one; if none has all three, use the one with the most choices and the longest text), with a player who meets one gate and misses another so both tag styles show. Shoot at 1280x800 and 1280x720, open both PNGs with the Read tool; fix clipping (autowrap, scroll) if any; paste findings in the commit. |
| WU-194 | world-ui | todo spec | The death lesson matches the odds it prints (reviewer note on WU-185: 89.6% reads "about 90% odds" with the middle-band lesson). *Spec:* src/ui/respawn_screen.gd ~69-73: band on the rounded percent the text prints (`pct`), not the raw `chance`: `if pct >= 90` / `elif pct >= 50`. Keep the three texts. Test in tests/unit/test_respawn_screen.gd: chance 0.896 -> text contains "90%" and "Even a weak foe"; 0.494 -> "49%" and "Grow stronger"; 0.5 -> middle band. |
| WU-195 | world-ui | todo spec | The workshop says what work and crafts pay (after PROF-003). *Spec:* src/world/interactables/workshop.gd ~25: the "Work as %s (1 month)" option gets a `"description"` from `Professions.work_preview(c, data, def.id, Calendar.DAYS_PER_MONTH)`: "About %d spirit stones and %d xp this month." src/ui/crafting_screen.gd (details under the ingredients label, ~105): one line from `Alchemy.recipe_margin`: "Ingredients cost about %d at shops; the output sells for about %d." and, when value < cost, add " Gathered herbs make it pay." Tests: workshop options for a Doctor include the description with the preview numbers; crafting details text for qi_gathering_pill contains both numbers (read them from recipe_margin, not literals). Shoot the crafting screen at 1280x720 with the existing screenshot flag for it (or add one), open the PNG, fix clipping. |
| WU-196 | world-ui | todo spec | Renown on screen (RENOWN-006 journal line, WU-192 arrival banner, C-130 milestones). *Spec:* tests/sim/screenshot_screens.gd: add `--renown-shot` following the existing flag pattern: a Qi Refining player with renown in qingshi_village at the first title tier and halfway to the second (set it through the Renown system's own setter/add, reading the thresholds from data, not literals), shoot (1) the HUD arrival banner for Qingshi with "Known here: <title>" and (2) the journal page with RENOWN-006's line, at 1280x800 and 1280x720. Open the PNGs with Read; fix clipping or a line cut off; paste findings in the commit. |
| WU-197 | world-ui | todo | Does the notice banner hide the HUD? (reviewer note on WU-158: the banner now sits in the top 3-20% of the screen, over the HUD's top area while it shows). Shoot the HUD at 1280x720 with a notice banner up (a milestone or realm banner) and the Goal line + hints visible. If the banner covers the vitals or the Goal line, move it just below them (or narrow it) without bringing back WU-158's problem (it must not cover centred window titles; check one centred window too). Paste findings. |
| WU-198 | world-ui | todo | The epilogue's fame line on screen (after EPI-003). Extend the final-death/epilogue shot (grep `epilogue` in tests/sim/screenshot_screens.gd) with a character who has a renown title, shoot at 1280x800 and 1280x720, open the PNGs, fix clipping; paste findings. |
| WU-193 | world-ui | todo | The Body Integration ladder on screen (after BI-001). Extend the shot WU-188 adds (or `--soul-shot`) with a Body Integration Early player: HUD Goal line and the journal's "Body Integration goals" section. Shoot at 1280x800 and 1280x720, open the PNGs, fix clipping; paste findings. |
| C-131 | content | todo spec | An Alchemist's first pills pay (QA-093: crafting from bought herbs loses money; four alchemist recipes at rank 0-1 sell for less than their herbs cost: qi_gathering_pill 16 -> 14, bone_setting_salve 20 -> 12, meridian_mending_pill 74 -> 60, clear_heart_pill 88 -> 30, using `Items.sell_price`, which caps crafted goods at min(price x 0.5, material per unit x 1.3)). *Spec:* data/recipes.json only: raise `output.count` (and `great_output.count` so it stays >= output) of those four until output x `Items.sell_price` is 1.15-1.35x the ingredient shop cost (planner's estimate: qi_gathering_pill 2 -> 3, bone_setting_salve 1 -> 2, meridian_mending_pill 1 -> 2, clear_heart_pill 1 -> 4; check each with the real sell_price, which drops as count rises). Do not change item prices. Add a data test (tests/unit, next to the recipe/alchemy data tests): for every recipe with min_rank <= 1, output count x sell_price >= ingredient shop cost (spirit_stone 1 each). Run `tools/balance.sh --check`; refresh only sections that moved because of this (paste before/after). |
| C-132 | content | todo spec | Odd jobs pay a living wage (QA-093: a month as a Doctor pays 5 stones at rank 0; gathering pays ~67 a month). *Spec:* data/professions.json `work_income` x3: alchemist 18, blacksmith 18, talisman_master 15, array_master 21, doctor 15, beast_tamer 15 (today only Doctor works at the workshop; the others' work_income feeds children's training and sims). Keep the `_doc`. Fix tests that assert old pay (tests/unit/test_exploit_audit.gd ~7 says "work_income 5 per month"; tests/unit/test_items_and_deeds.gd ~186 compares a talisman to work pay): keep each test's intent (e.g. selling talismans still beats working, the exploit audit's ratio bounds), adjusting numbers only when the intent holds. Run `tools/balance.sh --check` and refresh only sections that moved (economy/profession income), pasting before/after. |
| C-127 | content | todo spec | A Void Refinement breakthrough pill (GUIDE-036 Follow-up: the last breakthrough pill is for Soul Formation, so a Soul Formation player has no pill goal at all). *Spec:* follow the Spirit Severing Pill exactly (data/items.json ids `soul_formation_pill`, `flawless_soul_formation_pill`, `recipe_soul_formation_pill`; data/recipes.json `soul_formation_pill`). Add `void_refinement_pill` ("Void Piercing Pill" or similar, price 3,000,000, breakthrough_bonus 0.25, breakthrough_realm "void_refinement"), `flawless_void_refinement_pill` (7,000,000, 0.4), `recipe_void_refinement_pill` (price 0, learn_recipe), and a recipe: min_rank one above the Spirit Severing Pill's (or its value if that is already the profession's max rank), days ~130, difficulty ~0.7, xp ~10000, great_output the flawless pill, ingredients from existing late herbs (soul_severing_lotus, thousand_year_lingzhi, plus a Soul/Void Refinement material already in items.json; do not invent a herb nobody can find). Make the recipe scroll obtainable once: find where `recipe_soul_formation_pill` is granted (grep data/) and grant the new scroll from the analogous Soul Formation-or-later place (C-122's Void inheritance if it is on main, else a late auction lot in data/auctions.json following an existing lot's shape). Voice: the void is a door you learn to open. Tests: data validation; a test that Effects.check accepts the pill only for a Soul Formation player (next realm void_refinement), next to RV-005's pill tests (grep breakthrough_realm in tests/unit); GUIDE-036's `pill_source_goal` returns a Brew line for a Soul Formation late-stage player. |
| C-123 | content | todo | A seventh body tempering stage for Void Refinement (C-114's Starfire Body pattern one realm up). data/body_tempering.json: one stage after Starfire Body, gated at Void Refinement, costs and gains scaled like C-114 did from stage 5 to 6, materials from existing late items (e.g. star_silver, dragonblood_gold). VOID-001's body row appears by itself. Tests: body tempering data tests; a test that stage 7 needs Void Refinement. | |
| C-124 | content | todo | Your rival at Void Refinement (C-115's pattern one realm up). data/encounters.json: three once-only Void Refinement encounters gated `rival_attitude` friendly / bitter / proud, each with a duel choice (rival_grudge 5, C-109) and a peaceful way out, `{rival}` in the text. Tests like C-115's. | |
| C-125 | content | todo | Rank-4 profession choices at Nascent Soul (C-103's pattern one realm up). Give 3 Nascent Soul encounters a `requires.min_profession` choice at rank 4 for professions C-103 did not use (blacksmith, talisman master, array master), each with `profession_xp` 60-80 and a reward a little better than the best plain choice. Tests like C-103's (blocked at rank 3, allowed at 4). | |
| C-128 | content | todo | Body Integration foes (C-118's pattern one realm up: `git show 482f7b4 -- data/enemies.json`). data/enemies.json: 6 foes at realm body_integration stages 0-3 (beasts, a rogue body cultivator, a void-born thing), stats scaled from the Void Refinement foes as C-118 scaled Soul -> Void, lethal like their peers, rewards from existing late items. Tests: enemy data validation; QA-007d's realm-training/combat data tests stay green (run the combat balance check if C-118's commit did). |
| C-129 | content | todo | Body Integration encounters (after C-128; C-119's pattern: `git show 482f7b4 -- data/encounters.json`). data/encounters.json: 6 encounters gated min_realm body_integration in the late regions that host Void Refinement encounters, each of C-128's foes in at least one, mixing a fight, a choice with a cost and one attribute-gated choice. Tests like C-119's. |
| QA-096 | qa | todo spec | Why does curious seed 7 stall 23 months at Qi Refining 7th Layer? (QA-095 Follow-up: it sits at QR7 from month 14 to 37 with ~40 stones and 0 lives.) *Spec:* run tests/sim/simulate_curious_years.gd for seed 7 only with a per-month trace (add a `--trace=<seed>` flag if none exists, printing per month: realm/stage, qi / qi needed, breakthrough attempts and chance, stones in/out by source, days per activity, lives). Answer in the commit: what blocks it (qi rate, failed breakthroughs, injuries, spending, policy loop) and whether a human player in the same spot would see a hint pointing out (list the HUD hints/goal for that state with `Guidance.hints`). No data or game changes; Follow-ups with numbers if it is a game problem. Refresh no baseline unless the new flag changes default output (it must not). |
| QA-097 | qa | todo | Professions after the retune (after C-131 and C-132). tests/sim/profession_income.gd: in the game only non-crafting professions can "Work" at the workshop (src/world/interactables/workshop.gd CRAFTS); make the sim's crafting professions craft-and-sell (with bought and with gathered ingredients) instead of the work option they cannot take, keep work for Doctor. Re-run; refresh that baseline section only (paste before/after) and answer: does each profession now pay at least the sect-mission rate (0.38/day), and how far below gathering (2.24/day) is it? |

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
| QA-094 | qa | todo | Baselines after QA-092's curious-policy detour (QA-092 Follow-up: other sections driven by first_hour's curious policy may have shifted). Run `tools/balance.sh --check`; for each section that differs, say whether the change is the detour (bitter rival -> nearest forest/marsh/mountain) or something else, and refresh only the sections that moved because of it (paste before/after). Anything else that moved goes under Follow-ups. | |
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
