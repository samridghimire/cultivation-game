# Handoff notes

Short-lived context for the next session. Update or trim it when you finish a session; durable rules belong in CLAUDE.md.

## State on 2026-11-14 (planner, 00:10 UTC)
- 8 tasks landed (GFX-135, C-362, SPOT-001, GFX-140, GFX-136, LOG-004, GFX-137, SHOP-004). Review covered up to cede3c0
  (SPOT-001 look-line fix inline, nothing filed). Live claims: C-361, GFX-139, GUIDE-238.
- Planner shots (1280x720; default first hour, `--season=Winter --region=qingshi_village,withered_bone_marsh,misty_forest`):
  fields, marsh pools and villager spacing good. Found: winter roads = one row of centre dashes (GFX-124 rule) -> GFX-141 (spec
  file, also ragged verges and the marsh boardwalk); jetty ponds still ellipses, frozen ones with a dotted ring, PixelPlace
  plates, rectangular Reed Hall platform -> GFX-142 (spec file); spare field looks like a crate -> GFX-143; 10-line log for a
  99% boar fight -> LOG-006 then WU-536; Hunter Ma on the arrival crossroads -> SPOT-002.
- Follow-ups -> SHOP-005, LOG-005, C-363; QA-218 runs the balance check C-362 and LOG-004 skipped (style day, log lines/month).
- **Systems has 4 ready (SHOP-005, LOG-005, LOG-006, SPOT-002)**; ART-012 waits on QA-212. The big levers still wait on the
  owner (F-005d pacing, C-009 first fights, GFX-002 art pack).
- Next planner: view GFX-139/141/142 shots when they land; refill systems from QA-217/QA-218 results.

## State on 2026-11-13 (planner, 18:10 UTC)
- 10 tasks landed (GFX-132, WU-533, SEASON-022, LOG-003, GFX-133, WU-534, SHOP-002, C-343, SHOP-003, GFX-134). Review covered
  up to 3cc0507 (fixes inline, nothing filed). Live claim: QA-199.
- Planner shots (1280x720; default first hour, `--season=Winter --region=misty_forest,withered_bone_marsh`): shop tags fixed,
  Qingshi ground natural. Found: ellipse ponds and a straight stream -> GFX-135 (spec file); marsh reads as a field -> GFX-136;
  villagers clump at the marsh entrance -> SPOT-001; flat grid fields -> GFX-140; ellipse "plates" under places -> GFX-137;
  even tree sprinkle, no winter mist -> GFX-139; GFX-132/133/134 Follow-ups -> GFX-138.
- No first fighting style in 12 months in the first-hour sim -> C-362 (planner default: Hunter Ma teaches Iron Fist at favor 15)
  then GUIDE-238. LOG-004 (spec file) for the 9.5 lines/month target, SHOP-004 for SHOP-002/003 Follow-ups, QA-216 for the
  settings leak, QA-217 for the unexplained sect-mission income drop, C-361 for thin Core wilds.
- **Systems is thin: 3 ready (SPOT-001, LOG-004, SHOP-004)**; GUIDE-238 waits on C-362, ART-012 on QA-212.
- Next planner: view GFX-135/136 and SPOT-001 shots when they land; refill systems from QA-215/QA-217 results.

## State on 2026-11-13 (planner, 06:10 UTC)
- 11 tasks landed (WU-527, GFX-127, WU-529, GFX-128, WU-530, SEASON-019, SEASON-020, ART-014, C-356, C-352, QA-214). Review
  covered up to ef49021 (fixes inline, nothing filed). Live claims: GFX-129, QA-211 (a `wip` commit on its branch, not landed).
- Planner shots (1280x720; default first hour, marsh/Azure Peak/ridge/market arrivals, `screenshot_screens.gd`): map, artifact and
  log screens fine. Found: railway-track N-S road, bare crossroads, even tree sprinkle -> GFX-131 (spec file); flat single-colour
  ground everywhere -> GFX-130 (spec file); HUD log starts mid-message -> WU-531; shop opens on snacks and a keepsake -> WU-532,
  C-358 (also the "Steady hands. Steady hands" almanac echo); GFX-127 Follow-ups -> GFX-132.
- Play: year 1's boar hunt points to Misty Forest while a boar is fought in Qingshi's outskirts, and explore wins never count
  -> SEASON-021. QA-215 teaches the curious sim the season tasks (QA-214 found it never tries them).
- **Systems is thin: 1 ready (SEASON-021)**; SHOP-001 waits on WU-532, ART-012 on QA-212, LOG-002 on QA-211. The big levers
  still wait on the owner (F-005d pacing, C-009 first fights, GFX-002 art pack).
- Next planner: view GFX-129/130/131 shots when they land; refill systems from QA-215's open-task list and QA-211's templates.

## State on 2026-11-12 (planner, 00:10 UTC)
- 7 tasks landed (GUIDE-236, WU-507, WU-513, WU-514, C-349, FISH-010, C-350). No review since 7818199 (the reviewer's
  next run covers 11c2e23..). Live claims: C-350 (landed; claim awaits cleanup), CAL-011, WU-515.
- Planner shots (1280x720; first hour, six `--region=` arrivals, `--journal`): arrival banner and fishing log fixed.
  Found: "Tomorrow is fish rise to the bait." + the market said three times in Today -> TODAY-004 (also omen text arrays,
  then C-351); "Witherec Bone Marsh" still clipped -> WU-516; marsh sect hall on a dark slab -> GFX-121; Today tab a long
  scrolling list -> WU-517; Mugwort first on every path, even the ridge -> FORAGE-006 + C-352; market wages tiny -> C-353.
  QA-208 (3) now also covers C-350's skipped balance check.
- **Systems has 5 ready (CAL-011 claimed, TODAY-004, FOLK-032, CAL-012, FORAGE-006).** The big levers still wait on the
  owner (F-005d pacing: QR1 day 14 -> QR3 day 218 in the curious sim; C-009 first fights; GFX-002 art pack).
- Next planner: view WU-515, GFX-119/120/121 and WU-516 shots when they land; refill systems from what TODAY-004 and
  FORAGE-006 surface.

## State on 2026-11-10 (planner, 12:10 UTC)
- 9 tasks landed (GFX-113, GFX-114, GUIDE-233, C-347, SEASON-016, WU-508 parts 1-2, GUIDE-234, WU-509, C-346). Review
  eeed8bc..ce5bcc1 fixed wintry places on a season change inline; its notes -> GUIDE-235. Live claims: C-348, GFX-115, WU-507.
- Planner shots (1280x720; Azure Peak, marsh, Myriad Peaks in Winter; market, Misty Forest in Summer; default first hour):
  streams stay blue in winter, jetties run onto land, Myriad Peaks flat -> GFX-116; names on names, stats panel at ~35%
  alpha in Misty Forest -> WU-511; signpost crowd -> FOLK-032 (core, not the label task); figures float, player hard to
  find -> GFX-117; no mist in Misty Forest, bare trees in summer -> GFX-118. Earning line "for Headman Zhou (Headman
  Zhou)" -> GUIDE-235. hud_after_sect.png's log shows an empty first fishing trip despite FISH-008 -> FISH-009 (not yet
  diagnosed: may be the harness).
- Systems was empty: new SECT-006 (sect-hall chores, spec file) and CAL-010 (daily almanac, spec file), both planner
  defaults in DESIGN.md; GUIDE-236, FOLK-032. Content: C-350 errands in Misty Forest/market; C-349/WU-513 wait on CAL-010.
- Next planner: view GFX-115/116/117 and WU-511 shots when they land; check CAL-010's balance drift; GFX-002 still waits on
  the owner.

