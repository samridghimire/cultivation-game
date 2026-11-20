extends RefCounted
## QA-016: a scripted newcomer in Qingshi Village, shared by the sim
## (tests/sim/simulate_first_hour.gd) and its guards (tests/unit/test_first_hour.gd).
## Plays through the same GameState calls the menus use.
## QA-222: one sim "month" is 30 days of cultivation PLUS the days its other actions take (travel, work, missions, crafting,
## waiting, retreats), measured at ~60 clock days per month for a curious seed. So every `day` figure the sims print (Foundation day,
## seal days, breakthrough days) is the game clock's `total_days`, and a 36-month run ends near day 2000, not 1080.

const CHORES: Array[String] = ["chore_gather_herbs", "chore_widow_roof", "chore_drive_off_boar"]
const SPRING_DENSITY := 2.0  # Spirit Spring, see data/regions.json


## Starts a fresh session for `seed_value` and returns the counters dict.
## Keys: layer_day (layer number -> first day), sect_day, month_lines (Array of
## {category: count} per month), injuries, fights_won, fights_lost, fights_fled.
## `curious` adds the QA-029 policy each month (see _curious_month); the default
## newcomer only meditates and explores once. `month_hook(month)` (optional) runs
## after each month's actions. QA-044: `no_help` makes the curious player never ask for pointers or spar.
## QA-076: `wait_for_pill` > 0 makes a player at the Foundation bottleneck without a pill keep earning for up to that
## many days (out["waited_days"]) before attempting, as long as a merchant-sold pill exists to save for.
## QA-091: what the policy is doing now ("mission", "deed", "bounty" or "other"); the sims read it when a fight starts.
static var fight_origin := "other"
## QA-116: the curious player follows GUIDE-065's thin-defence hint (see _follow_defence_hint).
static var follow_defence := false
## QA-116: per seed, what following the hint did: {"trips": travels to another region, "armor": bought, "manual": bought}.
static var defence_log := {}
## QA-123: the curious player follows GUIDE-081's practice hint: while it speaks, practise that style to its next level.
static var practise_hint := false
## QA-123: day of the first win over a Mist Wolf in the last play() (-1 = none); read by tests/sim/simulate_practise.gd.
static var wolf_win_day := -1
## QA-136: the curious player attempts an open sect promotion trial when the hint's odds are >= TRIAL_MIN_ODDS
## (once a month, travelling to a sect hall if needed). `--no-trial` in simulate_first_hour.gd turns it off.
static var attempt_trials := true
## QA-128: a curious player treats injuries (owned items, then a clinic in the region) once a month; simulate_first_hour.gd's
## --no-heal turns it off. heal_log["healed"] counts treatments, ["stones"] the stones the clinic took.
static var heal_injuries := false
static var heal_log := {"healed": 0, "stones": 0}
## QA-181: in Qingshi a curious player works the village (see _village_month): rents the field and plants/harvests it, fishes the
## jetty, sells the catch and crops, shares tea with a visitor, settles a quarrel. village_log counts it: stones from the field and
## the fish (sold), rent paid, fishing days, harvests, teas, quarrels, favor. simulate_curious_years.gd's --village turns it on.
static var village := false
## QA-184: --tend (needs --village): after planting, stay in the village and water (clear/cloudy day) and nourish (qi allows) the field
## for as many days as the tended bonus needs (FieldPlots.care_needed); village_log["tend_days"] counts the days that took.
static var tend := false
static var village_log := {"field_stones": 0, "rent": 0, "harvests": 0, "crops": 0, "fish_stones": 0, "fish_days": 0, "teas": 0, "quarrels": 0, "meals": 0, "tend_days": 0, "forage_stones": 0, "forage_days": 0, "forage_picked": 0}
## QA-163: with injury_report on, play() logs every injury the player takes: injury_log entries are
## {seed, id, day, region, news (the danger line the HUD showed), days (healing time), qi_lost (cultivation days it costs
## if left alone), end (day it went, -1 still open), treated (it went well before its time)}.
static var injury_report := false
static var injury_log: Array[Dictionary] = []
## QA-162: with sect_report on, play() logs per seed what a sect member does with the sect: sect_log entries are
## {seed, joined (day or -1), away (days the month ended outside the sect's home region), months (sim months since
## joining), skipped (stipends withheld for missed duty), paid, missions, lectures}.
static var sect_report := false
## QA-173: read by simulate_curious_years.gd's --core-report (the attempt log already records every Core try); part of the memo key.
static var core_report := false
static var sect_log: Array[Dictionary] = []
## QA-171: with activity_report on, play() logs per seed the days spent per activity (read off the call stack of every
## clock advance) until Foundation, and the qi gained per meditation day. Part of the memo key.
static var activity_report := false
static var activity_log: Array[Dictionary] = []
## QA-229: with qi_probe on, play() logs for each meditation month in the first 6 that starts away from the bottleneck, uninjured
## and ends in the same stage: region, density asked, density the game used, sect bonus, measured vs expected qi per day.
## Part of the memo key.
static var qi_probe := false
static var qi_probe_log: Array[Dictionary] = []
## QA-138: a curious player takes the bout the spar hint names ("<Name> (<realm>) here would spar with you"), once a
## week while the hint speaks; simulate_first_hour.gd's --no-spar-hint turns it off. spar_log["bouts"] counts them,
## ["refused"] collects check_spar's text when the named partner refuses (a hint bug).
static var spar_hint := false
static var spar_log := {"bouts": 0, "refused": []}
## QA-220: the curious player chats once a day with the villager Guidance.style_teacher names when standing in their region
## (and gives one liked item when held); once a style is known, takes the weekly teacher bout Mentorship.teacher_bout_style
## names. simulate_first_hour.gd / simulate_curious_years.gd's --chat-teacher turn it on. out["teacher"] per seed:
## {style_day, source ("lesson" / "manual" / ""), bouts, mastered_day, chats}; days are the clock's (-1 = never).
static var chat_teacher := false
## QA-215: once a month the curious player does the elder's open season tasks that SeasonTasks places within SEASON_REACH_DAYS
## of where they stand (catch/gather at a place's table, hunt the village hunt's quarry or a site that can bring the foe up
## (only when the fight is rated 40%+, SEASON-024), enter the festival contest, sell a wanted good held), then walks home.
## simulate_curious_years.gd's --season-tasks turns it on (part of the memo key). season_task_log counts what was done.
static var season_tasks := false
## QA-174: at sect rank 1 take one mission a month, only while standing in a region with a sect hall (MISSION-001)
## and only when its foe is rated Even or better. simulate_curious_years.gd's --mission-monthly; part of the memo key.
static var mission_monthly := false
## QA-227: a sect member does the steward chore the duty hint names when the month's duty is unmet and remain
## (walking to the hall when it is <= 3 route days away); QA-228 also walks home at month start when the duty is projected short. simulate_curious_years.gd's --steward-chores; part of the memo key.
static var steward_chores := false
static var steward_max_days := 3  # --steward-days=N
const STEWARD_LAST_DAYS := 10
## QA-165: --heal-injuries goes beyond QA-128's treatment: when the injury line's cure is not here, claim a sect treasury
## item (contribution) or travel to a clinic one route away that the stones cover, treat, and walk home.
## heal_far_log: {"treated": cures taken, "trips": clinic journeys}. Part of the memo key.
static var heal_far := false
static var heal_far_log := {"treated": 0, "trips": 0}
## SEASON-025: matches SeasonTasks' audit (every year-1 task has a place within 6 route days).
const SEASON_REACH_DAYS := 6
## SEASON-025: why each season task last failed, keyed "<seed>|<season key>|<task id>" (read by simulate_curious_years.gd's report).
static var season_why := {}
static var season_seed := 0
## SEASON-025: the longest the policy waits at a closed stall for its market day.
const SEASON_STALL_WAIT_DAYS := 16
static var season_task_log := {"trips": 0, "catch_days": 0, "gather_days": 0, "hunts": 0, "contests": 0, "sold": 0, "bought": 0, "stall_waits": 0}
static var _teach_rec := {}
## QA-141: missions rated below this are skipped, as a player reading the board's odds (WU-286) would;
## simulate_first_hour.gd's --blind-missions sets it to 0 (the old policy).
static var min_mission_odds := 0.4

## QA-134: take the mission the sect hint names (the best-paying one), up to 3 a month;
## simulate_first_hour.gd's --one-mission sets it false (one mission a month, first listed).
static var chase_best_mission := true
## QA-144: once a month, spend stones above the next realm pill's reserve (and 20 for the clinic) on the best qi per
## stone the current region's merchant sells, and use the pills (not at a bottleneck); simulate_first_hour.gd's
## --buy-qi sets it. qi_log counts "bought", "stones" spent, pills "used" and "qi" gained from them.
static var buy_qi := false
## QA-164: with buy_qi, when this region's merchants sell nothing worth buying, follow the qi-pill hint
## (Guidance.qi_pill_offer_near) to the region it names, buy there and walk home. `--buy-qi-travel` sets it.
static var buy_qi_travel := false
static var qi_trips := 0
## QA-234: per-seed qi-pill buyer log. qi_buys has one entry per purchase {seed, item, region, trip, bought, stones, qi};
## qi_trip_log one per trip made only to buy {seed, region, days}; qi_hint_far counts hints naming a far pill the buyer skipped.
static var qi_buys: Array[Dictionary] = []
static var qi_trip_log: Array[Dictionary] = []
static var qi_hint_far: Dictionary = {}
static var _qi_seed := 0
static var _qi_on_trip := false
## QA-140: follow the "Sell your ..." / armor hints: sell loot to the named merchant, walk to the smithy, buy and
## wear the armor, walk home. simulate_first_hour.gd turns it on for --curious (`--no-armor` restores the old policy of never selling or buying armor).
static var shop_armor := false
static var armor_log := {"day": -1, "sold": 0, "stones_from_sales": 0, "trips": 0}
## QA-146: bounties the board listed vs taken, by the bounty's region (ids counted once per seed).
static var bounty_log := {"offered": {}, "taken": {}}
static var qi_log := {"bought": 0, "stones": 0, "used": 0, "qi": 0}
## QA-148: once a month a sect member spends contribution: the next realm's pill (once), a body art (once), then
## the shop's best qi pills with the rest, keeping the pill's cost while it is still to claim.
static var spend_contribution := false
## QA-150: at most this many contribution qi pills a month (-1 = no cap; the pill claim and body art are unchanged).
static var qi_pill_cap := -1
static var contribution_log := {"pill_days": [], "pill": 0, "body": 0, "qi_items": 0, "qi_cost": 0, "qi_used": 0, "qi": 0}
const TRIAL_MIN_ODDS := 0.7
## SIM-010: the "hints" player. Once a week (4 a month) it acts on the first Next-steps line it can act on (goal line, then the
## hints) through the same GameState calls the curious policy uses, else meditates the week. It replaces the month's 30-day
## meditation and the end-of-month explore. hints_log: {"acted": {action: count}, "idle_weeks": n, "weeks": n,
## "unmatched": {normalised line: times it sat above the line acted on, or was the whole list}}. Part of the memo key.
const HINT_MAX_TRIES := 3
static var hints_policy := false
static var hints_log := {"acted": {}, "idle_weeks": 0, "weeks": 0, "unmatched": {}}
## QA-145: once a month, before meditating, move to the faster spot Guidance.far_qi_offer names when it saves >= 30 days
## net of the round trip, and stay there (the new region is home from then on).
static var far_qi := false
## QA-156: once a month a sect member buys the treasury's best qi-gathering method manual with contribution (keeping the
## Foundation pill's claim while it is still to claim), learns it and makes it the main method. sect_method_log["month"]
## holds the day of each purchase (one per seed that made one), ["tech"] the technique ids.
static var sect_method := false
static var sect_method_log := {"day": [], "tech": []}
## QA-152: before any purchase, recharge the artifact when lives <= Guidance.LOW_ARTIFACT_LIVES and the stones cover it.
static var recharge_first := false
## QA-152: take only what Guidance.best_mission names (no odds rule of our own).
static var hint_missions := false
## QA-158: never join a sect (the rogue path).
static var stay_rogue := false
## SIM-012: --start=<region_id> moves the newcomer there at day 0 (the creation screen only offers data.start_region, so
## this is a what-if), --join=<sect_id> joins that sect at day 0 when it takes a mortal, else at the first chance.
static var start_region := ""
static var join_sect_id := ""
## QA-212: with artifact_report on, play() unseals each Creation Artifact function the day it is ready (cheapest first, never feeds stones)
## and artifact_log (per seed: {open: {id: day}, foundation: day, energy: {source: total}}) records when.
static var artifact_report := false
static var artifact_log: Array[Dictionary] = []
## QA-155: once a month a sect member buys the cheapest body-art manual the treasury sells (keeping the Foundation
## pill's claim while it is still to claim) or a merchant here sells for stones, learns it and practises it 7 days a
## month. trial_report (implied by body_art) records per seed the day the art was learned and the Core Disciple trial
## odds the first month a trial is open: body_art_log[seed] = {"learned": day or -1, "odds": float, "month": int}.
static var body_art := false
static var trial_report := false
static var body_art_log := {}
static var far_qi_day := -1  # QA-151: day the current seed arrived at the far spot, -1 before
static var far_qi_log := {"moved": 0, "month": [], "road_days": []}
const FAR_QI_MIN_SAVED := 30
## SIM-017: the hints player's menu presses (see PRESS_COST) and the first day and press count of each milestone, for
## tests/sim/first_hour_presses.gd. {"presses": n, "first": {milestone: {"day": d, "presses": n}}}, reset by play().
static var press_log := {"presses": 0, "first": {}}
## Menu presses per hinted action: open the menu, choose the entry, confirm. Walking to another region adds TRAVEL_PRESSES.
const PRESS_COST := {"talk": 3, "use_item": 3, "buy_qi": 3, "heal": 3, "chore": 3, "fight": 3, "great_beast": 6, "spar": 3, "sect_home": 0, "mission": 3, "sell": 3, "lend": 3, "teacher": 4, "fish": 3, "armor": 6, "treasury": 3, "unseal": 3, "travel": 0, "practise": 3, "forage": 2, "explore": 2, "bounty": 3, "cook": 3, "trial": 3, "other": 3}
const TRAVEL_PRESSES := 3
const MILESTONES: Array[String] = ["first_stage", "first_win", "first_friend", "friend_tier2", "first_technique", "first_breakthrough", "sect_joined"]


## PERF-004: unit tests that only read a run's result share one run per (seed, months, curious, no_help, wait, flags).
## A run is deterministic for those inputs (every sim flag belongs in the key); tests that read the statics (wolf_win_day, the logs) or pass a hook call play().
static var _memo := {}


static func play_cached(gs: Node, clock: Node, seed_value: int, months: int, curious: bool = false, no_help: bool = false, wait_for_pill: int = 0) -> Dictionary:
	var key := [seed_value, months, curious, no_help, wait_for_pill, tend, follow_defence, practise_hint, attempt_trials, heal_injuries, heal_far, village, spar_hint, chat_teacher, season_tasks, mission_monthly, steward_chores, steward_max_days, min_mission_odds, chase_best_mission, buy_qi, buy_qi_travel, hints_policy, start_region, join_sect_id, shop_armor, spend_contribution, qi_pill_cap, far_qi, recharge_first, hint_missions, sect_method, stay_rogue, body_art, trial_report, sect_report, core_report, activity_report, qi_probe]
	if not _memo.has(key):
		_memo[key] = play(gs, clock, seed_value, months, curious, Callable(), no_help, wait_for_pill)
		gs.end_session()
	return _memo[key]


