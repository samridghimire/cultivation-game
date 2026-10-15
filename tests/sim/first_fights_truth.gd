extends SceneTree
## QA-085: does the rated win % of a first-region foe match the real win rate? A new character
## after the curious policy's first steps (Elder Mo, the chores, qi items, the cheapest combat
## manual, starter gear) at Qi Refining layers 1-3 fights every foe the start region and its
## neighbours' exploration can throw at it (at any of those layers) 200 times through Combat.resolve (the call GameState.fight_enemy
## makes; no ally strike, full HP) and prints it next to Combat.win_chance (the rating).
## "(!)" marks rows where rated and real differ by more than 15 points.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/first_fights_truth.gd -- [fights] [seed]
## (Not staged: tests/sim/screenshot_first_hour.gd draws a hand-written Wild Boar log, which is why
## its shot read "Weak" over a defeat; real boar fights are in the table below.)

const FirstHour := preload("res://tests/sim/first_hour.gd")
const LAYERS: Array[int] = [1, 2, 3]
const GAP := 0.15


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var fights := int(args[0]) if args.size() > 0 else 200
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var gs: Node = root.get_node("GameState")
	var c := _newcomer(gs, seed_value)
	var data: GameData = gs.data
	var foes := foe_ids(c, data, gs.current_region)
	print("First-fights truth: %d fights per row, seed %d. Techniques: %s; weapon %s, armor %s." % [fights, seed_value, ",".join(c.techniques.keys()), c.equipment.get("weapon", "-"), c.equipment.get("armor", "-")])
	var bad := 0
	for layer in LAYERS:
		c.stage = layer - 1
		print("Qi Refining layer %d:" % layer)
		for id: String in foes:
			var enemy: Dictionary = data.enemies[id]
			var rated := Combat.win_chance(c, data, enemy)
			var real := real_rate(c, data, enemy, fights)
			var off := absf(rated - real) > GAP
			bad += 1 if off else 0
			print("  %-22s rated %3d%% (%-9s) real %3d%%%s" % [id, roundi(rated * 100), Combat.label_for_chance(rated), roundi(real * 100), "  (!)" if off else ""])
	print("Rows off by more than %d points: %d" % [roundi(GAP * 100), bad])
	quit()


## The curious policy's first steps for a default character, left at Qi Refining layer 1.
func _newcomer(gs: Node, seed_value: int) -> CharacterData:
	gs.rng.seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c := CharacterFactory.create("Newcomer", gs.data, rng)
	gs.start_session(c)
	gs.pending_event = ""
	FirstHour._talk_to_elder_mo(gs)
	for chore in FirstHour.CHORES:
		gs.perform_deed(chore)
	FirstHour._use_qi_items(gs, c)
	var manual: String = FirstHour.cheapest_combat_manual(gs, c)
	if manual != "":
		c.add_item("spirit_stone", int(gs.data.items[manual].get("price", 0)))
		gs.buy_item(manual)
		gs.use_item(manual)
	c.add_item("iron_sword", 1)
	gs.equip_item("iron_sword")
	c.realm_index = data_realm(gs.data)
	return c


static func data_realm(data: GameData) -> int:
	return data.realm_index_of("qi_refining")


## Enemy ids the start region's and its neighbours' exploration can throw at a Qi Refining character at any of LAYERS.
static func foe_ids(c: CharacterData, data: GameData, region_id: String) -> Array[String]:
	var out: Array[String] = []
	var saved := c.stage
	for where: String in data.regions:
		if where != region_id and not Exploration.is_nearby(data, region_id, where):
			continue
		var tags: Array = data.regions[where].get("encounter_tags", [])
		for layer in LAYERS:
			c.stage = layer - 1
			for id in Exploration.eligible_fights(c, data, tags, {}, "spring", where):
				if not out.has(id):
					out.append(id)
	c.stage = saved
	return out


static func real_rate(c: CharacterData, data: GameData, enemy: Dictionary, fights: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	var wins := 0
	for i in fights:
		if Combat.resolve(c, data, enemy, rng)["victory"]:
			wins += 1
	return float(wins) / fights
