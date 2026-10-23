extends RefCounted
## QA-016: a scripted newcomer in Qingshi Village, shared by the sim
## (tests/sim/simulate_first_hour.gd) and its guards (tests/unit/test_first_hour.gd).
## Plays through the same GameState calls the menus use.

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
## QA-138: a curious player takes the bout the spar hint names ("<Name> (<realm>) here would spar with you"), once a
## week while the hint speaks; simulate_first_hour.gd's --no-spar-hint turns it off. spar_log["bouts"] counts them,
## ["refused"] collects check_spar's text when the named partner refuses (a hint bug).
static var spar_hint := false
static var spar_log := {"bouts": 0, "refused": []}
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
static var qi_log := {"bought": 0, "stones": 0, "used": 0, "qi": 0}
const TRIAL_MIN_ODDS := 0.7


static func play(gs: Node, clock: Node, seed_value: int, months: int, curious: bool = false, month_hook: Callable = Callable(), no_help: bool = false, wait_for_pill: int = 0) -> Dictionary:
	gs.rng.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := CharacterFactory.create("Newcomer", gs.data, rng)
	var saves: Node = gs.get_node("/root/SaveManager")
	var autosave_was: bool = saves.autosave_enabled
	saves.autosave_enabled = false  # a sim month must not write the autosave slot (QA-137)
	gs.start_session(c)
	gs.pending_event = ""
	var bus: Node = gs.get_node("/root/EventBus")
	bus.clear_history()
	var out := {"layer_day": {}, "sect_day": -1, "rank_day": -1, "month_lines": [], "injuries": 0, "player": c, "kinds": [], "kind_sets": [], "stones": [], "realms": [], "first_win_day": -1, "first_style_day": -1, "first_win_enemy": "", "breaks": [], "bottleneck_day": {}, "waited_days": 0, "road": []}
	var done := {"no_help": no_help}
	# QA-063: remember the foe of the first real (non-spar) win; the day comes from the fights_won stat.
	var fight := {"enemy": "", "first_enemy": ""}
	var on_start := func(enemy: Dictionary) -> void: fight["enemy"] = "" if enemy.get("spar", false) else String(enemy.get("id", enemy.get("name", "?")))
	wolf_win_day = -1
	var on_end := func(_name: String, victory: bool, _log: PackedStringArray) -> void:
		if victory and fight["enemy"] != "" and fight["first_enemy"] == "":
			fight["first_enemy"] = fight["enemy"]
		if victory and fight["enemy"] == "mist_wolf" and wolf_win_day < 0:
			wolf_win_day = clock.total_days
	bus.combat_started.connect(on_start)
	bus.combat_finished.connect(on_end)
	_talk_to_elder_mo(gs)
	for chore in CHORES:
		gs.perform_deed(chore)
	_use_qi_items(gs, c)
	for month in months:
		if not c.alive:
			break
		bus.clear_history()  # the log is capped, which would hide a month's lines from the count
		var mark := 0
		gs.cultivate(Calendar.DAYS_PER_MONTH, SPRING_DENSITY)
		if not c.alive:
			break
		var broke := false
		# QA-066: log every breakthrough attempt (and the first day each realm's bottleneck was seen, month-granular).
		if Cultivation.is_at_bottleneck(c, gs.data) and not out["bottleneck_day"].has(c.realm_index):
			out["bottleneck_day"][c.realm_index] = clock.total_days
		if Cultivation.can_attempt_breakthrough(c, gs.data) and _keeps_saving_for_pill(gs, c, out, wait_for_pill):
			out["waited_days"] += Calendar.DAYS_PER_MONTH
		elif Cultivation.can_attempt_breakthrough(c, gs.data):
			var stones_now := c.item_count("spirit_stone")
			# QA-072: take a held breakthrough pill right before the attempt, as the breakthrough window's "Take" button does.
			for pill_id in Guidance.breakthrough_item_ids(c, gs.data):
				gs.use_item(pill_id)
			var attempt := {"day": clock.total_days, "from_realm": c.realm_index, "chance": Cultivation.breakthrough_chance(c, gs.data), "pill": c.breakthrough_pill != "", "stones": stones_now}
			var injuries_before := c.injuries.size()
			var realm_before := c.realm_index
			gs.attempt_breakthrough()
			attempt["success"] = c.alive and c.realm_index > realm_before
			attempt["injury"] = c.injuries.size() > injuries_before
			out["breaks"].append(attempt)
			broke = true
		_use_qi_items(gs, c)
		if c.is_rogue() and out["sect_day"] < 0:
			for sect_id: String in Sects.accepting_sects(c, gs.data):
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
		_note_first_win(out, c, clock, fight)
		if not curious:
			_retry_chores(gs, c)
			_note_first_win(out, c, clock, fight)
		if curious:
			kinds = _curious_month(gs, c, done, clock.total_days)
			if done.has("style_month") and out["first_style_day"] < 0:
				out["first_style_day"] = clock.total_days
			_note_first_win(out, c, clock, fight)
		var home_region: String = gs.current_region
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
		out["realms"].append(Cultivation.realm_label(c, gs.data))
		if month_hook.is_valid():
			month_hook.call(month)
	bus.combat_started.disconnect(on_start)
	bus.combat_finished.disconnect(on_end)
	out["style_month"] = int(done.get("style_month", -1))
	out["fair_log"] = done.get("fair_log", {"listed": [], "taken": [], "by_kind": {}})
	out["injuries"] = c.injuries.size()
	out["recharges"] = int(done.get("recharges", 0))
	out["trials_won"] = int(done.get("trials_won", 0))
	out["trials_lost"] = int(done.get("trials_lost", 0))
	out["sect_rank"] = -1 if c.is_rogue() else int(c.sect["rank"])
	out["lives"] = c.artifact_lives
	out["fights_won"] = LifeStats.get_stat(c, "fights_won")
	out["fights_lost"] = LifeStats.get_stat(c, "fights_lost")
	out["fights_fled"] = LifeStats.get_stat(c, "threats_fled")
	saves.autosave_enabled = autosave_was
	return out


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


