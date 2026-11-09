class_name Scenery
extends RefCounted
## Decorative scenery for a region map (VIS-002): trees, rocks, grass tufts and
## flowers scattered off the paths, places, abodes, npc_spots and spawn point.
## Pure placement: the world scene draws the result. Counts and colors come
## from regions.json `map.decor`, falling back to DEFAULTS.

## Kinds of drifting ambient particles a region map may name (world/ambient.gd draws them).
const AMBIENT_KINDS: PackedStringArray = ["petals", "leaves", "snow", "mist", "embers", "fireflies"]
const KINDS := ["tree", "rock", "grass", "flower"]
## map.decor keys: "<kind>s" counts, "<kind>_color" colors.
const DEFAULTS := {
	"trees": 14, "rocks": 8, "grass": 40, "flowers": 12,
	"tree_color": "2e5a2a", "rock_color": "7d7a72", "grass_color": "5f8a45", "flower_color": "e8c9e0",
}
const MAX_COUNT := 300
## map.decor.tree_kinds kinds (GFX-041); "round" is the village tree and the default.
const TREE_KINDS: PackedStringArray = ["round", "pine", "willow", "dead", "bamboo"]
## map.decor.clusters (clumps of 4-7 trees) upper bound, and a clump's radius.
const MAX_CLUSTERS := 12
const CLUSTER_RADIUS := 60.0
## Decor keys beyond DEFAULTS' counts and colours.
const EXTRA_KEYS: PackedStringArray = ["tree_kinds", "blossoms", "clusters", "rock_clusters", "edge_belt"]
## map.decor.rock_clusters (GFX-053): boulder groups of 3-6 rocks in 2-3 sizes, seeded before the scatter.
const MAX_ROCK_CLUSTERS := 12
const ROCK_CLUSTER_RADIUS := 45.0
## map.decor.edge_belt (GFX-089): 0..MAX_EDGE_BELT rows of dense trees along the map edges, EDGE_ROW_GAP px apart,
## EDGE_STEP px between trees; blocked rects (paths, places) leave gaps.
const MAX_EDGE_BELT := 3
const EDGE_ROW_GAP := 26.0
const EDGE_STEP := 34.0
## Decor keeps this far from a path rect (GFX-053).
const PATH_CLEARANCE := 12.0
## map.landmarks kinds (GFX-008, GFX-012); the solid ones block the player, the rest can be walked over.
const LANDMARK_KINDS: PackedStringArray = ["house", "field", "pond", "fence", "well", "wall", "cliff", "stream", "lantern", "pine", "stall", "jetty", "steps", "clouds"]
const SOLID_LANDMARKS: PackedStringArray = ["house", "well", "wall", "cliff", "lantern", "pine", "stall"]
## Crop-row colour of the field landmark by season (GFX-037); transparent while the furrows lie bare.
const CROP_COLORS := {"Spring": "7fc04a", "Summer": "4f9a3a", "Autumn": "d9aa3a", "Winter": "00000000"}
## Autumn canopy tones a tree picks from by its seed.
const AUTUMN_TONES: PackedStringArray = ["c9622a", "b8452c", "d99a2e", "a8532a"]
## Clearance kept around places, npc spots and the spawn point, and from the map edge.
const CLEARANCE := 28.0
const SPOT_RADIUS := 30.0
const EDGE := 16.0
## Placement tries per decoration before it is dropped.
const TRIES := 12


## Count key of a kind in map.decor ("grass" is both singular and plural).
static func count_key(kind: String) -> String:
	return "grass" if kind == "grass" else kind + "s"


## Decor settings of a region: DEFAULTS overridden by map.decor.
static func settings(region: Dictionary) -> Dictionary:
	var out := DEFAULTS.duplicate()
	out.merge(region.get("map", {}).get("decor", {}), true)
	return out


