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
Next (planner 2026-10-15 00:10): 18 tasks landed (GIFT-002, FEST-004, RUMOR-002, EFF-001, SECRET-003, LETTER-005, QI-002,
MENTOR-002, WU-102/109/111/112/114/115, C-068/069, QA-059/060). C-071 closed: MENTOR-002 made the data change (pointers
min_favor 20 -> 10). Claimed now: C-063, QA-061. Reviewer (to 597d486) filed no P0; its notes become WU-117 (gossip window
over a refusal) and FEST-005 (festival activity at every merchant). New theme **your first fighting style**: QA-060 and
C-068 found the curious player never learns a combat technique (0% vs a Mist Wolf bare, 81-99% with Iron Fist + Stone
Skin), though the Wandering Merchant in Qingshi sells Manual: Iron Fist for 15 stones; the only hint disappears once Elder
Mo teaches the breathing method. GUIDE-019 (spec file) names the manual, merchant and price; MENTOR-003 and WU-118/WU-119
surface it in the pointers refusal, the shop and the techniques screen; C-072 has Elder Mo say it; QA-062 teaches the sim
to buy it and re-measures pointers and deaths. Also WU-116 (first-hour screenshot pass), LOG-001 (QA-059 follow-up).
| id | role | status | task |
|---|---|---|---|
| GUIDE-019 | systems | todo spec | Your first fighting style. *Spec:* [docs/specs/GUIDE-019.md](specs/GUIDE-019.md). `Guidance.first_combat_manual/first_combat_hint` name the cheapest combat manual a merchant in the current region sells (Iron Fist, Wandering Merchant, 15 stones in Qingshi); the newcomer hint survives Elder Mo's breathing method; `Combat.loss_advice` says "You know no fighting style yet". |
| FEST-005 | systems | todo spec | The festival activity only at fitting stalls (reviewer 11th run note 3: "Float a lantern" shows at every merchant, also smithies that FEST-004 keeps festival goods away from). *Spec:* (1) src/autoload/game_state.gd `festival_activity_here()` (~2297) takes `stock_tags: Array = []` and skips an event unless `WorldEvents.sold_by(data, event_id, stock_tags)` (untagged merchants keep the entry, as today). (2) src/world/interactables/merchant.gd `get_options` passes its `stock_tags`. (3) Any other caller (grep `festival_activity_here`, e.g. guidance or HUD) keeps the old behaviour with the default `[]`. Tests in tests/unit/test_game_session.gd (or wherever FEST-003/WU-100 test `festival_activity_here`): during the Lantern Festival in a region with one, `festival_activity_here(["equipment", "ore", "smithing"])` is "" and `festival_activity_here(["herb", "ore"])` and `festival_activity_here([])` return the event id. |
| MENTOR-003 | systems | todo spec | Pointer refusals that tell you what to do (after GUIDE-019; QA-060 Follow-up). *Spec:* src/core/systems/mentorship.gd `check_pointers` (~56): (1) the "no technique" reason (~73) becomes "You have no technique they could correct yet." + " " + `Guidance.first_combat_hint(c, data, region_id)` when that is non-empty (else keep "find a technique manual first."). Mentorship is core and may call Guidance (both static, pure); add `region_id: String = ""` to `check_pointers` and pass `current_region` from GameState's callers (grep `check_pointers`). (2) The favor reason (~68) appends " Chats and gifts raise it." and, when a taste is known for that NPC (`Family.known_tastes` or the told hint flag `taste_told_<npc>`, see GIFT-002/WU-108 for how they are read), " They are fond of <item or tag name>." (pick the first known like, same wording helper WU-101's Look text uses if there is one). (3) Update tests that match the old strings. Tests in tests/unit/test_mentorship.gd: no technique in Qingshi names the Iron Fist manual; low favor with a known like names it; low favor with nothing known has only the chats-and-gifts sentence. |
| LOG-001 | systems | todo | One line per mission fight (QA-059 Follow-up 1: a fight mission posts "Sect mission: X.", the fight lines and "Mission complete: X. (...)"). In `GameState.take_mission` (game_state.gd ~1968) drop the separate "Sect mission: %s." post and instead pass a short context to the fight so its first line reads "Sect mission: <name>. You face ..." if `fight_enemy` posts a "You face" line you can prefix cheaply (read fight_enemy first; if it needs a new optional `prefix: String = ""` parameter, add it). The fail and complete lines stay. Grep tests for "Sect mission:" and update. Test: a won fight mission posts exactly one line containing "Sect mission:" and it also contains "You face". |
| LETTER-006 | systems | todo | A child's letter warms the child (LETTER-002 Follow-up). When a family letter from a child (`relation` "child") is received, the child gains favor like a friend's letter would (find where `Letters.monthly` applies a friend kind's favor / visit effects; children's favor lives where FAM-011's `max_child_favor` is applied, cap at it). Spouse letters: same with `dual_cultivation.max_favor` as the cap, if spouses get nothing today. Tests in tests/unit/test_letters.gd for both. |
| REF-001 | systems | todo | Sect-call bookkeeping into SectFactions (reviewer 3rd run note). Move `_expire_sect_calls` and the sect-call flag logic out of src/autoload/game_state.gd into static functions in src/core/systems/sect_factions.gd (`SectFactions.expire_calls(flags, today) -> PackedStringArray` returning the lines to post, or similar), GameState only posts and emits. Also fix the odd "calls on its senior disciples" line when the call mission is on cooldown for a senior: post nothing new in that case. No behaviour change otherwise; move or add unit tests for the moved logic. |
| WU-117 | world-ui | todo spec | No gossip window over a refusal (reviewer 11th run note 1). *Spec:* src/world/interactables/merchant.gd `_ask_rumors`: `var lines := GameState.hear_rumors()`; emit `EventBus.gossip_requested` only when `lines` is non-empty (`WorldEvents.rumors` always returns at least the shrug line, so empty means `_can_act` refused and already posted why). Update the GossipWindow's empty-text fallback comment accordingly (keep the fallback). Test: with the player unable to act (dead, or however test_game_session makes `_can_act` false), `hear_rumors()` is empty and the merchant does not emit `gossip_requested` (connect a flag to the signal; instantiate the merchant script like other interactable tests do). |
| WU-118 | world-ui | todo spec | Manuals in the shop say what they teach (first fighting style theme). *Spec:* src/ui/shop_screen.gd: `static func manual_note(c: CharacterData, data: GameData, item_id: String) -> String`: for an item whose `effects.learn_technique` names a technique: " (known)" if `Techniques.knows(c, id)`, else " (<kind word>)" with combat -> "fighting style", method -> "cultivation method", body -> "body art", cultivation -> "breathing art" (fallback: the raw kind); "" for other items. Append it to Buy-tab row labels (~318, before " (festival)"). In `compare_text` (~262), for a manual return "Teaches %s. You already know it." / "Teaches %s, a %s you do not know yet." When the player knows no combat technique, a combat manual's row is drawn in the accent colour (UIStyle.ACCENT; see how WU-108 colours gift rows). Tests in tests/unit/test_shop_screen.gd: Iron Fist manual for a bare character -> " (fighting style)", after learning -> " (known)", a pill -> "", compare_text for both cases. |
| WU-116 | world-ui | todo spec | First-hour screenshot pass (priority: smooth the first hour). *Spec:* extend tests/sim/screenshot_screens.gd (read its header; run with `--resolution 1280x800`) with a fresh character in Qingshi Village: character creation (root roll shown), the HUD right after the intro dialogue (hints visible), Elder Mo's dialogue, the Wandering Merchant's Buy tab, the first exploration result / encounter window, a lost fight's combat report (bare player vs mist_wolf, so loss advice shows), the journal on day 1. Look at each PNG at 1280x800 **and** at 1280x720 (Steam Deck is 1280x800; also check nothing needs more than 720 high). Fix clipping, overlap, unreadable or cut-off text you find (small UI fixes only, no core changes); list each screen and verdict in the commit body, and put bigger problems under Follow-ups. Don't commit the PNGs. |
| WU-119 | world-ui | todo | The techniques screen when you know no fighting style (after GUIDE-019). In src/ui/techniques_screen.gd (find the screen opened by `toggle_techniques`), when the player knows no `kind == "combat"` technique show one dimmed line at the top of the combat list (or the list's empty text): `Guidance.first_combat_hint(GameState.player, GameState.data, GameState.current_region)`. Nothing when it returns "". Extend the screen's test (or tests/unit/test_focus_audit.gd's techniques case) to check the line appears for a bare character and focus still lands on a focusable control. |
| WU-123 | world-ui | todo | Focus audit of the newest windows (like WU-103): the Gossip window (WU-111), the secret realm notice banner not stealing focus from an open menu (WU-114), the shop with a friend's price and a wrapped title (WU-102/WU-112), the People list with a request (WU-115). Add the missing cases to tests/unit/test_focus_audit.gd; fix any screen that opens without focus or doesn't close on ui_cancel. List what you covered in the commit body. |
| WU-120 | world-ui | todo | Show the way to the manual in the world (after GUIDE-019). While `Guidance.first_combat_manual(player, data, current_region)` names a merchant in the current region, that merchant interactable (match `display_name`) draws a small scroll marker above itself in `_draw()` (placeholder art, like other interactable markers; see how WU-097 drew festival awnings or how letter/bounty marks are drawn) and redraws on `EventBus.player_changed`; the marker goes away once a combat technique is known. Keep the logic a static helper on the merchant script (`static func shows_manual_mark(c, data, region_id, display_name) -> bool`) and test it: true for the Wandering Merchant for a bare character in Qingshi, false for the Herb Seller, false after learning Iron Fist. |
| C-072 | content | todo spec | Elder Mo points you to the Wandering Merchant (first fighting style theme). *Spec:* data/dialogue/ (Elder Mo's file; find it via data/npcs.json Elder Mo's dialogue id). After he teaches (or offers) the breathing method, add one node or extend an existing line: he says breathing keeps you alive but will not win a fight, and that the Wandering Merchant by the village square sells a crude boxing manual (Iron Fist) for a handful of stones; Stone Skin is worth saving for if you join the Azure Cloud Sect (its sect shop sells it). No new effects or items; keep his voice (read his existing lines). If the dialogue system validates node links (test_dialogue*.gd), keep them valid. Test: the dialogue test that walks every node still passes; add an assertion in the Elder Mo test (if one exists) that some node text contains "Iron Fist". |
| C-074 | content | todo spec | Something for Qi Refining in the third year (C-069's list: year 3 brings only Foundation/Core openings). *Spec:* add one Qi Refining inheritance to data/inheritances.json with `appears_years` 3 and `deadline_years` 10, in misty_forest or withered_bone_marsh (whichever has no QR inheritance yet; check `region` fields; a region needs an `inheritance` place in data/regions.json, add one like C-069's Mound of the Rusted Sword did if missing). Stages: realm qi_refining with min stage 4 if the schema supports a stage gate (else just the realm), a Spirit or Fortune attribute test (~11), and a non-lethal fight a typical player at QR stage 6 wins 55-70% (`tools/godot.sh --headless --path . -s res://tests/sim/simulate_combat.gd`, paste the row; reuse an enemy or add one in data/enemies.json with `lethal: false`). Reward: one QR technique or method manual with no other source (check `Items.has_known_source`-style tests: grep `has_known_source` in tests for the manual list) plus a few herbs or pills; no spirit stones. Voice and fields like C-069's. Add a `rival_news` line. Commit body: the updated "what opens in years 1-3" list. |
| C-063 | content | todo spec | The Mist Wolf mission waits until it is a fair fight (claimed 2026-10-14 23:25; C-068's worker measured a *typical* player at 81/95/99% vs mist_wolf at QR stages 0/1/2, so if your step (1) agrees, change no data, add the step (5) guard test and say so in the commit; the real gap is players with no technique, which GUIDE-019 and QA-062 take) (QA-052 and QA-048: every early curious-player death is "Cull the Mist Wolves", taken at its gate, Qi Refining 1st Layer `min_stage` 1, at 18-35% odds). Two claims have expired without landing, so keep it small: one data change plus one test. *Spec:* do **not** change mist_wolf's stats or `realm_training` (the first-fights question C-009 is the owner's). (1) Run `tools/godot.sh --headless --path . -s res://tests/sim/simulate_combat.gd` (read its header for args; you only need the typical player's rate vs mist_wolf at Qi Refining stages 1-6). (2) In data/sect_missions.json set `cull_mist_wolves.min_stage` to the lowest stage where that rate is >= 55% (QA-052 expects about 3). (3) If any other `min_rank` 0 fight mission rates below 45% at its own gate, raise its `min_stage` the same way; list before/after rates in the commit body. (4) Every sect must still have a non-fight mission at min_rank 0 for a 1st-layer newcomer; if one has none, say so in Follow-ups. (5) Test in tests/unit/test_sects.gd: every min_rank 0 fight mission is not rated "Dangerous" or "Deadly" for a typical player at its gate, if `Sects.mission_danger` (or the mission board's danger helper) makes that easy to call; otherwise say why not in the commit. Do **not** run the whole tools/balance.sh; QA-057 refreshes the baseline afterwards. |
| C-070 | content | todo | Help pages for this week's features (like C-055). In the help data (find where C-055 added pages: grep `bounties` in data/help*.json or src/ui/help_screen.gd), add short pages: merchant gossip (ask any merchant; what rumors can tell you), letters that ask for something (answer in person before the deadline; the map marks the asker's region), family letters, a friend's price (a merchant's letter lowers prices in their region for a while), festival activities (ask a merchant; once per festival), regions that grow richer in qi through your deeds, your first fighting style (manuals teach techniques; a combat technique is what wins early fights; merchants sell cheap ones), and word of a secret realm before it opens. 2-4 sentences each, no numbers that data can change. Tests: the help data test keeps passing (add the new ids to any list it checks). |
| C-062 | content | todo | Requests for the renowned (after RENOWN-002). One `min_renown` encounter per region besides the two RENOWN-002 wrote (Fallen Star Market, Azure Peak, Withered Bone Marsh, Myriad Peaks Ridge), once-only, fitting the region (a guild master asks you to escort a shipment; an elder of a minor sect asks you to judge a duel; marsh villagers beg you to end a corpse refiner; a ridge beast clan asks for a truce), gated at the region's realm, rewards about a week of the region's gather income plus favor/renown; any fight 45-75% at its gate (paste simulate_combat.gd rows). Tests: data test that every region has a min_renown encounter. |
| C-065 | content | todo | Festival activities (after FEST-003). Give qingming_festival and mid_autumn_festival an `activity` like FEST-003's Lantern one: Qingming "Sweep the ancestors' graves" (alignment +3, a little qi; bonus at Spirit >= 12: a whisper from the departed, small `breakthrough_bonus` 0.01), Mid-Autumn "Moon-viewing on the market roof" (qi; bonus at Charisma >= 12: a stranger's moon cake and favor... use items, e.g. 1 moon_cake). Small rewards, no stones beyond 5. Tests: data test that every festival has an activity. |
| C-075 | content | todo | Rumors that point at what is coming (after SECRET-003/C-069). Add 4-6 entries to data/rumors.json: one per region that has a secret realm or inheritance opening in years 1-3 (Verdant Remnant, Peach Blossom Grotto, Mound of the Rusted Sword, Fallen Star Vault, Sunken Sword Tomb), hinting where and roughly when without numbers data can change ("the old sword mound east of the market has started to hum"); gate by `min_realm` like C-067's realm-gated rumors and by `blocked_flags` once found if a flag exists. Keep rumor ids unique (RUMOR-002 reports duplicates). Test: the rumors data test passes; add nothing else unless a new field is needed. |

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
| QA-062 | qa | todo spec | The curious sim learns a fighting style (QA-060/C-068: the curious player knows 0 techniques at months 6/12/24, so pointers refuse and every Mist Wolf fight is bare). *Spec:* (1) tests/sim/first_hour.gd curious policy (`_curious_month`, ~82): once per life, as soon as the player has stones for it, buy and use the cheapest combat-technique manual that a merchant in the current region sells (compute it in the sim the way GUIDE-019 describes: `Items.merchant_sells` over the region's merchant places and combat `TechniqueDef`s; if GUIDE-019 has landed, call `Guidance.first_combat_manual` instead), through GameState's buy and use-item actions (grep `func buy` / `func use_item` in game_state.gd). Record the month it happened. Also practice it: if the policy never practices techniques, add one practice block a month when a technique is unmastered (GameState's practice action). (2) Re-run tests/sim/pointer_reasons.gd (10 seeds x 24 months) and tests/sim/simulate_curious_years.gd (seeds 1-10, 36 months). In the commit body give, before/after: median month the manual was learned, successful pointers per life, reason counts, deaths and the top 3 killers, and Mist Wolf mission win rate. (3) Refresh the affected tools/balance.sh sections only (curious years, first hour if it changes). Keep each run under ~60 s. Follow-ups: anything still unreachable. |
| QA-061 | qa | todo | Bounty pay after C-064 (C-064 Follow-up, reviewer 10th run note 5). Re-run tests/sim/simulate_bounty.gd for the Core Formation sword madman bounty (C-064 moved it to Core at 220 stones) and the new second Qingshi bounty; compare stones per day with gathering at that realm the way QA-053b did. If either is more than ~1.6x or under ~0.5x gathering, say which value you would change under Follow-ups (no data change). Refresh only the bounty section of docs/balance_baseline.txt (`tools/balance.sh --section`). |
| QA-044 | qa | todo | Do pointers and spars matter? (after QA-062, which makes pointers reachable in the sim): in tests/sim/first_hour.gd add a curious-policy switch that never uses pointers/spars, run 12 months for seeds 1-10 with and without, and print median technique levels and fights won at months 6 and 12. Under Follow-ups say whether pointers/spars meaningfully speed the first year (or are too strong: more than ~2 extra technique levels by month 12), with numbers. No data changes. |
| QA-045 | qa | todo spec | Why is the first Foundation year so gentle? (QA-039 Follow-up: 107/120 runs spent no artifact life, median win share 100%, 0 injuries; DESIGN.md's QA-007 target is ~60-85% against a foe of your own realm and stage.) *Spec:* extend the QA-039 sim (tests/sim/simulate_foundation_year.gd or wherever it landed) with `--threats=slip|fight` (default slip, today's behaviour). For seeds 1-10 and both policies print per region: encounters met, fights fought, fights evaded via sensed threats, the median stage reached by month 3/6/12, and a histogram of the rated odds (Combat sim helper the combat baseline uses) of every fight actually fought (<50%, 50-75%, 75-95%, >95%). Answer in the commit body, with numbers: (a) are fights rare or just easy? (b) do C-031's stage gates leave only foes the player has already outgrown by the time they appear? (c) does the player outgrow the region within months (stage climbs fast)? List under Follow-ups the 3 data changes you would make (enemy ids or gate stages), without making them. Add the `fight` run as its own tools/balance.sh section and refresh only that section. Keep it under ~60 s. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates). *Spec:* reuse QA-039's sim with the realm as an argument (`--realm=core_formation`): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each region whose encounters include Core Formation fights (Myriad Peaks Ridge and any other; list them from data), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent (tribulation not included) and medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. If QA-045 has landed, include its `--threats` switch and odds histogram. |
| QA-035 | qa | todo | Economy sim: sect months every month (ECON-001b Follow-up). tests/sim/simulate_economy.gd only runs sect months every 12 months, so mission cooldowns never bind and sect income can't be compared fairly with profession work (still 1.5-1.9x for Doctor/Beast Tamer). Make the sim run the sect policy month by month (respecting `Sects.mission_cooldown_left`, duty, stipends) for a sect life, keep the same seeds, print per-profession "sect stones / work stones" ratios, update tools/balance.sh's baseline. If any profession's ratio is still > 1.5x, list the top 3 mission ids by net stones under Follow-ups (the planner files the content retune); don't retune data in this task. Also paste the economy section before/after ENC-003 (fading encounters; its commit skipped that comparison) and say whether income moved. Keep runtime under ~60 s. |
| QA-057 | qa | todo | Curious sim after C-063 (after C-063 and QA-062 land; skip the re-run QA-062 already did and only add what C-063 changed). Re-run tests/sim/simulate_curious_years.gd for seeds 1-10 and compare with QA-054's numbers (deaths 20, early-ending seeds 0): deaths, the death log's top 3 killers, and months to the first sect mission. If the Mist Wolf is no longer the top killer, name the new one with its rated odds at the fatal take. Refresh that tools/balance.sh section. Follow-ups: the data change you would make for the new top killer (no data change here). |

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
