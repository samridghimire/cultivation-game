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
Next (planner 2026-10-09 18:10): 13 tasks landed (DANGER-001, LETTER-003, NEWS-003, WU-095/099/101/104/105, C-058/059/060,
QA-053b, QA-056). Claimed now: FEST-003, SHOP-001, C-064, QA-048. Reviewer (to 3108c18) filed no P0; its notes become
LETTER-003b (asks are answered in person only, expiry under the family topic), GIFT-002 (taste-hint threshold to data, -1
flags), FEST-004 (festival goods only at fitting stalls), WU-106 (likes on the sheet), WU-107 (lost-fight line fades),
WU-108 (gift list remembers a hint) and QA-058 (letter-request saves). New theme **the world talks back**: merchant gossip
from data (RUMOR-001 + C-067, C-059's rumor), deeds that enrich a region's qi (QI-001 + C-068 + WU-109, C-060's seed),
more letters that ask (C-066), letters marked on the world map (WU-110), and a log-noise sim (QA-059) so the new chatter
stays readable. C-063's 14:27 claim never landed; it is free again once the claim expires.
| id | role | status | task |
|---|---|---|---|
| LETTER-003b | systems | todo spec | Letter-request fixes (reviewer 9th run, note 3). *Spec:* (1) src/autoload/game_state.gd ~2879, the month tick's "<Name> no longer waits for your answer." post: it goes out under whatever `EventBus.topic` the tick last set; post it under the `family` topic (set `EventBus.topic = "family"` just before the loop, as `chat`/`give_gift` do at ~1150, and leave the topic the way the following code expects: the next block sets `EventBus.topic = "world"` itself at ~2884, check nothing between relies on the old topic). (2) `GameState.check_letter_request` (~2693): after the alive check, if `Npcs.region_of(npc, data) != current_region` return "They are in %s; give it to them in person." with the region's name (WU-099's NPC entry only shows when you stand next to them, but the action must not work from afar). (3) tests/unit/test_letters.gd (or wherever LETTER-003's GameState test lives): answering from another region is refused with that reason and the items stay; answering in the asker's region still works; if a test helper records posted topics (grep tests for `topic`), assert the expiry line is `family`. |
| SHOP-001 | systems | todo | A friend's price (C-053 Follow-up: the merchant letter pays 5 stones because there is no discount). (1) data/family.json letter kinds may carry `"deal": {"mult": 0.85-0.99, "days": int >= 1}`; validate in `Letters.validate`; document in the letters `_doc` (or the file's `_doc`). (2) CharacterData `var shop_deals: Dictionary = {}` (region_id -> {"mult": float, "until": int day}), to_dict/from_dict default {}. (3) `Letters.monthly`: a kind with `deal` sets `c.shop_deals[<writer's region>] = {mult, until: today + days}` (pass `today` in; keep the old signature working with a default) and appends "a friend's price in <region> for N days" to notes. (4) `static func deal_multiplier(c: CharacterData, region_id: String, today: int) -> float` (1.0 when none or expired); GameState's buy-side multiplier (`game_state.gd` ~2116, the one that already multiplies `Renown.buy_multiplier`) multiplies it in. Expired deals are dropped on the month tick. (5) data: `merchant_offer` loses its 5 stones and gets `"deal": {"mult": 0.9, "days": 30}`. Tests: deal set by the letter, applies only in that region and only until `until`, buy price drops ~10%, save round-trip, validation errors for mult outside 0.5..1. |
| RUMOR-001 | systems | todo spec | Merchant gossip from data (C-059 Follow-up: content cannot add rumors; `hear_rumors` only builds lines in code). *Spec:* [docs/specs/RUMOR-001.md](specs/RUMOR-001.md). Unblocks C-067. |
| QI-001 | systems | todo spec | Deeds that raise a region's qi density (C-060 Follow-up: the planted guardian seed should leave Azure Peak a little richer in qi). *Spec:* [docs/specs/QI-001.md](specs/QI-001.md). Unblocks C-068 and WU-109. |
| LETTER-002 | systems | todo | Family who are away write home (C-053 Follow-up: `Letters.writer` skips spouses, children and parents). (1) data/family.json letters: kinds may carry `"from": "family"` (default "friend"); a `family_chance` (0..1, e.g. 0.3) next to `monthly_chance`. Add 3 family kinds: a spouse in a sect ("{name} writes from {region}: the sect's rules are strict, but they think of you at every lamp-lighting." qi 20), a child in a sect asking for guidance (alignment +1, child favor via the existing child favor field if one exists, else nothing), a parent's worried letter (heal nothing; a few herbs). (2) `Letters.family_writer(c, npcs, data) -> String`: a living spouse or child aged >= 12 whose `sect` is non-empty (they live away), lowest id first. (3) `Letters.monthly`: first roll family (`family_chance`, family kinds only); if nobody writes, roll the friend letter as today (friend kinds only). Old data without `from` is all friend letters. Tests: family kinds never come from friends and vice versa; a child at home never writes; validation of `from` and `family_chance`. |
| GIFT-002 | systems | todo | Gift-taste tidy-up (reviewer 8th run, notes 3-4). (1) data/family.json: move the hard-coded favor 20 of the taste hint (game_state.gd ~1184 `int(npc_favor[npc_id]) >= 20`) to a gifts/taste rule, e.g. `"taste_hint_favor": 20` next to the other gift numbers (find where `gift_taste` reads its multipliers), document it in the `_doc`, validate int 0..100, read it in GameState. (2) Taste flags are ints (1 liked, -1 disliked) and -1 is truthy: grep every reader of `taste_` world flags (`flags.get("taste_...")`, `world_flags.has("taste_`) in src and make sure none treats a dislike as "known liked" by truthiness alone (compare `int(...) > 0`). Fix any that do. (3) Add the missing GameState test for the chat hint: chatting with a named NPC that has `likes` at favor >= the threshold posts `Family.taste_hint` once and sets `taste_told_<npc>`; a second chat does not repeat it; below the threshold nothing. |
| FEST-004 | systems | todo | Festival goods only at the right stalls (reviewer 9th run, note 1: FEST-002's goods appear at every merchant in the region, the Blood Lotus Apothecary and smithies too, and ignore `max_price`). (1) data/world_events.json festivals may carry `"stall_tags": [item tags]` (default: `["herb", "food", "general"]`, check which tags the village/market general merchants actually use in data/regions.json and pick the default from those); document in the `_doc`, validate as a non-empty string list. (2) Where FEST-002 adds `festival_stock()` to a merchant's stock (grep `festival_stock` in src/ui/shop_screen.gd / src/world/interactables/merchant.gd), add the festival rows only when the merchant's `stock_tags` (or `buy_tags`) intersect the festival's `stall_tags`, or the merchant has no `stock_tags` (sells everything). Keep ignoring `max_price` for festival goods (they are cheap) but say so in a code comment. Make the check a static function in core (`WorldEvents.sold_by(data, event_id, stock_tags: Array) -> bool`). Tests: an herb stall gets the festival goods, a smithy (`stock_tags` ["weapon", ...]) does not, a merchant without stock_tags does. |
| WU-103 | world-ui | todo spec | Focus audit of the newest menus (since WU-079). *Spec:* extend tests/unit/test_focus_audit.gd (read how it opens screens and asserts a focused Control) to cover: the bounty board menu (with an active hunt and with offers), the NPC gift list with a liked and a disliked item (WU-089 colors), the mission board with a lost-mission line (WU-088), the respawn screen with the odds line (WU-096), the journal Letters section with 3 letters, and a shop during a festival (festival rows). Each must have keyboard/gamepad focus on open and after closing a sub-list. Fix any screen that loses focus (smallest change, `grab_focus`). Commit body: what was covered and what was fixed. |
| WU-106 | world-ui | todo spec | "(likes N known)" on the sheet's People list (WU-105 Follow-up; WU-101 landed). *Spec:* (1) Move the flag scan out of `NPC.known_tastes_text` (src/world/interactables/npc.gd ~436) into core: `static func known_tastes(flags: Dictionary, data: GameData, npc_id: String) -> Dictionary` in src/core/systems/family.gd returning item_id -> taste (1/-1), keeping the exact prefix logic (skip `taste_told_*`, the rest must be an item id in `data.items` so "li" never matches "li_wei"'s flags). `known_tastes_text` calls it (same output; its tests must still pass). (2) src/ui/character_sheet.gd `people_lines` (~292) gets a trailing `flags: Dictionary = {}` parameter and appends " (likes N known)" when N = count of liked (taste > 0) entries is >= 1; the caller passes `GameState.world_flags`. Tests: test for `Family.known_tastes` (a like, a dislike, the li/li_wei case, `taste_told_` skipped); people_lines with 2 known likes shows "(likes 2 known)", with only a dislike shows nothing. |
| WU-107 | world-ui | todo spec | The mission board's "You lost this fight" line fades (reviewer 8th run, note 2: it never expires and uses the rating colour). *Spec:* (1) src/ui/mission_board.gd `loss_text` (~408): return "" once the loss is more than 60 days old (`const LOSS_MEMORY_DAYS := 60`; a cleared mission also clears it if `Sects` erases `mission_losses` on a win, check `Sects.complete`/`take_mission`; if a later win does not erase the entry, erase it there in core and add a test in test_sects). (2) Where the line is added to the details text, colour it with the danger colour of the mission's current rating (`UIStyle.DANGER_COLORS[Sects.mission_danger(...)]`, Risky amber etc.) instead of the rating's own colour, so a now-Weak fight you once lost does not look alarming. Tests (test_mission_board): loss 10 days ago -> text; 61 days ago -> ""; never lost -> ""; a won retry clears it. |
| WU-110 | world-ui | todo | Letters waiting on the world map (LETTER-003 + WU-099 landed). In src/ui/world_map_screen.gd `region_marks` (~200) add a `letter` mark per open letter request whose asker lives in that region: "Letter: <Name> asked for <count> <item> (N days left)" (reuse `Letters.request_lines` data: add `static func Letters.requests_in_region(c, data, npcs, region_id, today) -> Array[Dictionary]` in core rather than parsing text), with its own dot colour in the mark-kind -> colour table (~19). Tests: a request in Qingshi shows on Qingshi's marks and not elsewhere; an expired one shows nowhere. |
| WU-108 | world-ui | todo | The gift list remembers a hint (reviewer 8th run, note 3: a taste told in chat at favor 20 still shows as neutral in the gift menu). In src/world/interactables/npc.gd's gift list (~200), when the `taste_told_<npc>` world flag is set and the item has no learned taste flag but matches the NPC's first `likes` entry (equal item id, or the item's tags contain it: add `static func Family.matches_first_like(data, npc_id, item_id) -> bool` in core), suffix " (they are fond of these)" and use a dimmer accent colour (UIStyle has muted/secondary colours; grep). Sort these after learned likes and before neutral items. Tests: the suffix appears only with the told flag, never for a learned dislike, and `matches_first_like` handles tag and item-id likes. |
| WU-100 | world-ui | todo | Join the festival (after FEST-003). While a festival with an `activity` runs in the current region, the merchant's festival stall (WU-097 draws an awning beside merchants; find where) or the merchant menu gets an entry "<activity name> (festival)" with the activity text as description, disabled with `GameState.check_festival_activity` as the reason, action `GameState.festival_activity`. Play the festival chime WU-072 uses on success. Tests: entry shown only during the festival, disabled after taking part. |
| WU-102 | world-ui | todo | The friend's price in the shop (after SHOP-001). The shop header line that shows the renown discount (WU-084) also says "A friend's price: -N% (M days left)" when `Letters.deal_multiplier` < 1 in the current region; the world map region tooltip gets the same line. Tests: header text with and without a deal. |
| WU-109 | world-ui | todo | Show why a region's qi is richer (after QI-001). The world map region line (`world_map_screen.gd` ~352, "Qi density xN") appends " (the valley guardian's seed)" from `Exploration.qi_flag_reasons(data, region, GameState.world_flags)` (comma-joined); the HUD's region qi line (hud.gd ~448/848) does the same when non-empty. When the flag is first set, nothing extra (the encounter text tells it). Tests: a static helper building the map line with and without an active reason. |
| C-063 | content | todo spec | The Mist Wolf mission waits until it is a fair fight (QA-052 Follow-up 1: every early curious-player death was "Cull the Mist Wolves", taken at its gate (Qi Refining 1st Layer, `min_stage` 1) at 18-35% odds). *Spec:* do **not** change mist_wolf's stats or `realm_training` (the first-fights question C-009 is the owner's). (1) Run `tools/godot.sh --headless --path . -s res://tests/sim/simulate_combat.gd` (read its header for args) to get the typical player's win rate vs mist_wolf at each Qi Refining stage 1-6. (2) In data/sect_missions.json set `cull_mist_wolves.min_stage` to the lowest stage where that rate is >= 55% (QA-052 expects about 3). (3) If any other `kind: hunt`/`guard` mission with `min_rank` 0 sits below 45% at its own gate, raise its `min_stage` the same way (list them all in the commit body with before/after rates). (4) A newcomer must still have a sect mission they can take at Qi Refining 1st Layer: check `deliver`/non-fight missions exist at min_rank 0 for each sect (there are), and if a sect has none, say so in Follow-ups. (5) Re-run `tools/balance.sh` and commit the refreshed baseline with the change. Tests: test_data_references/test_sects keep passing; add a data test in tests/unit/test_sects.gd that every min_rank 0 fight mission rates at least "Risky" (not "Dangerous"/"Deadly") for a typical player at its gate, if `Sects.mission_danger` makes that easy to call; otherwise state why not in the commit. |
| C-066 | content | todo spec | More letters that ask for something (LETTER-003 built `request`; only `pill_request` uses it). *Spec:* add 4 kinds to data/family.json `letters.kinds`, each with a `request` (see the file's `_doc` for the fields: item, count, days, favor, effects) and true to the genre: (a) a herb for a sick parent (a common herb the Qingshi herb seller stocks, count 3, days 60, favor 8, effects alignment +3); (b) an ore for a friend's first sword (an ore sold in the region, count 2, days 90, favor 10); (c) a talisman for a long journey (a buyable or easily crafted talisman, count 1, days 45, favor 12, `min_favor` 30 if kinds support it); (d) at `min_favor` 50, a spirit beast material for a sect trial (a material dropped by a Qi Refining beast, count 2, days 120, favor 15, effects qi 100). Weights like `pill_request`'s. Every requested item must be obtainable before Foundation (test_obtainability covers items; also add a data test in test_letters.gd: every `request.item` is an items.json id and is sold by some merchant or dropped by an enemy at or below Foundation). Texts: one or two sentences in the letter voice C-053 used ({name} placeholder if the kind texts use it). |
| C-061 | content | todo | Festival stalls stocked (after FEST-002). 2-3 festival goods per festival in data/items.json + `shop_items` in data/world_events.json: Lantern Festival (paper lantern, sweet rice balls: a little qi), Qingming (willow branch: a minor ward buff 3 days; ancestor incense: alignment +3), Mid-Autumn (moon cake, osmanthus wine: a small favor-gift item). Cheap (2-15 stones), untagged so ordinary merchants never sell them, effects small. Tests: validators; every festival has at least 2 shop items; obtainability. |
| C-062 | content | todo | Requests for the renowned (after RENOWN-002). One `min_renown` encounter per region besides the two RENOWN-002 wrote (Fallen Star Market, Azure Peak, Withered Bone Marsh, Myriad Peaks Ridge), once-only, fitting the region (a guild master asks you to escort a shipment; an elder of a minor sect asks you to judge a duel; marsh villagers beg you to end a corpse refiner; a ridge beast clan asks for a truce), gated at the region's realm, rewards about a week of the region's gather income plus favor/renown; any fight 45-75% at its gate (paste simulate_combat.gd rows). Tests: data test that every region has a min_renown encounter. |
| C-064 | content | todo | Bounty follow-ups (C-052 Follow-ups). (1) Qingshi posts only one bounty: add a second, a fair Qi Refining 1st-3rd Layer foe that can be met in Qingshi (a new `village`-tagged, lethal: false enemy is fine, e.g. a hen-stealing fox spirit or a drunk bully disciple; add it to a Qingshi encounter too so `Bounties.hunt_roll` can find its trail), win rate 60-80% at its gate in simulate_combat. (2) The sword madman and iron-horn rhino bounties sit at the 45% floor: raise their `min_stage` (or `min_realm`) until the typical player wins >= 55%. Rewards stay ~1.5x a week of the region's gather income. Commit body: win rates before/after. |
| C-065 | content | todo | Festival activities (after FEST-003). Give qingming_festival and mid_autumn_festival an `activity` like FEST-003's Lantern one: Qingming "Sweep the ancestors' graves" (alignment +3, a little qi; bonus at Spirit >= 12: a whisper from the departed, small `breakthrough_bonus` 0.01), Mid-Autumn "Moon-viewing on the market roof" (qi; bonus at Charisma >= 12: a stranger's moon cake and favor... use items, e.g. 1 moon_cake). Small rewards, no stones beyond 5. Tests: data test that every festival has an activity. |
| C-067 | content | todo | Gossip worth hearing (after RUMOR-001). Add 12 rumors to data/rumors.json: at least one per region (`region` set), 3 realm-gated ones that hint at Foundation/Core content (a secret realm's next opening, an inheritance ground, a tribulation warning), 2 that hint at a hidden encounter behind `requires_flag`/`blocked_by_flag` (e.g. the valley guardian after `found_hidden_valley`, hidden once `met_valley_guardian`). One sentence each, a merchant's voice, never naming exact numbers. Tests: validator; a data test that every region has at least one rumor. |
| C-068 | content | todo | The guardian's seed takes root (after QI-001). The Misty Forest valley guardian's "Plant it on the Azure Peak cliffs" choice (data/encounters.json `misty_forest_valley_guardian`) sets `planted_guardian_seed` too: `set_flag` holds one flag, so either use a second effect key if Effects supports a list (check effects.gd ~122; do not change code) or keep `met_valley_guardian` on both choices and add `planted_guardian_seed` via whichever mechanism QI-001's tests used. Azure Peak in data/regions.json gets `"qi_flags": [{"flag": "planted_guardian_seed", "bonus": 0.1, "text": "the valley guardian's seed"}]` (if QI-001 did not add it already). Change the choice text to mention the cliffs' qi growing richer. Tests: a session test that choosing plant raises `region_qi_density()` in Azure Peak by 10%; swallowing does not. If `set_flag` cannot carry two flags without a code change, stop and say so in Follow-ups (the planner files a systems task). |

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
| QA-058 | qa | todo spec | Save checks for letter requests and friend's prices (reviewer 9th run, note 3: QA-056 predates LETTER-003). *Spec:* extend tests/unit/test_renown_saves.gd (QA-056's file): (1) a session with two open letter requests (one about to expire) -> `to_save_dict` -> fresh `from_save_dict`: both requests survive with npc_id/item/count/until/favor/effects; advancing past the first's `until` expires only it; `answer_letter_request` still works after load. (2) If SHOP-001 has landed (`CharacterData.shop_deals` exists), a deal survives the round trip and still prices the shop in its region only; if not, skip that part and say so. (3) Every fixture in tests/fixtures/saves/ loads with `letter_requests == []` and `Letters.request_lines` returns []. Fix any bug found (smallest change, with a test); otherwise "no bugs found" in the commit body. |
| QA-045 | qa | todo spec | Why is the first Foundation year so gentle? (QA-039 Follow-up: 107/120 runs spent no artifact life, median win share 100%, 0 injuries; DESIGN.md's QA-007 target is ~60-85% against a foe of your own realm and stage.) *Spec:* extend the QA-039 sim (tests/sim/simulate_foundation_year.gd or wherever it landed) with `--threats=slip|fight` (default slip, today's behaviour). For seeds 1-10 and both policies print per region: encounters met, fights fought, fights evaded via sensed threats, the median stage reached by month 3/6/12, and a histogram of the rated odds (Combat sim helper the combat baseline uses) of every fight actually fought (<50%, 50-75%, 75-95%, >95%). Answer in the commit body, with numbers: (a) are fights rare or just easy? (b) do C-031's stage gates leave only foes the player has already outgrown by the time they appear? (c) does the player outgrow the region within months (stage climbs fast)? List under Follow-ups the 3 data changes you would make (enemy ids or gate stages), without making them. Add the `fight` run as its own tools/balance.sh section and refresh only that section. Keep it under ~60 s. |
| QA-059 | qa | todo spec | Message log noise in the first year (the "people write, ask and celebrate" theme added letters, greetings, festival lines and requests). *Spec:* add tests/sim/log_noise.gd (headless, like tests/sim/first_hour.gd; reuse its curious policy): for seeds 1-5, 12 months of play, record every `EventBus.post` (connect to the signal EventBus.post emits; grep `message_posted`) with its topic and month. Print per topic posts/month, and the 10 most repeated line templates (strip digits and names: replace NPC names from `GameState.npcs` with <name>, digits with N). Add it as a tools/balance.sh section. In the commit body answer with numbers: which lines repeat more than 4 times a month on average, and is any topic over 60 posts/month? Under Follow-ups list up to 3 lines you would merge, throttle or move to a quieter topic (no code change here beyond the sim). Keep runtime under ~60 s. |
| QA-042 | qa | todo spec | A "first Core Formation year" sim, like QA-039 one realm up (verifies C-031's Core gates). *Spec:* reuse QA-039's sim with the realm as an argument (`--realm=core_formation`): typical player at Core Formation Early with qi 0, rogue and sect variants, start in each region whose encounters include Core Formation fights (Myriad Peaks Ridge and any other; list them from data), 12 months of weekly explore + meditation + one mission a month, threats answered "slip away". Print per seed fights won/lost/evaded, injuries, lives spent (tribulation not included) and medians. Add to tools/balance.sh; loose guard: no artifact life spent in >= 8/10 seeds. If QA-045 has landed, include its `--threats` switch and odds histogram. |
| QA-048 | qa | todo spec | A curious player who tries everything (QA-041 Follow-up). *Spec:* [docs/specs/QA-048.md](specs/QA-048.md). |
| QA-035 | qa | todo | Economy sim: sect months every month (ECON-001b Follow-up). tests/sim/simulate_economy.gd only runs sect months every 12 months, so mission cooldowns never bind and sect income can't be compared fairly with profession work (still 1.5-1.9x for Doctor/Beast Tamer). Make the sim run the sect policy month by month (respecting `Sects.mission_cooldown_left`, duty, stipends) for a sect life, keep the same seeds, print per-profession "sect stones / work stones" ratios, update tools/balance.sh's baseline. If any profession's ratio is still > 1.5x, list the top 3 mission ids by net stones under Follow-ups (the planner files the content retune); don't retune data in this task. Also paste the economy section before/after ENC-003 (fading encounters; its commit skipped that comparison) and say whether income moved. Keep runtime under ~60 s. |
| QA-057 | qa | todo | Curious sim after C-063 (after C-063 lands). Re-run tests/sim/simulate_curious_years.gd for seeds 1-10 and compare with QA-054's numbers (deaths 20, early-ending seeds 0): deaths, the death log's top 3 killers, and months to the first sect mission. If the Mist Wolf is no longer the top killer, name the new one with its rated odds at the fatal take. Refresh that tools/balance.sh section. Follow-ups: the data change you would make for the new top killer (no data change here). |
| QA-044 | qa | todo | Do pointers and spars matter? (after QA-048, which teaches the curious policy pointers and spars): in tests/sim/first_hour.gd add a curious-policy switch that never uses pointers/spars, run 12 months for seeds 1-10 with and without, and print median technique levels and fights won at months 6 and 12. Under Follow-ups say whether pointers/spars meaningfully speed the first year (or are too strong: more than ~2 extra technique levels by month 12), with numbers. No data changes. |

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