## State on 2026-11-10 (planner, 06:10 UTC)
- 15 tasks landed (GUIDE-230, GFX-111, WU-505, WU-506, GFX-112, WU-502, FISH-008, CAL-009, GUIDE-228, FOLK-031, GUIDE-232,
  C-204, C-340, C-341, QA-208 part 4). Review 2430218..eeed8bc fixed a doubled family birthday inline; its notes -> GUIDE-233
  (beginner's luck after "got away"), WU-509 (empty Today card), C-347 (no wage in Qingshi). Live claim: GFX-113.
- Planner shots (first hour `--terraces=3`; Qingshi, marsh, Misty Forest `--season=Winter`; 1280x720): rock, roads and the
  encounter strip read well. Winter: grey shadow discs under snowy pines, green woods and herb patch, jetties beside frozen
  ponds -> GFX-114 (spec file). NPC labels over the player, [E] chip over place labels, marsh signpost crowd -> WU-508.
  Arrival card covers the village top -> WU-510. Flat water -> GFX-115.
- Curious sim (1 seed, 3 months): 31 stones at day 143, Mortal until day 44 -> C-347 repeatable errands (planner default in
  DESIGN.md) and GUIDE-233 one-time jobs on the Earning card (spec file). GUIDE-234: sect missions as a disciple's earning.
- **Systems is thin (3 ready: GUIDE-233, SEASON-016, GUIDE-234).** Nearly every first-hour idea exists already (forecast, fish
  log, chores, birthdays, projects). The big levers wait on the owner: pacing (F-005d), first fights (C-009), rogue speed
  (QA-158). Next planner: look for systems work in what the content and GFX tasks surface, not another village layer; view
  GFX-113/114 and WU-508 shots when they land; GFX-002 still waits on the owner.

## State on 2026-11-10 (planner, 00:10 UTC)
- 13 tasks landed (GFX-109, WU-500, C-334, C-335, GUIDE-227, FOLK-030, GFX-110, QA-042, WU-501, GUIDE-229, SEASON-015,
  WU-504, C-339). Review 99c86db..2430218 fixed two slips inline; its QA-042 note -> C-343. Live claims: C-204, C-340,
  CAL-009, WU-502. The 12:10 planner run on 11-09 never happened (no commit).
- Planner shots at 1280x720 (six regions `--edge`, default first hour, screens): **Earnings recommends atrocities** (the
  journal's top "Earning here" row is "Poison the village well", 120/day; sell_street_child and rob_traveller qualify too,
  and GUIDE-229's empty-purse hint reads the same rows) -> GUIDE-230 at the top of P0. Peak rims look like town walls and
  brown boards -> GFX-111; great-beast pointer over the stats panel, ridge labels overlap -> WU-505; encounter strip roofs
  -> WU-506; flat roads -> GFX-112; Azure Peak flat -> GFX-113; stats panel lines clip -> WU-507.
- screenshot_screens.gd's combat_report fixture never lowers the Stone Ape's hp (synthetic log, not a game bug).
- Next planner: view GFX-111/WU-505/WU-506 shots when they land; check C-343's histogram; GFX-002 still waits on the owner.

## State on 2026-11-09 (planner, 06:10 UTC)
- 12 tasks landed (C-310, SEASON-013, WU-496, QA-206, GUIDE-224, SEASON-014, FOLK-029, WU-497, C-313, C-331, WU-498,
  QA-203 part 1 -> remainder QA-207). Review c85ddec..023bcd2 fixed the kickoff task lines inline; its notes -> RV-019
  (jetty lantern everywhere, creation at 720) and C-338/QA-199. Live claims: GFX-105, WU-495.
- **screenshot_screens.gd `--first-hour`/`--title`/`--creation` are broken on main** since WU-496 (`hud` is null at
  ~4312). Local workaround (do not commit): `if hud != null: hud.call("_update_modal")`. RV-019 fixes it.
- Planner shots: creation screen good but hints clip at 720; Qingshi jetty posts at stage 0 stand on grass; inventory icons
  all blobs -> GFX-106 (spec file); fight backdrops flat -> GFX-107; world map flat -> GFX-108; top-of-map dark band ->
  WU-499.
- Sims: first_hour `--curious --trace` (1 seed, 6 months) and quiet_stretches look healthy (curious median stretch 2 days);
  log_noise shows far-off festival "Tomorrow" reminders -> CAL-008. CAL-007 was already taken by an old commit.
- Systems has 4 ready tasks (FISH-007, CAL-008, GUIDE-225, GUIDE-226). Next planner: more systems from first-hour
  friction, not new village layers; view GFX-105/106/107 and RV-019 shots when they land; GFX-002 still waits on the owner.

## State on 2026-11-09 (planner, 00:10 UTC)
- 13 tasks landed (COOK-003, WU-491..494, GUIDE-223, C-329, C-332, C-333, ENC-014, GFX-104, FOLK-028, SEASON-012).
  Review 49b988c..c85ddec backfilled trail flags inline; its notes -> GUIDE-224 and WU-496. Live claims: C-310, SEASON-013.
- Planner shots: woods, crafting, family portraits, encounter figures good. `screenshot_screens.gd` opens screens without
  `_update_modal` (name card over map.png is a harness artifact, WU-496 checks the real path too). Title and creation
  screens are plain vector/text -> GFX-105, WU-497 (spec files). The screens fixture's children have random surnames
  (fixture only; core `Children` uses the father's surname).
- Systems is thin (GUIDE-224, SEASON-014, FOLK-029 ready). Next planner: if systems runs dry, look for first-hour friction in
  a `first_hour.gd --trace` run rather than adding more village-project/birthday layers; the SEASON/FOLK/birthday defaults
  are still waiting on the owner in DESIGN.md.

## State on 2026-11-08 (planner, 12:10 UTC)
- 9 tasks landed (WU-484, GUIDE-220, GUIDE-221, CRIT-002, WU-485, GFX-100, FOLK-026, WU-486, WU-487). Review
  877015a..b872ed1 fixed two slips inline, nothing filed. Live claims: GFX-101, WILD-021, C-327, C-313 (5h old, expiring).
- **ID collision found:** the open COOK-002 row shared its id with a landed 2026-10 commit `[COOK-002] Meals that carry
  you...`, so workers' `git log | grep [COOK-002]` said done and nobody took it. Renamed COOK-003; C-330 split (festival part
  ready now, dish part -> C-331). Planner: check new ids against `git log --format=%s` before using them.
- Screenshots render fine under xvfb in the cloud; workers kept writing "not rendered (no GPU)". Added a Screenshots
  section to CLAUDE.md. Planner shots this run: five regions + the default first-hour set (see BACKLOG header).
- Next planner: view GFX-101/102/103 and WU-488 shots when they land; GFX-002 (art pack) still waits on the owner.

## State on 2026-11-08 (planner, 00:10 UTC)
- 10 tasks landed (GFX-094, C-323, FOLK-022, GUIDE-218, COOK-001, C-324, GFX-095, WU-480, WU-481, C-325). Review
  d56a580..d259ccc fixed old saves losing cooked dishes inline; its notes -> GUIDE-219. Live claim: C-326.
- Planner shots (`--region=` five regions, `--festival`, `--book`): forage sprites, explore looks and People cards good.
  Secret-realm entrances are flat donuts -> GFX-098 (spec file); a villager on the marsh signpost and a name on a roof ->
  WU-483; HUD panels flat -> GFX-099; birthdays/untaught dishes invisible in the world -> WU-482. GFX-096/097 still queued.
- New systems: GUIDE-219 (reviewer notes), WILD-020 great-beast chains -> C-327 middle steps, FOLK-025 festival lines ->
  C-328. QA-204 (balance baseline) moved to the top of QA: C-324 could not explain its drift.
- Systems has 3 ready tasks; more ideas once these land: a third village project (if the owner keeps SEASON-008's default),
  a player's own birthday (needs a decision: today it falls on New Year's day for every character).
- Next planner: view GFX-096/097/098 and WU-482/483 shots when they land; GFX-002 (art pack) still waits on the owner.

## State on 2026-11-07 (planner, 18:10 UTC, 2nd run)
- The entry below labelled 18:10 was really the 12:10 run (its commit is dated 12:16).
- 12 tasks landed (GFX-091, WU-478, C-321, WU-477, FOLK-021, ENC-012, QA-205, GUIDE-217, GFX-092, GFX-093, WU-479, C-322).
  Review ac23991..d56a580 fixed a lost friend/lesson card inline; notes -> C-324 (tiger text) and COOK-001 (shorten_injury).
- Screenshots work on main again (QA-205). `--region=` runs skip the festival/book flags: use separate runs.
- Planner shots (all six regions, `--festival --friend-scene --book`): forage herbs are an 8x8 green checkerboard at 4x ->
  GFX-094; ten identical grey-dome explore places -> GFX-095 (spec file); People cards overflow -> WU-480; overlapping
  labels in Fallen Star, the marsh, Misty Forest and the festival -> WU-481; static fields -> GFX-096; thin festival decor and
  a grey band under the map -> GFX-097. Friend card, mist and pickup floats looked fine.
- New systems: COOK-001 (spec file), FOLK-022 (named friends had no birthday at all), GUIDE-218. Systems has only 3 ready
  tasks; candidates for more once these land: a Qi Refining great-beast step between the first beast and its Foundation
  return (Misty Forest, Azure Peak, the marsh), a third village project if the owner keeps SEASON-008's default.
- Next planner: view GFX-094/GFX-095/WU-480 shots when they land; GFX-002 (art pack) still waits on the owner.

## State on 2026-11-07 (planner, 18:10 UTC)
- 13 tasks landed (RV-018, WU-475, FOLK-019, C-311, C-319, FOLK-020, GFX-087, GFX-090, GUIDE-216, SEASON-010, WU-476,
  CRIT-001, C-320). Review aa54fa8..ac23991 merged RV-018's duplicate well into the Founder's Old Well inline.
- **Screenshots are broken on main** since GFX-087: tests/sim/screenshot_first_hour.gd names `Well`, whose script uses the
  GameState autoload, so the `-s` script fails to compile and the run exits 0 with no PNGs -> QA-205 (P0). Local workaround
  (do not commit): replace `Well.project_index(gs.data)` with `load("res://src/world/interactables/well.gd").project_index(gs.data)`.
  A fresh container also needs `tools/godot.sh --headless --path . --import` before the first shot.
- Planner shots (`--festival --friend-scene --well=3`, 1280x800): friend card portrait good; whole well (roof, ribbon) good.
  Festival: [E] chip at the top of the screen, a crowd figure on the player -> WU-478 (spec); square not festive -> GFX-093.
  Xiao Ling's rain scene on a clear day -> FOLK-021 (spec file).
- New: ENC-012 (injury effect, tag offerings) -> C-324, GUIDE-217 eggs in Today, GFX-092 pickup floats + gift icon, WU-479
  lesson card, C-323 festival spots. Systems has 3 ready tasks; ideas for more: a Qi Refining great-beast step after the
  capped first beast (C-317 note), a third village project once the owner answers SEASON-008.
- Next planner: view WU-478/GFX-093 festival shots once QA-205 lands; GFX-002 (art pack) still waits on the owner.

## State on 2026-11-07 (planner, 12:10 UTC)
- 15 tasks landed (WU-472, GFX-088, GFX-089, WU-473, WU-474, FOLK-016, GUIDE-215, SEASON-009, FOLK-017, FOLK-018,
  SEASON-008, C-312, C-318, C-316, QA-202). Review 3f308f5..aa54fa8 filed RV-018 (claimed 11:50).
- Planner shots (`--festival --friend-scene --critters`, `--region=qingshi_village,misty_forest`, 1280x800): GFX-089
  forest good. Festival crowd labels pile up and the [E] chip draws at the screen top -> WU-475 (spec file); square on
  the south edge -> GFX-090; friend card face tiny -> WU-476. "Founder's Old Well" is the inheritance place drawn as a
  stele (the landmark well by the workshop is a plain village well) -> note on RV-018, GFX-087 spec.
- New: FOLK-019, FOLK-020 friends who teach (spec file) -> C-321/WU-477, GUIDE-216, SEASON-010 -> C-322, CRIT-001 hen eggs,
  C-319 spots, C-320 tiger choices, GFX-091 mist bands. Systems has 5 ready tasks (no 6th worth writing yet).
- Next planner: view RV-018/GFX-087 well shots and WU-475/GFX-090 festival shots; GFX-002 (art pack) still waits on the owner.

## State on 2026-11-06 (planner, 12:10 UTC)
- 13 tasks landed (WU-462, GFX-078, WU-463, GUIDE-212, WU-464, C-309, WILD-018, C-272, GFX-079, SEASON-006, GFX-081,
  FEST-012, C-315). Review 5b5b907..dd1e14a filed C-315 (landed 11:25). Live claims: MISSION-003, QA-198.
- Planner shots (`--great --shrine=2 --region=qingshi_village,azure_peak,misty_forest`, `--calendar --book`): calendar,
  Festivals page and Azure steps good. Azure ground blocky + pine on the gate -> GFX-082 (spec file). Arrival line posted
  twice and vague, in-season line every arrival -> TODAY-002 (spec file). Foundation sees "Great Old Tusker (Weak)" and a
  Deadly leopard -> WILD-019 (spec file) -> C-317, C-312 (3). HUD panel cuts lines -> WU-468.
- New: WU-466 season board (spec file), GUIDE-214, SEASON-007 shrine incense (planner default, spec file) -> GFX-084,
  GFX-083 festival stalls (spec file), FOLK-013 friend scenes -> WU-467, C-316, QA-200 settings leak + calendar months.
- Next planner: view GFX-082/GFX-083/WU-466 shots when they land; GFX-002 (art pack) still waits on the owner.

## State on 2026-11-06 (planner, 06:10 UTC)
- 14 tasks landed (QA-197, GFX-076, WILD-017, FEST-009, FEST-010, WU-458, WU-459, FOLK-012, SEASON-005, QA-196, GFX-077,
  MARKET-012, WU-460, C-308). Review d8b322a..5b5b907 fixed two things inline; notes -> FEST-011. Live claim: WU-462.
- Planner shots (`--great --region=azure_peak,misty_forest`, `--book`, `--calendar`): GFX-076 gate and GFX-077 crane good.
  Foundation player sees only Weak roamers, HUD "Fair fight ... (Weak, 100 in 100)" -> WILD-018 (spec file), GUIDE-212,
  MISSION-003 -> C-312/C-313 -> QA-199. Calendar 6 cols for a 7-day week -> GFX-078 (spec file). Keepsake icons are black
  blobs -> WU-463. Azure Peak flat grey -> GFX-079. Log repeats lines -> WU-464.
- New: SEASON-006 shrine restoration (planner small default in DESIGN.md, spec file) -> GFX-081; FEST-012 festival stalls -> C-314.
- Several pre-ebae72c commits (FEST-009, WILD-017, GFX-076, QA-197) carry Co-Authored-By trailers; history is not rewritten.
- Next planner: view GFX-078/WU-463/GFX-079 shots when they land, and the QA-198 festival/journal shots; GFX-002 (art pack)
  still waits on the owner.

## State on 2026-11-06 (planner, 00:10 UTC)
- 17 tasks landed (WU-453, GFX-074, WU-456, WU-454, GFX-075, WU-457, WILD-016, SEASON-004, TODAY-001, MARKET-011, FEST-008,
  CAL-006, C-307, C-306, C-303, C-273, QA-045). Review ebed75d..d8b322a fixed two things inline. Live claim: QA-197.
- Screenshots DO work in the cloud: `xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3
  --resolution 1280x800 -s res://tests/sim/screenshot_first_hour.gd -- --great --region=azure_peak` (~3 min, PNGs in
  ~/.local/share/godot/app_userdata/Cultivation Game/screenshots/first_hour/). Workers wrongly report "no display"; specs now say so.
- Planner shots: gate still one pole, tree/villager on it, dome on the Azure court -> GFX-076 (spec); crane goat-sized -> GFX-077.
- QA-045: Foundation fights too easy (91% rated >95%) -> C-308 (spec, within the QA-007 default).
- New: WILD-017/C-309 hunt fixes and all seasons, FEST-009 rival at the festival, FEST-010 festival memories -> WU-460, FOLK-012
  friends at the festival, SEASON-005 season tasks -> WU-462/C-311, WU-459 mark days, MARKET-012, C-310, QA-198 festival shots.
- Next planner: view GFX-076/GFX-077 shots when they land; the owner still has not answered GFX-002 (art pack).

## State on 2026-11-05 (planner, 18:15 UTC)
- 14 tasks landed (MARKET-010, WILD-015, GFX-071, FEST-006, GOAL-012, GFX-072, WU-452, C-301, C-305, FEST-007, SEASON-003,
  QA-195 (test part only; balance part -> QA-196), GFX-073, C-302). Review 25992e9..ebed75d: main red 30 min, fixed by f027f5e.
  Live claim at 18:15: WILD-016. WU-453 finished on `claude/WU-453-regular-knows-it-ready` (f6eb174), not landed: row says cherry-pick.
- Planner shots (`--great --region=azure_peak,withered_bone_marsh,misty_forest`, `--great --tracks --region=misty_forest`):
  trail and labels good. Half gates, cave under the Azure court, plain marsh court -> GFX-074 (spec). Crane off screen on
  its day -> GFX-075. The tracks run crashed at screenshot_first_hour.gd:574 -> QA-197.
- Planner decision: Qingming to month 3 so spring has a festival (DESIGN.md C-307).
- New: WU-456 bait UI, TODAY-001 + WU-458 Today page, WU-457 festival crowd, SEASON-004, MARKET-011, FEST-008, CAL-006, QA-196.
- Next planner: view GFX-074/GFX-075 shots when they land; the owner still has not answered GFX-002 (art pack).

## State on 2026-11-05 (planner, 12:15 UTC)
- 14 tasks landed (WILD-014, SEASON-001, WU-445, WU-447, GFX-069, C-300, GFX-070, TRAVEL-001, GFX-067, GOAL-011, MARKET-009,
  WU-450, WU-451, C-299). Review 53e7743..25992e9 fixed GOAL-011 inline. Live claims at 12:15: WILD-015, QA-193, C-302.
- Planner shots (`--great --region=azure_peak,withered_bone_marsh,misty_forest`, `--great --tracks --region=misty_forest`,
  1280x800; Godot downloads in ~1 min): GFX-069 labels good. Gate roof hangs beside the road + tree on the board, Azure court
  over the Grotto, crane under labels -> GFX-071 (spec file). Tracks too sparse/pale -> GFX-072. Edge-cut labels -> GFX-073.
- C-299 regression: Night Market Stall sells only its picks -> MARKET-010 (top systems).
- New line: festival contests (FEST-006 spec file -> WU-454, FEST-007, C-306), summer festival C-305, regulars on screen WU-453,
  road encounter after the card WU-452, GOAL-012 per-realm great-beast wins, WILD-016 village hunt, QA-195 skipped balance checks.
- Next planner: view GFX-071/GFX-072 shots when they land; the owner still has not answered GFX-002 (art pack).

## State on 2026-11-05 (planner, 06:15 UTC)
- 12 tasks landed (WILD-012, WU-441, GFX-066, MARKET-007, GOAL-010, WU-440, GFX-068, C-297, C-296, MARKET-008, WU-443,
  WILD-013). Review c13642c..53e7743 fixed GOAL-009/010 0-based layers, FORAGE-005 shown slots inline. Live claims at 06:15:
  QA-193 (04:03), WU-445 (05:50), SEASON-001 (06:06).
- Planner shots: 720p text whole (GFX-066 good), Elder Mo clear (WU-441 good), marsh court/gate good. Labels collide (crane on
  Hermit Gu, chip on Pond Jetty) -> GFX-069 (spec file); Azure court flat and the gate thin -> GFX-070.
- New line: route-specific road encounters (TRAVEL-001 spec file; generic road encounters exist since TRAV-006), WU-447, C-303, Foundation road goals (GOAL-011), market regulars (MARKET-009,
  also prunes MARKET-008's per-day flags), bait on the tracks day (WILD-015), season ending line (SEASON-003), weather-herb
  recipes (C-302), tracks drawn on the ground (WU-450).
- WILD-013 skipped its balance check: C-300 (or QA-194 (3)) refreshes village/combat.
- Next planner: view GFX-069/GFX-070/WU-447 shots when they land; the owner still has not answered GFX-002 (art pack).

## State on 2026-11-05 (planner, 00:15 UTC)
- 12 tasks landed on 2026-11-02 (GFX-061/062/064/065, WU-439, CAL-005, WILD-011, MISSION-002, GOAL-009, FORAGE-005, C-284,
  QA-193 part 1); nothing landed 2026-11-03/04 (probably the weekly usage ran out). Live claim: WILD-012 (00:06 today).
- C-297 has a finished commit (ae050ab) on `claude/C-297-hunter-rumors-ready` that never reached main; the C-297 row says to
  cherry-pick it. The cleanup action has not removed that 3-day-old claim: check the workflow if more stale claims pile up.
- Planner shots: marsh calm and map roads fixed (good). 1280x720 text glyph breaks -> GFX-066; arrival card over Elder Mo and
  the [E] prompt over labels -> WU-441 (spec file); Azure Peak dreary, sect hall tiny -> GFX-068 (spec file).
- New systems line: market days with changing wares (MARKET-007 spec file, MARKET-008, WU-445, C-299), GOAL-010 road to
  Foundation, WILD-013 in-season beasts (+C-300), SEASON-001 season digest, WILD-014 great beasts return (+C-301), WU-443 road card.
- Next planner: view WU-441/GFX-066/GFX-068 shots when they land; the owner still has not answered GFX-002 (art pack).

## State on 2026-11-02 (planner, 18:15 UTC)
- 16 tasks landed (GFX-055/058/059/060, WU-435/437/438, GUIDE-210/211, GOAL-008, WILD-009/010, FORAGE-004, C-293,
  QA-190/191). Review fc7f679..9727a4a fixed GOAL-008 inline (great beast above the realm). No live claims at 18:15.
- Planner shots (`screenshot_screens.gd -- --map-shot` at 1280x720, `screenshot_first_hour.gd -- --book` and `-- --great
  --region=withered_bone_marsh,qingshi_village` at 1280x800): Qingshi, HUD cards and trophy shelf good. Map: roads run
  through unexplored node names (alpha buttons) -> GFX-061. Marsh ground is noise, toad among labels -> GFX-062.
  Nobody has viewed the full first-hour set or the new-game arrival card -> GFX-065.
- Planner decisions (in DESIGN.md): weekday names (CAL-005 -> WU-440); own-sect halls only (MISSION-002, smallest default).
- QA-177 was claimed twice and never landed; if it fails again, cut it to 5 seeds.
- Next planner: view GFX-061/062/065 shots when they land; read QA-193's forage numbers (C-293 re-measure).

## State on 2026-11-02 (planner, 12:15 UTC)
- 13 tasks landed (MISSION-001, RV-017, WU-433/434, GFX-056/057, GUIDE-208/209, WILD-008, FORAGE-003, C-292, C-294,
  QA-192). Review 152ba5f..fc7f679 filed RV-017 (landed). Live claims: QA-177, QA-190.
- Planner shots (`screenshot_first_hour.gd -- --great --region=azure_peak,withered_bone_marsh,myriad_peaks_ridge` and
  `screenshot_screens.gd -- --map-shot`, 1280x800): sect halls and labels look right; Great Cloud Crane reads; toad and ram
  were off camera -> GFX-060. World map: marsh has no map_pos and overlaps the Ridge, names clipped -> GFX-059 (spec file).
  HUD fair-fight line cut + "(Weak 99)" -> WU-435. Arrival line shows the old region's text -> GUIDE-210.
- Planner decision (C-292 Follow-up): cash spirit-stone drops from roamers stay; the 2-12 band is for items.
- New systems: GOAL-008 (goals that lead out of the village), FORAGE-004 rain finds (+ C-296), GUIDE-211 find notes,
  WILD-010 renown for great beasts; WU-437 trophy shelf, WU-438 arrival banner.
- Next planner: view GFX-059/WU-435/GFX-060 shots when they land; read QA-190 (then C-293) and QA-191.

## State on 2026-11-02 (planner, 06:15 UTC)
- 12 tasks landed (QA-189, GOAL-006/007, GUIDE-207, WU-431/432, GFX-052/053/054, C-291, FORAGE-002, WILD-007). Review
  972f647..152ba5f fixed GOAL-006 (log_complete on hunt_log) inline; notes -> WILD-008 (bounty vs great beast), GFX-057
  (paw glyph row), QA-192 (fuzz flake). Live claims: MISSION-001 (4th, 06:12; WIP now 9597e86), QA-177 (04:04).
- Planner shots (`--region=fallen_star_market,azure_peak,myriad_peaks_ridge,qingshi_village` and `screenshot_screens.gd
  -- --creation`, 1280x800; Godot downloads in ~1 min): **the Qingshi pond is drawn but hidden under the vitals card** at
  the arrival camera (WU-431's worker rendered and could not see a bug) -> WU-434 for every region. Labels readable now but
  overlapping in places -> GFX-056; Cloud Crane is a brown blob "(Deadly) (great)" -> GFX-057; market winter/garden/big
  shops -> GFX-058. Creation screen with WU-432's theme looks right.
- C-291 landed before WILD-007, so no trophies exist yet -> C-294. GUIDE-207 part 2 -> GUIDE-208.
- Next planner: view WU-434/GFX-056/GFX-057 shots when they land; read QA-190 (then release C-293) and QA-191.

## State on 2026-11-02 (planner, 00:15 UTC)
- 14 tasks landed (WU-429/430, GFX-048/049/050/051, WILD-005/006, GUIDE-206, COOK-001, MARKET-006, C-288, C-290, QA-187).
  Review de28f82..972f647 fixed WILD-005 (bounty pay logged as spoils) inline; notes -> GUIDE-207 (articles), C-293 (forage pay).
  Live claims: GOAL-006 (00:06), QA-189 (00:05). MISSION-001's 2nd claim left WIP e9fc3c7 (foundation_year survivability
  7/10); the task now says start from it, fix the sim not the threshold, skip `--check` (QA-191 does it).
- Planner shots (`--region=qingshi_village,fallen_star_market,azure_peak,myriad_peaks_ridge,misty_forest`, 1280x800): the
  Qingshi pond is not drawn (jetty over grass) -> WU-431; far labels vanish on paved/scree -> GFX-052 (spec file); scree is
  noise, a pine on the Ridge road -> GFX-053; market is a flat grid, edge stalls cut -> GFX-054. Misty Forest looks good;
  fox/stag shapes read (GFX-050 follow-up checked).
- Planner decision (C-288 Follow-up): forage is a snack, not a living -> C-293 caps it (after QA-190's numbers).
- Next planner: view WU-431/GFX-052/GFX-053 shots when they land; read QA-190 and QA-191.

## State on 2026-11-01 (planner, 18:15 UTC)
- 11 tasks landed (WU-426/427/428, GFX-046/047, CAL-004, MARKET-005, FORAGE-001, GUIDE-205, C-289, QA-188 part 3).
  QA-188 refreshed the whole balance baseline (drift = rng shift from village data). Review 8711586..de28f82: notes only;
  its notes are now WU-429 (water z, fleeing beasts over scenery, double colon) and C-290 (the gentle ape is skinned).
  Live claims: WILD-005 (18:06), MISSION-001 (14:30, expires ~18:30).
- Planner shots (`--region=qingshi_village|withered_bone_marsh|misty_forest`, 1280x800; the shot is
  `user://screenshots/first_hour/hud_arrival.png`): Next steps card ends mid-sentence ("(Sold at Wandering") -> WU-429;
  Misty jetty crosses the road, vertical jetties look like poles, black blots under marsh dead trees, pickups invisible ->
  GFX-049 (spec file); ape drawn as the plain quadruped -> GFX-050.
- New systems: GUIDE-206 (HUD names where), COOK-001 (eat before you fight), MARKET-006, WILD-006 (great beast weekly, spec
  file) -> WU-430 + C-291, GOAL-006. QA-190 sim picks forage.
- Next planner: view WU-429/GFX-049/GFX-050 shots when they land; read QA-189/QA-190 numbers.

## State on 2026-11-01 (planner, 12:10 UTC)
- 15 tasks landed (WU-422/423/424/425, GFX-044/045, WILD-002/003/004, CAL-003, MARKET-004, C-283/285/287, QA-188 part 2).
  Review 3508d33..8711586 fixed WILD-003 inline (only non-lethal beast quarry roams), nothing filed. MISSION-001's claim
  (06:06) expired without landing; it stays top of systems.
- Planner shots (`--region=misty_forest|withered_bone_marsh|qingshi_village`, 1280x800; copy hud_arrival.png between runs,
  the user:// path has a space): Misty Forest good, beasts visible. Jetties float 40-60 px off their ponds, the marsh's
  visible trees are 6 landmark `pine`s (decor dead trees too few), bog ground noisy -> GFX-046 (spec file). Roamers stack
  (ape on boar, names overlap) and bold charges don't pass `charged=true` -> WU-426.
- New: FORAGE-001 (spec file) -> WU-427 + C-288; CAL-004, MARKET-005, GUIDE-205, WILD-005; C-289 spoils for the kitchen;
  QA-188 is now the balance --check after the village data changes; QA-189 field sim sells its crop.
- Next planner: view GFX-046/WU-426 shots when they land; read QA-188's balance result.

## Village screens look (QA-182)

`tests/sim/screenshot_first_hour.gd` flags now combine (`-- --celebration --field --quarrel --cast` renders all four); `--quarrel` opens the QuarrelWindow through `quarrel_requested`, `--cast` the CastBar with the marker frozen at 0.45, and the `shop` shot is the ShopScreen itself (the merchant's list is `shop_menu`, only when a merchant node exists). Every shot except `hud_arrival` now waits out a fading banner (queued notices used to cover the modals).
Viewed at 1280x720 (all) and 1280x800 (run clean): celebration, quarrel, field, shop, cast, encounter, elder_mo_dialogue, hud_arrival, journal, character_sheet. Nothing clipped or overlapping; quarrel and cast read well, shop list/detail fit with the footer note, the journal and sheet scroll as designed. No one-place fixes needed.

## State on 2026-10-31 (planner, 18:15 UTC)
- 14 task commits landed (GFX-036/037, WU-413/415/416/417, WEATHER-006, FOLK-007/008, GOAL-005, MARKET-002, C-280, QA-183,
  QA-174 part 1). Review d37bbb0..18b102f fixed FISH-005 (missed trophy emptied the trip) and WEATHER-006 (paid discount
  permanent) inline. Live claim: none fresh (WU-417 branch is the landed one).
- Planner shots (Godot downloaded, `xvfb-run ... screenshot_first_hour.gd -- --season=Autumn` and `-- --book --digest
  --storm`, 1280x800): autumn trees, herbs page and digest card fine. The duel stage draws pale discs outside its frame over
  the name labels -> GFX-038 (spec file, top world-ui). Ground stays summer green in autumn -> GFX-039.
- `--book` mode only writes the book/digest shots; the default run writes the 14 first-hour shots.
- Systems was empty: FLAG-001 (spec), CAL-001 (spec file) -> WU-419, FOLK-009 (spec) -> WU-420, MISSION-001 (QA-174's
  finding; only Qingshi and Fallen Star Market have a sect_hall, Azure Peak has none), MARKET-003, FISH-006 -> C-283.
  QA-185 refreshes the balance baseline (QA-183 says `--check` is red from drift).
- Next planner: view GFX-038 shots when it lands; check MISSION-001 kept a board at the sect home; read QA-185's table.

## State on 2026-10-31 (planner, 12:15 UTC)
- 12 tasks landed (GFX-033/034/035, WU-414, WEATHER-005, GUIDE-204, FARM-005, GATHER-002, FISH-005, C-278/279, QA-182).
  Review 3579385..d37bbb0 fixed FISH-004 (rank-up via first-catch bonus) and WEATHER-005 (storm line every day) inline.
- Planner shots (`screenshot_first_hour.gd -- --storm`, `-- --book --field`, 1280x800): sheet and book fine; the fallen boar
  stands on its tail mid-air, roofs backdrop reads as hedges, `--storm` is lost after the first action -> GFX-036 (spec);
  both fish share one icon, no herb page -> WU-417 (spec); no visible seasons -> GFX-037.
- Systems had only DAY-001: added WEATHER-006 (spec, peddler discount flag nobody read), FOLK-007 (spec, friendship tiers ->
  WU-418), GOAL-005, MARKET-002. Content: C-280 spec'd, C-281, C-282. QA-184 (tending pays?).
- C-279 set rent 3 (not 4) with sim numbers; no `--check` run was mentioned. QA-183 is still the crafter-baseline question.
- Next planner: view GFX-036/WU-417 shots when they land; read QA-183/QA-184 numbers.

## State on 2026-10-31 (planner, 06:15 UTC)
- 13 tasks landed (QA-181, GFX-030/031/032, WU-411/412, FARM-003/004, GATHER-001, FISH-004, GUIDE-203, C-269/277). Review
  a12ccef..3579385 fixed C-277 inline, nothing filed. Live claim: WEATHER-005.
- Planner shots (screenshot_first_hour.gd, 1280x800): HUD card, bag, journal cards and visitor read well. Character sheet
  still weak -> GFX-034 (spec file); duel stage is a flat strip -> GFX-035. Village skills have nowhere to show finds ->
  GATHER-002 (herb log) + WU-414 (village book, spec file).
- QA-181 numbers -> C-279 (fishing 2.9x Doctor, field loses money; spec'd, top of content), FARM-005 (care pays at harvest).
  GATHER-001's crafter baseline drop -> QA-183. New: GUIDE-204 -> WU-415 (season in prices/shop), DAY-001 -> WU-416 (digest),
  FISH-005 -> C-280 (trophy fish).
- Next planner: read C-279's before/after and QA-183's verdict; view GFX-034/GFX-035 shots when they land.

## State on 2026-10-30 (planner, 18:15 UTC)
- 13 tasks landed (RV-016, WU-405/406/407, GFX-024/025/026, MARKET-001, FISH-002, WORLD-007, FARM-001, FOLK-004, C-274).
  Live claims: FOLK-005, WEATHER-004. World-ui was down to GFX-027 alone.
- Planner shots (screenshot_first_hour.gd, 1280x800): bullet, labels and ground fixed. Filed WU-408 (speaker portraits, spec
  file), GFX-028 (duel stage: 3x fighters, beast kinds, contrast; spec file), WU-409 (banner backdrop + titles, menu blank band),
  GFX-029 (field growth art), WU-410 (quarrel window), WU-411 (visitor tea + greeting_bubble shot), GFX-030 (sheet/journal
  cards), WU-412 (fishing timing bar, after FISH-003).
- Systems: GUIDE-202 (village hints + forecast, spec file), COOK-002 (meal buffs, spec file), FISH-003, FARM-002, TECH-010
  (reviewer notes), FOLK-006. Content: C-276 spec'd, C-277. QA-181 (village-life sim, spec file) on top for qa.
- Next planner: view WU-408/GFX-028/WU-409 shots when they land; read QA-181's numbers before adding more village systems.

## State on 2026-10-29 (planner, 18:15 UTC)
- 13 tasks landed (GFX-010..013, WU-397, RIVAL-022, ENC-010/011, WEATHER-001, WORLD-001, C-267, C-270, QA-175). Review
  c83d675..f62a1fb fixed GFX-010 (hunt line with hints off) and C-270 (capitalized lecture lines) inline. No live claims.
- Planner re-rendered all regions and the first hour (GFX-010/011/012 Follow-ups done): pixel people and landmarks work.
  Problems -> GFX-014 (fight report still vector pawns; banner over the report title), GFX-015 (too many NPC names;
  white labels on pale Azure Peak ground), GFX-016 (status card ~225 px, key strip wraps).
- Systems was empty: added RIVAL-023 (reviewer note: false spar-cooldown line), ENC-013 (seasons/weather gates, rest for
  repeatables -> C-265 rewritten with QA-175's numbers, C-271), HEART-001 (spec file; heart vision before major
  breakthroughs, EV-neutral since sims never pick it -> WU-400), WORLD-002/003 (doing-today line, greetings -> WU-401),
  WEATHER-002 (rain herbs, snow travel; runs balance.sh).
- Next planner: view GFX-014/015/016 shots when they land; check HEART-001's odds stay EV-neutral in balance.sh.

## State on 2026-10-29 (planner, 12:15 UTC)
- 15 tasks landed (GFX-006..009, WU-391/396, RIVAL-021, GUIDE-197/200/201, MENTOR-005, C-258/263, QA-173/176). Review
  1decde8..c83d675 fixed one test inline. Live claims: RIVAL-022 (WIP commit 12:28), C-256 (10:26).
- Planner rendered every region (`xvfb-run ... screenshot_regions.gd`, works in the cloud, ~1 min): the HUD covers the
  left third of the screen -> GFX-010 (spec file); people are vector pawns -> GFX-011 (spec file, generated pixel
  figures); only Qingshi has landmarks -> GFX-012 (new kinds wall/cliff/stream/lantern/pine/stall, all regions).
- Traces 139 (sect) and 141 (rogue), 36 months: Foundation village beats repeat monthly -> ENC-010 (rest_days, spec file);
  lecture line never varies -> C-270. New world-feel work: ENC-011 (`{villager}` in happenings + favor), WEATHER-001 ->
  WU-399, WORLD-001 (villagers' daily round), C-267 (beast tags for the duel stage), C-269 (Foundation Qingshi beats,
  `sect_only`), WU-397 (hit feedback + reduce motion), GFX-013 (last sprite hooks), WU-398 (hint-shot repairs).
- QA-173: base sect players stall at Foundation Peak (0/10 Core in 60 months), with the sect method 10/10 reach Core:
  recorded under F-005d; no retune (owner's pacing call).
- Next planner: QA-175's repeat list (-> C-265; ENC-010 may already cover the village beats), look at GFX-010/011 shots.

## State on 2026-10-29 (planner, 06:15 UTC)
- 3 tasks landed (GFX-001, WU-390, QA-168: every balance diff explained, no follow-ups). No review since 1decde8.
  Live claim: RIVAL-021 (fresh).
- World-ui was down to WU-391 alone. Added pack-independent visual work: GFX-006 (sprite hooks for ground, paths, decor,
  NPCs; spec file), GFX-009 (integer pixel zoom: 1920x1080 scales the world 1.35x today), GFX-007 (generated pixel ground
  fallback; spec file), WU-396 (duel stage in the fight report), GFX-008 (Qingshi landmarks: houses, fields, pond).
- Network: raw.githubusercontent.com is reachable from the cloud (itch/kenney/opengameart are not). Noted in DESIGN
  "(GFX-002)": the owner can just name a GitHub-hosted CC0 pack. QA-176 adds a licence guard test before any pack lands.
- Trace `simulate_curious_years.gd -- 1 36 --trace=137` (sect): Foundation m29, then 2048 stones and 7459 contribution
  unspent; the Heart Sutra (x1.9) is offered but the realm goal never says what it is worth -> GUIDE-201; a friendly
  rival still ambushes you -> RIVAL-022. The monthly pointers line and the headman beat repeat again (MENTOR-005, C-263).
- Next planner: QA-173/QA-175 results when they land (QA-175 -> spec C-265); move GFX-003..005 once the owner answers.

## State on 2026-10-29 (planner, 04:15 UTC)
- 20 tasks landed (GUIDE-190..196, WU-380/384..389, C-259..262, QA-170/172; GUIDE-190 had landed before the 02:15 plan).
  Review d6b9126..1decde8 fixed GUIDE-191 inline, filed nothing. Live claims: QA-168 (04:01); C-248 and C-256 are 3-5h old
  and the cleanup Action will release them.
- QA-170: skipped stipends are rank-1 months with no mission (the sim's policy), not a bug -> QA-174.
- Owner commit 11e79aa (2026-10-28): pixel-art direction, reference games, ~52 runs/day, fewer larger tasks. Applied:
  GFX-001 (sprite pipeline, spec file) on top of world-ui; GFX-002..005 blocked on the pack (the cloud can't reach
  itch.io/kenney/opengameart; DESIGN "(GFX-002)"); per-hint screenshot tasks merged into WU-391; hint-only specs skip
  balance.sh.
- Traces 127 (sect) and 131 (rogue), 36 months: rival duel nearly monthly -> RIVAL-021 (cooldown); Granary Blessing x4 ->
  C-263; identical pointers line -> MENTOR-005 (10 lines); sell hint sells order ingredients -> GUIDE-200; GUIDE-197
  bundles three Goals/hint truth fixes (faster spot after 90 days saved, Core pill behind a hopeless trial, no mission
  hint for a rich member). QA-175 counts every repeat in a long life -> C-265.
- Next planner: QA-168's attribution of the balance diffs, QA-173's Foundation Peak numbers (put them under F-005d, don't
  retune), QA-175's repeat list (spec C-265 from it).

## State on 2026-10-29 (planner, 02:15 UTC)
- 13 tasks landed (GUIDE-187/188/189, WU-377/378/379/381/382/383, C-255/257, QA-166/167). Review 4bc1f62..d6b9126: no
  defects. Live claims: GUIDE-190, GUIDE-191, C-248, C-256, QA-170.
- Trace `simulate_curious_years.gd -- 1 36 --trace=121` (sect, ~4 min): Foundation m11, then Foundation Peak m20-m36 with
  5 failed Core attempts (31-40%), method x1.0 and 7942 contribution unspent. Core Forming Pill is sold only to Elders (who
  must already be Core) in all three sects -> C-260 (move it to Core Disciple + data test). Method hint below the defence
  hint -> GUIDE-196. Newborn beat repeats -> C-261. QA-173 measures the Foundation Peak stall for F-005d.
- Follow-ups filed: GUIDE-193 (heal-first clause forward, WU-383), GUIDE-194 (urgent orders, QA-166), GUIDE-195 (explore
  footer, WU-382), WU-385/386 (first-hour shots), QA-172 (WU-379 test), QA-168 now also covers GUIDE-187/188/189's skipped
  balance checks and GUIDE-189's unexplained early-fights diff.
- Next planner: read QA-168 (is the early-fights diff real?) and QA-170's stipend answer; after QA-173, put its Foundation
  Peak numbers in front of the owner under F-005d, don't retune.

## First-hour screenshot look (WU-382, 2026-10-29)
`screenshot_first_hour.gd` writes 8 pngs (it overwrites between sizes, so copy them out after each run). Viewed hud_arrival and journal at both 1280x720 and 1280x800, the other six at 1280x720 only (they share one modal layout code path); nothing clipped, overlapping or cut mid-word beyond the intended "... (J)" cap. No layout changes needed.
- hud_arrival: Goal "Talk to Elder Mo" + fair fight + three hints fit the panel; the last hint is capped "... Blood Lotus Sect takes mortals now... (J)". The Goal line does not repeat any hint. The log panel and interact prompt do not overlap the status panel. `hud_after_sect` is not produced by this script (WU-379's region-aware clause is covered by test_hud_cues and the hint shots instead).
- journal: First goals + Next steps scroll cleanly; the milestone "First Blood" banner overlaps the top of the dimmed screen (a capture-timing artifact: the shot is taken while the banner is still fading, not a layout bug).
- character_sheet: Next steps (3 lines + "More in the Journal (J)"), Sect Reputation and the greyed Recharge button all fit; sheet is scrollable.
- inventory: Boar Hide detail wraps ("Sells for 2 each at ... and 2 more") without clipping.
- elder_mo_dialogue, explore_menu, encounter, combat_report: all fit; the greyed "Needs more favor (0/20)" option is still readable.
- Reading oddly (text, so Follow-up only): the Journal "Next steps" repeats the HUD hints nearly word for word (by design); the Explore menu's footer "Often quiet (14%). Fights 14%: Wild Boar (Weak). Crossroads 27%. Fortunes 45%." mixes ":" and "." separators.
- WU-385: the script now writes 9 pngs (new `hud_after_sect`: Outer Disciple at Qi Refining 1 in Qingshi Village; the shot restores sect, realm, stage and qi on close). 1280x720: the status panel (ends y=484) clears the message log (starts y=545); Goal "Talk to Elder Mo in Qingshi Village" is not repeated by a hint; the capped mission hint ends "... (J)". 1280x800: same, nothing clips or overlaps. Text oddity (Follow-up, not fixed): the message log still shows arrival lines naming travel "from Misty Forest" while the player stands in Qingshi Village.
- WU-388: explore_menu re-rendered at 1280x720: the footer reads "Often quiet 14%. Fights 14%: Wild Boar (Weak). Crossroads 27%. Fortunes 45%." with no parentheses; it wraps onto two lines and nothing clips.


## State on 2026-10-24 (planner, 06:15 UTC)
- 17 tasks landed (ITEM-003, GUIDE-178/179/181, PERF-006, WU-365/366/367/369/370/374, C-247/250/251/253, QA-155/163).
  Review 155b49f..257aa9c filed nothing (shop realm-tag note -> WU-375). Live claims: GUIDE-180, PERF-007, WU-362,
  WU-373, QA-162 (all fresh).
- QA-163: far-qi injuries go untreated (no healer at Azure Peak; hint silent when the clinic is far/unaffordable; sim
  ignores hints) -> GUIDE-183/187, C-254, QA-165. QA-155: body art lifts the Core Disciple trial median 10 -> 41 -> QA-169.
- Trace `simulate_curious_years.gd -- 1 36 --trace=103 --rogue` (~3 min): rogue Foundation m33, 1058 stones unspent
  -> GUIDE-184/185/186 (name the scroll seller, the local body manual first, the abode in the clan goal), C-256 (work pay).
- New: GUIDE-182..187, WU-375..378, C-254..256, QA-165..169.
- Next planner: read QA-162 (sect + far qi) first; if a travelling sect member is not faster than a travelling rogue,
  add numbers to DESIGN (QA-158), don't retune. Then QA-165 (does the far-qi speed-up survive healing?).

## State on 2026-10-24 (planner, 04:15 UTC)
- 13 tasks landed (GUIDE-173..177, C-244/246/249, QA-160/161, WU-363/364/368). No review since 41ee758 (next reviewer
  run covers c5b1ff15..558c8d5). Live claims: PERF-006, QA-155, WU-362, WU-369 (all fresh).
- QA-161: rogue + far qi spot = Foundation median 673 days vs sect base 1632 (sect arm never travels). The DESIGN
  (QA-158) question is annotated; no rogue levers proposed. -> QA-162 (sect + far qi, what a member gives up),
  QA-163 (far-qi injuries untreated?).
- Cloud-Mist Qi Pill works at Qi Refining (text says Foundation): ITEM-003 adds item `min_realm` (spec file), then
  C-252 audits other qi items, QA-164 re-runs QA-161's arms.
- New: ITEM-003, GUIDE-178..181, WU-371..374, C-251..253, QA-162..164; spec files ITEM-003.md, GUIDE-178.md.
- Next planner: read QA-162's answer. If a sect member who travels is not faster than a rogue who travels, that is a
  real sect-value question for the owner: add it to DESIGN (QA-158) with numbers, don't retune.

## State on 2026-10-24 (planner, 02:15 UTC)
- 17 tasks landed (GUIDE-158/168..171, WU-352/355/357..361, C-241/242/245, QA-158/159). Review 41ee758: no defects.
  Live claims: GUIDE-172, GUIDE-173, QA-160 (all ~02:05).
- QA-158 (rogue arm): Foundation by m36 3/10 vs sect 10/10. Trace `simulate_curious_years.gd -- 1 36 --trace=89 --rogue`
  (~2 min): QR8 at m36 with 1467 stones; the top hint (Cloud-Mist Qi Pill, 5000 qi for 198 stones, usable at Qi
  Refining though its text says Foundation) and the far-qi trip are never taken by the sim. -> QA-161 (top qa) measures
  a rogue who follows them; DESIGN "(QA-158) Rogue pace" asks the owner for the target (default: within ~1.5x of sect).
- New: GUIDE-174..177, PERF-006/007, WU-362..370, C-248..250, QA-161; spec file docs/specs/GUIDE-175.md.
- Next planner: read QA-161's answer first. If a hint-following rogue is still > 1.5x slower, write rogue-lever
  proposals into the DESIGN question (don't build them). If Cloud-Mist pills skip > 1 year at Qi Refining, that is a
  balance bug (the item text says Foundation): file a content task for a realm gate or price.

## State on 2026-10-24 (planner, 00:15 UTC)
- 13 tasks landed (GUIDE-163/164/166/167, WU-351/353/354, C-216/238/240/243, QA-156/157). Review f7ea31e only removed a
  stray scratch .uid. Live claims: GUIDE-165 (two claim branches), GUIDE-168, WU-356, QA-158 (none stale).
- QA-156: the treasury method (x1.6) is claimed ~day 900 and brings Foundation ~8% sooner -> GUIDE-158 unblocked and
  spec'd (docs/specs/GUIDE-158.md). Its follow-up ("claimable earlier?") is pacing, so it stays with F-005d.
- Trace `simulate_curious_years.gd -- 1 36 --trace=97` (~2 min): slower seed (QR9 m24, Foundation m29). -> GUIDE-169
  (trial line advice first for the HUD cap, spec file), GUIDE-170..173, C-245, WU-359..361, QA-160.
- Next planner: when QA-158 (rogue arm) lands, read its Follow-ups first; rogue-only gaps are the least explored area.

## State on 2026-10-23 (planner, 20:15 UTC)
- 15 tasks landed (RV-015, GUIDE-152..155/157, C-231/233/234, WU-339/342..345, QA-154). Review 886d9a4 filed nothing.
  Live claims: WU-311, GUIDE-156, QA-125 (none stale; C-204's claim is past 4h).
- Trace `simulate_curious_years.gd -- 1 48 --trace=83` (~3 min): 13 months at the QR9 bottleneck, 4 Foundation pills
  bought with stones while claimable for contribution (QA-157), 9956 unspent contribution at m48 with the x1.6 sect
  method in the treasury (WU-348, QA-156, GUIDE-158 -> DESIGN F-005d note), injured while the treasury sells a healing
  pill (GUIDE-161), 1-round boar fights at Foundation (C-236). `--hint-shot` aborts early on main (WU-347, top).
- Systems is thin (3 ready specs + GUIDE-156 claimed + GUIDE-158 waiting): the next planner should find more systems
  work, ideally from QA-125/QA-155/QA-156 answers on the Foundation trial and pacing.

## State on 2026-10-23 (planner, 18:15 UTC)
- 12 tasks landed (GUIDE-147/148/149/150, WU-337/338/340/341, C-223/232, QA-151/152). Review 19a5c27 filed RV-015; the
  planner measured den_wolf power_mult vs a bare QR1 newcomer (0.55 -> 57/80/92% at stages 0/1/2, typical player 100%),
  so RV-015 now tests that hunt against the bare newcomer instead of the typical player. Live claims: WU-311, QA-153, C-204.
- Traces: `simulate_first_hour.gd -- 1 12 --curious --trace --seed=79` (healthy first year) and
  `simulate_curious_years.gd -- 1 36 --trace=79` (Foundation years in Qingshi repeat; trial 5 in 100 at Foundation Peak;
  treasury body art never bought). -> GUIDE-152..157, WU-342..346, C-233..235, QA-154/155.
- Next planner: look past the first year more often; the first-year hints are now in good shape.

## State on 2026-10-23 (planner, 16:15 UTC)
- 16 tasks landed (GUIDE-138/144/145/146, INJ-001, PERF-005, WU-331..335, C-226/229/230, QA-147/150). Review bda3229 fixed
  GUIDE-145's free re-entry in place, filed nothing. Live claims: C-204, C-223 (11:36, past the 4h cleanup), QA-151,
  WU-311, WU-336.
- 16:10 curious trace (seed 73): final death on day 386 (3 lives spent on lethal Mist Wolves: 2 at 62% on the hinted
  mission, 2 at 85%; recharge line buried, qi-pill line led with 81-101 stones) -> GUIDE-147/148/150, QA-152/153,
  WU-338..341, C-231/232; DESIGN C-009 note. To reproduce: `simulate_first_hour.gd -- 1 12 --curious --trace --seed=73`
  (the sim stops silently at death; QA-152 adds a deaths report).
- QA-150 answer copied to F-005d (cap 2/month ~12% sooner); GUIDE-135 stays blocked. QA-147: Misty Forest's roadside
  rogue_cultivator rates 8% at m12 but is sensed and avoidable; left as is (C-009 territory).
- Four workers hit the same 2 failing `--hint-shot` asserts -> WU-337 at the top of world-ui.
- Systems has 4 ready tasks (GUIDE-147..150); QA-153's answer may add a rating fix. Content has 2 ready + 3 waiting/claimed.

## State on 2026-10-23 (planner, 14:15 UTC)
- 13 tasks landed (GUIDE-137/140/141/143, WU-309/329/330, C-224/225/227/228, QA-145/149). Review ec4ffab filed nothing.
  Live claims: C-223, GUIDE-138, INJ-001, QA-150, WU-311 (none stale; WU-311 has two claim branches, the 10:16 one expires).
- QA-149/C-225: newcomer breakthrough injuries are rare (1 seed in 20), no data change. QA-145: following the far-qi offer
  is a big speed-up (Foundation in 6/10 seeds by m12) -> DESIGN F-005d note, QA-151 measures fights after the move.
- 14:10 curious trace (seed 71): thin-defence line ignores the sect treasury's 45-contribution Stone Skin -> GUIDE-144,
  WU-336, C-229; "Fallen Star Vault is open" with no place or cost -> GUIDE-145, C-230; Foundation fights all 100% in
  Qingshi -> GUIDE-146 (after QA-147). Follow-ups filed: WU-333 (breakthrough shot, sect claim), WU-334 (far-qi map
  mark), WU-335 (show_journal lambda capture error).
- Owner questions unchanged (pacing incl. contribution qi pills and the far-qi trip, first fights, ascension, RIVAL-019,
  ENC-008, GEAR-001).

## State on 2026-10-23 (planner, 12:15 UTC)
- 15 tasks landed (GUIDE-130/132/133, EFF-001, WU-320/323/325/326/327/328, C-220/221/222, QA-148, QA-20261023-2). Review
  e46c09d filed nothing; its GUIDE-132 reserve note -> GUIDE-137. Live claims: C-223, QA-145, PERF-004 (none stale).
- QA-148: contribution qi pills are a big speed-up -> GUIDE-135 blocked (F-005d note added), QA-150 measures a capped hint.
- 12:10 curious trace (seed 1): Qi Deviation on day 28 with 19 stones (clinic 80, hint says only "see a doctor") ->
  GUIDE-138, INJ-001, QA-149, WU-331, C-225/226; "Use your Spirit Herb" beside the herb mission -> GUIDE-140; QR7 with
  every fight 98-100% -> C-228; Core Disciple line hides its Foundation gate -> GUIDE-141; breakthrough window still
  prices the pill in stones for a claimant -> WU-330, C-227. WU-329 repairs two failing `--hint-shot` asserts.
- Owner questions unchanged (pacing incl. contribution qi pills, first fights, ascension, RIVAL-019, ENC-008, GEAR-001).

## State on 2026-10-23 (planner, 08:15 UTC)
- 16 tasks landed (GUIDE-121/123/124/125/127, WU-313..318, C-208/211/215, QA-134/144). No new review since 05:58 (last
  reviewed 9f32f92). Live claims: GUIDE-119, PERF-003, WU-309, WU-311, C-204, C-212, QA-140 (none stale).
- Hint-cap work is done: QA-143's `--long-hints` on 86b81e3 shows cut lines only lose tails now (GUIDE-127 guards it).
- 08:10 curious trace (seed 61): Foundation at m12, 45 won / 3 lost, every fight 100% from m07, 426 stones, never left
  Qingshi (sixth trace in a row). At Foundation the Gather line's Azure Peak option (5x qi vs 2x) is cut by the HUD ->
  GUIDE-128 (spec, travel lead), QA-145 (spec, measure the trip), WU-319 (road says what waits), WU-321/323, C-219 (the
  "(2x qi)" labels are per region, Cloud-Sea Cliff is really 5x). QA-144 cleared GUIDE-126 (spec); GUIDE-131/WU-320 stop
  hints valuing qi that cannot fit before the bottleneck. Reviewer notes -> GUIDE-129 (wanted lines), GUIDE-130 (season).
- DESIGN F-005d gained the QA-144 note (Bog Lily Qi Pill in Qingshi). Owner questions otherwise unchanged.

## State on 2026-10-23 (planner, 06:15 UTC)
- 13 tasks landed (REV-030, GUIDE-118/122, WU-303/310/312, C-206/207/213/214, QA-141/142/143). No new review since 04:00
  (last reviewed ddada62). Live claims: GUIDE-121, WU-309, WU-311, C-204, QA-134 (none stale).
- Planner re-ran `--curious --long-hints` (10x12) on 8afd8bd: GUIDE-122 works; sect/trial lines wait on GUIDE-121; idle,
  practise and thin-defence lines -> GUIDE-125 (spec). GUIDE-127 adds a headline guard test after both.
- 06:10 trace (seed 59): QR6 at m12, 26 won / 2 lost, never left Qingshi, 349 stones unspent. The Wandering Merchant sells
  15-stone Qi Gathering Pills (no stock_tags = every untagged item) and nothing says so -> QA-144 (spec, measure first),
  GUIDE-126 (hint, after QA-144; may need the owner's pacing call), WU-314 (worth in the shop), WU-318 (shop marks the
  hinted item). Also new: WU-315/316/317, C-215..218.
- The first-hour sim prints "Compile Error: Identifier not found: EventBus (hud.gd:193)" at start because QA-143 uses
  `HUD.HINT_MAX_CHARS`; harmless, QA-144 step 3 switches it to `Guidance.HEADLINE_CHARS` once GUIDE-121 lands.
- Owner questions unchanged (pacing, first fights, ascension, RIVAL-019, ENC-008 checks, GEAR-001).

## State on 2026-10-23 (planner, 04:15 UTC)
- 13 tasks landed (TOOL-001, GUIDE-115/117/120, WU-300/301/302/305/306/308, C-209/210, QA-138). Review c2dec34
  (65d397e..89bc68f) filed nothing. Live claims: GUIDE-118, QA-141, QA-142 (none stale).
- 04:10 curious trace (seed 53, 12 months; TOOL-001 made it work in a fresh container): QR7, 27 won / 3 lost, 2 clinic
  visits, never left Qingshi, 262 stones unspent at m12 with the armor hint shown m06-m12 (GEAR-001 note added).
- WU-305 caps HUD hints at 120 characters, which now hides the action on the sect line (always the "Earn N more ..."
  preamble), the trial odds, the clinic price and the faster meditation spot -> GUIDE-121/122 (P0, specs in docs/specs/),
  QA-143 (tally of cut lines), WU-309/313 (shots after). Also new: GUIDE-123 (spar gain vs hint, QA-138 follow-up),
  GUIDE-124 (Gather line misses Qingshi's own Spirit Spring), WU-310/311/312, C-213/214.
- Owner questions unchanged (pacing, first fights, ascension, RIVAL-019, ENC-008 checks, GEAR-001).

## State on 2026-10-23 (planner, 02:15 UTC)
- 19 tasks landed (GUIDE-108b/110/111/112/113/114, DATA-001, ENC-008/009, WU-294..299, C-202/205, QA-128/139). No new
  review (last reviewed 65d397e). PERF-002 (no code change -> PERF-003) and C-203 landed during the run. Live
  claims: QA-138, WU-300 (none stale).
- 02:10 curious trace (seed 47, 12 months): calm and winnable (18 won / 2 lost, 0 injuries, QR8 at day 788). The deliver
  clause names the wrong mission (GUIDE-120), three hints want the same Spirit Herbs (GUIDE-115/118/119, WU-303/308), and the
  open trial at 60 in 100 gives no lever (GUIDE-117). New: TOOL-001 (sims fail in a fresh container until `--import`),
  QA-142 (balance baseline drift), C-209 (drunk bully power_mult), WU-301 (`--hint-shot` WU-288 case fails on main).
- DESIGN.md had the ENC-008 question twice; merged. Owner questions unchanged (pacing, first fights, ascension, RIVAL-019,
  ENC-008 checks, GEAR-001).

## State on 2026-10-23 (planner, 00:15 UTC)
- 11 tasks landed (GUIDE-108, PERF-001, C-199/200/201, WU-241/291/292/293, QA-136/137). No new review (last reviewed
  56b85f2). Live claims: GUIDE-110, GUIDE-112, ENC-008, WU-294, WU-295.
- Two workers claimed C-201 on different branch names (claude/C-201-herb-hall-tithe, claude/C-201-herb-tithe) and both
  landed: a duplicate `herb_hall_tithe` row -> C-205 (P0) and DATA-001 (duplicate-id validator). Workers should check
  `git branch -r | grep "claude/<id>-"` right before claiming.
- GUIDE-108 only works on an Array[String]; `hints()` passes a PackedStringArray copy, so the game still repeats the
  practise advice -> GUIDE-108b (P0). New helpers that edit `out` must return the array.
- 00:15 curious trace (seed 43): forced drunk-bully fight at 2 in 100 (QA-139 -> ENC-009), untreated injuries (QA-128 up),
  a year-long stage while the better spot was cut (GUIDE-113), duplicate sell advice (GUIDE-114), armor hint ignored for
  6 months (QA-140 + new DESIGN question GEAR-001, which was referenced in earlier handoffs but missing from DESIGN.md).
- The owner's three urgent questions (pacing, first fights, ascension), RIVAL-019, ENC-008 and GEAR-001 are open.

## State on 2026-10-22 (planner, 22:15 UTC)
- 15 tasks landed (GUIDE-104/106/107/109, WU-287/288/289/290, C-188/189/194/197/198, QA-133/135); GUIDE-104 closed with
  no code change. Review 10th run (to 56b85f2) fixed GUIDE-109's plural itself; nothing filed; its notes became WU-292..294
  and a PERF-001 addendum. Live claims: GUIDE-108, WU-291, QA-137.
- 22:10 curious trace (seed 31): Escort Mortal Villagers is the only winnable mission m02-m12 and its cooldown reads as
  "too dangerous" -> GUIDE-110, C-200 (stag mission), C-201 (herb tithe), C-202; spar hint untaken 10 months -> GUIDE-112,
  QA-138, C-203. Also new: GUIDE-111 (deliver missions you are close to), ENC-008 (chance checks, DESIGN question added),
  WU-295 (bounty shot), WU-296 (inventory qi worth), C-204 (Talisman income).
- The armor hint ("Heavenforge Smithy in Fallen Star Market (10 days) sells Boar Hide Jerkin for 70 stones") stays m06-m12
  with 77-130 stones in hand: the open Qingshi-gear question covers it.
- The owner's three urgent questions (pacing, first fights, ascension), RIVAL-019 and the Qingshi-gear question are open.

## State on 2026-10-22 (planner, 20:15 UTC)
- 11 tasks landed (C-191, WU-283, WU-284, QA-130, GUIDE-101, GUIDE-102, WU-286, GUIDE-105, QA-132, GUIDE-103, C-195).
  C-186 closed without a commit (QA-130 found a sim policy bug, not a data cause). No new review (last reviewed 393b4e4).
  Live claims: GUIDE-106, WU-285, WU-287.
- 20:10 curious trace (seed 23, 12 months): "at a sect hall" while Qingshi has the Sect Recruitment Hall -> GUIDE-107;
  "Use your Spirit Herb" unused for 8 months -> GUIDE-109, C-199; duplicate practise advice -> GUIDE-108; open trial at
  70-98 in 100 never attempted by the sim -> QA-136; every fight near home is 100% from QR 7th layer -> C-197, C-198.
- Follow-ups filed: PERF-001 (NPC menus ~250 ms), QA-137 (slowest tests), QA-135 (crafter baselines after QA-130),
  WU-289 (road marker + HUD badge shots), WU-290 (--missions-shot), WU-291 (board marks the best mission).
- WU-283/284/286 skipped screenshots claiming "no display": xvfb-run works in the container; the command is now in WU-289/290.
- The owner's three urgent questions (pacing, first fights, ascension), RIVAL-019 and the Qingshi-gear question are open.

## State on 2026-10-22 (planner, 18:15 UTC)
- 17 tasks landed (GUIDE-093..100, WU-277, WU-281, WU-282, C-182, C-184, C-185, C-187, QA-131, QA-20261022-1). No new
  review since c18365f (last reviewed 275a886). Live claims: WU-284 (17:46), C-158 (17:52).
- 18:10 curious trace (seed 11, 12 months): the "Earn 440 more sect contribution" line stays 9 months while Azure Cloud
  has 7 QR missions worth 25-90 and the "missions ready" line is cut by the 5-hint limit -> GUIDE-102 (merge, name the
  best), QA-134, WU-288, C-194. QR9 idle line says "the next layer" -> GUIDE-103. Trial 0 in 100 at QR8 injured, 70 at
  QR9 healed -> QA-133 -> GUIDE-104. Odds everywhere a fight is offered: WU-286 (mission board, `UIStyle.odds_text`),
  WU-287 (bounty board, explore sites), C-189; new DESIGN question on what Appraisal then adds.
- QA-132: the unit suite takes ~11 min (fuzz file ~3.7 min); cut it without losing coverage.
- The owner's three urgent questions (pacing, first fights, ascension), RIVAL-019 and the Qingshi-gear question are open.

## State on 2026-10-22 (planner, 12:15 UTC)
- 10 tasks landed (QA-123, C-178, GUIDE-083, WU-267, GUIDE-084, WU-269, QA-122, WU-268, C-173, GUIDE-087). Review
  efde69a..157a41d (6d437be) fixed a clinic clause itself; nothing filed. Live claims: GUIDE-078 (08:40, 6h stale at
  14:40), GUIDE-085, GUIDE-086, QA-126.
- 12:10 curious trace (seed 5): the open-trial line reads "...sect hall. (it pays 6 stones a month)" -> GUIDE-089 (runs
  after GUIDE-085, same line). Internal Injury x0.7 carried for months with stones for the clinic -> GUIDE-091 (what
  waiting costs), QA-128 (does the sim heal), C-181. QA-122's stuck Array seeds -> QA-127 (sim follows the odd-jobs
  hint first; data change only if still stuck). GUIDE-088 -> GUIDE-090 (loot pays for the body manual too).
- World-ui: WU-272 (re-shoot labels after WU-269), WU-273 (--techniques-shot), WU-274 (techniques focus audit), WU-276
  (C-178 encounter shots) are ready; WU-270/271/241 wait on systems/content.
- The owner's three urgent questions (pacing, first fights, ascension), RIVAL-019 and the Qingshi-gear question are open.

## State on 2026-10-22 (planner, 10:15 UTC)
- 14 tasks landed (WU-260 (missed at 08:15), GUIDE-077, WU-264, GUIDE-082, WU-265, QA-121, WU-266, WU-258, WU-262, C-163,
  QA-119, C-172, GUIDE-081, CMB-011). Review fe1822e..efde69a (744890d) filed nothing. Live claims: GUIDE-078 (08:40),
  GUIDE-083, QA-123.
- 10:10 curious trace (seed 3, 12 months): sect trial open for 5 months with no odds -> GUIDE-085/087, C-180; practice
  hint never says what a level opens -> GUIDE-086, WU-270; ~238 stones of loot never become armor -> GUIDE-088; a
  non-spar 0% fight at QR3 -> QA-126. QA-121's Foundation gap -> QA-125 (which single lever matters). WU-262's edge
  labels -> WU-269. WU-271 shoots the new hints. C-177 and WU-267 are unblocked.
- World-ui has only 2 ready rows (WU-267, WU-269); the rest wait on this run's systems tasks.
- The owner's three urgent questions (pacing, first fights, ascension), RIVAL-019 and the Qingshi-gear question are open.

## State on 2026-10-22 (planner, 08:15 UTC)
- 12 tasks landed (GUIDE-073, GUIDE-075, C-171, GUIDE-074, GUIDE-080, GUIDE-076, QA-120, C-175, WU-257, WU-256, WU-263,
  C-170). No new review (last reviewed fe1822e). Live claims: WU-260, GUIDE-077, WU-264, GUIDE-078.
- C-163 has a stale claim branch (01:26) that the cleanup Action has not removed: it runs ~every 4h, not hourly, so
  workers may skip tasks with old branches. BACKLOG's C-163 row says to push a fresh claim.
- 08:15 curious first-hour trace (seed 8): Iron Fist stays level 1 for ~200 days although level 2 takes ~30 days of
  practice. New: GUIDE-081 (practice hint gives days), WU-267 (practise-to-next-level button), C-178 (training
  encounters), QA-123 (does the curious sim practise). Also GUIDE-082 (armor hint "fights: The" typo), GUIDE-083 (far-qi
  distance), GUIDE-084 (next sect rank's stipend), CMB-011 (enemy power_mult) -> C-177, C-179 (renown in more regions),
  WU-265/266 (WU-256/257 follow-up shots), WU-268, C-176, QA-124.
- The owner's three urgent questions (pacing, first fights, ascension), RIVAL-019 and the Qingshi-gear question are open.

## State on 2026-10-22 (planner, 04:15 UTC)
- 12 tasks landed (RV-QA-115, C-168, QA-113, WU-248, GUIDE-071, ENC-006, WU-250, QA-118, GUIDE-068, WU-249, C-157, WU-251).
  Review df910b9..147a890 fixed WU-244 itself; nothing filed (its two notes -> GUIDE-073, WU-254). Live claims: C-163 (2nd),
  GUIDE-069, GUIDE-070, QA-117.
- New gap: Qingshi sells no weapons or armor (gear is 10 days away). GUIDE-072 (nearest market in hints), WU-253 (map shows
  what each region sells), C-169 (help). Selling basic gear in Qingshi is added to the owner's C-009 question.
- CMB-010 spec'd from QA-113 (flat realm_training from Void Refinement up); QA-120 re-checks late fights after it.
- Also new: GUIDE-073 (hints quote shop prices), GUIDE-074 (empty fights list says why), C-167 spec'd, C-170, WU-252/240
  spec'd, WU-254, WU-255, QA-119.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-22 (planner, 02:15 UTC)
- 9 tasks landed since 00:10 (QA-112, WU-244, C-165, C-166, WU-243, GUIDE-066, GUIDE-067, WU-246, WU-247). No new review
  (last reviewed df910b9). Live claims: RV-QA-115, C-163, GUIDE-068, QA-113.
- New, first-hours "tell the player where": GUIDE-071 (where to heal), GUIDE-070 (fair fights sorted by pay, not ease),
  ENC-006 (`renown` encounter effect, C-166 Follow-up) -> C-167, C-168 (help: bought-only ingredients), WU-248 (defence tag
  text), WU-249 (repeated HUD log lines collapse), WU-250/251/252 (new encounters and hints on screen / gamepad), QA-117
  (crafter sim follows the buy hint), QA-118 (do road encounters fire).
- QA-112 Follow-up (TT lethal hunters 0% even at Peak) waits on QA-113 -> CMB-010.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-22 (planner, 00:10 UTC)
- 19 tasks landed since 10-17 04:10 (GUIDE-057, C-150, TT-001, WU-234, WU-237, PROF-015, QA-109, C-160, WU-238, WU-236,
  PROF-017, PROF-016, WU-239, QA-114, WU-242, C-161, GUIDE-062, GUIDE-065, C-156). Review df910b9 filed RV-QA-115 (refresh
  the stale balance baseline), on top. Live claim: QA-112.
- Refocused on the first hours: GUIDE-066 (where to buy a bought-only ingredient: Array/Talisman crafters stall without
  paper), GUIDE-068/069 (where to buy armor and a body art), WU-244 (shop marks upgrades), WU-243 (new hints fit), WU-246
  (first-hour screenshot pass at Steam Deck size), C-163 (cheaper first array), C-165 (defence help), C-166 (three early
  road encounters), QA-116 (does the curious player win at Foundation when it follows the hint). C-160's still-unwinnable
  rogue waits on QA-116's numbers. Also GUIDE-067 (GUIDE-062 follow-up), C-164 (Talisman sale cap), WU-247.
- Systems has 3 ready rows (GUIDE-066/067/068) plus 2 dependent; refill next run.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-17 (planner, 04:10 UTC)
- 14 tasks landed (WU-229, WU-228, QA-108, PROF-013, C-154, WU-231, WU-232, C-155, PROF-014, YEAR-011, QA-110, WU-235,
  GUIDE-060, WU-233). No new review entry (last reviewed 7144c97). Live claims: GUIDE-057 (QA-108 confirmed its trigger),
  TT-001, QA-109, C-150 (second try).
- New problem from the baseline: the curious player is mugged 35 times at 0% by the forced Roadside Rogue right after
  reaching Foundation (C-160 gates it a stage later; QA-114 diagnoses the weakness, GUIDE-065 waits on it).
- QA-110 follow-ups -> C-161 (min_stage on the Mahayana magistrate and four inheritance realm stages). C-154 found TT/Mahayana
  Peak win% far below QA-007's default -> QA-113 measures, CMB-010 applies. QA-112 = TT gates.
- Also new: PROF-015/016/017 (review notes on orders and margin text), GUIDE-062 (generic late goal ladders, after TT-001),
  WU-237 (double "the" in inheritance labels), WU-238/239/240/241/242.
- Systems has only 3 ready unclaimed rows (PROF-015/016/017) plus 3 dependent; refill next run.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-17 (planner, 02:10 UTC)
- 15 tasks landed (PROF-011 (missed at 00:10: the clone was shallow, run `git fetch --unshallow`), C-152, C-149, WU-227, WU-226, PROF-012, C-151, WU-225, GUIDE-059, WU-215, WU-230, C-153, MAHA-001,
  QA-20261017-1, WU-224). No new review entry (last reviewed f27406e). Live claims: WU-229, QA-108, C-150 (expiring).
- C-151 cut the quarry's iron weights (spec'd 6 made iron a money press: gatherer 3.17/day); gathered Blacksmith now 1.84/day.
- New theme "orders you can see coming": PROF-013 (lapse says what was short), PROF-014 (gathering days on an open order),
  YEAR-011 (year review counts orders), plus GUIDE-060 (scroll index, review note), C-156 (doubled Visceral Mending scroll,
  review note), C-157 (TT breakthrough pill), C-158 (TT inheritance), C-159 (help), WU-231..236. Spec'd: PROF-013, PROF-014,
  YEAR-011, GUIDE-060, WU-228, WU-231, WU-232, C-154, C-156, C-157, QA-110.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-17 (planner, 00:10 UTC)
- 15 tasks landed (WU-216, QA-106, WU-219, GUIDE-054, WU-221, GUIDE-055, WU-220, QA-107, WU-222, C-136, GUIDE-056, C-147, WU-223,
  PROF-010, C-148). No new review entry (last reviewed 1e438fc). Live claims: PROF-011, MAHA-001, C-150, WU-215, QA-20261017-1
  (a QA self-filed task: mass-noun plurals).
- QA-107: orders lapse because of the order (rare Iron Essence in Qingshi, an ingredient a region away), not the reward (~1.6x
  market) or the sim. New: PROF-012 (count fits gather rate, full spec), C-151 rewritten (Qingshi ore site), QA-111 re-runs orders.
- QA-106: three demonic-path hunters are forced fights at 3-31%; C-153 moves them a stage later (planner accepted QA's numbers).
- Also new: GUIDE-059 + WU-230 (plurals everywhere), GUIDE-057 (waits on QA-108), QA-109 (every craft's first year), WU-224..229,
  C-154/C-155 + TT-001 (Tribulation Transcendence content), QA-110.
- Systems has only 4 unclaimed rows (2 of them dependent); add more next run if PROF-012/GUIDE-059 land.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-16 (planner, 20:10 UTC)
- 15 tasks landed (YEAR-010, QA-101, WU-209/210/211/212/213, C-128, C-129, C-142, C-144, GUIDE-049, GUIDE-050, GUIDE-052,
  QA-103). No new review entry (last reviewed 5709257). Live claims: BI-001, GUIDE-051, QA-102.
- GUIDE-049 fixed QA-100's day-60 stall: a new Alchemist now ends month 6 with 262 stones (curious 69), but meditates 0% of
  days. QA-104 runs the crafter a full year (do they stall again at rank 2, how far behind is their cultivation).
- New: PROF-008 (rank-up says what it opens), PROF-009 (orders you can fill nearby), GUIDE-053, MAHA-001, WU-215..218,
  C-145..149, QA-104..106. Spec'd: PROF-008, PROF-009, GUIDE-053, WU-214, WU-218, C-146, C-145, C-143, QA-104, QA-105.
- Professions vs gathering: plain gathering (2.24/day) still beats every craft; QA-105 finds out why before anyone retunes.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-16 (planner, 18:10 UTC)
- 14 tasks landed (GUIDE-048, PROF-007, RIVAL-020, GUIDE-047, WU-195, PROF-004, WU-201, WU-207, WU-208, C-137, C-141, QA-094,
  QA-100, plus C-140 done by the reviewer's help fix). Review e0dd610..5709257: nothing filed; notes -> GUIDE-050/051, WU-209.
  Live claims: C-128, YEAR-010, QA-101.
- Biggest first-hours finding: QA-100's new Alchemist stops earning at ~day 60 because the herb hint fades after 5 crafts.
  GUIDE-049 (fade by rank), GUIDE-052 (orders name the missing ingredient), C-144 (a rank-1 next recipe per craft), QA-102.
- Planner call: bought-ingredient first recipes losing a little is intended (gathering + commissions are the loop).
- QA-103 bisects the curious QR9 slowdown (476 -> 577 days) found by QA-094.
- The owner's three urgent questions (pacing, first fights, ascension) and RIVAL-019 are still open.

## State on 2026-10-16 (planner, 14:10 UTC)
- 13 tasks landed (YEAR-009, C-134, QA-097, GUIDE-044, C-133, WU-202, RENOWN-007, GUIDE-042, INH-006, QA-087, WU-203, C-125,
  WU-199). No new review entry (last reviewed e673015). Live claims: WU-195 (3h old), WU-200, C-135, QA-098.
- QA-097: crafting from shop-bought ingredients loses money for 4 of 5 crafts; gathered, Alchemist/Beast Tamer/Talisman beat sect
  missions but nothing beats plain gathering (2.24/day); Array Master loses either way. New: PROF-005 (stones in material value),
  C-137 (array pays), PROF-004 unblocked and spec'd, GUIDE-047, QA-100 (a new Alchemist's first six months), QA-101.
- PROF-006 lets `min_profession` 0 mean "practises it" so C-134's first-hours choices open to a fresh Apprentice; C-138 adds the
  Beast Tamer's. RIVAL-018 + owner question RIVAL-019 (the rival runs a realm ahead from month ~12).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-16 (planner, 10:10 UTC)
- 15 tasks landed (RENOWN-006, QA-095, WU-188, C-130, WU-192, QA-086, GUIDE-038, WU-191, C-126, GUIDE-040, QA-093, WU-180,
  WU-181, INH-005, and C-122 which landed before the 08:10 plan but was still listed). Review 26efd67..9206be9: nothing filed;
  its two notes became WU-194 and WU-197. Live claims: EPI-003, WU-190, C-123, C-127, QA-094 (07:05).
- The deadly first years look fixed (QA-095: no curious seed ends early in 36 months). Seed 7 still stalls 23 months at QR7
  (QA-096 traces it).
- New theme "professions pay" from QA-093: in-game only the Doctor can "Work" (crafting professions craft instead), and four
  alchemist recipes at rank 0-1 sell for less than their herbs cost. C-131 / C-132 (data), PROF-003 + WU-195 (show the
  numbers), YEAR-008, GUIDE-042, QA-097. QA-093's integer-truncation note is unreachable in game (work is always a month).
- QA-086: a meditate-only newcomer gets up to 60 quiet days; GUIDE-041 moves "try something new" from day 180 to 60.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-16 (planner, 06:10 UTC)
- 14 tasks landed (QA-084, WU-182, C-118/119, WU-185, C-116, RENOWN-004, INH-004, QA-092, WU-183, C-103, SOUL-002, C-117,
  YEAR-006). No new review entry (last reviewed 50042bb). Live claims: GRAT-002, WU-186, QA-091; GUIDE-036 / WU-180 / WU-181
  claims (02:06-03:16) expire with the 4h cleanup.
- New: VOID-001 (spec), RENOWN-005 (spec), YEAR-007, INH-005, WU-187 (spec), WU-188, WU-189 (spec), C-121 (spec), C-122..125,
  QA-093 (spec), QA-094. Re-spec'd with numbers: C-102 (QA-084's table), C-120 (RENOWN-004 is on main).
- Worth watching: QA-084 found profession *work* pays ~3 stones a week (work_income 5-7 x (rank+1) per month) against
  12-54 for one sect mission; QA-093 measures crafting and commissions too before anyone retunes. Professions are a pillar.
- QA-091 (claimed) decides whether the deadly first years are the sim being reckless or a real balance problem; if lethal
  "Weak"-rated foes kill often, that becomes an owner question.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-16 (planner, 04:10 UTC)
- 13 tasks landed (GUIDE-037, SOUL-001, INH-003, GRAT-001, YEAR-005, WU-178/179, C-106, C-113..115, QA-089/090). Review
  ac172f8..50042bb: the reviewer reworded C-115's bitter cairn, nothing filed. Live claims: GUIDE-036, QA-084, WU-158,
  WU-180..182 (WU-158's 20:10 branch is past the 4h cleanup).
- New: RENOWN-004, INH-004, SOUL-002, YEAR-006, GRAT-002, VOID-001 (after C-118/119), WU-183..186, C-118..120, QA-091/092.
  Spec'd: RENOWN-004, INH-004, SOUL-002, YEAR-006, WU-185, C-116, C-118, QA-091.
- Biggest first-years worry: the three-curious-years baseline has 20 artifact deaths in 10 seeds x 36 months, two seeds empty
  by age 18-21, mostly Mist Wolf sect missions and a Drunk Bully rated 98-100%. QA-091 finds out whether that is the sim
  being reckless, a rating mismatch, or a real balance problem. If deaths to heavily favoured lethal foes are real volume,
  that becomes an owner question (should a "Weak" lethal foe be able to kill you?).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-16 (planner, 02:10 UTC)
- 15 tasks landed (YEAR-004, EPI-002, INH-002, NS-007, WU-171..177, C-110..112, QA-088); RIVAL-017 marked done (the reviewer's
  07e4932 already keeps the bout record per rival). Review fccc922..ac172f8: no defects. Live claims: GUIDE-036, QA-089, WU-158,
  and two RIVAL-017 claims that should stand down.
- New: SOUL-001 (spec'd), INH-003, GRAT-001, YEAR-005, GUIDE-037, WU-178..182, C-114..117, QA-090. Spec'd: SOUL-001, INH-003,
  GRAT-001, WU-178, WU-179, C-113, C-114, C-115.
- Gratitude and grudges (karma ledgers) had no UI at all; GRAT-001/WU-178/C-116 surface them.
- WU-175's "edge labels" are objects at the camera edge while scrolling; not a bug, not filed.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-16 (planner, 00:10 UTC)
- 16 tasks landed (GUIDE-032..035, RIVAL-016, EFF-004, WU-165..167, WU-169/170, C-105, C-108, C-109, QA-071, QA-083).
  Live claims: NS-007, WU-171, C-107; WU-158's 20:10 claim expires with the 4h cleanup. No new review entry (last reviewed b2343fc).
- New: YEAR-004, EPI-002, INH-002, RIVAL-017, GUIDE-036, SOUL-001, WU-172..177, C-110..113, QA-088/089. Spec'd: YEAR-004,
  EPI-002, INH-002, RIVAL-017, WU-173/174/175, C-110/111, QA-088.
- QA-083: a player who neither fights nor befriends the rival keeps a proud rival forever; left as is (proud is the default mood).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 22:10 UTC)
- 18 tasks landed (RIVAL-012/014/015, CORE-001, FOUND-007, GUIDE-031, WU-160..164, C-098..101, C-104, QA-082, QA-085).
  RIVAL-015's code landed in 911d1e3 under the subject "fixup spacing" (marker commit b2343fc). Live claims (< 2h): GUIDE-032,
  GUIDE-033, WU-158, QA-083. No new review entry since 18:04 (last reviewed 9740f37).
- New: GUIDE-034/035, RIVAL-016, EFF-004, NS-007, WU-165..167, WU-169..171, C-105..108, QA-086/087. Spec'd: GUIDE-034,
  RIVAL-016, WU-165, WU-167, C-105, C-106, QA-086. QA-085: the WU-157 boar defeat shot was staged, ratings are honest.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 18:10 UTC)
- 21 tasks landed (FOUND-004/005, GUIDE-029/030, CHOICE-003, RIVAL-009/010/011, WU-148..153, C-090/091/092/094/096,
  QA-078/079). Live claim: QA-080 (18:03). Reviewer last reviewed ea1a53f; it fixed the HUD goal banner and WU-148's stale
  line, nothing filed.
- New: FOUND-006, EFF-003, RIVAL-012/013/014, CORE-001, WU-154..159, C-098..101, QA-082/083. Spec'd: FOUND-006, EFF-003,
  RIVAL-012/013, CORE-001, WU-154/155/157, C-093/097, QA-081/082. New DESIGN question RIVAL-014 (successor rival, default built).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 16:10 UTC)
- 16 tasks landed (RIVAL-007/008, CHOICE-002, C-062/085/087/088/089, WU-144..147, QA-075/076; QA-077 answered in QA-076,
  QA-073 already met at 408 s). Live claims: GUIDE-029, GUIDE-030, FOUND-004, WU-148, C-090, QA-078 (all < 1h), QA-071 (12:16,
  expires with the 4h cleanup). Reviewer last reviewed b54040f; nothing filed, its note is WU-150.
- New: RIVAL-009/010/011, FOUND-005, CHOICE-003, WU-150..153, C-092..097, QA-079..081. Spec'd: FOUND-005, RIVAL-009,
  CHOICE-003, RIVAL-011, WU-149/150/152, C-091/092/094/096, QA-079.
- The owner's three urgent questions (pacing, first fights, ascension) are still open; F-005 note gained QA-076's result.

## State on 2026-10-15 (planner, 14:10 UTC)
- 17 tasks landed (RIVAL-005/006, FOUND-003, CHOICE-001, GUIDE-027/028, WU-132/136/137/140/141/142/143, C-065, C-083,
  QA-072, QA-074). Live claims, all < 2h: C-085, QA-071, QA-073, QA-075. Reviewer last reviewed 911fc1e; its 18th-run
  note 1 is RIVAL-007, note 2 is C-088 (now spec'd).
- Systems and world-ui had no todo left. New: RIVAL-007/008, CHOICE-002, GUIDE-029/030, FOUND-004, WU-144..149,
  C-090/091, QA-076..078. Spec'd: RIVAL-007, CHOICE-002, GUIDE-029, WU-144/145/147, C-087/088/089, QA-076/077.
- QA-072: with saving, 6 of 10 sim players afford the Foundation pill; QA-076 checks whether waiting closes the rest.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 12:10 UTC)
- 8 tasks landed (RIVAL-004, PERF-001, WU-125, WU-138, WU-139, C-082, C-086, QA-070). Live claims, all < 2h: WU-137,
  QA-074, FOUND-003, WU-140, C-065. Reviewer last reviewed 039470a; its 16th-run notes are QA-074 and WU-142 (pill price
  vs stones held; the price itself stays with the owner's pacing question).
- New: CHOICE-001 (choice needs an attribute) + C-088, GUIDE-028 (fair_fights rated only the first nearby bounty), WU-141
  (rival Look), WU-142 (stones vs pill price), WU-143 (rival map mark), C-087 (rival at Foundation), C-089 (help pages),
  QA-075 (sim takes chore fights). Spec'd: RIVAL-005/006, GUIDE-027, WU-132/136, C-083/085, QA-071.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 10:10 UTC)
- 12 tasks landed (DLG-001, GUIDE-026, FOUND-002, RIVAL-003, WU-129, WU-134, C-063, C-077, C-084, QA-066/068/069); QA-057
  closed as not needed. Live claims: WU-125 (09:46), QA-070 (10:06). Reviewer last reviewed f36edce; nothing filed.
- **Process bug found:** the container's local `main` is a stale 2026-10-09 snapshot (depth-50 shallow clone, "diverged
  50/50"), so `git pull` fails and workers read an old BACKLOG: in the last hour they claimed 7 tasks done days ago
  (GIFT-002, FEST-004, RUMOR-002, EFF-001, C-069, SECRET-003, LETTER-005). The shallow clone also hides old `[ID]` commits
  from the "not done" grep. CLAUDE.md's worker loop now starts from `origin/main` (detached) and checks the Done table.
- New: FOUND-003 spec'd (QA-066 met its condition), PERF-001 re-spec'd from QA-068's numbers, GUIDE-027 (20 vs 40
  samples), RIVAL-005/006, WU-139 (sheet hides the rival before the meeting), WU-140, QA-072 (sim buys the Foundation
  pill), QA-073 (fuzz files, suite < 420 s). RIVAL-004, WU-137, WU-138, C-086 are unblocked.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 08:10 UTC)
- 8 tasks landed (GUIDE-023/024, FOUND-001, WU-126/133/135, C-081, QA-067); C-079 closed as not needed (C-081's run measured
  both first-inheritance fights fair at layer 1). Claimed (< 5h): GUIDE-026, FOUND-002, WU-125, WU-129 (2nd claim 07:46),
  C-063, C-065, C-077, QA-068. Reviewer last reviewed 111cd0a and filed nothing; its notes became DLG-001 and QA-071.
- Local clone was shallow and looked diverged; `git fetch --unshallow` showed it was simply behind; fast-forwarded.
- New: RIVAL-003 (spec file: the named rival is never introduced, so a first meeting around day 10), RIVAL-004 (journal),
  WU-138 (rival label in the world), C-086 (first-year rival encounters); C-084 realm descriptions + WU-137 realm card;
  DLG-001 (Elder Mo practise line for any style); FOUND-003 (conditional on QA-066); C-085 (bounty guard test); QA-070
  (curious sim takes bounties), QA-071 (inheritance baseline refresh). WU-133's missing screenshot check folded into WU-132.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 06:10 UTC)
- 13 tasks landed (GUIDE-020/021, INH-001, EFF-002, MENTOR-004, RUMOR-003, WU-127/130/131, C-078/080, QA-064/065).
  Claimed (all < 4h): GUIDE-023, GUIDE-024, WU-125, WU-126, WU-129, C-063 (4th claim), C-065. Reviewer last reviewed 5329c38.
- Local main had diverged from origin again (50/50, PR-era history); reset to origin/main.
- New theme "the road to Foundation": FOUND-001 (save for the pill), FOUND-002 (risk text), WU-134 (breakthrough window,
  spec file), WU-135 (lifespan/qi gain on success), WU-133 (wider shop list), WU-136. GUIDE-026 (open chore fights in
  fair_fights, from QA-065), C-082 (attribute +1 encounters, from QA-064), C-083 help pages, QA-068 (test.sh speed, qa
  top), QA-069, PERF-001 (after QA-068). QA-066's numbers should drive the next balance tasks.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 04:10 UTC)
- 11 tasks landed (MENTOR-003, LETTER-006, REF-001, GUIDE-019b, WU-120/123/124, C-070/075, QA-044/063). Claimed (< 2h):
  GUIDE-020, GUIDE-021, INH-001, WU-126, WU-129, C-065. C-063's third claim (23:25) is an empty branch; the row is now a
  test-first one-step task. Reviewer last reviewed e922009.
- QA-063: first win ~day 14 for both sims; QA-044: pointers modest. New: MENTOR-004 spec'd, RUMOR-003, GUIDE-023/024,
  WU-130/131/132, C-080/081, QA-065/066/067. Next theme candidate: the first Foundation breakthrough (QA-066 measures it).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 02:10 UTC)
- 11 tasks landed (GUIDE-019, FEST-005, LOG-001, WU-116/117/118/119, C-072/074/076, QA-062). Claimed (all < 3h): MENTOR-003,
  LETTER-006, REF-001, WU-123, C-063 (23:25, its third claim), C-070. Reviewer (to e922009) fixed Elder Mo's line and added
  `Techniques.knows_kind`; its notes became GUIDE-019b and WU-124.
- New theme "from a style to a win": GUIDE-020 (practise hint, first goal), GUIDE-021 (spec file, journal "Fights you can
  win") + WU-125, EFF-002 (`practice_days` effect) + C-077, INH-001 (inheritance `min_stage`) + C-079 + WU-129, WU-124
  (banners wait for the combat report), WU-126/127, C-078, MENTOR-004 (after QA-044), QA-063/064.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-15 (planner, 00:10 UTC)
- 18 tasks landed since the last plan (GIFT-002, FEST-004, RUMOR-002, EFF-001, SECRET-003, LETTER-005, QI-002, MENTOR-002,
  WU-102/109/111/112/114/115, C-068/069, QA-059/060). C-071 closed (MENTOR-002 did the data change). Claimed: C-063, QA-061.
  A stale `claude/RUMOR-002-*` claim exists although RUMOR-002 is on main (the backlog still listed it); harmless.
- Reviewer (to 597d486) filed nothing; notes became WU-117 and FEST-005.
- Theme "your first fighting style": the curious player never learns a combat technique, so pointers refuse and Mist Wolf
  fights are bare (0% vs 81-99% with Iron Fist + Stone Skin). Iron Fist is 15 stones at the Wandering Merchant, but the
  only hint vanishes once Elder Mo teaches breathing. GUIDE-019 (spec file) + MENTOR-003, WU-118/119/120, C-072, QA-062.
- The owner's three urgent questions (pacing, first fights, ascension) are still open; C-009 has an update with the
  default now being built (keep enemies, surface the manual).

## State on 2026-10-09 (planner, 20:10 UTC)
- 17 tasks landed since 18:10 (LETTER-002/003b, SHOP-001, RUMOR-001, QI-001, WU-100/103/106/107/108/110, C-061/064/066/067,
  QA-048/058). Claimed: GIFT-002, FEST-004, C-068, QA-059 (all < 1h). Reviewer (to 51025b4) filed no P0; its notes became
  RUMOR-002, EFF-001, LETTER-005, QI-002, QA-061.
- QA-048: months 13-36 bring nothing new for 9/10 curious players, pointers never fire, Mist Wolf mission still the only
  killer. Found while planning: the Peach Blossom Grotto (Qingshi, QR only) opens on days 0-45, while the player is still
  a Mortal, and next in year 3; C-069 moves it to year 2 and adds a year-2 inheritance. C-063 slimmed after two expired claims.
- Local main had diverged from origin again (50/50, PR-era history); reset to origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 18:10 UTC)
- 13 tasks landed since 16:15 (DANGER-001, LETTER-003, NEWS-003, WU-095/099/101/104/105, C-058/059/060, QA-053b, QA-056).
  Claimed: FEST-003, SHOP-001, C-064, QA-048 (all < 1h). C-063's 14:27 claim never landed (expires at 18:27, then free).
- Reviewer (to 3108c18) filed no P0; its notes became LETTER-003b, GIFT-002, FEST-004, WU-106/107/108, QA-058.
- New theme "the world talks back": RUMOR-001 (spec file) + C-067, QI-001 (spec file) + C-068 + WU-109, C-066 (request
  letters), WU-110 (letters on the map), QA-059 (log-noise sim).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 16:15 UTC)
- 17 tasks landed since 14:15 (BOUNTY-002, GIFT-001, FEST-002, RENOWN-003, NEWS-002, YEAR-003, WU-088/089/091/092/093/094/
  096/097, C-051/053, QA-055). Claimed: C-063 (14:27), QA-053b (16:02). Reviewer last reviewed 7950f03 and filed nothing.
- The local clone's main had diverged from origin (an old PR-era history); the planner reset it to origin/main. Workers
  should `git fetch && git reset --hard origin/main` if `git pull` complains about divergent branches on a fresh clone.
- QA-055: the board's odds are honest; the Mist Wolf deaths were real 30-43% losses on fights rated "Even". DANGER-001
  (systems top) adds a "Risky" rating for 50-70%.
- New theme "people write, ask and celebrate with you": LETTER-003 (spec file) + WU-099, LETTER-002, SHOP-001 + WU-102,
  NEWS-003, FEST-003 (spec file) + WU-100 + C-065. World-ui ready now: WU-095, WU-101, WU-103, WU-104, WU-105. QA-056/057 added.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 14:15 UTC)
- 12 tasks landed since 12:20 (MISS-001, RENOWN-002, GUIDE-018, MAT-001, WU-081/084/086/090, C-046/050/052/055).
  QA-054 landed during the run (0 of 10 curious seeds die for good now). Claimed: WU-088 (13:17), WU-091 (14:17).
- QA-054 Follow-up: the remaining deaths are the Mist Wolf mission rated "Even" (>= 50%) but lost at 18-35%:
  QA-055 (qa top) finds why `Combat.win_chance` disagrees with the real fight. Reviewer (to 7950f03) fixed two small things, filed nothing.
- C-052 put 11 bounties in data, but `Bounties.offers` lists the first 3 eligible in data order on every board, so most
  never show: BOUNTY-002 (local and nearby first) is the systems top task, WU-092 shows distance.
- QA-052 Follow-up 1 is C-063: raise the Mist Wolf mission's `min_stage` until it is a fair fight (no enemy stat changes
  while C-009 is open). C-064 takes C-052's bounty follow-ups.
- New theme "your name opens doors": RENOWN-003 (bounty pay), NEWS-002 (greetings by title), WU-094 (renowned requests
  look special), YEAR-003 (year review counts adventures). Also WU-093 (screenshot the week's screens), WU-095 (lives on
  the HUD), WU-096 (respawn screen names the odds and the recharge price), WU-097 (festival stalls drawn in the world).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 12:20 UTC)
- 17 tasks landed since 10:15 (TRAV-006/007, LETTER-001, RENOWN-001, NEWS-001, GUIDE-017, WU-074/080/082/083/087,
  C-047/048/057, QA-032/052, QA-053 part 1). Someone fixed conflict markers TRAV-006 left in main (c49865e).
  Claimed: EXPL-003, WU-086 (< 30 min), C-046 (again, 11:27; its first claim never landed either).
  Reviewer last reviewed c1080aa and filed nothing.
- QA-052: every early curious-player death is the Mist Wolf mission retried at 18-35% right after respawning.
  MISS-001 (lost mission cools down 7 days, recorded) + WU-088 (board says so) + QA-054 (sim policy) address it.
  QA-053 parts 2-3 moved to QA-053b.
- New theme "people and places you can please": GIFT-001 + C-058 + WU-089 (gift likes/dislikes), FEST-002 + C-061
  (festival stalls), RENOWN-002 + C-062 (requests for the renowned), GUIDE-018 (recap names hunt/letter/renown),
  WU-090 (mastery on the map), WU-091 (HUD crowding with everything on), C-059 (more maps), C-060 (second deep path).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 10:15 UTC)
- 13 tasks landed since 08:15 (WE-002, GUIDE-015/016, EXPL-002, MS-005, BOUNTY-001, WU-072/076/078/079, C-045, QA-049/051).
  Claimed: TRAV-006, LETTER-001, WU-077, C-048, QA-032 (all < 1h). C-046 (05:26) and WU-074 (06:46) claims never landed;
  their rows say the claim expired. Reviewer last reviewed 4319bc4 and filed nothing.
- QA-049 skipped its part (4) (sims write saves, so test.sh + balance.sh can't run together): moved into QA-053.
- QA-041's baseline shows 2 of 10 curious players dead before month 36: QA-052 investigates, WU-086 warns before a fight
  with an empty artifact.
- New theme "being known and growing stronger shows": RENOWN-001 (spec file) + WU-084, NEWS-001, TRAV-007 (flying sword,
  after TRAV-006), EXPL-003 (region mastery), WU-082 (hunt on the HUD), GUIDE-017 + WU-083 (craftable now), C-057 (a
  secret realm that needs a map), QA-053 (bounty economics, baseline refresh), MAT-001. C-055 widened to the newest features.
- Added an open question: infamy for demonic acts in a region (RENOWN-001 only builds renown).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 08:15 UTC)
- 10 tasks landed since 06:20 (ENC-003, EXPL-001, WU-061/070/073/075, C-018/049, QA-046/050). Claimed: WE-002,
  GUIDE-015, C-046 (3h old), WU-074 (claimed before its dependency EXPL-002 exists; it may land partially). Reviewer (to
  4319bc4) fixed three small things in one commit and filed nothing.
- C-049's Bog Lily recipe scroll has no source: QA-051 adds a recipe-scroll obtainability test and fixes the gaps.
- New theme "a target and a payoff for exploring": GUIDE-016 + WU-078 (deeper paths announce themselves and are found),
  BOUNTY-001 (spec file) + WU-076 + C-052, TRAV-006 + C-051 + WU-080 (road encounters), LETTER-001 + C-053 + WU-081
  (letters from friends), WU-077 (first-hour screenshot pass at 1280x800), WU-079 (focus audit), C-055 (help pages).
- Local `main` was again diverged from origin/main (50/50); the planner worked on a branch made from origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 06:20 UTC)
- 16 tasks landed since 04:15 (REALM-002, WU-067/068/069/071, C-043/044, NS-007, QA-041/047, ITEM-002, GUIDE-014,
  SEASON-002/003, TRAV-004/005). Claimed: WU-070, QA-046, C-046. Reviewer (to e7f99aa) filed nothing.
- QA-041: from month 7 the curious sim only explores and runs missions, but its policy never crafts/travels/gifts, so
  QA-048 teaches it before we trust that. NS-007 says the first-hour section of tools/balance.sh took >35 min: QA-049.
- New theme "the long middle": ENC-003 (met encounters fade), EXPL-001/C-048 (deeper paths after N explore days),
  WE-002/C-047/WU-072 (festivals with a favor bonus), GUIDE-015/C-050 (discovery rumors), EXPL-002/WU-074 (region
  progress), MS-005, WU-073 (undiscovered mark), WU-075 (herb seasons in the inventory), C-049 (high-region seasons).
- Local `main` was a shallow clone that looked diverged; `git fetch --unshallow` fixed it (no reset needed).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 04:15 UTC)
- 14 tasks landed since the last planner run (GUIDE-012/013, RV-014, SEASON-001, TRAV-002/003, NS-006, WU-060/063/065/066, C-038/042,
  QA-039). REALM-002, WU-064 and QA-041 are claimed (~04:00). The reviewer's last run (to d098150) filed nothing.
- New theme: reward curiosity about places (GUIDE-014 unexplored roads, TRAV-005 + C-046 + WU-070 a discovery on the first
  exploration of each region, TRAV-004 sect home regions, WU-061 spec'd, QA-047 save/load check) and seasons worth noticing
  (SEASON-002 "in season now", SEASON-003 milestone, WU-067 spec'd, WU-071, C-044 spec'd). WU-068 (ChoiceMenu refit on
  resize, reviewer note), WU-069 (look at the breakthrough effect), C-045 (gear past Core Formation, NS-006 Follow-up),
  QA-045 (why the first Foundation year is so gentle, QA-039 Follow-up), QA-046 (refresh the drifted baseline).
- Local `main` had diverged from origin/main again (old PR-era history); reset to origin/main (backup branch kept locally).
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 10:10 UTC)
- 14 tasks landed since 00:15 (WU-044/045/054/059/062, C-037/039/040/041, RV-013, MENTOR-001, SPAR-001, TRAV-001, QA-043).
  GUIDE-012, QA-040 and WU-061 are claimed.
- New: RV-014 (reviewer notes: spars burn no talismans and drain no lifespan; pointers "share" only a technique the senior
  knows better), TRAV-002/003 + WU-064 + C-043 (first sight of a region, backfilled visits for old saves), ITEM-002
  (`Items.has_known_source`, QA-043 Follow-up), WU-063 (breakthrough effect), WU-065 (Deck pass), WU-066 (spar report),
  WU-067 + C-044 (seasonal herbs, after SEASON-001), C-042 (corpse refiner fight, C-037 Follow-up), QA-044 (do pointers
  and spars matter?). C-039's Follow-up (a bare player is 0% vs Foundation foes) needs no task: nobody reaches Foundation bare.
- Local `main` had diverged from origin/main again (old squash history); reset to origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-09 (planner, 00:15 UTC)
- 13 tasks landed since 22:15 (QA-029, SECT-004/005, WU-056/057/058, C-031, C-035, C-020, QA-038, RV-012, GUIDE-011,
  KARMA-001). The systems queue was empty. QA-021 is claimed (00:00).
- New theme: people you learn from (MENTOR-001 pointers, SPAR-001 spars; specs in docs/specs; UI WU-059, hints GUIDE-012,
  audit QA-040), visited regions (TRAV-001, WU-061), seasons (SEASON-001 seasonal herbs, WU-060 tint check, WU-062 season
  banner), lecture surfacing (GUIDE-013, C-041), reviewer notes as RV-013 (year review names the year that ended, "+0 qi"
  lecture line, core no longer reads src/world), C-039 (fair Foundation fights in the 3 starter regions), C-040 (rank
  `min_stage` for two HARD trials), REALM-002 (secret realm entry item), QA-041 (36-month curious sim), QA-042 (Core year sim).
- Local `main` was again unrelated to origin/main (shallow clone); reset to origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 20:15 UTC)
- 18 tasks landed since 18:15 (CMB-002, WU-036/039..043, C-022/023, GUIDE-008/009, GOAL-002/003, MSG-002, REL-011, QA-020/033/036).
  CMB-003 and C-024 are claimed (~20:04 / 19:26).
- New: RV-010/RV-011/MSG-003/CMB-004/YEAR-002 from the reviewer's notes, GOAL-004 (profession goal), GUIDE-010 (new roads
  notice); WU-044 (HUD goal line), WU-045 (inventory "sells at / used in"), WU-046/047 (hit sounds, line colors after CMB-003),
  WU-048..050, WU-053; C-025 (recipes for unused beast materials), C-028 (help: fights, selling), C-029 (quiet-day lines),
  C-030 (milestones); QA-037 (combat text audit), QA-038 (shop fuzz).
- Local `main` was again unrelated to origin/main; planner worked on a branch made from origin/main.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 18:15 UTC)
- 15 tasks landed since 16:20 (FH-030, CULT-001, MSG-001, STAT-002, WU-032..035, WU-037, WU-038, ECON-001b, C-016, C-019,
  C-021, QA-034). The first-hour audit's fix list is complete. CMB-002 and QA-033 are claimed (~18:05).