## The extra things a curious player does in one month: explore weekly, one
## harmless deed, one sect mission, one chat (once), deliver orders. Returns the
## set of action kinds done.
static func _curious_month(gs: Node, c: CharacterData, done: Dictionary, today: int) -> Dictionary:
	var kinds := {}
	if heal_injuries and c.alive and not c.injuries.is_empty():
		var stones_before := c.item_count("spirit_stone")
		var log := {"healed": 0}
		_heal_before_fighting(gs, c, log)
		heal_log["healed"] += int(log["healed"])
		heal_log["stones"] += maxi(0, stones_before - c.item_count("spirit_stone"))
	if follow_defence:
		_follow_defence_hint(gs, c)
	if practise_hint:
		_follow_practice_hint(gs, c)
	var detour_home := _bitter_detour(gs, c)
	for week in 3:
		if not c.alive:
			return kinds
		_follow_spar_hint(gs, c, today + week * 7)
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
	if detour_home != "" and c.alive:
		gs.travel(detour_home)
	if not c.alive:
		return kinds
	_buy_breakthrough_pill(gs, c, done)
	if not c.alive:
		return kinds
	if buy_qi:
		_buy_qi_pills(gs, c)
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
	if not c.is_rogue() and c.alive:
		if chase_best_mission:
			# QA-134: the hint names the best-paying mission ("The best pays N contribution"); take it, up to 3 a month.
			for _i in 3:
				var best := Guidance.best_mission(c, gs.data, gs.world_flags)
				if not c.alive or best == "" or not _mission_is_sane(gs, c, best, done, today):
					break
				_take_one_mission(gs, c, done, kinds, fair, best, today)
		else:
			for mission_id in Sects.available_missions(c, gs.data, gs.world_flags):
				if Sects.check_mission(c, gs.data, mission_id, gs.world_flags) != "" or not _mission_is_sane(gs, c, mission_id, done, today):
					continue
				_take_one_mission(gs, c, done, kinds, fair, mission_id, today)
				break
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
static func _buy_breakthrough_pill(gs: Node, c: CharacterData, done: Dictionary) -> void:
	done["saving"] = false
	if c.realm_index != 1 or c.stage < 6 or c.breakthrough_pill != "" or not Guidance.breakthrough_items(c, gs.data).is_empty():
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


## QA-144: see buy_qi. The reserve is the next realm pill's price in the last three stages while none is held.
static func _buy_qi_pills(gs: Node, c: CharacterData) -> void:
	var reserve := 0
	if Guidance._pill_goal_applies(c, gs.data):
		reserve = Guidance.next_realm_pill_price(c, gs.data)
	var spare := c.item_count("spirit_stone") - reserve - 20
	if spare <= 0:
		return
	# Qi stops at the bottleneck, so only pills that fit in the room left are worth buying.
	var realm: RealmDef = gs.data.realms[c.realm_index]
	var room := realm.qi_required(realm.stage_count() - 1) - c.qi
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
			var rate := float(fx["qi"]) / price
			if rate > best_rate:
				best_rate = rate
				best_id = item_id
				best_price = price
	if best_id == "" or best_price > spare:
		return
	var count := mini(spare / best_price, int(room / float(gs.data.items[best_id]["effects"]["qi"])))
	var stones_before := c.item_count("spirit_stone")
	var had := c.item_count(best_id)
	gs.buy_item(best_id, "", count)
	var bought := c.item_count(best_id) - had
	qi_log["bought"] += bought
	qi_log["stones"] += stones_before - c.item_count("spirit_stone")
	for i in bought:
		if not c.alive or Cultivation.is_at_bottleneck(c, gs.data):
			break
		var qi_before := c.qi
		gs.use_item(best_id)
		if c.item_count(best_id) < had + bought - i:
			qi_log["used"] += 1
			qi_log["qi"] += maxi(0, c.qi - qi_before)


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
				if not String(f["text"]).begins_with("%s: %s" % [place.get("display_name", "Chore"), deed["name"]]) or Deeds.check(c, gs.data, deed, gs.world_flags, today) != "":
					continue
				var won_before := LifeStats.get_stat(c, "fights_won")
				fight_origin = "deed"
				gs.perform_deed(String(deed["id"]))
				fight_origin = "other"
				done["fair_log"]["taken"].append({"kind": "deed", "chance": float(f["chance"]), "won": LifeStats.get_stat(c, "fights_won") > won_before})
				kinds["deed_fight"] = true
				return


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
	var home: String = gs.current_region
	var where := String(picked["region"])
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
	done["fair_log"]["taken"].append({"kind": "bounty", "chance": float(entry["chance"]), "won": claimed[0] > 0})
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
		var manual := cheapest_combat_manual(gs, c)
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
				if cheapest == "" or int(gs.data.items[item_id].get("price", 0)) < int(gs.data.items[cheapest].get("price", 0)):
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


static func _talk_to_elder_mo(gs: Node) -> void:
	gs.start_dialogue("elder_mo")
	var guard := 0
	while gs.in_dialogue() and guard < 20:
		var view: Dictionary = gs.dialogue_view()
		var pick := -1
		for choice: Dictionary in view.get("choices", []):
			if not choice.get("disabled", false) and String(choice.get("label", "")).begins_with("I am new"):
				pick = int(choice["index"])
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
