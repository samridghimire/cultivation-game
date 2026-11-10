extends SceneTree
## QA-206: is fishing worth a day? For a Novice (0 xp), Angler (10) and Old Hand (40) at the fishing place
## of Qingshi (jetty stage 0 and 3) and of every other region: stones per fishing day (catch sold at the
## shop price of that season) by season, and the share of trips that bring a rare entry. Compared with a
## gathering day at the region's best gather place. Casts are ordinary (quality 0.5); storm days are lost.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_fishing.gd -- [trips per cell]

const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const RANKS: Array = [["Novice", 0], ["Angler", 10], ["Old Hand", 40]]
## Regions whose whole catch table needs a realm: the sim character (and the gathering row) is at this realm index.
## myriad_peaks_ridge: every entry needs Core Formation (3), so its rows are for a Core Formation character.
const REALM_FOR_REGION := {"myriad_peaks_ridge": 3}


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var trips := int(args[0]) if args.size() > 0 else 300
	var gs: Node = root.get_node("GameState")
	var data: GameData = gs.data
	print("Stones per fishing day (trip = 2 days, %d trips per cell, ordinary casts, storm days lost)" % trips)
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if String(place.get("type", "")) != "fishing":
				continue
			var rid := String(region["id"])
			var flags: Array = [0, 3] if rid == "qingshi_village" else [0]
			for stage: int in flags:
				for rank: Array in RANKS:
					_cell(gs, data, rid, place, String(rank[0]), int(rank[1]), stage, trips)
			print("  gathering in %s: %.2f stones/day at the best gather place (%s)" % [rid, _gather_day(data, rid), "Core Formation" if REALM_FOR_REGION.has(rid) else "Mortal"])
	quit(0)


func _cell(gs: Node, data: GameData, rid: String, place: Dictionary, rank: String, xp: int, stage: int, trips: int) -> void:
	var clock: Node = root.get_node("GameClock")
	var days := int(place.get("gather_days", 2))
	var per_season: Array[String] = []
	var all_stones := 0.0
	var all_days := 0
	var rare_trips := 0
	var all_trips := 0
	for season_i in SEASONS.size():
		var stones := 0
		for i in trips:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 * season_i + i + 1
			var c := CharacterFactory.create("Angler", data, rng)
			c.fishing_xp = xp
			c.realm_index = int(REALM_FOR_REGION.get(rid, 0))
			gs.start_session(c)
			gs.pending_event = ""
			gs.current_region = rid
			gs.world_flags["discovered_" + rid] = true
			for s in 3:
				gs.world_flags.erase("jetty_stage_%d" % (s + 1))
			for s in stage:
				gs.world_flags["jetty_stage_%d" % (s + 1)] = true
			gs.rng.seed = rng.seed
			clock.total_days = season_i * 90 + (i * 7) % 90 + 360
			var season := Calendar.season_of(clock.total_days)
			gs.fish(place.get("catch_table", []), days, "", 0.5)
			var got := false
			for item_id: String in c.inventory:
				var n := int(c.inventory[item_id])
				stones += n * Items.sell_price(data, item_id, season)
				for entry: Dictionary in place.get("catch_table", []):
					if String(entry.get("item", "")) == item_id and Fishing.is_rare(entry):
						got = true
			rare_trips += 1 if got else 0
			all_trips += 1
			gs.end_session()
		per_season.append("%s %.2f" % [SEASONS[season_i].substr(0, 3), float(stones) / (trips * days)])
		all_stones += stones
		all_days += trips * days
	print("  %-22s %-8s jetty %d: %.2f/day avg (%s), rare in %.0f%% of trips" % [rid, rank, stage, all_stones / all_days, ", ".join(per_season), 100.0 * rare_trips / all_trips])


## Expected stones per day at the region's best gather place (sold at shop price); one trip makes Exploration.GATHER_ROLLS rolls, as GameState.gather does.
func _gather_day(data: GameData, region: String) -> float:
	var best := 0.0
	var c := CharacterData.new()
	c.realm_index = int(REALM_FOR_REGION.get(region, 0))
	for place: Dictionary in data.regions[region].get("places", []):
		if place.get("type", "") != "gather":
			continue
		var total := 0.0
		var value := 0.0
		for entry: Dictionary in Exploration.gather_table_for(c, data, place.get("gather_table", [])):
			total += float(entry.get("weight", 0.0))
			if String(entry.get("item", "")) != "":
				value += float(entry["weight"]) * (int(entry.get("min", 1)) + int(entry.get("max", 1))) / 2.0 * Items.sell_price(data, String(entry["item"]))
		best = maxf(best, value / maxf(total, 0.001) * Exploration.GATHER_ROLLS / maxi(1, int(place.get("gather_days", 1))))
	return best