## [{kind, pos: Vector2, scale: float, color: Color}] for a region, deterministic
## for a given rng seed. Nothing is placed on paths, places, npc_spots or spawn.
static func place(region: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var map: Dictionary = region.get("map", {})
	var size_arr: Array = map.get("size", [1600, 1000])
	var size := Vector2(float(size_arr[0]), float(size_arr[1]))
	var blocked := blocked_rects(region)
	var spots: Array[Vector2] = []
	for s in region.get("npc_spots", []):
		spots.append(Vector2(float(s[0]), float(s[1])))
	if region.has("spawn"):
		spots.append(Vector2(float(region["spawn"][0]), float(region["spawn"][1])))
	var cfg := settings(region)
	var out: Array[Dictionary] = []
	for kind: String in KINDS:
		var color := Color(String(cfg[kind + "_color"]))
		var budget := clampi(int(cfg[count_key(kind)]), 0, MAX_COUNT)
		if kind == "tree":
			for c in clampi(int(cfg.get("clusters", 0)), 0, MAX_CLUSTERS):
				budget -= _place_clump(out, cfg, color, budget, size, blocked, spots, rng)
		if kind == "rock":
			for c in clampi(int(cfg.get("rock_clusters", 0)), 0, MAX_ROCK_CLUSTERS):
				budget -= _place_rock_group(out, cfg, color, budget, size, blocked, spots, rng)
		for i in budget:
			for attempt in TRIES:
				var pos := Vector2(rng.randf_range(EDGE, size.x - EDGE), rng.randf_range(EDGE, size.y - EDGE))
				if is_clear(pos, blocked, spots):
					out.append(_decor_item(kind, pos, color, cfg, rng))
					break
	var rows := clampi(int(cfg.get("edge_belt", 0)), 0, MAX_EDGE_BELT)
	if rows > 0:
		_place_edge_belt(out, cfg, Color(String(cfg["tree_color"])), rows, size, blocked, spots, rng)
	return out


## GFX-089: rows of trees hugging all four map edges so a forest closes in; skips blocked spots (path gaps).
static func _place_edge_belt(out: Array[Dictionary], cfg: Dictionary, color: Color, rows: int, size: Vector2,
		blocked: Array[Rect2], spots: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for r in rows:
		var inset := EDGE + 10.0 + float(r) * EDGE_ROW_GAP
		var x := inset
		while x <= size.x - inset:
			for y: float in [inset, size.y - inset]:
				var pos := Vector2(x + rng.randf_range(-6.0, 6.0), y + rng.randf_range(-5.0, 5.0))
				if is_clear(pos, blocked, spots):
					out.append(_decor_item("tree", pos, color, cfg, rng))
			x += EDGE_STEP
		var y2 := inset + EDGE_STEP
		while y2 <= size.y - inset - EDGE_STEP * 0.5:
			for x2: float in [inset, size.x - inset]:
				var pos2 := Vector2(x2 + rng.randf_range(-5.0, 5.0), y2 + rng.randf_range(-6.0, 6.0))
				if is_clear(pos2, blocked, spots):
					out.append(_decor_item("tree", pos2, color, cfg, rng))
			y2 += EDGE_STEP


static func _decor_item(kind: String, pos: Vector2, color: Color, cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var item := {"kind": kind, "pos": pos, "scale": rng.randf_range(0.8, 1.25), "color": color}
	if kind == "tree":
		item["tree_kind"] = pick_tree_kind(cfg.get("tree_kinds", {}), rng)
	return item


## A weighted pick from map.decor.tree_kinds; no rng draw when the region has none (layouts stay stable).
static func pick_tree_kind(kinds: Variant, rng: RandomNumberGenerator) -> String:
	if not (kinds is Dictionary) or (kinds as Dictionary).is_empty():
		return "round"
	var keys: Array = (kinds as Dictionary).keys()
	keys.sort()
	var total := 0.0
	for k: Variant in keys:
		total += float(kinds[k])
	var roll := rng.randf() * total
	for k: Variant in keys:
		roll -= float(kinds[k])
		if roll < 0.0:
			return String(k)
	return String(keys[keys.size() - 1])


## Seeds one clump of 4-7 trees around a clear centre; returns how many were placed (at most `budget`).
static func _place_clump(out: Array[Dictionary], cfg: Dictionary, color: Color, budget: int, size: Vector2,
		blocked: Array[Rect2], spots: Array[Vector2], rng: RandomNumberGenerator) -> int:
	var want := mini(rng.randi_range(4, 7), budget)
	if want <= 0:
		return 0
	var centre := Vector2.ZERO
	var found := false
	for attempt in TRIES * 3:
		centre = Vector2(rng.randf_range(EDGE + CLUSTER_RADIUS, size.x - EDGE - CLUSTER_RADIUS), rng.randf_range(EDGE + CLUSTER_RADIUS, size.y - EDGE - CLUSTER_RADIUS))
		if is_clear(centre, blocked, spots):
			found = true
			break
	if not found:
		return 0
	var placed := 0
	for i in want:
		for attempt in TRIES:
			var pos := centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, CLUSTER_RADIUS)
			if pos.x > EDGE and pos.y > EDGE and pos.x < size.x - EDGE and pos.y < size.y - EDGE and is_clear(pos, blocked, spots):
				out.append(_decor_item("tree", pos, color, cfg, rng))
				placed += 1
				break
	return placed


## GFX-053: a group of 3-6 rocks in 2-3 sizes (scale 0.7..1.9) around a clear centre; returns how many were placed.
static func _place_rock_group(out: Array[Dictionary], cfg: Dictionary, color: Color, budget: int, size: Vector2,
		blocked: Array[Rect2], spots: Array[Vector2], rng: RandomNumberGenerator) -> int:
	var want := mini(rng.randi_range(3, 6), budget)
	if want <= 0:
		return 0
	var centre := Vector2.ZERO
	var found := false
	for attempt in TRIES * 3:
		centre = Vector2(rng.randf_range(EDGE + ROCK_CLUSTER_RADIUS, size.x - EDGE - ROCK_CLUSTER_RADIUS), rng.randf_range(EDGE + ROCK_CLUSTER_RADIUS, size.y - EDGE - ROCK_CLUSTER_RADIUS))
		if is_clear(centre, blocked, spots):
			found = true
			break
	if not found:
		return 0
	var sizes := [0.7, 1.2, 1.9]
	var placed := 0
	for i in want:
		for attempt in TRIES:
			var pos := centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, ROCK_CLUSTER_RADIUS)
			if pos.x > EDGE and pos.y > EDGE and pos.x < size.x - EDGE and pos.y < size.y - EDGE and is_clear(pos, blocked, spots):
				var item := _decor_item("rock", pos, color, cfg, rng)
				item["scale"] = float(sizes[rng.randi_range(0, 2)]) if i > 0 else 1.9
				out.append(item)
				placed += 1
				break
	return placed


## Paths grown by PATH_CLEARANCE, places and abodes grown by CLEARANCE (both are centered on pos).
static func blocked_rects(region: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in region.get("map", {}).get("paths", []):
		out.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(PATH_CLEARANCE))
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var pos: Array = p.get("pos", [0, 0])
		var sz: Array = p.get("size", [64, 64])
		var size := Vector2(float(sz[0]), float(sz[1]))
		out.append(Rect2(Vector2(float(pos[0]), float(pos[1])) - size / 2.0, size).grow(CLEARANCE))
	for r in landmark_rects(region):
		out.append(r.grow(CLEARANCE / 2.0))
	return out


## Landmark rects of a region: map.landmarks `pos` is the centre, like a place's.
static func landmark_rects(region: Dictionary, solid_only: bool = false) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for lm: Dictionary in region.get("map", {}).get("landmarks", []):
		if solid_only and not SOLID_LANDMARKS.has(String(lm.get("kind", ""))):
			continue
		var pos: Array = lm["pos"]
		var sz: Array = lm["size"]
		var size := Vector2(float(sz[0]), float(sz[1]))
		var rect := Rect2(Vector2(float(pos[0]), float(pos[1])) - size / 2.0, size)
		if lm.get("kind", "") == "jetty":
			rect = jetty_layout(region, lm)["rect"]
		out.append(rect)
	return out


## WU-494: how much of the Village Pond Jetty is built at project `stage` (0..3; -1 = a jetty that is not the project's): the fraction of planks laid from the shore,
## whether the planks still have gaps, and whether the lantern post stands.
static func jetty_stage_look(stage: int) -> Dictionary:
	if stage < 0:  # RV-019: not the village project's jetty: a plain, whole walkway with no lantern post
		return {"frac": 1.0, "gaps": false, "lantern": false}
	match clampi(stage, 0, 3):
		0:
			return {"frac": 0.0, "gaps": false, "lantern": false}
		1:
			return {"frac": 0.5, "gaps": false, "lantern": false}
		2:
			return {"frac": 1.0, "gaps": true, "lantern": false}
	return {"frac": 1.0, "gaps": false, "lantern": true}


## WU-500: the jetty's post rects (6x6) at project `stage`. An unbuilt stretch (stage 0..1) shows bare posts in pairs along the
## full length, but only those standing in the water or within 6 px of the pond's rim; a finished jetty keeps two posts at the water end.
static func jetty_posts(region: Dictionary, lm: Dictionary, stage: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var lay := jetty_layout(region, lm)
	if not bool(lay["on_water"]):
		return out
	var full: Rect2 = lay["rect"]
	var vertical := bool(lay["vertical"])
	var toward: int = int(lay.get("toward_water", -1))
	var ponds: Array[Rect2] = []
	for other: Dictionary in region.get("map", {}).get("landmarks", []):
		if other.get("kind", "") == "pond":
			var half := Vector2(float(other["size"][0]), float(other["size"][1])) / 2.0
			ponds.append(Rect2(Vector2(float(other["pos"][0]), float(other["pos"][1])) - half, half * 2.0))
	var span := full.size.y if vertical else full.size.x
	var along: Array[float] = [2.0]
	if jetty_stage_look(stage)["frac"] < 1.0:
		along = [4.0, 4.0 + (span - 8.0) / 2.0, 4.0 + (span - 8.0)]
	for t in along:
		for off: float in [-9.0, 9.0]:
			var tip: Vector2
			if vertical:
				tip = Vector2(full.get_center().x + off, full.position.y + t if toward < 0 else full.end.y - t)
			else:
				tip = Vector2(full.position.x + t if toward < 0 else full.end.x - t, full.get_center().y + off)
			var post := Rect2(tip - Vector2(3, 3), Vector2(6, 6))
			var keep := false
			for pond in ponds:
				if pond.grow(6.0).intersects(post):
					keep = true
			if keep:
				out.append(post)
	return out


## GFX-046: where a `jetty` landmark really sits. Within JETTY_REACH px of a pond landmark it runs from the pond's
## nearest rim toward the landmark's pos (the fishing place), long side perpendicular to the shore, overlapping the
## water by JETTY_OVERLAP px; otherwise (a stream ford, no pond) it stays on its own rect. Returns {rect: Rect2 on
## the map, vertical: bool (true = the long side runs north-south), on_water: bool}.
const JETTY_REACH := 160.0
const JETTY_OVERLAP := 8.0


static func jetty_layout(region: Dictionary, lm: Dictionary) -> Dictionary:
	var pos := Vector2(float(lm["pos"][0]), float(lm["pos"][1]))
	var size := Vector2(float(lm["size"][0]), float(lm["size"][1]))
	var own := Rect2(pos - size / 2.0, size)
	var long_side := maxf(size.x, size.y)
	var short_side := minf(size.x, size.y)
	var best: Dictionary = {}
	var best_dist := INF
	for other: Dictionary in region.get("map", {}).get("landmarks", []):
		if other.get("kind", "") != "pond":
			continue
		var pc := Vector2(float(other["pos"][0]), float(other["pos"][1]))
		var half := Vector2(float(other["size"][0]), float(other["size"][1])) / 2.0
		if not Rect2(pc - half, half * 2.0).grow(JETTY_REACH).has_point(pos):
			continue
		var d := pos.distance_to(pc)
		if d < best_dist:
			best_dist = d
			best = {"c": pc, "half": half}
	if best.is_empty():
		return {"rect": own, "vertical": size.y > size.x, "on_water": false}
	var c: Vector2 = best["c"]
	var half: Vector2 = best["half"]
	var delta := pos - c
	var vertical := absf(delta.y) / half.y >= absf(delta.x) / half.x
	var rect: Rect2
	if vertical:
		var x := clampf(pos.x, c.x - half.x * 0.8, c.x + half.x * 0.8)
		var t := sqrt(maxf(0.0, 1.0 - pow((x - c.x) / half.x, 2.0)))
		if delta.y >= 0.0:
			var rim := c.y + half.y * t
			rect = Rect2(x - short_side / 2.0, rim - JETTY_OVERLAP, short_side, long_side)
		else:
			var rim2 := c.y - half.y * t
			rect = Rect2(x - short_side / 2.0, rim2 + JETTY_OVERLAP - long_side, short_side, long_side)
	else:
		var y := clampf(pos.y, c.y - half.y * 0.8, c.y + half.y * 0.8)
		var t2 := sqrt(maxf(0.0, 1.0 - pow((y - c.y) / half.y, 2.0)))
		if delta.x >= 0.0:
			var rim3 := c.x + half.x * t2
			rect = Rect2(rim3 - JETTY_OVERLAP, y - short_side / 2.0, long_side, short_side)
		else:
			var rim4 := c.x - half.x * t2
			rect = Rect2(rim4 + JETTY_OVERLAP - long_side, y - short_side / 2.0, long_side, short_side)
	var toward := -1 if (vertical and delta.y >= 0.0) or (not vertical and delta.x >= 0.0) else 1
	var clipped := _clip_to_paths(region, rect, vertical, toward)
	if clipped.size.x > 0.0:
		rect = clipped
	return {"rect": rect, "vertical": vertical, "on_water": true, "toward_water": toward}


## GFX-049: a jetty never crosses a path. Its land end (opposite the water end) stops JETTY_PATH_GAP px before a
## path it would enter, but stays at least JETTY_MIN_LEN long (overlapping the water more). Unchanged if no path is in the way.
const JETTY_PATH_GAP := 6.0
const JETTY_MIN_LEN := 28.0


static func _clip_to_paths(region: Dictionary, rect: Rect2, vertical: bool, toward: int) -> Rect2:
	var out := rect
	for pr: Array in region.get("map", {}).get("paths", []):
		var path := Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3]))
		if not path.intersects(out):
			continue
		# toward < 0: the water end is the low (north/west) end, so the land end is the high one; else the reverse.
		if vertical:
			if toward < 0:
				var end_y := minf(out.end.y, path.position.y - JETTY_PATH_GAP)
				if path.position.y >= out.position.y:
					out = Rect2(out.position.x, out.position.y, out.size.x, maxf(JETTY_MIN_LEN, end_y - out.position.y))
			else:
				var start_y := maxf(out.position.y, path.end.y + JETTY_PATH_GAP)
				if path.end.y <= out.end.y:
					var len := maxf(JETTY_MIN_LEN, out.end.y - start_y)
					out = Rect2(out.position.x, out.end.y - len, out.size.x, len)
		else:
			if toward < 0:
				var end_x := minf(out.end.x, path.position.x - JETTY_PATH_GAP)
				if path.position.x >= out.position.x:
					out = Rect2(out.position.x, out.position.y, maxf(JETTY_MIN_LEN, end_x - out.position.x), out.size.y)
			else:
				var start_x := maxf(out.position.x, path.end.x + JETTY_PATH_GAP)
				if path.end.x <= out.end.x:
					var len2 := maxf(JETTY_MIN_LEN, out.end.x - start_x)
					out = Rect2(out.end.x - len2, out.position.y, len2, out.size.y)
	return out


