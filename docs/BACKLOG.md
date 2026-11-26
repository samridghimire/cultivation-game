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
Next (planner 2026-11-26 06:10): 10 landed (SECT-046, WU-625, WU-626, SECT-047, SECT-048, WU-624, GFX-257, GUIDE-292, GFX-256,
SECT-045); SIM-034 needed no change. Reviewed through 35449b9. Planner shots 06:10: Qingshi arrival, the champion card and the
trial cards read well; **the breakthrough window, the biggest moment of the game, is still a plain text box** (GFX-258, spec;
GFX-260 after it). The sect ladder is deep enough for now: the next systems work turns to friends who cultivate on their own
(FOLK-050, spec), trial preparation shown sooner (SECT-051, spec), the second rank measured (SIM-035) and the reviewer's
contest notes (SECT-049). SECT-046 missed its first-promotion target because trial odds are 0-5 in 100 when contribution is
ready: that is a pacing call for the owner (DESIGN.md "(SECT-046) First promotion timing"), not a task.
Workers: after a rebase run `git diff origin/main --stat` and check it lists only files your task touched; rebase with
`--no-keep-empty`.
Reference: Tale of Immortal's sect life and NPCs who cultivate beside you.
Real games always start in Qingshi (`data.start_region`), so other-start fixes rank below Qingshi and sect work.
**Shots work in the cloud** (see CLAUDE.md "Screenshots"): render and look before landing any visual task.
**Owner 2026-10-28:** pixel art from CC0/CC-BY packs, a slower schedule, and fewer, larger player-facing tasks; hint and
wording changes skip `tools/balance.sh --check`.
| id | role | status | task |
|---|---|---|---|
| FOLK-050 | systems | todo spec | (Planner 2026-11-26 06:10; reference: Tale of Immortal's NPCs who cultivate beside you and remember you, Stardew Valley's villagers with lives of their own, mechanics only.) **Their own news.** Spec: [docs/specs/FOLK-050.md](specs/FOLK-050.md). When a named NPC you are friends with (favor >= `folk_news.min_favor`) begins Qi Refining or breaks through off screen, it becomes a pending own-news (`CharacterData.friend_news`, saved, default {}): a log line, the GFX-249 bubble, their own line on the next talk (npcs.json `own_news_lines`, fallback in family.json) and a one-time "Congratulate <name>" option (+3 favor). Measure 730 days x 6 seeds and paste which friends reach a milestone. No balance values change. |
| GFX-258 | world-ui | todo spec | (Planner shot 2026-11-26 06:10, `screenshot_screens.gd -- --breakthrough-shots`: the breakthrough window is text only; reference: Tale of Immortal's breakthrough scenes, staging only.) **The breakthrough, staged.** Spec: [docs/specs/GFX-258.md](specs/GFX-258.md). A code-drawn `BreakthroughStage` header in the breakthrough window (the player seated on a mat, qi motes spiralling in, a ghostly figure while a heart vision is pending that fades once faced), and Attempt plays a ~1.4 s success flash or failure burst before the realm card / failure banner. Skippable, gamepad-safe, fits 1280x720; `bs_stage_success.png` / `bs_stage_fail.png` shots. |
| SECT-051 | systems | todo spec | (SECT-046 Follow-up: when rank-1 contribution is ready the trial odds are 0-5 in 100, so first promotions wait months; reference: Tale of Immortal's breakthrough and trial preparation, mechanics only.) **A trial you can see coming.** Today the trial advice (`Sects.trial_advice`, e.g. "Learn an attack technique; the examiner uses Metal Edge Sword Art.") shows only once the trial is offered. *Spec:* (1) In `Guidance` (read how the sect trial line and the GUIDE-276 "tip the odds" clause are built; grep `trial_advice` and `_trial_foe`), when the player is in a sect, the next rank needs a trial, contribution is at least 50% of that rank's requirement and the trial odds (`Sects.trial_foe` vs the player, same odds function the trial card uses) are below 50 in 100, add one hint "Prepare for the <rank> trial (now <word>, N in 100): <trial_advice>" ranked right after the duty/mission line, at most once per 7 days like the friend line (follow the existing weekly-hint pattern). Never when the advice is empty. (2) The journal Sect page's "Rise to <rank>" panel (WU-618) shows the same advice as a muted row under the trial goal when odds < 50 (this is a small UI touch; keep it under 30 lines). (3) The sect_year hints player already acts on advice lines it understands; if it ignores this one, teach it the same action it takes for the trial card's advice (do not invent a new policy). (4) Measure with `tests/sim/sect_year.gd` seeds 1-3 x 3 sects, 300 days: per run the day contribution for rank 1 is ready, the trial odds that day, and the first promotion day, before and after; paste the table. No balance values change. Tests: hint appears at 50% contribution with low odds, not at 40%, not with odds >= 50, not when advice is empty, not twice in 7 days; Sect page row present/absent. |
| SIM-035 | systems | todo spec | (SECT-045 Follow-up: "the sim never reaches rank 2 contests"; reference: none, balance tooling.) **The second rank, measured.** (1) Extend `tests/sim/sect_year.gd` with `--days=730` support if missing and a `--ladder-report`: per sect and seed, the day of each promotion (rank 1, rank 2), the trial odds on the day each rank's contribution was ready, months at rank 2, inner-contest entries (SECT-045 `inner_contest`) and rounds won, and rank-2 duty met/short. (2) Run seeds 1-3 x 3 sects x 730 days and paste the table. (3) If no run enters an inner contest within 730 days, name the cause in one sentence per sect (rank 2 too late, the contest month passes while away, the hints player never takes it, foes out of reach) by reading the logs; fix a sim cause in the sim; list game causes under `Follow-ups:` (SECT-050 picks the top one). (4) Refresh the "Sect trials" section of docs/balance_baseline.txt with `tools/balance.sh --section` (SECT-045 found it stale: Inner Disciple median 414 -> 450) and explain the move in one sentence. No game data changes. |
| SECT-049 | systems | todo spec | (Reviewer notes 2026-11-26; reference: none, tech debt.) **Contest reasons by code.** (1) `Sects.check_contest` returns a `reason` code (e.g. "ok", "not_member", "wrong_month", "already_entered", "rank_too_low", "rank_too_high", "away", plus whatever cases exist today; read the function) alongside its message; `Sects.contest_line` and every other caller that today matches message prefixes ("You have already", "first two ranks"; grep `begins_with(` near contest code) switch on the code, so rewording a message never changes the Sect page. (2) Contest tests that mutate the shared Azure Cloud contest def (`data.sects["azure_cloud_sect"].contest` or similar) work on a duplicated def or restore it in every path (use a helper). (3) `ContestStage._pick_platform` (src/world/contest_stage.gd, GFX-255) has a never-set `fallback`: remove it or set it, whichever keeps behaviour. Tests: one per reason code through `contest_line`; a test asserts the shared def is unchanged after the contest tests run. |
| WU-631 | world-ui | todo | (Planner 2026-11-26 06:10; reference: Stardew Valley's first days, mechanics only.) **The first hour, polished again.** Render `screenshot_first_hour.gd` (no flags) and `screenshot_screens.gd -- --first-hour` at 1280x800 and 1280x720 and open every PNG. Fix the three worst layout problems you find (clipped or overlapping text, a label over a figure, focus not visible, a panel off screen), each under ~60 lines, with a test where the fix is logic (e.g. a pure placement or fit helper). Write each problem and fix in the commit message with the shot name; list the rest under `Follow-ups:`. Skip anything GFX-258 covers (the breakthrough window). |
| WU-627 | world-ui | todo | (After SECT-048; WU-622 Follow-up.) **Your contest record on the Sect page.** In the journal Sect page's This month panel, under the contest line, a muted "Contest: best round N of M, champion X times" from `Sects.contest_record` (only once the player has entered one). Render `--journal-sect` after a forced contest and open it. Test: line absent before the first contest, present after. |
| QA-247 | qa | todo | (WU-617, WU-616 Follow-ups; reference: none, shot pass.) **New cards, rendered.** (1) Add `--practice-level=<tech_id>` to tests/sim/screenshot_first_hour.gd: learn the technique, set its practice so the next session levels it, run one practice session through GameState and render the level-up card (practice_level.png) and, with a second non-levelling session, the log row (practice_row.png; crop not needed). (2) Render `--sect-trial=azure_cloud_sect --lose` at 1280x720 (WU-616 never checked it). (3) WU-611 is on main: render `--sect-contest=azure_cloud_sect` at 1280x800 and 1280x720 (planner 1280x800 render 2026-11-24 12:10 fits). (4) Planner 2026-11-24 12:10, also: WU-619 Follow-up: the `--member` shot leaves the disciple unreported, so add `--reported` (report through GameState) and render the calendar (`--calendar` or the journal Calendar tab) as a member in the contest month to show the lecture/duty/contest entries; WU-621 never rendered: open `--journal-sect` in the contest month; GFX-252: open `--sect-promote` once. Open every PNG; fix layout bugs you find if small (clipped text, overlap), else list them under Follow-ups. Note: shot runs that exit 134 after the last PNG are QA-240, not this task. |
| QA-248 | qa | todo | (C-423 and GFX-255 Follow-ups; reference: none, balance and shots.) **Chores and the stage, checked.** (1) C-423 moved sect_year first promotions later in 2 of 9 seeds (blood_lotus seed 1: 278 -> 349; pavilion seed 3: 123 -> 246). Log which missions the sect_year hints player takes in those two seeds before and after C-423 (673d575^ vs main): if the hint prefers a low-pay chore over a better-paying ready mission, file the cause in Follow-ups with the hint line; if the chores are simply more of the same, say so. (2) Render the contest stage on arrival for all three first-year sects (`--member=<sect> --contest-month --region=<home>`: azure_peak, withered_bone_marsh, the Pavilion's home) at 1280x800 and 1280x720 and open them: the platform and figures are on screen, not under the hotkey bar or a label. Fix the shot flags if needed; file visual bugs as Follow-ups. |
| QA-243 | qa | todo | *Planner 2026-11-23 12:10: QA-245 takes the sect shots; keep this to the flags named here.* *Planner 2026-11-23: also GFX-234's Follow-up: the `--friend-scene=<id>` shot keeps Qingshi behind the card for a villager of another region (current_region is set but the world is not rebuilt): rebuild the world for that region first.* (GFX-233, WU-593 and WU-594 Follow-ups: shot tooling and unrendered shots; reference: none, shot pass.) *Planner 2026-11-22 18:10: also GFX-238's Follow-up: `--book --favor=hunter_ma=90` renders Hunter Ma as Close friend, so the Sworn cord/knot was never seen: fix the flag ordering, then render the People card and a Qingshi arrival with the knot.* **Shots that show one thing each.** (1) In tests/sim/screenshot_first_hour.gd, clear the message log before tier-up, sworn and tea shots so the Almanac line no longer shows in them; (2) reset favor between shots in one run so `--tier-up-far` no longer inherits favor from an earlier `--tier-up` (store and restore `npc_favor` around each staged shot); (3) render and open `--book` (birthday within 14 days: add `--day=<n>` if no flag sets the date, or reuse `--birthday=hunter_ma` minus 5 days), `--calendar-month=10` (Hunter Ma's cake on day 21) and `--book --favor=hunter_ma=62`; describe each PNG and fix anything under ~60 lines. (4) WU-596 Follow-up: the people shot's own favor loop overwrites `--favor=<id>=<n>`; make an explicit `--favor` win so `--book --favor=hunter_ma=90` renders a Sworn card (GFX-238 needs it). Tests: none needed beyond a clean run. |
| QA-244 | qa | todo | (SIM-026 and C-414 Follow-ups; reference: none, balance tooling.) **Baseline after the shopping test player.** Run `tools/balance.sh --section` for the time breakdown and first_hour_presses sections on main and explain each moved line in one sentence (SIM-026 buys craft inputs, SIM-025 crafts/trials, C-414 local teachers, GUIDE-288 treasury manual read); paste `first_hour_presses.gd --starts=myriad_peaks_ridge,azure_peak,withered_bone_marsh,fallen_star_market` first_technique day on main vs 8362c13's parent 2dcbabd~1. Refresh only those sections. List anything unexplained under Follow-ups. |
| QA-245 | qa | todo | *Planner 2026-11-26 06:10: the `--sect-trial --lose` shot hard-codes `"chance": 0.35`, so sect_trial_lost.png reads "Dangerous (35 in 100)" right after a "Deadly (3 in 100)" trial card: compute it from the real odds.* (WU-608, WU-605, SECT-034 Follow-ups; planner shot 2026-11-23 12:10; reference: none, shot pass.) **Sect shots.** (1) `--sect-promote` adds 100000 contribution but rank 1 needs a trial, so the card reads "Promoted: Outer Disciple" with no perks: pass the trial in the flag (`Sects.pass_trial` or set rank 1) so it shows Inner Disciple and SECT-034's perks line; render and open. (2) Add `--sect-hall=<sect_id>` (join, report, open the home hall menu) and `--digest-sect` (a member's month-end digest card with the stipend row): render both and open (WU-608's "Sect overview" row first; one stipend row). (3) `--journal-sect --rank=1` (or similar) so the duty bar shows (Outer Disciple owes no duty): render and open. Fix layout problems under ~30 lines, else file them under Follow-ups. 1280x800 and 1280x720. *Planner 2026-11-24: also the --news shot leaves a friend-scene lesson card over the world (GFX-249 Follow-up), and WU-612's shots were never rendered.* |
| C-421 | content | todo spec | (After FOLK-048 and FOLK-049; absorbs C-422; same format as C-418; reference: Stardew Valley's villagers reacting to your milestones, mechanics only.) **What they say about your sect life.** In data/npcs.json `news_lines` (read FolkNews in src/core/systems/folk_news.gd and the file's `_doc` for the exact kinds and placeholders before writing), for Elder Mo, Xiao Ling and Hunter Ma (and the pond fisher if WU-625 is on main): (1) `<kind>_demonic` for join and rank (1 line each, `{sect}` allowed): worry, disappointment or a cold word, never praise; (2) `contest` (1 line, `{sect}`): Elder Mo proud, Hunter Ma practical, Xiao Ling teasing-warm; (3) `contest_demonic` (1 line): uneasy pride. <= 140 chars each, in their established voice (read their existing news_lines and friend scenes first). Test in tests/unit/test_folk_news.gd (or the FOLK-049 test file): for each villager every new key resolves through `FolkNews.take` for a demonic joiner and for a champion. Hint/wording only: no balance check. |
| C-412 | content | todo | (C-408 Follow-up: only 4 dishes are taught (`taught: true` home meals); reference: Stardew Valley's recipes from friends, mechanics only.) **Dishes your friends teach.** Add 4 taught home meals (data/recipes.json `home_meals`, COOK-001/002 format: ingredients from the teacher's own region, days 1, a dish item with a small COOK-002 `buff` within the validated limits, price like the existing taught dishes) and move one tier-2 or tier-3 lesson each of 4 start-region villagers outside Qingshi (one per region where it fits: marsh, market, Azure Peak, ridge) from practice_days/items to `learn_dish` of their dish, keeping the lesson text in their voice (rewrite it to show the cooking). Add their `taught_dish_line`. If a dish item is new, give it `likes` on at least one other villager. GameData validation passes; a test that each new dish is taught by exactly one lesson and is cookable after it. Run `tools/balance.sh --check` only if a buff exceeds the existing taught dishes'. |
| C-419 | content | todo | *Planner 2026-11-26: Fisher Pei (WU-625) is on main, so include them.* (After FOLK-047, same format as C-418.) **What they say when you break through.** `news_lines` `breakthrough` (1 line, `{realm}`) and `wedding` (1 line, `{spouse}`) for the Qingshi villagers with favor and friend scenes (C-418 found only 3: Elder Mo, Xiao Ling, Hunter Ma; plus C-405's pond fisher if it is on main), in their own voice, <= 140 chars; Elder Mo proud, Hunter Ma practical, Xiao Ling warm. If FOLK-048 is on main, also give each a `sect_join_demonic` line (wary, in their voice). Test that each has the keys. |
| QA-240 | qa | todo | *Planner 2026-11-26 06:10: the default run still exits 134 after character_sheet.png; also its combat_report.png shows the Azure Cloud join card on top of the fight report, because the hud_after_sect shot joins the sect without clearing the queued join card (clear `_pending_moments` and close `_sect_card` there, as --journal-sect does).* (QA-238 parts 1 and 3, not done in 613d9d9; planner shot run 2026-11-20 18:10 still exits 134 after character_sheet.png; reference: none, shot pass.) *Planner 2026-11-21 12:10: `--tea/--tier-up` runs still exit 134 after the last PNG.* **Shots that finish clean.** (1) The default `screenshot_first_hour.gd` run (no flags) exits 134 (`Aborted`) after its last shot: find the crash at exit (a freed node, or a thread still running at quit: GroundWarm, Audio's WorkerThreadPool title loop from PERF-026; try `--verbose` and wait_for_task_completion before quit) and make it exit 0. (2) Render hud_arrival at `--resolution 1280x720` and open it; fix or file anything cut. Open every PNG you render. |
| QA-242 | qa | todo | (WU-584, C-401, GFX-222, GUIDE-278 Follow-ups: shots never rendered; reference: none, shot pass.) *Planner 2026-11-22 00:10: also PERF-031 (886d615) never measured: paste `region_load_times.gd --full` on 886d615 and its parent 42a4a03 (warm switch HUD part, target < 25 ms), and render hud_arrival after one travel to check every HUD panel still shows.* **Shots of the last batch.** Render at 1280x800 and open every PNG: `--fight=wild_boar` combat_report and `--explore=all` for qingshi_village (WU-584: the report reads "Your odds before the fight: Easy, 99 in 100", the explore foes read "Easy for you, 99%" or "threat: Weak", nothing wraps badly); `screenshot_screens.gd -- --creation` (C-401: the dominant element's line under the talent verdict, not clipped); `--region=myriad_peaks_ridge --explore=all` (GFX-222 Follow-up: the ridge crags' floor after the cave/reeds/ruins floor change); and a Qingshi run with `--favor=45` where the Next-steps card shows GUIDE-278's "Grow closer" line (say if it fits on two lines). Fix each layout bug under ~30 lines in the same commit; list the rest under `Follow-ups:`. tools/test.sh. |
| C-406 | content | todo | (After FOLK-037; reference: Stardew Valley's visits, mechanics only.) **Tea at their place.** Optional `call_lines` on named NPCs in data/npcs.json (1-3 strings, <= 140 chars, `{player}` allowed), one picked the way C-404 picks `lend_lines` (stable hash of npc and day, never GameState.rng) and posted after the tea line in `GameState.call_on`; document in the file's `_doc`, validate count and length in GameData (copy the `lend_lines` validation). Write 2 lines each for every named NPC in the six start regions, in their own voice: what their home looks like, what they serve, a small confidence a Friend would share (never a mechanic, no modern slang). Tests: GameData rejects 4 lines or a 141-char line; the posted line is one of the NPC's; an NPC without `call_lines` posts only the tea line. No balance impact. |
| C-345 | content | todo | (WILD-020 chains are data-driven; reference: Monster Hunter's elder beasts, mechanics only.) **A great beast for Core cultivators.** Add a Core Formation great beast to Myriad Peaks Ridge's roamers.great (with its tracks, its day, a trophy item with a wall-fit description <= 140 chars and a trophy_comment-friendly name), and a chain step that sends a Foundation-beast slayer there. Rated Dangerous (40-60 in 100) for a geared Core Formation Early player (check with the combat sim's usage scan). tools/test.sh. |
| C-357 | content | todo | (C-342 Follow-up: ~100 encounters still have no `scene`; reference: none, content pass.) **The rest of the scenes.** List every encounter in data/encounters.json without `scene` (a quick script in the commit message is fine). Set one by hand wherever the text names or clearly implies a setting (woods, cave, ruins, reeds, ridge, trail, village; a festival in the village square is `village`, a market crowd is `village`). Leave unset only those whose text truly has no place, and list those ids in the commit. No text or effect changes. Render `screenshot_screens.gd` encounter.png for two newly set scenes (stage them if the script allows `--encounter=<id>`; add the flag if not) and open them. tools/test.sh. WU-552 Follow-up: the marsh and mountain ferryman/ford encounters (grep `ferry\|ford\|boat` in data/encounters.json) get `scene: river` (or `reeds` where the text is a marsh channel). |
| QA-236 | qa | todo | (GFX-194, PERF-012, GFX-197 Follow-ups: shots and the frame probe never run; reference: none, shot pass.) **Rain, checked.** (1) Render `screenshot_first_hour.gd -- --rain` and `--storm` for qingshi_village, azure_peak and withered_bone_marsh at 1280x800, open each: rings on ponds, streams and bog pools; puddle ripples never over carts, NPCs or roofs (PERF-012 now draws rings above world-drawn decor: say if any shows on a prop); no stripes. (2) Repeat the reviewer's frame probe from PERF-012's REVIEW entry (Qingshi, forced rain, xvfb opengl3, 150 frames, with and without rain) and paste ms/frame; flag > 5 ms extra under `Follow-ups:`. (3) Render the world map at 1280x720 (GFX-197) and say whether any day chip still touches a banner. (4) (GFX-200, C-391 Follow-ups) Fallen Star Market `--rain` and Summer: the new city earth, gutters and planters read under rain; the Next steps card lists the Porters' Foreman's stray-dog chore as the easy fight. Fix only what takes < 30 lines; the rest under `Follow-ups:`. |
| QA-225 | qa | todo | (Reviewer notes 2026-11-16: ART-012, C-377, C-376 and ART-015 changed balance numbers without `tools/balance.sh --check`; planner 2026-11-19 06:10: also C-394 (new monkey chore foe, baseline not refreshed); reference: none, balance.) **Balance after the seals and the new foes.** (Planner 2026-11-21 18:10: also C-409, whose Azure Peak 15-stone Iron Fist manual skipped the check; confirm the economy section.) (Planner 2026-11-21 06:10: also QA-241, whose per-NPC streams in Npcs.simulate shift every seeded run; say which sections moved only from the stream shift.) (Planner 2026-11-20 06:10: C-399 refreshed the baseline but left combat drift unexplained (first wolf win median 464 -> 480, fights won 38 -> 34), likely a stale baseline; explain it here.) (Planner 2026-11-19 18:10: also C-396's first-fight drops and C-397's gifts, both skipped the check.) (Planner 2026-11-18: also C-386, whose five favor errands skipped the check, and C-387's Star-Dew pill.) Run `tools/balance.sh --check`, then refresh (`tools/balance.sh --section`) every section that moved, one at a time (land after each if the run gets long), and explain each moved line in one sentence naming the likely task (ART-012/ART-015 energy, C-377 foes, C-376 encounters shifting rng draws). Flag anything no landed task explains under `Follow-ups:`. |
| QA-207 | qa | todo spec | (QA-203 Follow-up: part 1 landed b60a3df; reference: none, tooling.) **Shot pass, the rest.** Also QA-209's leftovers: map.png, the Qingshi arrival, shop.png, GFX-111/112 winter edges, a marsh encounter strip, and the jetty stage-3 label that crowds the Hooded Stranger's (fix if under ~30 lines). Render at 1280x800 and 1280x720 under xvfb and open every PNG: `screenshot_first_hour.gd` `--season-board`, `--regular`, `--calendar-month=3`, `--calendar-month=5`, `--festival`, `--contest`, `--season=Winter` (hens, no ducks), `--critters`, `--region=qingshi_village` with `--season=spring|autumn|winter` and `--field` (GFX-096: does the rented plot show young vs ripe crops?), `--well=0`/`--well=3`, a default shot on a work day and a rain day (FOLK-017's spots). Add a `--lesson` flag (WU-479 Follow-up: Hunter Ma's lesson card). Fix each small layout bug (clipping, overlap, bad wrap) in the same commit when it is under ~30 lines; bigger ones go under `Follow-ups:`. Note what you saw in docs/HANDOFF.md under "Shot pass (QA-207)". If RV-019 has not landed, apply its one-line `hud != null` guard locally only for `screenshot_screens.gd` runs. *Acceptance:* tools/test.sh. (Planner 2026-11-20 00:10: also the unrendered WU-565/GFX-214/GFX-215 shots: the journal Errands section with a met teacher, the withered_bone_marsh Next-steps card, journal/explore_menu/inventory at 1280x720, combat_report `--fight=cultivator`, Qingshi `--season=Spring|Autumn` yard props and coop hens, `--friend=peddler_hei --region=withered_bone_marsh` teacher menu, the ridge `--season=Winter` snow, `--walk=200` Qingshi Spring and Autumn (grass puffs, petals, falling leaves), and `--focus=spirit_spring_2x_qi` Qingshi plus the Azure Peak arrival (qi pool glow never over a label or the player).) |
| QA-237 | qa | todo | (C-385 Follow-ups; reference: Stardew Valley's community bundles, mechanics only.) **Season sets, measured after C-385.** C-385 made spring petals forageable, raised summer grass weight and changed autumn_moon to 2 Village Mugwort, but never measured. Run `first_hour.gd -- 6 24 --season-tasks --season-report` on main and on 7f97ce8 (the parent of 0bceee9) and paste the year-1 set completion (sets finished of 24, reason histogram) side by side. If a season still finishes 0 sets in every seed, name the blocking task and its reason under Follow-ups. Also run `tools/balance.sh --check` (C-385 changed a forage table and a price) and refresh the economy section with one sentence per moved line. tools/test.sh. |
| QA-221 | qa | todo | (After QA-219; the rest of its old scope; reference: none, balance.) **The rest of the baseline.** Run `tools/balance.sh --section` for combat, three curious years and the Core/foundation-year sections one at a time (land after each one that finishes if your run gets long), explain each moved line in one sentence naming the likely task (C-364, NPCFOE-001, C-365 move Core and combat; the teacher bouts move curious years), and list in `Follow-ups:` the Core-year >95% share with the top 5 foes filling it. QA-219 also flagged: the curious practiser's wolf-win "never" seeds rose 1 -> 5 (practise=false) and 0 -> 3 (practise=true); say whether teacher bouts eat the fight time (one `--trace` seed). Baseline only. tools/test.sh. |
| QA-199 | qa | todo | (WILD-018, C-312 and C-313 are on main: ready; C-313 skipped its balance check. C-308 Follow-up target.) **Is the Foundation year fair now?** Re-run `simulate_foundation_year` (6 seeds, `--threats=fight`, and the exploration-only 3-seed run) as C-308 did and paste the rated-odds histogram next to C-308's (before 90% >95%, after C-308 75%). Target from DESIGN.md (QA-007): the >95% share under 65% and 50-90% at 20-30% of exploration fights, lives spent median <= 1. If it misses, name the 3 fights that dominate the >95% bucket and their source (roamer, mission, chore, encounter) under `Follow-ups:`; do not retune data yourself. |
| QA-193 | qa | todo spec | (QA-191 and C-293 Follow-ups. **Part 1 landed a8c8757: do (2) and (3) only.**) **The sims know the new world.** (1) (done) The combat section of `docs/balance_baseline.txt` lists the four great beasts (old_tusker_boar, bog_king_toad, cloud_crane, thunder_horn_ram) as UNUSED because the usage scan only looks at encounters and missions: make it also count regions.json `roamers.enemies` and `roamers.great` (label "roamer" / "great roamer") so they get the usual entry/peak/talisman rows; refresh that section. (2) Re-run QA-190's village arm (`simulate_curious_years.gd -- 10 12 --village`) after C-293 and paste fishing / field / forage stones per day next to QA-190's (forage was 3.2 per visit-day before C-293; target <= ~1.5 in Qingshi). File per-region numbers above target under Follow-ups (no data changes). (3) Explain QA-191's "Armor shopping loot sales 110 -> 0" with a one-seed trace, or say it is rng and why. Refresh only the sections you changed. |
| GFX-260 | world-ui | todo | (After GFX-258; reference: Tale of Immortal's breakthrough scenes, staging only.) **The new realm and the failed gate, staged.** (1) RealmCard (src/ui/realm_card.gd) gets GFX-258's `BreakthroughStage` as a header in a "risen" pose: the player standing in a soft light column, motes settled into a ring at the feet, the new realm's name over it. (2) A failed major breakthrough opens a card instead of only the "Breakthrough Failed" banner (hud.gd `_on_breakthrough`): the stage in a dimmed "scattered" pose (motes drifting away, the player seated with head bowed), the qi lost, any injury, and the lessons bonus for the next attempt (the breakthrough window already shows "Lessons of N failed attempts +X%": reuse that term). Goes through the existing moments/realm-card path so it never stacks on another modal; focus on its button. Shots: extend `--breakthrough-shots` with realm_card_staged.png and breakthrough_failed.png; render at 1280x800 and 1280x720 and open them. Tests: the failed card opens on a failed attempt and carries the qi/injury/lesson lines; success still opens the realm card. |
| WU-629 | world-ui | todo | (After FOLK-050; reference: Stardew Valley's villagers sharing their news, mechanics only.) **Their news, on their faces.** The GFX-249 news bubble uses a distinct glyph for a friend's own news (a small rising star instead of the speech mark); the villager menu shows "Congratulate <name>" first while it is pending, and the reply shows as a friend-scene style card (reuse FriendSceneCard with the villager and the player face to face; no new art). Shots: add `--own-news=<npc_id>` to screenshot_first_hour.gd (force the pending own-news) for own_news_bubble.png and own_news_card.png; render and open them. Tests: the menu order and that the option disappears after congratulating. |
| C-424 | content | todo | (After FOLK-050; same tone rules as C-418/C-421.) **What they say about their own progress.** `own_news_lines` (`qi_start` and/or `breakthrough`, 1-2 lines each, `{player}` / `{realm}`, <= 140 chars, in their own voice, no pronouns for the player) for every named NPC with `cultivates: true` in data/npcs.json (Xiao Ling first: her `qi_start` is the one players will see most; Elder Mo, Herbalist Lan, Peddler Hei, Alchemist Hua, Blood Lotus Xue, Broker Qian, Swordsman Yun, Disciple Bai; higher-realm elders may get one short `breakthrough` line each). Read FOLK-050's `_doc` for the exact keys. |
| WU-630 | world-ui | todo | (After SECT-051.) **Preparing, on the trial card.** When SECT-051's prep advice applies, the Sect page row and the trial card share one look: a small "Prepare" tag in UIStyle accent before the advice, and the trial card lists up to two advice items (attack technique, armor, a meal) instead of one red sentence; red stays for the odds word only. Render `--sect-trial=azure_cloud_sect` and `--journal-sect` and open them. Test: the card's advice rows match `Sects.trial_advice` items. |
| SECT-050 | systems | todo | (After SIM-035.) **The inner contest within reach.** Fix the top game-side cause SIM-035 names for nobody entering an inner contest in two years (smallest change; a data change needs `tools/balance.sh --check`). If the cause is a pacing choice (rank 2 simply comes after year 2 by design), do nothing but write it under `Follow-ups:` for the planner. |
| GFX-002 | world-ui | blocked | Import the first pixel-art pack. **Blocked on the owner** (DESIGN.md "(GFX-002) Which pixel-art pack"): the cloud cannot reach itch.io, kenney.nl or opengameart.org. Default proposal: "Ninja Adventure" (Pixel-boy & AAA, CC0, 16x16, East Asian village tiles, 4-direction characters, items, UI). Once the pack's files and license are in `assets/third_party/<pack>/`, map the player and the Qingshi Village place kinds in data/sprites.json and add ASSETS.md rows. |
| GFX-003 | world-ui | blocked | (After GFX-002; GFX-006/007 already built the hooks, so this is mostly data/sprites.json mapping.) The start village in pixel art: ground tiles and decor (trees, rocks, water) for qingshi_village through `Sprites` keys `ground_<tag>` / `decor_<kind>` in world.gd `_draw()`/`_draw_decor()`, placeholder elsewhere; re-render `screenshot_regions.gd` for Qingshi. |
| GFX-004 | world-ui | blocked | (After GFX-002.) Player and NPC sprites with 4-direction walk cycles; the sect robe and alignment sash still readable (palette swap or an overlay); first-hour shots re-rendered. |
| GFX-005 | world-ui | blocked | (After GFX-002.) HUD and menu frames and item icons from the same pack (UIStyle panels, inventory icons by item tag), nearest filter, crisp at 1280x800 and 1920x1080. |

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

## Blocked (waiting on the owner, see DESIGN.md "Open design questions")
| id | role | status | task |
|---|---|---|---|
| GUIDE-135 | systems | blocked | (After QA-148; its Follow-ups decide the wording and reserve.) A hint to spend sect contribution ("Spend contribution: the sect treasury sells Superior Qi Gathering Pills for 40, about N days of meditation each (you have 1346)."), mirroring GUIDE-126's `qi_pill_offer` (usable qi only, keep the breakthrough pill's contribution while it is still to claim). If QA-148 flags a large pacing change (QR9 > ~30% sooner), this task becomes blocked on the owner (F-005d) instead; the planner will say which. *Planner 12:15: QA-148 says it is: contribution qi pills put 10/10 seeds past QR9 by month 12 (base 2/10). Blocked on F-005d; QA-150 measures a capped version for the owner.* *Planner 16:15: QA-150: cap 2/month ~12% sooner, cap 4 ~19%; proposed default for the owner is a 2-a-month hint.* |
| SECT-030 | systems | blocked | *Planner 2026-11-26: SECT-047 saw Azure/Blood seed 5 short on rank-1 duty 4-5 months, the sim cultivating away from the hall: same question.* (QA-228 and QA-229 Follow-ups.) A far-qi sect disciple misses the monthly duty about half the time, and walking home for the steward's chores costs ~330 days to Foundation; early sect members also never move to the better qi spot. Blocked on the DESIGN.md question "(SECT-030) Duty for disciples who cultivate far from the hall". Default if approved: meditation days at a qi spot of density >= 2x the sect hall's count toward duty at 1 contribution per 2 days for Outer Disciples, capped at half the monthly duty. |
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
| SECT-045 | systems | Ranks 2+ have their own yearly inner-sect contest (optional `inner_contest` block: own month, Foundation-level foes, ~3x prizes). |
| GFX-256 | world-ui | Winning every contest round adds a champion card: the player alone on the platform, banners, cheering crowd, petals, prize total. |
| GUIDE-292 | systems | An open lecture within reach ranks second in the hints; first rogue lecture 4/10 seeds (day 174) -> 10/10 (day 103). |
| GFX-257 | world-ui | Sect page goals draw pixel tick boxes; the duplicate "Earn N contribution" row is dropped. |
| WU-624 | world-ui | The lost-trial card names the lesson learned; the trial card shows "Lessons from N tries: examiner -X%". |
| SECT-048 | systems | Contest record: life stats, a Sect Champion milestone, `contest_record` on the character and an epilogue line. |
| SECT-047 | systems | `sect_year.gd --duty-report`; the rank-1 duty shortfall was the sim (it skipped the covering mission): Pavilion 6/6 short -> 0/6. |
| WU-626 | world-ui | The HUD goal row keeps the whole compacted goal whenever two rows hold it. |
| WU-625 | world-ui | Fisher Pei at the Village Pond Jetty (C-405's data); villager stands follow a tested label-clearance rule. |
| SECT-046 | systems | Each lost promotion trial makes that examiner 6% weaker next time (cap 18%, reset at promotion); 6/9 first promotions by day 180 not met (odds gap). |
| SIM-034 | systems | No change needed: hints-only quiet stretches over 1095 days are at most 57 days (target <= 90), measured in SECT-045's run. |
| WU-622 | world-ui | Sect page: the duty line turns green when met; not-ready missions grouped by their first blocker. |
| WU-618 | world-ui | Sect page: a "Rise to <next rank>" panel lists the next rank's goals, done or not; `--sect-rank` works on the journal shot. |
| GFX-255 | world-ui | The contest stage stands on the court or open ground beside the hall, clear of labels; refreshes when the month turns. |
| SIM-033 | systems | Rogue lecture hint names the hall; sim fixes: first style 0/10 -> 10/10 (day 23), lecture 0/10 -> 4/10 (day 174). |
| C-423 | content | Two free rank-0 chores per first-year sect (each sect has >= 4). |
| GFX-254 | world-ui | ContestArena on the contest card: platform, banners, spectators, you vs the round's foe, won/lost poses. |
| SIM-032 | systems | quiet_stretches counts trial-training weeks as new; longest stretches unchanged (seed 4: 109 days). |
| C-411 | content | Friend scenes at favor 40/60 for the eight Azure Peak and ridge friends; three cheap gifts. |
| WU-611 | world-ui | The sect contest card: round ladder, prizes and first-bout odds; each bout tells its result on a card. |
| SECT-042 | systems | Rank-1 goal rows (perk, tier mission, realm, next contribution) read from sects.json (review: lifetime rows rank-1 only). |
| WU-619 | world-ui | Lecture, monthly duty and the contest month on the calendar, with a dawn reminder on contest day. |
| SECT-043 | systems | Contest odds measured and tuned per round (power_mults); leaving and rejoining cannot enter twice a year. |
| FOLK-049 | systems | Winning every contest round queues "contest" friend news (demonic fallback). |
| SIM-031 | systems | rogue_season.gd: the rogue's first 180 days measured (no style, no lecture in any seed). |
| GFX-252 | world-ui | Rank trim (silver/gold/jade) on the player sprite; --sect-rank shot flag. |
| GFX-253 | world-ui | A contest stage (platform, banners, sparring disciples) at the sect hall during the contest month. |
| SECT-041 | systems | Sim takes ready missions before the friend line; 4/9 seeds at rank 1 by day ~180, now trial-limited. |
| SECT-044 | systems | The player's rival fights the contest's last round when in the same sect; win or lose moves grudge/favor. |
| WU-621 | world-ui | The Sect page's This month panel shows the contest: month, open now, or why barred. |
| WU-620 | world-ui | The contest card names your rival in the final round; landed 5408efb alongside GFX-254. |
| SECT-038 | systems | Yearly outer-sect contest: bouts in order until a loss, each win pays contribution and stones (review: prize promotions announced). |
| WU-615 | world-ui | Friend news really queues in play (start-region fallback); Xiao Ling opens her talk with it. |
| FOLK-048 | systems | Demonic sect news uses <kind>_demonic lines; has_pending follows the rogue rule. |
| GUIDE-291 | systems | Hints player acts on "Learn your first technique: ask <teacher> (free)" (sim fix; 0 unactionable weeks). |
| QA-246 | qa | Audit: e937e6f reverted nothing else; WU-612 and GFX-250 are on main. |
| GFX-251 | world-ui | Charcoal Burner's Stall moved to the road verge east of the bridge, label clear. |
| WU-616 | world-ui | Lost trial card names the real next rank and says lost; arena shows the player kneeling. |
| SIM-030 | systems | Hints player trains while the trial is Close and attempts it at >= 60 in 100; --trial-log. |
| WU-617 | world-ui | Practice sessions show level and days to the next; a level-up opens a small card. |
| GFX-249 | world-ui | A villager with pending news shows a red banner bubble until you talk to them; --news shot flag. |
| GUIDE-290 | systems | quiet_stretches.gd counts favor tiers, friend scenes and lectures as new (longest stretches unchanged: not a missing hint). |
| WU-612 | world-ui | The trial card returns to the board or hall menu; a friend's news is the dialogue's opening line. |
| GFX-250 | world-ui | SectVignette and TrialArena at 2x with PixelFigure people and per-sect props. |
| SECT-039 | systems | Lectures lead hints in the hall region, rank-1 contribution 300/250/300, rank-0 missions x1.5, softer rank-1 examiners (first promotion day 245-350). |
| SECT-040 | systems | Sects.trial_advice names the biggest gap; used in the lost-trial log, the card and guidance. |
| WU-613 | world-ui | Journal Sect page: tab focus follows the page, ready missions under Missions, one Treasury block. |
| FOLK-047 | systems | FolkNews breakthrough (Foundation and up) and wedding kinds with {realm}/{spouse}. |
| SIM-029 | systems | sect_year.gd prints the day each sect goal row completes; every row completes in every seed. |
| C-417 | content | Misty Forest Charcoal Burner's Stall sells Manual: Iron Fist and food; every start region has a local style. |
| WU-614 | world-ui | A lost promotion trial opens a TrialCard result mode (examiner, what you lacked, injury, odds now). |
| WU-610 | world-ui | The journal Sect page shows a rank progress bar, the trial foe, priced treasury rows and the first ready missions. |
| SECT-037 | systems | Joining marks the sect home explored, the home arrival line posts at join, the bottleneck line only when qi was capped. |
| GFX-247 | world-ui | Lin and Gui work spots clear of plates, --member shot flag, the Pavilion court drills (drill_sect_id). |
| GFX-248 | world-ui | The lecture card hall drawn at 2x with PixelFigure elder, disciples and player. |
| SECT-036 | systems | Part 1: the report line leads the Goal row for an unreported member; hints player lecture/trial branches (balance half -> SECT-039). |
| C-418 | content | Elder Mo, Xiao Ling and Hunter Ma have their own sect_join/promotion news lines. |
| WU-609 | world-ui | The rank trial opens a TrialCard: examiner, odds in words and N in 100, never-lethal line, perks; Not yet focused under 30 in 100. |
| GFX-246 | world-ui | Join, report and promotion sect cards open with a code-drawn vignette in the sect colour (SectVignette). |
| WU-608 | world-ui | The hall menu opens with a "Sect overview" row (journal Sect page, B back to the hall); month-end stipend posts become one digest row. |
| SIM-028 | systems | `tests/sim/sect_year.gd` + balance "sect year" section: no sect reaches rank 1 in year 1, report ~200 days late, 0 lectures (-> SECT-036). |
| FOLK-046 | systems | Friends (favor >= 40) in the start region react once to your sect join or promotion (FolkNews, `folk_news`, npcs.json `news_lines`). |
| SECT-035 | systems | A "sect" goal ladder (report, lecture, mission, rank 1) for members before Foundation, with a Sect goals block and the hall focus marker. |
| WU-607 | world-ui | Sect banner on the map at the home region, "Home of"/"Report at" in the details, one home arrival line; `--map-sect=`. |
| GFX-244 | world-ui | Blossom Crack label below its sprite, Hunter Ma's work spot clears the bounty board (Azure/marsh plates -> GFX-247). |
| SECT-034 | systems | Promotion summary names perks and the trial foe; lecture "open this month (Nd left)"; report hint leads; chore giver name shrinks by words. |
| GFX-243 | world-ui | Court drills flank the hall where the south band is shallow (Azure 2+4, Blood Lotus 4 flanking); the Pavilion's hall has no sect key (-> GFX-247). |
| WU-606 | world-ui | The monthly lecture is a moment: SectCard lecture mode with a hall vignette, the elder's line, qi or bottleneck, insight; `--sect-lecture=`. |
| GUIDE-289 | systems | The hints player reports at the hall; longest quiet stretch 79 -> 54 days (2 of 6 seeds <= 45; tea weeks remain, -> GUIDE-290). |
| WU-605 | world-ui | A Sect tab in the journal for members: banner header, This month card, rank ladder; `--journal-sect`. |
| PERF-030 | systems | Dropped (FOLK-046 run): profile_labels mean ~0.14 ms is already inside budget; a partial re-resolve risks layout changes. |
| GFX-234 | world-ui | Market and Qingshi close-ups rendered (market arrival, lend Hua, Qingshi labels, Old Monster Gui's scene); nothing to fix; `--friend-scene=<id>[,<favor>]`. |
| C-416 | content | Gifts for the last three: Hua likes Talisman Paper, Xue Cicada Shell, Lin Azure Pine Needle; every villager with drop_by_lines can give something. |
| FOLK-045 | systems | Drop-by gifts prefer the friend's work yield (rng-free); optional `{item}` token in drop_by lines, validated. |
| SECT-033 | systems | `Sects.ladder` and `Sects.month_status`: the sect at a glance as data (no UI). Lecture says "today" while unattended -> SECT-034. |
| WU-604 | world-ui | Sect cards queue as moments; a welcome card after reporting (steward line, items with icons, 4 hall services from `Guidance.hall_services`). Blood Lotus card rendered by the planner: fits. |
| GFX-242 | world-ui | Azure Peak plates clear: Lin by the forge, Bai east of the court, physician label nudged. "ask Qiu" names a steward off screen -> SECT-034. |
| GUIDE-286 | systems | Outside Qingshi the first-technique goal names the local teacher ("ask <Name> (free)"); the hints player takes it. Presses not measured -> QA-244. |
| SECT-032 | systems | Reporting at the hall: `welcome` per sect, `Sects.needs_report/report`, `GameState.report_to_sect`, `sect_reported`, hall option and hint. Sim has no report branch -> SECT-034. |
| GFX-241 | world-ui | Disciples drill on the sect court (`court_drill`, CourtDrill node, none in rain/festival). Azure one row; marsh/Pavilion courts too small -> GFX-243. |
| RV-SECT031 | systems | Every sect promotion (deeds, dialogue, letters, missions) emits `sect_promoted` once, via GameState's announced rank. |
| WU-603 | world-ui | A promotion card (rank, new perks, next rank); the reviewer queued it behind the mission board. "Next rank: a trial awaits" names no foe -> SECT-034. |
| GUIDE-287 | systems | A sect member or Qi Refining player no longer reads "Talk to Elder Mo" (past_elder_mo); sworn_tend_line skips family. |
| WU-601 | world-ui | The oath, tend and gift-left moments queue (FIFO) behind open screens and play one at a time. |
| GFX-238 | world-ui | Sworn friends get a red cord on the People card and a red knot before their world name; not rendered (shot flag shows Close friend) -> QA-243. |
| SECT-031 | systems | EventBus.sect_joined/sect_promoted, one _post_promotion(), Guidance.sect_welcome, Sects.promotion_summary; effects-driven promotions miss the signal -> RV-SECT031. |
| WU-602 | world-ui | Joining a sect shows a centred card: banner, rank, home, duty, perks, first step; opens over the hall menu -> WU-604. |
| C-414 | content | Five start regions get a dialogue first teacher; marsh and market stalls sell the Iron Fist manual; Misty Forest still has no local style -> C-417. |
| SIM-026 | systems | The hints player buys what a craft needs from a seller within 3 days; baseline not refreshed -> QA-244. |
| GFX-240 | world-ui | Qingshi jetty label moved off the pond (label_offset), Hooded Stranger nudged, the [E] chip avoids other places' sprites. |
| GUIDE-288 | systems | An owned treasury manual says "Study it from your bag"; the sim reads it; seed 1 longest stretch 63 days. |
| WU-594 | world-ui | A Close friend's People card names the road to Sworn friend: tea until favor 80, then the birthday gift (with its date). |
| FOLK-043 | systems | A Sworn friend in the region you arrive in halves your injuries once per 90 days (stable-hash line, no rng). |
| GFX-235 | world-ui | Reaching Sworn friend plays a 3 s staged oath (incense burner, bows, smoke, card); figures are flat blocks -> GFX-236. |
| WU-595 | world-ui | The goal chevron sits above the marked person's name plate; names keep off the player; [E] prompt vs place label not fixed -> WU-597. |
| GUIDE-285 | systems | Elder Mo goals and hints show only when Qingshi is within 3 days; other starts get their next reachable goal; no local first-method teacher outside Qingshi -> C-414. |
| FOLK-042 | systems | Cause found (sim missed the 14-day birthday window, birthday line ranked low, cheap liked gift too small); birthday_min_gain 10 rule; Sworn friend now reached in 7-10/10 seeds of every start (median day 178-431). |
| GFX-233 | world-ui | The tier-up shot shows the tier-up (banner, hearts); the banner icon pulses when the friend is off screen; --tier-up-far flag. |
| C-407 | content | Every start-region villager likes something buyable or gatherable nearby (Saint Lan gains Cliff Edelweiss). |
| GUIDE-280 | systems | Partial: quiet_stretches --weeks names the pattern (5-month peak cultivation, one weekly line repeated) and a 'You have never been to X' hint; longest stretches unchanged -> SIM-025. |
| WU-593 | world-ui | People cards count down to a friend's birthday ('Birthday in N days: a liked gift counts double'); the calendar day notes the double gift. |
| FOLK-040 | systems | Partial: the first liked birthday gift goes past the gift cap to favor 90, with a birthday hint the sim follows; Sworn friend still 0/10 -> FOLK-042. |
| WU-591 | world-ui | Name labels avoid the full 40 px sprite, so names sit above heads in every start (checked on the ridge and Azure Peak). |
| GFX-231 | world-ui | Rising hearts at 2x with a pop; tea pair seated a table apart; tier-up shot still shows the wrong banner -> GFX-233. |
| WU-592 | world-ui | People cards wrap every line inside the card; lesson line shortened to "Has a lesson for you". |
| GUIDE-284 | systems | Elder Mo lines get whole short forms, the dangling-word guard grows, "(opens at Core Formation)" kept whole; unreachable ridge goal -> GUIDE-285. |
| SIM-024 | systems | Six-start friendship table (close_friend, sworn_friend, first_lesson, first_friend_scene); sworn never, no friend scenes on ridge/Azure. |
| FOLK-041 | systems | Close friends in your region may leave a gift once a month (their yield or a cheap like) with a line; rng use -> RV-FOLK041. |
| PERF-031 | world-ui | All HUD modals build on first use, none on travel; timings not measured (-> QA-242). |
| GFX-232 | world-ui | Withered Bone Marsh's lower-left gets bog pools and dead trees; market/lend/friend-scene shots -> GFX-234. |
| GFX-230 | world-ui | The other five starts looked at: marsh, ridge and Azure Peak decor made fuller (data only); labels on benches -> WU-591, marsh lower-left -> GFX-232. |
| C-410 | content | Friend scenes at favor 40 and 60 for seven forest, marsh and market villagers, with three cheap local gifts. |
| C-409 | content | A Cloud-Stair Pedlar on Azure Peak sells the Iron Fist manual for 15: first technique median day 136 -> 7. |
| WU-588 | world-ui | People cards show what to do next with each person (Folk.next_step): tea, lend, likes, next tier. |
| WU-590 | world-ui | Place labels also avoid named villagers' and the player's bodies (move up/down, else fade). |
| GUIDE-283 | systems | Grow closer and tea hints get short forms; the short-hint fallback never ends inside a name or on a dangling word. |
| WU-589 | world-ui | Tea and tier-up shots staged right; named villagers (Elder Mo, Hunter Ma) now cross friendship tiers with hearts and a banner. |
| FOLK-039 | systems | Partial: sworn_friend milestone in the hints sim; 0/10 seeds reach it (gifts cap at 50, tea at 80) -> FOLK-040. |
| GFX-229 | world-ui | Work-prop vignettes drawn at 1.5x the figure's pixel scale (WorkProps.prop_scale). |
| WU-586 | world-ui | Next steps that never clip: investigated, nothing clipped in the --tea shot; regression test that the cut matches the label's real wrapping. |
| FOLK-038 | systems | Favor that names the next friendship step: Family.favor_progress_for names the next folk tier for villagers who cannot be courted. |
| GFX-227 | world-ui | A tier-up you can't miss: 7x6 pixel hearts rise above the name strip, a "<name>: <tier>" banner with the hearts icon. |
| GUIDE-281 | systems | A first technique on the ridge start: the Pedlar sells a 15-stone Iron Fist manual, the sim buys it before lending; ridge first_technique 165 -> 7. Azure still day 136 -> C-409. |
| GFX-228 | world-ui | Tea, seated: both figures sit, a 14x6 table with two cups and cushions, the interact prompt hides under any time-skip card. Shot not looked at -> WU-589. |
| C-408 | content | Something at every tier: tier-2 and tier-3 lessons for the 13 start-region villagers who had none. |
| GUIDE-282 | systems | Partial: --trace runs to the first friend; the cause is the weekly lend cap (5 lends = 35 days). Planner default: keep the cap (DESIGN.md). |
| WU-587 | world-ui | People before places: a place label that overlaps a villager's name row moves or fades. The label still covers the sprite's head -> WU-590. |
| PERF-029 | systems | Partial: fight ratings keyed by the fighter's combat stats (Combat.rating_key); timing not measured -> QA-243. |
| PERF-018 | world-ui | Partial: Settings/Help/Load screens built on first use; warm switch HUD part ~80 -> 68 ms. The rest -> PERF-031. |
| PERF-025 | systems | Partial: label spread checks membership by hash (O(n^2) -> O(n)). Rect cache and partial re-resolve -> PERF-030. |
| GFX-226 | world-ui | Tea, shown: a "Tea with {name}" card, the pair beside the villager with a low table and a steaming cup; --tea=<id> shot flag. |
| PERF-028 | systems | Partial: fight fingerprints key buffs/injuries by what a fight reads, bounded ratings remember rejections; hints ~13 s per long sim seed unchanged, the real cut moves to PERF-029. |
| SIM-023 | systems | first_hour_presses --start/--starts and a "first hour in every start" baseline: ridge/azure learn a technique at day 165/136, marsh's first friend at day 50. |
| WU-585 | world-ui | Lending a hand in every start: Scenery.lend_spot picks a free side, the card rises above a pair in the lower half. |
| GFX-225 | world-ui | A tier-up you see: hearts rise over the villager after any card closes, the new pip flashes, lend row names the next tier; --tier-up shot flag. |
| FOLK-037 | systems | Tea with a friend: once a Friend, share tea weekly (1 day, +3 favor up to 80); Close friend 10/10 sim seeds by day ~125. |
| GUIDE-279 | systems | The Easy fight line comes before the make-friend line until the first win; first_win worst day 90 -> 9; --trace=<seed>. |
| QA-241 | qa | Seeded tests that don't leak: a freed HUD's time-skip no longer re-shows in the next session; Npcs.simulate rolls per-NPC streams. |
| GFX-224 | world-ui | Villager work props as small vignettes (stump and split logs, furrows, dust puff, water, reading table, basket). |
| C-355 | content | The artifact's whispers: 3 dry lines per moment, picked by name and moment, not the shared rng. |
| GFX-223 | world-ui | Boulders with a firmer contact shadow and a lit top edge, like the ridge crags. |
| QA-239 | qa | Named NPCs roll their roots from their own stream (world seed + id), so adding a villager no longer reshuffles others; per-NPC streams in Npcs.simulate left to QA-241. |
| WU-584 | world-ui | One word for odds: the report says "Your odds before the fight: Easy", explore foes "Easy for you, 99%" or "threat: Weak". |
| GUIDE-278 | systems | "Grow closer" hint once a villager is a Friend and none is a Close friend: a liked gift in the bag or on sale here. |
| SIM-022 | systems | quiet_stretches --breakdown: days and qi per activity to Foundation; cultivate 466 days, chores+missions 206, travel 78 (0 qi); 1 of 4 seeds reaches Foundation by day 1095. |
| PERF-027 | systems | Partial: quiet_stretches --profile: Next-steps build ~9 s of a ~14 s seed, fair_fights ~22 ms per call; the speedup moves to PERF-028. |
| C-404 | content | Every named villager thanks you in their own voice after a lent hand (lend_lines, stable pick, no rng draw). |
| GFX-222 | world-ui | --explore=all renders every place's strip; caves, reeds and ruins now stand on stone, mud and dust floors. |
| WU-583 | world-ui | Villager label is one strip (name, heart pips, marker) that spread_labels keeps clear; --favor= shot flag. |
| GUIDE-277 | systems | Qi Refining players are no longer shown a great-beast goal they can't meet; far easy fights give way to near ones; prepare weeks count as idle in the sim. |
| C-401 | content | Element descriptions and root-grade blurbs; character creation says what your dominant element is good at. |
| FOLK-036 | systems | The make-friend line is 3rd in the hint list and continues to "Become friends" (lend or a liked gift) until a Friend; first Friend median day 76. |
| GFX-221 | world-ui | Lending a hand shows a "Helping {name}" card with the player beside the villager at their work. |
| WU-582 | world-ui | Explore-site menus open with a scene strip of the place (ChoiceMenu shows it for any source with menu_scene_look). |
| C-403 | content | Ten more named villagers work (chop, hawk, read, sweep, hoe): every start region has >= 2 at work. Pond fisher not done (QA-239, C-405). |
| SIM-021 | systems | Hints sim lends a hand: first Acquaintance day 328 -> 41; Friend tier still never; the line is 7th of 5 visible (FOLK-036). |
| GFX-220 | world-ui | Myriad Peaks Ridge: no stray melt blob, olive alpine turf, warmer road, crags with contact shadow and lit edge. |
| GUIDE-276 | systems | Even fights (0.7-0.9) carry a short prep clause in the journal and HUD. |
| GUIDE-275 | systems | Ridge start: the first manual is named away from home, closed road goals skipped, injuries say when healed; idle weeks 171 -> 7. |
| WU-581 | world-ui | Villagers at a friendship tier show 1-3 heart pips after their name, and a speech dot for a lesson to talk about. |
| WU-580 | world-ui | Goal row fitted to two lines with a word-boundary ellipsis; character-creation stick re-arms properly. |
| FOLK-035 | systems | Lend a hand: once a week per named villager, +4 favor (to 45), 1 day, small yield; "Make a friend" hint. |
| QA-238 | qa | --skip-dusk works with a single --region (parts 1 and 3 moved to QA-240). |
| SIM-019 | systems | quiet_stretches --days=N; the hints player fights the Foundation great beast; 1 of 4 seeds reaches Foundation in 3 years. |
| GFX-219 | world-ui | Villagers at their work: optional activity (sweep/hoe/fish/read/hawk/chop/sit) with a 2-frame prop; 16 villagers tagged. |
| C-402 | content | Every repeatable newcomer chore rated >= 0.96 for a day-7 newcomer; test_newcomer_chores.gd keeps it so. |
| PERF-026 | systems | Title music synthesized on a worker thread; GroundWarm re-bakes pruned files (measurements still need a display). |
| SIM-020 | systems | Hints sim acts on sell, lecture and meditate lines; marsh start idle weeks 5 -> 0. |
| WU-578 | world-ui | Creation names the root by element count, the right stick steps attributes; title clouds fade, smooth sky bands, a redrawn seated cultivator. |
| WU-579 | world-ui | Next-steps hints trim at a word boundary with an ellipsis, never on a bare preposition; full text as tooltip. |
| GUIDE-274 | systems | Guidance.prep_step names the best next step for a fight under 0.7; great-beast notes carry it. |
| C-400 | content | Forges, waters and crowds tagged with sound in every region (max 4 per region). |
| GFX-218 | world-ui | Bluer moonlit nights, a warmer dusk; workshop, clinic, hall, shrine and stall lanterns glow; the skip card dims only while a cycle plays. |
| SIM-017 | systems | Hints sim counts menu presses per milestone (first_hour_presses.gd, baseline section). |
| WU-576 | world-ui | Failed trades play no coin, storms keep one wind layer, the journal header has a Calendar button. |
| GFX-216 | world-ui | Title screen: soft wrapping pixel clouds, pines clear of the menu, a seated cultivator with rising motes, breathing pavilion glow. |
| WU-575 | world-ui | Character creation: aligned attribute grid with trimmed hints and an about line, root-coloured aura behind the portrait. |
| GFX-217 | world-ui | Multi-day skips play 1-3 dusk-night-dawn cycles on the world tint; lanterns and windows glow (NightGlow). |
| WU-577 | world-ui | Optional `sound` on places and landmarks: positional amb_water/forge/falls/crowd/wind loops (3 places tagged). |
| SIM-018 | systems | Hints sim: qi-pill buying uses qi to bottleneck and skips unaffordable pills, far chores travelled to; idle weeks 20 -> 0 (marsh 25 -> 5). |
| PERF-022 | systems | GroundWarm also bakes next season's ground when the season ends within 7 days. |
| PERF-024 | systems | Partial: label pin pass builds its obstacle rects once (rest -> PERF-025). |
| PERF-023 | systems | StartupLaps (--profile-startup) and lazy SFX synthesis (136 ms -> 0 at launch). |
| GUIDE-273 | systems | Layer goals name their first step (meditate, about N days). |
| C-399 | content | Rank-0 home meals for every early region from local ingredients (+ test). |
| C-385 | content | Season tasks finishable: Qingshi spring petal forage, summer grass weight, autumn_moon -> 2 Village Mugwort. |
| WU-573 | world-ui | Region/weather/season ambience beds and accents, step/meditate/coin/rustle/splash sounds, Ambience volume (review: per-layer fade tweens). |
| GFX-215 | world-ui | Meditation places and abodes with qi_density > 1 show rising motes and a breathing ground ring. |
| GFX-214 | world-ui | Grass puffs (petals in spring) while walking; falling leaves in autumn/leaves regions (pool of 40; review: toggle keeps leaves). |
| WU-574 | world-ui | Gamepad test drives every HUD screen and Qingshi menu; A/B added to ui_accept/ui_cancel when missing. |
| WU-565 | world-ui | Shot pass: Qingshi/Azure Peak Winter, Qingshi/Misty Forest Summer clean; --shop-manual flag (rest moved to QA-207). |
| SIM-016 | systems | Hints sim acts on bounties, easy-fight starts, cooking and armor; idle weeks 34 -> 20 of 520. |
| PERF-021 | systems | Partial: one shared cover list for label spreading (rest in PERF-024). |
| SIM-015 | systems | Hints sim in a sect (--hints-only/--start/--join): duty met 130/130, disciple lines all acted on. |
| PERF-017 | systems | Neighbour regions' ground baked on a worker thread 2 s after load; a first visit reads the cache. |
| C-398 | content | Test: an Easy fight exists on each of the 7 days after the region's chore, every early region and season (no gaps). |
| GFX-211 | world-ui | --fight=<id>[,...] shots of every first foe; Azure Peak winter cascades draw as frozen icefalls. |
| GFX-212 | world-ui | Footprints: snow prints, rain ripples, road dust behind the player (cap 40; reduce_motion static). |
| GFX-213 | world-ui | Meditation seats the player, draws root-coloured qi motes and a tick glow; --meditate shot flag. |
| WU-572 | world-ui | Goal and easy-fight markers also refresh on day change. |
| GUIDE-271 | systems | Great-beast road goal carries odds, picks the best beast, HUD skips it while Deadly (cache key fixed by review). |
| SIM-014 | systems | Partial: hints player fishes and buys/equips armor; FirstHour.easy_fight_start helper (rest -> SIM-016). |
| C-396 | content | Each first-fight foe drops one item that feeds a local loop (gift, recipe or ingredient). |
| C-397 | content | 17 early NPCs get a once-only first secret at favor 8-12: a scene, a small gift and a place tip. |
| PERF-020 | systems | Partial: crowd_keep/separate without per-label allocations (Qingshi 2.06 -> 1.85 ms); rest -> PERF-021. |
| GUIDE-272 | systems | Partial: hints sim --idle-dump, skips skipped goal rows, sect-home branch reachable; idle weeks 68 -> 34 (rest -> SIM-016). |
| PERF-019 | systems | Label work per frame cut ~6x walking (cached text sizes, cover lists built once, re-spread every 0.2 s); profile_labels.gd. |
| WU-571 | world-ui | Easy-fight HUD line fits one row; build-time lift counted as walk lift; dead label code removed. |
| GUIDE-270 | systems | Dialogue.next_unlock and a Today line naming who will say more as a friend; npc_met_<id> flag. |
| GFX-209 | world-ui | Fallen foes lie on their shadow in the duel stage. |
| GFX-210 | world-ui | Azure Peak rock ledge, stream cascades and boulders in the arrival view. |
| GFX-208 | world-ui | A named villager's label is pinned in a band around their body. |
| SIM-013 | systems | Hints player visits Fallen Star and picks by the path; no doubled "Easy fight:" prefix. |
| GUIDE-269 | systems | Every easy-fight line names where to start it (Bounty Board, mission board, explore site). |
| C-395 | content | test_easy_fights: an Easy fight in every early region every season (no gaps found). |
| GUIDE-268 | systems | Goal trip notes and abode hints say the realm a gated road opens at. |
| SIM-012 | systems | --start/--join flags for the hints sim (runs not done -> SIM-015). |
| WU-570 | world-ui | Silver marker and edge arrow over the easy fight when the goal has no target here. |
| GFX-204 | world-ui | Own dog and drake beast rows, goat -> ram, sharper bear ears, bigger rhino horn. |
| PERF-016 | systems | Ground cache PNG encoded and written on a worker thread (tmp + rename), GroundCache.flush(). |
| GUIDE-264 | systems | A sect home behind a realm-gated road says when the road opens and drops below actionable hints (route_gate). |
| GFX-206 | world-ui | Person labels lift at most 16 px or fall below the feet; place labels yield; arrival banner blocks labels. |
| QA-237 | qa | Hints sim travels, practises and claims from the treasury: idle weeks 304 -> 50 of 520. |
| GUIDE-267 | systems | Easy fight line names the chore giver ("ask Qiu"); Guidance.fight_target. |
| GFX-205 | world-ui | Azure Peak dressing: cliff faces, terraces, stairs, wind-bent pines, mist rows (draw-only). |
| WU-569 | world-ui | Labels near the player re-aim and ease aside as you walk. |
| C-394 | content | Woodcutter Bai's Thicket Monkey Troop chore: Misty Forest's easy first fight. |
| GUIDE-266 | systems | Guidance.hud_goal_text: one goal text for the HUD, goal_region and the goal-way fight. |
| GUIDE-265 | systems | A stall's wanted item that is by the path folds into the forage line. |
| QA-238 | qa | Data tests: every teacher likes something cheap or near; chore fights are non-lethal and pay 6-12. |
| GFX-207 | world-ui | Own DuelStage shapes for goat, leech swarm, crow flock and monkey troop. |
| GFX-201 | world-ui | Player ground ring and rim; labels lift off the player at region build. |
| WU-567 | world-ui | Gold goal marker over the current goal's person/place with an edge arrow. |
| GUIDE-261 | systems | Headman Zhou's work line names a chore only when one is open. |
| C-392 | content | Easy chore fights in Azure Peak, Bone Marsh and Myriad Ridge (goat, leeches, crows). |
| SIM-011 | systems | The hints sim player acts on the sect-home, unseal and teacher lines; per-line tally. |
| GFX-202 | world-ui | Labels never touch: deed givers count as persons, overlap tests per region. |
| GFX-203 | world-ui | No yellow smudges on the ridge and Azure Peak ground. |
| GUIDE-262 | systems | The goal-way fight works for any goal that names a region. |
| GUIDE-263 | systems | Newcomer odds in plain words. |
| WU-568 | world-ui | Lighter first menus: creation, Elder Mo's dialogue and Explore. |
| C-393 | content | Every teacher's favor road has a cheap, reachable liked gift. |
| WU-566 | world-ui | Shot pass of the first five minutes; findings -> WU-567, WU-568, GUIDE-263. |
| GFX-200 | world-ui | Fallen Star Market: city earth with grit, hall forecourts linked to streets, gutters and potted trees. |
| SIM-010 | systems | A `hints` sim policy that follows the Next-steps lines; 5 unactable lines -> SIM-011, GUIDE-261. |
| PERF-015 | systems | region_load_times --full: every warm region switch under 100 ms; HUD _ready ~60 ms is the biggest part. |
| C-391 | content | Fallen Star's Porters' Foreman pays 10 stones to chase stray dogs: an easy first fight in the market. |
| C-390 | content | Item-asking sect missions pay ~1.4x the items' price (missions with stipends 2.27x work). |
| GFX-199 | world-ui | Own beast shapes for bear, rhino, tortoise and spider; tusker, porcupine and peng keywords. |
| PERF-014 | systems | profile_saves sim: 10-year autosave ~41 ms, load 91 ms; no change needed. |
| PERF-013 | systems | Ground textures baked to a disk cache: second visits 3-5 ms. |
| GUIDE-260 | systems | A first fight on the way to the goal's region is listed first (within 2 extra travel days). |
| GFX-198 | world-ui | Ridge scree from 12 tiles (no dotted grid), no edge blob, dithered winter kerbs, clean Meteor Crater bowl. |
| C-389 | content | Misty Forest, Bone Marsh and the Ridge forage their own seasonal plants (13 new herbs). |
| QA-234 | systems | The sim buyer asks the far-pill hint first; it never names a far pill from Qingshi (as decided). |
| PERF-012 | world-ui | Rain ripple rings draw in the RainPuddles node: no whole-world redraw 8 times a second. |
| GFX-197 | world-ui | Map day chips placed clear of banners, mark pips fit under banners, coloured legend bullets. |
| PERF-011 | systems | profile_days `--realm`; no day over 60 ms for QR1 or Foundation (worst 15.5 ms). |
| GUIDE-259 | systems | Two-stage fair-fight rating: Foundation 3 cold fair_fights ~50 -> ~32 ms, shown odds unchanged. |
| GFX-196 | world-ui | Own silhouettes for wolf, boar, tiger, deer and fox; `--fight=<enemy_id>` shot flag. |
| GFX-194 | world-ui | Puddle ripples in the ground pass; rain rings on ponds, streams and bog pools. |
| QA-235 | qa | Every region in every season rendered; ridge grid and market winter snow -> GFX-198. |
| C-387 | content | Star-Dew Qi Pill (260 qi, 20 stones) sold only at the Fallen Star Market. |
| PERF-010 | systems | Partial: shade grid built per lattice row (byte-identical); the rest -> PERF-013. |
| GUIDE-258 | systems | The lost-fight card's "A fairer fight" line is built from the entry's parts. |
| GFX-195 | world-ui | Ridge snow blobs: hashed cluster rims, flat snow with a shadow edge, fewer on the ridge. |
| WU-564 | world-ui | Partial: hens at the coop, a clear marsh gate, label z test; the shots -> WU-565. |
| QA-217 | systems | Sect-mission income drop bisected to C-356 and C-359 data changes (not rng drift). |
| PERF-009 | systems | Region ground passes run on raw bytes with integer hashes; worst cold region 1668 -> 586 ms. |
| WU-562 | world-ui | Partial shot pass: the Hunters' Bounty Board label no longer slides onto its board; the rest -> WU-565. |
| C-388 | content | Village happenings rest longer between repeats (boar, lost coin, pickpocket medians 14 -> 6). |
| GUIDE-257 | systems | Journal Errands lists every open teacher favor errand with its region, days and favor. |
| GFX-193 | world-ui | Grass patch tint quantised to 2x2 clusters with a dithered border: no soft smudges. |
| GFX-192 | world-ui | World map: land washes, a seeded river, paper-banner region labels and dashed roads. |
| GUIDE-255 | systems | fair_fights memoised per state; win_chance_at_least stops early; warm refresh 0.5 ms. |
| GUIDE-256 | systems | Optional deed `hint` phrases for teacher errands; fixed "help with on her..." and the contest journal line. |
| QA-216 | qa | The test runner keeps Settings in memory only (Settings.persist=false). |
| GFX-191 | world-ui | Ridge snow drifts only in Winter; the ridge gets a sparse cold alpine meadow (map.alpine_meadow density). |
| GFX-190 | world-ui | Rain puddles sit on their own layer above paths and below props; rain drips from the eaves and wets building bases. |
| C-386 | content | Five more teachers (Xiao Ling, Peddler Hei, Bai Qingwu, Ye Zhuoran, Broker Qian) get a once-only favor errand. |
| QA-194 | systems | The combat sim rates level-free roamers at their region's entry realm. |
| QA-177 | systems | Repeat report after C-265/C-271/C-268: boar, lost coin and pickpocket still met 13-19 times in 36 months (C-388). |
| QA-232 | qa | Screenshot scripts keep Settings in memory only (Settings.persist); screenshot_screens SCRIPT ERRORs 19 -> 0. |
| WU-563 | world-ui | A beaten beast rolls onto its back with a dust puff; shadow and plate follow. |
| GFX-187 | world-ui | Azure Peak gets alpine meadow ground life; the dark blob under the signpost is gone. |
| GUIDE-252 | systems | Partial: quiet Combat.resolve and precomputed stats make cold fair_fights 3x faster (Foundation still ~40 ms; GUIDE-255). |
| GFX-189 | world-ui | Winter woods sites draw as a grove of snowy pines and bare trees; no darkened crowns. |
| QA-231 | systems | The --chat-teacher sim takes the teacher's favor errand first: first style median day 104 -> 21. |
| GFX-188 | world-ui | Qingshi dwellings get seeded doorstep props: drying racks by season, a sleeping cat, hens. |
| WU-561 | world-ui | The beaten foe's shadow lies under its body and beasts are scaled to the stage. |
| GUIDE-253 | systems | The qi-pill hint scores every market within reach by qi minus the round trip; pill qi per stone is flat, so none wins yet. |
| GUIDE-254 | systems | The no-fighting-style hint names the teacher's favor errand while it is open. |
| C-384 | content | Every away-from-home teacher has buyable/gatherable likes each season (tested). |
| C-381 | content | Quill-Back Porcupine (Misty Forest, 5th layer) and the Quill-Stitched Jerkin recipe; baseline refreshed. |
| GFX-186 | world-ui | Misty Forest gets seeded canopy masses with undergrowth; the vertical tint bands are gone. |
| GFX-185 | world-ui | Dirt roads have a wandering verge and bed, broken wheel ruts, verge tufts and lanes that join the road (restored by the reviewer). |
| PERF-008 | systems | tests/sim/region_load_times.gd times every region; paved winter ground 5.4 s -> 1.6 s; all regions still over 250 ms. |
| GFX-182 | world-ui | Encounter woods scenes use the scene's own props (no village fence/lantern), tall edge trunks and leaf litter. |
| WU-557 | world-ui | Shot pass of the river, rain and spar screens; the shot scripts' tweens are killed on exit. |
| QA-230 | systems | Seed 8 opens its Core Disciple trial late because of its rolls, not a rule; no fix needed. |
| GFX-184 | world-ui | Rain days darken the ground and leave seeded sky-tinted puddles with ripples on paths and yards; half stay the next day. |
| QA-228 | systems | `--steward-chores` walks home when the duty is projected short: duty share unchanged (~54%), Foundation +329 days. |
| QA-229 | systems | `--qi-probe`: measured qi/day matches expected within 5%; early sect members just never leave Qingshi for the far spot. |
| QA-226 | qa | Hill dog odds pinned by stage (layer 1 ~7%, layer 3 45%); the Well-below-you reason is tested. |
| C-380 | content | Hunter Ma's once-only snare-line errand (day 0, +12 favor) and a deed `favor` key; errand + two liked gifts reach his lesson. |
| GFX-183 | world-ui | Broadleaf trees get a visible trunk, overlapping lit lobes, seeded size/lean, a trunk-following shadow and autumn leaf litter. |
| WU-560 | world-ui | Shot pass of WU-556/558, GFX-179/180; no defects (shop teaches line and greyed Buy states still unseen). |
| GUIDE-251 | systems | The qi-pill hint prefers a far pill when its qi after the round trip beats the local pill by 1.25x. |
| GFX-181 | world-ui | Village grass gets tuft clumps, lone tufts and a season detail; worn yards get ragged edges, pebbles and a tuft fringe. |
| WU-559 | world-ui | Explore odds say Mostly/Sometimes/Rarely quiet; season tasks and the inventory/auction price lines read right. |
| GFX-179 | world-ui | Every crag, ledge and boulder cluster on scree gets a downhill pebble fan and a contact shadow; random fans dropped. |
| QA-124 | systems | Crafter sim `--buy-travel` and `--region=`: from Misty Forest a talisman master crafts only by walking to the far market (0 -> 42 crafts). |
| SEASON-026 | systems | Season-task sim tries weekly and a second place: year-1 sets finished 1 -> 4 of 24. |
| C-383 | content | Nine once-only season encounters for newcomers in forest, mountain, marsh and village gaps. |
| WU-558 | world-ui | Event dialogues show the speaker's pixel portrait (rival or named NPC) per node; `--dialogue=<id>` shot flag. |
| GFX-180 | world-ui | Hedge map edges become a layered woodland edge: 2-4 blob rows, small trees, flowering shrubs and rocks, by region tree colour and season. |
| QA-169 | systems | `--trial-combo` (body art + armor + practised style): Core Disciple trial median 6 -> 31 in 100; the body art lifts the low seeds. |
| QA-164 | systems | `--buy-qi-travel`: the qi-pill buyer never travels because the hint only names a far pill when none is sold locally; arm table refreshed. |
| WU-556 | world-ui | Shop manual pane shows one teaches line; a greyed Buy says the shortfall; the sheet says Son/Daughter of the <surname> family. |
| GFX-176 | world-ui | Every market stall gets a cobbled lane to a street, court or building front; test checks each stall has one. |
| QA-171 | systems | `--activity-report`: days per activity until Foundation; missions (~210 days) explain the sect arm's ~264-day gap to the far-qi rogue. |
| WU-555 | world-ui | A moving NPC or roamer re-lays its name label against the place labels once it has moved 6 px (eased, throttled). |
| GFX-178 | world-ui | Streams meander (40 px, 320-520 px wavelength) with a breathing bed, pebbles, riffles and reeds; straight at bridges and places. |
| SEASON-025 | systems | Season-task sim waits for the wanted stall's market day, reach 6 days, `--season-report` failure reasons (year 1: 2 of 24 finished). |
| QA-227 | systems | `--steward-chores` sim policy and Inner Disciple/Foundation columns; policy almost never fires (far-qi members are 7 route days from the hall). |
| GFX-177 | world-ui | The marsh gets reed fringes, floating leaves, mist wisps, wet peat sheen and boardwalk posts, by season. |
| SEASON-024 | systems | `--season-tasks` sim plays festivals, buys and sells wanted goods, hunts at 40%+; an audit test finds every year-1 task within reach (sim still finished 2 of 24 cells). |
| WU-553 | world-ui | The duel stage draws a spar partner from their own world look; `--spar=<npc_id>` shot flag. |
| QA-165 | systems | `--heal-injuries` sim policy: healing costs the far-qi rogue ~140 days, about half its lead survives. |
| GUIDE-250 | systems | The away fair-fight search gets a reserve of 8 ratings and skips hopeless foes; `Combat.odds_kind` is public. |
| WU-551 | world-ui | Technique rows get kind icons and practice bars; the detail pane shows practice to the next level. |
| WU-554 | world-ui | Gear strip on the character sheet (icon, name, stats per slot; press to unequip). |
| SPAR-003 | systems | Guidance passes world flags to the spar and pointer checks, so the spar hint matches the spar action. |
| C-375 | content | Maple Carp at the Qingshi jetty in autumn; Xiao Ling likes it; every villager has 2 rain-free autumn likes. |
| WU-552 | world-ui | Encounter cards titled from name or scene + season; a river encounter scene on nine ford/river encounters. |
| QA-174 | systems | `--mission-monthly` sect policy; one mission a month does not meet the rank-1 duty in the sim. |
| C-378 | content | Hill Dog Fang loot, Fang Hunting Knife recipe, Hunter Ma likes the fang. |
| GFX-175 | world-ui | Alpine ground variety and seasonal touches on Myriad Peaks Ridge. |
| GFX-173 | world-ui | Ridge and Azure terrace gather sites draw as bowed contour steps that follow the hill, with scorched and misty variants. |
| QA-215 | systems | `--season-tasks` sim policy and `--focus=<id>` shot flag; the sim finished 1 of 6 year 1-2 season sets. |
| WU-548 | world-ui | Friendly spars show the duel stage, HP bars and a result block; the loser kneels. |
| C-379 | content | First-fights sim covers Qi Refining 1-7: the Fog Antler Stag, Mist Wolf and Mist Fox give fair fights for the middle layers. |
| GUIDE-249 | systems | Next steps names a fair fight one road away when home has only easy ones (reviewer fixed the cap and search). |
| WU-550 | world-ui | `--threat=` and `--encounter=` shot flags; all season encounters and three threat prompts rendered. |
| GFX-174 | world-ui | The Fallen Star Market has flagstone courts, cobbled stall lanes and edge-only packed earth. |
| ART-015 | systems | Month-end artifact energy from Foundation; the Spirit Garden opens about 200 days after the Inner World. |
| QA-224 | systems | The `--chat-teacher` sim policy gifts its way to a lesson: first style median day 104, all by lesson. |
| WU-549 | world-ui | Every map name gets the soft plate, with a 12 px minimum gap between labels on a row. |
| GUIDE-248 | systems | Far short hints for buying, selling, gathering and season tasks carry their route days. |
| FIGHT-002 | systems | The threat prompt and journal say why the odds are what they are (far above you, hits too hard, barely scratch, well below you). |
| GFX-171 | world-ui | The Meteor Crater Field is a bowl with a raised rim, slope rings, an umber floor and rim flags. |
| GFX-172 | world-ui | Ridge and Azure Peak roads have wandering edges and irregular flagstones. |
| WU-546 | world-ui | `--first-visit` shot flag; the slim arrival banner wraps between the status and Next-steps cards. |
| WU-547 | world-ui | A beaten beast lies on its side with stiff legs; the Defeated tag sits on its body. |
| C-377 | content | Feral Hill Dog and Spear Deserter: fair fights near home at Qi Refining 2-3. |
| C-376 | content | Eight season-gated newcomer encounters, two per season. |
| QA-223 | qa | Baseline refresh after LOG-009 and the label pass. |
| GFX-169 | world-ui | Autumn fights stand on ochre-olive ground with leaf drifts; spring has blossoms. |
| QA-220 | systems | `--chat-teacher` sim policy (first style median day 45, all by manual: the policy never reached a teacher). |
| QA-222 | systems | Sim days vs months explained: a sim month is 30 cultivation days plus action days. |
| ART-012 | systems | Seals open on time: progress energy stage 20 / realm 60, optional `unlock.spends`; Appraising Eye ~day 676, Inner World at Foundation. |
| WU-544 | world-ui | First arrival in a region names who teaches there; the world map tooltip lists teachers for visited regions. |
| TEACH-005 | systems | Styles learned from manuals, shops or sects are self-taught; teacher bouts, pride and graduation follow the real teacher. |
| GUIDE-246 | systems | The far-teacher short hint is whole on the card with the region short name and route days. |
| GFX-167 | world-ui | Ridge terraces are staggered bands with risers, drifts are mounds, the scree trail wobbles. |
| C-372 | content | Peddler Hei, Bai Qingwu, Ye Zhuoran and Broker Qian each give a one-time errand after you master their art. |
| C-373 | content | The four regional teachers each like at least two things a newcomer can get in their region. |
| SEASON-023 | systems | Season-task lines name the place and region and a stall that wants goods today. |
| GUIDE-247 | systems | The easy/fair fight hint from another region carries the route days. |
| WU-545 | world-ui | Villager and roamer labels nudge off place names or fade (LabelLayout.separate). |
| GFX-168 | world-ui | The market avenue stops at the crater; snow bowl neutral, scorched earth with a soot rim. |
| GFX-170 | world-ui | Azure Peak road is a mossy stone path with grass-tuft verges and lighter speckle. |
| LOG-009 | systems | Same-kind forecasts skip 2 days; practice without a new tier folds into one month-end line. |
| C-374 | content | Qingshi villagers have reachable likes in all four seasons (Xiao Ling likes ice perch in winter). |
| GUIDE-244 | systems | The Today chip keeps the whole first name; the arrival line is shortened with short_today_item. |
| GUIDE-245 | systems | No-style hint falls back to the nearest teacher at any distance ("... (12 days away)") and notes realm-gated arts here. |
| GFX-164 | world-ui | Myriad Peaks Ridge: wandering slope bands, a third of the speckle (map.speckle), a darker wobbling trail verge. |
| WU-543 | world-ui | `--friend=<id> --region=` keeps the region; `--flag=` and `--realm=` shot flags. |
| QA-219 | qa | First-hour and log-noise baseline refreshed after quiet stretches, teachers and Hunter Ma. |
| QA-212 | systems | `--artifact-report`: day each seal opens, Foundation day and energy by source per seed. |
| LOG-008 | systems | Tomorrow's omen forecast is folded when today has the same omen or boost kind. |
| GFX-165 | world-ui | Winter crater as one snow bowl; DuelStage.unit_hash uses a splitmix finaliser. |
| GFX-166 | world-ui | Ridge terraces as earth bands, ledges with a lit edge and foot stones, flat irregular pebbles. |
| C-368 | content | Every Qingshi villager has likes a newcomer can get in spring/summer; teachers two. |
| C-371 | content | Regional teachers get graduation lines and two after-lesson dialogue nodes. |
| QA-209 | world-ui | `screenshot_screens.gd --fight-region=a,b` renders combat_report_<id>/encounter_<id> staged in each region; shot-pass notes in HANDOFF. |
| C-367 | content | Peddler Hei, Disciple Bai, Ye Zhuoran and Broker Qian each teach one art through dialogue. |
| GFX-162 | world-ui | The crater ring draws under the avenue (snow ring in winter); marsh pilings are uneven, some lean; reed tufts in three shapes. |
| GFX-161 | world-ui | Fight and encounter backdrops follow the season (snow, autumn ochre) and the woods strip has two rows of pines with clearings. |
| GFX-163 | world-ui | Trees cast flat ground-tinted ellipse shadows sized by kind instead of grey discs. |
| GUIDE-243 | systems | The HUD Today chip names the first thing in full plus +N (Guidance.short_today_item); GUIDE-244 found it still cut in play. |
| C-370 | content | Hunter Ma and Xiao Ling each have a one-time errand with a keepsake once you graduate from their style. |
| TEACH-004 | systems | Graduation comes by any road, monthly pride keys are pruned, and pride goes only to the villager who taught the style. |
| WU-542 | world-ui | The villager card and the Arts screen show each taught style's practice-day state and who taught it. |
| GFX-159 | world-ui | The ridge ground has slate slope bands, half the speckle, dark-footed scree, lichen clumps and shale plates. |
| GFX-158 | world-ui | Winter paved markets keep dark swept streets with snow along the kerbs; earth lots get uneven snow with bare patches. |
| GUIDE-242 | systems | Next steps names the villager in this region whose weekly teacher bout is allowed today. |
| TEACH-002 | systems | A villager can teach up to 3 lessons (tiers strictly ascending). |
| GFX-160 | world-ui | Terraces are wide wobbling bands fading into the hillside with staggered crop tufts, no dark rim. |
| C-369 | content | Xiao Ling and Elder Mo have two after-lesson dialogue nodes each. |
| GFX-157 | world-ui | Fight backdrops: hazed far ridge of overlapping arcs, tiered pines with a darker front row, lit roof walls, Defeated tag on a plate. |
| TEACH-003 | systems | Levelling a style a living villager taught earns them favor (2/level, 4/month) and a remark on the next talk. |
| SPAR-002 | systems | A mastered style ends teacher bouts; the bout that masters it brings the graduation line and a one-time favor gift. |
| WU-541 | world-ui | Ready lessons read "ready" in gold on the Teaches lines; Talk reads "Talk (lesson ready)". |
| GFX-156 | world-ui | The marsh main road is a raised bed with a wobbling edge, a ragged mud verge and puddles, boards inside the bed. |
| GFX-155 | world-ui | The Fallen Star Market keeps paving to its streets; packed earth between them has loose flags, straw, cart ruts and kerbs. |
| WU-540 | world-ui | Covered person labels slide sideways; named villagers never stand on a hall stair. |
| GFX-154 | world-ui | Azure court is warm mid grey with four flag tones and faint joints; terrace bands overlap with earthen risers and planted rows. |
| GFX-153 | world-ui | Seasonal ridge snow drifts, polygon crags with a lit facet and snow cap, scree stepping stones visible on dark beds. |
| SKIP-003 | systems | One wake tip for meditation, gathering and work; the teacher hint hides 21 days after meeting that teacher. |
| SPAR-001 | systems | A villager who taught you a style spars with you weekly even while both are mortal (practice for that style, +1 favor on a win). |
| C-366 | content | Xiao Ling teaches Stone Skin at favor 40 through a dialogue choice (5 days). |
| WU-539 | world-ui | Named villagers' menus show Favor N with tier hearts, learned likes and locked-lesson progress; no empty band under Leave. |
| GFX-152 | world-ui | North-south marsh boardwalk narrowed, winter board gaps are dark ice with snow caps, the Reed Hall platform is long boards. |
| C-354 | content | Every almanac omen has three village greetings about the day. |
| GFX-138 | world-ui | Qingshi SE/SW houses get footpaths, a fuller square ring, ragged market scorch, spread crates, crater fence south runs. |
| TEACH-001 | systems | Npcs.teachings lists what a villager can teach and the favor each needs. |
| GFX-149 | world-ui | Scree roads are wandering grit trails with stepping stones, not flagstone grids. |
| WU-538 | world-ui | Settings toggle "Wake from long meditation for festivals and hunts" (default on) plus a one-time tip. |
| NPCFOE-001 | systems | Generated rival cultivators fight at x1.25 stats and no lower than one stage below you (enemies.json person_foes). |
| SKIP-002 | systems | Gathering and work of 7+ days stop at the wake day, paid pro rata; requests wake you the day before. |
| GFX-150 | world-ui | Stepped ledge silhouettes, puffy wisps, arced terraces, tonal ridge ground patches. |
| C-365 | content | Elder python and toad variants for sect hunts: Core odds 0.54/0.36 at Early, spoils +1. |
| WU-537 | world-ui | The villager menu shows a "Teaches:" block (up to 3, known greyed, locked show the favor/tier). |
| GFX-151 | world-ui | The Azure court has worn flags of varied widths, a processional strip, moss and cracks, and a deep tread stair. |
| GUIDE-241 | systems | Once you know a style, a weekly Next-steps line names the nearest villager with something new to teach. |
| C-364 | content | Core wilds retuned: the Core-year >95% bucket shrinks (50-95% now 48%); generated rival cultivators and two great beasts remain too easy. |
| GUIDE-240 | systems | After 3 wins against the hinted easy foe, the HUD fight line suggests a fair fight instead (wins_by_foe in LifeStats). |
| LOG-007 | systems | The weekly artifact energy line is gone; artifact gains ride on the progress line that caused them. |
| GFX-148 | world-ui | Ragged winter snow banks on road verges, blob contact shadows, a Reed Hall jetty, wheel tracks kept on narrow roads. |
| QA-218 | qa | Balance baseline refreshed after Hunter Ma and the quieter log: curious first style median day 45; first-hour 11.0 log lines/month. |
| GFX-147 | world-ui | Terraces draw as stepped ragged bands with crop rows; the Azure Cloud Hall court gets a kerb, snow edge and corner lanterns. |
| SKIP-001 | systems | A 7+ day meditation wakes early for a festival, hunted great beast, ripe crop, rent, request or secret realm opening. |
| GFX-146 | world-ui | The marsh boardwalk is a narrower wobbling walkway on pilings with mud verges and missing boards over murky water. |
| GUIDE-239 | systems | On day 1 the fighting hint names Hunter Ma (any favor gap in the current region) and how to win his favor. |
| C-360 | content | Short `eve` texts for the almanac omens the evening forecast line uses. |
| GFX-145 | world-ui | Myriad Peaks Ridge: tapered rock-band ledges, polygon boulders, ragged drifts, scree pebble clusters, puff-shaped wisps. |
| WU-536 | world-ui | The combat report shows the 2-line summary for easy fights with a "Show every blow" button. |
| GUIDE-238 | systems | The no-fighting-style hint names a villager who can teach one (here or one route away, favor within 10) and what they like; the manual hint adds "(N more stones)". |
| LOG-006 | systems | Combat.summary: a 2-line outcome + best blow for fights rated >= 90% won or <= 10% lost (GameState.last_fight_summary). |
| GFX-144 | world-ui | Groves with region-fitting undergrowth (map.decor.undergrowth_kinds) in Qingshi, Azure Peak, the marsh and Myriad Peaks Ridge. |
| SPOT-002 | systems | Named NPCs keep off road crossings, the arrival point and entrances, and 40 px from each other (Npcs.settle_named). |
| C-363 | content | Hunter Ma hides his lesson once Iron Fist is known (choice hide_if) and offers a repeatable "Spar with me." (+1 favor a week). |
| GFX-142 | world-ui | Lobed pond shores, ragged banks and snow drifts on ice, blob bases instead of plates, a notched Reed Hall platform. |
| GFX-143 | world-ui | Rented field plots drawn as ragged tilled fields with furrows, a wattle border and crops by stage and season. |
| LOG-005 | systems | Practice/cultivate rows fold across dawn lines; the great-beast eve reminder only when you hunt that beast. |
| QA-213 | qa | Economy sim twice as fast (Sects.mission_offered), output byte-identical. |
| SHOP-005 | systems | No hint or seller lookup names festival goods out of season (Items.in_season); only buy hints are remembered. |
| C-361 | content | Seven Core Formation encounters and three Core foes (storm wildcat, gale hawk, mire serpent) on the ridge, in the deep bog and on Azure Peak. |
| GFX-141 | world-ui | Roads with two wandering wheel tracks, footprints and ragged verges; an old-boards bog boardwalk. |
| GFX-139 | world-ui | Misty Forest trees grow in 7 seeded groves with glades, ferns, bushes, mushrooms and fallen logs. |
| SHOP-004 | systems | Buy hints skip out-of-season festival goods; buy_hints keeps 4 items per region and is saved. |
| GFX-137 | world-ui | Ragged PixelPlace.blob replaces ellipse plates under the herb patch, quarry, bog pool and abode base. |
| LOG-004 | systems | Back-to-back practice/cultivate lines fold into one row; gift delight joins the accept line; forecasts only on change or bad weather; great-beast eves only when near. |
| GFX-136 | world-ui | Withered Bone Marsh: murky ragged pools, mud patches, dead trees, half-sunk bones; Reed Hall on a stilted plank platform. |
| GFX-140 | world-ui | Tilled fields: ragged edges, furrow rows, seasonal crops, snow in winter troughs; scarecrow in Qingshi. |
| SPOT-001 | systems | At most 2 villagers per haunt place, overflow to the nearest free place; generated villagers keep clear of entrances. |
| C-362 | content | Hunter Ma teaches the Iron Fist for free (5-day lesson) once his favor reaches 15. |
| GFX-135 | world-ui | Ponds with ragged seeded shores, banks, shallows, reeds and stones; frozen ponds crack; streams meander. |
| GFX-134 | world-ui | Fallen Star Market: paved avenue from the City Gate, scorched ring with star shards and a rope fence round the crater, crate clusters. |
| SHOP-003 | systems | Optional item `festival` field: untagged merchants sell festival goods from 30 days before through the festival. |
| C-343 | content | max_realm foundation on 40 low-tier encounters and 19 sect missions; Core fights rated >95% 98% -> 55%. |
| SHOP-002 | systems | GameState.buy_hints: a shop in the region a hint named lists that item first (reviewer: reset per session and on purchase). |
| WU-534 | world-ui | a/an in the season kickoff, each coming festival named once, season card queued behind open screens. |
| GFX-133 | world-ui | Scenery.ragged_outline: ragged Qingshi square, patches and yards, flagstone ring round the tree, winter fills match the snow. |
| LOG-003 | systems | Tomorrow's omen only when an open season task needs it; no mission fight intro under a combat report; 12.1 -> 11.4 lines/month. |
| SEASON-022 | systems | Hunt `where` reads "(explore X in Region)" via SeasonTasks.with_where; sites_with_foe scans every foe. |
| WU-533 | world-ui | "(for you)" only for real needs (max 4), a technique hint puts its manual on top, no-gear footer only without gear. |
| GFX-132 | world-ui | Every Qingshi house gets a yard prop; footpaths take the shortest unblocked route (houses 3/4 still without one). |
| C-359 | content | procure_azure_crystal pays like an honest errand above the member price; reward floor test follows it. |
| WU-532 | world-ui | Items.useful_now / shop_order: hinted item, learnable manuals, realm pills and upgrades first, tagged "(for you)". |
| WU-531 | world-ui | HUD log card holds only whole messages (HUD.fit_messages); the reviewer fixed the scroll so the shot starts whole. |
| LOG-002 | systems | "The artifact drinks the change in you" posts at most weekly; gains fold into the next line. |
| GFX-130 | world-ui | Soft light/dark ground patches, clover/moss blobs, worn earth round places, patchy winter snow. |
| SEASON-021 | systems | Explore, threat, encounter and sect-mission wins count for the season hunt; SeasonTasks.where names the explore place. |
| C-358 | content | found_feather no_shop; almanac texts no longer open with their omen's name (validated). |
| GFX-131 | world-ui | Qingshi's roads read as walked dirt; map.square + Scenery.village_square (big tree, benches, lantern); tree groves. |
| QA-211 | qa | Log/first-hour re-baseline; --log-templates in log_noise.gd; first hour 12.1 lines/month (target 9.5). |
| GFX-129 | world-ui | Role accessories and robe colours for villagers (PixelFigure.accessories_for). |
| WU-530 | world-ui | Map day labels slide clear of region boxes, unexplored regions get a dotted border, journal and map share UIStyle.block. |
| ART-014 | systems | A won fight whose spoils the artifact likes adds one "The artifact stirs" line while a seal is closed, once a day. |
| C-352 | content | forage.signature for Misty Forest, marsh, Azure Peak (new Azure Pine Needles), ridge, market; Mugwort cut outside Qingshi. |
| GFX-128 | world-ui | Frost glints on snow, wooden-rimmed winter planters, market street snow caps no longer rungs. |
| WU-529 | world-ui | Only the nearest owner's name shows over the player; walking NPC names yield to shown place labels. |
| SEASON-020 | systems | SeasonTasks.preview_line: next season's asks in the last 7 days, in Today. |
| SEASON-019 | systems | Year 1 uses the first_year set; later years cycle the others; a third set per season. |
| QA-214 | qa | --season-report in simulate_curious_years: the curious policy never does season tasks (0 of 6 seeds). |
| GFX-127 | world-ui | Scenery.village_yards: footpaths, packed-earth yards, seeded props, varied roofs in Qingshi. |
| C-356 | content | Sect mission pay retuned (gather_spirit_herbs 36, procure_azure_crystal 84); economy baseline refreshed. |
| WU-527 | world-ui | Artifact screen "Grows from" and "Lately" lines; Artifact filter in the message log. |
| WU-526 | world-ui | Market pennants draw inside the stall, the sect gate signboard slides clear of landmarks, far realm tags refresh on any stage change. |
| GFX-124 | world-ui | Dirt roads drawn as walked earth (ruts, stones, worn edges). |
| GFX-125 | world-ui | Marsh pools, reeds, lily pads and standing water under trees; ice and snow-capped reeds in winter. |
| WU-528 | world-ui | World Map side panel in short headed blocks (Today, You here, Shops, Places) with caps. |
| GFX-126 | world-ui | Fallen Star Market streets, cobbles, herb planters, stall props and a scorched ring round the crater. |
| ART-011 | systems | artifact_gains log (last 6, saved), gain_text/energy_sources/next_seal_line, Today artifact line. |
| FOLK-034 | systems | Omen talk hash-picked (no rng draw); village news for bounties and village hunts. |
| ART-013 | systems | energy.tag_mult: beast materials 2x, trophies/ore/blood arts 1.5x, keepsakes refused; Feed list sorted by energy. |
| SEASON-018 | systems | Year 1 hunt tasks ask for the Weak wild boar; test pins no year-1 hunt above Dangerous. |
| QA-210 | qa | test_first_spring.gd: year-1 Spring catch/forage reachable; stag was Deadly (fixed by SEASON-018). |
| WU-521 | world-ui | Stronger mist bands (capped so labels stay readable) and brighter market lanterns. |
| CAL-012 | systems | On an omen day Next steps says what it is good for and where. |
| FOLK-033 | systems | Villagers sometimes mention the day's omen (optional almanac.json talk lines). |
| WU-522 | world-ui | Person labels never sit on their own figure; far NPC realm tags refresh on breakthrough. |
| C-353 | content | Fallen Star Market gets an Auction Ledger Copyist and a Lantern-Hanger job (best repeatable 3 stones/day). |
| ART-009 | systems | The artifact gains energy from stages, realms, first wins, discoveries and secret realm floors; hum + hint when a seal can break. |
| ART-010 | systems | The artifact whispers once per life at 8 moments (data/artifact.json whispers, new log category artifact). |
| QA-035 | qa | Economy sim: disciples take a sect mission every month one is ready; mission vs work stones per profession. |
| ARCH-001 | systems | src/core no longer uses src/world classes (PlaceLooks), pinned by test_core_isolation; arrival warnings use the arrival season. |
| WU-524 | world-ui | The artifact screen: life pips, an energy bar toward the cheapest seal, four power cards, feed/anchor buttons. |
| C-342 | content | 288 more encounters get a scene picture from their region (village, ridge, ruins, woods, reeds, trail, cave). |
| C-351 | content | Every almanac omen has 3 text variants in the village-almanac voice. |
| WU-523 | world-ui | Banners (milestones, new friends) wait until every modal screen is closed. |
| WU-525 | world-ui | The clan screen shows an n x n clan relation grid with coloured standings instead of pair sentences. |
| WU-519 | world-ui | Test audit of every fixed-width HUD line (status, hunt, key strip): all fit or end in an ellipsis. |
| GFX-123 | world-ui | Myriad Peaks Ridge gets crags and wind-streaked snow drifts (map.high crags/drifts); Azure Peak gets crags. |
| SEASON-017 | systems | Dangerous/Deadly season hunt tasks say how: join the village hunt on Day N, or come back stronger. |
| LOG-001 | systems | Dawn folds marks, omen and reminders into at most 3 log lines (VillageCalendar.dawn_lines). |
| FISH-011 | systems | Fishing.is_iced: winter ice-fishing drops weather fish, Today says "ice-fishing at", the trip chops a hole. |
| WU-520 | world-ui | Far NPC labels show the name only (plus a realm tag for stronger cultivators); the full title up close. |
| GFX-122 | world-ui | Paved roads without near-black holes (Scenery.paving_shade); winter boardwalk planks stay brown. |
| GUIDE-237 | systems | Wildlife.region_threat: the travel menu names Dangerous/Deadly beasts; one danger warning per region per season on arrival. |
| WU-518 | world-ui | Crisp small text: subpixel positioning off, normal hinting, and a 14 px floor on UIStyle.label. |
| WU-517 | world-ui | Today card in three headed blocks (Here today, The season's tasks, Around the village), 5 rows each with '+N more'. |
| GFX-121 | world-ui | `hall_ground` on sect halls (stone, planks or terrace): the marsh hall on a stilted boardwalk, Azure Cloud Hall on a pale stone terrace. |
| C-344 | content | Eight Core Formation encounters on Myriad Peaks Ridge (elder's test, rival duel, lightning vein, core-devourer's bargain...). |
| WU-516 | world-ui | The stats panel's region name gets the width it needs; only a name that cannot fit trims with an ellipsis. |
| GFX-120 | world-ui | Mist bands turn blue-grey on snow (`--fog` shot flag); every fishing place stands at its jetty's land end. |
| FORAGE-006 | systems | Optional `forage.signature` takes forage slot 0 when in season; Guidance lists it first (data in C-352). |
| QA-208 | qa | Balance baseline refreshed, drift explained per commit (parts 3 and 5); log noise 8.6 -> 11.6 lines/month. |
| FOLK-032 | systems | Generated villagers keep 64 px from travel places and the arrival point and stand 28 px apart. |
| GFX-119 | world-ui | Fallen Star Market's `map.market`: awning stalls, handcarts, lantern strings and shoppers walking stall to stall. |
| TODAY-004 | systems | 'Tomorrow: <Name>.'; market day, market line and wanted line fold into one; omen text may be an array. |
| CAL-011 | systems | Dawn posts the day's omen (category almanac); the calendar reminders end with tomorrow's omen. |
| WU-515 | world-ui | Roamer spots keep 260 px from every travel place and the spawn; wander targets never enter the ring (reviewer wired the live roamer). |
| C-350 | content | Repeatable paid errands in Misty Forest (Woodcutter Bai) and Fallen Star Market (Porters' Foreman). |
| FISH-010 | systems | CastBar posts only the quality line; GameState.fish alone posts slip lines (one fishing story in the log). |
| C-349 | content | Six more almanac omens (fishing, gathering, trade, gifts, practice). |
| WU-514 | world-ui | The arrival banner keeps only Qi and danger; today's line is said once (log and Next steps). |
| WU-513 | world-ui | Almanac line under the Today date header; omen glyphs, legend and name on the calendar. |
| WU-507 | world-ui | Stats panel: region name on its own row with a coloured Qi chip, ellipsis on the sect line. |
| GUIDE-236 | systems | Guidance.sect_home_hint: a new disciple is told where their sect's home hall is and what is there. |
| SECT-006 | systems | Steward chores at your own sect hall (spec docs/specs/SECT-006.md). |
| GFX-118 | world-ui | Misty Forest mist bands stronger (map.mist), summer trees in leaf. |
| CAL-010 | systems | Almanac (data/almanac.json, Almanac system): a daily omen boosts fishing, gathering, gifts, selling or practice; shown in the journal. |
| GFX-117 | world-ui | Ground shadows under every figure and a player outline/ring so you stand out in the crowd. |
| WU-510 | world-ui | Slimmer arrival banner that leaves the village visible. |
| GFX-116 | world-ui | Winter streams freeze, jetties run out over the water, the ridge gets map.high. |
| GUIDE-235 | systems | Sects.contribution_value: honest mission pay net of consumed items; cleaner Earning lines. |
| FISH-009 | systems | Regression test: a fresh character's first Qingshi trip always lands a fish (core was already right). |
| WU-511 | world-ui | LabelLayout.person_offset: NPC names never sit on place names; stats panel alpha. |
| C-348 | content | Project news lines for the well, jetty and terraces; three more family birthday lines. |
| GFX-115 | world-ui | Scenery.water_decor: drifting glints, lily pads on clear ponds, reed tufts on murky ones, stream banks and pebbles by bridges. |
| C-346 | content | A guest_line for each of the four festivals in its own mood. |
| WU-509 | world-ui | The Today tab skips a main card that only has People lines; the date heading moves to the first card with lines. |
| GUIDE-234 | systems | Earnings: a sect mission row for a disciple at a hall (stones a day, contribution; Dangerous+ skipped). |
| WU-508 | world-ui | Labels over the player's body fade to 35% (LabelFade.alpha_for); a place label under the [E] chip hides. Parts 3-4 -> WU-511. |
| SEASON-016 | systems | Optional season_tasks.json project `news` lines, used 70% of the time for that project's stage news; the jetty ships 2. |
| C-347 | content | Repeatable headman errands in Qingshi: chore_odd_jobs (2 days, 9 stones, weekly), chore_haul_water (1 day, 4 stones). |
| GUIDE-233 | systems | Earnings.one_time_rows: up to 2 "Once:" headman jobs on the Earning card; one beginner's-luck line after "got away". |
| GFX-114 | world-ui | Winter look: snow-blue tree shadows, snow-capped woods sites, dormant herb beds, ice holes at frozen jetties. |
| GFX-113 | world-ui | Azure Peak map.high: lanterned stone stairs, railed hall court, cloud wisps, a cloud-sea band, leaning pines. |
| GFX-112 | world-ui | Roads drawn per ground (Scenery.path_tiles): slabs on scree/paved, planks on murky bog, a muddy track with puddles, rutted grass; snowy edges in winter. |
| GUIDE-232 | systems | Earnings.far_row: one neighbouring-region row when it pays 1.5x after the round trip; the journal and empty-purse hint name it. |
| FOLK-031 | systems | People card festival-guest line: friends who cheer (max 3 names) and last year's champion; optional world_events.json guest_line. |
| GUIDE-228 | systems | HUD short form of the meal-before-a-fight hint ("Eat Eel Congee: 55 -> 63"). |
| C-341 | content | Herb Slope Terraces stage texts, done_line and done_text in the village's voice; Herbalist Lan likes spirit_herb. |
| C-204 | content | Talisman Master income checked (d365 471 vs 512/373/314): no change needed. |
| WU-506 | world-ui | encounters.json scene and regions.json map.wild_look; PlaceLooks.scene_look; the strip draws the right place (10 scenes set). |
| WU-505 | world-ui | BeastArrow.clamp_marker keeps the beast pointer off HUD panels; strict label test covers all six regions. |
| FISH-008 | systems | A first fishing trip that comes home empty lands one common fish (Fishing.beginner_catch). |
| GUIDE-230 | systems | Earnings chore rows only from repeatable, non-negative, enemy-free deeds (Deeds.is_repeatable); one festival line on its first day. |
| GFX-111 | world-ui | Cliff rims, cliff landmarks and relief ledges drawn as jagged shaded rock (Scenery.jagged_outline). |
| CAL-009 | systems | Calendar and Today list your own, your spouse's and children's birthdays; a birthday chat with family gives +3 favor (family_birthday_lines). |
| C-340 | content | player_birthday_gift for Herbalist Lan, Hua Qingyi, Ye Zhuoran and Bai Qingwu (new found_feather); no more promises of missing mechanics. |
| WU-502 | world-ui | The Herb Slope terraces are drawn by stage (--terraces=N). |
| GFX-109 | world-ui | Myriad Peaks Ridge and Azure Peak get code-drawn relief: lit rock ledges, boulder clusters, snow drifts (map.relief). |
| WU-500 | world-ui | Qingshi jetty posts stand only in or at the pond; strict label-vs-footprint test fixes 8 Qingshi pairs. |
| C-334 | content | encounters.json `figure` set on ~260 encounters with a clear subject. |
| C-335 | content | 10 trophy_comment lines and wall-fit descriptions for all 11 great-beast trophies. |
| GUIDE-227 | systems | Far reminders keep events you can still reach; Earnings gathering row models herb lore, bonus units and weather; missing chore/craft tests. |
| FOLK-030 | systems | Optional npcs.json player_birthday_gift given with the villager's birthday line once a year (Hunter Ma: 2 venison). |
| GFX-110 | world-ui | Map margins use the region's ground fading to dark; regions.json map.edge (hedge, treeline, wall, cliff, reeds) on all six regions; --edge shot flag. |
| QA-042 | qa | First Core Formation year sim (realm 3) in balance.sh plus a loose guard; fights there are almost all trivial (-> C-343). |
| WU-501 | world-ui | Season card strip in the season's own colours; encounter strip draws the explored place's look (GameState.last_explore_look). |
| GUIDE-229 | systems | Guidance.empty_purse_hint names the best Earnings row when stones run short. |
| SEASON-015 | systems | Fourth Qingshi project: the Herb Slope Terraces (3 stages, +10% chance of an extra herb unit each). |
| WU-504 | world-ui | Journal Today tab gets "Earning here" and "People today" cards (Guidance.people_today_lines). |
| C-339 | content | items.json icon on 32 items (lanterns, food, drink, charms, scrolls). |
| RV-019 | world-ui | screenshot_screens.gd runs again in --first-hour/--title/--creation; the Qingshi jetty sits on the pond. |
| WU-495 | world-ui | One season card (strip, Looking back, Coming up) replaces the recap and kickoff banners; waits for the realm card. |
| FISH-007 | systems | Fishing rank gives bonus draws on a caught trip (Fishing.bonus_draws), so rank shows in income. |
| CAL-008 | systems | Far festival/event/realm reminders carry the travel time or are dropped when you cannot arrive in time. |
| GUIDE-225 | systems | Hints probe with swap-and-restore instead of deep-copying the character. |
| C-338 | content | Fishing prices and weights cut so a Novice earns about 1.5-2.5x a gathering day. |
| GFX-105 | world-ui | A code-drawn pixel title scene behind the main menu. |
| GFX-106 | world-ui | Item icons by kind (items.json `icon`, ITEM_ICON_KINDS): food, drink, lantern, charm, trophy and more. |
| GFX-107 | world-ui | Fight backdrops: far ridge, near layer and foreground props per region (DuelStage.backdrop_layers). |
| GFX-108 | world-ui | The world map is a parchment map with terrain per region. |
| GUIDE-226 | systems | Earnings.earning_options: stones per day for the best chore, gathering, fishing and craft here; journal "Earning here". |
| C-336 | content | player_birthday_line for every named Qingshi villager and every named villager with a birthday. |
| WU-499 | world-ui | Blossom Crack, Old Shrine and the Old Well labels clear their neighbours; no empty band above the map. |
| C-337 | content | Season recap templates: 3 per key plus quiet lines, in the village chronicle voice. |
| WU-498 | world-ui | The Wandering Merchant moved off the pond corner; Qingshi's pond, jetty and rock labels no longer overlap. |
| QA-203 | qa | Part 1 of the shot pass: `--hud-panel` crops right at 1280x720, the multi-region run clears the log per region (rest -> QA-207). |
| C-331 | content | Every dish-teaching villager has a `taught_dish_line` in their own voice. |
| C-313 | content | Two Foundation missions per sect hall; the Qi Refining missions they replace stop at Qi Refining. |
| WU-497 | world-ui | Character creation in two columns: framed pixel portrait, element bars, talent badge, attribute bars. |
| FOLK-029 | systems | Optional npcs.json `player_birthday_line`: a villager's own words on your birthday. |
| SEASON-014 | systems | The season recap's lines live in data/season_tasks.json `recap` (templates, own rng stream). |
| GUIDE-224 | systems | `route_days(..., ignore_realm_gates)` replaces a character copy per HUD refresh; the recap names the village project stage. |
| WU-496 | world-ui | screenshot_screens.gd opens screens through the HUD's modal path; `--trophies` check. |
| SEASON-013 | systems | A season kickoff banner: village tasks, festivals and in-season beasts/forage of your region. |
| QA-206 | qa | tests/sim/simulate_fishing.gd and a fishing balance section (Novice/Angler/Old Hand, jetty 0 and 3, vs gathering). |
| C-310 | content | 3 win and 3 lose lines per festival contest; rival festival lines grown to 6+6. |
| COOK-003 | systems | Cooking a dish a friend taught you: that friend's next chat within 14 days says their taught_dish_line (+3 favor, once per dish). |
| WU-491 | world-ui | The region name card is dismissed when a HUD modal opens; the combat report rating uses the HUD's wording and odds; 4+ choice encounters use a 72 px strip. |
| GUIDE-223 | systems | Short forms for the HUD fair-fight and hunt lines; whole-phrase Today shortening; realm-gated trip days. |
| C-329 | content | trail_done_text for the four great-beast trails, real names for the great_trail milestones, 6 news.great_trail lines. |
| C-333 | content | folk_greetings.player_birthday grown to 10 lines (no per-NPC field existed -> FOLK-029). |
| ENC-014 | systems | Optional encounters.json figure (none/beast/robed/villager/child/elder/spirit/treasure/corpse), read before the tag guess; 12 examples. |
| WU-492 | world-ui | Crafting window: nearest two sources per missing ingredient (+N more), All sources toggle, scrolling detail with pinned buttons. Planner shot: fits 1280x800. |
| GFX-104 | world-ui | Explore woods draw five shaded crowns with trunks and a path; herb woods add sprigs. Planner shot: reads as woods. |
| WU-493 | world-ui | Family screen: framed 5x portrait, list-row figure icons with realm/age, died-at-age lines, empty-family line. |
| FOLK-028 | systems | On your birthday the family dish waits when you enter or wake at the Family Home; without family a Close friend leaves a small gift. |
| SEASON-012 | systems | Season recap (LifeStats.season_summary, season_start_stats snapshot, HUD banner): village tasks, project, up to 3 activity lines. |
| WU-494 | world-ui | Hung trophies draw as plaques on the home's wall; the pond jetty builds up by stage; a cake marker over the player on their birthday; --jetty=N. |
| C-332 | content | Jetty stage texts in the village's voice; the Pearl-Backed Bream bites at the Qingshi pond once the jetty is whole; Hunter Ma likes it. |
| QA-204 | qa | Clean balance baseline: every drifting section explained and refreshed; `--check` is trustworthy again. |
| WILD-022 | systems | Hang up to 3 great-beast trophies at your home (Trophies, trophy_menu): +1 renown a month each in that region; visitors remark on them (family.json trophy_comment). |
| SEASON-011 | systems | After the well, finished season sets repair Qingshi's Village Pond Jetty in 3 stages (+5% catch each); the whole jetty unlocks a gated pond fish. |
| WU-490 | world-ui | The hen coop is a pixel coop (Sprites key `coop`); hens gather and peck by it on a fed day. |
| WILD-021 | systems | Beating the last great beast of a region's trail sets great_trail_done_<region>, posts trail_done_text and earns a great_trail_<region> deed. |
| C-330 | content | festival_memory_line for every villager who can invite you to a festival, 6 more festival_memory greetings. |
| WU-489 | world-ui | The message log hides until its first line; crossroads labels in Qingshi no longer touch. |
| WU-488 | world-ui | The encounter card opens with a 600x120 scene strip (region backdrop, player, a beast/robed/treasure figure from the encounter's tags and id words). |
| FOLK-027 | systems | A rolled player birthday (age still counts at New Year): friends greet you that day (+2 favor once a year), family gives you a dish; sheet shows "Born:". |
| C-328 | content | festival_lines for every named villager in a festival region, 8 more folk_greetings.festival lines. |
| GUIDE-222 | systems | regions.json short_name; Guidance.short_goal shortens the HUD goal line; short_hint has fight-line short forms (the HUD fair-fight line itself still unshortened, see GUIDE-223). |
| C-327 | content | Middle steps on the Misty Forest, Azure Peak and Marsh great-beast trails. |
| GFX-103 | world-ui | Region signposts fit the full name (wider board, smaller font, two lines); regions.json map.water clear/murky/icy ponds. |
| GFX-102 | world-ui | Gather sites take a regions.json look (patch, rubble, crater, crystal, frost, terrace, bog). |
| GFX-101 | world-ui | The player has a light outline and darker shadow; the target highlight is four gold corner brackets. |
| WU-484 | world-ui | Generated villagers and walkers keep off building footprints and the gate (Npcs.place_keepout/settle_stand); named shopkeepers stand at their door. |
| WU-485 | world-ui | Painted camera margins on all four sides (World.margin_rects); festival caption no longer covers the [E] chip; choice menus fit their content. |
| GFX-100 | world-ui | regions.json map.building_style (thatch/tile/stone/stilt/log) recolours and reshapes buildings per region; contact shadows. Planner shots 12:10: Azure tile and marsh log/stilt read well. |
| WU-486 | world-ui | Emote bubbles (love/happy/sweat) over villagers on gifts, friend scenes and lessons; ! bubble for waiting lessons (Folk.gift_reaction, EmoteBubble). |
| WU-487 | world-ui | screenshot_first_hour.gd --realm-open; SecretRealms.next_open_day_in_region; open clefts and gates read as open. |
| GUIDE-220 | systems | Guidance.short_hint / hints(short=true) squeeze HUD Next steps to 42 chars; journal keeps full text. |
| GUIDE-221 | systems | Today lists what an open festival stall sells and announces tomorrow's fixed-date festival; calendar entries list up to 4 wares. |
| CRIT-002 | systems | Village Hen Coop (coop place type): Scatter grain once a day so tomorrow's hens lay surely (hen lays.feed data). |
| FOLK-026 | systems | A Close friend who came to a festival contest as your guest recalls it on the first chat within 10 days (+2 favor once). |
| WU-483 | world-ui | Walking villagers' stops keep 40 px off travel points and 24 px off place rects (Npcs.nudge_stop); labels on a building move below the figure. Planner shots: the marsh gate and roof cases remain -> WU-484. |
| GFX-099 | world-ui | UIStyle.panel_style() is a code-drawn FramedPanel (gold outer line, inner line, corner brackets); bars get a fill outline; key bar draws key caps. |
| WILD-020 | systems | Great-beast `return` nests to any depth (Wildlife.great_chain); _great_pick walks the first unbeaten step; rumor, trophy and village book follow the chain. |
| C-314 | content | Festival stalls sell 4-6 wares each (11 new items: charms, kites, cakes, lanterns, soups); four villagers like some of them. |
| WU-482 | world-ui | Cake marker over a friend on their birthday, "- birthday today" on the [E] chip, Cook menu hints "???" taught dishes, People cards turn the birthday gold within 7 days; --birthday= shot flag. |
| GFX-098 | world-ui | Secret-realm entrances take a regions.json look (rift, cleft, seal, gate, tomb, pavilion) with closed and open templates; PlaceLooks.REALM_LOOKS. |
| FOLK-025 | systems | Villagers say a festival line once per festival per year (npcs.json festival_lines, family.json folk_greetings.festival); birthdays win. |
| GUIDE-219 | systems | find_note skips untaught dishes; lessons_waiting skips a friend who taught today; EXPLORE_LOOKS moved to core PlaceLooks. |
| C-326 | content | Birthdays and birthday_lines for the 15 other named villagers, 5 more birthday_thanks lines, a catfish like for Old Monster Gui. |
| GFX-097 | world-ui | Festival bunting at 2x with pennants, 6-8 poles, red/gold ground cloth; festival looks in data/world_events.json `decor`; no forage in the ring; bottom camera band painted. |
| GFX-096 | world-ui | Field landmarks follow the season (sprouts, tall rows, golden rows, snowy furrows); the rented field draws tilled beds (Scenery.field_look). |
| GFX-094 | world-ui | Forage pickups are 16x16 sprites at PX=2 (sprig, mushrooms, ore, sack) with a shadow; items.json forage_tint. |
| C-323 | content | Elder Mo, Xiao Ling and Hunter Ma get festival spots just outside the festival ring. |
| FOLK-022 | systems | Named NPCs take an optional birthday {month, day} and birthday_line; liked gifts that day post a birthday_thanks line. |
| GUIDE-218 | systems | Today lists a named friend's birthday and a waiting lesson with where they stand; the journal lists waiting lessons. |
| COOK-001 | systems | Taught home meals (recipes.json taught), CharacterData.known_dishes, learn_dish effect; Cook lists only known dishes. |
| C-324 | content | The tiger's failed back-away gives the torn_shoulder injury; its offering and the fevered child's take tag offers. |
| GFX-095 | world-ui | Explore places take a regions.json look (cave, woods, ruins, reeds, ridge, trail) drawn by PixelPlace templates. |
| WU-480 | world-ui | People cards grow to fit; a reached, untaught lesson reads "Talk to <name> to learn something". |
| WU-481 | world-ui | Place labels outrank villager and beast labels; NPC spots validated 40+ px from signposts. |
| C-325 | content | Xiao Ling, Hunter Ma and Herbalist Lan teach the four taught dishes through learn_dish lessons. |
| GFX-091 | world-ui | Misty regions (map.mist >= 0.5) draw 3-5 soft mist bands that drift sideways (MistBands), still under reduce_motion. |
| WU-478 | world-ui | The [E] chip follows its target every tick; festival crowd figures keep 28 px clear of the player. |
| C-321 | content | Real FOLK-020 lessons for Elder Mo, Xiao Ling (cooked dishes), Hunter Ma, Herbalist Lan and Hua Qingyi. |
| WU-477 | world-ui | Village book people cards show "Taught you: <effect>" or "At <tier>: ???" per lesson. |
| FOLK-021 | systems | Friend scenes may need a weather; lessons only where the teacher stands; friend_scene carries gift_id; new lesson_taught signal. |
| ENC-012 | systems | Effects key `injury`; encounter choice `offer {tag,count}` (disabled without goods, takes the cheapest). |
| QA-205 | qa | SeasonTasks.project_index replaces Well.project_index; tools/test.sh compiles every tests/sim/*.gd with --check-only. |
| GUIDE-217 | systems | Today lists "Hen's Egg by the coop (N left)"; the festival line uses ends_phrase on its last two days. |
| GFX-092 | world-ui | Friend card gift row shows the item icon; eggs and well water float "+1 <name>" above the player. |
| GFX-093 | world-ui | Festival poles with bunting ring the square (lanterns glow at night festivals), plus a festival look (boats/drum, willow/kite); FestivalDecor.layout. |
| WU-479 | world-ui | A lesson shows on the friend scene card with the teacher's portrait and a gold "You learned: ..." line, queued like friend scenes. |
| C-322 | content | Four Well Water / Hen's Egg dishes and six more project_stage news lines. |
| C-320 | content | Mist-Crowned Tiger: fight, back away (spirit check; a failure costs a day and Shaken Nerves) or leave 2 venison for forest renown. |
| CRIT-001 | systems | Qingshi's hens may leave a Hen's Egg by the coop each day (Critters.eggs_today, egg_pickup place, per-day world flag). |
| WU-476 | world-ui | The friend scene card shows the villager's figure at 5x in a framed portrait beside the text. |
| SEASON-010 | systems | Each Founder's Old Well stage posts a project_stage news line; villagers greet you about it. |
| GUIDE-216 | systems | Journal fight lines use the Easy/Fair prefix with odds once; event and festival lines say "ends today" / "last day tomorrow". |
| GFX-090 | world-ui | Qingshi's festival square moved to [660, 800]; villagers and crowd stand on a ring off stalls and landmarks; validated 160 px from map edges. |
| GFX-087 | world-ui | The Founder's Old Well is drawn by project stage (weeds, rope and bucket, roof, ribbon), labelled (n/3) until whole; --well=N shot flag. |
| FOLK-020 | systems | Named villagers can teach one lasting lesson per friendship tier (npcs.json lessons, Folk.due_lessons, GameState.lessons_for). |
| C-319 | content | Work, market, rain and rest spots for the 15 other named NPCs in five regions, 40 px clear of places and landmarks. |
| C-311 | content | Season task set 1 audited; a second 3-task set per season and a keepsake payout per season (lantern, realgar wine, moon cake, osmanthus wine). |
| FOLK-019 | systems | Named NPCs with dialogue say one remembered line when it opens: gift memory, else village news once per item. |
| WU-475 | world-ui | Crowds show at most 3 nearby labels (LabelLayout.crowd_keep); the [E] chip falls back to just above the figure. |
| RV-018 | world-ui | Draw water on the Founder's Old Well once whole (need line before); the season board names the current village project. |
| WU-474 | world-ui | The interact prompt is a compact chip beside its target (also when the label is hidden); the fallback is text-sized. |
| QA-202 | qa | src/ui EventBus/GameClock lambda connects became bound methods; the signal audit builds and frees the HUD twice. |
| FOLK-017 | systems | Named villagers get daily spots (work, market, rain, festival, rest weekday) via Folk.spot_for; they walk there on a new day. |
| C-316 | content | Friend and close-friend scenes for Elder Mo, Xiao Ling and Hunter Ma, plus 4 any-villager scenes, gifts on most. |
| WU-473 | world-ui | Combat report floats damage numbers (gold on solid/critical, grey on glancing) and a technique banner per blow. |
| C-318 | content | Six village news lines per kind (contest_win, great_beast, shrine_stage, season_done, breakthrough). |
| GFX-088 | world-ui | Hens run from the player and drift back, ducks paddle away, butterflies rise (Critters pure helpers, CritterLayer). |
| GFX-089 | world-ui | Misty Forest: darker bluer ground, 120 mostly-pine trees, mist all year, new map.decor.edge_belt. |
| FOLK-018 | systems | World flag gift_memory keeps each villager's last gift; the next chat within 30 days says a line; village book shows it. |
| SEASON-009 | systems | Season tasks may be `sets`; SeasonTasks.tasks_for picks sets[(year-1) % n]. |
| WU-472 | world-ui | The key-hint bar fades while the player stands behind it; camera limits let the player scroll clear of the HUD. |
| GUIDE-215 | systems | Next steps: nearest fight first with route days, away chores rated, odds once, festival end worded as last day. |
| FOLK-016 | systems | EventBus.friend_scene carries npc id and gift name; the card shows "They give you X."; waits for the contest card. |
| SEASON-008 | systems | After the shrine, finished season sets restore the Founder's Old Well in 3 stages (+5% crops each); whole well gives Well Water daily. |
| C-312 | content | Foundation roamers in the marsh and ridge (Grey-Fang Alpha, Moon-Ridge Elk, Mire-Scale Caiman, Mist-Shrouded Leopard). |
| WU-470 | world-ui | Calendar day number and icons on one row so labels fit; every festival day tinted with a band, the name on day 1. |
| WILD-020 | systems | Wild regions list in-season forage and fat beasts from the window start on the calendar and Today. |
| FOLK-015 | systems | The newest deed is village news for 7 days (world flag village_news); villagers greet you with it. |
| CAL-008 | systems | A running festival marks every one of its days on the calendar (festival_day entries); Today says day n of N. |
| GFX-086 | world-ui | Hens, ducks and butterflies in Qingshi (`map.ambient_critters`, Critters + CritterLayer), by season, seeded per day. |
| WU-469 | world-ui | Season board: drawn check boxes, the place on a dim second line only when the text lacks it, modal sized to content; shop notes under the title. |
| WU-471 | world-ui | Next steps lines get a kind icon (goal, fight, today, season, other); `--hud-panel` shot. |
| QI-003 | systems | Exploration.effective_density + format_density: one qi number in the HUD, arrival card, travel note, map and abode hints. |
| C-317 | content | First great beasts capped at Qi Refining; their returns and the crane/ram retuned as Foundation fights; baseline refreshed. |
| QA-201 | qa | No lambda connects to EventBus/GameClock in src/world; test_signal_audit scans src/world. |
| FOLK-014 | systems | any_villager scenes only for living sect-less villagers of the region; SeasonTasks.where memoized per day; "people" log category. |
| GFX-085 | world-ui | Qingshi has a festival square: the contest stall and its crowd gather there, clear of every place; mortal villagers drop "(Mortal)". |
| WU-467 | world-ui | A friend scene card (figure, name, text, focused Close), queued behind dialogue and road cards. |
| GFX-084 | world-ui | Shrine incense smoke and a warm altar glow only while the incense burns; a restored stage in view plays a confetti puff; `--incense` shot. |
| WU-468 | world-ui | Next steps lines capped at ~2 wrapped lines, cut at a clause; the Today line shows only its first item. |
| FOLK-013 | systems | Friend scenes: optional npcs.json `scenes`, one a day on talking to a friend at the right tier, some with a gift; EventBus.friend_scene. |
| QA-200 | qa | Tests that change Settings fail unless they restore them; settings.cfg checked after the run; `--calendar-month=N` shot. |
| GFX-083 | world-ui | One decoration per festival (boat prow and drum, lanterns, moon disc, willow and kite), festive trim on festival_only stalls; `--festival-stall=` shot. |
| WU-466 | world-ui | Qingshi's bounty board opens a Village tasks modal (tasks, where, reward, shrine stage). |
| GUIDE-214 | systems | SeasonTasks.where names the place for each season task; journal, board and HUD use it. |
| SEASON-007 | systems | Light 1 Village Mugwort a day at the restored shrine for +5% qi in Qingshi that day (timed qi flag); Today line. |
| WILD-019 | systems | Optional `max_realm` on great beasts and their returns; Wildlife.great_enemy_for picks the slot's beast for a character. |
| TODAY-002 | systems | The arrival line posts once per day and region and names the pickups; the in-season line once a season per region. |
| GFX-082 | world-ui | Grass variants within 3% luminance (no blocky ground); decor kept 40 px off gates and travel places; Azure pine moved off the gate. |
| QA-198 | qa | Screenshot flags --festival, --contest, --practice, --regular, --journal; marked calendar days reach Today. |
| FEST-011 | systems | Invitation reminder only near the festival; the invited friend is not a contest entrant; the rival is marked by id. |
| MISSION-003 | systems | Optional `max_realm` on sect missions (skipped and refused above it), validated. |
| C-315 | content | An autumn-only Mist Fox roams Misty Forest for Foundation players; test: every season hunt target roams for Qi Refining and Foundation. |
| FEST-012 | systems | Merchant places may be `festival_only`; four festival stalls (Dragon Boat, Lantern, Qingming, Mid-Autumn); Today and calendar say so. |
| GFX-081 | world-ui | The Old Shrine in Qingshi drawn in five stages from rubble to painted and lit, label (n/4); `--shrine=N` shot. |
| SEASON-006 | systems | Each finished season set restores one stage of Qingshi's shrine; four stages give +5% qi in Qingshi. |
| GFX-079 | world-ui | Azure Peak: grey-green ground, `map.scree_density`, stone steps to the hall, a cloud band, 30 trees and boulder groups. |
| C-272 | content | Heart visions for Soul Formation, Void Refinement, Body Integration, Mahayana and Tribulation Transcendence. |
| WILD-018 | systems | Roamer `max_realm`, return beasts' own `min_realm`, Mist-Shrouded Leopard for Foundation; Foundation <50% fights 29 -> 195 (C-312 (3)). |
| C-309 | content | Spring and summer in-season beasts in Misty Forest and Hunter Ma, so the village hunt runs every season. |
| WU-464 | world-ui | Same-day identical log lines fold into one row with (xN); the arrival season sentence is not repeated. |
| GUIDE-212 | systems | Even fights sort before easy ones and the HUD says "Easy fight" for the latter. |
| WU-463 | world-ui | Contest card names who cheered and marks the rival; keepsakes get their own glyphs, unowned ones greyed. |
| GFX-078 | world-ui | Calendar in 7 columns under a weekday header, day number, 20 px icons and a label per cell, grouped Next line, hunt glyph. |
| WU-462 | world-ui | Season tasks on the journal Today page, a HUD line when one is left, and a banner when the set is done. |
| C-308 | content | Foundation twins of weak Qi-Refining fights (leopard, alpha, chieftain, corpse puppets), two sensed Dangerous foes; >95% rated fights 90% -> 75%. |
| WU-460 | world-ui | Village book Festivals page: one card per contest festival with last placing, champion, streak and keepsake. |
| MARKET-012 | systems | A regular hears a stall's wanted item the day before an open day (reminders, Today, calendar). |
| GFX-077 | world-ui | Great roamers draw at 1.6x with a wide shadow and a danger aura ring; label and hit box follow. |
| QA-196 | qa | Combat scan counts great-return beasts; full balance --check rerun and baseline refreshed with explained diffs. |
| SEASON-005 | systems | data/season_tasks.json: three village tasks per season (catch, gather, hunt, contest, sell_wanted) with a reward. |
| FOLK-012 | systems | Friends of the region cheer in a contest (+1 each, max 3); a Close friend invites you the day before. |
| WU-459 | world-ui | Calendar: Enter/A on a future day picks a label to mark; red seal, Marked line, Unmark. |
| WU-458 | world-ui | Journal opens on a Today page: date, weekday, weather and one icon row per today line. |
| FEST-010 | systems | Contest results kept per festival (last 10 years); history and history_lines; win/lose text lists. |
| FEST-009 | systems | The met, living rival within one realm enters every festival contest, remarks on it, festival tally kept. |
| WILD-017 | systems | The village hunt takes its posted days, doubles spoils, a loss ends the season's hunt; on the calendar and Today; a hunter NPC leads it. |
| GFX-076 | world-ui | Gate: two 64 px posts, a lifted roof and a hanging name board; decor and villagers keep clear; grotto moved off the Azure court. |
| QA-197 | qa | Screenshot scripts run to the end (--great shot last, road card waits for its line). |
| WU-457 | world-ui | On a festival day whose contest you have not entered, the stall says '<contest> today' and up to 4 villagers stand round it. |
| C-273 | content | Neighbourly asks 7 -> 18: region-bound and seasonal, items from each region's own tables. |
| C-303 | content | Ten more road encounters: market and ridge routes, spring/winter, fog/snow, a sect-only and a rogue-only Foundation pair. |
| CAL-006 | systems | Mark up to 5 future days with a calendar label (GameState.mark_day/unmark_day); a reminder the day before and on the day. UI: WU-459. |
| GFX-075 | world-ui | An edge arrow points at an off-screen great beast, tinted by danger, with its name; clear of the HUD panels. |
| MARKET-011 | systems | Selling one item to one merchant more than 5 times in 7 days lowers its price 10% per extra unit (floor 50%), recovering daily; shown on the shop row. |
| FEST-008 | systems | In the 7 days before a contest, the festival's practice place offers a 1-day practice: +2 per day to that year's roll, max +6. |
| WU-454 | world-ui | A contest podium card after each festival contest: standings with You marked, prize and win/lose text, gamepad focus, queued behind the road card. |
| WU-453 | world-ui | The shop title says what a regular gets (or how many market days to go); the journal market line marks the stall (regular). Landed from the -ready branch. |
| WU-456 | world-ui | The explore site offers 'Set bait on the trail' on a great beast's tracks day (disabled with the bait names when none is held). |
| QA-045 | qa | Foundation year sim records rated odds and adds --threats=fight: 91% of Foundation fights are rated >95%, so the first Foundation year is too easy -> C-308. |
| TODAY-001 | systems | Guidance.today_lines / GameState.today_lines: what today holds (festival, great beast, market, wanted item, in-season beasts, forage, reminders, season end). |
| C-306 | content | Each contest pays 1st/2nd/3rd: a keepsake for 1st, favor with the village, renown for the winner. |
| C-307 | content | Qingming moves to month 3 so spring has a festival. |
| SEASON-004 | systems | The season-ending line uses plurals, thins fat roamers instead of dropping them, and names missed festivals. |
| GFX-074 | world-ui | The mountain gate stands 250 px in with its board on the map side, clear of the exit label; the marsh court has dark flagstones, steps, lanterns and reeds. Still reads as one pole: GFX-076. |
| WILD-016 | systems | The village hunt: on the first market day of a season with an in-season beast, Qingshi's board offers a joint hunt (hunters' strike, double spoils, +1 favor with the villagers). Fixes and all-year hunts: WILD-017, C-309. |
| QA-195 | qa | GOAL-011 integration test (HUD goal text Middle, then great beast). Balance part moved to QA-196. |
| GFX-073 | world-ui | World labels are clamped inside the visible screen, clear of the HUD panels. |
| C-305 | content | A Dragon Boat Festival in Qingshi (month 5) with a boat race contest. |
| C-301 | content | Bog King Toad, Cloud Crane and Thunder-Horn Ram come back angrier as return beasts with their own trophies. |
| C-302 | content | Rain Cap, Fogbloom and Frostbell each go into a recipe. |
| SEASON-003 | systems | Three days before a season ends, one line names what leaves with it. |
| WILD-015 | systems | Bait a great beast's trail on its tracks day (GameState.bait_offer/set_bait); it walks weakened. No UI yet (WU-456). |
| FEST-007 | systems | Last year's contest champion is named on the calendar, enters again, and three wins in a row earn a milestone. |
| GOAL-012 | systems | Great-beast wins remember the realm they were won in; road goals use it and point at return beasts. |
| FEST-006 | systems | Each festival has a once-a-year contest against the region's villagers: placing, prizes, favor, renown. |
| WU-452 | world-ui | A road encounter opens after the road card finishes, not under it. |
| GFX-072 | world-ui | Great-beast prints walk as a close, dark trail you can follow. |
| GFX-071 | world-ui | The mountain gate spans the road, the Azure court leaves the Grotto free, the Great Cloud Crane is visible. |
| MARKET-010 | systems | The Night Market Stall sells its untagged wares again besides the rotating picks (reserved `untagged` tag). |
| C-299 | content | Rotating and wanted pools for the Night Market Stall and the Corpse Peddler's Skiff (open days 6 and 21). |
| WU-451 | world-ui | The trophy shelf shows a second slot for a return beast; the road goal names the active great beast. |
| WU-450 | world-ui | A trail of great-beast prints (hoof, three-toed, webbed, paw) on its tracks day and its own day. |
| MARKET-009 | systems | Selling a stall's wanted item on 3 market days makes you a regular: 10% off its rotating wares and one extra pick. |
| GOAL-011 | systems | Four Foundation road goals (Middle, a great beast of the realm, a Core Forming Pill source, Peak then attempt). |
| GFX-067 | world-ui | Smithy chimney with furnace mouth and smoke; the map's "!" marker has a backing. |
| TRAVEL-001 | systems | Road encounters take `road_regions` (x2 weight) and read the destination's weather; six route encounters. |
| GFX-070 | world-ui | Sect court extends south with a paler walk and shadow; the gate is a roofed arch with a hanging name board. |
| C-300 | content | `in_season` on beasts in Misty Forest, Azure Peak, the marsh and the Ridge; validated against `seasons`, max 2 per region. |
| WILD-014 | systems | Great defs take a `return` beast: after the first win the slot spawns it on the same weekday with its own trophy (Scarred Old Tusker). |
| GFX-069 | world-ui | Great beasts rank after the target in the label spread; [E] chip and highlight box are blockers; re-spread every 0.25 s on movement. |
| WU-447 | world-ui | RoadCard emits `finished`; the arrival banner waits for it; the card names the road encounter. |
| SEASON-001 | systems | `Guidance.season_digest`: forage, roamers, festivals and weather posted once on a season's first day. |
| WU-445 | world-ui | Rotating stalls open today get bunting and a sparkle; map detail and shop title name the new wares. |
| WILD-013 | systems | Roamer entries take `in_season`: spoils roll twice in those seasons and the arrival line says so (mist fox autumn, mist python summer). |
| WU-443 | world-ui | A road card on travel: fade, "From -> To · N days" with a filling dotted line; any key skips; reduce_motion cuts. |
| MARKET-008 | systems | A rotating stall may want one pool item each market day and buys it at x mult (max 5 a day); Sell tab and journal say so. |
| C-296 | content | Weather finds: Rain Cap Mushroom (Qingshi, rain), Fogbloom Moss (marsh, fog), Frostbell Herb (Ridge, snow). |
| C-297 | content | Every great beast has a nameless hunter's rumour, shown in the village book and the great-beast road goal. |
| GFX-068 | world-ui | Azure Peak: calmer scree; sect halls get a flagstone court with steps and lanterns; a gate with a name board (also the marsh). |
| WU-440 | world-ui | HUD date line, calendar detail and calendar cells name the weekday. |
| GOAL-010 | systems | Three more road goals: the 9th Layer, a Foundation pill (where to get it), attempt Foundation (review: 0-based stage fixed). |
| MARKET-007 | systems | Merchant places take `rotating_stock`; Qingshi's market stall picks 3 of 12 new wares each market day. |
| GFX-066 | world-ui | Crisp text at 1280x720/1080p: 2D pixel snapping off (it dropped glyphs at fractional stretch); a test pins it. |
| WU-441 | world-ui | Elder Mo clear of the arrival card; the interact prompt is a chip above its target; labels keep off the key strip. |
| WILD-012 | systems | Tracks the day before a great beast walks: a once-a-day explore line and a half-alpha paw on the map. |
| GFX-061 | world-ui | World map nodes get an opaque backing; road lines are clipped at node edges and no longer cross names. |
| GFX-062 | world-ui | Calmer bog ground; roamers and great beasts spawn 90 px clear of places and NPC homes (review: never inside solid landmarks). |
| GFX-065 | world-ui | First-hour set viewed at 800/720; `--arrival-card` shot; one arrival line per region shot; wider key strip. |
| WU-439 | world-ui | Unexplored map nodes show a lure line (great beast / ruins / danger); the road-goal region gets a gold mark. |
| GFX-064 | world-ui | Shops >= 110 px are buildings (compact shop for 110-119 px); smithy chimney, scroll sign; flagstones show through snow. |
| CAL-005 | systems | Named 7-day week (Calendar.weekday_name); the great-beast road goal names the soonest beast and its weekday. |
| WILD-011 | systems | Great-beast "Tomorrow:" reminders skip beasts already beaten (nearness rule was in place). |
| MISSION-002 | systems | Sect halls take an optional `sect`; Azure Cloud and Blood Lotus halls serve only their own disciples. |
| GOAL-009 | systems | Three more road goals: join a sect or stay free, first mission or bounty, 6th Layer. |
| FORAGE-005 | systems | forage_picks; at 25/75/150 picks a message, +1 pickup on half the full days, an 8% extra copy (spec values overshot the cap). |
| C-284 | content | Every named NPC has >= 2 likes incl. a cheap village gift; Elder Mo dislikes demonic, Xiao Ling blood arts. |
| WILD-010 | systems | renown.sources.great_beast (15) on a great-beast win, once a day. |
| GFX-058 | world-ui | Merchants >= 120 px draw a two-storey shop front; market rocks 12 -> 3, two garden beds; winter/rain viewed. |
| GUIDE-211 | systems | Guidance.find_note: the forage pick line says what the find is used in and what it sells for. |
| FORAGE-004 | systems | Forage entries take an optional `weather`; Misty Forest's rain-only Purple Cloud Mushroom. |
| GFX-055 | world-ui | Forced-weather shots fixed; rain streaks 2x8 and a grey rain tint; snowy winter furrows. |
| QA-191 | qa | Balance baseline refreshed after the mission board gate (sect runs walk to halls). |
| WU-438 | world-ui | Region name card holds ~2 s with the arrival line under it; a new game opens with it, a load does not. |
| WU-437 | world-ui | Hunts page Trophies row: won great beasts show the trophy, unwon ones ??? with region and walk day. |
| WU-435 | world-ui | Fair-fight line 'Fair fight: <short> (<rating>, N in 100)' wraps instead of being cut; 12 place labels moved clear of the cards. |
| C-293 | content | Forage counts 1-2 (Qingshi) / 1-3 (wilds), cheap herbs weighted up; 'Village Mugwort' -> 'Mugwort'; value-per-day test. |
| GFX-060 | world-ui | --great saves a close-up of each great beast; Thunder-Horn Ram warm umber, toad greener. |
| WILD-009 | systems | Wildlife.quarry_notes: after 3 hunts the Fight option lists usual spoils and temper. |
| GOAL-008 | systems | Guidance.road_goals: Misty Forest, Fallen Star Market, a great beast, a bounty, a hidden discovery. |
| GFX-059 | world-ui | World map: marsh map_pos, name-sized nodes, route labels placed clear, code-drawn land, glyph row. |
| QA-190 | qa | Village sim picks and sells forage: 3.2 stones per visit-day (before C-293) vs fishing 1.38. |
| GUIDE-210 | systems | Arrival line only in its own region (arrival_region flag) and names a festival first. |
| RV-017 | world-ui | Sect halls in Azure Peak and Withered Bone Marsh; Sects.board_reason names the nearest hall; every sect home region has a hall. |
| WU-433 | world-ui | Leaf glyph on world-map nodes with forage today; "By the path today:" line in the region detail. |
| C-292 | content | Roamer item drops priced 2-12 stones (ape leaves Boar Hide; wolf pelt and fox tail 12); test_roamer_spoils.gd. |
| GUIDE-209 | systems | Guidance.arrival_line (great beast, open stall, forage count, rain-fish) posted on arrival and shown as the day's top hint. |
| FORAGE-003 | systems | Calendar `forage` entries for seasonal forage in visited regions; picked herbs go into the herb log. |
| GFX-057 | world-ui | Crane, toad and ram figures for the great beasts; label "Great Cloud Crane (Deadly)"; paw glyph row fixed. |
| QA-192 | qa | Fuzz test logs the seed, kind and option when the engine logs an error (flake did not reproduce in 20 runs). |
| WILD-008 | systems | Beating a great beast that is the bounty quarry pays the bounty too; Wildlife.display_name ("Great <name>"). |
| GUIDE-208 | systems | Buy hints name market-day stalls; qi-pill hint looks one route away; "Chore for X: Foe" lines. |
| GFX-056 | world-ui | LabelLayout.offsets: place and NPC labels pushed apart deterministically; no two place labels overlap in any region. |
| WU-434 | world-ui | test_nothing_under_hud_cards_on_arrival over every region; Qingshi pond and many places moved into view. |
| C-294 | content | Four great-beast trophies (tusk, crown plume, throat pearl, horn coil) set as roamers.great.trophy. |
| MISSION-001 | systems | Missions only at a sect hall or the sect's home region; the Foundation-year sim takes them there. |
| GOAL-007 | systems | Three newcomer goals after the first technique (forage, a fish or harvest, a meal), each naming where; veterans see them done. |
| GFX-054 | world-ui | Fallen Star Market: flagstones only along streets and a plaza, packed earth elsewhere, tree clusters, street lanterns, places moved off the arrival HUD cards. |
| WILD-007 | systems | Optional great.trophy; Wildlife.record_great stores the first-win day and gives the trophy once per beast kind; Hunts page marks great beasts. |
| WU-432 | world-ui | UIStyle.theme() styles LineEdit, SpinBox, OptionButton, CheckBox, HSlider and scrollbars on the root; bolder hoe glyph. |
| FORAGE-002 | systems | Foraging.unpicked/summary and GameState.forage_today(region_id). |
| C-291 | content | Great beasts: Old Tusker, Cloud Crane, Bog-King Toad, Thunder-Horn Ram, weekdays so linked regions never share a day. |
| GFX-053 | world-ui | Calmer scree with frost/moss patches, map.decor.rock_clusters, decor kept 12 px off paths. |
| GFX-052 | world-ui | Far labels keep an opaque fill and outline; paved and scree maps draw a plate behind labels. |
| WU-431 | world-ui | WaterLife skips jetty rects (no highlights or ripples on planks); pond-drawable test. The missing pond was the HUD card covering it -> WU-434. |
| GUIDE-207 | systems | Trial and chore fair-fight lines say where; Text.a for meal names (part 2 moved to GUIDE-208). |
| GOAL-006 | systems | Milestones First Find, Forager, Home Cook, Rain Angler, Beast Hunter II; cooked_meals log. |
| QA-189 | qa | The village sim sells its surplus crop: tending now pays ~2x fishing per day spent. |
| WU-430 | world-ui | Great beasts at 1.5x with a gold ring and name; gold paw and detail on the world map; calendar glyph; --great shots. |
| GFX-048 | world-ui | Creation uses the night-mountain backdrop, a coloured root verdict, even 160x44 buttons; --title/--creation shots. |
| GFX-051 | world-ui | Coin and paw glyphs on world map nodes; one stream layer; --rain shot mode. |
| C-290 | content | The Grave Guardian Ape leaves a Guardian's River Stone instead of a hide. |
| MARKET-006 | systems | Heal-source and qi-pill hints include sole-seller market stalls with their next market day; merchant_price counts stalls. |
| WILD-006 | systems | A great beast walks each region one day in seven (slot 101), x2 spoils, calendar entry and a reminder the day before. |
| GFX-050 | world-ui | Fox, deer and ape beast shapes with fitting furs. |
| COOK-001 | systems | Guidance.meal_before_fight names the buff meal that lifts the odds most, with before -> after numbers. |
| QA-187 | qa | Screenshot tool: --region=a,b lists and --companion shots; all regions viewed. |
| GFX-049 | world-ui | Jetties stop short of roads, vertical jetties are walkways, no blots under dead trees, forage pickups 4x with a ground disc. |
| WU-429 | world-ui | Next steps card cuts whole entries; water under figures; fleeing beasts avoid scenery; hunt detail wording. |
| C-288 | content | Forage tables for all six regions with seasonal and realm-gated entries. |
| GUIDE-206 | systems | Fair-fight entries carry a short where-label; the HUD line uses it; a roamer here ranks above exploring. |
| WILD-005 | systems | CharacterData.hunt_spoils records real drops per beast; Wildlife.spoils_of; the Hunts page uses it. |
| WU-426 | world-ui | A bold beast's charge opens a menu whose Fight passes charged=true; the bounty quarry spawns at once; beasts keep their distance. |
| GFX-046 | world-ui | Jetties run from the pond rim into the water; marsh landmarks are dead trees + a willow (30 decor trees); a quieter bog. |
| WU-427 | world-ui | Forage pickups drawn on the map by tag with a sparkle; interact picks directly with a "+N Item" float. |
| GFX-047 | world-ui | Streams scroll downstream, pond highlights shimmer, rain rings on ponds; static with reduce_motion. |
| WU-428 | world-ui | World map nodes show today's weather, an open stall ($) and roaming beasts (w); detail panel has a "Today:" line. |
| CAL-004 | systems | Rent due-day reminder fires; request reminder names the items; an unloaded asker reads "A neighbour". |
| MARKET-005 | systems | Gear/scroll hints name a sole-seller stall's next market day; fish hints read rain-only fish and prefer today's weather. |
| FORAGE-001 | systems | regions.json `forage`, Foraging.nodes/validate, GameState.forage_here/pick_forage, forage_changed, foraged stat. |
| GUIDE-205 | systems | Fair-fight hints name a winnable beast roaming here today or one region away. |
| C-289 | content | Boar meat, venison, python meat from roamers; Boar Roast and Venison Herb Broth home meals; NPC likes. |
| QA-188 | qa | Balance baseline refreshed after the village data changes (part 3): drift explained by rng shift; fishing 1.33 stones/day. |
| WU-423 | world-ui | Beasts drawn in the wild: roamer figures wander near seeded spots, Fight / Leave with the threat in the name. |
| WU-422 | world-ui | Calendar icons per entry kind with a legend, "Next:" on empty days, season-tinted title, [Y] cal on the key strip. |
| GFX-044 | world-ui | Soft round mist and edge-faded fog, `map.mist` per region (Misty Forest 0.45), readable dead trees and bog reeds. |
| GFX-045 | world-ui | Ponds with rims, mud ring, reeds and highlight; stream banks and stones; a `jetty` landmark kind under fishing places. |
| WU-424 | world-ui | Roamers follow their temper: flees run, wary face you, bold charge with a ! and open their menu once a day. |
| WU-425 | world-ui | Village book Hunts page: hunted beasts with counts and spoils, unhunted ones as ???. |
| WILD-002 | systems | `Wildlife.temper` (flees/wary/bold, regions.json override), `GameState.roamer_temper`, charge line on engage. |
| CAL-003 | systems | "Tomorrow:" reminders (max 3) posted once a day from VillageCalendar.reminders; the digest lists them last. |
| WILD-003 | systems | The active bounty's (non-lethal beast) quarry roams the map as slot 100 and pays through `_fight_bounty`. |
| WILD-004 | systems | `hunt_log`, beasts_hunted life stat, `Wildlife.log_summary/huntable`, Beast Hunter milestone at 10. |
| MARKET-004 | systems | Gear, heal and qi-pill seller hints skip market stalls unless they are open today. |
| C-285 | content | Qingshi field rent 3 -> 2 and crop yields +1: untended field nets +34 over 480 days (was -18). |
| C-287 | content | Roamers for Misty Forest, Azure Peak, Withered Bone Marsh and Myriad Peaks Ridge (non-lethal beasts, seasonal entries). |
| C-283 | content | A rain-only fish at each of the five fishing places, one NPC likes each, Loach Porridge home meal; rain added to Azure Peak. |
| GFX-043 | world-ui | Winter that reads as snow: lighter tint, whiter ground, snow caps on fences/wells, frozen cracked ponds, snow-day footprints. |
| GFX-041 | world-ui | Per-region tree kinds (round/pine/willow/dead/bamboo) via `map.decor.tree_kinds`, blossoms and clusters; `--region=` shot flag. |
| FISH-006 | systems | Catch entries take `weather`; rain gives an extra draw, storms refuse casting; hint on pond, cast bar and journal. |
| FOLK-011 | systems | Generated villagers get likes/dislikes from `folk_tastes` pools by a stable hash; gifts, hints and the people page use them. |
| QA-184 | qa | `--tend` village arm: tended field 0.79 gross stones per tending day vs fishing 1.10; untended nets -8 (C-285 acts on it). |
| WU-421 | world-ui | LabelLayout.resolve ranks and nudges overlapping world labels, fades the rest; HUD rects block labels. |
| C-286 | content | Fishing at Bog Pond Shore, Cloud-Stream Ford and Thunder Tarn Ledge; 9 new fish with realm-gated trophies. |
| WILD-001 | systems | Wildlife system: regions.json `roamers`, deterministic daily roamers, `roamers_here`/`engage_roamer`, `roamers_changed`. |
| GFX-042 | world-ui | `map.ground_style` paved/scree/bog (+ litter) ground and paved streets; stripes/squares traced to fog sheets and mist quads. |
| CAL-002 | systems | VillageCalendar.upcoming adds the player's field, rent, request, secret realm and event dates. |
| MARKET-003 | systems | Sold-at lines and buy hints name market days; closed stalls are not pointed at as sellers; close_shop clears shop_name. |
| GFX-038 | world-ui | Duel stage clipped to its frame; far hills drawn as upper arcs; forced weather honoured. |
| WU-418 | world-ui | HudIcons.hearts; villager menu header with friendship label and heart row; Look line; journal "Friends:" line (Folk.friends_line); tier-up banner with portrait; `--friend` shot. |
| GFX-039 | world-ui | Seasonal ground: spring flowers, autumn ochre and leaves, winter snow ground and trodden paths; `map.no_snow`. |
| WU-419 | world-ui | CalendarScreen (Y, and from the journal): month grid with market icons, day detail, LB/RB months; `--calendar` shot. |
| GFX-040 | world-ui | VillageLife node: chimney smoke, pond ripples and a jumping fish (not on frozen ponds), a bird flock on clear days; off with reduce_motion. |
| WU-420 | world-ui | Village book "People" page (Tab cycles pages): a card per known villager with portrait, hearts, tier, birthday countdown and liked-item icons. |
| FLAG-001 | systems | Every flag reader honours timed flags; the legacy permanent storm peddler discount migrates to a 30-day timed flag. |
| CAL-001 | systems | VillageCalendar.upcoming/month_grid: market days, known birthdays, festivals, season starts; GameState.upcoming_days. |
| FOLK-009 | systems | Folk.people_entries for the people page (favor tier, tastes known, birthday). |
| C-281 | content | Seasonal fish at both ponds (spring bream, winter perch, autumn roach, summer bass, autumn trophy eel). |
| C-282 | content | Mild `scorched` injury from storm lightning while exploring. |
| QA-185 | qa | balance_baseline.txt refreshed; `tools/balance.sh --check` green again. |
| QA-186 | qa | Field, autumn and spring-shop shots viewed; village sim: fishing ~1.10 stones/day, rented field nets -8 over 480 days. |
| WU-416 | world-ui | DigestCard shows `last_digest` after a 5+ day action above the log; queues behind banners/modals; `--digest` shot. |
| GFX-037 | world-ui | Seasonal trees (blossom, autumn leaves, bare snowy winter), snow caps on roofs, icy pond rim, seasonal crop rows; `--season=` shot flag. |
| FOLK-008 | systems | Generated villagers have a stable birthday: greeting line, double first gift once a year, journal line 7 days ahead. |
| MARKET-002 | systems | Places may carry `open_days`; the Travelling Market Stall in Qingshi opens on days 10 and 25; journal hints the next market day. |
| QA-174 | qa | Part 1: test pins that `take_mission` has no region gate in core (only the world UI gates it). Part 2 stays open. |
| WU-415 | world-ui | Shop title shows the season; Buy/Sell rows get up/down price arrows; Dear/Cheap in <season> in tooltip and detail. |
| C-280 | content | Trophy fish: Gold-Scaled Carp (Qingshi jetty) and Ghostwhisker Eel (Misty Pond, autumn), liked by four NPCs. |
| GOAL-005 | systems | Milestone checks `log_kinds`, `log_complete`, `trophy`; harvests life stat; six village milestones. |
| FOLK-007 | systems | Friendship tiers for generated villagers (family.json `folk_tiers`) with a one-time line and gift per tier. |
| WU-417 | world-ui | Village book Fish/Herbs pages, Open village book button on the sheet, per-fish tinted icons. |
| WEATHER-006 | systems | Timed world flags (`flag_days`, `Effects.flag_active`); the stranded peddler's 30-day herb discount; storm greetings. |
| WU-413 | world-ui | Status-card chip names today's invited friend; the fight report says who fights beside you; field tool icons, "Dry, water it today." |
| QA-183 | qa | Crafter baseline now 5 seeds per craft; herb lore did not make crafters poorer (rng-sequence noise). |
| GFX-036 | world-ui | Fallen beasts lie on their back, per-region backdrop skylines with haze and clouds, `World.force_weather` keeps `--storm` shots stormy. |
| WU-411 | world-ui | A visiting friend stands by a pixel tea tray ("has come to see how you are"); greeting_bubble shot fixed, new visitor shot. |
| DAY-001 | systems | `DayDigest` folds a 5+ day action's posts into at most 5 lines in `GameState.last_digest`. |
| GFX-035 | world-ui | Duel stage: seasonal sky, a region silhouette layer (pines, roofs, reeds, hills), region grass with tufts, ~40% taller. |
| FISH-005 | systems | Trophy catch_table entries need a clean strike and fishing xp 10+; near misses snap the line; first trophy posts a Pond legend line. |
| C-278 | content | Three storm-only happenings (lost flock, lightning-split tree with Thunder Dao insight, stranded peddler) and three storm tip lines. |
| GATHER-002 | systems | Herb log (`CharacterData.herb_log`): first find of a kind posts "First find" and +2 gather xp; journal lines. |
| WU-414 | world-ui | VillageBook modal from the journal: fish grid, caught ones framed with counts, unknown ones as ??? silhouettes; `--book` shot. |
| FARM-005 | systems | Crops count care days; enough watering/nourishing yields `tended_bonus` more (regions.json tended_share/tended_bonus). |
| QA-182 | qa | Screenshot flags combine; `--quarrel`, `--cast`; shop shot is the ShopScreen; every village screen viewed, nothing to fix. |
| C-279 | content | Qingshi jetty carp weight 5 -> 3, field rent 6 -> 3: fishing 1.42 -> 0.99 stones/day, field net -132 -> +24 a year. |
| GFX-033 | world-ui | Storm plan (dark tint, heavy rain, lightning flash and thunder, off with reduce_motion), sturdier crops, fallen fighters with a Defeated tag. |
| GUIDE-204 | systems | Armor/manual/pill/heal hints quote the seasonal price; journal sells-high line; `seasonal_mult` ignores season case (prices were always off-season before). |
| WEATHER-005 | systems | Exploring on a storm day: 8% lightning (Thunder Dao progress with the insight or metal 50+), 5% Lightning-struck Wood. |
| GFX-034 | world-ui | Character sheet: styled qi and root bars, a Path card, flush Next steps, a Village crafts card with fishing and herb lore bars. |
| FARM-004 | systems | Nourish a growing field with qi (30 qi, +2 days, +3 with Wood 50+), once a day, field menu entry. |
| GFX-030 | world-ui | Character sheet and journal sections are headed cards; journal goals use a pixel checkbox. |
| FISH-004 | systems | Angler's log: catch_log, first catch +2 fishing xp, journal "Fish caught: N of M" and a missing-fish hint. |
| GUIDE-203 | systems | Journal hints a buff dish before an Even-or-harder foe; buy-ingredient hints use the season's price. |
| C-277 | content | Wedding greetings name the partner; tea visits get 5 lines (4 seasonal) and 3 tip-with-tea lines. |
| GATHER-001 | systems | Herb lore: gather_xp, ranks Novice..Herb Sage, extra-unit chance and rarer finds; journal and sheet line. |
| GFX-032 | world-ui | Shared ItemRow: framed icon slots, count and price badges, a 48 px icon in the inventory detail pane. |
| C-269 | content | Four Foundation-realm Qingshi happenings (two sect_only), new sect_only encounter field. |
| WU-412 | world-ui | Fishing is a timing bar (CastBar); auto_cast skips it, reduce_motion halves the marker speed. |
| FARM-003 | systems | Field plants can be seasonal (peach blossom spring, mugwort not winter); out-of-season plants greyed in the menu. |
| GFX-031 | world-ui | HUD: styled qi bar with a trough, soul-lamp lives, stone icon, season and weather icons. |
| QA-181 | qa | `--village` sim arm: fishing ~1.43 stones/day (2.9x Doctor), field net negative at rent 6, village median 405 vs 296 stones. |
| GFX-027 | world-ui | Ribbon and bow on the stall nearest the lanterns, a confetti puff when you attend, lanterns at the Family Home for family celebrations. |
| WU-410 | world-ui | QuarrelWindow: topic, both portraits, four choices with check tags, result before closing. |
| FOLK-006 | systems | Settled quarrels leave a 30-day mark: mediated pair seen together, the side you opposed greets you coldly, extortion starts a rumor. |
| C-276 | content | Qingshi field grows 6 plants (mugwort, peach blossom petal, purple cloud mushroom added); plantable items say so. |
| TECH-010 | systems | Pure `greeting_for` plus `GameState.receive_greeting_gift`; harvest of an orphaned crop pays 1 herb. |
| FARM-002 | systems | Misty Forest field (2 plots), watering by hand on dry days, enlarging a field once. |
| GFX-029 | world-ui | Field plots drawn by state and growth stage, ripe crop in its icon tint, frost tint; "ready in N days". |
| WU-409 | world-ui | Banners on a dark ribbon titled by kind, queued banners hold 1 s, ChoiceMenu description reserve trimmed. |
| FISH-003 | systems | Fishing xp and ranks, rare-catch odds by skill and cast quality, got-away roll, `Fishing.zone_width` for WU-412. |
| COOK-002 | systems | Dishes carry buffs (Fish Stew defense, Eel Congee attack, new Herb Porridge health), cooking at the Family Home, generated descriptions. |
| C-275 | content | folk_tips grows to 10 lines, with seasonal and weather object lines. |
| GFX-028 | world-ui | Duel stage 130 px with region ground, shadows, five beast kinds, light rim, names over hp bars. |
| GUIDE-202 | systems | `Weather.forecast`; journal Around the village gets crop, cook, tomorrow's weather and visitor lines; HUD shows tomorrow. |
| WEATHER-004 | systems | Summer storms in Qingshi and Myriad Peaks: fewer herbs, poor fishing, metal qi and Thunder Dao boosts. |
| WU-408 | world-ui | Framed speaker portraits in DialogueWindow and NPC/deed-giver ChoiceMenus. |
| FOLK-005 | systems | Invite a cultivator friend (favor 60+) to explore: they strike in that day's next fight. |
| RV-016 | systems | Weather qi bonus averaged over the days cultivated (`Weather.mean_qi_mult`, up to 365 days) in cultivate/dual cultivation; baseline refreshed. |
| WU-406 | world-ui | The hint bullet lives in an HBox beside the autowrapped label, so edge-space trimming can no longer swallow it; geometry test. |
| GFX-024 | world-ui | Character sheet left column: framed 4x portrait, name, age, realm, qi bar, root grade and five element bars. |
| GFX-025 | world-ui | Place names fade with distance (1.0 within 220 px, 0.35 at 420), lift out from under HUD panels; "Show all place names" setting. |
| GFX-026 | world-ui | Grass with four deterministic 16 px variants, ragged path edges, wall/cliff/stream as PixelLandmark kinds. |
| WU-407 | world-ui | Journal section "Around the village" (`Guidance.village_lines`: weather, tip, requests, celebrations, best catch); tip site gets the gold "!". |
| WU-405 | world-ui | Generated pixel jetty (planks, float, reeds); the fishing option notes the weather. |
| MARKET-001 | systems | items.json `seasonal_prices`: seasonal herbs buy/sell x0.85 in season, x1.2 outside; shops and inventory pass the season. |
| FISH-002 | systems | Home meals (recipes.json `home_meals`, Cooking): Fish Stew, Eel Congee at any workshop; `shorten_injury` effect; villagers ask for Silver Carp. |
| WORLD-007 | systems | Friends drop by: family.json `folk_visits`, deterministic `Folk.visitor`, tea for favor and a tip; `folk_visit_day` saved. |
| FARM-001 | systems | Farmer Tian's Spare Field: rent, plant, harvest (`FieldPlots`, `CharacterData.field_plots`); rain faster, winter frozen, Wood 50+ bonus. |
| FOLK-004 | systems | Village quarrels (family.json `folk_quarrels`, `Folk.monthly_quarrel`): mediate, side with one, or demand payment. |
| C-274 | content | Three news variants per celebration type and celebration greetings while a villager's celebration is open. |
| QA-180 | qa | The sell-keeps-order hint shot gives the smith a sellable ore, so the hint line shows. |
| GFX-023 | world-ui | Weddings hang red pixel lanterns near the celebrating villager (white for funerals, swaying unless reduce_motion); celebrants wear a sash; `--celebration` shot. |
| GFX-022 | world-ui | PixelPlace nature kinds (meditation ring, herb patch, cave mouth, stele, abode, rift, camp) and PixelLandmark house/well/stall/pine/lantern/pond/field/fence. |
| WEATHER-003 | systems | regions.json `qi_element` per weather kind: a root with that element at 50+ cultivates faster that day (`Weather.qi_mult`, `effect_note(.., "meditate")`); baseline refreshed. |
| FOLK-002 | systems | Villagers at favor 40+ hand over a small gift when they greet you, once per 45 days (`folk_gifts`, `CharacterData.folk_gift_day`). |
| C-256 | content | Rank-0 work pays 0.30-0.39 of the best crafting margin per day in every craft: no change (docs/specs/C-256-result.md). |
| QA-179 | qa | Balance baseline re-checked after the village-life batch; tiny log-line and one-seed drifts refreshed, nothing unexplained. |
| WU-403 | world-ui | Gather options note the weather; `GameState.journey_days` (snow day included) drives the travel menu and world map labels. |
| WU-404 | world-ui | `HUD.hint_indent()` spaces for the hint bullet (still overlaps in the 12:20 shot: WU-406); shots open through `_update_modal`; `shop` shot. |
| C-271 | content | Harvest festival autumn-only; six seasonal/weather happenings (planting, flood, hunt drive, snow traveller, fog patch, meteors). |
| FOLK-003 | systems | Chatting with a friend (favor 20+ after the review fix) may give a 10-day gathering tip: +2 of an in-season item in the region (`folk_tips`). |
| GFX-021 | world-ui | PixelPlace: nine village building kinds as generated outlined pixel art at `Sprites.scale()`; vector PlaceArt stays the fallback. |
| WORLD-006 | systems | Full-month feasts for births and funerals for deaths in your region open celebrations you can attend (types in family.json; old saves default to wedding). |
| FISH-001 | systems | Fishing place type with `catch_table` and `fishing_weather`; ponds in Qingshi and Misty Forest; three fish sold to the Wandering Merchant. |
| WU-402 | world-ui | Villagers with an open folk request show the gold "!" and a full-alpha name; the greeting asks for the item; the answer reads "Give 3 Spirit Grass". |
| GFX-020 | world-ui | The fallen foe stays on the duel stage (lying down, darkened), empty hp bars stay visible, crisper rain streaks; `--fight=beast|cultivator` shots. |
| GFX-019 | world-ui | `ItemIcon`: generated 12x12 glyphs per item kind (tinted pills/herbs) in inventory, shop and crafting rows; `icon_<id>`/`icon_<kind>` sprite keys override. |
| WORLD-005 | systems | Folk celebrations (family.json `celebrations`): a wedding in your region opens 30 days to attend (+6 favor to both, alignment +1) and a double first gift. |
| QA-178 | qa | `--hint-shot` asserts match the current HUD (contribution label, wrapped hints, clinic line); all hints were right. |
| FOLK-001 | systems | Monthly folk requests (family.json `folk_requests`) stored as LETTER-003 requests with source "folk"; silent expiry. |
| C-265 | content | Rest days on five repeating village beats; fold beast, hopeful youths and peak rogue retire after one meeting. |
| HEART-002 | systems | Heart vision choices gain min/max_alignment and an alignment shift; each vision has a demonic-only and a righteous-only choice. |
| WU-401 | world-ui | A generated villager near you shows a 3 s greeting bubble once a day (WORLD-003 lines). |
| WORLD-004 | systems | Rain and snow move villagers from outdoor haunts to sheltered places; `haunt_positions` keeps them >= 28 px apart. |
| GFX-018 | world-ui | Deed-giver places draw PixelFigure people from an optional regions.json `look`; Bandit Camp is a tent and fire; Farmer Tian. |
| GFX-017 | world-ui | Opaque panels, a dim backdrop and a hidden interact prompt behind modals; the log card fits its lines. |
| WEATHER-002 | systems | Rain: gathered herbs may come with one extra; snow adds a day to journeys (regions.json `weather_effects`). |
|---|---|---|
| C-415 | content | Every start-region villager has their own two lines for tending a Sworn friend (Bai Qingwu: care, not gifts). |
| WU-600 | world-ui | A friend's drop-by gift raises a queued bottom-centre 'From <Name>' card with the item icon and their line. |
| WU-599 | world-ui | A Sworn friend tending you plays the tea-card pattern: both seated, their line, 'N days of healing'. |
| SIM-025 | systems | The hints player crafts and takes open trials; longest stretches 53/42/75/100 -> 63/42/61/65 days. |
| PERF-032 | systems | Hints measured at 2.5 s per long seed (was 3.3 s): no cache needed; fair_fights (1.4 s) is next. |
| WU-596 | world-ui | People cards say how: unknown likes read 'give a gift to learn', the birthday row is not repeated, Sworn cards name the tend use. |
| WU-597 | world-ui | A name under the [E] prompt chip fades to 35%; place labels already hid under it. |
| FOLK-044 | systems | friend_tended / friend_gift_left signals, a sworn_tend_hint after the injury line, and the hints player walks to the friend. |
| C-413 | content | 17 start-region villagers have their own drop-by gift lines (3 never fire: no cheap like -> C-416). |
| RV-FOLK041 | systems | Drop-by gifts roll from stable hashes of npc id and day, never the shared rng. |
| GFX-236 | world-ui | The Sworn oath plays where the friend stands with the real figures, a burner between them, labels hidden. |
| WORLD-003 | systems | `Folk.greeting`: warm/cool passing lines by favor from family.json `folk_greetings`; `GameState.greeting_for`. |
| WU-400 | world-ui | The breakthrough window shows the heart vision, its choices with check tags, the outcome and refreshed odds; asks once before pushing on. |
| WU-398 | world-ui | `--hint-shot` repairs: core pill rank clause, trial and sell-keeps-order shots, explored-out scroll; four older asserts still trip -> QA-178. |
| WU-399 | world-ui | Rain, snow, fog and cloudy tint in the world scene from `Weather.of`; `--weather=<kind>` for region shots. |
| WORLD-002 | systems | `Npcs.haunt_place` + `activity_line`: a villager's Look text says what they are doing today. |
| C-248 | content | Help: the sect page names the rogue join hint; the rival page mentions the friendly spar. |
| GFX-016 | world-ui | Slimmer status card (merged lines), Next steps capped at 5 lines, one-line key strip with a backing, cards fade near the player. |
| HEART-001 | systems | `HeartVision`: optional heart vision per major realm (Foundation, Core, Nascent Soul) with checked choices and a one-shot `heart_bonus` in the odds. |
| GFX-015 | world-ui | Generated villagers' names fade in near the player; every map label gets a dark outline. |
| ENC-013 | systems | Encounter `weather` gate; `rest_days` now also rests repeatable happenings. |
| RIVAL-023 | systems | The encounter spar sets the same spar cooldown as the NPC-menu spar. |
| GFX-014 | world-ui | Duel stage fighters are PixelFigure people and a generated pixel quadruped for beasts; banners wait for the fight report. |
| C-268 | content | Eight village/city beats name a `{villager}` and give `villager_favor` on the kind choice. |
| WU-397 | world-ui | Heavy hits shake the duel stage, breakthroughs shake the camera, death gets a red vignette; `reduce_motion` setting turns all motion off. |
| GFX-013 | world-ui | Sprite hooks for the map border, festival stalls and the 9-sliced highlight ring; Sprites.frame caches its AtlasTexture. |
| WEATHER-001 | systems | `Weather.of(data, region, day)`: deterministic daily weather per region and season; the HUD date line shows it (cosmetic). |
| WORLD-001 | systems | `Npcs.haunt()`: villagers keep a daily round between 2-3 haunts of their region. |
| QA-175 | qa | `--repeat-report`: lost coin 16x (49x rogue), beast at the fold 16x, boar 12x, pickpocket 12x in 36 months -> C-265 (after ENC-013). |
| ENC-010 | systems | Fading happenings rest 120 days (per-encounter `rest_days`) after being met; balance baseline refreshed. |
| C-270 | content | Lectures read like scenes: 9 month-indexed lines per sect with `{elder}`/`{topic}`. |
| GFX-012 | world-ui | Walls, cliffs, streams with bridges, lanterns, pines and stalls in every region. |
| GFX-011 | world-ui | `PixelFigure`: generated 16x20 pixel people (3-frame walk, hair styles, child variant) for the player and NPCs. |
| C-267 | content | 35 animal/monster enemies tagged `beast` for the duel stage. |
| ENC-011 | systems | `{villager}`/`{elder}` in happenings name living locals; `villager_favor`/`elder_favor` effects (Folk). Content in C-268. |
| RIVAL-022 | systems | Friendly rivals invite a non-injuring spar instead of a duel (`rival_spar_friendly`); balance baseline refreshed. |
| GFX-010 | world-ui | Compact HUD: status card top-left, Next steps card top-right, key strip bottom-right (`key_help`), short fading log. |
| QA-173 | qa | `--core-report`: base sect players stall at Foundation Peak (0/10 reach Core in 60 months); with the sect method 10/10 do. Numbers under F-005d; no retune. |
| WU-391 | world-ui | Screenshot batch for the 2026-10-29 guidance (journal_core_pill_rank assert fails on main, explored-out line below the fold -> WU-398). |
| GUIDE-201 | systems | The realm goal says how long Core takes with the claimable sect method. |
| MENTOR-005 | systems | Ten pointer lines from a master, picked by day. |
| GFX-008 | world-ui | Qingshi landmarks: 4 houses, 2 fields, pond, fence, well (`map.landmarks`, houses and well solid). |
| GUIDE-197 | systems | Goals tell the truth about the next step: faster spot, Core pill behind a hopeless trial, no mission push on a rich member (shot -> WU-398). |
| QA-176 | qa | Asset licence guard test (ASSETS.md row, LICENSE file, CC0/CC-BY only) before the first pack lands. |
| GUIDE-200 | systems | The sell hint and Sell all keep what open orders need (shot not added -> WU-398). |
| WU-396 | world-ui | A duel stage above the fight report bars (no enemy has a "beast" tag yet -> C-267; no reduce-motion setting -> WU-397). |
| GFX-007 | world-ui | Generated 16x16 pixel ground and path tiles per region until the pack lands. |
| RIVAL-021 | systems | Rival encounters rest between meetings (`rival_quiet_until`); balance baseline refreshed. |
| C-258 | content | Help: next-recipe, clan-abode and explored-out hints. |
| GFX-009 | world-ui | Integer pixel zoom at every window size (1280x800 and 1080p shots not viewed in the cloud run). |
| GFX-006 | world-ui | Sprite hooks for ground, paths, decor and NPCs (`Sprites.first`); map border, festival stalls and the highlight ring still have none -> GFX-013. |
| C-263 | content | The Granary Blessing happens once. |
| WU-390 | world-ui | Road unlock notice reads "(the road from <Region> takes N days)" instead of a distance from a region you are not in. |
| GFX-001 | world-ui | Pixel-art pipeline: data/sprites.json + `Sprites` loader; player, place art and credits use it, `_draw()` fallback; no assets. |
| QA-168 | qa | Balance baseline refreshed after GUIDE-189..196 and C-259/260/261; every diff explained (RNG streams, hint-following sims). |
| WU-387 | world-ui | hint_method_first shot: the treasury method leads the capped HUD hints; the thin-defence line still shows. |
| C-262 | content | Help: the breakthrough page says where a Core Forming Pill comes from. |
| C-259 | content | Four once-only Foundation happenings for Misty Forest and Fallen Star Market (balance.sh skipped). |
| GUIDE-194 | systems | An order due within 3 days takes a hint slot right after the sect duty. |
| QA-172 | qa | HUD Goal line test: the region-aware faster-spot clause appears only with region and day. |
| GUIDE-196 | systems | A claimable sect method that nearly doubles qi leads the thin-defence line (balance.sh skipped). |
| WU-388 | world-ui | First-hour explore_menu re-render: footer reads "Often quiet 14%." and fits. |
| C-261 | content | "A Name for the Newborn" happens once (named_a_newborn flag). |
| WU-384 | world-ui | hint_heal_before_travel shot: the capped HUD line keeps "Heal first, then travel to". |
| WU-389 | world-ui | journal_core_pill_rank shot: Goals say a Core Disciple could claim the Core Forming Pill for 3200. |
| C-260 | content | Sect Core Forming Pill claimable from Core Disciple (rank 2) in every sect, with a data test. |
| GUIDE-195 | systems | Explore footer writes the quiet share like the others ("Often quiet 14%."). |
| WU-386 | world-ui | First-hour journal/inventory/character shots wait out the milestone banner. |
| GUIDE-193 | systems | The heal-first warning leads the far-qi travel line so the capped HUD keeps it. |
| GUIDE-192 | systems | The realm goal's odds include a breakthrough pill held but not taken. |
| GUIDE-191 | systems | Explored-out hint names the nearest region with unmet happenings (review: plural fix, test asserts mastery). |
| QA-170 | qa | --sect-report: skipped stipends are rank-1 months with no mission (sim policy, not a bug) -> QA-174. |
| WU-385 | world-ui | First-hour hud_after_sect shot: a new Outer Disciple's HUD fits (arrival-log oddity -> WU-390). |
| WU-380 | world-ui | journal_recipe_treasury shot: Goals say the next recipe's scroll is claimed from the sect treasury. |
| GUIDE-190 | systems | heal_source prefers a usable cure from a structural affordable flag (text unchanged). |
| GUIDE-189 | systems | The next-recipe line says "claim it from your sect treasury for N contribution" (balance.sh early-fights diff -> QA-168). |
| WU-383 | world-ui | hint_heal_before_travel shot: the capped HUD line cuts the "Heal first" warning -> GUIDE-193. |
| WU-381 | world-ui | hint_thin_defence_budget shot: manual-first HUD line, no armor over the stones left. |
| C-255 | content | Help: the injuries page names the far clinic; the combat page mentions the body-art hint. |
| C-257 | content | Qingshi Foundation beats fade: the well hums once; headman and youths no longer repeat. |
| WU-382 | world-ui | First-hour screenshot re-audit: no layout fixes needed (footer separators -> GUIDE-195; no hud_after_sect shot -> WU-385). |
| WU-378 | world-ui | hint_thin_defence_local shot: manual-first line and Waterfall Cave clan goal. |
| QA-166 | qa | A due-soon order line shows with 3 days left; in hud_busy it lost to the hint limit -> GUIDE-194. |
| GUIDE-188 | systems | The thin-defence armor budget leaves out the manual the line just told you to buy. |
| WU-379 | world-ui | The HUD Goal line passes region and day to Guidance.goals (weak test -> QA-172). |
| QA-167 | qa | The doomed-order hint test really runs (fails when GUIDE-177 is reverted). |
| GUIDE-187 | systems | The far-qi travel line warns an injured player when the destination has no healer. |
| WU-377 | world-ui | hint_rogue_join: the capped HUD line keeps "members gather qi x1.5". |
| WU-376 | world-ui | `--hint-shot` hint_injury_far (Misty Forest; Azure Peak now has a clinic): far clinic, trip and "(you have 5)" fit. |
| GUIDE-184 | systems | The next-recipe line names the merchant selling the scroll, where and for how much. |
| WU-362 | world-ui | The sect hall's join prompt says what membership gives (`sect_join_prompt` shot). |
| GUIDE-186 | systems | The clan goal names the abode to claim (`_abode_pick`, "(you have S)" when short). |
| C-252 | content | Qi-item audit: no realm-named pill lacks `min_realm`; 3 cheap potent pills -> F-005d note. Help: potent pills need their realm. |
| GUIDE-185 | systems | The thin-defence line leads with "Buy <manual> from the <merchant> here for N stones" (both clauses can spend the same stones -> GUIDE-188). |
| WU-371 | world-ui | treasury_learn shot rendered: the Learn button is focused and does not clip. |
| GUIDE-182 | systems | The rogue's sect hint leads with the best sect and its perks. |
| C-254 | content | Cliffside Hermit Physician: a clinic at Azure Peak. |
| GUIDE-183 | systems | The injury line names a far clinic even when you cannot afford it ("(you have S)", sell-first clause). |
| WU-372 | world-ui | hint_sect_method shot asserts both rates in the capped HUD line. |
| PERF-007 | systems | The mission hint rates unhurt odds only in the branch that reads them (the 5 cold ratings are all used). |
| WU-375 | world-ui | Shops and the inventory flag pills above the player's realm ("[needs Foundation Establishment]"). |
| QA-162 | qa | `--sect-report`: sect+far-qi Foundation median 1013 d vs rogue+far-qi 708 (base 1817); travel costs members nothing; 41% of stipends skipped -> QA-170/171. |
| GUIDE-180 | systems | The single-mission line names the extra pay. |
| WU-373 | world-ui | `--hint-shot` journal_rank_needs: the rank goal joins both needs with "and". |
| ITEM-003 | systems | Realm-gated pills: item `min_realm` (Cloud-Mist needs Foundation, Earth Marrow Core Formation); hints skip gated pills. |
| GUIDE-178 | systems | Alchemy orders prefer ingredients from your own region; a neighbour's ingredient is asked for 1 at a time. |
| GUIDE-181 | systems | The rank goal lists every unmet need at once (`Sects.rank_needs`). |
| GUIDE-179 | systems | The sect method hint leads with the rates ("(qi x1.6, yours x1.2)"). |
| PERF-006 | systems | Items.sources memoised per GameData: warm journal 87.6 -> 7.9 ms. |
| WU-374 | world-ui | `--hint-shot` hint_order_doomed: a doomed order takes no hint slot, the journal lists it. |
| WU-369 | world-ui | `--help-shot` mode; the help body scroll is focusable for the gamepad. |
| WU-370 | world-ui | `--hint-shot` hud_busy: the busiest HUD still fits (due-soon order line missing -> QA-166). |
| WU-367 | world-ui | No "As Elder" before the realm gate; built twice (--breakthrough-shots and --hint-shot). |
| WU-365 | world-ui | `--hint-shot` hint_rogue_join (capped line cuts the perks -> GUIDE-182). |
| WU-366 | world-ui | `--hint-shot` journal_clan_goal: the clan goal wraps cleanly. |
| C-251 | content | Help: clan goal lists founding needs; unmeetable orders drop out of hints. |
| C-253 | content | Three once-only Foundation rogue beats (cave-swap board, wandering master, shared night watch). |
| C-250 | content | Help: Goals topic names the faraway-spot and hopeless-trial goal lines. |
| C-247 | content | Help: the treasury method hint waits until you can spare the contribution. |
| QA-163 | qa | `--injury-report`: far-qi injuries go untreated (no healer at Azure Peak, sim ignores hints, hint silent ~15/50) -> GUIDE-183, GUIDE-187, C-254, QA-165. |
| QA-155 | qa | `--body-art`: the art lifts Core Disciple trial odds median 10 -> 41 in 100, not over 50 -> QA-169. |
| WU-368 | world-ui | Sect treasury: "Learn <tech> now" after claiming a manual, then "Set as your main method" (pngs unrendered -> WU-371). |
| WU-364 | world-ui | `--hint-shot` journal_goals realm/rank: both goal lines wrap cleanly. |
| WU-363 | world-ui | `--hint-shot` hint_sect_method: HUD cap cuts the rate comparison (-> GUIDE-179). |
| QA-161 | qa | Rogue arms: Foundation median 673 d with far qi (10/10), 1142 buy-qi, 1295 plain (3/10); sect base 1632 (-> QA-162..164). |
| QA-160 | qa | Balance baseline refreshed (all diffs explained); balance.sh step in the worker loop. |
| C-249 | content | `rogue_only` encounter field + three once-only Qi Refining rogue beats (breath-walker, river barter, recruiter). |
| C-246 | content | Help: the practice hint names your body art when the style is trained far enough. |
| C-244 | content | Audit: 6 of 7 rank-0/1 alchemy recipes need ingredients Qingshi lacks; no data field (-> GUIDE-178). |
| GUIDE-177 | systems | `Commissions.can_meet_in_time`: a gather-only order that can't be met in time leaves the hints. |
| GUIDE-176 | systems | `Clans.found_needs`: the clan goal lists realm, abode and stones at once. |
| GUIDE-175 | systems | `Sects.membership_perks`/`membership_line`: the rogue sect hint says what members get. |
| GUIDE-174 | systems | Drunk bully capped at Qi Refining; `outgrown_hint` treats an empty home as outgrown. |
| GUIDE-173 | systems | The best-mission line adds "and N spirit stones" / "and N qi". |
| GUIDE-172 | systems | The trial advice skips the treasury source when the thin-defence hint already names that manual. |
| WU-360 | world-ui | hint_practice_target also asserts the capped HUD trial line names Iron Fist. |
| GUIDE-171 | systems | The rank goal says the trial is "beyond you yet" instead of "you can seek promotion" when odds are below 20 in 100. |
| C-242 | content | Help: the duty hint names a covering mission; missing duty only skips the stipend. |
| GUIDE-158 | systems | `Guidance.sect_method_hint`: the treasury's faster method, keeping the breakthrough pill's contribution. |
| C-241 | content | Help (Goals topic): members see contribution next to their spirit stones. |
| GUIDE-169 | systems | The trial line opens "The <rank> trial is too hard for now: <lever> first." (`_trial_lever`), so the HUD cap keeps the advice. |
| WU-361 | world-ui | `--hint-shot` hint_body_art_target: "practise Stone Skin Tempering to level N", never Iron Fist. |
| GUIDE-170 | systems | The pill rank clause never names a rank whose min_realm is above yours. |
| C-245 | content | Capped old boxer, widow's thief, chore swap and harvest festival at Qi Refining; drunk bully kept (-> GUIDE-174). |
| QA-159 | qa | `profile_days.gd --hints`: cold hints 70-77 ms (5 ratings), warm 4 ms; journal warm ~63 ms with 0 ratings (-> PERF-006/007). |
| WU-359 | world-ui | `--hint-shot` sheet_member: "Contribution: 6998 to spend (lifetime 7400)" fits. |
| WU-355 | world-ui | `--hint-shot` hint_duty: covering mission named, else the skipped stipend. |
| GUIDE-168 | systems | The realm goal names a faster qi spot when it saves a year net of the trip. |
| QA-158 | qa | Curious sim `--rogue`: Foundation by m36 3/10 vs 10/10 in a sect; no final deaths; 22-29 month stretches with nothing new. |
| WU-352 | world-ui | `--hint-shot` hint_qi_two_spots: the far-spot line joins durations with "and". |
| WU-358 | world-ui | `--map-shot` map_market: the 8-merchant Sells line fits; details scroll; no layout change needed. |
| WU-357 | world-ui | `--hint-shot` hint_trial_no_style: "learn a combat technique", never "practise". |
| GUIDE-165 | systems | The treasury heal hint keeps the Foundation pill claim's contribution in reserve. |
| WU-356 | world-ui | `--hint-shot` hint_missions_last_stage: at QR9 the mission line says to break through first. |
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
