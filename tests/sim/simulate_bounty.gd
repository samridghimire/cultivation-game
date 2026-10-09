extends SceneTree
## Bounty-hunter economy sim (QA-053b): a Qi Refining 4th Layer typical player takes the Misty Forest
## bounty whenever it is off cooldown and explores there for `months` months. Prints stones/month from
## bounties, the share of hunts won, and the gather income of the same region for comparison.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_bounty.gd -- [seeds] [months]

const CombatBalance := preload("res://tests/sim/combat_balance.gd")
const BOUNTY_ID := "iron_back_boar_bounty"
const REGION := "misty_forest"
const STAGE := 3
const HUNT_DAYS := 7  # one explore_many call; the gather comparison is per week too


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 12
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var data: GameData = gs.data
	var bounty := Bounties.def_of(data, BOUNTY_ID)
	var gather_week := _gather_per_week(data)
	print("Bounty-hunter sim: %d seeds, %d months, Qi Refining layer %d, %s in %s (reward %d stones)" % [seeds, months, STAGE + 1, BOUNTY_ID, REGION, int(bounty["reward_stones"])])
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
		var model := CombatBalance.typical_player(data, 1, STAGE)
		c.attributes = model.attributes.duplicate()
		c.techniques = model.techniques.duplicate(true)
		c.equipment = model.equipment.duplicate()
		c.realm_index = 1
		c.stage = STAGE
		gs.start_session(c)
		gs.pending_event = ""
		gs.current_region = REGION
		gs.world_flags["discovered_" + REGION] = true
		var lives_start: int = c.artifact_lives
		var weeks := 0
		var end_day: int = clock.total_days + months * Calendar.DAYS_PER_MONTH
		while c.alive and clock.total_days < end_day:
			if c.bounty.is_empty() and Bounties.check_take(c, data, BOUNTY_ID, clock.total_days) == "":
				gs.take_bounty(BOUNTY_ID)
			if c.bounty.is_empty():
				gs.cultivate(7, Exploration.qi_density(data, REGION))  # waiting out the cooldown
			else:
				weeks += 1
				gs.explore_many(HUNT_DAYS)
				if gs.pending_encounter != "":
					gs.choose_encounter(0)
				if gs.pending_threat != "":
					gs.face_threat(false)
			gs.pending_respawn = {}
			gs.current_region = REGION
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
	print("Gathering in %s: %.1f stones/week (best place). One bounty = %.2f weeks of gather income; a week hunting earns %.1f stones." % [REGION, gather_week, float(bounty["reward_stones"]) / maxf(gather_week, 0.01), float(bounty["reward_stones"]) / maxf(per_bounty_weeks, 0.01)])
	quit()


## Expected stones per week of gathering at the region's best gather place (sold at shop price).
func _gather_per_week(data: GameData) -> float:
	var best := 0.0
	var c := CharacterData.new()
	c.realm_index = 1
	for place: Dictionary in data.regions[REGION].get("places", []):
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