static func is_clear(pos: Vector2, blocked: Array[Rect2], spots: Array[Vector2]) -> bool:
	for r in blocked:
		if r.has_point(pos):
			return false
	for s in spots:
		if pos.distance_to(s) < SPOT_RADIUS + CLEARANCE:
			return false
	return true


## GFX-054: how far flagstones reach beyond a street on a `paved` ground.
const PAVED_REACH := 80.0


## GFX-054: the areas of a `paved` map that get flagstones (the rest is packed earth), as Rect2 in sprite px
## (map px / `scale`): every path grown by PAVED_REACH plus the optional `map.plaza` [x, y, w, h].
## Empty for any other ground style or a map without paths: the whole ground is then paved as before.
static func paved_zones(map: Dictionary, scale: float = 1.0) -> Array:
	var zones: Array = []
	if str(map.get("ground_style", "grass")) != "paved" or map.get("paths", []).is_empty():
		return zones
	for r: Array in map.get("paths", []):
		zones.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(PAVED_REACH))
	var plaza: Variant = map.get("plaza", null)
	if plaza is Array and plaza.size() == 4:
		zones.append(Rect2(float(plaza[0]), float(plaza[1]), float(plaza[2]), float(plaza[3])))
	for i in zones.size():
		var z: Rect2 = zones[i]
		zones[i] = Rect2(z.position / scale, z.size / scale)
	return zones