static func play(gs: Node, clock: Node, seed_value: int, months: int, curious: bool = false, month_hook: Callable = Callable(), no_help: bool = false, wait_for_pill: int = 0) -> Dictionary:
	_qi_seed = seed_value
	season_seed = seed_value
	gs.rng.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := CharacterFactory.create("Newcomer", gs.data, rng)
	var saves: Node = gs.get_node("/root/SaveManager")
	var autosave_was: bool = saves.autosave_enabled
	saves.autosave_enabled = false  # a sim month must not write the autosave slot (QA-137)
	gs.start_session(c)
	gs.pending_event = ""
	if start_region != "" and gs.data.regions.has(start_region):
		gs.current_region = start_region
	if join_sect_id != "" and c.is_rogue() and Sects.accepting_sects(c, gs.data).has(join_sect_id):
		gs.join_sect(join_sect_id)
	var bus: Node = gs.get_node("/root/EventBus")
	bus.clear_history()
	var out := {"layer_day": {}, "sect_day": -1, "rank_day": -1, "month_lines": [], "injuries": 0, "player": c, "kinds": [], "kind_sets": [], "stones": [], "realms": [], "first_win_day": -1, "first_style_day": -1, "first_win_enemy": "", "breaks": [], "bottleneck_day": {}, "waited_days": 0, "road": [], "contribution": [], "bottleneck_stones": -1, "month_days": []}
	bounty_log["seen"] = {}
	press_log = {"presses": 0, "first": {}}
	_teach_rec = {"style_day": -1, "source": "", "bouts": 0, "mastered_day": -1, "chats": 0}
	out["teacher"] = _teach_rec
	far_qi_day = -1
	var done := {"no_help": no_help}
	# QA-063: remember the foe of the first real (non-spar) win; the day comes from the fights_won stat.
	var fight := {"enemy": "", "first_enemy": ""}
	var on_start := func(enemy: Dictionary) -> void: fight["enemy"] = "" if enemy.get("spar", false) else String(enemy.get("id", enemy.get("name", "?")))
	wolf_win_day = -1
	armor_log["day"] = -1
	var on_end := func(_name: String, victory: bool, _log: PackedStringArray) -> void:
		if victory and fight["enemy"] != "" and fight["first_enemy"] == "":
			fight["first_enemy"] = fight["enemy"]
		if victory and fight["enemy"] == "mist_wolf" and wolf_win_day < 0:
			wolf_win_day = clock.total_days
	bus.combat_started.connect(on_start)
	bus.combat_finished.connect(on_end)
	var open_injuries := {}
	var on_msg := func(text: String, category: String) -> void:
		_injury_sync(gs, c, clock.total_days, open_injuries, seed_value, text if category == "danger" else "")
	if injury_report:
		bus.message_posted.connect(on_msg)
	var sect_entry := {"seed": seed_value, "joined": -1, "away": 0, "months": 0, "skipped": 0, "paid": 0, "missions": 0, "lectures": 0, "chores": 0, "chore_days": 0, "chore_walk_days": 0, "chore_trips": 0, "foundation_day": -1, "rank1_day": -1, "short": [], "earned": []}
	var on_sect_msg := func(text: String, _category: String) -> void:
		if text.contains("this month's stipend is withheld"):
			sect_entry["skipped"] += 1
			var short := RegEx.create_from_string("\\((\\d+)/(\\d+) contribution\\)").search(text)  # QA-170: earned/duty
			var rank_now := int(c.sect.get("rank", 0)) if not c.is_rogue() else -1
			sect_entry["short"].append([rank_now, int(short.get_string(1)), int(short.get_string(2))] if short != null else [rank_now, -1, -1])
		elif text.begins_with("Mission complete:") and not c.is_rogue():
			var key := "missions_rank%d" % int(c.sect.get("rank", 0))  # QA-170
			sect_entry[key] = int(sect_entry.get(key, 0)) + 1
		elif text.begins_with("Your sect pays your monthly stipend"):
			sect_entry["paid"] += 1
	if sect_report:
		bus.message_posted.connect(on_sect_msg)
	var act := {"seed": seed_value, "days": {}, "foundation_days": {}, "med_qi": 0.0, "med_days": 0, "found": false}
	var on_days := func(days: int) -> void:
		var kind := _activity_of(get_stack())
		var tally: Dictionary = act["days"]
		tally[kind] = int(tally.get(kind, 0)) + days
	if activity_report:
		clock.days_advanced.connect(on_days)
	var art_rec := {"open": {}, "foundation": -1, "energy": {}}
	if artifact_report:
		artifact_log.append(art_rec)
		ArtifactFunctions.gain_observer = func(source: String, amount: int) -> void:
			var tally: Dictionary = art_rec["energy"]
			tally[source] = int(tally.get(source, 0)) + amount
	_talk_to_elder_mo(gs)
	for chore in CHORES:
		gs.perform_deed(chore)
	_use_qi_items(gs, c)
	for month in months:
		if not c.alive:
			break
		bus.clear_history()  # the log is capped, which would hide a month's lines from the count
		var mark := 0
		var qi_density := SPRING_DENSITY
		if far_qi:
			qi_density = _move_for_qi(gs, c, clock, month, qi_density, out)
		var kinds_pre := {}
		var qi_before := c.qi
		var realm_before_med := c.realm_index
		var probe_ok := qi_probe and month < 6 and c.injuries.is_empty() and not Cultivation.is_at_bottleneck(c, gs.data)
		var probe_stage := c.stage
		var probe_day: int = clock.total_days
		var probe_region: String = gs.current_region
		var probe_expected := 0.0
		var probe_used := 0.0
		if probe_ok:
			probe_used = gs._cultivation_density(qi_density, Calendar.DAYS_PER_MONTH)
			probe_ok = Cultivation.days_to_bottleneck(c, gs.data, probe_used) > Calendar.DAYS_PER_MONTH
			probe_expected = Cultivation.qi_per_day(c, gs.data, qi_density * gs.region_qi_density(Calendar.DAYS_PER_MONTH) * Sects.cultivation_bonus(c, gs.data))
		_walk_home_for_duty(gs, c, done, kinds_pre, clock.total_days)
		if hints_policy:
			kinds_pre.merge(_hints_month(gs, c, done, clock.total_days, qi_density))
		else:
			gs.cultivate(Calendar.DAYS_PER_MONTH, qi_density)
		if probe_ok and c.alive and c.stage == probe_stage and c.realm_index == realm_before_med and clock.total_days > probe_day:
			qi_probe_log.append({"seed": seed_value, "month": month + 1, "region": probe_region, "sect": not c.is_rogue(), "asked": qi_density, "used": probe_used, "bonus": Sects.cultivation_bonus(c, gs.data), "days": clock.total_days - probe_day, "measured": (c.qi - qi_before) / float(clock.total_days - probe_day), "expected": probe_expected})
		if not c.alive:
			break
		if activity_report and not act["found"] and c.realm_index == realm_before_med:
			act["med_qi"] += maxf(0.0, c.qi - qi_before)  # a month that ends below its start (injury, pill) gathered nothing we can read
			act["med_days"] += Calendar.DAYS_PER_MONTH
		var broke := false
		# QA-066: log every breakthrough attempt (and the first day each realm's bottleneck was seen, month-granular).
		if Cultivation.is_at_bottleneck(c, gs.data) and not out["bottleneck_day"].has(c.realm_index):
			out["bottleneck_day"][c.realm_index] = clock.total_days
			if c.realm_index == 1 and out["bottleneck_stones"] < 0:
				out["bottleneck_stones"] = c.item_count("spirit_stone")  # QA-146
		if Cultivation.can_attempt_breakthrough(c, gs.data) and _keeps_saving_for_pill(gs, c, out, wait_for_pill):
			out["waited_days"] += Calendar.DAYS_PER_MONTH
		elif Cultivation.can_attempt_breakthrough(c, gs.data):
			var stones_now := c.item_count("spirit_stone")
			# QA-072: take a held breakthrough pill right before the attempt, as the breakthrough window's "Take" button does.
			for pill_id in Guidance.breakthrough_item_ids(c, gs.data):
				gs.use_item(pill_id)
			var attempt := {"day": clock.total_days, "from_realm": c.realm_index, "chance": Cultivation.breakthrough_chance(c, gs.data), "pill": c.breakthrough_pill != "", "stones": stones_now, "contribution": Sects.contribution_balance(c), "method": Techniques.method_rate(c, gs.data)}
			var injuries_before := c.injuries.size()
			var realm_before := c.realm_index
			gs.attempt_breakthrough()
			attempt["success"] = c.alive and c.realm_index > realm_before
			attempt["injury"] = c.injuries.size() > injuries_before
			out["breaks"].append(attempt)
			broke = true
		_use_qi_items(gs, c)
		if c.is_rogue() and out["sect_day"] < 0 and not stay_rogue:
			for sect_id: String in Sects.accepting_sects(c, gs.data):
				if join_sect_id != "" and sect_id != join_sect_id:
					continue  # SIM-012: --join waits for that sect
				gs.join_sect(sect_id)
				break
		if not c.is_rogue() and out["sect_day"] < 0:
			out["sect_day"] = clock.total_days
		if not c.is_rogue() and int(c.sect["rank"]) >= 1 and out["rank_day"] < 0:
			out["rank_day"] = clock.total_days  # QA-136: first day (month-granular) as Inner Disciple or above
		if c.realm_index == 1 and not out["layer_day"].has(c.stage + 1):
			for layer in range(1, c.stage + 2):
				if not out["layer_day"].has(layer):
					out["layer_day"][layer] = clock.total_days
		var kinds := {}
		out["contribution"].append(Sects.contribution_balance(c) if c.is_rogue() else int(c.sect.get("contribution", 0)))
		for b: Dictionary in Bounties.offers(c, gs.data, clock.total_days, gs.current_region):
			if not bounty_log["seen"].has(b["id"]):
				bounty_log["seen"][b["id"]] = true
				var offered: Dictionary = bounty_log["offered"]
				offered[String(b["region"])] = int(offered.get(String(b["region"]), 0)) + 1
		_note_first_win(out, c, clock, fight)
		if hints_policy:
			kinds = kinds_pre
		elif not curious:
			_retry_chores(gs, c)
			_note_first_win(out, c, clock, fight)
		if curious:
			kinds = _curious_month(gs, c, done, clock.total_days)
			_note_teacher_style(gs, c)
			if done.has("style_month") and out["first_style_day"] < 0:
				out["first_style_day"] = clock.total_days
			_note_first_win(out, c, clock, fight)
		var home_region: String = gs.current_region
		if not hints_policy:
			gs.explore()
			if explore_observer.is_valid():
				explore_observer.call(home_region, 1)
		_note_first_win(out, c, clock, fight)
		var counts := {}
		for i in range(mark, bus.history.size()):
			var cat: String = bus.history[i]["category"]
			_note_road(gs, out, String(bus.history[i]["text"]))
			counts[cat] = int(counts.get(cat, 0)) + 1
		out["month_lines"].append(counts)
		out["kinds"].append(kinds.size())
		var with_break := kinds.duplicate()
		if broke:
			with_break["breakthrough"] = true
		out["kind_sets"].append(with_break)
		out["stones"].append(c.item_count("spirit_stone"))
		out["month_days"].append(clock.total_days)
		out["realms"].append(Cultivation.realm_label(c, gs.data))
		if injury_report:
			_injury_sync(gs, c, clock.total_days, open_injuries, seed_value, "")
		if sect_report and not c.is_rogue():
			if sect_entry["joined"] < 0:
				sect_entry["joined"] = clock.total_days
			sect_entry["months"] += 1
			if c.realm_index >= 2 and int(sect_entry["foundation_day"]) < 0:
				sect_entry["foundation_day"] = clock.total_days  # QA-227
			if gs.current_region != (gs.data.sects[c.sect["id"]] as SectDef).home_region:
				sect_entry["away"] += Calendar.DAYS_PER_MONTH
		if activity_report and not act["found"] and c.realm_index >= 2:
			act["found"] = true
			act["foundation_days"] = (act["days"] as Dictionary).duplicate()
			act["foundation_day"] = clock.total_days
		if artifact_report:
			_artifact_month(gs, c, clock.total_days, art_rec)
		if month_hook.is_valid():
			month_hook.call(month)
	if artifact_report:
		ArtifactFunctions.gain_observer = Callable()
	if activity_report:
		clock.days_advanced.disconnect(on_days)
		act["sect"] = "rogue" if c.is_rogue() else String(c.sect["id"])
		activity_log.append(act)
	if injury_report:
		bus.message_posted.disconnect(on_msg)
	if sect_report:
		bus.message_posted.disconnect(on_sect_msg)
		sect_entry["missions"] = LifeStats.get_stat(c, "missions_done")
		sect_entry["lectures"] = LifeStats.get_stat(c, "lectures_attended")
		sect_entry["chores"] = int(done.get("chores", 0))
		sect_entry["chore_days"] = int(done.get("chore_days", 0))  # QA-228
		sect_entry["chore_walk_days"] = int(done.get("chore_walk_days", 0))
		sect_entry["chore_trips"] = int(done.get("chore_trips", 0))
		sect_entry["rank1_day"] = int(out["rank_day"])
		sect_entry["end_day"] = clock.total_days
		sect_log.append(sect_entry)
	bus.combat_started.disconnect(on_start)
	bus.combat_finished.disconnect(on_end)
	out["style_month"] = int(done.get("style_month", -1))
	out["fair_log"] = done.get("fair_log", {"listed": [], "taken": [], "by_kind": {}})
	out["injuries"] = c.injuries.size()
	out["recharges"] = int(done.get("recharges", 0))
	out["no_hint_months"] = int(done.get("no_hint_months", 0))
	out["trials_won"] = int(done.get("trials_won", 0))
	out["trials_lost"] = int(done.get("trials_lost", 0))
	out["sect_rank"] = -1 if c.is_rogue() else int(c.sect["rank"])
	out["lives"] = c.artifact_lives
	out["fights_won"] = LifeStats.get_stat(c, "fights_won")
	out["fights_lost"] = LifeStats.get_stat(c, "fights_lost")
	out["fights_fled"] = LifeStats.get_stat(c, "threats_fled")
	saves.autosave_enabled = autosave_was
	return out


## QA-171: name the activity behind a clock advance from the stack (frame 0 is the signal handler, 1 GameClock.advance,
## 2 GameState._pass_time, 3 the GameState action that spent the days).
static func _activity_of(stack: Array) -> String:
	if stack.size() < 4:
		return "other"
	var fn := String(stack[3].get("function", ""))
	if fn == "cultivate" or fn == "cultivate_in_seclusion":
		return "meditation"
	if fn == "travel":
		return "travel"
	if fn.contains("mission"):
		return "missions"
	if fn.contains("lecture"):
		return "lectures"
	if fn.contains("fight") or fn.contains("combat") or fn.contains("explore") or fn.contains("hunt") or fn.contains("spar") or fn.contains("bounty"):
		return "fights"
	if fn.contains("work") or fn.contains("craft") or fn.contains("brew") or fn.contains("forge") or fn.contains("deed") or fn.contains("chore") or fn.contains("steward") or fn.contains("gather") or fn.contains("harvest") or fn.contains("fish") or fn.contains("tend") or fn.contains("mine"):
		return "work"
	return "other:" + fn


## QA-212: unseal every function that is ready, cheapest first (the day is month-granular), and note the day Foundation is reached.
static func _artifact_month(gs: Node, c: CharacterData, day: int, rec: Dictionary) -> void:
	if int(rec["foundation"]) < 0 and c.realm_index >= 2:
		rec["foundation"] = day
	while c.alive:
		var ready := ArtifactFunctions.ready_to_unseal(c, gs.data, gs.world_flags)
		if ready.is_empty():
			return
		ready.sort_custom(func(a: String, b: String) -> bool:
			return int(ArtifactFunctions.get_def(gs.data, a).get("unlock", {}).get("energy", 0)) < int(ArtifactFunctions.get_def(gs.data, b).get("unlock", {}).get("energy", 0)))
		gs.unlock_artifact_function(ready[0])
		if not ArtifactFunctions.is_unlocked(c, ready[0]):
			return
		rec["open"][ready[0]] = day


## QA-118: remember the id of a road encounter ("On the road: <text>" in the log) so the sim can list them.
static func _note_road(gs: Node, out: Dictionary, text: String) -> void:
	if not text.begins_with("On the road: "):
		return
	var body := text.substr(13)
	for id: String in gs.data.encounters:
		var enc_text := String(gs.data.encounters[id].get("text", ""))
		if "road" in gs.data.encounters[id].get("tags", []) and enc_text != "" and body.begins_with(enc_text.substr(0, 40)):
			out["road"].append(id)
			return


## QA-076: true while the player is at the Qi Refining -> Foundation bottleneck with no pill and still has waiting days.
static func _keeps_saving_for_pill(gs: Node, c: CharacterData, out: Dictionary, wait_for_pill: int) -> bool:
	if wait_for_pill <= 0 or c.realm_index != 1 or int(out["waited_days"]) >= wait_for_pill:
		return false
	if c.breakthrough_pill != "" or not Guidance.breakthrough_item_ids(c, gs.data).is_empty():
		return false
	return not Guidance.next_realm_pill(c, gs.data).is_empty()


## QA-069: once a month in the village, an uninjured newcomer tries again any chore
## fight they lost at day 0 once the odds are at least "Even" (0.7).
static func _retry_chores(gs: Node, c: CharacterData) -> void:
	if not c.alive or gs.current_region != "qingshi_village" or not c.injuries.is_empty():
		return
	for chore in CHORES:
		var deed: Dictionary = gs.data.deeds.get(chore, {})
		var enemy_id := String(deed.get("enemy", ""))
		if enemy_id == "" or gs.world_flags.has(String(deed.get("blocked_by_flag", ""))):
			continue
		if Combat.win_chance(c, gs.data, gs.data.enemies[enemy_id]) >= 0.7:
			gs.perform_deed(chore)


static func _note_first_win(out: Dictionary, c: CharacterData, clock: Node, fight: Dictionary) -> void:
	if out["first_win_day"] < 0 and LifeStats.get_stat(c, "fights_won") >= 1:
		out["first_win_day"] = clock.total_days
		out["first_win_enemy"] = fight["first_enemy"]


## QA-082: the "explore" entries Fights you can win lists now, keyed by foe name -> rated chance, plus a
## sink that collects the fights the next explore_many meets ({name, won}). A listed foe met while
## exploring counts as "taken" (the player did not choose it, but it is the fight the list promised).
static func _explore_watched(gs: Node, c: CharacterData, today: int) -> Dictionary:
	var listed := {}
	for f: Dictionary in Guidance.fair_fights(c, gs.data, gs.world_flags, today, gs.current_region):
		if String(f["kind"]) == "explore":
			listed[String(f["enemy"])] = float(f["chance"])
	var seen := {"listed": listed, "met": [], "name": ""}
	var bus: Node = gs.get_node("/root/EventBus")
	var on_start := func(enemy: Dictionary) -> void: seen["name"] = String(enemy.get("name", ""))
	var on_end := func(_n: String, victory: bool, _log: PackedStringArray) -> void: seen["met"].append({"name": seen["name"], "won": victory})
	bus.combat_started.connect(on_start)
	bus.combat_finished.connect(on_end)
	seen["off"] = func() -> void:
		bus.combat_started.disconnect(on_start)
		bus.combat_finished.disconnect(on_end)
	return seen


