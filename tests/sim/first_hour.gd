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
## newcomer only meditates and explores once.
static func play(gs: Node, clock: Node, seed_value: int, months: int, curious: bool = false) -> Dictionary:
	gs.rng.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := CharacterFactory.create("Newcomer", gs.data, rng)
	gs.start_session(c)
	gs.pending_event = ""
	var bus: Node = gs.get_node("/root/EventBus")
	bus.clear_history()
	var out := {"layer_day": {}, "sect_day": -1, "month_lines": [], "injuries": 0, "player": c, "kinds": [], "kind_sets": [], "stones": [], "realms": []}
	var done := {}
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
		if Cultivation.can_attempt_breakthrough(c, gs.data):
			gs.attempt_breakthrough()
			broke = true
		_use_qi_items(gs, c)
		if c.is_rogue() and out["sect_day"] < 0:
			for sect_id: String in Sects.accepting_sects(c, gs.data):
				gs.join_sect(sect_id)
				break
		if not c.is_rogue() and out["sect_day"] < 0:
			out["sect_day"] = clock.total_days
		if c.realm_index == 1 and not out["layer_day"].has(c.stage + 1):
			for layer in range(1, c.stage + 2):
				if not out["layer_day"].has(layer):
					out["layer_day"][layer] = clock.total_days
		var kinds := {}
		if curious:
			kinds = _curious_month(gs, c, done, clock.total_days)
		gs.explore()
		var counts := {}
		for i in range(mark, bus.history.size()):
			var cat: String = bus.history[i]["category"]
			counts[cat] = int(counts.get(cat, 0)) + 1
		out["month_lines"].append(counts)
		out["kinds"].append(kinds.size())
		var with_break := kinds.duplicate()
		if broke:
			with_break["breakthrough"] = true
		out["kind_sets"].append(with_break)
		out["stones"].append(c.item_count("spirit_stone"))
		out["realms"].append(Cultivation.realm_label(c, gs.data))
	out["injuries"] = c.injuries.size()
	out["fights_won"] = LifeStats.get_stat(c, "fights_won")
	out["fights_lost"] = LifeStats.get_stat(c, "fights_lost")
	out["fights_fled"] = LifeStats.get_stat(c, "threats_fled")
	return out


## The extra things a curious player does in one month: explore weekly, one
## harmless deed, one sect mission, one chat (once), deliver orders. Returns the
## set of action kinds done.
static func _curious_month(gs: Node, c: CharacterData, done: Dictionary, today: int) -> Dictionary:
	var kinds := {}
	for week in 3:
		if not c.alive:
			return kinds
		gs.explore_many(7)
		kinds["explore"] = true
		if gs.pending_encounter != "":
			gs.choose_encounter(0)
		if gs.pending_threat != "":
			gs.face_threat(false)
	if not c.alive:
		return kinds
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
	if not c.is_rogue() and c.alive:
		for mission_id in Sects.available_missions(c, gs.data, gs.world_flags):
			if Sects.check_mission(c, gs.data, mission_id, gs.world_flags) != "" or not _mission_is_sane(gs, c, mission_id, done, today):
				continue
			var lost_before := LifeStats.get_stat(c, "fights_lost")
			var odds_before := _mission_odds(gs, c, mission_id)
			gs.take_mission(mission_id)
			kinds["mission"] = true
			if LifeStats.get_stat(c, "fights_lost") > lost_before:
				done["lost_missions"][mission_id] = {"day": today, "odds": odds_before}
			break
	_recharge_with_spare_stones(gs, c)
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
		_everything_month(gs, c, kinds, today)
	return kinds


## QA-048: the rest of what the menus offer, each tried once a month and only when the core
## check allows it: craft, profession work, gift, pointers/spar, lecture, secret realm, and
## (every 6th month) a trip to the nearest unvisited region and back.
static func _everything_month(gs: Node, c: CharacterData, kinds: Dictionary, today: int) -> void:
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
	if c.alive:
		for npc_id: String in gs.npcs:
			if gs.check_pointers(npc_id) == "":
				gs.ask_pointers(npc_id)
				kinds["pointer"] = true
				break
			if gs.check_spar(npc_id) == "":
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
				gs.explore_many(7)
				if gs.pending_encounter != "":
					gs.choose_encounter(0)
				if gs.pending_threat != "":
					gs.face_threat(false)
				kinds["travel"] = true
				if c.alive:
					gs.travel(home)


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
	var lost: Dictionary = done["lost_missions"].get(mission_id, {})
	if not lost.is_empty() and today - int(lost["day"]) < 60 and odds < float(lost["odds"]) + 0.15:
		return false
	if c.artifact_lives >= 0 and c.artifact_lives <= 1 and odds < 0.85:
		return false  # the last life: only near-certain fights
	return not (danger == "Dangerous" and odds < 0.5 and c.artifact_lives >= 0 and c.artifact_lives <= 2)


## QA-054: buys an artifact life once stones exceed twice its price.
static func _recharge_with_spare_stones(gs: Node, c: CharacterData) -> void:
	if not c.alive or c.artifact_lives < 0:
		return
	if CreationArtifact.check_recharge(c, gs.data) == "" and c.item_count("spirit_stone") > 2 * CreationArtifact.recharge_cost(c, gs.data):
		gs.recharge_artifact()


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