## GFX-110: map.edge kinds and the props along the outer map edge.
const EDGE_KINDS: PackedStringArray = ["hedge", "treeline", "wall", "cliff", "reeds"]
const EDGE_INSIDE := 16.0  # how far a prop reaches into the map (never more than 24)
const EDGE_DEPTH := {"hedge": 14.0, "treeline": 30.0, "wall": 10.0, "cliff": 22.0, "reeds": 18.0}
const EDGE_PATH_GAP := 10.0


## GFX-110: props along the four outer map edges for a region with `map.edge`, [{kind, rect: Rect2, seed: int, side: int}].
## Each rect reaches at most EDGE_INSIDE px into the map and the rest out into the margin; none touches a path
## (grown by EDGE_PATH_GAP, so a wall has a gap at each road). Seeded by region id; empty without map.edge.
static func edge_props(region: Dictionary, size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	var kind := String(map.get("edge", ""))
	if not EDGE_KINDS.has(kind):
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|edge")
	var gaps: Array[Rect2] = []
	for r in map.get("paths", []):
		gaps.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(EDGE_PATH_GAP))
	var depth: float = EDGE_DEPTH[kind]
	var total := EDGE_INSIDE + depth
	for side in 4:
		var length := size.x if side < 2 else size.y
		var t := 0.0
		while t < length:
			var step := rng.randf_range(18.0, 34.0) if kind != "wall" else 40.0
			step = minf(step, length - t)
			var r: Rect2
			match side:
				0: r = Rect2(t, -depth, step, total)
				1: r = Rect2(t, size.y - EDGE_INSIDE, step, total)
				2: r = Rect2(-depth, t, total, step)
				_: r = Rect2(size.x - EDGE_INSIDE, t, total, step)
			t += step
			var blocked := false
			for g in gaps:
				if g.intersects(r):
					blocked = true
					break
			var seed_value := rng.randi()
			if not blocked and step >= 8.0:
				out.append({"kind": kind, "rect": r, "seed": seed_value, "side": side})
	return out