static func _log_explore_fights(done: Dictionary, seen: Dictionary) -> void:
	seen["off"].call()
	seen.erase("off")  # QA-099: on_start captures `seen`, which held the lambda that captures on_start
	if not done.has("fair_log"):
		done["fair_log"] = {"listed": [], "taken": [], "by_kind": {}}
	for m: Dictionary in seen["met"]:
		if seen["listed"].has(m["name"]):
			done["fair_log"]["taken"].append({"kind": "explore", "chance": float(seen["listed"][m["name"]]), "won": m["won"]})


## QA-090: every sim exploration goes through here so a caller can watch it. `explore_observer`
## (optional, `func(region_id: String, days: int)`) runs after each explore_many.
static var explore_observer: Callable = Callable()


static func _explore(gs: Node) -> void:
	var region: String = gs.current_region
	var days: int = gs.explore_many(7)
	if explore_observer.is_valid():
		explore_observer.call(region, days)


## QA-092: a bitter rival spoils gathering in forest/marsh/mountain regions, so the curious player
## walks to the nearest such region (direct route) for the month's exploring. Returns the region to
## come back to ("" = no detour).
static func _bitter_detour(gs: Node, c: CharacterData) -> String:
	var rv := Rivals.rival_of(c, gs.npcs)
	if rv == null or Rivals.attitude(c, rv, int(gs.npc_favor.get(rv.id, 0)), gs.data) != "bitter":
		return ""
	var spoils_tags: Array = gs.data.encounters["rival_spoils_gathering"]["tags"]
	var tagged := func(region_id: String) -> bool:
		for t: String in gs.data.regions.get(region_id, {}).get("encounter_tags", []):
			if t in spoils_tags:
				return true
		return false
	if tagged.call(gs.current_region):
		return ""
	var home: String = gs.current_region
	var best := ""
	var best_days := 1 << 30
	for r: Dictionary in Exploration.routes(c, gs.data, home):
		if r["ok"] and tagged.call(r["to"]) and int(r["days"]) < best_days:
			best = String(r["to"])
			best_days = int(r["days"])
	if best == "":
		return ""
	gs.travel(best)
	return home if gs.current_region == best else ""


## QA-163: diff c.injuries against the open entries: new ids are logged (with the danger line that announced
## them), vanished ids are closed.
static func _injury_sync(gs: Node, c: CharacterData, day: int, open: Dictionary, seed_value: int, news: String) -> void:
	for id: String in c.injuries.keys():
		if open.has(id):
			continue
		var entry := {"seed": seed_value, "id": id, "day": day, "region": gs.current_region, "news": news, "days": int(c.injuries[id]), "qi_lost": Injuries.qi_days_lost_for(c, gs.data, id), "end": -1, "treated": false}
		open[id] = entry
		injury_log.append(entry)
	for id: String in open.keys():
		if news != "" and String(open[id]["news"]) == "" and news.begins_with(Injuries.injury_name(gs.data, id)):
			open[id]["news"] = news  # the combat/breakthrough line synced the injury first; the danger line follows
		if not c.injuries.has(id):
			var e: Dictionary = open[id]
			e["end"] = day
			e["treated"] = day - int(e["day"]) < int(e["days"]) - 2
			open.erase(id)


## The extra things a curious player does in one month: explore weekly, one
## harmless deed, one sect mission, one chat (once), deliver orders. Returns the
## set of action kinds done.
static func _curious_month(gs: Node, c: CharacterData, done: Dictionary, today: int) -> Dictionary:
	var kinds := {}
	if recharge_first and c.alive and c.artifact_lives >= 0 and c.artifact_lives <= Guidance.LOW_ARTIFACT_LIVES:
		if CreationArtifact.check_recharge(c, gs.data) == "" and c.item_count("spirit_stone") >= CreationArtifact.recharge_cost(c, gs.data):
			gs.recharge_artifact()
	if heal_injuries and c.alive and not c.injuries.is_empty():
		var stones_before := c.item_count("spirit_stone")
		var log := {"healed": 0}
		_heal_before_fighting(gs, c, log)
		heal_log["healed"] += int(log["healed"])
		heal_log["stones"] += maxi(0, stones_before - c.item_count("spirit_stone"))
	if heal_far and c.alive and not c.injuries.is_empty():
		_heal_far(gs, c)
	if village and c.alive:
		_village_month(gs, c)
	if follow_defence:
		_follow_defence_hint(gs, c)
	if practise_hint:
		_follow_practice_hint(gs, c)
	if season_tasks and c.alive:
		_season_task_month(gs, c)
	var detour_home := _bitter_detour(gs, c)
	for week in 3:
		if not c.alive:
			return kinds
		_follow_spar_hint(gs, c, today + week * 7)
		if season_tasks and c.alive:
			if week > 0:
				_season_task_month(gs, c)  # SEASON-026: the pass runs weekly
			_season_festival_watch(gs, c)
		if chat_teacher and c.alive:
			_chat_teacher_week(gs, c)
		if not c.alive:
			return kinds
		var seen := _explore_watched(gs, c, today)
		_explore(gs)
		_log_explore_fights(done, seen)
		kinds["explore"] = true
		if gs.pending_encounter != "":
			gs.choose_encounter(encounter_choice(c, gs.data, gs.data.encounters[gs.pending_encounter], gs.world_flags, gs.npcs))
		if gs.pending_threat != "":
			gs.face_threat(false)
	if season_tasks and c.alive:
		_season_task_month(gs, c)  # SEASON-026: the fourth weekly pass
	if detour_home != "" and c.alive:
		gs.travel(detour_home)
	if not c.alive:
		return kinds
	_buy_breakthrough_pill(gs, c, done)
	if not c.alive:
		return kinds
	if buy_qi:
		_buy_qi_pills(gs, c)
	if spend_contribution and not c.is_rogue():
		_spend_contribution(gs, c)
	if sect_method and not c.is_rogue():
		_buy_sect_method(gs, c)
	if body_art or trial_report:
		_body_art_month(gs, c, today)
	if shop_armor:
		_shop_for_armor(gs, c)
	var region: Dictionary = gs.data.regions.get(gs.current_region, {})
	for place: Dictionary in region.get("places", []):
		var ctx := String(place.get("deed_context", ""))
		if ctx == "" or kinds.has("deed"):
			continue
		for opt: Dictionary in Deeds.options(c, gs.data, ctx, gs.world_flags, today):
			var deed: Dictionary = opt["deed"]
			if opt["disabled"] or opt["lethal"] or done.has(deed["id"]) or deed.has("enemy") or int(deed.get("effects", {}).get("alignment", 0)) < 0:
				continue
			done[deed["id"]] = true
			gs.perform_deed(deed["id"])
			kinds["deed"] = true
			break
	# QA-067: what "Fights you can win" would list this month (empty list = a month of no suggestion).
	var fair := Guidance.fair_fights(c, gs.data, gs.world_flags, today, gs.current_region) if c.alive else ([] as Array[Dictionary])
	if not done.has("fair_log"):
		done["fair_log"] = {"listed": [], "taken": [], "by_kind": {}}
	done["fair_log"]["listed"].append(fair.size())
	for f: Dictionary in fair:
		var k := String(f.get("kind", ""))
		done["fair_log"]["by_kind"][k] = int(done["fair_log"]["by_kind"].get(k, 0)) + 1
	if not c.is_rogue() and c.alive and mission_monthly and int(c.sect.get("rank", 0)) <= 1:
		_take_monthly_mission(gs, c, done, kinds, fair, today)
	elif not c.is_rogue() and c.alive:
		if chase_best_mission:
			# QA-134: the hint names the best-paying mission ("The best pays N contribution"); take it, up to 3 a month.
			for _i in 3:
				var best := Guidance.best_mission(c, gs.data, gs.world_flags)
				if c.alive and best == "" and _i == 0:
					done["no_hint_months"] = int(done.get("no_hint_months", 0)) + 1  # QA-154
				if not c.alive or best == "" or not _mission_is_sane(gs, c, best, done, today):
					break
				_take_one_mission(gs, c, done, kinds, fair, best, today)
		else:
			for mission_id in Sects.available_missions(c, gs.data, gs.world_flags):
				if Sects.check_mission(c, gs.data, mission_id, gs.world_flags) != "" or not _mission_is_sane(gs, c, mission_id, done, today):
					continue
				_take_one_mission(gs, c, done, kinds, fair, mission_id, today)
				break
	if steward_chores and c.alive and not c.is_rogue():
		_do_steward_chores(gs, c, done, kinds, today)
	_attempt_open_trial(gs, c, done, kinds)
	_take_listed_deed(gs, c, done, fair, kinds, today)
	_take_listed_bounty(gs, c, done, fair, kinds)
	if not done.get("saving", false):
		if _recharge_with_spare_stones(gs, c):
			done["recharges"] = int(done.get("recharges", 0)) + 1
	_learn_fighting_style(gs, c, done, today)
	if not done.has("talk") and c.alive:
		for npc_id: String in gs.npcs:
			gs.start_dialogue(npc_id)
			if gs.in_dialogue():
				done["talk"] = true
				kinds["talk"] = true
				for choice: Dictionary in gs.dialogue_view().get("choices", []):
					if not choice.get("disabled", false):
						gs.choose_dialogue(int(choice["index"]))
						break
				if gs.in_dialogue():
					gs.end_dialogue()
				break
	for i in range(c.commissions.size() - 1, -1, -1):
		if c.alive and Commissions.check_deliver(c, gs.data, i) == "":
			gs.deliver_commission(i)
			kinds["commission"] = true
	if c.alive:
		_everything_month(gs, c, kinds, today, bool(done.get("no_help", false)))
	return kinds


## QA-227: the steward chore the duty hint names: while this month's duty is unmet and <= STEWARD_LAST_DAYS remain, do the
## best-paying chore of the home hall's steward (same deed the steward menu runs), walking there first when the hall is
## <= steward_max_days route days away. sect_log counts them via done["chores"] (read by play's report).
static func _do_steward_chores(gs: Node, c: CharacterData, done: Dictionary, kinds: Dictionary, today: int) -> void:
	var duty := Sects.monthly_duty(c, gs.data)
	if duty <= 0 or Sects.duty_progress(c) >= duty or bool(c.sect.get("duty_grace", false)):
		return
	var sect: SectDef = gs.data.sects[c.sect["id"]]
	var hall := sect.home_region
	var start: String = gs.current_region
	if start != hall:
		var d := Guidance.route_days(c, gs.data, start, hall)
		if d <= 0 or d > steward_max_days:
			return
		_walk_to(gs, c, hall)
	if c.alive and gs.current_region == hall:
		_run_chores(gs, c, duty, done, kinds, today)
	if c.alive and gs.current_region != start:
		_walk_to(gs, c, start)


## QA-228: do the steward's best-paying chore until this month's duty is met (or the sect month ends); done["chore_days"] counts the days.
static func _run_chores(gs: Node, c: CharacterData, duty: int, done: Dictionary, kinds: Dictionary, today: int) -> void:
	var hall := (gs.data.sects[c.sect["id"]] as SectDef).home_region
	var month_idx := c.age_days / Calendar.DAYS_PER_MONTH
	var progressed := true
	while progressed and c.alive and Sects.duty_progress(c) < duty and c.age_days / Calendar.DAYS_PER_MONTH == month_idx:
		progressed = false
		var best := {}
		var best_rate := 0.0
		for place: Dictionary in gs.data.regions.get(hall, {}).get("places", []):
			var ctx := String(place.get("deed_context", ""))
			if String(place.get("type", "")) != "deed_giver" or ctx == "":
				continue
			for opt: Dictionary in Deeds.options(c, gs.data, ctx, gs.world_flags, today):
				var deed: Dictionary = opt["deed"]
				var gain := int(deed.get("effects", {}).get("contribution", 0))
				if opt["disabled"] or not deed.get("requires", {}).has("sect") or gain <= 0:
					continue
				var rate := float(gain) / float(maxi(1, int(deed.get("days", 1))))
				if rate > best_rate:
					best_rate = rate
					best = deed
		if best.is_empty():
			break
		var before := c.age_days
		gs.perform_deed(String(best["id"]))
		done["chore_days"] = int(done.get("chore_days", 0)) + (c.age_days - before)
		done["chores"] = int(done.get("chores", 0)) + 1
		kinds["deed"] = true
		progressed = true


## QA-228: at the start of a sect month, when the duty is projected short (earned so far + the smallest mission on the board,
## if --mission-monthly is on, < the rank's duty), walk to the home hall, do chores until the duty is met or the month ends, and
## walk back to where the member stood. done["chore_walk_days"] counts the days spent walking, done["chore_trips"] the trips.
static func _walk_home_for_duty(gs: Node, c: CharacterData, done: Dictionary, kinds: Dictionary, today: int) -> void:
	if not steward_chores or not c.alive or c.is_rogue():
		return
	var duty := Sects.monthly_duty(c, gs.data)
	if duty <= 0 or bool(c.sect.get("duty_grace", false)):
		return
	var projected := Sects.duty_progress(c)
	if mission_monthly and int(c.sect.get("rank", 0)) <= 1:
		var least := 0
		for id: String in Sects.available_missions(c, gs.data, gs.world_flags):
			if Sects.check_mission(c, gs.data, id, gs.world_flags) == "":
				var gain := int(gs.data.sect_missions[id].get("contribution", 0))
				least = gain if least == 0 else mini(least, gain)
		projected += least
	if projected >= duty:
		return
	var hall := (gs.data.sects[c.sect["id"]] as SectDef).home_region
	var start: String = gs.current_region
	if start != hall:
		var d := Guidance.route_days(c, gs.data, start, hall)
		if d <= 0:
			return
		var before := c.age_days
		_walk_to(gs, c, hall)
		done["chore_walk_days"] = int(done.get("chore_walk_days", 0)) + (c.age_days - before)
	if c.alive and gs.current_region == hall:
		done["chore_trips"] = int(done.get("chore_trips", 0)) + 1
		_run_chores(gs, c, duty, done, kinds, today)
	if c.alive and gs.current_region != start:
		var before2 := c.age_days
		_walk_to(gs, c, start)
		done["chore_walk_days"] = int(done.get("chore_walk_days", 0)) + (c.age_days - before2)


static func _walk_to(gs: Node, c: CharacterData, target: String) -> void:
	for _hop in 8:
		if gs.current_region == target or not c.alive:
			return
		var before: String = gs.current_region
		var next := Guidance.first_hop(c, gs.data, before, target)
		if next == "":
			return
		gs.travel(next)
		if gs.current_region == before:
			return


## QA-136: when the hint says "The trial for <rank> is open" and its odds are >= TRIAL_MIN_ODDS, walk to a sect hall
## (the current region's, else the first region with one), attempt the trial through GameState and walk home.
## done["trials_won"] / done["trials_lost"] count the outcomes.
static func _attempt_open_trial(gs: Node, c: CharacterData, done: Dictionary, kinds: Dictionary) -> void:
	if not attempt_trials or not c.alive or c.is_rogue() or not c.injuries.is_empty():
		return
	if Guidance.trial_odds(c, gs.data) < TRIAL_MIN_ODDS:
		return
	var home: String = gs.current_region
	var hall_region := ""
	for rid: String in ([home] + gs.data.regions.keys()):
		for place: Dictionary in gs.data.regions.get(rid, {}).get("places", []):
			if String(place.get("type", "")) == "sect_hall":
				hall_region = rid
				break
		if hall_region != "":
			break
	if hall_region == "":
		return
	if home != hall_region:
		gs.travel(hall_region)
		if gs.current_region != hall_region or not c.alive:
			return
	var rank_before := int(c.sect["rank"])
	gs.attempt_promotion_trial()
	var won := c.alive and not c.is_rogue() and int(c.sect["rank"]) > rank_before
	done["trials_won" if won else "trials_lost"] = int(done.get("trials_won" if won else "trials_lost", 0)) + 1
	kinds["trial"] = true
	if home != hall_region and c.alive:
		gs.travel(home)


## QA-072: from Qi Refining 7th Layer, when Guidance.next_realm_pill names a pill a merchant sells, stop optional
## spending (done["saving"]) once stones reach 60% of its price and buy it as soon as they cover it (travelling to
## the merchant's region and back). The pill is taken right before the attempt (see play).
## QA-145: see far_qi. Returns the density to meditate at this month: the offered spot's after a move, else `density`
## (the Spirit Spring while still in Qingshi; the best local spot once the player has moved).
static func _move_for_qi(gs: Node, c: CharacterData, clock: Node, month: int, density: float, out: Dictionary) -> float:
	if out.has("far_qi_region"):
		return float(Guidance.best_qi_in_region(c, gs.data, gs.current_region, gs.world_flags)["density"])
	var offer := Guidance.far_qi_offer(c, gs.data, gs.current_region, gs.world_flags, density)
	if offer.is_empty() or int(offer["away"]) <= 0 or int(offer["days_here"]) - int(offer["days_far"]) - 2 * int(offer["away"]) < FAR_QI_MIN_SAVED:
		return density
	var target := String(offer["region"])
	var start: int = clock.total_days
	for hop in 12:
		if gs.current_region == target or not c.alive:
			break
		var next := Guidance.first_hop(c, gs.data, gs.current_region, target)
		if next == "":
			break
		var before: String = gs.current_region
		gs.travel(next)
		if gs.current_region == before:
			break
	if gs.current_region != target:
		return density
	far_qi_log["moved"] += 1
	far_qi_log["month"].append(month + 1)
	far_qi_log["road_days"].append(clock.total_days - start)
	out["far_qi_region"] = target
	far_qi_day = clock.total_days
	return float(Guidance.best_qi_in_region(c, gs.data, target, gs.world_flags)["density"])


