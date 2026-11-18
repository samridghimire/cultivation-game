extends SceneTree
## PERF-008: how long does a region take to build? For every region and Summer/Winter, times a cold-cache and a warm-cache
## world build (instantiate + add to tree; total adds the ground and path textures _draw makes on the first frame), plus the ground texture, path textures and decor pass called directly.
## tools/godot.sh --headless --path . -s res://tests/sim/region_load_times.gd [-- --region=a,b --runs=3]
## Writes no saves. Budget: 250 ms cold per region.

const SEASON_DAYS := {"Summer": 90, "Winter": 270}
var started := false
var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3 and not started:
		started = true
		_run()
		quit()
	return false


func _median(a: Array[float]) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _ms(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, rng, "male"))
	var runs := 3
	var only: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = maxi(1, int(arg.substr(7)))
		elif arg.begins_with("--region="):
			for id in arg.substr(9).split(",", false):
				only.append(id)
	if OS.get_cmdline_user_args().has("--no-disk-cache"):
		GroundCache.enabled = false
	var passes := OS.get_cmdline_user_args().has("--passes")
	var ids: Array = gs.data.regions.keys()
	ids.sort()
	if passes:
		_print_passes(gs, ids, only)
		return
	var over: Array[String] = []
	for warm in [false, true]:
		print("\n== %s cache (median of %d runs, ms) ==" % ["WARM" if warm else "COLD", runs])
		print("%-26s %-7s %8s %8s %8s %8s" % ["region", "season", "total", "ground", "paths", "decor"])
		for id: String in ids:
			if not only.is_empty() and not only.has(id):
				continue
			for season: String in SEASON_DAYS:
				var tot: Array[float] = []
				var gr: Array[float] = []
				var pa: Array[float] = []
				var de: Array[float] = []
				for i in runs:
					root.get_node("GameClock").total_days = SEASON_DAYS[season]
					gs.current_region = id
					if not warm:
						GroundTiles.clear_cache()
					elif i == 0:
						var primer := _build()
						_parts(primer, gs, id, season, true)  # prime the cache the way _draw would
						root.remove_child(primer)
						primer.free()
					var t0 := Time.get_ticks_usec()
					var w := _build()
					var build_ms := _ms(t0)
					var parts := _parts(w, gs, id, season, warm)
					tot.append(build_ms + parts[0] + parts[1])  # headless never runs _draw, so add the textures it would make
					gr.append(parts[0])
					pa.append(parts[1])
					de.append(parts[2])
					root.remove_child(w)
					w.free()
				var m := _median(tot)
				print("%-26s %-7s %8.1f %8.1f %8.1f %8.1f" % [id, season, m, _median(gr), _median(pa), _median(de)])
				if not warm and m > 250.0:
					over.append("%s/%s %.0f ms" % [id, season, m])
	print("\nOver the 250 ms cold budget: %s" % (", ".join(over) if not over.is_empty() else "none"))


func _build() -> Node:
	var w: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(w)
	return w


## Calls the game's own functions directly with the world's arguments: [ground ms, paths ms, decor ms].
func _parts(w: Node, gs: Node, rid: String, season: String, warm: bool) -> Array[float]:
	var map: Dictionary = gs.data.regions[rid].get("map", {})
	var sc := float(Sprites.scale())
	var size: Vector2 = w.map_size
	if not warm:
		GroundTiles.clear_cache()
	var gseason := GroundTiles.ground_season(season, map)
	var style := str(map.get("ground_style", "grass"))
	var t0 := Time.get_ticks_usec()
	GroundTiles.ground_texture(Color(map.get("ground", "4d6b3c")), rid, Vector2i(ceili(size.x / sc), ceili(size.y / sc)), ["Spring", "Summer"].has(season), gseason, style, Scenery.paved_zones(map, sc), float(map.get("scree_density", 1.0)), w.call("_ground_life", map, sc))
	var g := _ms(t0)
	t0 = Time.get_ticks_usec()
	for r in map.get("paths", []):
		GroundTiles.path_texture(Color(map.get("path_color", "8a7350")), rid, Vector2i(ceili(float(r[2]) / sc), ceili(float(r[3]) / sc)), gseason, style)
	var p := _ms(t0)
	t0 = Time.get_ticks_usec()
	w.call("_build_decor")
	var d := _ms(t0)
	return [g, p, d]


## `--passes`: per-pass usec inside GroundTiles.ground_texture for each region (cold, Summer and Winter).
func _print_passes(gs: Node, ids: Array, only: Array[String]) -> void:
	for id: String in ids:
		if not only.is_empty() and not only.has(id):
			continue
		for season: String in SEASON_DAYS:
			root.get_node("GameClock").total_days = SEASON_DAYS[season]
			gs.current_region = id
			var w := _build()
			GroundTiles.clear_cache()
			GroundTiles.profile = {}
			GroundTiles.profiling = true
			var parts := _parts(w, gs, id, season, false)
			GroundTiles.profiling = false
			var keys: Array = GroundTiles.profile.keys()
			keys.sort_custom(func(a, b): return GroundTiles.profile[a] > GroundTiles.profile[b])
			var line := "%-24s %-6s ground %7.1f ms:" % [id, season, parts[0]]
			for k in keys:
				line += "  %s %.0f" % [k, float(GroundTiles.profile[k]) / 1000.0]
			print(line)
			root.remove_child(w)
			w.free()
