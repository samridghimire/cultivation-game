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
	var out := {"layer_day": {}, "sect_day": -1, "month_lines": [], "injuries": 0, "player": c, "kinds": []}
	var done := {}
	_talk_to_elder_mo(gs)
	for chore in CHORES:
		gs.perform_deed(chore)
	_use_qi_items(gs, c)
	for month in months:
		if not c.alive:
			break
		var mark: int = bus.history.size()
		gs.cultivate(Calendar.DAYS_PER_MONTH, SPRING_DENSITY)
		if not c.alive:
			break
		if Cultivation.can_attempt_breakthrough(c, gs.data):
			gs.attempt_breakthrough()
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
			if Sects.check_mission(c, gs.data, mission_id, gs.world_flags) == "" and Sects.mission_danger(c, gs.data, mission_id) != "Deadly":
				gs.take_mission(mission_id)
				kinds["mission"] = true
				break
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
	return kinds


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