static func _buy_breakthrough_pill(gs: Node, c: CharacterData, done: Dictionary) -> void:
	done["saving"] = false
	if c.realm_index != 1 or c.stage < 6 or c.breakthrough_pill != "" or not Guidance.breakthrough_items(c, gs.data).is_empty():
		return
	# QA-157: an Inner Disciple claims the pill from the sect treasury (GUIDE-132) instead of paying stones for it.
	if Guidance.sect_pill_claimable(c, gs.data):
		var claim_id := String(Guidance.sect_pill_entry(c, gs.data)["item_id"])
		if Sects.check_purchase(c, gs.data, claim_id) == "":
			gs.buy_with_contribution(claim_id)
			if c.item_count(claim_id) > 0:
				return
	var pill := Guidance.next_realm_pill(c, gs.data)
	if pill.is_empty():
		return
	var pill_id := String(pill["id"])
	var region_id := ""
	for rid: String in gs.data.regions:
		for place: Dictionary in gs.data.regions[rid].get("places", []):
			if String(place.get("type", "")) == "merchant" and Items.merchant_sells(gs.data, pill, place.get("stock_tags", []), int(place.get("max_price", 0))):
				region_id = rid
				break
		if region_id != "":
			break
	if region_id == "":
		return
	var price := Reputation.buy_price(c, gs.data, pill_id, "", gs.buy_multiplier())
	var stones := c.item_count("spirit_stone")
	done["saving"] = stones * 10 >= price * 6
	if stones < price:
		return
	var home: String = gs.current_region
	if home != region_id:
		gs.travel(region_id)
		if gs.current_region != region_id:
			return
	if c.alive:
		gs.buy_item(pill_id)
	if home != region_id and c.alive:
		gs.travel(home)


## QA-140: see shop_armor. Gate and budget mirror Guidance.armor_hint: an unarmored Qi Refining fighter who knows a
## combat style. Stones plus what the local buyer pays for loot must cover armor sold in the nearest region that has
## one; sell here, travel there, buy, wear, travel back.
static func _shop_for_armor(gs: Node, c: CharacterData) -> void:
	if c.realm_index != 1 or c.stage < Guidance.ARMOR_HINT_MIN_STAGE or c.equipment.get("armor", "") != "" or not Techniques.knows_kind(c, gs.data, "combat"):
		return
	var home: String = gs.current_region
	var offer := Guidance.sell_offer(c, gs.data, home)
	var budget := c.item_count("spirit_stone") + int(offer.get("total", 0))
	var far := Guidance.nearest_selling(c, gs.data, home, func(r: String) -> String: return Guidance.affordable_armor(c, gs.data, r, budget))
	if far.is_empty():
		return
	var armor_id: String = far["result"]
	var region_id: String = far["region_id"]
	if c.item_count("spirit_stone") < Guidance.merchant_price(c, gs.data, region_id, armor_id) and not offer.is_empty():
		_sell_loot_here(gs, c, home)
	if c.item_count("spirit_stone") < Guidance.merchant_price(c, gs.data, region_id, armor_id):
		return
	if region_id != home:
		gs.travel(region_id)
		if gs.current_region != region_id:
			return
		armor_log["trips"] += 1
	if c.alive:
		gs.buy_item(armor_id)
		if c.item_count(armor_id) > 0:
			gs.equip_item(armor_id)
			if armor_log["day"] < 0:
				armor_log["day"] = gs.get_node("/root/GameClock").total_days
	if region_id != home and c.alive:
		gs.travel(home)


## QA-140: sells every sellable stack the best buyer in `region_id` takes (the Sell all button).
static func _sell_loot_here(gs: Node, c: CharacterData, region_id: String) -> void:
	var best_ids: Array = []
	var best_total := 0
	for place: Dictionary in gs.data.regions[region_id].get("places", []):
		if String(place.get("type", "")) != "merchant":
			continue
		var ids := Items.bulk_sell_ids(c, gs.data, place.get("stock_tags", []), place.get("buy_tags", []))
		var total := Items.bulk_sell_total(c, gs.data, ids)
		if total > best_total:
			best_total = total
			best_ids = ids
	if best_ids.is_empty():
		return
	armor_log["stones_from_sales"] += gs.sell_all(best_ids)
	armor_log["sold"] += 1


## QA-181: see village. Only in Qingshi (the one region with a field, a jetty and a visitor spot for a newcomer). Sells crops by
## kind (herb tag items the field grows) and fish at the merchant price (Items.sell, seasonal).
static func _village_month(gs: Node, c: CharacterData) -> void:
	if gs.current_region != "qingshi_village":
		return
	var region: Dictionary = gs.data.regions[gs.current_region]
	var field := FieldPlots.place_def(gs.data, gs.current_region)
	var fish_places: Array = []
	for place: Dictionary in region.get("places", []):
		if String(place.get("type", "")) == "fishing":
			fish_places.append(place)
	var today: int = gs.get_node("/root/GameClock").total_days
	if not field.is_empty():
		var key := FieldPlots.key(gs.current_region, field)
		var crops: Dictionary = {}
		for id: String in FieldPlots.plantable(field):
			crops[id] = true
		if FieldPlots.rented(c, key, today):
			gs.harvest_field()
			var got := 0
			for id: String in crops:
				got += c.item_count(id)
			if got > 0:
				village_log["harvests"] += 1
				village_log["crops"] += got
		# a plantable herb in the pack, and the rent in hand
		var seed_id := ""
		for id: String in crops:
			if c.item_count(id) > 0 and (seed_id == "" or int(gs.data.items[id].get("price", 0)) < int(gs.data.items[seed_id].get("price", 0))):
				seed_id = id
		if not FieldPlots.rented(c, key, today) and seed_id != "" and c.item_count("spirit_stone") >= int(field["rent"]):
			var s0 := c.item_count("spirit_stone")
			gs.rent_field()
			village_log["rent"] += s0 - c.item_count("spirit_stone")
		if FieldPlots.rented(c, key, today):
			for i in FieldPlots.plots_for(c, field, key):
				if c.item_count(seed_id) <= 0:
					break
				gs.plant_field(seed_id)
			if tend:
				_tend_field(gs, c, field, key, seed_id)
		for id: String in crops:
			# QA-189: keep `plots` seeds of the crop it plants, sell the surplus (and every other kind)
			var n := c.item_count(id)
			if id == seed_id:
				n -= FieldPlots.plots_for(c, field, key)
			if n > 0:
				var s1 := c.item_count("spirit_stone")
				gs.sell_item(id, n)
				village_log["field_stones"] += c.item_count("spirit_stone") - s1
	# QA-190: forage: pick every pickup standing here today (no time cost) and sell the finds
	var found: Dictionary = {}
	for n: Dictionary in gs.forage_here():
		if gs.pick_forage(int(n["slot"])):
			found[String(n["item"])] = true
			village_log["forage_picked"] += 1
	village_log["forage_days"] += 1
	for id: String in found:
		var sf := c.item_count("spirit_stone")
		gs.sell_item(id, c.item_count(id))
		village_log["forage_stones"] += c.item_count("spirit_stone") - sf
	# fish: two trips a month, one on a rain day when it rains
	for place: Dictionary in fish_places:
		for trip in 2:
			if not c.alive:
				return
			gs.fish(place.get("catch_table", []), int(place.get("gather_days", 2)), String(place.get("display_name", "")))
			village_log["fish_days"] += int(place.get("gather_days", 2))
		var fish_ids: Array = []
		for id: String in c.inventory.keys():
			if "fish" in gs.data.items.get(id, {}).get("tags", []):
				fish_ids.append(id)
		var s2 := c.item_count("spirit_stone")
		gs.sell_all(fish_ids)
		village_log["fish_stones"] += c.item_count("spirit_stone") - s2
		break
	var visitor: String = gs.visitor_today()
	if visitor != "" and gs.check_tea(visitor) == "":
		gs.share_tea(visitor)
		village_log["teas"] += 1
	var q := Folk.open_quarrel(gs.world_flags, gs.current_region, today)
	if not q.is_empty() and gs.check_quarrel(String(q["a"])) == "":
		if not gs.settle_quarrel(String(q["a"]), "mediate").is_empty():
			village_log["quarrels"] += 1


## QA-184: see tend. One day at a time: water on a clear or cloudy day, nourish when qi allows, then let the day pass.
static func _tend_field(gs: Node, c: CharacterData, field: Dictionary, key: String, crop_id: String) -> void:
	for day in FieldPlots.care_needed(field, crop_id):
		if not c.alive:
			return
		var before: int = int(c.field_plots[key].get("watered_day", -1)) + int(c.field_plots[key].get("nourished_day", -1))
		gs.water_field()
		gs.nourish_field()
		if int(c.field_plots[key].get("watered_day", -1)) + int(c.field_plots[key].get("nourished_day", -1)) == before:
			continue
		gs._pass_time(1)
		village_log["tend_days"] += 1


## QA-144: see buy_qi. The reserve is the next realm pill's price in the last three stages while none is held.
static func _buy_qi_pills(gs: Node, c: CharacterData) -> void:
	if not buy_qi_travel:
		_buy_qi_here(gs, c)
		return
	# QA-234: ask the hint first; the old order bought the local pill whenever one was on sale, so a far pill the hint named was never followed.
	var offer := Guidance.qi_pill_offer_near(c, gs.data, gs.current_region, gs.world_flags)
	if offer.is_empty() or not offer.has("region_id") or String(offer["region_id"]) == gs.current_region or not c.alive:
		_buy_qi_here(gs, c)
		return
	if c.item_count("spirit_stone") <= 20:
		return
	qi_hint_far[_qi_seed] = int(qi_hint_far.get(_qi_seed, 0)) + 1
	var home: String = gs.current_region
	var start_day: int = gs.get_node("/root/GameClock").total_days
	var target := String(offer["region_id"])
	for hop in 12:
		if gs.current_region == target or not c.alive:
			break
		var next := Guidance.first_hop(c, gs.data, gs.current_region, target)
		if next == "":
			break
		var before: String = gs.current_region
		gs.travel(next)
		if gs.current_region == before:
			break
	if gs.current_region != target:
		return
	qi_trips += 1
	_qi_on_trip = true
	_buy_qi_here(gs, c)
	_qi_on_trip = false
	for hop in 12:
		if gs.current_region == home or not c.alive:
			break
		var back := Guidance.first_hop(c, gs.data, gs.current_region, home)
		if back == "":
			break
		var before2: String = gs.current_region
		gs.travel(back)
		if gs.current_region == before2:
			break
	qi_trip_log.append({"seed": _qi_seed, "region": target, "days": int(gs.get_node("/root/GameClock").total_days) - start_day})


## QA-144: buys and uses pills from the current region's merchants; true if any were bought.
static func _buy_qi_here(gs: Node, c: CharacterData) -> bool:
	var reserve := 0
	if Guidance._pill_goal_applies(c, gs.data):
		reserve = Guidance.next_realm_pill_price(c, gs.data)
	var spare := c.item_count("spirit_stone") - reserve - 20
	if spare <= 0:
		return false
	# Qi stops at the bottleneck, so only pills that fit in the room left are worth buying.
	# SIM-018: room to the bottleneck over every stage left (the offer's own measure), not just the last stage's cost.
	var room := Cultivation.qi_to_bottleneck(c, gs.data)
	var best_id := ""
	var best_price := 0
	var best_rate := 0.0
	for p: Dictionary in gs.data.regions.get(gs.current_region, {}).get("places", []):
		if String(p.get("type", "")) != "merchant":
			continue
		for item_id: String in gs.data.items:
			var item: Dictionary = gs.data.items[item_id]
			var fx: Dictionary = item.get("effects", {})
			if int(fx.get("qi", 0)) <= 0 or float(fx["qi"]) > room or fx.has("burn_lifespan") or int(fx.get("alignment", 0)) < 0 or not Items.merchant_sells(gs.data, item, p.get("stock_tags", []), int(p.get("max_price", 0))):
				continue
			var price := Guidance.merchant_price(c, gs.data, gs.current_region, item_id)
			# SIM-018: only what the purse reaches and the character may use (the offer's own filters), else the best-rate pill hides the one the hint names.
			if price > spare or Items.realm_block(c, gs.data, item_id) != "":
				continue
			var rate := float(fx["qi"]) / price
			if rate > best_rate:
				best_rate = rate
				best_id = item_id
				best_price = price
	if best_id == "" or best_price > spare:
		return false
	var count := mini(spare / best_price, int(room / float(gs.data.items[best_id]["effects"]["qi"])))
	var stones_before := c.item_count("spirit_stone")
	var had := c.item_count(best_id)
	gs.buy_item(best_id, "", count)
	var bought := c.item_count(best_id) - had
	qi_log["bought"] += bought
	if bought > 0:
		qi_buys.append({"seed": _qi_seed, "item": best_id, "region": String(gs.current_region), "trip": _qi_on_trip, "bought": bought, "stones": stones_before - c.item_count("spirit_stone"), "qi": 0})
	qi_log["stones"] += stones_before - c.item_count("spirit_stone")
	for i in bought:
		if not c.alive or Cultivation.is_at_bottleneck(c, gs.data):
			break
		var qi_before := c.qi
		gs.use_item(best_id)
		if c.item_count(best_id) < had + bought - i:
			qi_log["used"] += 1
			qi_log["qi"] += maxi(0, c.qi - qi_before)
			if not qi_buys.is_empty():
				qi_buys[-1]["qi"] += maxi(0, c.qi - qi_before)
	return bought > 0


## QA-148: see spend_contribution.
static func _spend_contribution(gs: Node, c: CharacterData) -> void:
	var data: GameData = gs.data
	var log := contribution_log
	var pill := Guidance.next_realm_pill(c, data)
	var pill_cost := 0
	var pill_open := false  # the pill is sold here and still to claim in this realm
	if not pill.is_empty() and c.realm_index == 1 and c.breakthrough_pill == "" and Guidance.breakthrough_items(c, data).is_empty():
		var entry := Sects.shop_entry(c, data, String(pill["id"]))
		if not entry.is_empty():
			pill_open = true
			pill_cost = int(entry["contribution"])
			if Guidance._pill_goal_applies(c, data) and Sects.check_purchase(c, data, String(pill["id"])) == "":
				gs.buy_with_contribution(String(pill["id"]))
				if c.item_count(String(pill["id"])) > 0:
					log["pill"] += pill_cost
					log["pill_days"].append(gs.get_node("/root/GameClock").total_days)
					pill_open = false
					pill_cost = 0
	if not Techniques.knows_kind(c, data, "body"):
		for entry: Dictionary in Sects.shop_items(c, data):
			var tech_id := Items.manual_technique(data, String(entry["item_id"]))
			if tech_id == "" or data.techniques[tech_id].kind != "body" or Sects.check_purchase(c, data, String(entry["item_id"])) != "":
				continue
			if Sects.contribution_balance(c) - int(entry["contribution"]) < pill_cost:
				continue
			gs.buy_with_contribution(String(entry["item_id"]))
			gs.use_item(String(entry["item_id"]))
			if Techniques.knows_kind(c, data, "body"):
				log["body"] += int(entry["contribution"])
			break
	var realm: RealmDef = data.realms[c.realm_index]
	var room := realm.qi_required(realm.stage_count() - 1) - c.qi
	var best_id := ""
	var best_cost := 0
	var best_qi := 0
	var best_rate := 0.0
	for entry: Dictionary in Sects.shop_items(c, data):
		var item: Dictionary = data.items.get(String(entry["item_id"]), {})
		var fx: Dictionary = item.get("effects", {})
		if int(fx.get("qi", 0)) <= 0 or int(fx["qi"]) > room or fx.has("burn_lifespan") or int(fx.get("alignment", 0)) < 0:
			continue
		var rate := float(fx["qi"]) / int(entry["contribution"])
		if rate > best_rate and Sects.check_purchase(c, data, String(entry["item_id"])) == "":
			best_rate = rate
			best_id = String(entry["item_id"])
			best_cost = int(entry["contribution"])
			best_qi = int(fx["qi"])
	if best_id == "":
		return
	var count := mini((Sects.contribution_balance(c) - pill_cost) / best_cost, room / best_qi)
	if qi_pill_cap >= 0:
		count = mini(count, qi_pill_cap)
	for i in count:
		if not c.alive or Cultivation.is_at_bottleneck(c, data):
			break
		var had := c.item_count(best_id)
		gs.buy_with_contribution(best_id)
		if c.item_count(best_id) <= had:
			break
		log["qi_items"] += 1
		log["qi_cost"] += best_cost
		var qi_before := c.qi
		gs.use_item(best_id)
		if c.item_count(best_id) <= had:
			log["qi_used"] += 1
			log["qi"] += maxi(0, c.qi - qi_before)