## GFX-109: map.relief keys and limits.
const RELIEF_KEYS: PackedStringArray = ["ledges", "snow", "boulders"]
const RELIEF_MAX := 12
const RELIEF_BORDER := 24.0
const RELIEF_PATH_GAP := 12.0
const RELIEF_PLACE_GAP := 16.0
const RELIEF_POINT_RADIUS := 60.0
const RELIEF_SPOT_RADIUS := 24.0
const RELIEF_TRIES := 30


## GFX-109: rock ledges, boulder clusters and snow drifts of a `map.relief` region, [{kind: "ledge"|"boulders"|"drift", rect: Rect2, seed: int}].
## Seeded from the region id only; clear of paths, places, landmarks, the spawn and travel points, npc spots and the map border; never overlapping. Empty without map.relief.
static func relief_layout(region: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	var relief: Variant = map.get("relief", null)
	if not relief is Dictionary:
		return out
	var size_arr: Array = map.get("size", [1600, 1000])
	var bounds := Rect2(Vector2.ZERO, Vector2(float(size_arr[0]), float(size_arr[1]))).grow(-RELIEF_BORDER)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|relief")
	var forbid: Array[Rect2] = []
	for r in map.get("paths", []):
		forbid.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(RELIEF_PATH_GAP))
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var pos: Array = p.get("pos", [0, 0])
		var sz: Array = p.get("size", [64, 64])
		var psize := Vector2(float(sz[0]), float(sz[1]))
		forbid.append(Rect2(Vector2(float(pos[0]), float(pos[1])) - psize / 2.0, psize).grow(RELIEF_PLACE_GAP))
	forbid.append_array(landmark_rects(region))
	var points: Array[Vector3] = []  # x, y, radius
	if region.has("spawn"):
		points.append(Vector3(float(region["spawn"][0]), float(region["spawn"][1]), RELIEF_POINT_RADIUS))
	for p: Dictionary in region.get("places", []):
		if String(p.get("type", "")) == "travel":
			points.append(Vector3(float(p["pos"][0]), float(p["pos"][1]), RELIEF_POINT_RADIUS))
	for s in region.get("npc_spots", []):
		points.append(Vector3(float(s[0]), float(s[1]), RELIEF_SPOT_RADIUS))
	var taken: Array[Rect2] = []
	var snow := clampf(float(relief.get("snow", 0.0)), 0.0, 1.0)
	var items: Array[Dictionary] = []
	for i in clampi(int(relief.get("ledges", 0)), 0, RELIEF_MAX):
		var r := Rect2(0, 0, rng.randf_range(60.0, 180.0), rng.randf_range(18.0, 36.0))
		var it := _relief_try(r, "ledge", rng, bounds, forbid, points, taken)
		if not it.is_empty():
			items.append(it)
	for i in clampi(int(relief.get("boulders", 0)), 0, RELIEF_MAX):
		var r := Rect2(0, 0, rng.randf_range(40.0, 70.0), rng.randf_range(40.0, 70.0))
		var it := _relief_try(r, "boulders", rng, bounds, forbid, points, taken)
		if not it.is_empty():
			items.append(it)
	out.append_array(items)
	for it in items:
		if rng.randf() >= snow:
			continue
		var base: Rect2 = it["rect"]
		var w := rng.randf_range(30.0, 90.0)
		var r := Rect2(base.position.x + rng.randf_range(0.0, maxf(base.size.x - w, 0.0)), base.end.y, w, rng.randf_range(10.0, 16.0))
		if not _relief_fits(r, bounds, forbid, points, taken):
			continue
		taken.append(r.grow(4.0))
		out.append({"kind": "drift", "rect": r, "seed": rng.randi()})
	return out