- New theme: fights with flavor (CMB-003, WU-043 spoils, WU-036 playback), loot worth money (C-023 beast materials,
  GUIDE-009 sell hint, WU-039 shop tabs, WU-040 sell all), goals past the first hour (GOAL-002 breakthrough odds in the
  journal, GOAL-003 mid-game goals, WU-041 days-to-next-layer on the HUD), fair gates (C-024: Foundation trials, the
  tournament_bout ring at QR1 vs a QR6 foe, vengeful_brother), MSG-002, QA-035 (economy sim monthly sect), QA-036.
- QA-029 (curious-player sim) is now the QA worker's top task: its Follow-ups should drive the next first-hour fixes.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 16:20 UTC)
- 16 tasks landed since 14:15 (CMB-001, BT-001, MED-001, EXP-001, YEAR-001, GUIDE-007, WU-024/027/028/029/030/031, C-017,
  RV-009, QA-028, QA-030). The "say what an action will do" theme is complete. ECON-001b is claimed (16:09).
- A first-hour audit found: the first sect hint points a mortal at the Blood Lotus Sect (the only sect that takes mortals),
  the technique hint at a manual a newcomer can't afford, no clear first goal, no confirms on leave sect / feed artifact /
  burn-lifespan pills, the Qingshi merchant buys nothing, and raw numbers in grudge/favor/alignment messages.
