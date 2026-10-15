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
Next (planner 2026-10-15 16:10): 16 tasks landed (RIVAL-007/008, CHOICE-002, C-062, C-085, C-087, C-088, C-089, WU-144..147,
QA-075, QA-076; QA-077 answered inside QA-076; QA-073 already met: suite 408 s). QA-076: waiting up to 120 days at the bottleneck
closes the pill gap for every short seed (owner's F-005d note updated). Live claims: GUIDE-029, GUIDE-030, FOUND-004, WU-148,
C-090, QA-078, QA-071. New: **the rival as a person** (RIVAL-009 attitude from favor and grudge, RIVAL-010 encounters by attitude,
RIVAL-011 word of their death, WU-151 sheet/Look, C-092/C-093 data); **the road to Core Formation** (FOUND-005 tribulation
readiness in the journal, WU-153 on the attempt option, C-097 help); **choices say what they cost** (CHOICE-003 alignment and
item tags, C-094 help page, C-096 encounters where you give something up); WU-150 720p HUD shot WU-144 skipped, WU-152 focus
audit, QA-079 stale baseline sections, QA-080 renowned-request rewards.
Next (planner 2026-10-15 14:10): 17 tasks landed (RIVAL-005/006, FOUND-003, CHOICE-001, GUIDE-027/028, WU-132/136/137/140/141/142/143,
C-065, C-083, QA-072, QA-074). Systems and world-ui queues were empty; new work: **the rivalry keeps going** (RIVAL-007 surpass a
rival already behind, RIVAL-008 they push back, WU-148 the realm card names them, C-087 at Foundation, QA-078 measures it);
**the pill gap** (QA-072: 6 of 10 sim players now afford the Foundation pill; GUIDE-029 tells the rest how to earn the gap, QA-076
measures whether waiting closes it; the price stays the owner's F-005d call); **choices that use who you are** (CHOICE-002
profession checks + WU-146 "[Comprehension 12]" tags, C-088/C-090/C-091 data); **fights for rogues** (GUIDE-030 rates the
region's exploration foes, WU-147 bounties on the map); polish from Follow-ups (WU-144 shorter HUD line, WU-145 breakthrough
window at 720p, WU-149 lessons on a failed attempt); FOUND-004 goals after Foundation.
| id | role | status | task |
|---|---|---|---|
| GUIDE-029 | systems | todo spec | The pill gap says how to close it (QA-072 Follow-up: 3 of 10 sim players reach the Qi Refining bottleneck 130-190 stones short of the ~300-stone Foundation pill, and attempt anyway). *Spec:* (1) src/core/systems/guidance.gd `_rate_fight` (~1044): entries gain `"stones": int`: bounties `Bounties.paid_stones(c, data, b)` (pass it in from the bounty loop), missions and deeds the `spirit_stone` count in their reward/effects `items` if any, else 0. (2) New `static func pill_gap_note(c, data, fights: Array) -> String`: "" unless `pill_saving_goal(c, data)` != "" and stones < `next_realm_pill_price`; else "%d stones short. %s pays %d." naming the fair fight (from `fights`, i.e. fair_fights output) with the most `stones` > 0 (text = the entry's label part before " (", or simply the enemy name with its kind: "A bounty on the <enemy>"), or "%d stones short. Bounties, sect missions and selling herbs and ore pay best." when none pays. (3) Journal: in `journal()` compute `fair_fights` once and pass it to both `_fair_fight_entries` and `_breakthrough_entries` (or wherever the "Save for ..." line is shown in the journal), adding the note as its own line under the saving line, tone "normal". The HUD goals line stays as is (no combat sims there). Tests (test_guidance.gd): short with a fair 40-stone bounty in reach -> names it and 40; short with no paying fight -> the generic line; affordable -> ""; below 7th layer -> "". |
| GUIDE-030 | systems | todo | Fights you can win in the wilds (QA-070: bounties are listed ~3 times in 120 months, so for a rogue the journal and HUD fair-fight line are usually empty). In `Guidance.fair_fights`, when fewer than FAIR_FIGHTS_MAX entries were found, rate the current region's exploration foes: the enemies of fight encounters `Exploration` can roll here for this player now (reuse its own filtering: tags, realm gates, flags, season; read `roll_encounter` and extract a `static func eligible_fights(c, data, tags, flags, season, region_id) -> Array[String]` returning enemy ids if one does not exist), at most 2 rated, kind "explore", text "Explore here: %s (%s, %d in 100)". Count them in FAIR_FIGHT_MAX_RATED. Tests: a region with a fair exploration foe lists it when no mission/bounty is fair; missions still sort first at equal chance; lethal "Deadly" foes never listed (they are below 0.7 anyway). Re-run tests/sim/fair_fights.gd and paste the explore row win share. |
| FOUND-004 | systems | todo | Goals after Foundation (the journal's first goals end at the 3rd layer; after that only the realm/rank/milestone lines). Smallest version: `Guidance.foundation_goals(c, data, flags, clan) -> Array[Dictionary]` like `first_goals`, shown by the journal (and ticked by WU-131's banner, which keys off first goals: generalise it to both lists) only from Foundation Establishment until all are done: "Reach Foundation Establishment Middle", "Claim a cave abode" (`c.abode != ""`), "Temper your body to its first stage" (BodyTempering stage >= 1), "Win a fight against a Foundation foe" (a LifeStats counter if one exists; else `fights_won` gained since reaching Foundation via a stat recorded at the breakthrough), "Found a clan or rise to Inner Disciple" (clan != null or sect rank >= 2). Pick only goals whose state is already tracked; skip any that would need new persistent state and say so in Follow-ups. Tests in test_guidance.gd. |
| FOUND-005 | systems | todo spec | The journal says whether you would survive your next tribulation (Core Formation calls down the first one; DESIGN.md TRIB-001/QA-010: a player with no defense technique or shield talisman cannot pass it, and today the journal only says "Success calls down a Heavenly Tribulation"). *Spec:* src/core/systems/guidance.gd: new `static func tribulation_note(c: CharacterData, data: GameData) -> Dictionary` returning {} unless `Tribulation.has_tribulation(data, c.realm_index + 1)` and the player is in the last stage of their realm (`c.stage + 1 >= data.realms[c.realm_index].stage_count()`); else `p := Tribulation.preview(c, data, c.realm_index + 1)` and `{"text": ..., "tone": ...}` with text "Heavenly Tribulation ahead: %d waves%s, likely %d damage against your %d hp%s." (" and a heart demon" when `p.heart_demon`; " and a %d-point shield" when `p.shield > 0`). When `p.expected_damage >= p.max_hp + p.shield` append " You would not survive it yet: ready a shield talisman, train a defense technique or wear better armor." and tone "warning", else tone "normal". In `_breakthrough_entries` (~1227) add it as a "Breakthrough" entry right after the Qi line. Do not change `_cultivation_hint`. Tests (tests/unit/test_guidance.gd): Foundation Establishment Peak with no gear and no technique -> warning text with "would not survive"; same player with huge max_hp (give a high-hp armor or set Constitution very high; check `Combat.stats`) -> tone normal and no "would not survive"; Foundation Middle -> {}; Qi Refining 9th Layer (Foundation has no tribulation) -> {}; heart-demon wording when alignment <= the heart-demon threshold in realms.json. |
| RIVAL-009 | systems | todo spec | Your rival's attitude toward you (C-086/C-087 change rival favor and grudge, but nothing ever shows it). *Spec:* (1) data/karma.json `rival`: new `friendly_favor` (int 1-100, default 20) and `bitter_grudge` (int >= 1, default 10); document both in the `_doc` rival sentence, validate in `Rivals.validate` (wrong type or out of range is an error). (2) src/core/systems/rivals.gd: `static func attitude(c: CharacterData, rival: CharacterData, favor: int, data: GameData) -> String`: "bitter" when `Karma.grudge(c, rival.id) >= bitter_grudge` (bitter wins), else "friendly" when `favor >= friendly_favor`, else "proud"; `static func attitude_text(attitude: String) -> String`: "bitter" -> "they hold a grudge", "friendly" -> "a friendly rivalry", "proud" -> "". (3) guidance.gd `_rival_entry` (~1124): take the `favor` dict `journal()` already has (pass it through) and, when `attitude_text` != "", append "; %s" inside the parentheses: "Rival: Lin Feng, Qi Refining (ahead of you; a friendly rivalry)". Tests (tests/unit/test_rivals.gd + test_guidance.gd): default -> "proud" and the journal line unchanged; favor 20 -> friendly; grudge 10 with favor 50 -> bitter; validation rejects `friendly_favor` 0 and `bitter_grudge` "x". |
| CHOICE-003 | systems | todo spec | Choice tags also name alignment and cost (WU-146 shows `check` as "[Comprehension 12] ..."; 17 encounter choices with `min_alignment`/`max_alignment` and the ones that cost items show nothing until you fail them). *Spec:* src/core/systems/exploration.gd `check_tag` (~523): after the attribute and profession parts add (a) `min_alignment` -> `Alignment.tier_name(int(req.min_alignment), data)` (e.g. "Virtuous"), `max_alignment` -> the same for its value; (b) every negative entry of the choice's `effects.items` -> "%d %s" (count, item name; `spirit_stone` reads "%d stones"). Join all parts with ", " as now. Update the doc comment above `check_tag` and the encounters.json `_doc` sentence about `check`. If the encounter-window or encounter tests pin a label that now gains a tag, update them. Tests (tests/unit/test_encounter_choices.gd): a `min_alignment` 300 choice tags with that tier's name; a choice costing 2 of an item tags "2 <name>"; one costing 30 spirit stones tags "30 stones"; attribute + cost -> "Comprehension 12, 30 stones"; a plain choice still "". |
| RIVAL-011 | systems | todo spec | Word of your rival's death (Rivals.rival_of returns null once they die, so a rival lost to old age, a tribulation or a sect battle simply vanishes from the news). *Spec:* (1) src/core/systems/rivals.gd `static func death_news(c: CharacterData, rival: CharacterData) -> String`: "" when `rival == null`, alive, or `rival.cause_of_death` starts with "slain by " (the player's own kill already posts its line; Karma.commit uses "slain by <player name>"); "old age" -> "Word reaches you: your rival %s has died of old age."; "heavenly tribulation" -> "Word reaches you: your rival %s perished under the Heavenly Tribulation."; a cause starting "fell in battle" -> "Word reaches you: your rival %s %s." (cause as is); else "Word reaches you: your rival %s is dead.". (2) src/autoload/game_state.gd `_rival_news` (~2961): after the `rival_met` check and before `rival == null` returns, if `not world_flags.get("rival_death_news", false)` and `npcs.get(player.rival)` is a dead record, post `death_news` (tone "info", skip when "") and set the flag (also when the line was "" so a player kill never posts later). A save whose rival died earlier gets the line once at the next month; fine. Tests (test_rivals.gd + a GameState test): each cause's line; a player kill posts nothing; posted once over two months; nothing before `rival_met`. |
| RIVAL-010 | systems | todo | Rival encounters by attitude (after RIVAL-009). Encounters gain an optional `rival_attitude` ("friendly", "bitter", "proud"; validated, documented in encounters.json `_doc` next to `rival`): such an encounter only rolls when `Rivals.attitude` matches. The roll path needs the rival's favor: pass GameState's `npc_favor.get(rival.id, 0)` (or the whole dict) the way `rival` is checked today (find where `Rivals.allows` is called during the roll). Tests: an attitude-gated encounter rolls only for the matching attitude; validation rejects "angry". No data uses it yet (C-093). |
| WU-148 | world-ui | todo | The realm card names the rival you just passed. When a major breakthrough also surpasses the rival (RIVAL-006's line is posted in the same action), the RealmCard shows "You have surpassed <name>." as its first extra line (`card_lines` keeps MAX_EXTRA_LINES). Smallest wiring: GameState keeps `last_surpassed_rival: String` set in `_check_rival_surpassed` and cleared when the HUD opens the card (or on the next action); hud.gd passes it to the card. Test in test_realm_card.gd. |
| WU-149 | world-ui | todo spec | A failed breakthrough says what you learned (FOUND-003 shows lessons only in the next window's odds). *Spec:* src/autoload/game_state.gd `attempt_breakthrough`: right after the "Your breakthrough to %s failed (%d%% chance). Your qi scatters." post (~317) and also after the "fails in the tribulation" one (~319), when the failed attempt was a major breakthrough (the realm changes on success: compare `result` / the realm being attempted; layer failures inside a realm keep today's text), post (tone "info"): "The lessons stay with you: +%d%% on your next attempt." with `roundi(minf(data.failure_bonus * player.breakthrough_failures, data.failure_bonus_max) * 100)` (Cultivation already incremented `breakthrough_failures`), or "Your failures have taught you all they can (+%d%%)." once `data.failure_bonus * player.breakthrough_failures >= data.failure_bonus_max`. Check first whether minor failures also increment `breakthrough_failures` (cultivation.gd ~196 does it for every failure); if lessons apply to all failures, post the line for minor failures too and say so in the commit. Tests (test_game_session.gd or test_breakthrough_news.gd): seeded failing Foundation attempt posts "+3%"; the 4th failure posts the "taught you all they can (+9%)" line; a success posts neither. |
| WU-150 | world-ui | todo spec | Check the shorter HUD fair-fight line at 720p (WU-144 could not run `--win-shots`). *Spec:* run tests/sim/screenshot_screens.gd `--win-shots` (see WU-132's commit for the command; WU-145 ran its sibling mode in the cloud) at 1280x720 and 1280x800 and view the PNGs. If the "Fair fight:" line still ellipsizes, find the longest enemy name in data/enemies.json and make `fair_fight_line` drop the percent first ("Fair fight: <enemy> (<rating>)") when the full line would not fit the label width (measure with the label's font: `font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x`), keeping the tooltip. Add a test that the line for the longest enemy name at the HUD's 1280x720 width fits. Paste verdicts per shot in the commit; if nothing is cut off, land only the verdicts and the test. |
| WU-152 | world-ui | todo spec | Focus audit of the newest windows (WU-136's pattern in tests/unit/test_focus_audit.gd). *Spec:* add cases: (1) the encounter window with a "[Comprehension 12]" choice enabled, a locked one and the plain ones: focus lands on the first enabled choice, the locked one is skipped by ui_down; (2) the encounter window when every choice is locked: focus on the Walk away / dismiss button; (3) the world map with an active bounty hunt and offers (WU-147's marks): opening it focuses as before and ui_cancel closes it; (4) the breakthrough window with the lessons line (WU-145 case c): focus on Attempt. Fix any focus bug found in the window's own script (grab_focus after layout, `focus_mode` on new controls). Paste which cases needed a fix. |
| WU-151 | world-ui | todo | The rival's attitude on the sheet and in Look (after RIVAL-009). The character sheet's rival line and the rival's Look text (WU-139 / WU-141, `Rivals.relation_text`) add `Rivals.attitude_text` when not "" ("Rival: Lin Feng, ahead of you; they hold a grudge"); the NPC label's " (rival)" turns the warning color while bitter (WU-138 picks danger when a realm ahead; keep that first). Tests in the sheet and NPC Look tests. |
| WU-153 | world-ui | todo | The tribulation readiness on the attempt option (after FOUND-005). src/world/interactables/meditation_spot.gd: the breakthrough attempt option for a breakthrough that brings a tribulation adds `Guidance.tribulation_note(...).text` to its description (FOUND-002's `breakthrough_risk_text` skips tribulation breakthroughs today), so the player reads "You would not survive it yet" before clicking. Test in the meditation spot test. |
| C-090 | content | todo | Encounters a profession can answer (after CHOICE-002). Give 4 existing encounters (one per profession: doctor, alchemist, blacksmith, beast tamer; pick ones that already fit, e.g. a wounded traveller, a cracked cauldron, a broken blade, a sick spirit beast, across at least 3 regions) a choice with `requires.min_profession` rank 1, rewarding a little better than the best plain choice (some stones, favor, profession xp if Effects supports it, or `grateful_npc`). Genre voice. Tests: EFF-001's effect walk passes; a data test that each new choice is blocked at rank 0 and allowed at rank 1 (`Exploration.check_choice`). |
| C-091 | content | todo spec | More attribute checks in the first year (CHOICE-001 is on main, like C-088). *Spec:* attributes roll 5-15 (data/attributes.json), so 12+ is about a third of new characters before C-082's +1 encounters. In data/encounters.json give 4 existing Qi Refining encounters (not C-086's rival ones, not ones that already have a requires choice; list your picks by id in the commit) one new choice each with `requires: {"min_attributes": {"<attr>": 12}}`, one per attribute: spirit (sense something hidden: a herb, a qi pocket), fortune (a lucky find: 20-40 stones), charisma (talk your way to a better deal or a new acquaintance: favor or `grateful_npc`), constitution (endure: carry, dig, swim; qi 40-60 or a herb). Rewards a little better than the best plain choice, never a fight. Keep every plain choice. Genre voice, second person, no gendered words for the player. Tests: EFF-001's effect walk passes; a data test (next to C-088's) that each new choice is blocked at 11 and allowed at 12 via `Exploration.check_choice`, and that the four attributes are all covered. |
| C-092 | content | todo spec | Small rival follow-ups (C-087 and C-089 Follow-ups). *Spec:* (1) data/encounters.json: C-087's Azure Peak sparring challenge gives its accept choice `rival_favor` 5 and qi +40 in its effects (win or lose, the bout itself teaches), so accepting is worth it; decline stays as is. (2) data/help.json "Your Rival" page (C-089): add that the journal's Household section lists "Rival: <name>, <realm> (<where you stand>)" once you have met them (RIVAL-004), that word of their major breakthroughs reaches you, and that a rival you surpass works harder (RIVAL-008) and can overtake you again. Plain, short, second person. Tests: EFF-001's effect walk and the help data test pass; extend C-087's data test to check the accept choice's favor. |
| C-094 | content | todo spec | Help page "Choices and Checks" (CHOICE-001/002, WU-146; CHOICE-003 adds alignment and costs). *Spec:* data/help.json: a new page after "Exploring and Encounters": some choices need an attribute ("[Comprehension 12]"), a profession rank ("[Doctor, Apprentice]"), a moral standing or an item they cost; a locked choice says why in brackets; when every choice is locked you can walk away; attributes can still grow a little from rare encounters (C-082); profession ranks come from working and crafting. Keep it under the length of the longest existing page. Test: the help data test passes (and the page order test if there is one). |
| C-096 | content | todo spec | Encounters where you give something up (effects with a negative `items` entry are already payable-checked by `Effects.check`). *Spec:* data/encounters.json: 3 new once-only Qi Refining encounters in 3 different regions, each with a choice that costs an existing cheap item (grep data/items.json for a low-grade healing pill (`heal_injury` effect), a ration-like food or a common herb; cost 1-2) and a plain choice: (1) a dying rogue cultivator on the road begs for a pill (give: alignment +15, `grateful_npc` (see C-011/encounters `_doc`); walk on: nothing), (2) a mortal family's child burns with fever (give a herb or pill: alignment +10, region renown if Effects supports it, else favor), (3) a wandering alchemist trades a recipe hint for a spirit herb (give: a Dao insight or `practice_days`/qi 60). Second person, genre voice, no gendered words for the player. Tests: EFF-001's effect walk passes; a data test that each giving choice is blocked without the item (`Exploration.check_choice`) and allowed with it. |
| C-095 | content | todo | Encounters a profession can answer, at Foundation (after C-090, same pattern). Give 3 existing Foundation Establishment encounters (or add 3 once-only ones) a `requires.min_profession` choice at rank 2 (array master, talisman master and one of C-090's four), rewarding a little better than the best plain choice. Tests like C-090's. |
| C-093 | content | todo | Rival encounters by attitude (after RIVAL-010). data/encounters.json: 3 once-only rival encounters, Qi Refining or Foundation: `rival_attitude` "friendly" (they share a cultivation insight or a meal: qi or a pill), "bitter" (they spread a rumor against you or try to spoil your herb gathering: a non-lethal `fight_rival` choice or pay to settle it), "proud" (they publicly challenge you at a sect or market: accept `fight_rival`, decline costs a little renown or favor). Genre voice. Tests: EFF-001's walk; data test that each has a valid attitude. |
| C-097 | content | todo | The tribulation help page says how to read the journal's readiness line (after FOUND-005): "Heavenly Tribulation ahead: N waves, likely D damage against your H hp", what to do when it says you would not survive yet (shield talismans from the Talisman Master or market, a defense technique, armor, Constitution), and that the heart demon comes for the deeply demonic. Test: help data test. |

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
| QA-079 | qa | todo spec | Refresh the stale baseline sections (QA-075 Follow-up: `tools/balance.sh --check` showed 22 changed lines in "first hour, curious" and 16 in "log noise" on main before QA-075). *Spec:* run `tools/balance.sh --check` on current main and list every section that differs. Refresh each with `tools/balance.sh --section "<name>"`. In the commit body paste, per refreshed section, the medians/summary lines before and after, and name the commits that most likely moved them (`git log --oneline -- tests/sim data src/core` since the section's last refresh). Flag under Follow-ups any change that reads like a regression: first-win median day later, more seeds with no win, log lines/month up > 20%, a topic's busiest month doubled. No code or data changes. |
| QA-080 | qa | todo | Are the renowned requests paid right? (C-062 Follow-up: their stones are estimates against "a week of the region's gather income".) Using the economy sim's gather-income numbers (tests/sim/simulate_economy.gd, the "economy" baseline section), print per C-062 encounter: its stones (and items' value), the region's median weekly gather income at that realm, and the ratio. Paste the table in the commit; list under Follow-ups any request paying under 0.5x or over 2x a week (the content worker retunes). No data changes. |
| QA-081 | qa | todo | Does the readiness line tell the truth? (after FOUND-005) For typical players at Foundation Establishment Peak (no gear / best buyable gear, with and without Stone Skin, with and without a readied shield talisman, alignment 0 and -500), compare `Guidance.tribulation_note`'s verdict ("would not survive" or not) with `Tribulation.endure` survival over 200 seeded runs each. Paste the table; Follow-ups if the line says "survive" where survival is under 60%, or "would not survive" where it is over 60% (the systems worker then changes the threshold). |
| QA-078 | qa | todo | How the rivalry plays out (RIVAL-005/006 landed; input for RIVAL-008). New tests/sim/rival_story.gd (or a section in first_hour.gd): seeds 1-10, 36 months, default and curious policies: day of the first meeting, the rival's realm/stage every 6 months next to the player's, the day the player surpasses them (or never), rival breakthrough news lines posted, rival encounters met (C-086). Add a docs/balance_baseline.txt section. Flag if the rival is surpassed in under a year in most seeds (then the rival never feels like a threat). |
| QA-071 | qa | todo spec | Refresh the early-inheritances baseline (reviewer note: QA-064's numbers predate INH-001's Rotting Pier gate; C-082 landed, so attributes can now grow by 1 from three once-only encounters). Re-run tests/sim/early_inheritances.gd (seeds 1-10, 36 months) and refresh that section of docs/balance_baseline.txt; paste before/after per inheritance (passable, claimed, median month) in the commit body. If the curious policy never meets C-082's attribute encounters, say how many seeds explored the region long enough. Follow-ups: any inheritance still claimed by fewer than 3/10 seeds, with the blocking trial. No data changes. |
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