static func _relief_try(r: Rect2, kind: String, rng: RandomNumberGenerator, bounds: Rect2, forbid: Array[Rect2], points: Array[Vector3], taken: Array[Rect2]) -> Dictionary:
	for attempt in RELIEF_TRIES:
		var cand := Rect2(Vector2(rng.randf_range(bounds.position.x, bounds.end.x - r.size.x), rng.randf_range(bounds.position.y, bounds.end.y - r.size.y)).round(), r.size.round())
		if _relief_fits(cand, bounds, forbid, points, taken):
			# leave room below for a drift
			taken.append(cand.grow(4.0))
			taken.append(Rect2(cand.position.x, cand.end.y, cand.size.x, 20.0))
			return {"kind": kind, "rect": cand, "seed": rng.randi()}
	return {}


static func _relief_fits(r: Rect2, bounds: Rect2, forbid: Array[Rect2], points: Array[Vector3], taken: Array[Rect2]) -> bool:
	if not bounds.encloses(r):
		return false
	for f in forbid:
		if f.intersects(r):
			return false
	for p in points:
		var near := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if near.distance_to(Vector2(p.x, p.y)) < p.z:
			return false
	for t in taken:
		if t.intersects(r):
			return false
	return true


## Load errors for map.decor in data/regions.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		var plaza: Variant = region.get("map", {}).get("plaza", null)
		if plaza != null and not (plaza is Array and plaza.size() == 4 and plaza.all(func(v: Variant) -> bool: return v is float or v is int) and float(plaza[2]) > 0.0 and float(plaza[3]) > 0.0):
			errors.append("Region '%s' map.plaza must be [x, y, w, h] with w, h > 0" % region["id"])
		var density: Variant = region.get("map", {}).get("scree_density", 1.0)
		if not ((density is float or density is int) and float(density) >= 0.0 and float(density) <= 1.0):
			errors.append("Region '%s' map.scree_density must be 0-1" % region["id"])
		var relief: Variant = region.get("map", {}).get("relief", null)
		if relief != null:
			if not relief is Dictionary:
				errors.append("Region '%s' map.relief must be an object" % region["id"])
			else:
				for key in relief:
					if not RELIEF_KEYS.has(String(key)):
						errors.append("Region '%s' map.relief has unknown key '%s'" % [region["id"], key])
					elif key == "snow":
						if not ((relief[key] is float or relief[key] is int) and float(relief[key]) >= 0.0 and float(relief[key]) <= 1.0):
							errors.append("Region '%s' map.relief.snow must be 0-1" % region["id"])
					elif not (relief[key] is float or relief[key] is int) or int(relief[key]) < 0 or int(relief[key]) > RELIEF_MAX:
						errors.append("Region '%s' map.relief.%s must be 0-%d" % [region["id"], key, RELIEF_MAX])
		var edge: Variant = region.get("map", {}).get("edge", null)
		if edge != null and not (edge is String and EDGE_KINDS.has(edge)):
			errors.append("Region '%s' map.edge must be one of %s" % [region["id"], ", ".join(EDGE_KINDS)])
		var decor: Variant = region.get("map", {}).get("decor", {})
		if not decor is Dictionary:
			errors.append("Region '%s' map.decor must be an object" % region["id"])
			continue
		for key in decor:
			if key == "tree_kinds":
				errors.append_array(_validate_tree_kinds(region["id"], decor[key]))
			elif key == "blossoms":
				if not decor[key] is bool:
					errors.append("Region '%s' map.decor.blossoms must be true or false" % region["id"])
			elif key == "clusters":
				if not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_CLUSTERS:
					errors.append("Region '%s' map.decor.clusters must be 0-%d" % [region["id"], MAX_CLUSTERS])
			elif key == "edge_belt":
				if not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_EDGE_BELT:
					errors.append("Region '%s' map.decor.edge_belt must be 0-%d" % [region["id"], MAX_EDGE_BELT])
			elif key == "rock_clusters":
				if not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_ROCK_CLUSTERS:
					errors.append("Region '%s' map.decor.rock_clusters must be 0-%d" % [region["id"], MAX_ROCK_CLUSTERS])
			elif not DEFAULTS.has(key):
				errors.append("Region '%s' map.decor has unknown key '%s'" % [region["id"], key])
			elif String(key).ends_with("_color"):
				if not (decor[key] is String and Color.html_is_valid(decor[key])):
					errors.append("Region '%s' map.decor.%s is not a color" % [region["id"], key])
			elif not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_COUNT:
				errors.append("Region '%s' map.decor.%s must be 0-%d" % [region["id"], key, MAX_COUNT])
		var landmarks: Variant = region.get("map", {}).get("landmarks", [])
		if not landmarks is Array:
			errors.append("Region '%s' map.landmarks must be a list" % region["id"])
			continue
		for lm: Variant in landmarks:
			if not (lm is Dictionary and LANDMARK_KINDS.has(String(lm.get("kind", "")))):
				errors.append("Region '%s' has a landmark with an unknown kind (%s)" % [region["id"], ", ".join(LANDMARK_KINDS)])
			elif not (_is_pair(lm.get("pos")) and _is_pair(lm.get("size")) and float(lm["size"][0]) > 0.0 and float(lm["size"][1]) > 0.0):
				errors.append("Region '%s' landmark '%s' needs numeric pos and positive size [x, y]" % [region["id"], lm["kind"]])
			elif lm.has("tree_kind") and not (lm["kind"] == "pine" and TREE_KINDS.has(String(lm["tree_kind"]))):
				errors.append("Region '%s' landmark '%s' tree_kind must be one of (%s) and only goes on a pine" % [region["id"], lm["kind"], ", ".join(TREE_KINDS)])
			elif lm.has("color") and not (lm["color"] is String and Color.html_is_valid(lm["color"])):
				errors.append("Region '%s' landmark '%s' color is not a color" % [region["id"], lm["kind"]])
	return errors