- New: FH-030 (spec), CULT-001, MSG-001, STAT-002, CMB-002, GUIDE-008; WU-032 (spec), WU-033..038; C-019 (spec), C-020..022;
  QA-033, QA-034.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 14:15 UTC)
- 14 tasks landed since 12:20 (GUIDE-004/005/006, RECAP-001 + WU-025, MS-004, WU-021/022/023/026, C-015, NS-002b, NS-004,
  QA-031). Systems and world-ui queues were empty again; restocked around one theme: say what an action will do before the
  player picks it (BT-001 breakthrough odds, MED-001 meditation preview, EXP-001 explore outlook, all shown via WU-027's
  ChoiceMenu `description` in WU-029/WU-030), plus WU-028 (hide HUD behind modals), YEAR-001 + WU-031 (yearly recap),
  GUIDE-007 (untried features), C-016/C-017/C-018, QA-032.
- RV-009 has a WIP branch (claimed 10:26, never landed); the row tells the next content worker to start from d814d2d.
- origin/main history was rewritten at some point: a fresh clone's local `main` can be unrelated to origin/main. Reset to
  origin/main (`git reset --hard origin/main` on a clean tree) before working.
- The owner's three urgent questions (pacing, first fights, ascension) are still open.

## State on 2026-10-08 (planner, 12:20 UTC)
- 17 tasks landed since 10:20 (RV-005b/006, ENC-002 + C-014 min_stage gating, GUIDE-003, MS-003, PROF-002, SF-002, C-013,
  QA-027, REL-005 export presets, WU-015..020). Systems and world-ui queues were empty again; restocked.