## QA-155: see body_art. The reserve is the next realm pill's contribution price while it is still to claim.
static func _body_art_month(gs: Node, c: CharacterData, today: int) -> void:
	var data: GameData = gs.data
	var log: Dictionary = body_art_log.get(int(gs.rng.seed), {"learned": -1, "odds": -1.0, "month": -1})
	body_art_log[int(gs.rng.seed)] = log
	if body_art and c.alive and not c.is_rogue() and not Techniques.knows_kind(c, data, "body"):
		var reserve := 0
		var pill := Guidance.next_realm_pill(c, data)
		if not pill.is_empty() and c.realm_index == 1 and c.breakthrough_pill == "" and Guidance.breakthrough_items(c, data).is_empty():
			reserve = int(Sects.shop_entry(c, data, String(pill["id"])).get("contribution", 0))
		var bought := false
		for entry: Dictionary in Sects.shop_items(c, data):
			var item_id := String(entry["item_id"])
			var tech_id := Items.manual_technique(data, item_id)
			if tech_id == "" or data.techniques[tech_id].kind != "body" or Techniques.knows(c, tech_id) or not data.techniques[tech_id].activation.is_empty():
				continue
			if Sects.check_purchase(c, data, item_id) == "" and Sects.contribution_balance(c) - int(entry["contribution"]) >= reserve:
				gs.buy_with_contribution(item_id)
				gs.use_item(item_id)
				bought = true
				break
		if not bought:
			var manual := _cheapest_body_manual(gs, c, gs.current_region)
			if manual != "":
				gs.buy_item(manual)
				gs.use_item(manual)
		if Techniques.knows_kind(c, data, "body"):
			log["learned"] = today
	if body_art and c.alive:
		for tech_id: String in c.techniques:
			if data.techniques[tech_id].kind == "body" and not Techniques.is_mastered(c, data, tech_id):
				gs.practice_technique(tech_id, 7)
				break
	if c.alive and float(log["odds"]) < 0.0:
		var odds := Guidance.trial_odds(c, data)
		if odds >= 0.0:
			log["odds"] = odds
			log["month"] = today / Calendar.DAYS_PER_MONTH


## QA-156: see sect_method.
static func _buy_sect_method(gs: Node, c: CharacterData) -> void:
	var data: GameData = gs.data
	var reserve := 0
	var pill := Guidance.next_realm_pill(c, data)
	if not pill.is_empty() and c.realm_index == 1 and c.breakthrough_pill == "" and Guidance.breakthrough_items(c, data).is_empty():
		reserve = int(Sects.shop_entry(c, data, String(pill["id"])).get("contribution", 0))
	var current := Techniques.method_rate_of(c, data, Techniques.main_method(c, data))
	var best_item := ""
	var best_tech := ""
	var best_rate := current
	for entry: Dictionary in Sects.shop_items(c, data):
		var item_id := String(entry["item_id"])
		var tech_id := Items.manual_technique(data, item_id)
		if tech_id == "" or not data.techniques[tech_id].is_method() or Techniques.knows(c, tech_id):
			continue
		var rate := Techniques.method_rate_of(c, data, tech_id)
		if rate <= best_rate or Sects.check_purchase(c, data, item_id) != "" or Sects.contribution_balance(c) - int(entry["contribution"]) < reserve:
			continue
		best_rate = rate
		best_item = item_id
		best_tech = tech_id
	if best_item == "":
		return
	gs.buy_with_contribution(best_item)
	gs.use_item(best_item)
	if not Techniques.knows(c, best_tech):
		return
	gs.set_main_method(best_tech)
	sect_method_log["day"].append(gs.get_node("/root/GameClock").total_days)
	sect_method_log["tech"].append(best_tech)


## QA-075: once a month, does the open chore fight "Fights you can win" lists at >= 0.7 (the list only covers the
## current region's deed givers, so no travel is needed) and logs whether it was won.
static func _take_listed_deed(gs: Node, c: CharacterData, done: Dictionary, fair: Array[Dictionary], kinds: Dictionary, today: int) -> void:
	if not c.alive:
		return
	for f: Dictionary in fair:
		if String(f["kind"]) != "deed" or float(f["chance"]) < 0.7:
			continue
		for place: Dictionary in gs.data.regions.get(gs.current_region, {}).get("places", []):
			if String(place.get("type", "")) != "deed_giver" or String(place.get("deed_context", "")) == "":
				continue
			for deed in Deeds.available(gs.data, String(place["deed_context"]), gs.world_flags):
				if not String(f.get("label", f["text"])).begins_with("%s: %s" % [place.get("display_name", "Chore"), deed["name"]]) or Deeds.check(c, gs.data, deed, gs.world_flags, today) != "":
					continue
				var won_before := LifeStats.get_stat(c, "fights_won")
				fight_origin = "deed"
				gs.perform_deed(String(deed["id"]))
				fight_origin = "other"
				_fair_log(done)["taken"].append({"kind": "deed", "chance": float(f["chance"]), "won": LifeStats.get_stat(c, "fights_won") > won_before})
				kinds["deed_fight"] = true
				return


## SIM-018: the listed chore one short route away (<= FAR_DEED_MAX_DAYS, odds >= 0.7): travels there, does it, walks home.
## True when the deed was done. The travel days pass on the clock like any other trip.
const FAR_DEED_MAX_DAYS := 3


static func _take_far_deed(gs: Node, c: CharacterData, done: Dictionary, fair: Array[Dictionary], kinds: Dictionary, today: int) -> bool:
	if not c.alive:
		return false
	var home: String = gs.current_region
	for f: Dictionary in fair:
		if String(f["kind"]) != "deed" or float(f["chance"]) < 0.7 or int(f.get("days", 0)) < 1 or int(f["days"]) > FAR_DEED_MAX_DAYS:
			continue
		for route: Dictionary in gs.data.regions.get(home, {}).get("routes", []):
			var away := String(route.get("to", ""))
			if int(route.get("days", 1)) != int(f["days"]):
				continue
			for place: Dictionary in gs.data.regions.get(away, {}).get("places", []):
				if String(place.get("type", "")) != "deed_giver" or String(place.get("deed_context", "")) == "":
					continue
				for deed in Deeds.available(gs.data, String(place["deed_context"]), gs.world_flags):
					if not String(f.get("label", "")).begins_with("%s in " % place.get("display_name", "Chore")) or not String(f.get("label", "")).ends_with(": %s" % deed["name"]) or Deeds.check(c, gs.data, deed, gs.world_flags, today) != "":
						continue
					gs.travel(away)
					if gs.current_region != away:
						return false
					var won_before := LifeStats.get_stat(c, "fights_won")
					fight_origin = "deed"
					gs.perform_deed(String(deed["id"]))
					fight_origin = "other"
					_fair_log(done)["taken"].append({"kind": "deed", "chance": float(f["chance"]), "won": LifeStats.get_stat(c, "fights_won") > won_before})
					kinds["deed_fight"] = true
					if c.alive:
						_walk_to(gs, c, home)
					return true
	return false


## SIM-016: the fair-fight log in `done`, created on first use (the hints policy never reaches the curious player's setup).
static func _fair_log(done: Dictionary) -> Dictionary:
	if not done.has("fair_log"):
		done["fair_log"] = {"listed": [], "taken": [], "by_kind": {}}
	return done["fair_log"]


## QA-070: once a month, takes the listed bounty when "Fights you can win" rates it >= 0.7 and no hunt is
## active: travels to its region if needed, explores until it is claimed (or 30 days), then goes home.
static func _take_listed_bounty(gs: Node, c: CharacterData, done: Dictionary, fair: Array[Dictionary], kinds: Dictionary) -> void:
	if not c.alive or not c.bounty.is_empty():
		return
	var entry := {}
	for f: Dictionary in fair:
		if String(f["kind"]) == "bounty" and float(f["chance"]) >= 0.7:
			entry = f
			break
	if entry.is_empty():
		return
	var today: int = gs.get_node("/root/GameClock").total_days
	var picked := {}
	for b: Dictionary in Bounties.offers(c, gs.data, today, gs.current_region):
		if String(gs.data.enemies.get(String(b.get("enemy", "")), {}).get("name", "")) == String(entry["enemy"]) and Bounties.check_take(c, gs.data, String(b["id"]), today) == "":
			picked = b
			break
	if picked.is_empty():
		return
	_hunt_bounty(gs, c, done, kinds, picked, float(entry["chance"]))


## SIM-016: "Goal: Finish a bounty": the offer here with the best rated odds, taken when they are >= 0.7 (the board's rating).
static func _take_best_bounty(gs: Node, c: CharacterData, done: Dictionary, kinds: Dictionary) -> void:
	if not c.alive or not c.bounty.is_empty():
		return
	var today: int = gs.get_node("/root/GameClock").total_days
	var picked := {}
	var best := 0.7
	for b: Dictionary in Bounties.offers(c, gs.data, today, gs.current_region):
		var foe: Dictionary = gs.data.enemies.get(String(b.get("enemy", "")), {})
		if foe.is_empty() or Bounties.check_take(c, gs.data, String(b["id"]), today) != "":
			continue
		var chance := Combat.win_chance(c, gs.data, foe)
		if chance >= best:
			best = chance
			picked = b
	if not picked.is_empty():
		_hunt_bounty(gs, c, done, kinds, picked, best)


## Takes `picked`, travels to its region, explores until it is claimed (or 30 days), then goes home.
static func _hunt_bounty(gs: Node, c: CharacterData, done: Dictionary, kinds: Dictionary, picked: Dictionary, chance: float) -> void:
	var today: int = gs.get_node("/root/GameClock").total_days
	var home: String = gs.current_region
	var where := String(picked["region"])
	var taken: Dictionary = bounty_log["taken"]
	taken[where] = int(taken.get(where, 0)) + 1
	if where != home:
		gs.travel(where)
		if gs.current_region != where:
			return
	var claimed := [0]
	var on_claim := func(_n: String, _s: int) -> void: claimed[0] += 1
	var bus: Node = gs.get_node("/root/EventBus")
	bus.bounty_claimed.connect(on_claim)
	gs.take_bounty(String(picked["id"]))
	if c.bounty.is_empty():
		bus.bounty_claimed.disconnect(on_claim)
		return
	var start: int = today
	var foe: Dictionary = gs.data.enemies[String(picked["enemy"])]
	while c.alive and not c.bounty.is_empty() and gs.get_node("/root/GameClock").total_days - start < 30:
		if Combat.win_chance(c, gs.data, foe) < 0.5:
			break  # QA-126: injured since taking it; a player gives the hunt up and heals first
		_explore(gs)
		if gs.pending_encounter != "":
			gs.choose_encounter(encounter_choice(c, gs.data, gs.data.encounters[gs.pending_encounter], gs.world_flags, gs.npcs))
		if gs.pending_threat != "":
			gs.face_threat(false)
	bus.bounty_claimed.disconnect(on_claim)
	_fair_log(done)["taken"].append({"kind": "bounty", "chance": chance, "won": claimed[0] > 0})
	kinds["bounty"] = true
	if c.alive and gs.current_region != home:
		gs.travel(home)


## QA-062: once per life, buys and reads the cheapest combat-technique manual a merchant in the
## current region sells (as soon as the stones allow), then practices an unmastered technique
## for a block each month. `done["style_month"]` records the month it was learned.
static func _learn_fighting_style(gs: Node, c: CharacterData, done: Dictionary, today: int) -> void:
	if not c.alive:
		return
	if not done.has("style_month"):
		var manual := cheapest_combat_manual(gs, c) if not teacher_reachable(gs, c) else ""  # QA-224
		if manual != "" and not done.get("saving", false) and c.item_count("spirit_stone") >= int(gs.data.items[manual].get("price", 0)):
			gs.buy_item(manual)
			gs.use_item(manual)
			if c.item_count(manual) == 0:
				done["style_month"] = today / Calendar.DAYS_PER_MONTH
	for tech_id: String in c.techniques:
		var def: TechniqueDef = gs.data.techniques[tech_id]
		if (def.kind == "combat" or (follow_defence and def.kind == "body")) and not Techniques.is_mastered(c, gs.data, tech_id) and c.alive:
			gs.practice_technique(tech_id, 7)
			break


## QA-138: when a hint says "<Name> (...) here would spar with you", spar with that NPC.
static func _follow_spar_hint(gs: Node, c: CharacterData, today: int) -> void:
	if not spar_hint or not c.alive:
		return
	for h: String in Guidance.hints(c, gs.data, gs.hint_density(), 5, gs.npcs, gs.world_flags, gs.current_region, today, gs.npc_favor):
		if not h.contains(" here would spar with you"):
			continue
		for npc_id: String in gs.npcs:
			var npc: CharacterData = gs.npcs[npc_id]
			if not h.begins_with("%s (" % npc.name):
				continue
			var reason: String = gs.check_spar(npc_id)
			if reason == "":
				gs.spar_with(npc_id)
				spar_log["bouts"] += 1
			else:
				spar_log["refused"].append(reason)
			return


## QA-220/QA-224: one week of the --chat-teacher policy (see chat_teacher). Records the first style's day and source, the weekly
## bout and the day it is mastered in _teach_rec. A named villager cannot be "chatted" with (Family.check_chat sends the player to
## the dialogue), so favor comes from gifts: the teacher Guidance.style_teacher names, within TEACHER_REACH_DAYS, is visited, given
## every liked item held (or bought here when the purse allows), and asked for the lesson once favor reaches its need.
static func _chat_teacher_week(gs: Node, c: CharacterData) -> void:
	if not Techniques.knows_kind(c, gs.data, "combat"):
		_visit_style_teacher(gs, c)
	else:
		for npc_id: String in gs.npcs:
			if Mentorship.teacher_bout_style(c, npc_id, gs.data, gs.world_flags) != "" and gs.check_spar(npc_id) == "":
				gs.spar_with(npc_id)
				_teach_rec["bouts"] += 1
				break
	_note_teacher_style(gs, c)


## True while a teacher's lesson is within reach, so the policy keeps its stones off the manual (QA-224).
static func teacher_reachable(gs: Node, c: CharacterData) -> bool:
	if not chat_teacher or Techniques.knows_kind(c, gs.data, "combat"):
		return false
	var teacher := Guidance.style_teacher(c, gs.npcs, gs.data, gs.current_region, gs.npc_favor, _day(gs))
	return not teacher.is_empty() and not bool(teacher.get("far", false)) and int(teacher.get("days", 99)) <= TEACHER_REACH_DAYS


const TEACHER_REACH_DAYS := 3


static func _visit_style_teacher(gs: Node, c: CharacterData, reach: int = TEACHER_REACH_DAYS, allow_far: bool = false) -> void:
	var teacher := Guidance.style_teacher(c, gs.npcs, gs.data, gs.current_region, gs.npc_favor, _day(gs))
	if teacher.is_empty() or (bool(teacher.get("far", false)) and not allow_far) or int(teacher["days"]) > reach:
		return
	var home: String = gs.current_region
	if gs.current_region != String(teacher["region_id"]) and not _go_to(gs, c, String(teacher["region_id"])):
		return
	var npc_id := String(teacher["npc_id"])
	_take_favor_errands(gs, c, npc_id)  # QA-231
	for day in 7:
		if not c.alive or Techniques.knows_kind(c, gs.data, "combat"):
			break
		if int(gs.npc_favor.get(npc_id, 0)) >= int(teacher["need"]):
			_ask_lesson(gs, npc_id)
			break
		var gave := false
		for liked: String in gs.data.npcs[npc_id].get("likes", []):
			if not gs.data.items.has(liked):
				continue
			if c.item_count(liked) == 0 and c.item_count("spirit_stone") >= int(gs.data.items[liked].get("price", 0)) + SPARE_STONES:
				gs.buy_item(liked)
			while c.item_count(liked) > 0 and int(gs.npc_favor.get(npc_id, 0)) < int(teacher["need"]):
				var before := int(gs.npc_favor.get(npc_id, 0))
				gs.give_gift(npc_id, liked)
				if int(gs.npc_favor.get(npc_id, 0)) == before and c.item_count(liked) > 0:
					break
				gave = true
				_teach_rec["chats"] += 1
		if not gave:
			break
	if c.alive and gs.current_region != home:
		_go_to(gs, c, home)


const SPARE_STONES := 5


## QA-231: before gifting, takes every available deed of the teacher's errand context whose `favor` names him (C-380's snare line).
static func _take_favor_errands(gs: Node, c: CharacterData, npc_id: String) -> void:
	var context := String(gs.data.npcs[npc_id].get("deed_context", ""))
	if context == "":
		return
	for deed: Dictionary in Deeds.available(gs.data, context, gs.world_flags):
		if not c.alive or not (deed.get("favor", {}) as Dictionary).has(npc_id):
			continue
		if Deeds.check(c, gs.data, deed, gs.world_flags, _day(gs)) != "":
			continue
		gs.perform_deed(String(deed["id"]))
		_teach_rec["errands"] = int(_teach_rec.get("errands", 0)) + 1


## Opens the teacher's dialogue and takes the "Show me ..." choice, then whatever choice follows, until a style is learned.
static func _ask_lesson(gs: Node, npc_id: String) -> void:
	gs.start_dialogue(npc_id)
	for step in 3:
		if not gs.in_dialogue():
			return
		var pick := -1
		for choice: Dictionary in gs.dialogue_view().get("choices", []):
			if choice.get("disabled", false):
				continue
			if pick < 0 and not String(choice["label"]).begins_with("Later"):
				pick = int(choice["index"])
			if String(choice["label"]).begins_with("Show me"):
				pick = int(choice["index"])
				break
		if pick < 0:
			break
		gs.choose_dialogue(pick)
	if gs.in_dialogue():
		gs.end_dialogue()


## QA-215: see season_tasks. Does each open task that can be reached, then returns to the region it started in.
static func _season_task_month(gs: Node, c: CharacterData) -> void:
	var home: String = gs.current_region
	var today := _day(gs)
	for t: Dictionary in SeasonTasks.tasks_for(gs.data, today):
		if not c.alive:
			return
		if bool(c.season_tasks.get("done", false)) and String(c.season_tasks.get("season_key", "")) == SeasonTasks.season_key(today):
			break
		if _season_task_left(gs, c, t) <= 0:
			continue
		_season_tries = 0
		match String(t["kind"]):
			"catch", "gather":
				_season_gather(gs, c, t)
			"hunt":
				_season_hunt(gs, c, t)
			"contest":
				_season_contest(gs, c, t)
			"sell_wanted":
				_season_sell(gs, c, t)
	if c.alive and gs.current_region != home:
		_go_to(gs, c, home)


