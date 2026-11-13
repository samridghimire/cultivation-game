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
	var sq: Variant = region.get("map", {}).get("square", null)
	if sq is Array and sq.size() == 4:  # GFX-131: nothing grows in the village square
		out.append(Rect2(float(sq[0]), float(sq[1]), float(sq[2]), float(sq[3])))
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


## WU-502: how the Village Herb Slope looks at terrace project `stage` (0..3; -1 = no project): stone `edging` round the bed, stepped
## `rows` of terrace (0, 0, 2, 3), tidy `herbs` lines on the rows and a small water `channel` down one side (finished only).
static func terrace_look(stage: int) -> Dictionary:
	match clampi(stage, 0, 3) if stage >= 0 else 0:
		1:
			return {"edging": true, "rows": 0, "herbs": false, "channel": false}
		2:
			return {"edging": true, "rows": 2, "herbs": false, "channel": false}
		3:
			return {"edging": true, "rows": 3, "herbs": true, "channel": true}
	return {"edging": false, "rows": 0, "herbs": false, "channel": false}


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
## GFX-116: the shore end of a jetty stands this far outside the rim; the planks run from there out over the water toward the pond centre.
const JETTY_SHORE := 4.0


## GFX-120: where the planks meet dry land (the end a fisher stands at), from a jetty_layout result.
static func jetty_land_end(lay: Dictionary) -> Vector2:
	var r: Rect2 = lay["rect"]
	if not bool(lay["on_water"]):
		return r.get_center()
	var toward: int = int(lay["toward_water"])
	if bool(lay["vertical"]):
		return Vector2(r.get_center().x, r.end.y if toward == -1 else r.position.y)
	return Vector2(r.end.x if toward == -1 else r.position.x, r.get_center().y)


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
		long_side = minf(long_side, maxf(JETTY_MIN_LEN, half.y * t * 1.5))  # GFX-116: the water end stays inside a shallow pond
		if delta.y >= 0.0:
			var rim := c.y + half.y * t
			rect = Rect2(x - short_side / 2.0, rim + JETTY_SHORE - long_side, short_side, long_side)
		else:
			var rim2 := c.y - half.y * t
			rect = Rect2(x - short_side / 2.0, rim2 - JETTY_SHORE, short_side, long_side)
	else:
		var y := clampf(pos.y, c.y - half.y * 0.8, c.y + half.y * 0.8)
		var t2 := sqrt(maxf(0.0, 1.0 - pow((y - c.y) / half.y, 2.0)))
		long_side = minf(long_side, maxf(JETTY_MIN_LEN, half.x * t2 * 1.5))
		if delta.x >= 0.0:
			var rim3 := c.x + half.x * t2
			rect = Rect2(rim3 + JETTY_SHORE - long_side, y - short_side / 2.0, long_side, short_side)
		else:
			var rim4 := c.x - half.x * t2
			rect = Rect2(rim4 - JETTY_SHORE, y - short_side / 2.0, long_side, short_side)
	var toward := -1 if (vertical and delta.y >= 0.0) or (not vertical and delta.x >= 0.0) else 1
	var clipped := _clip_to_paths(region, rect, vertical, toward)
	if clipped.size.x > 0.0:
		rect = clipped
	return {"rect": rect, "vertical": vertical, "on_water": true, "toward_water": toward}


## GFX-114: where the ice hole of a frozen pond goes: past the water end (clear of the place label) of the jetty `lm`, pulled toward the
## pond centre until it lies inside the pond ellipse. Returns Vector2.INF when `lm` has no pond.
static func ice_hole_point(region: Dictionary, lm: Dictionary) -> Vector2:
	var lay := jetty_layout(region, lm)
	if not bool(lay.get("on_water", false)):
		return Vector2.INF
	var r: Rect2 = lay["rect"]
	var toward: int = int(lay["toward_water"])
	var vertical := bool(lay["vertical"])
	var tip: Vector2
	if vertical:
		tip = Vector2(r.get_center().x, r.position.y - 34.0 if toward < 0 else r.end.y + 34.0)
	else:
		tip = Vector2(r.position.x - 34.0 if toward < 0 else r.end.x + 34.0, r.get_center().y)
	var pond := Rect2()
	var best := INF
	for other: Dictionary in region.get("map", {}).get("landmarks", []):
		if other.get("kind", "") != "pond":
			continue
		var pc := Vector2(float(other["pos"][0]), float(other["pos"][1]))
		var d := tip.distance_to(pc)
		if d < best:
			best = d
			pond = Rect2(pc - Vector2(float(other["size"][0]), float(other["size"][1])) / 2.0, Vector2(float(other["size"][0]), float(other["size"][1])))
	if best == INF:
		return Vector2.INF
	var c := pond.get_center()
	var half := pond.size / 2.0
	for i in 12:
		var q := (tip - c) / (half * 0.8)
		if q.length() <= 1.0:
			return tip
		tip = tip.lerp(c, 0.2)
	return c


## GFX-114: "foot" (a flat ellipse at the trunk) under every tree in winter and under bare trees; else "round".
static func tree_shadow(season: String, bare: bool) -> String:
	return "foot" if bare or season == "Winter" else "round"


## GFX-117: the ground shadow ellipse under a person's feet, relative to the feet point (`size` = the figure's footprint).
static func figure_shadow(size: Vector2, snowy: bool) -> Rect2:
	var w := clampf(size.x * 0.75, 14.0, 40.0) * (1.1 if snowy else 1.0)
	var h := w * 0.32
	return Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h))


## GFX-117: soft dark, or snow-blue on snowy ground (matches GFX-114's tree shadows).
static func figure_shadow_color(snowy: bool) -> Color:
	return Color(0.2, 0.3, 0.5, 0.3) if snowy else Color(0, 0, 0, 0.3)


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
				var prop := {"kind": kind, "rect": r, "seed": seed_value, "side": side}
				if kind == "cliff":
					prop["h"] = 0.65 + 0.35 * float(seed_value % 100) / 100.0  # GFX-111: per-prop height (fraction of the rect's depth)
				out.append(prop)
	return out


