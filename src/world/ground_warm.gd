class_name GroundWarm
extends RefCounted
## PERF-017: bakes the ground of the regions one road away on a worker thread a couple of seconds after a region loads,
## into GroundCache, so the first visit reads a PNG instead of building (Fallen Star in Winter took ~380 ms cold).
## The thread runs only GroundTiles.ground_image (pure pixels) and the cache write; arguments are built on the main
## thread by `args_for`, the same ones world.gd's _draw passes, so the memory/disk keys match.


## GFX-130: path rects clover keeps off and the worn ellipses round places, in ground-texture px.
static func life_for(region: Dictionary, sc: float) -> Dictionary:
	var map: Dictionary = region.get("map", {})
	var avoid: Array = []
	for r in map.get("paths", []):
		avoid.append(Rect2(float(r[0]) / sc, float(r[1]) / sc, float(r[2]) / sc, float(r[3]) / sc))
	var zones := Scenery.paved_zones(map, sc)
	var worn: Array = []
	for pl in region.get("places", []):
		var k := Npcs.place_keepout(pl)
		var e := Rect2(k.get_center() - k.size * 0.65, k.size * 1.3)
		var ok := true
		for z: Rect2 in zones:
			if z.intersects(Rect2(e.position / sc, e.size / sc)):
				ok = false
		if ok:
			worn.append(Rect2(e.position / sc, e.size / sc))
	for r in worn:
		avoid.append(r)
	return {"avoid": avoid, "worn": worn, "path_color": Color(map.get("path_color", "8a7350")), "speckle": float(map.get("speckle", 1.0)), "alpine_meadow": map.get("alpine_meadow", false)}


## The ground_texture arguments region `region` draws in `season` (calendar season), or {} when a sprite replaces the ground.
static func args_for(region: Dictionary, rid: String, season: String, sc: float) -> Dictionary:
	if Sprites.first(["ground_" + rid, "ground"]) != null:
		return {}
	var map: Dictionary = region.get("map", {})
	var size := Vector2(float(map.get("size", [1600, 1000])[0]), float(map.get("size", [1600, 1000])[1]))
	return {
		"base": Color(map.get("ground", "4d6b3c")), "rid": rid, "size_px": Vector2i(ceili(size.x / sc), ceili(size.y / sc)),
		"flowers": ["Spring", "Summer"].has(season), "season": GroundTiles.ground_season(season, map),
		"style": str(map.get("ground_style", "grass")), "zones": Scenery.paved_zones(map, sc),
		"scree": float(map.get("scree_density", 1.0)), "life": life_for(region, sc),
	}


static func key_of(a: Dictionary) -> String:
	return GroundTiles.memory_key(a["base"], a["rid"], a["size_px"], a["flowers"], a["season"], a["style"], a["zones"], a["scree"], a["life"])


static var _queued: Dictionary = {}


## Queues a background bake of one region's ground. Returns true when a task was started.
static func warm(region: Dictionary, rid: String, season: String) -> bool:
	if not GroundCache.enabled or not GroundCache.threaded:
		return false
	var a := args_for(region, rid, season, float(Sprites.scale()))
	if a.is_empty() or a["size_px"].x * a["size_px"].y < GroundCache.MIN_PIXELS:
		return false
	var mem := key_of(a)
	var disk_key := GroundCache.key([mem])
	# PERF-026: a queued bake blocks a repeat only while it runs; once done, a file the cache pruned is baked again.
	if (_queued.has(disk_key) and not _queued[disk_key][0]) or GroundTiles.is_cached(mem) or GroundCache.has(disk_key):
		return false
	var done := [false]
	_queued[disk_key] = done
	GroundTiles._byte_to_float()  # lazy table: build it here, not racily on the worker
	DirAccess.make_dir_recursive_absolute(GroundCache.dir)
	var d := GroundCache.dir
	GroundCache._reap()
	GroundCache._tasks.append(WorkerThreadPool.add_task(func() -> void:
		var img := GroundTiles.ground_image(a["base"], a["rid"], a["size_px"], a["flowers"], a["season"], a["style"], a["zones"], a["scree"], a["life"])
		GroundCache._write(d, disk_key, img)
		done[0] = true))
	return true


## Bakes the regions one road from `rid` for `season`; returns how many tasks started.
static func warm_neighbours(data: GameData, rid: String, season: String) -> int:
	var n := 0
	for route: Dictionary in data.regions.get(rid, {}).get("routes", []):
		var to := str(route.get("to", ""))
		if data.regions.has(to) and warm(data.regions[to], to, season):
			n += 1
	return n


## PERF-022: the season that follows the current one when it ends within this many days.
const NEXT_SEASON_WITHIN := 7


## Bakes the neighbours for the current season, then, when the season ends within NEXT_SEASON_WITHIN days, the next
## season's ground of the current region and its neighbours (lowest priority: queued last). Returns tasks started.
static func warm_all(data: GameData, rid: String, total_days: int) -> int:
	var n := warm_neighbours(data, rid, Calendar.season_of(total_days))
	if Calendar.days_left_in_season(total_days) > NEXT_SEASON_WITHIN:
		return n
	var next := Calendar.season_of(total_days + Calendar.days_left_in_season(total_days) + 1)
	if data.regions.has(rid) and warm(data.regions[rid], rid, next):
		n += 1
	return n + warm_neighbours(data, rid, next)