## SEASON-024: a player watches the calendar: when an open contest task's festival is on in reach and its days are not
## over before the walk there ends, go now and enter (then walk home).
static func _season_festival_watch(gs: Node, c: CharacterData) -> void:
	var home: String = gs.current_region
	var today := _day(gs)
	if bool(c.season_tasks.get("done", false)) and String(c.season_tasks.get("season_key", "")) == SeasonTasks.season_key(today):
		return
	for t: Dictionary in SeasonTasks.tasks_for(gs.data, today):
		if String(t["kind"]) != "contest" or _season_task_left(gs, c, t) <= 0:
			continue
		for rid in _near_regions(gs, c):
			var inst := WorldEvents.instance_in(gs.world_events, String(t["target"]), rid)
			if inst.is_empty():
				continue
			var walk := 0 if rid == gs.current_region else Guidance.route_days(c, gs.data, gs.current_region, rid)
			if walk >= 0 and today + walk < int(inst.get("end_day", 0)):
				_season_contest(gs, c, t)
	if c.alive and gs.current_region != home:
		_go_to(gs, c, home)


## SEASON-026: places tried for the current task this week; a failed try moves on to the next place until SEASON_PLACES_PER_WEEK.
static var _season_tries := 0
const SEASON_PLACES_PER_WEEK := 2


## Counts a try; true when another place may be tried (the task is still open and the week's budget is not spent).
static func _season_more(gs: Node, c: CharacterData, t: Dictionary) -> bool:
	_season_tries += 1
	return c.alive and _season_tries < SEASON_PLACES_PER_WEEK and _season_task_left(gs, c, t) > 0


static func _season_why(gs: Node, t: Dictionary, reason: String) -> void:
	season_why["%d|%s|%s" % [season_seed, SeasonTasks.season_key(_day(gs)), String(t["id"])]] = reason


static func _season_task_left(gs: Node, c: CharacterData, t: Dictionary) -> int:
	var st: Dictionary = c.season_tasks
	if String(st.get("season_key", "")) != SeasonTasks.season_key(_day(gs)):
		return int(t["count"])
	return int(t["count"]) - int((st.get("progress", {}) as Dictionary).get(String(t["id"]), 0))


## Region ids within SEASON_REACH_DAYS of here (here first), nearest first.
static func _near_regions(gs: Node, c: CharacterData) -> Array[String]:
	var found: Array = []
	for rid: String in gs.data.regions:
		var d := 0 if rid == gs.current_region else Guidance.route_days(c, gs.data, gs.current_region, rid)
		if d >= 0 and d <= SEASON_REACH_DAYS:
			found.append([d, rid])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[String] = []
	for f: Array in found:
		out.append(String(f[1]))
	return out


static func _go_to(gs: Node, c: CharacterData, rid: String) -> bool:
	if gs.current_region != rid and c.alive:
		gs.travel(rid)
	return c.alive and gs.current_region == rid


static func _season_gather(gs: Node, c: CharacterData, t: Dictionary) -> void:
	var kind := String(t["kind"])
	var season := Calendar.season_of(_day(gs))
	var why := "no place in reach"
	for rid in _near_regions(gs, c):
		for place: Dictionary in gs.data.regions[rid].get("places", []):
			var table: Array = place.get("catch_table", []) if kind == "catch" else place.get("gather_table", [])
			var hit := false
			for e: Dictionary in table:
				if String(e.get("item", "")) == String(t["target"]):
					if Exploration.in_season(e, season.to_lower()):
						hit = true
					elif why == "no place in reach":
						why = "out of season"
			if not hit or not _go_to(gs, c, rid):
				continue
			season_task_log["trips"] += 1
			_season_why(gs, t, "too few lucky days")
			for trip in 6:
				if not c.alive or _season_task_left(gs, c, t) <= 0:
					return
				var days := int(place.get("gather_days", 2))
				if kind == "catch":
					gs.fish(table, days, String(place.get("display_name", "")))
					season_task_log["catch_days"] += days
				else:
					gs.gather(table, days)
					season_task_log["gather_days"] += days
			if not _season_more(gs, c, t):
				return
	_season_why(gs, t, why)


static func _season_hunt(gs: Node, c: CharacterData, t: Dictionary) -> void:
	var target := String(t["target"])
	var enemy: Dictionary = gs.data.enemies.get(target, {})
	if enemy.is_empty() or Combat.win_chance(c, gs.data, enemy) < 0.4:
		_season_why(gs, t, "hunt odds under 40%")
		return
	_season_why(gs, t, "no place in reach")
	var season := Calendar.season_of(_day(gs)).to_lower()
	for rid in _near_regions(gs, c):
		var quarry := VillageHunt.quarry(gs.data, rid, _day(gs))
		var by_hunt := quarry == target
		var sites := Exploration.sites_with_foe(c, gs.data, rid, target, season, _day(gs))
		if not by_hunt and sites.is_empty():
			continue
		if not _go_to(gs, c, rid):
			return
		_season_why(gs, t, "foe did not show")
		season_task_log["trips"] += 1
		if by_hunt and gs.village_hunt_quarry() == target:
			gs.join_village_hunt()
			season_task_log["hunts"] += 1
			if _season_task_left(gs, c, t) <= 0 or not c.alive:
				return
		if sites.is_empty():
			if _season_more(gs, c, t):
				continue
			return
		for round in 3:
			if not c.alive or _season_task_left(gs, c, t) <= 0:
				return
			_explore(gs)
			season_task_log["hunts"] += 1
			if gs.pending_encounter != "":
				gs.choose_encounter(encounter_choice(c, gs.data, gs.data.encounters[gs.pending_encounter], gs.world_flags, gs.npcs))
			if gs.pending_threat != "":
				gs.face_threat(false)
		if not _season_more(gs, c, t):
			return


static func _season_contest(gs: Node, c: CharacterData, t: Dictionary) -> void:
	var event_id := String(t["target"])
	_season_why(gs, t, "out of season")
	for rid in _near_regions(gs, c):
		if WorldEvents.instance_in(gs.world_events, event_id, rid).is_empty():
			continue
		if not _go_to(gs, c, rid):
			return
		_season_why(gs, t, "lost the contest")
		if gs.check_festival_contest(event_id) == "":
			gs.festival_contest(event_id)
			season_task_log["contests"] += 1
		if not _season_more(gs, c, t):
			return


static func _season_sell(gs: Node, c: CharacterData, t: Dictionary) -> void:
	var why := "no place in reach"
	var waiting := {}  # nearest closed stall that wants goods: {rid, place, wait}
	for rid in _near_regions(gs, c):
		for place: Dictionary in gs.data.regions[rid].get("places", []):
			if not place.has("wanted"):
				continue
			var w := Places.wanted_today(place, _day(gs))
			if w.is_empty():
				var wait := Places.days_until_open(place, _day(gs))
				if wait > 0 and (waiting.is_empty() or wait < int(waiting["wait"])):
					waiting = {"rid": rid, "place": place, "wait": wait}
				why = "stall closed"
				continue
			if c.item_count(String(w["item"])) <= 0 and not _season_buy_wanted(gs, c, String(w["item"]), maxi(1, _season_task_left(gs, c, t))):
				why = "could not afford"
				continue
			if not _go_to(gs, c, rid):
				return
			gs.shop_name = String(place.get("display_name", ""))
			var before := _season_task_left(gs, c, t)
			gs.sell_item(String(w["item"]), mini(c.item_count(String(w["item"])), maxi(1, before)))
			gs.shop_name = ""
			season_task_log["sold"] += before - _season_task_left(gs, c, t)
			_season_why(gs, t, "" if _season_task_left(gs, c, t) <= 0 else "too few wanted goods")
			if not _season_more(gs, c, t):
				return
			continue
	_season_why(gs, t, why)
	# SEASON-025: nothing is wanted today: wait at the nearest stall for its open day, then sell what we can afford.
	if not waiting.is_empty() and int(waiting["wait"]) <= SEASON_STALL_WAIT_DAYS and _go_to(gs, c, String(waiting["rid"])):
		season_task_log["stall_waits"] += 1
		var left_days := int(waiting["wait"])
		while left_days > 0 and c.alive:
			var step := mini(left_days, 5)
			gs.cultivate(step)
			left_days -= step
		if c.alive and not Places.wanted_today(waiting["place"], _day(gs)).is_empty():
			_season_sell(gs, c, t)


## SEASON-024: buy `count` of `item_id` in the nearest merchant within reach that sells it and that we can afford
## (the policy then walks to the stall). Returns whether we now hold at least one.
static func _season_buy_wanted(gs: Node, c: CharacterData, item_id: String, count: int) -> bool:
	var item: Dictionary = gs.data.items.get(item_id, {})
	if item.is_empty():
		return false
	var home: String = gs.current_region
	for rid in _near_regions(gs, c):
		for p: Dictionary in gs.data.regions[rid].get("places", []):
			if String(p.get("type", "")) != "merchant" or not Items.merchant_sells(gs.data, item, p.get("stock_tags", []), int(p.get("max_price", 0))):
				continue
			var price := Guidance.merchant_price(c, gs.data, rid, item_id)
			if price <= 0 or price * count > c.item_count("spirit_stone"):
				continue
			if not _go_to(gs, c, rid):
				return false
			gs.shop_name = String(p.get("display_name", ""))
			gs.buy_item(item_id, "", count)
			gs.shop_name = ""
			season_task_log["bought"] += c.item_count(item_id)
			return c.item_count(item_id) > 0
	if c.alive and gs.current_region != home:
		_go_to(gs, c, home)
	return false


## QA-220: first combat style known (and how) and the day it is mastered, from the clock.
static func _day(gs: Node) -> int:
	return int(gs.get_node("/root/GameClock").total_days)


static func _note_teacher_style(gs: Node, c: CharacterData) -> void:
	if not c.alive or _teach_rec.is_empty():
		return
	for tech_id: String in c.techniques:
		if (gs.data.techniques[tech_id] as TechniqueDef).kind != "combat":
			continue
		if int(_teach_rec["style_day"]) < 0:
			_teach_rec["style_day"] = _day(gs)
			_teach_rec["source"] = "lesson" if String(gs.world_flags.get(Mentorship.taught_by_key(tech_id), "self")) not in ["", "self"] else "manual"
		if int(_teach_rec["mastered_day"]) < 0 and Techniques.is_mastered(c, gs.data, tech_id):
			_teach_rec["mastered_day"] = _day(gs)
		break


## QA-220: median first-style day, source split, bouts and median mastery day over `runs`.
static func teacher_summary(runs: Array) -> String:
	var days: Array = []
	var masters: Array = []
	var sources := {"lesson": 0, "manual": 0, "": 0}
	var bouts := 0
	for r: Dictionary in runs:
		var t: Dictionary = r.get("teacher", {})
		if t.is_empty():
			continue
		if int(t["style_day"]) >= 0:
			days.append(int(t["style_day"]))
		if int(t["mastered_day"]) >= 0:
			masters.append(int(t["mastered_day"]))
		sources[String(t["source"])] += 1
		bouts += int(t["bouts"])
	days.sort()
	masters.sort()
	return "first style: median day %s (%d/%d seeds; lesson %d, manual %d), bouts %d, mastered: median day %s (%d seeds)" % [str(days[days.size() / 2]) if not days.is_empty() else "-", days.size(), runs.size(), sources["lesson"], sources["manual"], bouts, str(masters[masters.size() / 2]) if not masters.is_empty() else "-", masters.size()]


## QA-123: while Guidance.practice_hint speaks, practise its style until the next level (at most 60 days a month).
static func _follow_practice_hint(gs: Node, c: CharacterData) -> void:
	if not c.alive or Guidance.practice_hint(c, gs.data) == "":
		return
	var id := Techniques.practice_target(c, gs.data)
	var days := mini(Techniques.days_to_next(c, gs.data, id), 60)
	if id != "" and days > 0:
		gs.practice_technique(id, days)


## The cheapest manual of a plain combat technique (no lifespan cost) that a merchant in the
## player's region sells, or "" when there is none or the player already knows it.
static func cheapest_combat_manual(gs: Node, c: CharacterData) -> String:
	var region: Dictionary = gs.data.regions.get(gs.current_region, {})
	var best := ""
	for place: Dictionary in region.get("places", []):
		if String(place.get("type", "")) != "merchant":
			continue
		for tech: TechniqueDef in gs.data.techniques.values():
			if tech.kind != "combat" or tech.manual_item == "" or not tech.activation.is_empty() or Techniques.knows(c, tech.id):
				continue
			var item: Dictionary = gs.data.items.get(tech.manual_item, {})
			if item.is_empty() or not Items.merchant_sells(gs.data, item, place.get("stock_tags", []), int(place.get("max_price", 0))):
				continue
			if best == "" or int(item["price"]) < int(gs.data.items[best]["price"]):
				best = tech.manual_item
	return best


## QA-048: the rest of what the menus offer, each tried once a month and only when the core
## check allows it: craft, profession work, gift, pointers/spar, lecture, secret realm, and
## (every 6th month) a trip to the nearest unvisited region and back.
static func _everything_month(gs: Node, c: CharacterData, kinds: Dictionary, today: int, no_help: bool = false) -> void:
	for recipe_id: String in gs.data.recipes:
		if c.alive and Alchemy.check(c, gs.data, recipe_id) == "":
			gs.refine(recipe_id)
			kinds["craft"] = true
			break
	if c.alive:
		for prof_id: String in c.professions:
			gs.work_profession(prof_id, 7)
			kinds["work"] = true
			break
	if c.alive:
		var best_id := ""
		# QA-060: befriend a teacher first. Gifts to "the highest-favor NPC" went to a stranger-turned-friend
		# and Elder Mo never reached the favor pointers need.
		for npc_id: String in gs.npcs:
			var npc: CharacterData = gs.npcs[npc_id]
			if not npc.alive or Npcs.region_of(npc, gs.data) != gs.current_region or not Mentorship.is_senior(c, npc):
				continue
			if best_id == "" or int(gs.npc_favor.get(npc_id, 0)) > int(gs.npc_favor.get(best_id, 0)):
				best_id = npc_id
		if best_id == "":
			for npc_id: String in gs.npcs:
				if gs.npcs[npc_id].alive and (best_id == "" or int(gs.npc_favor.get(npc_id, 0)) > int(gs.npc_favor.get(best_id, 0))):
					best_id = npc_id
		var cheapest := ""
		for item_id: String in c.inventory:
			if Family.gift_value(gs.data, item_id) > 0 and Family.check_gift(c, gs.npcs.get(best_id), int(gs.npc_favor.get(best_id, 0)), item_id, gs.data) == "":
				# QA-188: never hand over a disliked item; a liked one beats a cheaper neutral one.
				var taste := Family.gift_taste(gs.data, best_id, item_id)
				if taste < 0:
					continue
				var cheap_taste := Family.gift_taste(gs.data, best_id, cheapest) if cheapest != "" else -2
				if cheapest == "" or taste > cheap_taste or (taste == cheap_taste and int(gs.data.items[item_id].get("price", 0)) < int(gs.data.items[cheapest].get("price", 0))):
					cheapest = item_id
		if best_id != "" and cheapest != "":
			gs.give_gift(best_id, cheapest)
			kinds["gift"] = true
	# QA-087: cross hands with the rival when GUIDE-033 lists the bout as a fair fight.
	if c.alive and c.rival != "":
		for f: Dictionary in Guidance.fair_fights(c, gs.data, gs.world_flags, today, gs.current_region, gs.npcs, gs.npc_favor):
			if f["kind"] == "rival" and gs.check_spar(c.rival) == "":
				gs.spar_with(c.rival)
				kinds["spar"] = true
				break
	if c.alive and not no_help:
		for npc_id: String in gs.npcs:
			if gs.check_pointers(npc_id) == "":
				gs.ask_pointers(npc_id)
				kinds["pointer"] = true
				break
			if npc_id != c.rival and gs.check_spar(npc_id) == "":
				gs.spar_with(npc_id)
				kinds["spar"] = true
				break
	if c.alive and not c.is_rogue() and Sects.check_lecture(c, gs.data, today) == "":
		gs.attend_lecture()
		kinds["lecture"] = true
	if c.alive:
		for realm_id: String in gs.data.secret_realms:
			if SecretRealms.check_enter(c, gs.data, realm_id, gs.current_region, today) != "":
				continue
			var floor_def := SecretRealms.next_floor(c, gs.data.secret_realms[realm_id], today)
			var guardian := String(floor_def.get("guardian", ""))
			if guardian != "" and Combat.win_chance(c, gs.data, gs.data.enemies[guardian]) < 0.6:
				continue  # retreat from a floor that is too dangerous
			gs.enter_secret_realm(realm_id)
			kinds["secret_realm"] = true
			break
	if c.alive and today / Calendar.DAYS_PER_MONTH % 6 == 5:
		var routes := Guidance.unexplored_routes(c, gs.data, gs.current_region)
		if not routes.is_empty():
			var home: String = gs.current_region
			gs.travel(String(routes[0]["to"]))
			if gs.current_region != home:
				_explore(gs)
				if gs.pending_encounter != "":
					gs.choose_encounter(encounter_choice(c, gs.data, gs.data.encounters[gs.pending_encounter], gs.world_flags, gs.npcs))
				if gs.pending_threat != "":
					gs.face_threat(false)
				kinds["travel"] = true
				if c.alive:
					gs.travel(home)