static func _validate_tree_kinds(region_id: String, kinds: Variant) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not (kinds is Dictionary) or (kinds as Dictionary).is_empty():
		errors.append("Region '%s' map.decor.tree_kinds must be a non-empty object" % region_id)
		return errors
	for k: Variant in kinds:
		if not TREE_KINDS.has(String(k)):
			errors.append("Region '%s' map.decor.tree_kinds has unknown kind '%s' (%s)" % [region_id, k, ", ".join(TREE_KINDS)])
		elif not (kinds[k] is float or kinds[k] is int) or float(kinds[k]) <= 0.0:
			errors.append("Region '%s' map.decor.tree_kinds.%s weight must be > 0" % [region_id, k])
	return errors


static func _is_pair(v: Variant) -> bool:
	return v is Array and (v as Array).size() == 2 and (v as Array).all(func(n: Variant) -> bool: return n is float or n is int)


## How a tree looks in `season` (GFX-037, GFX-041): `canopy` colour, `bare` (no leaves), `snow` (white caps),
## `blossoms` and `leaves` (fallen) pixel counts. `kind` is a tree_kinds kind: only "round" blossoms (and only when
## `blossoms_ok`), pine and bamboo stay green, willow yellows in autumn and bares in winter, dead is always bare.
## Pure: the same (season, seed, base, kind) always gives the same look.
static func tree_look(season: String, seed_value: int, base: Color = Color("2e5a2a"), kind: String = "round", blossoms_ok: bool = true) -> Dictionary:
	var h := absi(seed_value * 2654435761) % 1000
	match kind:
		"dead":
			return {"canopy": Color("8a7f6a"), "bare": true, "snow": season == "Winter", "blossoms": 0, "leaves": 0}
		"pine", "bamboo":
			var evergreen := base.lightened(0.12) if season == "Spring" else base
			return {"canopy": evergreen, "bare": false, "snow": season == "Winter", "blossoms": 0, "leaves": 0}
		"willow":
			match season:
				"Autumn":
					return {"canopy": Color("c9b04a"), "bare": false, "snow": false, "blossoms": 0, "leaves": 4 + h % 4}
				"Winter":
					return {"canopy": Color("6b5a48"), "bare": true, "snow": true, "blossoms": 0, "leaves": 0}
				"Spring":
					return {"canopy": base.lightened(0.12), "bare": false, "snow": false, "blossoms": 0, "leaves": 0}
			return {"canopy": base, "bare": false, "snow": false, "blossoms": 0, "leaves": 0}
	match season:
		"Spring":
			return {"canopy": base.lightened(0.12), "bare": false, "snow": false, "blossoms": (5 + h % 4) if blossoms_ok else 0, "leaves": 0}
		"Autumn":
			return {"canopy": Color(AUTUMN_TONES[h % AUTUMN_TONES.size()]), "bare": false, "snow": false, "blossoms": 0, "leaves": 4 + h % 4}
		"Winter":
			return {"canopy": Color("6b5a48"), "bare": true, "snow": true, "blossoms": 0, "leaves": 0}
	return {"canopy": base, "bare": false, "snow": false, "blossoms": 0, "leaves": 0}