- RV-009 (gathering trips come back empty) is still unclaimed and stays the content worker's top task.
- New: C-015 (fair fights where they appear, spec; supersedes QA-007f), MS-004 (backfill veteran milestone counters),
  GUIDE-005 (outgrown cultivation method hint), CMB-001 + WU-024 (why you lost), WU-021 (screenshot every screen, spec),
  WU-022 (gamepad-readable disabled reasons), WU-023 (NPC labels vs places), GUIDE-004/006, RECAP-001 + WU-025, WU-026
  (text size), REL-011 (Steam upload prep), QA-030 (mid-game fuzz), QA-031 (save round-trip soak).
- Workers can now run fast: keep >= 6 per role. The owner's three urgent questions (pacing, first fights, ascension) are
  still open.

## State on 2026-10-08 (planner, 10:20 UTC)
- 21 tasks landed since 06:15 (RV-001/004/005/007, PROF-001 + WU-013 commissions, C-011 errands, C-012, LW-002c, ART-008,
  WE-001, WU-010..014, NS-005, QA-024..026, QA-007g, ECON-001). Systems and world-ui queues had run dry; restocked.
- New: ENC-002 (encounter `min_stage`, sim measures missions at their real gate) -> C-014 (gate the 0-14% Qi Refining
  cliff); GUIDE-003 (journal Opportunities + Errands, spec), RV-005b (herb bonus no longer blocks the realm pill), SF-002,
  PROF-002, MS-003; WU-015 (journal on the gamepad's left trigger), WU-016..020; QA-027 (sim covers realm/inheritance/
  event foes), QA-028, QA-029 (a "curious player" first-hour sim); C-013 help pages, ECON-001b, NS-007.
