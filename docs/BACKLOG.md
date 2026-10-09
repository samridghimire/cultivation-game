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
Next (planner 2026-10-09 14:15): 12 tasks landed (MISS-001, RENOWN-002, GUIDE-018, WU-081/084/086/090, C-046/050/052/055,
MAT-001). C-052 put 11 bounties in data, but a board lists the first 3 eligible in data order whatever region it stands in,
so most of them never show: **BOUNTY-002** (boards list local and nearby hunts first) is the systems worker's top task, then
WU-092 shows how far each hunt is. QA-052 Follow-up 1 is **C-063** (gate the Mist Wolf mission until it is a fair fight;
enemy stats stay as they are while C-009 is open). New theme: **your name opens doors**: renown raises bounty pay
(RENOWN-003), people greet you by your title (NEWS-002), renowned requests look special (WU-094), and the year review
counts discoveries, bounties and mastered regions (YEAR-003). WU-093 screenshots the week's new screens; WU-095 puts the
artifact's lives on the HUD (after WU-091).
| id | role | status | task |
|---|---|---|---|
| BOUNTY-002 | systems | todo spec | Bounty boards list local and nearby hunts first (C-052 Follow-up: 11 bounties now, but `Bounties.offers` takes the first `offers` (3) eligible in data order, so a Qingshi or Fallen Star board shows the same early rows and most regions' hunts never appear). *Spec:* (1) src/core/systems/bounties.gd: `static func offers(c: CharacterData, data: GameData, today: int, region_id: String = "") -> Array[Dictionary]`. Collect every eligible bounty exactly as today (region exists, not the active one, off cooldown, `Exploration.realm_allows`) **before** applying the limit. When `region_id != ""`, stable-order them into three groups: bounties whose `region == region_id`, then those whose region is a direct route of it (`Exploration.is_nearby(data, region_id, b.region)`), then the rest; data order inside each group (build three arrays and concatenate; do not use sort_custom, it is not stable). Then cut to `int(data.bounty_config.get("offers", 3))`. `region_id == ""` keeps today's exact behaviour. (2) src/world/interactables/bounty_board.gd: pass `GameState.current_region`. grep for other `Bounties.offers(` callers (journal, guidance, sims) and pass the region where one is meaningful (the player's current region); leave sims as they are. (3) data/bounties.json `_doc`: say boards list hunts in their own region first, then neighbouring regions, then the rest. No data value changes. Tests (tests/unit/test_bounties.gd): with a fixture of 5 bounties in data order far, far, neighbour, local, local and offers 3, `offers(..., "qingshi_village")` returns local, local, neighbour; with region "" it returns the first three in data order; a local bounty on cooldown is skipped and the next group fills the slot; a bounty above the realm gate never shows. Integration (test_game_session.gd or the bounty board test): the Qingshi board's first option is a Qingshi bounty for a Qi Refining 3rd Layer player. Acceptance: tools/test.sh passes; no save change. |
| GIFT-001 | systems | todo spec | NPCs like and dislike gifts. *Spec:* (1) data/npcs.json: each named NPC may get `"likes": [ids or tags]` and `"dislikes": [ids or tags]` (an entry matches an item id or one of the item's `tags`; document in `_doc`, validate every entry is a known item id or a tag used by at least one item). Generated NPCs get none. data/family.json `acquaintance` gets `"gift_like_mult": 2.0` and `"gift_dislike_favor": -3` (documented, validated; absent = 1.0 / 0). (2) family.gd: `static func gift_taste(data: GameData, npc_id: String, item_id: String) -> int` (1 liked, -1 disliked, 0 neutral; dislikes win when both match). `give_gift` takes an optional `npc_id: String = ""` and: liked = `ceili(gift_value * gift_like_mult)` (still capped by gift_max_favor - favor), disliked = `gift_dislike_favor` (negative, the item is still taken), and returns `taste` in its result. A disliked gift is allowed even at gift_max_favor (check_gift's "politely declines" stays for neutral/liked only). (3) GameState.give_gift passes the npc id and posts "<Name> is delighted." / "<Name> frowns at the <item>." after the favor line. Once a taste is shown, remember it: world flag `taste_<npc>_<item>` = 1 or -1, so the UI (WU-089) can mark items. (4) `static func taste_hint(data, npc_id) -> String`: "<Name> is fond of <first like as a readable word: item name, or the tag (herb -> herbs, ore -> ores, talisman -> talismans)>." for the NPC dialogue/chat line; GameState.chat appends it once favor >= 20 (one line, only the first time: flag `taste_told_<npc>`). Tests (test_family.gd): liked doubles, disliked lowers favor and takes the item, tag match and id match, dislike beats like, cap still applies, no config = old numbers, the flag is set, taste_hint text, validator rejects an unknown id/tag. Give 2 NPCs likes in the test fixture or in data (Elder Mo likes `herb`, Herbalist Lan dislikes `demonic`) so the game shows it at once; C-058 does the rest. |
| FEST-002 | systems | todo spec | Festival stalls (C-047 Follow-up): during a festival, the region's merchants sell festival goods. *Spec:* (1) data/world_events.json: an event may have `"shop_items": [item ids]` (document in `_doc`; validate known items with a price > 0; add "shop_items" to the allowed keys list in WorldEvents.validate). (2) world_events.gd: `static func shop_items(data: GameData, active: Array, region_id: String) -> Array` = union of `shop_items` of events active in the region, in data order, no duplicates. (3) GameState: `func festival_stock() -> Array` returning that for `current_region`. shop_screen.gd (line ~185 `Items.shop_stock(...)`): append festival_stock ids not already in the list, at the end, under the existing tabs (they fall into their `Items.category`); their label gets " (festival)". Items.buy needs no change (it does not check stock). (4) Data, so it shows at once: two items in data/items.json, priced modestly and untagged so ordinary merchants never sell them: "Moon Cake" (price 6, usable: qi +15, description of lotus-seed paste) and "Paper Lantern" (price 4, a gift item: no effect, high gift value for its price is not needed). Mid-Autumn Moon Festival `shop_items: ["moon_cake"]`, Lantern Festival `["paper_lantern"]`. test_obtainability must still pass (if `Items.has_known_source` does not know world-event stock, teach `_gives`/sources about `shop_items` with the source text "Festival stall: <event name>"). Tests (test_world_events.gd): shop_items while active and not when inactive or in another region; validator rejects an unknown item; the source text. C-061 adds more goods. |
| RENOWN-003 | systems | todo spec | A known name earns better bounty pay (your name opens doors). *Spec:* (1) data/regions.json `renown.tiers` entries get optional `bounty_mult` (float >= 1.0; absent = 1.0): Known 1.1, Respected 1.2, Renowned 1.3; document it in the regions `_doc` renown sentence and validate in `Renown.validate` (a number >= 1.0). (2) renown.gd: `static func bounty_multiplier(c: CharacterData, data: GameData, region_id: String) -> float` = the tier for `value(c, region_id)`'s `bounty_mult`. (3) bounties.gd `complete`: `stones = int(round(reward_stones * Renown.bounty_multiplier(c, data, b.region)))`; return a Dictionary `{"stones": int, "bonus": int}` instead of int (bonus = stones - reward_stones) and update every caller (grep `Bounties.complete(`; GameState and tests). Renown for the bounty itself is gained after payment, as today, so the tier used is the one you had when you won. (4) GameState posts the existing claim line plus " Your name earned you %d more." when bonus > 0. (5) The bounty board option label (bounty_board.gd) shows the paid amount (`reward x mult`) instead of the raw reward when mult > 1, e.g. "33 stones (+10% for your name)". Tests: test_renown.gd multiplier per tier, absent = 1.0, validator rejects 0.9; test_bounties.gd complete pays 1.2x at Respected and bonus is reported; board label text. |
| NEWS-002 | systems | todo | People greet you by your name (your name opens doors). data/regions.json `renown` gets optional `greetings`: [{min_tier (int, index into tiers, >= 1), text (with {name} = the NPC's name, {title} = your title there)}], validated in Renown.validate (min_tier in range, non-empty text); write 4 lines, e.g. "{name} brightens: so you are the one they call {title}." `Renown.greeting(c, data, region_id, npc_name, day) -> String`: "" below the lowest min_tier, else one line among those whose min_tier <= your tier index, picked by `posmod(day, n)` (no rng). GameState.chat posts it (category "progress") at most once per NPC per 30 days (world flag `greeted_<npc>` = the day). Generated and named NPCs alike; family members never (they know you). Tests: no line below Known; line text with name and title; once per 30 days; validator rejects min_tier 0 or out of range. |
| YEAR-003 | systems | todo | The year review counts your adventures (YEAR-001 + newer stats). `LifeStats.year_summary` gets one more line, right after the fights line: from the deltas of `discoveries`, `bounties_done` and `regions_mastered`, a single sentence naming only the non-zero ones, e.g. "You found 2 hidden places, claimed 1 bounty and mastered the Misty Forest." (mastered: just "mastered 1 region" — the summary has no region names). Keep the cap at 4 lines but drop the deeds line before the new line when over the cap (order: realm, fights, adventures, crafted, stones, deeds, floors; the cap trims from the end). Check the year review UI (grep `year_summary`) still fits; the yearly snapshot must include these stats (they are in life_stats, so it should). Tests in test_life_stats.gd: each part alone, all three, none (no line), the cap. |
| WU-088 | world-ui | todo | (Claimed 13:17.) The mission board remembers a fall (after MISS-001). A mission with `Sects.last_loss_days_ago >= 0` shows its disabled reason from check_mission (MISS-001's "You fell to this mission recently...") and, once offered again, its description gets "You lost this fight N days ago." in the danger color; the danger rating line stays. Tests: board entry text after a forced loss and after the cooldown. |
| WU-091 | world-ui | todo | (Claimed 14:17.) HUD crowding check with everything on (after WU-082/WU-087). Extend tests/sim/screenshot_first_hour.gd (or add a capture) with a character who has a goal line, a hunt line, an active festival, a renown title, 3 hints and a pending letter, at 1280x800 and at UI scale 115%. Look at the PNGs (do not commit them): no HUD text overlaps another, the hint panel does not cover the bottom bar, nothing is clipped. Fix what you see (trim, wrap, or drop the lowest-priority line when space runs out). Tests: a layout test that the HUD panels' rects do not intersect with all lines shown. |
| WU-094 | world-ui | todo spec | Renowned requests look special (RENOWN-002 landed: encounters may carry `min_renown`). *Spec:* (1) src/ui/encounter_window.gd `title_for(enc, discovery, deep_path)` (line ~57): when `enc.has("min_renown")` and neither discovery nor deep path applies, the title is "A request for the renowned: <encounter name>"; the title label uses UIStyle's accent color for it (as discovery titles do, if they have a color; otherwise the accent). (2) The message the exploration posts for such an encounter (GameState explore path, grep `last_explore_deep_path` for where the deep-path text is chosen) gets the prefix "Because your name is known here, " on its first line; keep the category. (3) Help: add one sentence to the renown help page in data/help.json ("Once you are known in a region, its people bring you requests they would not trust to a stranger."). Tests (test_encounter_window or a new test): title for a min_renown encounter, discovery title still wins, a plain encounter unchanged; the explore message prefix. Acceptance: test.sh passes; gamepad focus unchanged. |
| WU-093 | world-ui | todo spec | Screenshot the week's new screens (WU-021 tool). *Spec:* extend tests/sim/screenshot_screens.gd's mid-game character so every newly shown block has data: 3 letters (Letters.remember), renown 60 in Qingshi and 110 in the Misty Forest, a mastered region flag, an active bounty, an active festival (WorldEvents), a lost mission (`mission_losses`). Capture (add captures if missing): journal (Letters section), character sheet (Renown block, life record), world map details for the mastered region, the Qingshi bounty board option list (ChoiceMenu), a shop with the renown discount header. Run `xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 --resolution 1280x800 -s res://tests/sim/screenshot_screens.gd`, open each PNG (Read the image) and fix what you see: overlapping or clipped text, a section pushed off screen without scrolling, a list without focus. Do not commit PNGs. Commit body: one line per screen (fine / what you fixed). Tests: tests/unit/test_steam_deck_layout.gd keeps passing; add a case for any screen you changed. |
| WU-096 | world-ui | todo | The respawn screen teaches the lesson (QA-052: the curious player retried the same fight right after each respawn). In src/ui/respawn_screen.gd under the summary: (1) when the death was a fight, "You had about N% odds against <foe>. Grow stronger before you face it again." (GameState stores `enemy_id` and the pre-fight `Combat.win_chance` in `pending_respawn` where it is built; grep `pending_respawn =`; absent keys = no line, so old saves still load); (2) "Recharging the artifact costs N spirit stones (you have M)." from `CreationArtifact.recharge_cost`, in the warning color when lives_left <= 1. Keep the panel within 1280x800 (test_steam_deck_layout). Tests: static text helpers for both lines with and without the new keys. |
| WU-097 | world-ui | todo | Festival stalls in the world (C-047/WE-002 festivals are active per region via WorldEvents). While a festival is active in the current region, draw a small placeholder stall (`_draw()`: an awning in red/gold, two hanging lanterns) beside each merchant place, built when the region builds and refreshed on `days_advanced`/region change; it is decoration only (no interaction, no collision). Lantern Festival and Mid-Autumn get lanterns, Qingming willow branches (pick by event id; unknown festivals get lanterns). Respect the Ambient effects setting only if it already gates decor. Tests: the stall node exists next to the Qingshi merchant with a festival active and not without one. Look at it with tests/sim/screenshot_regions.gd (do not commit PNGs). |
| WU-089 | world-ui | todo | Gift menu shows tastes (after GIFT-001). In the NPC "Give a gift" list, an item whose `taste_<npc>_<item>` flag is 1 gets " (liked)" and the accent color, -1 gets " (disliked)" and the danger color, and the description line shows the favor it would give (`Family.gift_value` x like mult, or the dislike penalty). Unknown tastes show nothing. Liked items sort first. Tests: labels and order with a liked and a disliked flag set. |
| WU-092 | world-ui | todo | Bounty board says how far each hunt is (after BOUNTY-002). Each "Hunt:" label ends with "(here)" for the board's region or "(N days away)" from `Exploration.routes_from`/`travel_days` for a direct route (flying sword days included), nothing for further regions (their description says "far from here"). Tests: label text for a local, neighbouring and far bounty. |
| WU-095 | world-ui | todo | The artifact's lives on the HUD (after WU-091, which fixes HUD crowding first). The HUD status block shows "Lives N" next to the realm/qi line (short, one word + number); at 1 life it uses the warning color, at 0 the danger color with "Final life" text. Update it on `player_changed` and `player_respawned`. Respect WU-091's layout test (extend it with this line on). Tests: text and color at 3, 1 and 0 lives. |

| C-063 | content | todo spec | The Mist Wolf mission waits until it is a fair fight (QA-052 Follow-up 1: every early curious-player death was "Cull the Mist Wolves", taken at its gate (Qi Refining 1st Layer, `min_stage` 1) at 18-35% odds). *Spec:* do **not** change mist_wolf's stats or `realm_training` (the first-fights question C-009 is the owner's). (1) Run `tools/godot.sh --headless --path . -s res://tests/sim/simulate_combat.gd` (read its header for args) to get the typical player's win rate vs mist_wolf at each Qi Refining stage 1-6. (2) In data/sect_missions.json set `cull_mist_wolves.min_stage` to the lowest stage where that rate is >= 55% (QA-052 expects about 3). (3) If any other `kind: hunt`/`guard` mission with `min_rank` 0 sits below 45% at its own gate, raise its `min_stage` the same way (list them all in the commit body with before/after rates). (4) A newcomer must still have a sect mission they can take at Qi Refining 1st Layer: check `deliver`/non-fight missions exist at min_rank 0 for each sect (there are), and if a sect has none, say so in Follow-ups. (5) Re-run `tools/balance.sh` and commit the refreshed baseline with the change. Tests: test_data_references/test_sects keep passing; add a data test in tests/unit/test_sects.gd that every min_rank 0 fight mission rates at least "Risky" (not "Dangerous"/"Deadly") for a typical player at its gate, if `Sects.mission_danger` makes that easy to call; otherwise state why not in the commit. |
| C-051 | content | todo spec | Road encounters (TRAV-006 landed: encounters tagged ["road"] are rolled by `Exploration.road_encounter` after a journey; see the caravan fire and overturned cart in data/encounters.json). 8 more encounters tagged ["road"] in data/encounters.json spread over the realms with `min_realm`/`max_realm`: Qi Refining (a highwayman who can be paid off or fought, a lost child to walk home), Foundation (a sect patrol checking tokens, a dying cultivator's storage ring: take it or bury him), Core and up (a beast-tide straggler fight, a fallen star fragment, an ambush by demonic cultivators gated by `max_alignment`, a sword-flying senior who shares a little qi and a pointer on the way). Fights must be fair at their gate (run tests/sim/simulate_combat.gd and paste the rows; entry 40-75%). No stone reward above one week of gather income at that realm. |
| C-053 | content | todo | Letters with more voices (after LETTER-001). 8 more letter kinds in data/family.json `letters`: from a spouse away in a sect, a former rival grudgingly impressed (needs favor), an elder you met at a lecture, a child in a sect asking for pills (a request that sets a flag the journal shows), a merchant offering a discount, a friend's wedding invitation, news of a death in their clan, a gift of a technique hint (small Dao insight chance). Keep gifts small. Tests: validator, every kind's text formats with {name}/{region}. |
| C-058 | content | todo | Gift tastes for the named NPCs (after GIFT-001). Give every named NPC in data/npcs.json 1-2 `likes` and 0-1 `dislikes` true to who they are (a sword maniac likes weapons/ores, an alchemist herbs, a righteous elder dislikes `demonic`, a demonic cultivator likes `blood_art`, a mortal likes cheap things such as `paper_lantern` if FEST-002 landed). Prefer tags; use item ids for personal favorites. Keep at least half the NPCs liking something buyable at their region's merchants so the mechanic is usable. Tests: validator; a data test that every named NPC has at least one like. |
| C-059 | content | todo | More maps to find (C-057 Follow-ups). (1) A merchant rumor about the dying explorer: in the Fallen Star Market or mountain-region merchant gossip (the `discovery_rumor`/rumor lines GUIDE-015 uses, or an existing rumor list; grep `rumors`) a line like "A wounded treasure hunter came down from the cliffs muttering about a drowned sword." (2) One more realm with an `entry_item` at Core Formation level (check data/secret_realms.json for a Core realm without one) and its map from two sources (a Core-gated choice encounter in a nearby region and an auction lot or a deed/bounty reward). Tests: test_obtainability, entry refused/allowed like C-057's test. |
| C-060 | content | todo | A second deeper path (C-048 Follow-up). In the Misty Forest (its first deep path is the hidden valley, EXPL-001), add a `min_explores` 60 encounter that `requires_flag` the first one's flag and is once-only: the valley's guardian spirit, old now, asks you to carry its seed to the Azure Peak cliffs (a choice: plant it there for a lasting small qi density flag and alignment +10, or eat it for a breakthrough-bonus pill-like effect at -alignment). Rewards at Qi Refining late / Foundation early. Tests: data test that it needs the first path's flag; a session test (explore_many with a forced explore_days) that it appears only after the first path. |
| C-061 | content | todo | Festival stalls stocked (after FEST-002). 2-3 festival goods per festival in data/items.json + `shop_items` in data/world_events.json: Lantern Festival (paper lantern, sweet rice balls: a little qi), Qingming (willow branch: a minor ward buff 3 days; ancestor incense: alignment +3), Mid-Autumn (moon cake, osmanthus wine: a small favor-gift item). Cheap (2-15 stones), untagged so ordinary merchants never sell them, effects small. Tests: validators; every festival has at least 2 shop items; obtainability. |
| C-062 | content | todo | Requests for the renowned (after RENOWN-002). One `min_renown` encounter per region besides the two RENOWN-002 wrote (Fallen Star Market, Azure Peak, Withered Bone Marsh, Myriad Peaks Ridge), once-only, fitting the region (a guild master asks you to escort a shipment; an elder of a minor sect asks you to judge a duel; marsh villagers beg you to end a corpse refiner; a ridge beast clan asks for a truce), gated at the region's realm, rewards about a week of the region's gather income plus favor/renown; any fight 45-75% at its gate (paste simulate_combat.gd rows). Tests: data test that every region has a min_renown encounter. |
| C-064 | content | todo | Bounty follow-ups (C-052 Follow-ups). (1) Qingshi posts only one bounty: add a second, a fair Qi Refining 1st-3rd Layer foe that can be met in Qingshi (a new `village`-tagged, lethal: false enemy is fine, e.g. a hen-stealing fox spirit or a drunk bully disciple; add it to a Qingshi encounter too so `Bounties.hunt_roll` can find its trail), win rate 60-80% at its gate in simulate_combat. (2) The sword madman and iron-horn rhino bounties sit at the 45% floor: raise their `min_stage` (or `min_realm`) until the typical player wins >= 55%. Rewards stay ~1.5x a week of the region's gather income. Commit body: win rates before/after. |

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
| QA-054 | qa | todo spec | (Claimed 14:04.) The curious sim stops dying to one wolf (QA-052 Follow-ups 2). *Spec:* in tests/sim/simulate_curious_years.gd (and any shared policy helper, grep the mission choice that compares `Sects.mission_danger != "Deadly"`): (1) skip a mission whose last attempt was lost until the player's rated odds against its enemy rise by 15 points or 60 days pass (keep a per-mission dict in the policy; if MISS-001 has landed, also respect `check_mission`, which already refuses during the loss cooldown); (2) skip any mission rated "Dangerous" whose `Combat.win_chance` is below 0.5 when the artifact has 1 life or less; (3) recharge the artifact when stones allow (use the GameState action the UI uses; grep `recharge`) once stones exceed 2x the price. Re-run 10 seeds x 36 months and put in the commit body: deaths before/after, lives spent, final deaths, and the top 3 killers after the change. Refresh only the "three curious" balance.sh section. Guard (in the sim's own check, like QA-041's): at most 1 of 10 seeds ends before month 36. No data changes. |
| QA-053b | qa | todo spec | Bounty economics and a baseline refresh (QA-053 parts 2-3; part 1 landed). *Spec:* (1) Economy: add a "bounty hunter" line to tests/sim/simulate_economy.gd: a Qi Refining 4th Layer typical player who takes the Misty Forest bounty whenever it is off cooldown and explores there, for 12 months; print stones/month from bounties vs gathering in the same region, and the share of hunts won. Target: bounty income about 1.5-3x a week of gather income per bounty (BOUNTY-001 sized them so); if it is far off, say so under Follow-ups with the reward you would set (no data change). (2) Refresh the combat and economy sections (`tools/balance.sh --section combat`, `--section economy`), which drifted after C-045, RENOWN-001 (renown discounts) and QA-032 (min_stage 1 missions), and explain any row that moved by more than 10 points. |
| QA-048 | qa | todo spec | A curious player who tries everything (QA-041 Follow-up). *Spec:* [docs/specs/QA-048.md](specs/QA-048.md). |
| QA-045 | qa | todo spec | Why is the first Foundation year so gentle? (QA-039 Follow-up: 107/120 runs spent no artifact life, median win share 100%, 0 injuries; DESIGN.md's QA-007 target is ~60-85% against a foe of your own realm and stage.) *Spec:* extend the QA-039 sim (tests/sim/simulate_foundation_year.gd or wherever it landed) with `--threats=slip|fight` (default slip, today's behaviour). For seeds 1-10 and both policies print per region: encounters met, fights fought, fights evaded via sensed threats, the median stage reached by month 3/6/12, and a histogram of the rated odds (Combat sim helper the combat baseline uses) of every fight actually fought (<50%, 50-75%, 75-95%, >95%). Answer in the commit body, with numbers: (a) are fights rare or just easy? (b) do C-031's stage gates leave only foes the player has already outgrown by the time they appear? (c) does the player outgrow the region within months (stage climbs fast)? List under Follow-ups the 3 data changes you would make (enemy ids or gate stages), without making them. Add the `fight` run as its own tools/balance.sh section and refresh only that section. Keep it under ~60 s. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates). *Spec:* reuse QA-039's sim with the realm as an argument (`--realm=core_formation`): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each region whose encounters include Core Formation fights (Myriad Peaks Ridge and any other; list them from data), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent (tribulation not included) and medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. If QA-045 has landed, include its `--threats` switch and odds histogram. |
| QA-044 | qa | todo | Do pointers and spars matter? (after QA-048, which teaches the curious policy pointers and spars): in tests/sim/first_hour.gd add a curious-policy switch that never uses pointers/spars, run 12 months for seeds 1-10 with and without, and print median technique levels and fights won at months 6 and 12. Under Follow-ups say whether pointers/spars meaningfully speed the first year (or are too strong: more than ~2 extra technique levels by month 12), with numbers. No data changes. |
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