## QA-126: the first open choice that is not a fight rated below 50% (a player reads the
## odds on the choice before accepting a duel); 0 when every choice is a bad fight.
static func encounter_choice(c: CharacterData, data: GameData, encounter: Dictionary, flags: Dictionary, people: Dictionary) -> int:
	for choice: Dictionary in Exploration.choices(c, data, encounter, flags, people):
		if choice["disabled"]:
			continue
		if not choice["fight"] or choice["chance"] < 0.0 or choice["chance"] >= 0.5:
			return int(choice["index"])
	return 0


## QA-174: one mission this month, only where the board is (Sects.board_reason) and only if rated Even or better.
static func _take_monthly_mission(gs: Node, c: CharacterData, done: Dictionary, kinds: Dictionary, fair: Array[Dictionary], today: int) -> void:
	var best := Guidance.best_mission(c, gs.data, gs.world_flags)
	if best == "" or Sects.check_mission(c, gs.data, best, gs.world_flags, gs.current_region) != "":
		return
	if _mission_odds(gs, c, best) < Guidance.FAIR_FIGHT_MIN_CHANCE or not _mission_is_sane(gs, c, best, done, today):
		return
	_take_one_mission(gs, c, done, kinds, fair, best, today)


## Takes one mission and logs its outcome. Missions need no travel (Sects.check_mission has no place rule).
static func _take_one_mission(gs: Node, c: CharacterData, done: Dictionary, kinds: Dictionary, fair: Array[Dictionary], mission_id: String, today: int) -> void:
	var lost_before := LifeStats.get_stat(c, "fights_lost")
	var odds_before := _mission_odds(gs, c, mission_id)
	var won_before := LifeStats.get_stat(c, "fights_won")
	var label := "Sect mission: %s" % gs.data.sect_missions[mission_id]["name"]
	var listed_chance := -1.0
	for f: Dictionary in fair:
		if String(f["text"]).begins_with(label):
			listed_chance = float(f["chance"])
	fight_origin = "mission"
	gs.take_mission(mission_id)
	fight_origin = "other"
	if listed_chance >= 0.0:
		done["fair_log"]["taken"].append({"kind": "mission", "chance": listed_chance, "won": LifeStats.get_stat(c, "fights_won") > won_before})
	kinds["mission"] = true
	if LifeStats.get_stat(c, "fights_lost") > lost_before:
		done["lost_missions"][mission_id] = {"day": today, "odds": odds_before}


## Rated win chance against the mission's foe (1.0 when it has none).
static func _mission_odds(gs: Node, c: CharacterData, mission_id: String) -> float:
	var enemy_id := String(gs.data.sect_missions.get(mission_id, {}).get("enemy", ""))
	if enemy_id == "" or not gs.data.enemies.has(enemy_id):
		return 1.0
	return Combat.win_chance(c, gs.data, gs.data.enemies[enemy_id])


## QA-054: a sensible player skips Deadly foes, a mission just lost until the odds rise
## 15 points (or 60 days pass), and Dangerous foes under 50% when the artifact has 2 lives or fewer.
static func _mission_is_sane(gs: Node, c: CharacterData, mission_id: String, done: Dictionary, today: int) -> bool:
	if not done.has("lost_missions"):
		done["lost_missions"] = {}
	if hint_missions:
		return true
	var danger := Sects.mission_danger(c, gs.data, mission_id)
	if danger == "Deadly":
		return false
	var odds := _mission_odds(gs, c, mission_id)
	if odds < min_mission_odds:
		return false
	var lost: Dictionary = done["lost_missions"].get(mission_id, {})
	if not lost.is_empty() and today - int(lost["day"]) < 60 and odds < float(lost["odds"]) + 0.15:
		return false
	if c.artifact_lives >= 0 and c.artifact_lives <= 1 and odds < 0.85:
		return false  # the last life: only near-certain fights
	# QA-091: under 50% only while the artifact still holds 3+ lives, whatever the danger label says.
	return not (odds < 0.5 and c.artifact_lives >= 0 and c.artifact_lives <= 2)


## QA-054: buys an artifact life once stones exceed twice its price.
static func _recharge_with_spare_stones(gs: Node, c: CharacterData) -> bool:
	if not c.alive or c.artifact_lives < 0:
		return false
	if CreationArtifact.check_recharge(c, gs.data) == "" and c.item_count("spirit_stone") > (1 if c.artifact_lives <= 1 else 2) * CreationArtifact.recharge_cost(c, gs.data):
		gs.recharge_artifact()
		return true
	return false


## SIM-012: reads `--start=<region_id>` and `--join=<sect_id>` from a command line; returns true for an argument it consumed.
static func parse_start_arg(arg: String) -> bool:
	if arg.begins_with("--start="):
		start_region = arg.substr(8)
		return true
	if arg.begins_with("--join="):
		join_sect_id = arg.substr(7)
		return true
	return false


## SIM-010: one sim month of the hints player: four weekly steps (see hints_policy). Returns the kinds of action taken.
static func _hints_month(gs: Node, c: CharacterData, done: Dictionary, today: int, density: float) -> Dictionary:
	var kinds := {}
	for week in 4:
		if not c.alive:
			break
		var day: int = gs.get_node("/root/GameClock").total_days
		var region_before: String = gs.current_region
		hints_log["weeks"] += 1
		var acted := ""
		var acted_line := ""
		var skipped: Array[String] = []
		var tries: Dictionary = done.get_or_add("hint_tries", {})
		for line: String in _next_steps(gs, c, day):
			# A line acted on HINT_MAX_TRIES times that is still there is one the policy cannot finish: a player moves on.
			if int(tries.get(line, 0)) < HINT_MAX_TRIES:
				acted = _act_on_hint(gs, c, done, line, day)
			if acted != "":
				acted_line = line
				tries[line] = int(tries.get(line, 0)) + 1
				break
			skipped.append(line)
		if acted == "":
			# GUIDE-275: a great beast that is not for now: the player cultivates the week (raising the odds the line rates).
			for line in skipped:
				if line.begins_with("Goal: Beat a great beast"):
					acted = _prepare_week(gs, c)
					acted_line = line
					break
			if acted != "":
				skipped.erase(acted_line)
		for line in skipped:
			var key := RegEx.create_from_string("\\d+").sub(line, "N", true)
			key = key.substr(0, 70)
			hints_log["unmatched"][key] = int(hints_log["unmatched"].get(key, 0)) + 1
		if acted == "":
			hints_log["idle_weeks"] += 1
			# GUIDE-272: what the Next-steps card said on an idle week (normalised), for --idle-dump.
			var idle_key := " || ".join(skipped).replace("\n", " ")
			idle_key = RegEx.create_from_string("\\d+").sub(idle_key, "N", true).substr(0, 700)
			if idle_key == "":
				idle_key = "(no lines)"
			(hints_log.get_or_add("idle_lists", {}) as Dictionary)[idle_key] = int((hints_log["idle_lists"] as Dictionary).get(idle_key, 0)) + 1
			if c.alive:
				gs.cultivate(7, density)
			kinds["meditate"] = true
		else:
			hints_log["acted"][acted] = int(hints_log["acted"].get(acted, 0)) + 1
			# SIM-011: per-line tally of lines acted on (the unmatched tally above counts the lines it could not act on).
			var acted_key := RegEx.create_from_string("\\d+").sub(acted_line, "N", true).substr(0, 70)
			(hints_log.get_or_add("acted_lines", {}) as Dictionary)[acted_key] = int((hints_log["acted_lines"] as Dictionary).get(acted_key, 0)) + 1
			kinds[acted] = true
			press_log["presses"] = int(press_log["presses"]) + int(PRESS_COST.get(acted, 3)) + (TRAVEL_PRESSES if gs.current_region != region_before else 0)
			# An action that took less than the week leaves the rest of it to meditation.
			var left: int = 7 - (gs.get_node("/root/GameClock").total_days - day)
			if left > 0 and c.alive:
				gs.cultivate(left, density)
		note_milestones(gs, c)
	return kinds


## SIM-017: records the day and press count of each milestone the first time it holds.
static func note_milestones(gs: Node, c: CharacterData) -> void:
	var first: Dictionary = press_log["first"]
	var held := {"first_stage": c.realm_index * 100 + c.stage > 0, "first_win": LifeStats.get_stat(c, "fights_won") > 0,
		"first_technique": not c.techniques.is_empty(), "first_breakthrough": c.realm_index >= 1, "sect_joined": not c.is_rogue(), "first_friend": false, "friend_tier2": false}
	for npc_id: String in gs.npc_favor:
		var tier := Folk.tier_index(gs.data, int(gs.npc_favor[npc_id]))
		held["first_friend"] = held["first_friend"] or tier >= 0  # the first tier (Acquaintance)
		held["friend_tier2"] = held["friend_tier2"] or tier >= 1  # the second (Friend)
	for m: String in MILESTONES:
		if held[m] and not first.has(m):
			first[m] = {"day": gs.get_node("/root/GameClock").total_days, "presses": int(press_log["presses"])}


## SIM-014: where an easy-fight line says to start: "bounty", "mission", "explore" or "" (GUIDE-269 trailing clause).
static func easy_fight_start(line: String) -> String:
	if line.contains("(Bounty Board") or line.contains("(Hunters' Bounty Board"):
		return "bounty"
	if line.contains("(mission board"):
		return "mission"
	if line.contains("(explore "):
		return "explore"
	return ""


## SIM-013: "Easy fight: <text>" with exactly one prefix (the fight text may already carry it).
static func with_easy_fight_prefix(text: String) -> String:
	return "Easy fight: " + text.trim_prefix("Easy fight: ")


## SIM-010: what the HUD's Next steps card lists, top first: the goal line, the easy-fight line, then the hints.
static func _next_steps(gs: Node, c: CharacterData, day: int) -> Array[String]:
	var lines: Array[String] = []
	# SIM-021: the make-a-friend line sits past the HUD's 5-line cap; a player who knows the NPC menu's "Lend a hand" does it
	# first each week it is on offer (a weekly kindness, 1 day), so the sim reads it uncapped and puts it first.
	var friend := Guidance.make_friend_hint(c, gs.data, gs.npcs, gs.world_flags, gs.current_region, day, gs.npc_favor)
	if friend != "":
		lines.append(friend)
	# GUIDE-275: the HUD's own goal text (GUIDE-271's skipped rows included), so a goal's named first step reaches the policy.
	var goal := Guidance.hud_goal_text(c, gs.data, gs.world_flags, gs.current_region, day, null, gs.hint_density())
	if goal != "":
		lines.append("Goal: " + goal)
	for f: Dictionary in Guidance.fair_fights(c, gs.data, gs.world_flags, day, gs.current_region, gs.npcs, gs.npc_favor):
		lines.append(with_easy_fight_prefix(String(f.get("text", ""))))
		break
	for h: String in Guidance.hints(c, gs.data, gs.hint_density(), 5, gs.npcs, gs.world_flags, gs.current_region, day, gs.npc_favor):
		lines.append(h)
	return lines


## SIM-010: acts on one Next-steps line when a known action fits it; returns the action's name, "" when none did anything.
static func _act_on_hint(gs: Node, c: CharacterData, done: Dictionary, line: String, day: int) -> String:
	var kinds := {}
	var stones_before := c.item_count("spirit_stone")
	var day_before: int = gs.get_node("/root/GameClock").total_days
	var inv_before := c.inventory.size()
	if line.begins_with("Goal: Learn your first technique: buy "):
		# GUIDE-275: the goal names a manual a merchant here sells and the stones are in hand.
		var manual := cheapest_combat_manual(gs, c)
		if manual == "" or c.item_count("spirit_stone") < int(gs.data.items[manual].get("price", 0)):
			return ""
		gs.buy_item(manual)
		gs.use_item(manual)
		return "manual" if not c.techniques.is_empty() else ""
	if line.begins_with("Goal: Learn your first technique: ") and line.contains("earn "):
		# GUIDE-275: too poor for the manual: sell what a stall pays for, else take the nearest fair fight for the stones.
		_sell_loot_here(gs, c, gs.current_region)
		if c.item_count("spirit_stone") > stones_before:
			return "sell"
		return _act_on_hint(gs, c, done, "Easy fight: earn the stones", day)
	if line == "Goal: Learn your first technique" and start_region != "" and gs.current_region != start_region:
		# GUIDE-275: away from a start whose merchant sells a combat manual: walk home to it and buy (the next week's line names the price).
		var home_manual := Guidance.first_combat_manual(c, gs.data, start_region)
		if not home_manual.is_empty() and String(home_manual["merchant"]) != "":
			if c.item_count("spirit_stone") >= int(home_manual["price"]):
				_walk_to(gs, c, start_region)
				return "travel" if gs.current_region == start_region else ""
			# Too poor for it: earn the stones where you stand (a sale, else the nearest fair fight).
			_sell_loot_here(gs, c, gs.current_region)
			if c.item_count("spirit_stone") > stones_before:
				return "sell"
			return _act_on_hint(gs, c, done, "Easy fight: earn the stones", day)
	if line.begins_with("You are ready to break through") and Cultivation.can_attempt_breakthrough(c, gs.data):
		# GUIDE-275: the line says to attempt it; a player does (pills first, as the breakthrough window's Take button does).
		for pill_id in Guidance.breakthrough_item_ids(c, gs.data):
			gs.use_item(pill_id)
		gs.attempt_breakthrough()
		return "breakthrough"
	if line.contains("Elder Mo") and (line.begins_with("Ask ") or line.begins_with("Goal: Talk") or line.contains("teaches a breathing")) or line == "Goal: Learn your first technique":
		_walk_to(gs, c, "qingshi_village")
		if gs.current_region != "qingshi_village":
			return ""
		var before := c.techniques.size()
		var flag_before: bool = gs.world_flags.get(Guidance.ELDER_MO_FLAG, false)
		_talk_to_elder_mo(gs, "teach me how to cultivate")
		var changed: bool = c.techniques.size() != before or bool(gs.world_flags.get(Guidance.ELDER_MO_FLAG, false)) != flag_before
		return "talk" if changed else ""
	if line.begins_with("Make a friend: lend ") or line.begins_with("Become friends: lend "):
		# SIM-021: the line names the villager; lend them a hand (1 day) once the weekly cooldown allows.
		for id: String in gs.data.npcs:
			var npc: CharacterData = gs.npcs.get(id)
			if npc != null and (line.begins_with("Make a friend: lend %s a hand" % npc.name) or line.begins_with("Become friends: lend %s a hand" % npc.name)):
				var favor_before := int(gs.npc_favor.get(id, 0))
				gs.lend_a_hand(id)
				return "lend" if int(gs.npc_favor.get(id, 0)) > favor_before else ""
		return ""
	if line.begins_with("Use your"):
		_use_qi_items(gs, c)
		return "use_item" if c.inventory.size() != inv_before or c.item_count("spirit_stone") != stones_before else ""
	if line.begins_with("Buy ") and line.contains("spare stones"):
		var okq := _buy_qi_here(gs, c)
		return "buy_qi" if okq else ""
	if line.begins_with("Treat your injuries") and not c.injuries.is_empty():
		var log := {"healed": 0}
		_heal_before_fighting(gs, c, log)
		if int(log["healed"]) > 0:
			return "heal"
		# GUIDE-275: no healer in reach and the line says to rest: meditate through it (the days heal it as they pass).
		if line.contains("rest or meditate") and c.alive:
			gs.cultivate(mini(7, Injuries.days_to_heal(c)), gs.hint_density())
			return "rest"
		return ""
	if line.contains("paid work") or line.begins_with("Headman Zhou"):
		var got := false
		for chore in CHORES:
			if not done.has(chore):
				done[chore] = true
				gs.perform_deed(chore)
				got = true
		return "chore" if got else ""
	if line.begins_with("Easy fight") or line.contains("Fights you can win"):
		var fair := Guidance.fair_fights(c, gs.data, gs.world_flags, day, gs.current_region, gs.npcs, gs.npc_favor)
		_take_listed_deed(gs, c, done, fair, kinds, day)
		# SIM-016: start where the line says (GUIDE-269): the bounty board or the mission board.
		var start := easy_fight_start(line)
		if kinds.is_empty() and start == "bounty":
			_take_listed_bounty(gs, c, done, fair, kinds)
		elif kinds.is_empty() and start == "mission" and not c.is_rogue():
			var pick := Guidance.best_mission(c, gs.data, gs.world_flags)
			if pick != "" and _mission_is_sane(gs, c, pick, done, day):
				_take_one_mission(gs, c, done, kinds, [] as Array[Dictionary], pick, day)
		# SIM-018: a chore listed "N days away" (N <= 3): travel there, do it, come home.
		if kinds.is_empty() and _take_far_deed(gs, c, done, fair, kinds, day):
			return "fight"
		if not kinds.is_empty():
			return "fight"
		var won: int = LifeStats.get_stat(c, "fights_won")
		_explore(gs)
		return "fight" if LifeStats.get_stat(c, "fights_won") > won else ""
	if line.contains("would spar with you"):
		var spar_before := int(spar_log["bouts"])
		var was := spar_hint
		spar_hint = true
		_follow_spar_hint(gs, c, day)
		spar_hint = was
		return "spar" if int(spar_log["bouts"]) > spar_before else ""
	# GUIDE-272: before the generic mission branch (the line says "your sect's own missions").
	if line.begins_with("Your sect's home") and not c.is_rogue():
		var home := Sects.home_region(gs.data, String(c.sect["id"]))
		if home != "":
			_walk_to(gs, c, home)
		return "sect_home" if home != "" and gs.get_node("/root/GameClock").total_days != day_before else ""
	if line.contains("mission") and not c.is_rogue():
		var best := Guidance.best_mission(c, gs.data, gs.world_flags)
		if best != "" and _mission_is_sane(gs, c, best, done, day):
			var fair2: Array[Dictionary] = []
			_take_one_mission(gs, c, done, kinds, fair2, best, day)
			return "mission"
		return ""
	if line.begins_with("Sell your"):
		_sell_loot_here(gs, c, gs.current_region)
		return "sell" if c.item_count("spirit_stone") > stones_before else ""
	if line.contains("can teach you") or line == "Goal: Learn a fighting style":
		# SIM-011: a player who reads the hint walks to the teacher, runs his favor errand, gifts, and asks for the lesson.
		var favor_before: Dictionary = gs.npc_favor.duplicate()
		_visit_style_teacher(gs, c, HINT_TEACHER_REACH_DAYS, true)
		if Techniques.knows_kind(c, gs.data, "combat") or gs.npc_favor != favor_before or gs.get_node("/root/GameClock").total_days != day_before:
			return "teacher"
	if line.begins_with("Goal: Catch a fish"):
		# SIM-014: the village jetty, with the table and days its own menu passes.
		_walk_to(gs, c, "qingshi_village")
		if gs.current_region != "qingshi_village":
			return ""
		var caught_before := c.catch_log.size()
		for p: Dictionary in gs.data.regions["qingshi_village"].get("places", []):
			if String(p.get("type", "")) == "fishing":
				gs.fish(p.get("catch_table", []), int(p.get("gather_days", 2)), String(p.get("display_name", "")))
				break
		return "fish" if c.catch_log.size() != caught_before or gs.get_node("/root/GameClock").total_days != day_before else ""
	if line.begins_with("Armor keeps you standing") or line.begins_with("Your defence is thin"):
		# SIM-014: sell the loot the line names here, then buy and equip the armor as the defence follow-up does.
		_sell_loot_here(gs, c, gs.current_region)
		var armor_before: String = String(c.equipment.get("armor", ""))
		_follow_defence_hint(gs, c)
		if String(c.equipment.get("armor", "")) == armor_before:
			_buy_armor_trip(gs, c)
		return "armor" if String(c.equipment.get("armor", "")) != armor_before else ""
	if line.begins_with("Goal: Finish a bounty"):
		# SIM-016: the board here; the offer with the best rated odds when they are >= 0.7.
		_take_best_bounty(gs, c, done, kinds)
		return "bounty" if kinds.has("bounty") else ""
	if line.begins_with("Goal: Cook a meal"):
		# SIM-016: the workshop is in the village; cook the cheapest dish the pack (or the stalls here) can fill.
		_walk_to(gs, c, "qingshi_village")
		return "cook" if gs.current_region == "qingshi_village" and _cook_cheapest(gs, c) else ""
	if line.begins_with("Goal: Beat a great beast"):
		return _hunt_great_beast(gs, c, day)
	if line.begins_with("Goal: Walk to "):
		# QA-237: the goal names the first hop out of the village; the player travels there.
		_walk_to(gs, c, "misty_forest")
		return "travel" if gs.get_node("/root/GameClock").total_days != day_before else ""
	if line.begins_with("Practise ") and line.contains(" on the Techniques screen"):
		var practise_id := Techniques.practice_target(c, gs.data)
		if practise_id == "":
			return ""
		gs.practice_technique(practise_id, 7)
		return "practise" if gs.get_node("/root/GameClock").total_days != day_before else ""
	if line.begins_with("Your sect treasury sells ") or line.contains("from your sect treasury"):
		var claim := Guidance._body_manual_treasury(c, gs.data)
		if claim.is_empty():
			return ""
		var held := c.item_count(String(claim["item_id"]))
		gs.buy_with_contribution(String(claim["item_id"]))
		return "treasury" if c.item_count(String(claim["item_id"])) > held else ""
	if line.begins_with("Unseal "):
		var ready := ArtifactFunctions.ready_to_unseal(c, gs.data, gs.world_flags)
		if not ready.is_empty():
			gs.unlock_artifact_function(ready[0])
			return "unseal" if ArtifactFunctions.is_unlocked(c, ready[0]) else ""
		return ""
	if line.begins_with("Goal: Visit "):
		# SIM-013: the goal names a place (the market); the player travels there like the map's Travel button.
		var visit := "fallen_star_market" if line.contains("Fallen Star") else ""
		if visit == "":
			return ""
		_walk_to(gs, c, visit)
		return "travel" if gs.get_node("/root/GameClock").total_days != day_before or gs.current_region == visit else ""
	if line.contains("by the path") or line.begins_with("Goal: Pick something"):
		# SIM-013: pick what lies by the path here (the same action as the Pick button); explore when nothing grows here today.
		var picked := false
		for n: Dictionary in gs.forage_here():
			if gs.pick_forage(int(n["slot"])):
				picked = true
		if picked:
			return "forage"
		if line.begins_with("Goal: "):
			_explore(gs)
			return "explore"
		return ""
	if line.begins_with("Goal: ") and line.contains("Learn a fighting"):
		var seen := _explore_watched(gs, c, day)
		_explore(gs)
		_log_explore_fights(done, seen)
		return "explore"
	if line.contains("trial") and line.contains("open"):
		_attempt_open_trial(gs, c, done, kinds)
		return "trial" if kinds.has("trial") else ""
	# SIM-020: lines a player reads and acts on that the policy ignored: sell what a stall would pay for, attend the elder's
	# lecture at the hall, and meditate when the next stage is a few days of qi away.
	if line.contains("would pay about") or line.begins_with("Good for trade"):
		_sell_loot_here(gs, c, gs.current_region)
		return "sell" if c.item_count("spirit_stone") > stones_before else ""
	if line.contains("lectures this month") and not c.is_rogue():
		var hall := Sects.home_region(gs.data, String(c.sect["id"]))
		if hall != "":
			_walk_to(gs, c, hall)
		if Sects.check_lecture(c, gs.data, day) == "":
			gs.attend_lecture()
			return "lecture"
		return ""
	if line.begins_with("Gather ") and line.contains(" more qi to reach the next stage") and c.alive:
		gs.cultivate(7, gs.hint_density())
		return "meditate"
	return "" if gs.get_node("/root/GameClock").total_days == day_before else "other"