## GFX-111: a rock silhouette for `rect`: [bottom-left, jagged top points..., bottom-right], deterministic from `seed`.
## The top points run left to right across the rect, each lifted 0..`jitter` px below the top edge; every point lies inside rect.grow(jitter).
static func jagged_outline(rect: Rect2, seed: int, points: int, jitter: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := maxi(points, 4) - 2
	out.append(Vector2(rect.position.x, rect.end.y))
	for i in n:
		var x := rect.position.x + rect.size.x * float(i) / float(n - 1)
		out.append(Vector2(x, rect.position.y + rng.randf() * jitter))
	out.append(Vector2(rect.end.x, rect.end.y))
	return out


## GFX-133: a closed, ragged outline for a ground fill: a rounded rect (corner `radius`) whose edge is pushed in or out
## along its normal by smoothed seeded noise of up to `amp` px, sampled every 8 px. Never an axis-aligned rectangle; same seed, same shape.
static func ragged_outline(rect: Rect2, seed: int, radius: float, amp: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rad := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts: Array[Vector2] = []
	var nrm: Array[Vector2] = []
	var inner := rect.grow(-rad)
	var corners := [[Vector2(inner.end.x, inner.position.y), -PI / 2.0], [Vector2(inner.end.x, inner.end.y), 0.0], [Vector2(inner.position.x, inner.end.y), PI / 2.0], [Vector2(inner.position.x, inner.position.y), PI]]
	for ci in 4:
		var c: Vector2 = corners[ci][0]
		var a0: float = corners[ci][1]
		for k in 5:
			var a := a0 + (PI / 2.0) * float(k) / 4.0
			var d := Vector2(cos(a), sin(a))
			pts.append(c + d * rad)
			nrm.append(d)
		# straight edge to the next corner
		var nc: Vector2 = corners[(ci + 1) % 4][0]
		var dir := Vector2(cos(a0 + PI / 2.0), sin(a0 + PI / 2.0))
		var edge_from := c + dir * rad
		var edge_to := nc + Vector2(cos(a0 + PI / 2.0), sin(a0 + PI / 2.0)) * 0.0
		edge_to = nc + Vector2(cos(corners[(ci + 1) % 4][1]), sin(corners[(ci + 1) % 4][1])) * rad
		var len := edge_from.distance_to(edge_to)
		var steps := int(len / 8.0)
		for k in range(1, steps):
			pts.append(edge_from.lerp(edge_to, float(k) / float(steps)))
			nrm.append(dir)
	var n := pts.size()
	var raw: Array[float] = []
	for i in n:
		raw.append(rng.randf_range(-1.0, 1.0))
	var out := PackedVector2Array()
	for i in n:
		var off := (raw[(i + n - 1) % n] + raw[i] * 2.0 + raw[(i + 1) % n]) / 4.0 * amp * 1.6
		out.append(pts[i] + nrm[i] * clampf(off, -amp, amp))
	return out


## GFX-122: a paving slab's colour: a gentle +-8% of `base` (never below 0.92x), and now and then (1 slab in 8) a lighter
## worn slab instead of a dark one. Deterministic from `seed`.
static func paving_shade(base: Color, seed: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if rng.randi() % 8 == 0:
		return base.lightened(0.05 + rng.randf() * 0.05)
	var f := rng.randf_range(-0.08, 0.08)
	return base.lightened(f) if f >= 0.0 else base.darkened(-f)


## GFX-112: the road surface pieces laid over a path rect, seeded by region id and rect. Each is
## {kind: slab|plank|rut|edge|puddle|tuft, rect: Rect2, shade: -1..1, flag: crack|gap|""}. Style: scree/paved = irregular
## slabs; bog with map.water murky = planks across the path; other bog = a muddy track with puddles; grass/litter = two
## worn ruts, a dark edge strip on each side and tufts creeping in. Every rect lies inside `path_rect`; none overlaps a stream crossing (a bridge).
static func path_tiles(region: Dictionary, path_rect: Rect2, weather: String = "clear", winter: bool = false) -> Array[Dictionary]:
	var map: Dictionary = region.get("map", {})
	var style := str(map.get("ground_style", "grass"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|roadtiles" % [region.get("id", ""), path_rect])
	var along_x := path_rect.size.x >= path_rect.size.y
	var bridges: Array[Rect2] = []
	for lm: Dictionary in map.get("landmarks", []):
		if str(lm.get("kind", "")) == "stream":
			var sz: Array = lm["size"]
			var c: Array = lm["pos"]
			bridges.append(Rect2(float(c[0]) - float(sz[0]) * 0.5, float(c[1]) - float(sz[1]) * 0.5, float(sz[0]), float(sz[1])).grow(6.0))
	var out: Array[Dictionary] = []
	var len_total := path_rect.size.x if along_x else path_rect.size.y
	var width := path_rect.size.y if along_x else path_rect.size.x
	var inset := 3.0
	var pos := 0.0
	if style == "scree" or style == "paved":
		var main_street := map.has("market")  # GFX-126: larger worn slabs between a dark gutter on each edge
		var gutter := 3.0 if main_street else 0.0
		var rows := maxi(int(floor((width - inset * 2.0 - gutter * 2.0) / (20.0 if main_street else 14.0))), 1)
		var row_w := (width - inset * 2.0 - gutter * 2.0) / float(rows)
		if main_street:
			for side in 2:
				out.append({"kind": "edge", "rect": _road_rect(path_rect, along_x, 0.0, 0.0 if side == 0 else width - gutter, len_total, gutter), "shade": 0.0, "flag": "gutter"})
		for row in rows:
			pos = inset
			var first := true
			while pos < len_total - inset - 6.0:
				var l := minf((18.0 + rng.randf() * 22.0) if main_street else (10.0 + rng.randf() * 16.0), len_total - inset - pos)
				if main_street and first and row % 2 == 1:
					l = minf(l * 0.5, len_total - inset - pos)  # GFX-131: odd rows start half a slab later, so slab joints never line up
				first = false
				var roll := rng.randf()
				var flag := "crack" if roll < 0.12 else ("gap" if roll < 0.2 else "")
				if main_street and flag == "":
					flag = "main"
				out.append({"kind": "slab", "rect": _road_rect(path_rect, along_x, pos, inset + gutter + row * row_w, l, row_w), "shade": rng.randf() * 2.0 - 1.0, "flag": flag})
				pos += l
	elif style == "bog" and str(map.get("water", "clear")) == "murky":
		pos = inset
		while pos < len_total - inset - 4.0:
			var l := minf(7.0 + rng.randf() * 3.0, len_total - inset - pos)
			out.append({"kind": "plank", "rect": _road_rect(path_rect, along_x, pos, inset, l - 1.0, width - inset * 2.0), "shade": rng.randf() * 2.0 - 1.0, "flag": ""})
			pos += l
	else:
		var strip := 3.0
		# GFX-131: roads that wander: broken edge strips, wobbling ruts, no ruts near a crossing.
		var crossings: Array[Rect2] = []
		for pr: Variant in map.get("paths", []):
			var pa: Array = pr
			var other := Rect2(float(pa[0]), float(pa[1]), float(pa[2]), float(pa[3]))
			if other != path_rect and other.grow(40.0).intersects(path_rect):
				crossings.append(other.grow(40.0))
		for side in 2:
			pos = rng.randf() * 8.0
			while pos < len_total:
				var l := minf(rng.randf_range(10.0, 28.0), len_total - pos)
				var th := rng.randf_range(2.0, 4.0)
				var base_off := inset if side == 0 else width - inset - th
				var shift := float(rng.randi_range(0, 2)) * (1.0 if side == 0 else -1.0)
				out.append({"kind": "edge", "rect": _road_rect(path_rect, along_x, pos, base_off + shift, l, th), "shade": -0.5, "flag": ""})
				var gap := rng.randf_range(0.0, 8.0)
				if gap > 4.0 and rng.randf() < 0.5:
					var gx := pos + l + gap * 0.5
					if gx < len_total - 3.0:
						out.append({"kind": "tuft", "rect": _road_rect(path_rect, along_x, gx, base_off + shift + (1.0 if side == 0 else -1.0), 3.0, 4.0), "shade": rng.randf() * 2.0 - 1.0, "flag": ""})
				pos += l + gap
		for off_f: float in [0.3, 0.62]:
			pos = rng.randf() * 10.0
			var wob := 0.0
			while pos < len_total:
				var l := minf(rng.randf_range(14.0, 36.0), len_total - pos)
				wob = clampf(wob + float(rng.randi_range(-2, 2)), -3.0, 3.0)
				var rr := _road_rect(path_rect, along_x, pos, width * off_f - 2.0 + wob, l, 4.0)
				var near := false
				for c in crossings:
					if c.intersects(rr):
						near = true
						break
				if not near:
					out.append({"kind": "rut", "rect": rr, "shade": -0.3, "flag": ""})
				pos += l + rng.randf_range(4.0, 12.0)
		var n := int(len_total / 22.0)
		for i in n:
			var k := "puddle" if style == "bog" else "tuft"
			var sz := Vector2(10.0, 4.0) if k == "puddle" else Vector2(3.0, 5.0)
			var across := rng.randf_range(0.0, maxf(width - sz.y, 0.0)) if k == "puddle" else (inset if rng.randf() < 0.5 else width - inset - sz.y)
			if k == "tuft" and rng.randf() < 0.4:
				continue
			out.append({"kind": k, "rect": _road_rect(path_rect, along_x, rng.randf() * maxf(len_total - sz.x, 0.0), across, sz.x, sz.y), "shade": rng.randf() * 2.0 - 1.0, "flag": ""})
		# GFX-124: walked earth: pebbles and footprints, and sky-coloured puddles on wet days (never in snow).
		var wet := weather in ["rain", "storm"] and not winter
		for i in int(len_total / 30.0):
			var k2 := "pebble" if rng.randf() < 0.6 else "print"
			var sz2 := Vector2(2.0, 2.0) if k2 == "pebble" else Vector2(3.0, 2.0)
			out.append({"kind": k2, "rect": _road_rect(path_rect, along_x, rng.randf() * maxf(len_total - sz2.x, 0.0), rng.randf_range(inset + strip, maxf(width - inset - strip - sz2.y, inset + strip)), sz2.x, sz2.y), "shade": rng.randf() * 2.0 - 1.0, "flag": ""})
		if wet and style != "bog":
			for i in int(len_total / 120.0) + 1:
				out.append({"kind": "puddle", "rect": _road_rect(path_rect, along_x, rng.randf() * maxf(len_total - 12.0, 0.0), rng.randf_range(inset + strip, maxf(width - inset - strip - 5.0, inset + strip)), 12.0, 5.0), "shade": 0.0, "flag": "sky"})
	var kept: Array[Dictionary] = []
	for t in out:
		var hit := false
		for b in bridges:
			if b.intersects(t["rect"]):
				hit = true
				break
		if not hit and str(t["kind"]) in ["pebble", "print", "puddle", "tuft"]:
			for pl: Dictionary in region.get("places", []):
				if Npcs.place_keepout(pl).intersects(t["rect"]):
					hit = true
					break
		if not hit and winter and t["kind"] == "rut":  # GFX-124: snow covers the ruts except a trodden centre
			var tr: Rect2 = t["rect"]
			var mid := path_rect.get_center()
			var centre := absf((tr.get_center().y - mid.y) if along_x else (tr.get_center().x - mid.x)) < width * 0.2
			hit = not centre
		if not hit:
			kept.append(t)
	return kept


static func _road_rect(path_rect: Rect2, along_x: bool, along: float, across: float, length: float, thick: float) -> Rect2:
	if along_x:
		return Rect2(path_rect.position.x + along, path_rect.position.y + across, length, thick)
	return Rect2(path_rect.position.x + across, path_rect.position.y + along, thick, length)


## GFX-113: map.high (a sect on a mountain): rail (bool: a carved rail round the sect hall court), wisps (int 0-8 drifting cloud wisps)
## lean_pines (int 0-8 pines leaning out over the top cliffs), crags (GFX-123, int 0-8 rock outcrops) and drifts (int 0-12 snow drift patches).
const HIGH_KEYS: PackedStringArray = ["rail", "wisps", "lean_pines", "crags", "drifts"]
const HIGH_CRAG_MAX := 8
const HIGH_DRIFT_MAX := 12
const HIGH_PINE_MAX := 8
const HIGH_WISP_MAX := 8


## GFX-113: leaning pines for a `map.high` region: [{pos: Vector2 (the trunk's foot), lean: float (-1 left .. 1 right)}].
## They stand on the lower lip of the top-half `cliff` landmarks, seeded by region id, clear of places, solid landmarks and paths.
static func high_pines(region: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var high: Variant = region.get("map", {}).get("high", null)
	if not high is Dictionary:
		return out
	var want := clampi(int(high.get("lean_pines", 0)), 0, HIGH_PINE_MAX)
	if want == 0:
		return out
	var map_h := float(region["map"]["size"][1])
	var cliffs: Array[Rect2] = []
	for lm: Dictionary in region["map"].get("landmarks", []):
		if String(lm.get("kind", "")) == "cliff" and float(lm["pos"][1]) < map_h / 2.0:
			cliffs.append(Rect2(Vector2(float(lm["pos"][0]) - float(lm["size"][0]) / 2.0, float(lm["pos"][1]) - float(lm["size"][1]) / 2.0), Vector2(float(lm["size"][0]), float(lm["size"][1]))))
	if cliffs.is_empty():
		return out
	var blocked := blocked_rects(region)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|high_pines")
	for i in want * 12:
		if out.size() >= want:
			break
		var c := cliffs[i % cliffs.size()]
		var foot := Vector2(rng.randf_range(c.position.x + 40.0, c.end.x - 40.0), c.end.y + rng.randf_range(34.0, 52.0))
		var box := Rect2(foot - Vector2(26.0, 8.0), Vector2(52.0, 16.0))
		var ok := true
		for b in blocked:
			if b.intersects(box):
				ok = false
				break
		for o in out:
			if absf(o["pos"].x - foot.x) < 90.0:
				ok = false
		if ok:
			# Lean away from the cliff-top's centre, toward the cliff edge (up on the map).
			out.append({"pos": foot, "lean": -1.0 if foot.x < float(region["map"]["size"][0]) / 2.0 else 1.0})
	return out


## GFX-123: crags (rock outcrops with a lit top face and a dark cliff face, 60-140 px wide) and drifts (wind-streaked snow patches)
## of a `map.high` region: [{kind: "crag"|"drift", rect: Rect2, seed: int}]. Seeded from the region id; clear of places, paths,
## solid landmarks, the spawn, travel points, npc spots, the map border and map.relief items; never overlapping.
static func high_crags(region: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	var high: Variant = map.get("high", null)
	if not high is Dictionary:
		return out
	var crags := clampi(int(high.get("crags", 0)), 0, HIGH_CRAG_MAX)
	var drifts := clampi(int(high.get("drifts", 0)), 0, HIGH_DRIFT_MAX)
	if crags + drifts == 0:
		return out
	var size_arr: Array = map.get("size", [1600, 1000])
	var bounds := Rect2(Vector2.ZERO, Vector2(float(size_arr[0]), float(size_arr[1]))).grow(-RELIEF_BORDER)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|high_crags")
	var forbid: Array[Rect2] = []
	for r in map.get("paths", []):
		forbid.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow(RELIEF_PATH_GAP))
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var pos: Array = p.get("pos", [0, 0])
		var sz: Array = p.get("size", [64, 64])
		var psize := Vector2(float(sz[0]), float(sz[1]))
		forbid.append(Rect2(Vector2(float(pos[0]), float(pos[1])) - psize / 2.0, psize).grow(RELIEF_PLACE_GAP))
	forbid.append_array(landmark_rects(region))
	var points: Array[Vector3] = []
	if region.has("spawn"):
		points.append(Vector3(float(region["spawn"][0]), float(region["spawn"][1]), RELIEF_POINT_RADIUS))
	for p: Dictionary in region.get("places", []):
		if String(p.get("type", "")) == "travel":
			points.append(Vector3(float(p["pos"][0]), float(p["pos"][1]), RELIEF_POINT_RADIUS))
	for s in region.get("npc_spots", []):
		points.append(Vector3(float(s[0]), float(s[1]), RELIEF_SPOT_RADIUS))
	var taken: Array[Rect2] = []
	for it: Dictionary in relief_layout(region):
		taken.append((it["rect"] as Rect2).grow(8.0))
	for i in crags:
		var r := Rect2(0, 0, rng.randf_range(60.0, 140.0), rng.randf_range(38.0, 64.0))
		var it := _relief_try(r, "crag", rng, bounds, forbid, points, taken)
		if not it.is_empty():
			out.append(it)
	for i in drifts:
		var r := Rect2(0, 0, rng.randf_range(50.0, 120.0), rng.randf_range(14.0, 26.0))
		var it := _relief_try(r, "drift", rng, bounds, forbid, points, taken)
		if not it.is_empty():
			out.append(it)
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
		if region.get("map", {}).has("yards") and not region["map"]["yards"] is bool:
			errors.append("Region '%s' map.yards must be a bool" % region["id"])
		var plaza: Variant = region.get("map", {}).get("plaza", null)
		if plaza != null and not (plaza is Array and plaza.size() == 4 and plaza.all(func(v: Variant) -> bool: return v is float or v is int) and float(plaza[2]) > 0.0 and float(plaza[3]) > 0.0):
			errors.append("Region '%s' map.plaza must be [x, y, w, h] with w, h > 0" % region["id"])
		var square: Variant = region.get("map", {}).get("square", null)
		if square != null and not (square is Array and square.size() == 4 and square.all(func(v: Variant) -> bool: return v is float or v is int) and float(square[2]) > 0.0 and float(square[3]) > 0.0):
			errors.append("Region '%s' map.square must be [x, y, w, h] with w, h > 0" % region["id"])
		var high: Variant = region.get("map", {}).get("high", null)
		if high != null:
			if not high is Dictionary:
				errors.append("Region '%s' map.high must be an object" % region["id"])
			else:
				for key in high:
					if not key in HIGH_KEYS:
						errors.append("Region '%s' map.high has unknown key '%s'" % [region["id"], key])
					elif key == "rail":
						if not high[key] is bool:
							errors.append("Region '%s' map.high.rail must be a bool" % region["id"])
					else:
						var cap := HIGH_PINE_MAX
						match key:
							"wisps":
								cap = HIGH_WISP_MAX
							"crags":
								cap = HIGH_CRAG_MAX
							"drifts":
								cap = HIGH_DRIFT_MAX
						if not (high[key] is float or high[key] is int) or int(high[key]) < 0 or int(high[key]) > cap:
							errors.append("Region '%s' map.high.%s must be 0-%d" % [region["id"], key, cap])
		errors.append_array(MarketLayout.validate(region))
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


## GFX-128: how a decorative ground flower looks by season: {kind: "flower" | "glint", color: Color}. Spring and Summer keep the
## region's flower colour; Autumn turns the blooms to orange and brown seed heads; Winter has no blooms, only a pale blue frost glint.
static func flower_look(season: String, base: Color, seed_value: int) -> Dictionary:
	match season:
		"Winter":
			return {"kind": "glint", "color": Color("bcd8f2")}
		"Autumn":
			return {"kind": "flower", "color": Color("c8742e") if seed_value % 2 == 0 else Color("8a5a32")}
	return {"kind": "flower", "color": base}


## GFX-128: a herb planter box by season: {rim: Color, fill: Color, stalks: bool (dark dead stalks poke through the snow)}.
static func planter_look(season: String) -> Dictionary:
	if is_snowy(season):
		return {"rim": Color("8a6a40"), "fill": Color(0.9, 0.93, 1.0), "stalks": true}
	return {"rim": Color("7a5a38"), "fill": Color("3e2f1e"), "stalks": false}


## GFX-115: seeded decoration for ponds and streams. Returns dictionaries {kind, pos: Vector2, rect: Rect2 (the water
## it belongs to)}: kind "glint" (3-6 per pond, drift in WaterLife), "pad" (lily pads on clear ponds in Spring/Summer),
## "reed" (tufts at the rim of murky ponds, any season) and "pebble" (beside a path bridge on streams). Every glint, pad
## and reed lies inside its pond's rect and none under a jetty or bridge. Frozen water (Winter, unless no_snow) gets none.
static func water_decor(region: Dictionary, season: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	if is_snowy(season) and not bool(map.get("no_snow", false)):
		return out
	var water: String = String(map.get("water", "clear"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("water_decor:" + str(region.get("id", "")))
	var blocked: Array[Rect2] = []
	for lm: Dictionary in map.get("landmarks", []):
		if String(lm.get("kind", "")) == "jetty":
			blocked.append((jetty_layout(region, lm)["rect"] as Rect2).grow(3.0))
	var paths: Array[Rect2] = []
	for pr: Array in map.get("paths", []):
		paths.append(Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3])))
	for lm: Dictionary in map.get("landmarks", []):
		var kind := String(lm.get("kind", ""))
		if kind != "pond" and kind != "stream":
			continue
		var size := Vector2(float(lm["size"][0]), float(lm["size"][1]))
		var rect := Rect2(Vector2(float(lm["pos"][0]), float(lm["pos"][1])) - size / 2.0, size)
		if kind == "stream":
			for p in paths:
				if p.intersects(rect):
					var cross := p.intersection(rect)
					var horiz := p.size.x >= p.size.y
					for k in 4:
						var off := Vector2(-14.0 if k % 2 == 0 else 14.0, 0.0) if not horiz else Vector2(0.0, -14.0 if k % 2 == 0 else 14.0)
						var spot := cross.get_center() + off + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
						if rect.grow(4.0).has_point(spot) and not _under_any(spot, paths):
							out.append({"kind": "pebble", "pos": spot, "rect": rect})
			continue
		var inner := rect.grow(-maxf(6.0, minf(rect.size.x, rect.size.y) * 0.12))
		for k in rng.randi_range(3, 6):
			_add_water_spot(out, "glint", inner, rect, blocked, rng)
		if water == "clear" and (season == "Spring" or season == "Summer"):
			for k in 2 + int(rect.size.x) / 90:
				_add_water_spot(out, "pad", inner, rect, blocked, rng)
		elif water == "murky":
			for k in 3 + int(rect.size.x) / 80:
				var a := rng.randf() * TAU
				var spot := rect.get_center() + Vector2(cos(a) * rect.size.x * 0.4, sin(a) * rect.size.y * 0.4)
				if rect.has_point(spot) and not _under_any(spot, blocked):
					out.append({"kind": "reed", "pos": spot, "rect": rect})
	return out


static func _add_water_spot(out: Array[Dictionary], kind: String, inner: Rect2, rect: Rect2, blocked: Array[Rect2], rng: RandomNumberGenerator) -> void:
	for attempt in 6:
		var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
		var d := (p - rect.get_center()) / (rect.size / 2.0)
		if d.length() < 0.8 and not _under_any(p, blocked):
			out.append({"kind": kind, "pos": p, "rect": rect})
			return


static func _under_any(p: Vector2, rects: Array[Rect2]) -> bool:
	for r in rects:
		if r.grow(2.0).has_point(p):
			return true
	return false


## GFX-125: shallow pools, reed clumps and lily pads of a bog region's ground. Pure and seeded: the same seed and size
## give the same output, and no pool or clump touches a keepout rect (roads, places, landmarks, arrival ring).
## Returns {"pools": [{"pts": PackedVector2Array, "center": Vector2, "rect": Rect2, "lilies": Array[Dictionary]}],
## "reeds": [{"pos": Vector2, "stalks": [{"dx": float, "h": float}]}]}.
static func marsh_features(region_seed: int, size: Vector2, keepouts: Array[Rect2]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = region_seed
	var pools: Array[Dictionary] = []
	var taken: Array[Rect2] = []
	var tries := 0
	var want := rng.randi_range(6, 10)
	while pools.size() < want and tries < 400:
		tries += 1
		var rx := rng.randf_range(26.0, 62.0)
		var ry := rx * rng.randf_range(0.4, 0.65)
		var c := Vector2(rng.randf_range(rx + 40.0, size.x - rx - 40.0), rng.randf_range(ry + 40.0, size.y - ry - 40.0))
		var rect := Rect2(c - Vector2(rx, ry) * 1.2, Vector2(rx, ry) * 2.4)
		if _marsh_hits(rect, keepouts, taken, 14.0):
			continue
		var pts := PackedVector2Array()
		var n := 14
		for i in n:
			var a := TAU * float(i) / float(n)
			var j := rng.randf_range(0.78, 1.18)
			pts.append(c + Vector2(cos(a) * rx * j, sin(a) * ry * j))
		var lilies: Array[Dictionary] = []
		if pools.size() < 3:
			lilies = pond_lilies(Rect2(c - Vector2(rx, ry) * 0.8, Vector2(rx, ry) * 1.6), rng.randi(), 3)
		pools.append({"pts": pts, "center": c, "rect": rect, "lilies": lilies})
		taken.append(rect)
	var reeds: Array[Dictionary] = []
	var clump_rects: Array[Rect2] = []
	for pool: Dictionary in pools:
		for k in 2:
			var a := rng.randf() * TAU
			var r: Rect2 = pool["rect"]
			var at: Vector2 = pool["center"] + Vector2(cos(a) * r.size.x * 0.46, sin(a) * r.size.y * 0.46)
			_marsh_add_reeds(reeds, clump_rects, at, rng, keepouts, taken, size)
	for i in 14:
		var at := Vector2(rng.randf_range(40.0, size.x - 40.0), rng.randf_range(40.0, size.y - 40.0))
		_marsh_add_reeds(reeds, clump_rects, at, rng, keepouts, taken, size)
	return {"pools": pools, "reeds": reeds}

## GFX-135: smoothed seeded radius factor (1.0 +/- amp) of a ragged shoreline at `angle` (radians): 12 control points round the
## circle, cosine-interpolated. Same seed, same shape; different seeds differ.
static func pond_mask_radius(angle: float, seed: int, amp: float) -> float:
	var n := 12
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts: Array[float] = []
	for i in n:
		pts.append(rng.randf_range(-1.0, 1.0))
	var t := fposmod(angle, TAU) / TAU * float(n)
	var i0 := int(t) % n
	var f := t - floorf(t)
	var k := (1.0 - cos(f * PI)) * 0.5
	return 1.0 + amp * lerpf(pts[i0], pts[(i0 + 1) % n], k)


## GFX-135: how far out the pond's outer (bank) edge reaches along `angle`, as a fraction of the landmark ellipse: 0.88 .. 1.0.
static func pond_edge(angle: float, seed: int) -> float:
	var amp := 0.12
	return 0.88 + 0.12 * (pond_mask_radius(angle, seed, amp) - (1.0 - amp)) / (2.0 * amp)


## GFX-135: width of the bank band (px) between the water and the outer edge of a pond.
const POND_BANK := 3.0


## GFX-135: true if world point `p` is on open water of the pond landmark `lm` (inside the ragged mask minus the bank band).
static func pond_water_contains(lm: Dictionary, p: Vector2) -> bool:
	var c := Vector2(float(lm["pos"][0]), float(lm["pos"][1]))
	var half := Vector2(float(lm["size"][0]), float(lm["size"][1])) / 2.0
	var d := p - c
	var nrm := Vector2(d.x / half.x, d.y / half.y)
	var edge := pond_edge(atan2(nrm.y, nrm.x), hash(str(lm["pos"]))) - POND_BANK / minf(half.x, half.y)
	return nrm.length() < edge


## GFX-135: amplitude (px) of a stream's meander.
const STREAM_AMP := 4.0


## GFX-135: sideways offset (px, |x| <= STREAM_AMP) of a stream at world coordinate `along` its length: a seeded sine
## (wavelength 120-200 px) that is exactly 0 within 24 px of any `spans` entry (x = start, y = end along the same axis;
## the path crossings, where a bridge must meet the water).
static func stream_offset(along: float, seed: int, spans: Array[Vector2]) -> float:
	var near := INF
	for sp in spans:
		near = minf(near, maxf(0.0, maxf(sp.x - along, along - sp.y)))
	if near <= 24.0:
		return 0.0
	var ease_in := clampf((near - 24.0) / 24.0, 0.0, 1.0)
	var wave := 120.0 + float(absi(seed) % 81)
	var phase := float(absi(seed / 7) % 628) / 100.0
	return sin(TAU * along / wave + phase) * STREAM_AMP * ease_in


## GFX-135: the stretches along a stream landmark's axis where a path crosses it (for stream_offset).
static func stream_spans(region: Dictionary, lm: Dictionary) -> Array[Vector2]:
	var size := Vector2(float(lm["size"][0]), float(lm["size"][1]))
	var r := Rect2(Vector2(float(lm["pos"][0]), float(lm["pos"][1])) - size / 2.0, size)
	var horizontal := size.x >= size.y
	var out: Array[Vector2] = []
	for pr: Array in region.get("map", {}).get("paths", []):
		var pth := Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3]))
		if pth.intersects(r):
			var ix := pth.intersection(r)
			out.append(Vector2(ix.position.x, ix.end.x) if horizontal else Vector2(ix.position.y, ix.end.y))
	return out



## GFX-125: `count` lily pads (centre and radius) scattered inside `rect`'s ellipse; seeded.
static func pond_lilies(rect: Rect2, seed_value: int, count: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.6
		out.append({"pos": rect.get_center() + Vector2(cos(a) * rect.size.x * 0.5 * d, sin(a) * rect.size.y * 0.5 * d), "r": rng.randf_range(3.0, 5.0)})
	return out


## GFX-125: the keepouts of a bog's ground features: roads, places, landmarks, NPC spots and the arrival ring.
static func marsh_keepouts(region: Dictionary) -> Array[Rect2]:
	var out := blocked_rects(region)
	for lm in landmark_rects(region):
		out.append(lm.grow(14.0))
	for spot: Array in region.get("npc_spots", []):
		out.append(Rect2(float(spot[0]) - 40.0, float(spot[1]) - 40.0, 80.0, 80.0))
	var arrival: Array = []
	if region.has("spawn"):
		arrival.append(region["spawn"])
	for place: Dictionary in region.get("places", []):
		if String(place.get("type", "")) == "travel":
			arrival.append(place.get("pos", [0, 0]))
	for a: Array in arrival:
		out.append(Rect2(float(a[0]) - 90.0, float(a[1]) - 90.0, 180.0, 180.0))
	return out


## GFX-126: a market's street dressing. Returns {"props": [{kind: barrel|crate|sack, rect}], "patches": [Rect2] packed earth,
## "cobbles": [Rect2] small dark block cobbles, "scorch": [{center, radius}] around gather places with look crater}.
## Seeded; nothing lies inside a road, place (with its label band) or landmark rect, except scorch (ground tint only).
static func market_props(region: Dictionary, size: Vector2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|marketprops" % region.get("id", ""))
	var map: Dictionary = region.get("map", {})
	var roads: Array[Rect2] = []
	for r in map.get("paths", []):
		roads.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	var solid: Array[Rect2] = []
	for pl: Dictionary in region.get("places", []):
		var k := Npcs.place_keepout(pl)
		solid.append(Rect2(k.position - Vector2(0, 26), k.size + Vector2(0, 26)).grow(10.0))
	var lms := landmark_rects(region)
	var scorch: Array[Dictionary] = []
	for pl: Dictionary in region.get("places", []):
		if str(pl.get("look", "")) == "crater":
			var pos: Array = pl["pos"]
			var sz: Array = pl.get("size", [100, 100])
			scorch.append({"center": Vector2(float(pos[0]), float(pos[1])), "radius": maxf(float(sz[0]), float(sz[1])) * 0.8})
	var props: Array[Dictionary] = []
	var kinds := ["barrel", "crate", "sack"]
	# GFX-134: the paved avenue (76 px) from the travel place (gate) to the nearest cross street, when a vertical road meets it
	var avenue := Rect2()
	for pl: Dictionary in region.get("places", []):
		if str(pl.get("type", "")) != "travel":
			continue
		var gx := float(pl["pos"][0])
		for r in roads:
			if r.size.y > r.size.x and gx >= r.position.x and gx <= r.end.x:
				var gy := float(pl["pos"][1])
				var top := 0.0
				for r2 in roads:
					if r2.size.x > r2.size.y and r2.end.y < gy and gx >= r2.position.x and gx <= r2.end.x:
						top = maxf(top, r2.position.y + r2.size.y * 0.5)
				avenue = Rect2(r.get_center().x - 38.0, top, 76.0, gy - top)
	for i in lms.size():
		if str(map["landmarks"][i].get("kind", "")) != "stall":
			continue
		var lr: Rect2 = lms[i]
		for n in 3:
			var side := rng.randi() % 4
			var at: Vector2
			match side:
				0: at = Vector2(lr.position.x - 14.0, rng.randf_range(lr.position.y, lr.end.y))
				1: at = Vector2(lr.end.x + 4.0, rng.randf_range(lr.position.y, lr.end.y))
				2: at = Vector2(rng.randf_range(lr.position.x, lr.end.x), lr.end.y + 4.0)
				_: at = Vector2(rng.randf_range(lr.position.x, lr.end.x), lr.position.y - 14.0)
			var rect := Rect2(at, Vector2(10, 10))
			if _market_blocked(rect, roads, solid, lms, 1.0, size, lr):
				continue
			var clash := false
			for q in props:
				if (q["rect"] as Rect2).grow(2.0).intersects(rect):
					clash = true
			if not clash:
				props.append({"kind": kinds[rng.randi() % 3], "rect": rect})
	var patches: Array[Rect2] = []
	for i in 40:
		var pr := Rect2(rng.randf_range(20.0, size.x - 60.0), rng.randf_range(20.0, size.y - 40.0), rng.randf_range(24.0, 44.0), rng.randf_range(12.0, 22.0))
		if patches.size() < 8 and not _market_blocked(pr, roads, solid, lms, 6.0, size, Rect2()) and not avenue.intersects(pr):
			patches.append(pr)
	var cobbles: Array[Rect2] = []
	for i in 600:
		var cr := Rect2(rng.randf_range(10.0, size.x - 16.0), rng.randf_range(10.0, size.y - 14.0), 5.0, 4.0)
		if not _market_blocked(cr, roads, solid, lms, 2.0, size, Rect2()) and not avenue.intersects(cr):
			cobbles.append(cr)
	var out := {"props": props, "patches": patches, "cobbles": cobbles, "scorch": scorch, "avenue": avenue, "avenue_slabs": _avenue_slabs(avenue), "ring": PackedVector2Array(), "shards": [] as Array[Rect2], "fence": [] as Array[Dictionary]}
	var arng := RandomNumberGenerator.new()
	arng.seed = hash("%s|avenue" % region.get("id", ""))
	# GFX-134: clusters of crates, barrels and sacks along the avenue (appended to props so they draw and test alike)
	var clusters := 0
	for attempt in 200:
		if clusters >= 3:
			break
		var side := -1.0 if arng.randf() < 0.5 else 1.0
		var cy := arng.randf_range(avenue.position.y + 30.0, avenue.end.y - 60.0)
		var cx := avenue.position.x - 22.0 if side < 0.0 else avenue.end.x + 8.0
		var placed: Array[Dictionary] = []
		for n in 3:
			var rect := Rect2(Vector2(cx + (float(n % 2) * 12.0 * -side), cy + float(n) * 11.0).round(), Vector2(10, 10))
			if _market_blocked(rect, roads, solid, lms, 1.0, size, Rect2()):
				continue
			var clash := false
			for q in props + placed:
				if (q["rect"] as Rect2).grow(2.0).intersects(rect):
					clash = true
			if not clash:
				placed.append({"kind": kinds[arng.randi() % 3], "rect": rect})
		if placed.size() >= 2:
			props.append_array(placed)
			clusters += 1
	# the crater plaza: a round scorched ring, faint star-shard stones and a low rope fence on two sides
	for pl: Dictionary in region.get("places", []):
		if str(pl.get("look", "")) != "crater":
			continue
		var cpos := Vector2(float(pl["pos"][0]), float(pl["pos"][1]))
		var csz: Array = pl.get("size", [100, 100])
		var crect := Rect2(cpos - Vector2(float(csz[0]), float(csz[1])) * 0.5, Vector2(float(csz[0]), float(csz[1])))
		var ring_rect := crect.grow(46.0)
		out["ring"] = ragged_outline(ring_rect, hash("%s|ring" % region.get("id", "")), minf(ring_rect.size.x, ring_rect.size.y) * 0.5, 5.0)
		var inner_solid: Array[Rect2] = []  # every other place; the crater's own rect + label band is the only part kept clear
		for pl2: Dictionary in region.get("places", []):
			if pl2 != pl:
				var k2 := Npcs.place_keepout(pl2)
				inner_solid.append(Rect2(k2.position - Vector2(0, 26), k2.size + Vector2(0, 26)).grow(10.0))
		var crater_clear := Rect2(crect.position - Vector2(6, 32), crect.size + Vector2(12, 38))
		inner_solid.append(crater_clear)
		var shards: Array[Rect2] = []
		for i in 12:
			if shards.size() >= 5:
				break
			var a := TAU * (float(i) / 12.0) + arng.randf_range(-0.15, 0.15)
			var at := cpos + Vector2(cos(a) * (ring_rect.size.x * 0.5 - 8.0), sin(a) * (ring_rect.size.y * 0.5 - 6.0))
			var sr := Rect2((at - Vector2(3, 3)).round(), Vector2(6, 6))
			if _market_blocked(sr, roads, inner_solid, lms, 2.0, size, Rect2()):
				continue
			shards.append(sr)
		out["shards"] = shards
		var fence: Array[Dictionary] = []
		for sx: float in [-1.0, 1.0]:
			var fx: float = cpos.x + sx * (ring_rect.size.x * 0.5 + 6.0)
			var posts: Array[Rect2] = []
			for k in 4:
				var pr := Rect2(Vector2(fx - 2.0, cpos.y - 33.0 + float(k) * 22.0).round(), Vector2(4, 8))
				if not _market_blocked(pr, roads, inner_solid, lms, 2.0, size, Rect2()):
					posts.append(pr)
			if posts.size() >= 2:
				fence.append({"posts": posts})
		out["fence"] = fence
	return out


## GFX-134: staggered pale slab rows over the avenue rect, one slab per row cell (seeded by position only).
static func _avenue_slabs(avenue: Rect2) -> Array[Rect2]:
	var slabs: Array[Rect2] = []
	if avenue.size.x <= 0.0:
		return slabs
	var row := 0
	var y := avenue.position.y
	while y < avenue.end.y:
		var h := minf(14.0, avenue.end.y - y)
		var off := 0.0 if row % 2 == 0 else 12.0
		var x := avenue.position.x - off
		while x < avenue.end.x:
			var r := Rect2(x, y, 24.0, h).intersection(avenue)
			if r.size.x > 4.0:
				slabs.append(r)
			x += 24.0
		y += 14.0
		row += 1
	return slabs


## GFX-131: the village square (map.square [x, y, w, h]): a soft-edged patch of packed earth with worn patches, one big old
## tree ringed with stones, benches and a lantern post. Pure and seeded by the region id. Empty without map.square.
## {outline: PackedVector2Array, rect: Rect2, patches: [{rect, shade}], tree: {pos, r} or {}, props: [{kind, rect}]}.
static func village_square(region: Dictionary) -> Dictionary:
	var sq: Variant = region.get("map", {}).get("square", null)
	if not (sq is Array and sq.size() == 4):
		return {}
	var rect := Rect2(float(sq[0]), float(sq[1]), float(sq[2]), float(sq[3]))
	var seed_value := hash("%s|square" % region.get("id", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var keep: Array[Rect2] = []
	for r: Variant in region.get("map", {}).get("paths", []):
		keep.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	for pl: Dictionary in region.get("places", []):
		keep.append(Npcs.place_keepout(pl).grow(12.0))
	keep.append_array(landmark_rects(region))
	var arrival := _arrival_points(region)
	var patches: Array[Dictionary] = []
	for i in rng.randi_range(10, 16):
		var pr := Rect2(rect.position.x + rng.randf_range(10.0, rect.size.x - 50.0), rect.position.y + rng.randf_range(8.0, rect.size.y - 30.0), rng.randf_range(20.0, 44.0), rng.randf_range(10.0, 22.0))
		patches.append({"rect": pr.intersection(rect), "shade": rng.randf() * 2.0 - 1.0})
	var tree := {}
	var taken: Array[Rect2] = []
	var fits: Array[Vector2] = []
	var gy := rect.position.y
	while gy <= rect.end.y:
		var gx := rect.position.x
		while gx <= rect.end.x:
			var c := Vector2(gx, gy)
			var foot := Rect2(c - Vector2(20, 20), Vector2(40, 40))
			var label_band := Rect2(foot.position - Vector2(0, 26), Vector2(foot.size.x, 26))
			if rect.encloses(foot) and not _square_hits(foot, keep, arrival) and not _square_hits(label_band, keep, arrival):
				fits.append(c)
			gx += 10.0
		gy += 10.0
	if not fits.is_empty():
		var tc: Vector2 = fits[rng.randi() % fits.size()]
		tree = {"pos": tc.round(), "r": 44.0}
		taken.append(Rect2(tc - Vector2(26, 26), Vector2(52, 52)))
	var props: Array[Dictionary] = []
	var wanted := ["bench", "lantern_post"] + (["bench"] if rng.randf() < 0.5 else [])
	for kind: String in wanted:
		var sz := Vector2(22, 10) if kind == "bench" else Vector2(8, 22)
		for attempt in 60:
			var pr := Rect2((rect.position + Vector2(rng.randf_range(10.0, rect.size.x - 40.0), rng.randf_range(10.0, rect.size.y - 34.0))).round(), sz)
			if not rect.encloses(pr) or _square_hits(pr, keep, arrival):
				continue
			var clash := false
			for t in taken:
				if t.intersects(pr.grow(2.0)):
					clash = true
					break
			if clash:
				continue
			taken.append(pr.grow(2.0))
			props.append({"kind": kind, "rect": pr})
			break
	var blob := ragged_outline(rect, seed_value, 20.0, 9.0)
	var stones: Array[Dictionary] = []
	var tracks: Array[Rect2] = []
	var tufts: Array[Rect2] = []
	if not tree.is_empty():
		var tp: Vector2 = tree["pos"]
		var stone_keep: Array[Rect2] = []  # roads are drawn over stones, so only places and landmarks block them
		for pl: Dictionary in region.get("places", []):
			stone_keep.append(Npcs.place_keepout(pl).grow(12.0))
		stone_keep.append_array(landmark_rects(region))
		for i in rng.randi_range(10, 16):
			var a := TAU * float(i) / 13.0 + rng.randf_range(-0.2, 0.2)
			var sz := rng.randf_range(10.0, 18.0)
			var c := tp + Vector2(cos(a) * rng.randf_range(32.0, 40.0), sin(a) * rng.randf_range(18.0, 24.0) + 14.0)
			var sr := Rect2(c - Vector2(sz, sz * 0.7) / 2.0, Vector2(sz, sz * 0.7)).abs()
			if not rect.encloses(sr) or _square_hits(sr, stone_keep, [] as Array[Vector2]):
				continue
			var clash := false
			for q: Dictionary in stones:
				if (q["rect"] as Rect2).grow(1.0).intersects(sr):
					clash = true
			for pr: Dictionary in props:
				if (pr["rect"] as Rect2).grow(2.0).intersects(sr):
					clash = true
			if not clash:
				stones.append({"rect": sr, "tone": rng.randi() % 3})
	for r2 in region.get("map", {}).get("paths", []):
		var pr2 := Rect2(float(r2[0]), float(r2[1]), float(r2[2]), float(r2[3]))
		var hit := pr2.intersection(rect)
		if hit.size.x > 0.0 and hit.size.y > 0.0 and tracks.size() < 3:
			tracks.append(hit.grow(3.0).intersection(rect))
	var perim := 0.0
	for i in blob.size():
		perim += blob[i].distance_to(blob[(i + 1) % blob.size()])
	for i in int(perim / 64.0 * 3.0):
		var idx := rng.randi() % blob.size()
		var tp2 := blob[idx] + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		var tr := Rect2(tp2, Vector2(2, rng.randf_range(3.0, 5.0)))
		if not _square_hits(tr, keep, arrival):
			tufts.append(tr)
	return {"rect": rect, "outline": jagged_outline(rect, seed_value, 18, 10.0), "blob": blob, "patches": patches, "tree": tree, "props": props, "stones": stones, "tracks": tracks, "tufts": tufts}


static func _square_hits(r: Rect2, keep: Array[Rect2], arrival: Array[Vector2]) -> bool:
	for k in keep:
		if k.intersects(r):
			return true
	for a in arrival:
		if r.grow(SPOT_RADIUS).has_point(a):
			return true
	return false


## GFX-127: roof colours a village house can take (slate blue, thatch, red tile, grey tile).
const YARD_ROOFS: Array[String] = ["4a6fa5", "c9a35a", "a8443a", "6b6f78"]
const YARD_BUILDINGS: Array[String] = ["workshop", "clinic", "orphanage", "sect_hall", "family_home", "auction"]
const YARD_PATH_W := 11.0
const YARD_PATH_MAX := 260.0
const YARD_PATH_MAX_PLACE := 420.0  # GFX-132: temple, workshop, clinic, sect hall may sit further from a road
const YARD_PROP_SIZES := {"woodpile": Vector2(20, 12), "water_jar": Vector2(10, 12), "veg_row": Vector2(36, 20), "washing_line": Vector2(40, 24), "bench": Vector2(22, 10)}


## GFX-127: the lived-in dressing of a village (regions with `map.yards`): {"footpaths": [{rect, door}] (door = index of the
## building; each building gets an L of at most two rects from its door to the nearest road), "yards": [{rect}] packed earth under
## each house, "props": [{kind, rect}] beside each house, "roof": {landmark index: Color}}. Seeded by region id; empty otherwise.
static func village_yards(region: Dictionary, size: Vector2) -> Dictionary:
	var out := {"footpaths": [] as Array[Dictionary], "yards": [] as Array[Dictionary], "props": [] as Array[Dictionary], "roof": {}}
	var map: Dictionary = region.get("map", {})
	if not bool(map.get("yards", false)):
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|yards" % region.get("id", ""))
	var roads: Array[Rect2] = []
	for r in map.get("paths", []):
		roads.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	var keep: Array[Rect2] = []  # place keepouts with the label band, grown by 10
	for pl: Dictionary in region.get("places", []):
		var k := Npcs.place_keepout(pl)
		keep.append(Rect2(k.position - Vector2(0, 26), k.size + Vector2(0, 26)).grow(10.0))
	for a in _arrival_points(region):
		keep.append(Rect2(a - Vector2(90, 90), Vector2(180, 180)))
	var lms := landmark_rects(region)
	var houses: Array[int] = []
	var buildings: Array[Rect2] = []  # footprints whose door gets a path (houses first, then places)
	var own_lm: Array[int] = []  # landmark index of each building, -1 for a place
	var own_pl: Array[int] = []
	var lm_list: Array = map.get("landmarks", [])
	for i in lm_list.size():
		if str(lm_list[i].get("kind", "")) == "house":
			houses.append(i)
			buildings.append(lms[i])
			own_lm.append(i)
			own_pl.append(-1)
	var places: Array = region.get("places", [])
	for j in places.size():
		var pl: Dictionary = places[j]
		if str(pl.get("type", "")) in YARD_BUILDINGS:
			var pos: Array = pl["pos"]
			var sz: Array = pl["size"]
			buildings.append(Rect2(float(pos[0]) - float(sz[0]) / 2.0, float(pos[1]) - float(sz[1]) / 2.0, float(sz[0]), float(sz[1])))
			own_lm.append(-1)
			own_pl.append(j)
	var paths_out: Array[Dictionary] = out["footpaths"]
	for b in buildings.size():
		var br: Rect2 = buildings[b]
		var door := Vector2(br.get_center().x, br.end.y)
		var cands: Array[Dictionary] = []  # {"rects": Array[Rect2], "len": float}
		var touching := false
		var w := YARD_PATH_W
		var limit := YARD_PATH_MAX_PLACE if own_pl[b] >= 0 else YARD_PATH_MAX
		for road in roads:
			if road.grow(1.0).has_point(door) or road.grow(12.0).intersects(br):  # the door or the whole building stands at the road
				touching = true
			if road.size.x >= road.size.y:  # a horizontal road
				if road.position.y >= door.y:  # below: straight down, or sideways then down
					cands.append({"rects": [Rect2(door.x - w / 2.0, door.y, w, road.position.y + 1.0 - door.y)], "len": road.position.y - door.y})
					for sx in _side_xs(br):
						var x0: float = minf(door.x, sx) - w / 2.0
						cands.append({"rects": [Rect2(x0, door.y, absf(sx - door.x) + w, w), Rect2(sx - w / 2.0, door.y, w, road.position.y + 1.0 - door.y)], "len": absf(sx - door.x) + road.position.y - door.y})
				else:  # above: along the bottom edge to a side, then up
					for sx in _side_xs(br):
						var x0: float = minf(door.x, sx) - w / 2.0
						cands.append({"rects": [Rect2(x0, door.y, absf(sx - door.x) + w, w), Rect2(sx - w / 2.0, road.end.y - 1.0, w, door.y + w - road.end.y + 1.0)], "len": absf(sx - door.x) + door.y - road.end.y})
					# last resort: straight up behind the building (hidden under its footprint), a back-door path
					cands.append({"rects": [Rect2(door.x - w / 2.0, road.end.y - 1.0, w, door.y - 20.0 - road.end.y + 1.0)], "len": door.y - road.end.y + 60.0})
			else:  # a vertical road: down a step (or further), then sideways
				var gap := road.position.x - door.x if road.position.x > door.x else door.x - road.end.x
				if gap < 0.0:
					touching = true
					continue
				var x1 := door.x if road.position.x > door.x else road.end.x - 1.0
				var x2 := road.position.x + 1.0 if road.position.x > door.x else door.x
				for drop in [w, 36.0, 72.0]:
					cands.append({"rects": [Rect2(door.x - w / 2.0, door.y, w, drop), Rect2(x1, door.y + drop - w, x2 - x1, w)], "len": gap + drop - w})
		if touching:
			continue
		cands.sort_custom(func(m: Dictionary, n: Dictionary) -> bool: return m["len"] < n["len"])
		var chosen: Array = []
		for c in cands:
			if float(c["len"]) > limit:
				break
			var blocked := false
			for r: Rect2 in c["rects"]:
				if r.position.x < 8.0 or r.position.y < 8.0 or r.end.x > size.x - 8.0 or r.end.y > size.y - 8.0:
					blocked = true
				for q in lms.size():
					if q != own_lm[b] and lms[q].intersects(r) and q < lm_list.size() and str(lm_list[q].get("kind", "")) != "stream":
						blocked = true
				for j in places.size():
					if j != own_pl[b] and keep[j].intersects(r):
						blocked = true
			if not blocked:
				chosen = c["rects"]
				break
		for r: Rect2 in chosen:
			paths_out.append({"rect": r, "door": b})
	# yards, roofs and props, per house
	var yards_out: Array[Dictionary] = out["yards"]
	var props_out: Array[Dictionary] = out["props"]
	var roof_out: Dictionary = out["roof"]
	var start := rng.randi() % YARD_ROOFS.size()
	var solid: Array[Rect2] = []
	solid.append_array(roads)
	solid.append_array(keep)
	for p: Dictionary in paths_out:
		solid.append(p["rect"])
	for n in houses.size():
		var i: int = houses[n]
		var hr: Rect2 = lms[i]
		roof_out[i] = Color(YARD_ROOFS[(start + n) % YARD_ROOFS.size()])
		var yr := Rect2(hr.get_center().x - hr.size.x * 0.7, hr.end.y - 4.0, hr.size.x * 1.4, 24.0)
		yards_out.append({"rect": yr, "outline": ragged_outline(yr, hash("%s|yard|%d" % [region.get("id", ""), i]), 10.0, 5.0)})
		var kinds := YARD_PROP_SIZES.keys()
		var left := rng.randi() % 2 == 0
		var placed := 0
		for m in rng.randi_range(1, 2):
			var kind: String = kinds[rng.randi() % kinds.size()]
			var order: Array[String] = [kind]
			for k2 in ["water_jar", "woodpile", "bench"]:  # smaller props where the first pick does not fit
				if k2 != kind:
					order.append(k2)
			var done := false
			for k in order:
				var psz: Vector2 = YARD_PROP_SIZES[k]
				# beside the house (preferred side first), then in front below the yard, then behind
				var spots: Array[Rect2] = []
				for lf in [left, not left]:
					var px := hr.position.x - psz.x - 22.0 if lf else hr.end.x + 22.0
					spots.append(Rect2(px, hr.end.y - psz.y - 2.0 - 26.0 * m + 26.0, psz.x, psz.y))
				spots.append(Rect2(hr.position.x + hr.size.x * 0.1, hr.end.y + 26.0 + 4.0 * m, psz.x, psz.y))
				spots.append(Rect2(hr.end.x - hr.size.x * 0.1 - psz.x, hr.end.y + 26.0 + 4.0 * m, psz.x, psz.y))
				spots.append(Rect2(hr.get_center().x - psz.x / 2.0, hr.position.y - psz.y - 8.0, psz.x, psz.y))
				for rect in spots:
					if _market_blocked(rect, solid, [] as Array[Rect2], lms, 6.0, size, Rect2()):
						continue
					var clash := false
					for q: Dictionary in props_out:
						if (q["rect"] as Rect2).grow(4.0).intersects(rect):
							clash = true
					if not clash:
						props_out.append({"kind": k, "rect": rect})
						done = true
						placed += 1
						break
				if done:
					break
			left = not left if m == 0 else left
	return out


## GFX-132: x positions beside a building (near, then further out, each side) where a footpath may run up or down.
static func _side_xs(br: Rect2) -> Array[float]:
	var out: Array[float] = []
	for off in [8.0, 36.0, 70.0]:
		out.append(br.end.x + off)
		out.append(br.position.x - off)
	return out


static func _arrival_points(region: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if region.has("spawn"):
		out.append(Vector2(float(region["spawn"][0]), float(region["spawn"][1])))
	return out


static func _market_blocked(rect: Rect2, roads: Array[Rect2], solid: Array[Rect2], lms: Array[Rect2], gap: float, size: Vector2, own: Rect2) -> bool:
	if rect.position.x < 8.0 or rect.position.y < 8.0 or rect.end.x > size.x - 8.0 or rect.end.y > size.y - 8.0:
		return true
	for r in roads:
		if r.grow(gap).intersects(rect):
			return true
	for r in solid:
		if r.intersects(rect):
			return true
	for r in lms:
		if r != own and r.grow(gap).intersects(rect):
			return true
		if r == own and r.intersects(rect):
			return true
	return false


static func _marsh_hits(rect: Rect2, keepouts: Array[Rect2], taken: Array[Rect2], gap: float) -> bool:
	for k in keepouts:
		if k.intersects(rect):
			return true
	for t in taken:
		if t.grow(gap).intersects(rect):
			return true
	return false


static func _marsh_add_reeds(out: Array[Dictionary], clump_rects: Array[Rect2], at: Vector2, rng: RandomNumberGenerator, keepouts: Array[Rect2], pools: Array[Rect2], size: Vector2) -> void:
	var rect := Rect2(at - Vector2(14, 22), Vector2(28, 30))
	if rect.position.x < 8.0 or rect.position.y < 8.0 or rect.end.x > size.x - 8.0 or rect.end.y > size.y - 8.0:
		return
	for k in keepouts:
		if k.intersects(rect):
			return
	for cr in clump_rects:
		if cr.intersects(rect):
			return
	for pr in pools:
		if pr.grow(-10.0).intersects(Rect2(at - Vector2(2, 2), Vector2(4, 4))):
			return
	var stalks: Array[Dictionary] = []
	for i in rng.randi_range(3, 7):
		stalks.append({"dx": rng.randf_range(-10.0, 10.0), "h": rng.randf_range(12.0, 22.0)})
	clump_rects.append(rect)
	out.append({"pos": at, "stalks": stalks})
