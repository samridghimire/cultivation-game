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
Next (planner 2026-10-09 08:15): the long middle is filling in. Landed: met encounters fade (ENC-003), deeper paths
(EXPL-001), discoveries look special and show on the map (WU-070/073), unvisited regions dim (WU-061), herb seasons in
the inventory (WU-075), high-region seasons (C-049), Soul Formation people (C-018). In flight: festivals (WE-002), rumors
(GUIDE-015), discoveries everywhere (C-046). New: give exploring a target and a payoff. A deeper path announces itself
and is found on the next explore (GUIDE-016, WU-078), bounties turn a region into a hunt (BOUNTY-001, WU-076, C-052),
journeys have road encounters (TRAV-006, C-051, WU-080), friends write letters (LETTER-001, C-053, WU-081). UI: a
first-hour screenshot pass on the Deck resolution (WU-077) and a focus audit of the newest screens (WU-079).
| id | role | status | task |
|---|---|---|---|
| WE-002 | systems | todo spec | Festivals: world events with fixed `months`, `festival` marker, `favor_mult` modifier for chat/gifts, journal line, a winter Lantern Festival in Qingshi. *Spec:* [docs/specs/WE-002.md](specs/WE-002.md). |
| GUIDE-015 | systems | todo spec | Rumors of discoveries (after TRAV-005, landed). *Spec:* optional `"discovery_rumor": "<one sentence>"` on a region in data/regions.json (document in `_doc`; validator: only on a region that has a `discovery`). New `static func discovery_rumors(c: CharacterData, data: GameData, flags: Dictionary, region_id: String) -> PackedStringArray` in guidance.gd: rumor texts of regions with a rumor whose `"discovered_" + id` flag is unset and that are reachable now (the current region, or `Exploration.check_travel(c, data, region_id, id).ok`), current region first, then data order. (1) `Guidance.journal` Opportunities: the first one as "Rumor: <text>" (tone "normal"). (2) Merchant rumors: where GameState builds the `extra` list for `WorldEvents.rumors` (grep `WorldEvents.rumors(`), add the first rumor not about the current region. Write Misty Forest's: "Herb-pickers say an old shrine hides in a hollow tree somewhere in the Misty Forest." Tests: a fresh Qingshi character sees the Misty Forest rumor in the journal; after `world_flags["discovered_misty_forest"] = true` it is gone; a region gated above the player's realm never shows its rumor; the validator rejects a rumor on a region without a discovery. |
| EXPL-002 | systems | todo spec | How much of a region you've seen (after ENC-003, which adds `encounter_counts`). `static func region_progress(c: CharacterData, data: GameData, region_id: String) -> Dictionary` in exploration.gd: `{"met": n, "total": m}` over encounters that share a tag with the region's `encounter_tags`, are not `requires_flag`/`rival`/`discovery_only`, and whose `min_realm` (if any) is at or below the player's realm; `met` counts those with `encounter_counts[id] > 0` or whose `blocked_by_flag` is set. Journal Opportunities line for the current region "<Region>: you have seen N of M happenings here." only when N < M. LifeStats key `happenings_seen` (distinct encounter ids met overall, synced from `encounter_counts.size()`) and a milestone "Wanderer of Many Roads" at 50. Tests: counts rise as encounters are noted; a realm-gated encounter is not in `total` until the realm is reached; milestone at 50. |
| MS-005 | systems | todo spec | Seeker of Hidden Places (after C-046). LifeStats key `discoveries` = number of world flags `discovered_<region>` that are true (sync it where `regions_visited` is synced, life_stats.gd ~97; it needs the flags, so add a `flags` param or sync from GameState after explore) and a milestone in data/milestones.json `seeker_of_hidden_places` "Seeker of Hidden Places", "Find the hidden places of four regions.", life_stat discoveries min 4. `LifeStats.backfill` counts existing flags for old saves. Tests: the count follows the flags; the milestone fires at 4 and only once; backfill. |
| GUIDE-016 | systems | todo spec | A deeper path announces itself and is found (EXPL-001 Follow-up: nothing tells the player a path opened, and the encounter then only sits in the pool at its weight). *Spec:* (1) exploration.gd: `static func open_deep_paths(c: CharacterData, data: GameData, region_id: String, flags: Dictionary) -> Array[String]`: ids (data order) of encounters with `min_explores` that share a tag with the region's `encounter_tags`, `min_explores <= familiarity(c, region_id)`, `realm_allows` and `alignment_allows` pass, `requires_flag` (if any) is set and `blocked_by_flag` (if any) is unset. `static func deep_path_for(c, data, region_id, flags) -> Dictionary`: the first of those that has a `blocked_by_flag` (once-only), else {}. (2) GameState `_explore_once`: right after `Exploration.discovery_for` comes back empty, try `deep_path_for`; if found use it as the encounter (like the discovery, but without setting `discovered_*`), set `last_explore_deep_path = true` (new var, reset each explore; WU-078 may use it) and prefix the log text with "A hidden path: " (instead of "A discovery: "). Its own effects should set its `blocked_by_flag` (check the Misty Forest one in data/encounters.json does; if it does not, add `set_flag` to its effects and say so). (3) Guidance.unlock_notices: for each visited region and each id in `open_deep_paths` that has a `blocked_by_flag`, `_add_notice(out, flags, "deep_path_" + id, "Your days in %s have shown you a path you had missed. Explore there again." % region name)`. Tests (tests/unit/test_deeper_paths.gd): familiarity below the threshold gives no open path and no notice; at the threshold the notice appears once and the next `GameState.explore` in that region meets the deep-path encounter with the "A hidden path: " prefix; after it the flag is set and later explores never repeat it; a realm-gated deep path waits for the realm. |
| BOUNTY-001 | systems | todo spec | Bounties (core): take a bounty on a region's foe, exploring that region may pick up its trail, win for stones. *Spec:* [docs/specs/BOUNTY-001.md](specs/BOUNTY-001.md). |
| TRAV-006 | systems | todo spec | Things happen on the road. Today a journey is just days passing (plus a rare grudge ambush). *Spec:* (1) data/regions.json gets a top-level `"road": {"chance_per_day": 0.08, "max_chance": 0.4, "encounter_tags": ["road"]}` (document it in the file's `_doc`; GameData loads it into `data.road: Dictionary`, default {} meaning no road encounters; validate numbers in 0..1 and tags a non-empty array). (2) exploration.gd: `static func road_encounter(c: CharacterData, data: GameData, days: int, flags: Dictionary, rng: RandomNumberGenerator, season: String) -> Dictionary`: with probability `min(max_chance, chance_per_day * days)` roll `roll_encounter(c, data, road.encounter_tags, flags, rng, null, 1.0, season, "")`, else {} (no rng draw at all when `data.road` is empty, so existing seeded tests keep their numbers). (3) GameState: make `_road_ambush()` return bool (true when a hunter appeared). In `travel`, after it, if no ambush and `_can_act()`, call `road_encounter` and, if non-empty, run it through the same path as an explore encounter: extract the tail of `_explore_once` from `LifeStats.add(player, "encounters")` to the end into `func _meet_encounter(encounter: Dictionary, prefix: String = "") -> Dictionary` and call it from both, with prefix "On the road: " for road ones (the discovery prefix moves into the same param). Then `EventBus.region_changed` and autosave as today. (4) Two road encounters in data/encounters.json tagged ["road"]: a fortune (a merchant caravan shares its fire: a little qi, days 0) and a choice (an overturned cart: help for +alignment and a day, or loot it for stones at -alignment); no fights here (C-051 adds those, realm-gated). Tests (test_exploration.gd + test_game_session.gd): no draw when `road` is empty; chance scales with days and caps; with chance forced to 1.0 a travel posts "On the road: " and counts an encounter; a choice road encounter leaves `pending_encounter` set after arrival and `choose_encounter` (or whatever answers it) works in the new region. |
| LETTER-001 | systems | todo | Letters from people who like you (makes relationships live between visits). Data: `data/family.json` gets a `letters` block `{"monthly_chance": 0.25, "min_favor": 40, "kinds": [{"id", "weight", "text" (may use {name}, {region}), "effects" (shared effect keys, e.g. a small gift item or qi), "min_favor"?}]}` with 3 kinds to start (a greeting with a small herb, news that they moved up a stage, an invitation to visit that grants +5 favor when you next chat with them: set a flag `letter_visit_<npc>`). Core `Letters` (src/core/systems/letters.gd): monthly, for the living non-family named or known NPC with the highest favor >= min_favor (ties: data order), roll the chance, pick a kind by weight, apply effects, return `{npc_id, text}`; GameState posts "A letter from <name>: <text>" ("social" or the log topic chat uses) on month end and keeps the last 10 in `CharacterData.letters` (to_dict/from_dict with default []). The chat action consumes `letter_visit_<npc>` for +5 extra favor. Tests: no letter below min_favor; deterministic with a seeded rng; the gift lands in the inventory; the visit bonus applies once; save round trip. |
| WU-077 | world-ui | todo spec | First-hour screenshot pass at the Steam Deck resolution. *Spec:* add a `--first-hour` mode to tests/sim/screenshot_screens.gd (or a sibling script; keep the file's header doc in sync) that builds a **fresh** character (CharacterFactory, Qingshi Village, day 0, no sect) instead of the mid-game one and captures: the HUD on arrival, Elder Mo's dialogue, the journal, the explore option menu at the Misty Forest edge (or the nearest explore site), an encounter choice window, a combat report after one fight, the inventory and the character sheet. Run it at 1280x800 with xvfb-run (command in the file header) and look at every PNG. Fix up to 3 real problems you see (clipped or overlapping text, a panel off screen, unreadable contrast, a focus ring missing), each with a test where one can catch it (label size/visibility checks like test_ui_scale's). List what you looked at and what you changed in the commit; anything bigger than ~100 lines goes under Follow-ups. Do not commit PNGs. |
| WU-078 | world-ui | todo spec | The explore spot tells you about deeper paths (EXPL-001 landed; GUIDE-016 makes the path appear). *Spec:* in src/world/interactables/explore_site.gd `get_options()`, build one extra description line for both Explore options via a new testable static `static func familiarity_line(c: CharacterData, data: GameData, region_id: String) -> String` (put it in explore_site.gd or Guidance): "You know these paths well (N days explored)." once N >= 1, plus " Something deeper may open after M days." when `Exploration.next_deep_path(c, data, region_id)` is M >= 0; "" for N = 0 and no deep path. Append it to the outlook with "\n". If GameState has `last_explore_deep_path` (GUIDE-016) when this lands, give the encounter window title "Hidden path: <name>" in UIStyle.ACCENT like WU-070's "Discovery:" (follow its code); if GUIDE-016 has not landed, skip that part and say so. Tests (tests/unit/ next to WU-070's or the explore site's tests): N = 0 gives ""; after 3 explore days the line names 3 days; with the Misty Forest deep path above familiarity it names its day count; once familiarity passes every deep path, no "deeper" clause. |
| WU-079 | world-ui | todo | Focus audit for the screens and windows added since QA-020: world map (WU-061/073 marks), family tree, remappable controls (UI-003c), message log topic filters (UI-002b), companion UI, artifact inner world/garden, the encounter "Discovery:" window. Extend tests/unit/test_focus_audit.gd so each opens, has a focused control after one frame and can be closed with ui_cancel; fix any that fail. Also check each fits at 1280x800 with UI scale 115% (like WU-026). |
| WU-072 | world-ui | todo | Festivals look festive (after WE-002). When a world event with `festival: true` starts in the current region, show the WU-062 banner style with the event name and a one-line subtitle from its start text, and a chime (reuse a positive Audio cue); the HUD event line and the world map mark say "Festival: <name>" instead of "<name>!"; the NPC menu's Chat and Give gift descriptions add "(festival: favor x2)" when `WorldEvents.favor_multiplier` > 1 in the current region. Tests: banner text when the Lantern Festival starts in Qingshi; the map mark text; the chat description with and without the festival. |
| WU-074 | world-ui | todo | Region familiarity on the world map (after EXPL-001 and EXPL-002). The world map details panel of a visited region adds "Explored N days" (`Exploration.familiarity`), "Seen N of M happenings" (`Exploration.region_progress`) and, when `next_deep_path` >= 0, "Deeper paths after M days". Unvisited regions show none of it. Tests: a fresh character's Qingshi details show "Explored 0 days"; after explore_many(3) "Explored 3 days"; Misty Forest unvisited shows none. |
| WU-076 | world-ui | todo | Bounty boards in the world (after BOUNTY-001). New place type `bounty_board` (interactable in src/world/interactables/, placeholder art in place_art.gd, validate the type where place types are validated) with one board in Qingshi Village and one in Fallen Star Market (clear of other places and HUD panels: WU-017/WU-023 tests). Options: one per `Bounties.offers` ("Hunt: <enemy> in <region>, <stones> stones" with `Appraisal.danger_text` for the enemy in the label and the bounty `text` as description, disabled with `check_take`'s reason), plus "Abandon your hunt (<enemy>)" when one is active. Journal line comes from BOUNTY-001. Tests: the board lists the Qi Refining bounty for a fresh character at Qi Refining 4th Layer; taking it disables the others with "You are already on a hunt."; abandon re-enables after the cooldown. |
| WU-080 | world-ui | todo | Road encounters on the way (after TRAV-006). When a travel produced a road encounter (expose `GameState.last_travel_road_encounter: String`, set in travel), the arrival card waits until the encounter/choice window closes (or shows after it), and the travel option's description adds "Roads are quiet" / "Roads see traffic" from `data.road` chance for that trip's days (e.g. ">= 30%: the road is long; things may happen on the way"). Tests: forced-chance travel shows the choice window before the arrival card; description text for a 1-day and a 6-day route. |
| WU-081 | world-ui | todo | Letters you can reread (after LETTER-001). Journal gets a "Letters" section (newest first, up to 5, "<name>: <text>") and a small banner "A letter from <name>" (WU-042 banner style) when one arrives. Tests: the section lists a letter after a forced month end with a high-favor NPC; banner text. |
| C-046 | content | todo | Discoveries for every region (after TRAV-005): one `discovery_only` encounter per region that has none (Qingshi Village, Fallen Star Market, Azure Peak, Withered Bone Marsh, Myriad Peaks Ridge) and set each region's `discovery`. Each is a small fortune or a choice (no forced lethal fight), true to the region, rewarding curiosity with something useful at that region's realm (a herb or material, a little qi, a recipe scroll, a hint flag for a later encounter); keep stone rewards modest (<= one week of that region's gather income). Use `min_realm` only if the region itself is realm-gated. Tests come from TRAV-005's validator; add a data test that every region has a discovery. |
| C-045 | content | todo spec | Gear past Core Formation (NS-006 Follow-up: the best non-demonic gear is grade 4, so the sim's typical player fights Nascent Soul and Soul Formation foes in Core gear; tests/sim/combat_balance.gd `best_gear` allows grade <= realm_index + 1). Add a grade-5 weapon and armor (Nascent Soul) and a grade-6 weapon and armor (Soul Formation) to data/items.json (righteous or neutral; stats on the curve: grade 4 is attack 40 / defense 25 + max_hp 170, the demonic grade-5 banner is attack 85 with a lifespan cost; aim ~60 / 35 + 240 for grade 5 and ~85 / 48 + 330 for grade 6), Blacksmith recipes for them in data/recipes.json using NS-002/NS-006 materials, recipe scrolls as rewards of NS-006 enemies or a Myriad Peaks Ridge merchant at a steep price. Then run simulate_combat.gd: the NS-001/NS-006 foes' entry rates will rise; keep the "same curve" (entry 10-75%, peak 75-100%) by retuning enemies if needed, paste before/after rows, refresh the baseline. |
| C-047 | content | todo | Festivals (after WE-002). Two more festivals in data/world_events.json with `festival: true`, fixed `months` and monthly_chance 1.0: a spring Qingming-style ancestor festival at Azure Peak (favor_mult 1.5, encounter_tags ["festival_spring"]) and a mid-autumn moon festival at Fallen Star Market (favor_mult 2.0, price_mult 0.9, encounter_tags ["festival_autumn"]); give the Lantern Festival encounter_tags ["festival_winter"]. Write 2 encounters per festival tag in data/encounters.json (a lantern riddle contest for a small prize, a moon-viewing poetry gathering that grants a Dao insight chance or qi, an ancestor-grave sweeping that gives alignment +5 and a little qi, a choice to pick a pocket in the festival crowd for stones at -alignment, ...), no lethal fights, rewards modest. One help line in the world events help page. Tests: data validators; a test that each festival tag has at least 2 encounters. |
| C-048 | content | todo spec | Deeper paths for every region (after EXPL-001). One `min_explores` encounter per region besides Misty Forest (Qingshi 15, Fallen Star Market 20, Azure Peak 25, Withered Bone Marsh 25, Myriad Peaks Ridge 30 days), each `blocked_by_flag` once-only, true to the region (an old herbalist's hidden garden above the village, a smuggler's tunnel under the market, a cliff cave with a dead elder's sword intent, a drowned shrine in the marsh, a beast king's abandoned lair), rewards at the region's realm worth about a week of that region's gather income or a Dao insight; one may be a choice. Optionally a second, `min_explores` 60, follow-up via `requires_flag` in one region. Tests: data test that every region has a `min_explores` encounter sharing its tags. |
| C-055 | content | todo | Help pages for what landed this week (no help yet): discoveries (first exploration of a region, the map mark), deeper paths (days explored, the journal line), familiar encounters fading so new ones surface, herb seasons in the inventory and at gather sites, unvisited regions on the map. In data/help.json, follow the existing pages' tone and length (2-5 short lines each, or one page with five bullets; check the help screen's page size). Tests: existing help validators; add the page ids to any test that lists required pages. |
| C-050 | content | todo | Rumors for every discovery (after GUIDE-015 and C-046). A `discovery_rumor` for every region with a `discovery`: one sentence, the kind of thing a merchant or herb-picker would say, pointing at the region without spoiling the reward. Data test: every region with a discovery has a rumor. |
| C-051 | content | todo | Road encounters (after TRAV-006). 8 more encounters tagged ["road"] in data/encounters.json spread over the realms with `min_realm`/`max_realm`: Qi Refining (a highwayman who can be paid off or fought, a lost child to walk home), Foundation (a sect patrol checking tokens, a dying cultivator's storage ring: take it or bury him), Core and up (a beast-tide straggler fight, a fallen star fragment, an ambush by demonic cultivators gated by `max_alignment`, a sword-flying senior who shares a little qi and a pointer on the way). Fights must be fair at their gate (run tests/sim/simulate_combat.gd and paste the rows; entry 40-75%). No stone reward above one week of gather income at that realm. |
| C-052 | content | todo | Bounties for every region (after BOUNTY-001). Bring data/bounties.json to 10-12 bounties: 2 per region, at the region's realm span, each on an enemy that already appears in that region's encounters, rewards ~1.5x a week of the region's gather income (economy baseline), `text` in a notice-board voice ("The Qingshi elders offer ..."). Run simulate_combat.gd for each target at the bounty's gate and keep each at 45-80%; paste the rows. |
| C-053 | content | todo | Letters with more voices (after LETTER-001). 8 more letter kinds in data/family.json `letters`: from a spouse away in a sect, a former rival grudgingly impressed (needs favor), an elder you met at a lecture, a child in a sect asking for pills (a request that sets a flag the journal shows), a merchant offering a discount, a friend's wedding invitation, news of a death in their clan, a gift of a technique hint (small Dao insight chance). Keep gifts small. Tests: validator, every kind's text formats with {name}/{region}. |

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
| QA-051 | qa | todo | Every recipe scroll can be found (C-049 Follow-up: `recipe_bog_lily_qi_pill` has no source, so the Bog Lily Qi Pill cannot be learned). In tests/unit/test_obtainability.gd, extend the "every manual and pill has a source" test (~line 178) to items whose effects have `learn_recipe`, and add a test that every recipe in data/recipes.json is learnable: either known from the start (check how starting recipes are given) or taught by a scroll that has a known source. Fix every gap in data in the same commit (for the bog lily scroll: sell it at a Withered Bone Marsh merchant through its stock tags at its 450 price, or make it a reward of an autumn marsh encounter); list each fix in the commit. Use KNOWN_UNOBTAINABLE only for scrolls meant as unique rewards and say why. |
| QA-049 | qa | todo spec | Make tools/balance.sh usable again (NS-007 skipped its baseline refresh: "first-hour sim took >35 min"; QA-046 then timed the whole run at ~8m45s, so first find out what made NS-007's run slow, e.g. running alongside tools/test.sh). *Spec:* (1) Time every section of tools/balance.sh (`time` each `run`, print to stderr) and find the slow one(s); profile with fewer seeds/months to see whether the cost is the sim's policy (e.g. explore_many loops, long seclusion) or a game-code hot spot (a per-day O(n^2) scan, NPC sim, journal/hint rebuilds in a loop). (2) If it is a real game-code hot spot that also hurts the game (anything per-day over all NPCs/encounters), fix it with a test and note the before/after time; if it is only the sim, trim it (fewer seeds or months for that section, cache static lookups) and say what changed in the section header. (3) Add `tools/balance.sh --section "<name prefix>"`: runs only the matching section(s) and replaces just those in docs/balance_baseline.txt (others kept byte for byte); `--check` accepts it too. Document both in the script's header comment. (4) QA-046 Follow-up: running tools/test.sh and tools/balance.sh at the same time fails ("Could not write save autosave"); make the sims never write user://saves (disable autosave for sim sessions through a SaveManager flag, or give sims their own user dir) so both can run together. Acceptance: full `tools/balance.sh` under ~10 min here and every section under ~3 min; paste the per-section times in the commit; refresh the baseline. |
| QA-048 | qa | todo spec | A curious player who tries everything (QA-041 Follow-up). *Spec:* [docs/specs/QA-048.md](specs/QA-048.md). |
| QA-045 | qa | todo spec | Why is the first Foundation year so gentle? (QA-039 Follow-up: 107/120 runs spent no artifact life, median win share 100%, 0 injuries; DESIGN.md's QA-007 target is ~60-85% against a foe of your own realm and stage.) *Spec:* extend the QA-039 sim (tests/sim/simulate_foundation_year.gd or wherever it landed) with `--threats=slip|fight` (default slip, today's behaviour). For seeds 1-10 and both policies print per region: encounters met, fights fought, fights evaded via sensed threats, the median stage reached by month 3/6/12, and a histogram of the rated odds (Combat sim helper the combat baseline uses) of every fight actually fought (<50%, 50-75%, 75-95%, >95%). Answer in the commit body, with numbers: (a) are fights rare or just easy? (b) do C-031's stage gates leave only foes the player has already outgrown by the time they appear? (c) does the player outgrow the region within months (stage climbs fast)? List under Follow-ups the 3 data changes you would make (enemy ids or gate stages), without making them. Add the `fight` run as its own tools/balance.sh section and refresh only that section. Keep it under ~60 s. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates). *Spec:* reuse QA-039's sim with the realm as an argument (`--realm=core_formation`): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each region whose encounters include Core Formation fights (Myriad Peaks Ridge and any other; list them from data), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent (tribulation not included) and medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. If QA-045 has landed, include its `--threats` switch and odds histogram. |
| QA-044 | qa | todo | Do pointers and spars matter? (after QA-048, which teaches the curious policy pointers and spars): in tests/sim/first_hour.gd add a curious-policy switch that never uses pointers/spars, run 12 months for seeds 1-10 with and without, and print median technique levels and fights won at months 6 and 12. Under Follow-ups say whether pointers/spars meaningfully speed the first year (or are too strong: more than ~2 extra technique levels by month 12), with numbers. No data changes. |
| QA-035 | qa | todo | Economy sim: sect months every month (ECON-001b Follow-up). tests/sim/simulate_economy.gd only runs sect months every 12 months, so mission cooldowns never bind and sect income can't be compared fairly with profession work (still 1.5-1.9x for Doctor/Beast Tamer). Make the sim run the sect policy month by month (respecting `Sects.mission_cooldown_left`, duty, stipends) for a sect life, keep the same seeds, print per-profession "sect stones / work stones" ratios, update tools/balance.sh's baseline. If any profession's ratio is still > 1.5x, list the top 3 mission ids by net stones under Follow-ups (the planner files the content retune); don't retune data in this task. Also paste the economy section before/after ENC-003 (fading encounters; its commit skipped that comparison) and say whether income moved. Keep runtime under ~60 s. |
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