- RV-009 (gathering trips come back empty ~50-88%) is the content worker's top task.

## State on 2026-10-08 (planner, 06:15 UTC)
- 20 tasks landed since 04:15 (journal, milestones UI/progress, epilogue, music, title art, sect clashes, NS-003 region,
  RV-002/RV-003...). Reviewer fixes RV-001, RV-004..RV-007 are on top.
- New "playable and fun" group: PROF-001 (crafting commissions, spec in docs/specs/PROF-001.md) + WU-013 (its UI), C-011
  (favor errands in named NPCs' dialogue), C-012 (workshops in 3 more regions, beast tide defence), LW-002c (sect call
  deadline), ART-008 (appraisal shows win %), WE-001, WU-010..014, QA-026.
- RV-008 done: .github/workflows/cleanup-claims.yml is on main (hourly), the script only deletes stale *claim* branches, and
  workers rebase with `--force-rebase` so empty claim commits stop landing.
- New open questions in DESIGN.md: (RV-005) one breakthrough pill per attempt, (PROF-001) lapsed commissions.

## State on 2026-10-08 (planner, 04:15 UTC)
- 13 more tasks landed (FH-024/025, WU-001..003, STAT-001, GOAL-001, REL-007, REL-009, QA-019, NS-001/002, LW-003b). The
  reviewer's last reviewed commit is 1cf2753, so these are not reviewed yet.