## Crop-row colour of the big field in `season` (alpha 0 in winter: bare furrows).
static func crop_color(season: String) -> Color:
	return Color(String(CROP_COLORS.get(season, "4f9a3a")))


## GFX-096: how a field landmark looks in `season`. `seed_value` (the field's position hash) varies neighbours:
## `vertical` rows run north-south, `alt` swaps the crop tone. Returns {style, color, vertical, sheaves, snow}.
## style: sprout (spring), tall (summer), golden (autumn), bare (winter).
static func field_look(season: String, seed_value: int, no_snow: bool = false) -> Dictionary:
	var h := absi(seed_value)
	var style := "tall"
	var color := Color("3f8a30")
	match season:
		"Spring":
			style = "sprout"
			color = Color("8fd16a")
		"Autumn":
			style = "golden"
			color = Color("d9aa3a")
		"Winter":
			style = "bare"
			color = Color("00000000")
	if h % 3 == 0 and style != "bare":
		color = color.darkened(0.12)
	return {"style": style, "color": color, "vertical": h % 4 == 1, "sheaves": style == "golden",
		"snow": style == "bare" and not no_snow}


## GFX-043: the newest footprint list: `prints` plus `pos`, oldest dropped beyond `cap` (default 12).
static func add_footprint(prints: Array, pos: Vector2, cap: int = 12) -> Array:
	var out := prints.duplicate()
	out.append(pos)
	while out.size() > cap:
		out.remove_at(0)
	return out


## True when roofs, pines and ponds carry snow or ice.
static func is_snowy(season: String) -> bool:
	return season == "Winter"