const HINT_TEACHER_REACH_DAYS := 30
## SIM-019: the Foundation road goal's beast is only walked to when it rates at least this and arrives within GREAT_WAIT_DAYS.
const GREAT_MIN_ODDS := 0.7
const GREAT_WAIT_DAYS := 30


## SIM-019: acts on the great-beast road goal on its weekday: skips (like a player) when the fight rates under GREAT_MIN_ODDS or the
## beast's day is too far; else waits, travels so as to arrive that day, fights it and walks home. "great_beast" when it was fought.
## GUIDE-275: the beast is not for now (too weak, too far in days or the road): a player does not stand idle but cultivates the
## week, which is what raises the odds the goal line rates. "prepare" when the week was spent.
static func _prepare_week(gs: Node, c: CharacterData) -> String:
	if not c.alive:
		return ""
	gs.cultivate(7, gs.hint_density())
	return "prepare"


static func _hunt_great_beast(gs: Node, c: CharacterData, day: int) -> String:
	var clock: Node = gs.get_node("/root/GameClock")
	var next := Guidance._next_great(c, gs.data, day, "", true)
	var rid: String = next["region"]
	if rid == "" or int(next["day"]) - day > GREAT_WAIT_DAYS:
		return ""
	var enemy_id := Wildlife.active_great_enemy(c, gs.data, rid)
	if not gs.data.enemies.has(enemy_id) or Combat.win_chance(c, gs.data, gs.data.enemies[enemy_id]) < GREAT_MIN_ODDS:
		return ""
	var home: String = gs.current_region
	var route := Guidance.route_days(c, gs.data, home, rid) if home != rid else 0
	if route < 0 or route > int(next["day"]) - day:
		return ""
	var target: int = int(next["day"])
	while c.alive and clock.total_days < target - route:
		gs.cultivate(mini(7, target - route - clock.total_days), gs.hint_density())
	if not c.alive:
		return ""
	if home != rid:
		gs.travel(rid)
		if gs.current_region != rid:
			return ""
	if gs.pending_encounter != "":
		gs.choose_encounter(encounter_choice(c, gs.data, gs.data.encounters[gs.pending_encounter], gs.world_flags, gs.npcs))
	if gs.pending_threat != "":
		gs.face_threat(false)
	if c.alive and clock.total_days < target:
		gs.cultivate(target - clock.total_days, gs.hint_density())
	var won := false
	if c.alive:
		for r: Dictionary in gs.roamers_here():
			if int(r["slot"]) == Wildlife.GREAT_SLOT:
				var held := c.great_beasts.size()
				gs.engage_roamer(Wildlife.GREAT_SLOT)
				won = c.great_beasts.size() > held
	if c.alive and gs.current_region != home:
		gs.travel(home)
	return "great_beast" if won else "fight"


## SIM-016: cooks the cheapest known home meal the pack covers, buying missing ingredients from a merchant here. True when cooked.
static func _cook_cheapest(gs: Node, c: CharacterData) -> bool:
	var data: GameData = gs.data
	var best := ""
	var best_cost := 1 << 30
	for m: Dictionary in Cooking.known_meals(c, data):
		var cost := 0
		var ok := true
		var ingredients: Dictionary = m["ingredients"]
		for item_id: Variant in ingredients:
			var missing := maxi(0, int(ingredients[item_id]) - c.item_count(String(item_id)))
			if missing > 0:
				if Guidance.merchant_selling(data, gs.current_region, String(item_id)) == "":
					ok = false
					break
				cost += missing * Guidance.merchant_price(c, data, gs.current_region, String(item_id))
		if ok and cost <= c.item_count("spirit_stone") and cost < best_cost:
			best = String(m["id"])
			best_cost = cost
	if best == "":
		return false
	for item_id: Variant in Cooking.meal(data, best)["ingredients"]:
		var need := int(Cooking.meal(data, best)["ingredients"][item_id]) - c.item_count(String(item_id))
		for _i in maxi(0, need):
			gs.buy_item(String(item_id))
	var before := int(c.cooked_meals.get(best, 0))
	gs.cook_meal(best)
	return int(c.cooked_meals.get(best, 0)) > before


## SIM-016: walks to the nearest region whose merchants sell armor the purse reaches, buys and wears it, and walks home.
static func _buy_armor_trip(gs: Node, c: CharacterData) -> void:
	var data: GameData = gs.data
	var home: String = gs.current_region
	var targets: Array[String] = [home]
	for rid: String in data.regions:
		if rid != home:
			targets.append(rid)
	for rid: String in targets:
		var armor := Guidance.affordable_armor(c, data, rid)
		if armor == "" or not c.alive:
			continue
		if rid != gs.current_region:
			if Guidance.route_days(c, data, home, rid) <= 0:
				continue
			_walk_to(gs, c, rid)
			if gs.current_region != rid:
				break
		gs.buy_item(armor)
		gs.equip_item(armor)
		break
	if c.alive and gs.current_region != home:
		_walk_to(gs, c, home)


static func _talk_to_elder_mo(gs: Node, prefer: String = "") -> void:
	gs.start_dialogue("elder_mo")
	var guard := 0
	while gs.in_dialogue() and guard < 20:
		var view: Dictionary = gs.dialogue_view()
		var pick := -1
		for choice: Dictionary in view.get("choices", []):
			if not choice.get("disabled", false) and String(choice.get("label", "")).begins_with("I am new"):
				pick = int(choice["index"])
			if prefer != "" and not choice.get("disabled", false) and String(choice.get("label", "")).contains(prefer):
				pick = int(choice["index"])
				break
		if pick < 0:
			for choice: Dictionary in view.get("choices", []):
				if not choice.get("disabled", false):
					pick = int(choice["index"])
					break
		if pick < 0:
			break
		gs.choose_dialogue(pick)
		guard += 1
	if gs.in_dialogue():
		gs.end_dialogue()


static func _use_qi_items(gs: Node, c: CharacterData) -> void:
	for item_id: String in c.inventory.keys():
		var def: Dictionary = gs.data.items.get(item_id, {})
		if def.get("effects", {}).has("qi"):
			for i in int(c.inventory.get(item_id, 0)):
				gs.use_item(item_id)


## QA-116: while Guidance.thin_defence_hint speaks, heal injuries (items, then a clinic here), then buy the cheapest
## body-technique manual and the best armor the purse reaches (this region's merchants, else the nearest region that
## sells them: one trip, then home), learn and equip them. Counts go to defence_log[seed].
static func _follow_defence_hint(gs: Node, c: CharacterData) -> void:
	var data: GameData = gs.data
	if not c.alive or Guidance.thin_defence_hint(c, data) == "":
		return
	var log: Dictionary = defence_log.get(int(gs.rng.seed), {"trips": 0, "armor": 0, "manual": 0, "healed": 0})
	defence_log[int(gs.rng.seed)] = log
	_heal_before_fighting(gs, c, log)
	var home: String = gs.current_region
	var targets: Array[String] = [home]
	for rid: String in data.regions:
		if rid != home:
			targets.append(rid)
	for rid: String in targets:
		if not c.alive or Guidance.thin_defence_hint(c, data) == "":
			break
		var wants_armor: bool = c.equipment.get("armor", "") == "" and Guidance.affordable_armor(c, data, rid) != ""
		var wants_manual: bool = not Techniques.knows_kind(c, data, "body") and _cheapest_body_manual(gs, c, rid) != ""
		if not wants_armor and not wants_manual:
			continue
		if rid != gs.current_region:
			gs.travel(rid)
			if gs.current_region != rid:
				continue
			log["trips"] += 1
		var manual: String = _cheapest_body_manual(gs, c, rid) if not Techniques.knows_kind(c, data, "body") else ""
		if manual != "" and c.alive:
			gs.buy_item(manual)
			gs.use_item(manual)
			if Techniques.knows_kind(c, data, "body"):
				log["manual"] += 1
		var armor: String = Guidance.affordable_armor(c, data, rid) if c.equipment.get("armor", "") == "" else ""
		if armor != "" and c.alive:
			gs.buy_item(armor)
			gs.equip_item(armor)
			if c.equipment.get("armor", "") == armor:
				log["armor"] += 1
		break
	if gs.current_region != home and c.alive:
		gs.travel(home)
	if not Techniques.knows_kind(c, data, "body") and c.alive:
		for entry: Dictionary in Sects.shop_items(c, data):
			var tech_id := Items.manual_technique(data, String(entry["item_id"]))
			if tech_id != "" and data.techniques[tech_id].kind == "body" and Sects.contribution_balance(c) >= int(entry["contribution"]):
				gs.buy_with_contribution(String(entry["item_id"]))
				gs.use_item(String(entry["item_id"]))
				log["manual"] += 1
				break


static func _cheapest_body_manual(gs: Node, c: CharacterData, region_id: String) -> String:
	var data: GameData = gs.data
	var best := ""
	for item_id: String in data.items:
		var tech_id := Items.manual_technique(data, item_id)
		if tech_id == "" or data.techniques[tech_id].kind != "body" or Techniques.knows(c, tech_id) or not data.techniques[tech_id].activation.is_empty():
			continue
		var price := int(data.items[item_id].get("price", 0))
		if price > c.item_count("spirit_stone") or Guidance.merchant_selling(data, region_id, item_id) == "":
			continue
		if best == "" or price < int(data.items[best].get("price", 0)):
			best = item_id
	return best


static func _heal_before_fighting(gs: Node, c: CharacterData, log: Dictionary) -> void:
	var data: GameData = gs.data
	for injury_id: String in c.injuries.keys():
		if not c.alive:
			return
		var healed := false
		for item_id: String in c.inventory.keys():
			if c.item_count(item_id) > 0 and Guidance._heals(data, item_id, injury_id):
				gs.use_item(item_id)
				healed = true
				break
		if not healed:
			for p: Dictionary in data.regions.get(gs.current_region, {}).get("places", []):
				if String(p.get("type", "")) == "clinic" and Medicine.clinic_cost(c, data, injury_id) <= c.item_count("spirit_stone"):
					gs.visit_clinic(injury_id)
					healed = true
					break
		if healed:
			log["healed"] += 1


## QA-165: for each open injury still left after the here-and-now treatment: claim a treasury cure, else go to a clinic
## one route away when the stones cover it, treat, and walk back.
static func _heal_far(gs: Node, c: CharacterData) -> void:
	var data: GameData = gs.data
	for injury_id: String in c.injuries.keys():
		if not c.alive or not c.injuries.has(injury_id):
			continue
		var claim := Guidance._heal_treasury(c, data, injury_id)
		if not claim.is_empty():
			gs.buy_with_contribution(String(claim["item_id"]))
			if c.item_count(String(claim["item_id"])) > 0:
				gs.use_item(String(claim["item_id"]))
				heal_far_log["treated"] += 1
				continue
		var cost := Medicine.clinic_cost(c, data, injury_id)
		if cost > c.item_count("spirit_stone"):
			continue
		var home: String = gs.current_region
		var target := ""
		for rid: String in data.regions:
			if rid == home or Guidance.route_days(c, data, home, rid) <= 0 or Guidance.first_hop(c, data, home, rid) != rid:
				continue
			for p: Dictionary in data.regions[rid].get("places", []):
				if String(p.get("type", "")) == "clinic":
					target = rid
			if target != "":
				break
		if target == "":
			continue
		gs.travel(target)
		if gs.current_region != target:
			continue
		heal_far_log["trips"] += 1
		gs.visit_clinic(injury_id)
		if not c.injuries.has(injury_id):
			heal_far_log["treated"] += 1
		gs.travel(home)