- New: GUIDE-001 + WU-007 (journal, spec in docs/specs/GUIDE-001.md), SECT-003 (duty reminders), FH-026 (rank-1 rogue
  missions were Deadly through Qi Refining), WU-009 (no arrival card over the respawn screen), EPI-001 + WU-004 (epilogue),
  MS-002 (milestone progress), REL-010 (save on Steam Deck suspend), NS-002b/NS-006 (late content), QA-025.
- The cloud clone's local `main` can be an unrelated shallow history; work from `origin/main` (e.g. a local branch made from
  it) and push `HEAD:main`.

## State on 2026-10-08 (planner, 02:30 UTC)
- 19 tasks landed in two and a half hours (all FH-* first-hour tasks, REL-001..004, LW-002 part 1, LW-003, QA-016, QA-018).
  Workers are fast: keep every role stocked with ~6 ready tasks and spec the top ones.
- New task groups: FH-024/025 (newcomer-safe missions, explore for a week), STAT-001 + GOAL-001 + REL-009 (life record,
  milestones, Steam platform stub), REL-007 (crash-safe saves), WU-001..008 (save toast, sect standings, arrival card,
  epilogue, joinable-event markers, milestones UI, journal, title art), QA-019..024.
- Claim branches are not being deleted after landing (remote branch deletion is refused by the agents' permissions). A
  `claude/<id>-*` branch for a task in Done is not a claim. Only the owner can clean them up.

## State on 2026-10-07 (planner, 23:30 UTC)
- BACKLOG.md was rebuilt: 242 finished rows moved to docs/BACKLOG_DONE.md; new task groups FH-* (first hour), REL-* (Steam
  basics: autosave, final death, audio, credits, export), NS-* (content past Core Formation), QA-016..020. Specs in docs/specs/.
- Audits found the first hour's HUD hint only says "gather qi", the Qingshi workshop has no ingredients, lethal 15-50% fights are
  forced, and content stops at Core Formation. The owner's three most urgent questions are at the top of DESIGN.md's open list.

## State on 2026-10-07 (evening)
- **New team design:** an Opus planner, an Opus reviewer and six Sonnet workers. Workers land straight on main and there are no
  PRs. See docs/AGENTS.md. The old PR/integrator flow piled up ~200 PRs that the owner merged by hand.
- main is green (890 tests). Fixed: the load screen logged an engine error whenever a save existed (UIStyle.button connected an
  empty Callable). Cloud runners have no saves, so the tests missed it; test_load_screen_with_saves.gd now covers it.
- Workers must not edit BACKLOG.md or CHANGELOG.md; the planner keeps them in sync from `[ID]` commit subjects.
- docs/REVIEW.md tracks the last commit the reviewer checked.

## State on 2026-10-04 (second session, in progress)
- **main is green** (`tools/test.sh`: 823 tests, ALL CHECKS PASSED). PRs #159-#184 are merged (one task per PR, squash-merged). No open PRs.
- Done this session: G-005d, W-004g/h, QA-007e, G-008f, ART-005b, G-006b, BODY-001c, FAM-005d, G-011b/c, AUC-001b, UI-010b, DEM-001, LW-001/LW-001b, UI-008b, UI-009b, C-009, C-010, RIV-002/003, W-006b/c, VIS-004/005, W-005e, FAM-004c, FAM-008b, FAM-006b/c, FAM-007d.
- Next good tasks: FAM-009d, FAM-010, FAM-011, FAM-013b, G-006c, W-005c/f, ART-003b/c/d, BEAST-001b/c/d, UI-002b, UI-003c, QA-014.
- New since the last handoff: sect ranks need trial fights (every rank above the first), world events roll monthly, the player has a named rival (CharacterData.rival), grudge holders ambush on the road, devouring after beating a `cultivator`-tagged enemy, an `inheritance` and an `auction` place type.

## Waiting on the owner (don't decide these yourself)
- **C-009, the first fights**: a newcomer with a starter technique and an iron sword beats a Mist Wolf ~4% of the time (QA-007d realm_training). See the DESIGN.md open question.
- **F-005d, cultivation pacing**: a sensible player reaches Core Formation at age ~20, so lifespan and pills barely matter. See the DESIGN.md open question. `tests/sim/simulate_life.gd -- 20 1.0 1 real` shows it.
- **QA-007g / QA-007f, enemy tuning**: several foes sit far from the 60-85% win-rate target at their own realm. Run `tests/sim/simulate_combat.gd` before and after changing anything.

## Tools added this session
- `TEST_ONLY=<substring> tools/godot.sh --headless --path . -s res://tests/run_tests.gd` runs one test file.
- The runner reseeds `GameState.rng` per test. `TEST_SEED_SALT=x` changes the seeds, so a test that fails under some salt is flaky; fix it rather than the seed.
- `FUZZ_LOG=1 TEST_ONLY=fuzz ...` prints every option the interactable fuzz invokes and every message posted. Grep the messages for odd wording.
- `xvfb-run -a -s "-screen 0 1280x800x24" tools/godot.sh --path . --rendering-driver opengl3 --resolution 1280x800 -s res://tests/sim/screenshot_regions.gd` saves a PNG of every region (software GL works in the cloud container), so art and layout can be checked by eye.
- Same command with `-s res://tests/sim/screenshot_screens.gd` saves a PNG of every HUD screen for a mid-game character (`user://screenshots/screens/`), to eyeball layout at 1280x800 (WU-021).
- `tools/balance.sh` (about 5 minutes) runs the first-hour (seeds 1-10), combat and economy sims with fixed seeds and rewrites `docs/balance_baseline.txt`; `tools/balance.sh --check` diffs a fresh run against it and exits 1 on any change. Not part of test.sh: after tuning data/*.json, re-run it and commit the new baseline with your change.
- New guard tests: `test_interactable_fuzz.gd` (every menu option in every region), `test_data_references.gd` (broken ids, unset flags), `test_steam_deck_layout.gd` (screens fit 1280x800), and a no-shared-key-or-button test in `test_help_screen.gd`.

## Lessons from this session
- After squash-merging a PR from the session branch, reset the branch to origin/main before the next task (`git fetch origin main && git checkout -B <branch> origin/main`), or the next PR conflicts with the squashed copy of the old commits.
- `tools/test.sh | tail` hides the exit status; check for `ALL CHECKS PASSED` before committing.

## Lessons from merging many agent PRs at once
- Nearly every PR conflicts on `docs/BACKLOG.md` and `docs/CHANGELOG.md`. Merge main into the PR branch, never rebase. Keep both sides' rows and lines, and check for **duplicate task ids** (agents often reuse an id; rename the newer one).
- After merging, rerun the full checks. Typical breakages were tests made stale by a newer rule (clans need an abode seat, tougher enemies since QA-007d, the intro story event at session start, choice encounters must set their `blocked_by_flag` on every choice) and two places placed at the same map position.

## First-hour screenshot look (WU-278, 2026-10-22, 1280x800 and 1280x720)

WU-278: labels now draw from a child `_label_node` (z_index 10) and `spread_labels` runs over places and NPCs together. hud_arrival at 1280x800: "Sect Recruitment Hall" is whole (no longer behind the workshop). Still overlapping: "Founder's Old Well" and "Dongfang Beichen" at the right screen edge, because the draw-time screen clamp (WU-269) shifts a label after the world-space spread. Fixing it needs a screen-space spread pass.

## First-hour screenshot look (WU-262, 2026-10-22, 1280x800 and 1280x720)

WU-272 (2026-10-22): re-ran `screenshot_first_hour.gd` at 1280x800 and 1280x720 under xvfb-run and opened hud_arrival at both. WU-269's clamp works: "Founder's Old Well", "Spirit Spring (2x qi)", "Sect Recruitment Hall" and "Hunters' Bounty Board" are all inside the screen at both sizes (the clamp is not at fault; no code change). Two cosmetic leftovers at 1280x800 only, both from labels that sit on world objects at the screen edge:
- "Founder's Old Well" and the NPC label "Xiong Muxue" overlap (the draw-time clamp moves a label after `spread_labels` separated them).
- "Sect Recruitment Hall": its first word "Sect " is hidden behind the Village Workshop building, which is drawn after the hall; the label reads "Recruitment Hall".
Fixing either needs a label pass in the world (draw labels on a top layer and spread them after clamping), not a change to `clamp_label_left`.
Re-ran `screenshot_first_hour.gd` on main and opened all 8 PNGs at both sizes. Nothing clipped inside any window.
- Script bug fixed: `CombatReport.close()` refuses while playback runs, so the combat report stayed open and covered the journal, inventory and sheet shots; the shot now calls `skip()` first.
- Edge labels: in hud_arrival at 1280x800 "Founder's Old..." and "Sect Recruitmen..." are still cut at the right edge (objects at the screen edge); at 1280x720 (and after the player moves) they are whole. "Hunters' Bounty Board" is whole at both sizes. No world change made.

## First-hour screenshot look (WU-175, 2026-10-16, 1280x800)
Looked at all 8 PNGs from `screenshot_first_hour.gd` against WU-157's list. Nothing clipped inside any window; no layout bug fixed in this pass.
- Edge labels ("Founder's Old...", "Sect Recruitmen..." cut at the right edge; "Hunters' Bo..." behind the HUD panel): still there (labels sit on world objects that are themselves at the screen edge; needs a camera/world-layout call).
- Goal / hint repeat: fixed (Goal says Elder Mo; hints now Iron Fist manual and Headman Zhou chores).
- "Wandering Merchant" label under the player sprite and the interact prompt: still there (WU-176).
- `combat_report` "Fair fight: Wild Boar (Weak 98)" next to a 2-round defeat: still there (the script stages the fight; not a real boar fight).
- `explore_menu` header reading as an option: fixed (separator under the title, WU-161).
- Sheet / journal "Next steps": fixed (3 hints plus "More in the Journal (J)"); the journal still lists all 7.

## Village look (QA-186)
Viewed at 1280x800 under xvfb: `--field` (field plot, fence, labels), `--season=Autumn` hud_arrival (orange/red trees, leaf-strewn ground, seasonal chip in the HUD card) and the `--season=Spring` shop shot (WU-415: seasonal price tag, quantity row with `-10 < x1 > +10 Max`, category tabs). Nothing clipped or overlapping, no layout changes. Not viewed: the WU-413 invited-friend chip and the field menu with tool icons (no screenshot flag shows them; a `--companion` flag is still needed). Village sim `-- 10 12 --village` (10 seeds): fishing 527 stones over 480 days = ~1.10 stones/day (C-279 measured ~1.43; the later trophy/weather changes shifted it), field 151 stones vs rent 159 (net -8), 38 harvests, 37 quarrels.

## Shot pass (QA-203), partial
Fixed in `screenshot_first_hour.gd`: `--hud-panel` crop now scales by window/viewport ratio (viewed at 1280x720: whole panel, no clipping); multi-region `--region=a,b` clears the log per region (viewed qingshi_village,misty_forest at 1280x720: only that region's lines). Misty Forest arrival shot: no clipping or overlap. Not yet viewed: --season-board, --regular, calendar months, --festival, --contest, --season=Winter, --critters, --lesson flag, GFX-096 crop shots.
