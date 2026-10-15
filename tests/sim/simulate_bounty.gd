extends SceneTree
## Bounty-hunter economy sim (QA-053b, QA-061): a typical player takes a bounty whenever it is off
## cooldown and explores its region for `months` months. Prints stones/month from bounties, the share
## of hunts won, and the gather income of the same region for comparison. Runs every case in CASES.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_bounty.gd -- [seeds] [months]

const CombatBalance := preload("res://tests/sim/combat_balance.gd")
## [bounty id, realm index, stage] of the typical player who hunts it.
const CASES: Array = [
	["iron_back_boar_bounty", 1, 3],
	["drunk_bully_bounty", 1, 3],
	["sword_madman_bounty", 3, 0],
]
const HUNT_DAYS := 7  # one explore_many call; the gather comparison is per week too


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 12
	for entry: Array in CASES:
		_run_case(String(entry[0]), int(entry[1]), int(entry[2]), seeds, months)
	quit()


func _run_case(bounty_id: String, realm_index: int, stage: int, seeds: int, months: int) -> void:
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var data: GameData = gs.data
	var bounty := Bounties.def_of(data, bounty_id)
	var region := String(bounty["region"])
	var gather_week := _gather_per_week(data, region, realm_index)
	var best_region := region
	var best_week := gather_week
	for region_id: String in data.regions:
		var week := _gather_per_week(data, region_id, realm_index)
		if week > best_week:
			best_week = week
			best_region = region_id
	print("Bounty-hunter sim: %d seeds, %d months, %s layer %d, %s in %s (reward %d stones)" % [seeds, months, data.realms[realm_index].name, stage + 1, bounty_id, region, int(bounty["reward_stones"])])
	print("  seed  bounties  hunt weeks  stones  stones/month  injuries  lives spent")
	var done_all: Array = []
	var weeks_all: Array = []
	var fights_won := 0
	var fights_lost := 0
	for s in range(1, seeds + 1):
		gs.rng.seed = s
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var c := CharacterFactory.create("Hunter", data, rng)
		var model := CombatBalance.typical_player(data, realm_index, stage)
		c.attributes = model.attributes.duplicate()
		c.techniques = model.techniques.duplicate(true)
		c.equipment = model.equipment.duplicate()
		c.realm_index = realm_index
		c.stage = stage
		gs.start_session(c)
		gs.pending_event = ""
		gs.current_region = region
		gs.world_flags["discovered_" + region] = true
		var lives_start: int = c.artifact_lives
		var weeks := 0
		var end_day: int = clock.total_days + months * Calendar.DAYS_PER_MONTH
		while c.alive and clock.total_days < end_day:
			if c.bounty.is_empty() and Bounties.check_take(c, data, bounty_id, clock.total_days) == "":
				gs.take_bounty(bounty_id)
			if c.bounty.is_empty():
				gs.cultivate(7, Exploration.qi_density(data, region))  # waiting out the cooldown
			else:
				weeks += 1
				gs.explore_many(HUNT_DAYS)
				if gs.pending_encounter != "":
					gs.choose_encounter(0)
				if gs.pending_threat != "":
					gs.face_threat(false)
			gs.pending_respawn = {}
			gs.current_region = region
		var stones := LifeStats.get_stat(c, "stones_earned")
		var done := LifeStats.get_stat(c, "bounties_done")
		done_all.append(done)
		weeks_all.append(weeks)
		fights_won += LifeStats.get_stat(c, "fights_won")
		fights_lost += LifeStats.get_stat(c, "fights_lost")
		print("  %4d  %8d  %10d  %6d  %12.1f  %8d  %11d" % [s, done, weeks, done * int(bounty["reward_stones"]), float(done * int(bounty["reward_stones"])) / months, c.injuries.size(), lives_start - c.artifact_lives])
		gs.end_session()
	var total_done := 0
	var total_weeks := 0
	for i in done_all.size():
		total_done += done_all[i]
		total_weeks += weeks_all[i]
	var per_bounty_weeks := float(total_weeks) / maxf(total_done, 1)
	print("Hunt weeks per bounty claimed: %.1f; fights won %d, lost %d (%.0f%% won)" % [per_bounty_weeks, fights_won, fights_lost, 100.0 * fights_won / maxf(fights_won + fights_lost, 1)])
	print("Gathering in %s: %.1f stones/week (best place). One bounty = %.2f weeks of gather income; a week hunting earns %.1f stones." % [region, gather_week, float(bounty["reward_stones"]) / maxf(gather_week, 0.01), float(bounty["reward_stones"]) / maxf(per_bounty_weeks, 0.01)])
	print("Best gathering anywhere for this realm: %s at %.1f stones/week (a bounty week earns %.1fx that)." % [best_region, best_week, float(bounty["reward_stones"]) / maxf(per_bounty_weeks, 0.01) / maxf(best_week, 0.01)])
	print("")


## Expected stones per week of gathering at the region's best gather place (sold at shop price).
func _gather_per_week(data: GameData, region: String, realm_index: int) -> float:
	var best := 0.0
	var c := CharacterData.new()
	c.realm_index = realm_index
	for place: Dictionary in data.regions[region].get("places", []):
		if place.get("type", "") != "gather":
			continue
		var total := 0.0
		var value := 0.0
		for entry: Dictionary in Exploration.gather_table_for(c, data, place.get("gather_table", [])):
			total += float(entry.get("weight", 0.0))
			if String(entry.get("item", "")) != "":
				value += float(entry["weight"]) * (int(entry.get("min", 1)) + int(entry.get("max", 1))) / 2.0 * Items.sell_price(data, String(entry["item"]))
		best = maxf(best, value / maxf(total, 0.001) / maxi(1, int(place.get("gather_days", 1))) * 7.0)
	return best
