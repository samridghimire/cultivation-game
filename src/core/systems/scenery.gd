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
const EXTRA_KEYS: PackedStringArray = ["tree_kinds", "blossoms", "clusters", "groves", "undergrowth_kinds", "rock_clusters", "edge_belt", "canopy_masses"]
## map.decor.undergrowth_kinds (GFX-144): weights for what grows under groves (filler kinds; logs always come on top).
const UNDERGROWTH_KINDS: PackedStringArray = ["fern", "bush", "mushroom", "reed", "stone"]
const DEFAULT_UNDERGROWTH := {"fern": 6.0, "bush": 4.0}
## map.decor.groves (GFX-139): dense groves of 6-15 trees, the tallest in the middle, with open glades between them.
const MAX_GROVES := 10
const GROVE_RADIUS := 95.0
const GROVE_GAP := 40.0
## map.decor.canopy_masses (GFX-186): big clumps of 6-14 overlapping trees that read as one dark canopy; they ride on top of
## the tree budget and keep apart from groves and each other. Items carry "canopy": index and the "grove" keys, so the
## groves' undergrowth grows round them; the world draws one merged shadow per mass.
const MAX_CANOPY_MASSES := 20
const CANOPY_RADIUS := 85.0
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
			var grove_centres: Array[Vector2] = []
			for g in clampi(int(cfg.get("groves", 0)), 0, MAX_GROVES):
				budget -= _place_grove(out, cfg, color, budget, size, blocked, spots, rng, grove_centres, g)
			for m in clampi(int(cfg.get("canopy_masses", 0)), 0, MAX_CANOPY_MASSES):
				_place_canopy_mass(out, cfg, color, size, blocked, spots, rng, grove_centres, m)
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


## GFX-139: a grove of 6-15 trees round a clear centre, scale falling from the middle out (tallest in the middle).
## Groves keep GROVE_GAP + both radii apart so glades stay open. Items carry "grove": index. Returns trees placed.
static func _place_grove(out: Array[Dictionary], cfg: Dictionary, color: Color, budget: int, size: Vector2,
		blocked: Array[Rect2], spots: Array[Vector2], rng: RandomNumberGenerator, centres: Array[Vector2], index: int) -> int:
	var want := mini(rng.randi_range(6, 15), budget)
	if want <= 0:
		return 0
	var radius := GROVE_RADIUS * clampf(float(want) / 12.0, 0.6, 1.1)
	var centre := Vector2.ZERO
	var found := false
	for attempt in TRIES * 4:
		centre = Vector2(rng.randf_range(EDGE + radius, size.x - EDGE - radius), rng.randf_range(EDGE + radius, size.y - EDGE - radius))
		var apart := true
		for other in centres:
			if other.distance_to(centre) < GROVE_RADIUS * 2.0 + GROVE_GAP:
				apart = false
				break
		if apart and is_clear(centre, blocked, spots):
			found = true
			break
	if not found:
		return 0
	centres.append(centre)
	var placed := 0
	for i in want:
		for attempt in TRIES:
			var d := 0.0 if i == 0 else sqrt(rng.randf()) * radius
			var pos := centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * d
			if pos.x > EDGE and pos.y > EDGE and pos.x < size.x - EDGE and pos.y < size.y - EDGE and is_clear(pos, blocked, spots):
				var item := _decor_item("tree", pos, color, cfg, rng)
				item["scale"] = lerpf(1.5, 0.8, d / radius) * rng.randf_range(0.94, 1.06)
				item["grove"] = index
				item["grove_centre"] = centre
				item["grove_radius"] = radius
				out.append(item)
				placed += 1
				break
	return placed


## GFX-186: one canopy mass of 6-14 trees (radius CANOPY_RADIUS, the tallest near the middle). Needs a clear centre that is
## GROVE_GAP + both radii from every earlier grove/mass centre; items get "canopy" and the grove keys (index 100 + m).
static func _place_canopy_mass(out: Array[Dictionary], cfg: Dictionary, color: Color, size: Vector2, blocked: Array[Rect2],
		spots: Array[Vector2], rng: RandomNumberGenerator, centres: Array[Vector2], index: int) -> int:
	var want := rng.randi_range(6, 14)
	var centre := Vector2.ZERO
	var found := false
	for attempt in TRIES * 4:
		centre = Vector2(rng.randf_range(EDGE + CANOPY_RADIUS, size.x - EDGE - CANOPY_RADIUS), rng.randf_range(EDGE + CANOPY_RADIUS, size.y - EDGE - CANOPY_RADIUS))
		var apart := true
		for other in centres:
			if other.distance_to(centre) < GROVE_RADIUS + CANOPY_RADIUS + GROVE_GAP:
				apart = false
				break
		if apart and is_clear(centre, blocked, spots):
			found = true
			break
	if not found:
		return 0
	centres.append(centre)
	var placed := 0
	for i in want:
		for attempt in TRIES:
			var d := 0.0 if i == 0 else sqrt(rng.randf()) * CANOPY_RADIUS
			var pos := centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * d
			if pos.x > EDGE and pos.y > EDGE and pos.x < size.x - EDGE and pos.y < size.y - EDGE and is_clear(pos, blocked, spots):
				var item := _decor_item("tree", pos, color, cfg, rng)
				item["scale"] = lerpf(1.45, 0.9, d / CANOPY_RADIUS) * rng.randf_range(0.94, 1.06)
				item["canopy"] = index
				item["grove"] = 100 + index
				item["grove_centre"] = centre
				item["grove_radius"] = CANOPY_RADIUS
				out.append(item)
				placed += 1
				break
	return placed


## GFX-144: one weighted undergrowth kind (keys in insertion order).
static func _pick_undergrowth(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k: Variant in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	var last := "fern"
	for k: Variant in weights:
		last = String(k)
		roll -= float(weights[k])
		if roll < 0.0:
			return last
	return last


## GFX-139: undergrowth for the groves in `decor` ([{kind: "fern"|"bush"|"log"|"mushroom", pos, scale}]): 2-4 fallen logs
## in all, ferns/bushes and mushroom clusters under the groves, never on paths, places, npc_spots or spawn.
static func undergrowth(region: Dictionary, decor: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var groves := {}
	for d in decor:
		if d.has("grove") and not groves.has(d["grove"]):
			groves[d["grove"]] = d
	if groves.is_empty():
		return out
	var blocked := blocked_rects(region)
	var spots: Array[Vector2] = []
	for s in region.get("npc_spots", []):
		spots.append(Vector2(float(s[0]), float(s[1])))
	if region.has("spawn"):
		spots.append(Vector2(float(region["spawn"][0]), float(region["spawn"][1])))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(region.get("id", "")), "undergrowth"])
	var keys: Array = groves.keys()
	keys.sort()
	var custom: bool = region.get("map", {}).get("decor", {}).has("undergrowth_kinds")
	var weights: Dictionary = region.get("map", {}).get("decor", {}).get("undergrowth_kinds", DEFAULT_UNDERGROWTH)
	var logs := 0
	var want_logs := rng.randi_range(2, 4)
	for k: Variant in keys:
		var g: Dictionary = groves[k]
		var centre: Vector2 = g["grove_centre"]
		var radius: float = g["grove_radius"]
		var plan: Array[String] = []
		for i in rng.randi_range(5, 9):
			plan.append(_pick_undergrowth(weights, rng))
		if not custom:
			for i in rng.randi_range(1, 2):
				plan.append("mushroom")
		if logs < want_logs:
			plan.append("log")
			logs += 1
		for kind in plan:
			for attempt in TRIES:
				var pos := centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * radius * 1.1
				if is_clear(pos, blocked, spots):
					out.append({"kind": kind, "pos": pos, "scale": rng.randf_range(0.8, 1.2), "flip": rng.randf() < 0.5})
					break
	return out


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
		elif lm.get("kind", "") == "stream":  # GFX-178: the bed swings STREAM_AMP either side of the axis
			rect = rect.grow_individual(STREAM_AMP, 0.0, STREAM_AMP, 0.0) if size.x < size.y else rect.grow_individual(0.0, STREAM_AMP, 0.0, STREAM_AMP)
		out.append(rect)
	return out


## WU-585: where the player stands while helping the villager at `npc_pos`: one `gap` to their left (facing the prop),
## else right, below, above, then two gaps out; a spot is free when the player's body (`radius`) misses every solid
## landmark and the map edge. Falls back to the left spot when nothing is free.
static func lend_spot(region: Dictionary, npc_pos: Vector2, gap: float = 40.0, radius: float = 14.0) -> Vector2:
	var sz: Array = region.get("map", {}).get("size", [1600, 1000])
	var bounds := Rect2(Vector2.ZERO, Vector2(float(sz[0]), float(sz[1]))).grow(-radius)
	var solids := landmark_rects(region, true)
	for k in [1.0, 2.0]:
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP]:
			var p: Vector2 = npc_pos + dir * gap * k
			if not bounds.has_point(p):
				continue
			var body := Rect2(p - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			var hit := false
			for r in solids:
				if r.intersects(body):
					hit = true
					break
			if not hit:
				return p
	return npc_pos + Vector2.LEFT * gap


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


## GFX-142: where the ragged pond bank crosses the line through `along` (x when `vertical`, else y): the distance from the pond
## centre to the bank as a fraction of the half extent (like the old ellipse `t`), found by scanning inward from the ellipse.
static func _pond_rim_t(c: Vector2, half: Vector2, pseed: int, along: float, vertical: bool, positive: bool) -> float:
	var sgn := 1.0 if positive else -1.0
	var ext := half.y if vertical else half.x
	var steps := 48
	for i in steps + 1:
		var f := 1.0 - float(i) / float(steps)
		var p := Vector2(along, c.y + sgn * ext * f) if vertical else Vector2(c.x + sgn * ext * f, along)
		var n := Vector2((p.x - c.x) / half.x, (p.y - c.y) / half.y)
		if n.length() <= pond_edge(atan2(n.y, n.x), pseed):
			return f
	return 0.0


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
			best = {"c": pc, "half": half, "seed": hash(str(other["pos"]))}
	if best.is_empty():
		return {"rect": own, "vertical": size.y > size.x, "on_water": false}
	var c: Vector2 = best["c"]
	var half: Vector2 = best["half"]
	var pseed: int = best["seed"]
	var delta := pos - c
	var vertical := absf(delta.y) / half.y >= absf(delta.x) / half.x
	var rect: Rect2
	if vertical:
		var x := clampf(pos.x, c.x - half.x * 0.8, c.x + half.x * 0.8)
		var t := _pond_rim_t(c, half, pseed, x, true, delta.y >= 0.0)
		long_side = minf(long_side, maxf(JETTY_MIN_LEN, half.y * t * 1.5))  # GFX-116: the water end stays inside a shallow pond
		if delta.y >= 0.0:
			var rim := c.y + half.y * t
			rect = Rect2(x - short_side / 2.0, rim + JETTY_SHORE - long_side, short_side, long_side)
		else:
			var rim2 := c.y - half.y * t
			rect = Rect2(x - short_side / 2.0, rim2 - JETTY_SHORE, short_side, long_side)
	else:
		var y := clampf(pos.y, c.y - half.y * 0.8, c.y + half.y * 0.8)
		var t2 := _pond_rim_t(c, half, pseed, y, false, delta.x >= 0.0)
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


## GFX-163: width of a tree's ground shadow ellipse by kind (round/willow ~ canopy width, pine ~60%, bamboo ~45%).
static func shadow_width(kind: String, k: float) -> float:
	var canopy := 36.0 * k
	match kind:
		"pine":
			return canopy * 0.6
		"bamboo":
			return canopy * 0.45
		_:
			return canopy


## GFX-183: seeded layout of a broadleaf tree, relative to the trunk anchor (y 16 = the foot).
## Returns {scale 0.85..1.15, lean -1..1 px, trunk_w 3..5, trunk_h 6..10, base_y (canopy underside y),
## lobes [{c: Vector2, r: float}] (3..5 overlapping lobes, all above base_y + 2)}.
static func round_tree_layout(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value) + 1
	var trunk_h := rng.randi_range(6, 10)
	var base_y := 16.0 - float(trunk_h) + 2.0
	var n := rng.randi_range(3, 5)
	var lobes: Array = []
	for i in n:
		var t := float(i) / float(n - 1)
		var r := rng.randf_range(8.0, 12.0)
		var x := lerpf(-11.0, 11.0, t) + rng.randf_range(-2.0, 2.0)
		var lift := (1.0 - absf(t - 0.5) * 2.0) * 9.0  # the middle lobes sit higher
		lobes.append({"c": Vector2(x, base_y - r - 2.0 - lift - rng.randf_range(0.0, 3.0)), "r": r})
	return {
		"scale": rng.randf_range(0.85, 1.15), "lean": rng.randf_range(-1.0, 1.0),
		"trunk_w": rng.randi_range(3, 5), "trunk_h": trunk_h, "base_y": base_y, "lobes": lobes,
	}


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
const PAVED_REACH := 36.0


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


## GFX-180: which kind of hedge prop a seed makes: "plain", "tree" (a small tree over the hedge), "flower" (a flowering shrub) or "rock".
static func hedge_variant(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 17
	var f := rng.randf()
	if f < 0.2:
		return "tree"
	if f < 0.37:
		return "flower" if rng.randf() < 0.65 else "rock"
	return "plain"


## GFX-180: the foliage blobs of one hedge prop, back row first: [{pos: Vector2, radius: float, layer: int}] (layer 0 back, 1 front).
## 2-4 blobs per prop with varied radii (0.45-0.85 x the short side); back blobs sit toward the map edge, front blobs
## 0..EDGE_INSIDE*0.5 px inward so the inner silhouette undulates. Every centre lies inside rect.grow(8).
static func hedge_blobs(rect: Rect2, seed_value: int, side: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var inward := [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)][side] as Vector2
	var along := Vector2(1, 0) if side < 2 else Vector2(0, 1)
	var length := rect.size.x if side < 2 else rect.size.y
	var short := minf(rect.size.x, rect.size.y)
	var c := rect.get_center()
	var out: Array[Dictionary] = []
	var count := rng.randi_range(2, 4)
	for i in count:
		var layer := 0 if i < count / 2 else 1
		var u := (float(i) + 0.5) / float(count) - 0.5 + rng.randf_range(-0.12, 0.12)
		var off := -rng.randf_range(3.0, 6.0) if layer == 0 else rng.randf_range(0.0, EDGE_INSIDE * 0.5)
		out.append({"pos": c + along * u * length + inward * off, "radius": short * rng.randf_range(0.45, 0.85), "layer": layer})
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


## GFX-145: an irregular rock outline, 6-9 points round `center`, each at 0.75-1.0 x `radius`; same seed, same rock.
static func rock_polygon(center: Vector2, radius: float, seed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := rng.randi_range(6, 9)
	var out := PackedVector2Array()
	var a0 := rng.randf() * TAU
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		out.append(center + Vector2(cos(a), sin(a)) * radius * rng.randf_range(0.75, 1.0))
	return out


## GFX-166: a low irregular stone: the rock_polygon flattened to `flatness` (0.5-0.7) of its height around `center`, so a pebble or
## boulder reads as a stone lying on the ground, not a ball.
static func flat_stone(center: Vector2, radius: float, seed: int, flatness: float = 0.6) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in rock_polygon(center, radius, seed):
		out.append(Vector2(q.x, center.y + (q.y - center.y) * flatness))
	return out


## GFX-166: foot stones of a rock step along x in [x0, x1] at height y: [{pos: Vector2, radius: float, seed: int}], 2-4 of them,
## each inside the span.
static func ledge_foot_stones(x0: float, x1: float, y: float, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7919
	var out: Array[Dictionary] = []
	for i in rng.randi_range(2, 4):
		var r := rng.randf_range(2.0, 4.0)
		out.append({"pos": Vector2(rng.randf_range(x0 + r, maxf(x1 - r, x0 + r)), y + rng.randf_range(1.0, 4.0)), "radius": r, "seed": rng.randi()})
	return out


## GFX-145: pebble clusters of a scree map, ~1 per 64x64 px, [{center: Vector2, seed: int, count: int}]. Seeded by the region id;
## no centre lies in a `keepouts` rect (paths, places) or within 8 px of the map border. Empty for other ground styles.
static func scree_clusters(region: Dictionary, keepouts: Array[Rect2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	if String(map.get("ground_style", "")) != "scree":
		return out
	var size_arr: Array = map.get("size", [1600, 1000])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|scree_clusters")
	var cells_x := int(float(size_arr[0]) / 64.0)
	var cells_y := int(float(size_arr[1]) / 64.0)
	var density := clampf(float(map.get("scree_density", 1.0)), 0.2, 1.0)
	for cy in cells_y:
		for cx in cells_x:
			var c := Vector2((cx + rng.randf_range(0.1, 0.9)) * 64.0, (cy + rng.randf_range(0.1, 0.9)) * 64.0)
			var cnt := rng.randi_range(3, 6)
			var sd := rng.randi()
			if rng.randf() > density * 0.6 or c.x < 8.0 or c.y < 8.0:
				continue
			var blocked := false
			for k in keepouts:
				if k.has_point(c):
					blocked = true
					break
			if not blocked:
				out.append({"center": c, "seed": sd, "count": cnt})
	return out


## GFX-179: one scree fan at the foot of each outcrop (crag, ledge, boulder cluster): `anchors` are their rects. Returns
## [{origin: Vector2, base: Vector2, length: float, spread: float, seed: int}]; `origin` is within 24 px of the rect's
## bottom centre `base`, and the fan spreads downhill (+y) from it. Seeded by the region id and the anchor order.
static func outcrop_fans(region_id: String, anchors: Array[Rect2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in anchors.size():
		var r := anchors[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|outcrop_fan|%d" % [region_id, i])
		var base := Vector2(r.get_center().x, r.end.y)
		var origin := base + Vector2(rng.randf_range(-0.2, 0.2) * minf(r.size.x, 100.0), rng.randf_range(-4.0, 4.0))
		out.append({"origin": origin, "base": base, "length": rng.randf_range(26.0, 44.0) + minf(r.size.x, 140.0) * 0.12, "spread": minf(r.size.x, 140.0) * 0.5 + rng.randf_range(10.0, 20.0), "seed": rng.randi()})
	return out


## GFX-179: the pebbles of a fan, [Vector3(x, y, size)] in a wedge that widens downhill from `origin`; `size` 1-3 px, the
## last 40% of them (the tip) are the lightest. Deterministic from the fan's seed.
static func fan_pebbles(fan: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(fan["seed"])
	var o: Vector2 = fan["origin"]
	var length := float(fan["length"])
	var spread := float(fan["spread"])
	for i in int(length * 0.9):
		var t := sqrt(rng.randf())
		var half := spread * (0.25 + 0.75 * t)
		out.append(Vector3(o.x + rng.randf_range(-half, half) * (1.0 - t * 0.35), o.y + 2.0 + t * length, float(rng.randi_range(1, 3))))
	return out


## GFX-145: 2-4 faint lighter slope bands across a scree map, [{rect: Rect2, seed: int}], seeded by the region id.
static func scree_bands(region: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	if String(map.get("ground_style", "")) != "scree":
		return out
	var size_arr: Array = map.get("size", [1600, 1000])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|scree_bands")
	for i in rng.randi_range(2, 4):
		var w := rng.randf_range(300.0, 620.0)
		var h := rng.randf_range(40.0, 80.0)
		out.append({"rect": Rect2(rng.randf_range(0.0, maxf(float(size_arr[0]) - w, 1.0)), rng.randf_range(0.0, maxf(float(size_arr[1]) - h, 1.0)), w, h), "seed": rng.randi()})
	return out


## GFX-156: the raised bed of a murky-bog boardwalk: 70% of the road width, centred, along either axis. Boards lie inside it.
static func bog_bed_rect(path_rect: Rect2) -> Rect2:
	if path_rect.size.x >= path_rect.size.y:
		return Rect2(path_rect.position.x + 3.0, path_rect.position.y + path_rect.size.y * 0.15, path_rect.size.x - 6.0, path_rect.size.y * 0.70)
	return Rect2(path_rect.position.x + path_rect.size.x * 0.15, path_rect.position.y + 3.0, path_rect.size.x * 0.70, path_rect.size.y - 6.0)


## GFX-156: the bed outline as a polygon whose long edges wobble 0-2 px outward (never inward, so boards stay inside), sampled every 24 px.
static func bog_bed_polygon(path_rect: Rect2, seed: int) -> PackedVector2Array:
	var bed := bog_bed_rect(path_rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var along_x := path_rect.size.x >= path_rect.size.y
	var length := bed.size.x if along_x else bed.size.y
	var n := maxi(int(length / 24.0), 1)
	var side_a := PackedVector2Array()
	var side_b := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var wa := rng.randf_range(0.0, 2.0)
		var wb := rng.randf_range(0.0, 2.0)
		if along_x:
			var x := bed.position.x + bed.size.x * t
			side_a.append(Vector2(x, bed.position.y - wa))
			side_b.append(Vector2(x, bed.end.y + wb))
		else:
			var y := bed.position.y + bed.size.y * t
			side_a.append(Vector2(bed.position.x - wa, y))
			side_b.append(Vector2(bed.end.x + wb, y))
	side_b.reverse()
	return side_a + side_b


## GFX-156: 2-3 small puddle rects on the mud verges of a bog road (outside the bed, inside `path_rect`), seeded.
static func bog_puddles(path_rect: Rect2, seed: int) -> Array[Rect2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bed := bog_bed_rect(path_rect)
	var along_x := path_rect.size.x >= path_rect.size.y
	var out: Array[Rect2] = []
	var count := rng.randi_range(2, 3)
	for i in count:
		var upper := rng.randf() < 0.5
		var w := rng.randf_range(6.0, 12.0)
		var h := rng.randf_range(2.0, 3.0)
		var verge_w := (bed.position.y - path_rect.position.y) if along_x else (bed.position.x - path_rect.position.x)
		if verge_w < h + 5.0:
			continue
		var along := rng.randf_range(8.0, (path_rect.size.x if along_x else path_rect.size.y) - w - 8.0)
		var across := rng.randf_range(1.5, verge_w - h - 3.5)
		var r: Rect2
		if along_x:
			r = Rect2(path_rect.position.x + along, (path_rect.position.y + across) if upper else (bed.end.y + 2.5 + across), w, h)
		else:
			r = Rect2((path_rect.position.x + across) if upper else (bed.end.x + 2.5 + across), path_rect.position.y + along, h, w)
		out.append(r)
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
## GFX-154: a terrace-court flag's colour: one of four clearly different tones (about -12 %, -4 %, +4 %, +11 %), by `seed`.
static func terrace_flag_shade(base: Color, seed: int) -> Color:
	var f: float = [-0.12, -0.04, 0.04, 0.11][absi(hash([seed, "tone"])) % 4]
	return base.lightened(f) if f >= 0.0 else base.darkened(-f)


static func paving_shade(base: Color, seed: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if rng.randi() % 8 == 0:
		return base.lightened(0.05 + rng.randf() * 0.05)
	var f := rng.randf_range(-0.08, 0.08)
	return base.lightened(f) if f >= 0.0 else base.darkened(-f)


## GFX-112: the road surface pieces laid over a path rect, seeded by region id and rect. Each is
## {kind: slab|flag_poly|grit|pebble|plank|rut|edge|puddle|tuft, rect: Rect2, shade: -1..1, flag: crack|gap|""}. Style: scree/paved = irregular
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
	if style == "scree":
		_scree_trail_tiles(out, rng, path_rect, along_x, len_total, width)
	elif style == "paved":
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
		# GFX-146: a walkway ~58% of the road width, centred, drifting +-3 px; wet mud verges either side with reed tufts;
		# pilings under the board ends every 36-48 px; missing boards show water with a broken stub.
		var walk := width * 0.58
		var margin := (width - walk) * 0.5
		var drift := minf(3.0, maxf(margin - 1.0, 0.0))
		var wob_pos: Array[float] = []
		var wob_val: Array[float] = []
		var wp := 0.0
		while wp < len_total + 60.0:
			wob_pos.append(wp)
			wob_val.append(rng.randf_range(-drift, drift))
			wp += 60.0
		var planks := 0
		var missing := 0
		var prev_missing := false
		pos = inset
		while pos < len_total - inset - 4.0:
			var l := minf(6.0 + rng.randf() * 6.0, len_total - inset - pos)
			var pflag := ""
			var proll := rng.randf()
			planks += 1
			# GFX-141: a rotted board is rare (<= 1 in 14) and never two in a row
			if proll < 0.06 and not prev_missing and float(missing + 1) * 14.0 <= float(planks):
				pflag = "missing"
				missing += 1
			elif proll < 0.16:
				pflag = "dark"
			prev_missing = pflag == "missing"
			var mid := pos + l * 0.5
			var wi := mini(int(mid / 60.0), wob_pos.size() - 2)
			var centre_off := lerpf(wob_val[wi], wob_val[wi + 1], (mid - wob_pos[wi]) / 60.0)
			var jitter_a := float(rng.randi_range(0, 1))
			var jitter_b := float(rng.randi_range(0, 1))
			var across0 := margin + centre_off + jitter_a
			var board := _road_rect(path_rect, along_x, pos, across0, l - 1.0, walk - jitter_a - jitter_b)
			out.append({"kind": "plank", "rect": board, "shade": rng.randf() * 2.0 - 1.0, "flag": pflag})
			if pflag == "missing":  # a broken stub at one end
				var stub_len := rng.randf_range(2.0, 3.5)
				var top := rng.randf() < 0.5
				var sa := across0 if top else across0 + walk - jitter_a - jitter_b - stub_len
				out.append({"kind": "stub", "rect": _road_rect(path_rect, along_x, pos, sa, l - 1.0, stub_len), "shade": 0.0, "flag": ""})
			pos += l
		# wet verges and pilings
		for side in 2:
			var v_across := 0.0 if side == 0 else width - margin + drift
			var v_w := margin - drift if side == 0 else margin - drift
			if v_w >= 1.0:
				out.append({"kind": "mud", "rect": _road_rect(path_rect, along_x, 0.0, v_across, len_total, v_w), "shade": -1.0, "flag": ""})
		var pil_at := 10.0 + rng.randf() * 20.0
		while pil_at < len_total - 8.0:
			var wi2 := mini(int(pil_at / 60.0), wob_pos.size() - 2)
			var co := lerpf(wob_val[wi2], wob_val[wi2 + 1], (pil_at - wob_pos[wi2]) / 60.0)
			for pside in 2:
				var pa := margin + co - 2.0 if pside == 0 else margin + co + walk - 3.0
				var lean := float(rng.randi_range(1, 2)) * (1.0 if rng.randi_range(0, 1) == 0 else -1.0) if rng.randf() < 0.3 else 0.0  # GFX-162: a few lean 1-2 px
				out.append({"kind": "piling", "rect": _road_rect(path_rect, along_x, pil_at + lean, pa, 3.0, 5.0), "shade": 0.0, "flag": "lean" if lean != 0.0 else ""})
			pil_at += rng.randf_range(24.0, 60.0)  # GFX-162: uneven spacing
		var tuft_at := 6.0 + rng.randf() * 10.0
		while tuft_at < len_total - 8.0:
			for side in 2:
				var tn := rng.randi_range(0, 1) + 1
				for ti in tn:
					if margin - drift >= 4.0:
						var tx := tuft_at + rng.randf() * 18.0
						var tacross := rng.randf_range(0.5, margin - drift - 3.0) if side == 0 else width - margin + drift + rng.randf_range(0.0, maxf(margin - drift - 3.5, 0.0))
						out.append({"kind": "tuft", "rect": _road_rect(path_rect, along_x, tx, tacross, 2.0, 3.0), "shade": 1.0 if rng.randf() < 0.5 else -1.0, "flag": ["straight", "bent", "seed"][rng.randi_range(0, 2)]})  # GFX-162: three tuft shapes
			tuft_at += 40.0
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
		# GFX-141: two wheel tracks that wander together (one shared wobble per road), each 2-3 px thick, broken by 6-20 px gaps.
		var wobble: Array[float] = []  # one offset per 30-60 px stretch of road
		var wob_at: Array[float] = []
		var wpos := 0.0
		while wpos < len_total + 60.0:
			wob_at.append(wpos)
			wobble.append(rng.randf_range(-3.0, 3.0))
			wpos += rng.randf_range(30.0, 60.0)
		for off_f: float in [0.22, 0.74]:
			pos = rng.randf() * 10.0
			while pos < len_total:
				var l := minf(rng.randf_range(14.0, 36.0), len_total - pos)
				var wi := 0
				while wi + 1 < wob_at.size() and wob_at[wi + 1] <= pos:
					wi += 1
				var th2 := float(rng.randi_range(2, 3))
				var rr := _road_rect(path_rect, along_x, pos, track_offset(width, off_f, wobble[wi], th2), l, th2)
				var near := false
				for c in crossings:
					if c.intersects(rr):
						near = true
						break
				if not near:
					out.append({"kind": "rut", "rect": rr, "shade": -0.3, "flag": "slush" if winter else ""})
				pos += l + rng.randf_range(6.0, 20.0)
		if winter:  # footprints trodden between the tracks
			for i in int(len_total / 24.0):
				out.append({"kind": "print", "rect": _road_rect(path_rect, along_x, rng.randf() * maxf(len_total - 3.0, 0.0), width * rng.randf_range(0.36, 0.6), 3.0, 2.0), "shade": 0.0, "flag": ""})
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
		if not hit:
			kept.append(t)
	return kept


## GFX-149: the tiles of a mountain trail (scree ground): a wandering grit bed 60% of the road width, irregular stepping
## flagstones in the bed (1-2 abreast, 1 in 6 tilted as a `flag_poly` with `points`, 1 in 8 missing) and loose pebbles off the bed
## and along both edges. The road rect itself draws nothing. Appends to `out`.
static func _scree_trail_tiles(out: Array[Dictionary], rng: RandomNumberGenerator, path_rect: Rect2, along_x: bool, len_total: float, width: float) -> void:
	var bed_w := roundf(width * 0.6)
	var margin := (width - bed_w) * 0.5
	var drift := minf(4.0, maxf(margin - 1.0, 0.0))
	var knots: Array[float] = []
	var vals: Array[float] = []
	var kp := 0.0
	while kp < len_total + 80.0:
		knots.append(kp)
		vals.append(rng.randf_range(-drift, drift))
		kp += rng.randf_range(24.0, 40.0)
	# the grit bed in 8 px pieces so its edges follow the wander
	var gp := 0.0
	while gp < len_total:
		var gl := minf(8.0, len_total - gp)
		var off := _trail_offset(knots, vals, gp + gl * 0.5)
		out.append({"kind": "grit", "rect": _road_rect(path_rect, along_x, gp, margin + off, gl, bed_w), "shade": 0.0, "flag": ""})
		gp += gl
	# stepping stones
	var pos := rng.randf_range(2.0, 8.0)
	var prev_l := -1
	var prev_w := -1
	var count := 0
	while pos < len_total - 10.0:
		var lanes := 2 if rng.randf() < 0.3 else 1
		var step := 0.0
		var lane_w_total := 0.0
		var lane_defs: Array[Vector2] = []
		for ln in lanes:
			var sl := rng.randi_range(8, 18)
			var sw := rng.randi_range(6, 12)
			if lanes == 2:
				sw = mini(sw, int((bed_w - 6.0) / 2.0))
			if sl == prev_l and sw == prev_w:
				sl += 1 if sl < 18 else -1
			prev_l = sl
			prev_w = sw
			lane_defs.append(Vector2(float(sl), float(sw)))
			lane_w_total += float(sw)
			step = maxf(step, float(sl))
		var mid := pos + step * 0.5
		var centre := margin + _trail_offset(knots, vals, mid) + bed_w * 0.5
		var gap := 2.0 if lanes == 2 else 0.0
		var across := centre - (lane_w_total + gap) * 0.5 + rng.randf_range(-1.0, 1.0) * maxf(bed_w - lane_w_total - gap - 4.0, 0.0) * 0.4
		for ln in lanes:
			var d: Vector2 = lane_defs[ln]
			var rr := _road_rect(path_rect, along_x, pos + (step - d.x) * rng.randf(), across, d.x, d.y)
			across += d.y + gap
			count += 1
			var roll := rng.randf()
			var shade := rng.randf() * 2.0 - 1.0
			if roll < 1.0 / 8.0:
				continue  # missing: just grit
			if roll < 1.0 / 8.0 + 0.5:  # GFX-167: half the flags are irregular quads, not rectangles
				var pts := PackedVector2Array()
				var j := 1.4
				var corners := [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)]
				var inward := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
				for ci in 4:
					pts.append(corners[ci] + inward[ci] * rng.randf_range(0.0, j * 2.0))
				out.append({"kind": "flag_poly", "rect": rr, "points": pts, "shade": shade, "flag": ""})
			else:
				out.append({"kind": "slab", "rect": rr, "shade": shade, "flag": ""})
		pos += step + rng.randf_range(4.0, 14.0)
	# GFX-167: sparse short wheel ruts along the bed (about one per 70 px), never a regular pattern
	var rp := rng.randf_range(10.0, 40.0)
	while rp < len_total - 24.0:
		var rl := rng.randf_range(10.0, 22.0)
		var roff := _trail_offset(knots, vals, rp + rl * 0.5)
		out.append({"kind": "rut", "rect": _road_rect(path_rect, along_x, rp, margin + roff + bed_w * rng.randf_range(0.2, 0.7), rl, 1.0), "shade": 0.0, "flag": "trail"})
		rp += rl + rng.randf_range(40.0, 110.0)
	# pebbles: scattered off the bed (about 1 per 120 px^2) and small clusters along both edges every 30-60 px
	var off_area := maxf(width - bed_w, 0.0) * len_total
	for i in int(off_area / 120.0):
		var side := rng.randi() % 2
		var across := rng.randf_range(0.0, maxf(margin - drift - 2.0, 0.0)) if side == 0 else width - margin + drift + rng.randf_range(0.0, maxf(margin - drift - 2.0, 0.0))
		out.append({"kind": "pebble", "rect": _road_rect(path_rect, along_x, rng.randf() * maxf(len_total - 2.0, 0.0), across, 2.0, 2.0), "shade": rng.randf() * 2.0 - 1.0, "flag": ""})
	for side in 2:
		var cp := rng.randf_range(0.0, 30.0)
		while cp < len_total - 8.0:
			var base_across := 1.0 if side == 0 else width - 4.0
			for k in rng.randi_range(2, 4):
				out.append({"kind": "pebble", "rect": _road_rect(path_rect, along_x, cp + rng.randf_range(0.0, 6.0), base_across + rng.randf_range(0.0, 2.0) * (1.0 if side == 0 else -1.0), 2.0, 2.0), "shade": rng.randf() * 2.0 - 1.0, "flag": "edge"})
			cp += rng.randf_range(30.0, 60.0)


## GFX-172: a mountain stone road laid inside `rect`: a bed whose two long edges wander +-`amp` px (smooth seeded knots every ~28 px,
## `inset` px in from the rect so a verge shows) and irregular 4-6-sided flagstones of varied size in 2-3 staggered courses with earth
## gaps between them (about 1 in 7 missing). Returns {"bed": PackedVector2Array, "stones": Array[Dictionary{poly, shade}]}.
## Everything lies inside `rect`; the same seed gives the same road.
static func stone_road(rect: Rect2, seed_value: int, inset: float = 6.0, amp: float = 4.5) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "stone_road"])
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var width := rect.size.y if along_x else rect.size.x
	var ins := minf(inset, width * 0.2)
	var a := minf(amp, width * 0.15)
	var knots_lo: Array[float] = []
	var knots_hi: Array[float] = []
	for i in int(length / 28.0) + 3:
		knots_lo.append(rng.randf_range(-1.0, 1.0))
		knots_hi.append(rng.randf_range(-1.0, 1.0))
	var edge := func(p: float, hi: bool) -> float:
		var ks: Array[float] = knots_hi if hi else knots_lo
		var f := p / 28.0
		var i0 := int(f)
		var t := (1.0 - cos((f - float(i0)) * PI)) * 0.5
		var w := lerpf(ks[i0], ks[i0 + 1], t) * a
		return (width - ins + w) if hi else (ins + w)
	var at := func(p: float, o: float) -> Vector2:
		return rect.position + (Vector2(p, o) if along_x else Vector2(o, p))
	var lo: Array[Vector2] = []
	var hi_pts: Array[Vector2] = []
	var n := maxi(int(length / 6.0), 2)
	for i in n + 1:
		var p := length * float(i) / float(n)
		lo.append(at.call(p, edge.call(p, false)))
		hi_pts.append(at.call(p, edge.call(p, true)))
	var bed := PackedVector2Array()
	for q in lo:
		bed.append(q)
	for i in range(hi_pts.size() - 1, -1, -1):
		bed.append(hi_pts[i])
	var stones: Array[Dictionary] = []
	var lanes := 3 if width >= 54.0 else 2
	var cursors: Array[float] = []
	for k in lanes:
		cursors.append(rng.randf_range(2.0, 14.0))
	while true:
		var k := 0
		for j in lanes:
			if cursors[j] < cursors[k]:
				k = j
		if cursors[k] > length - 12.0:
			break
		var slen := minf(rng.randf_range(9.0, 20.0), length - 1.0 - cursors[k])
		if slen < 6.0:
			cursors[k] = length
			continue
		var mid: float = cursors[k] + slen * 0.5
		var blo: float = edge.call(mid, false) + 1.5
		var bhi: float = edge.call(mid, true) - 1.5
		var lane_w := (bhi - blo) / float(lanes)
		var l0 := blo + lane_w * float(k)
		var hy := maxf(lane_w * 0.5 - 1.5, 2.0) * rng.randf_range(0.8, 1.0)
		var hx := slen * 0.5 - 1.0
		var cy := l0 + lane_w * 0.5 + rng.randf_range(-1.0, 1.0)
		cursors[k] += slen + rng.randf_range(2.0, 4.0)
		if rng.randf() < 1.0 / 7.0:
			continue
		var sides := rng.randi_range(4, 6)
		var rot := rng.randf_range(0.0, 0.5)
		var poly := PackedVector2Array()
		for si in sides:
			var ang := rot + TAU * float(si) / float(sides) + rng.randf_range(-0.12, 0.12)
			var rr := rng.randf_range(0.85, 1.0) * 1.2
			var dx := clampf(cos(ang) * hx * rr, -hx, hx)
			var dy := clampf(sin(ang) * hy * rr, -hy, hy)
			poly.append(at.call(mid + dx, cy + dy))
		stones.append({"poly": poly, "shade": rng.randf_range(-1.0, 1.0)})
	return {"bed": bed, "stones": stones}


## GFX-185: a walked dirt road over `rect`: a wandering `verge` (the rect grown 2 px), a `bed` inside it, broken `ruts`
## (polylines at ~30% / 70% of the width, none under 24 px) and `tufts` ({pos, h}) on the verges and, on side lanes
## (width < 24), down the middle. `straight` rects (bridges, places; plus `bounds`, the map edge, when it has an area)
## keep both edges unwobbled within 10 px; `joins` (other path rects) make an end that meets one fan out 3 px.
static func dirt_road(rect: Rect2, seed_value: int, amp: float = 3.5, straight: Array[Rect2] = [], bounds: Rect2 = Rect2(), joins: Array[Rect2] = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "dirt_road"])
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var width := rect.size.y if along_x else rect.size.x
	var a := minf(amp, width * 0.2)
	var nk := int(length / 26.0) + 3
	var knots: Array[float] = []
	for i in nk * 4:
		knots.append(rng.randf_range(-1.0, 1.0))
	var wob := func(pp: float, k: int) -> float:
		var f := pp / 26.0
		var i0 := int(f)
		var t := (1.0 - cos((f - float(i0)) * PI)) * 0.5
		return lerpf(knots[k * nk + i0], knots[k * nk + i0 + 1], t)
	var at := func(pp: float, o: float) -> Vector2:
		return rect.position + (Vector2(pp, o) if along_x else Vector2(o, pp))
	var calm := func(pp: float) -> bool:
		for o: float in [0.0, width]:
			var q: Vector2 = at.call(pp, o)
			for sr in straight:
				if sr.grow(10.0).has_point(q):
					return true
			if bounds.has_area():
				if q.x - bounds.position.x < 10.0 or bounds.end.x - q.x < 10.0 or q.y - bounds.position.y < 10.0 or bounds.end.y - q.y < 10.0:
					return true
		return false
	var fan := func(pp: float) -> float:
		var out := 0.0
		for end_p: float in [0.0, length]:
			var d := absf(pp - end_p)
			if d >= 10.0:
				continue
			var q: Vector2 = at.call(end_p, width * 0.5) + (Vector2(-3.0 if end_p == 0.0 else 3.0, 0.0) if along_x else Vector2(0.0, -3.0 if end_p == 0.0 else 3.0))
			for jr in joins:
				if jr != rect and jr.grow(2.0).has_point(q):
					out = maxf(out, 3.0 * (1.0 - d / 10.0))
		return out
	var n := maxi(int(length / 6.0), 2)
	var v_lo: Array[Vector2] = []
	var v_hi: Array[Vector2] = []
	var b_lo: Array[Vector2] = []
	var b_hi: Array[Vector2] = []
	var tufts: Array[Dictionary] = []
	var next_tuft := [rng.randf_range(0.0, 18.0), rng.randf_range(0.0, 18.0)]
	var ruts: Array[PackedVector2Array] = []
	for i in n + 1:
		var pp := length * float(i) / float(n)
		var still: bool = calm.call(pp)
		var fn: float = fan.call(pp)
		var w0: float = 0.0 if still else float(wob.call(pp, 0)) * a
		var w1: float = 0.0 if still else float(wob.call(pp, 1)) * a
		var w2: float = 0.0 if still else float(wob.call(pp, 2)) * a * 0.5
		var w3: float = 0.0 if still else float(wob.call(pp, 3)) * a * 0.5
		v_lo.append(at.call(pp, -2.0 - fn + w0))
		v_hi.append(at.call(pp, width + 2.0 + fn + w1))
		b_lo.append(at.call(pp, 2.0 - fn * 0.5 + w2 if still else maxf(2.0 - fn * 0.5 + w2, 1.0)))
		b_hi.append(at.call(pp, width - 2.0 + fn * 0.5 + w3 if still else minf(width - 2.0 + fn * 0.5 + w3, width - 1.0)))
		for s in 2:
			while next_tuft[s] <= pp and next_tuft[s] < length:
				var edge_o: float = (-2.0 + w0) if s == 0 else (width + 2.0 + w1)
				var off := rng.randf_range(0.0, 2.0) * (-1.0 if s == 0 else 1.0)
				tufts.append({"pos": at.call(next_tuft[s], edge_o + off), "h": rng.randi_range(2, 4)})
				next_tuft[s] += rng.randf_range(12.0, 24.0)
	if width < 24.0:  # a lane: a sparse strip of grass down the middle
		var cp := rng.randf_range(20.0, 60.0)
		while cp < length - 12.0:
			tufts.append({"pos": at.call(cp, width * 0.5 + rng.randf_range(-1.0, 1.0)), "h": rng.randi_range(2, 3)})
			cp += rng.randf_range(40.0, 110.0)
	elif width >= 24.0:
		for frac: float in [0.3, 0.7]:
			var cur := rng.randf_range(0.0, 40.0)
			while cur < length - 10.0:
				var seg_len := rng.randf_range(40.0, 120.0)
				var end_p := minf(cur + seg_len, length)
				var pts := PackedVector2Array()
				var q := cur
				while q <= end_p:
					pts.append(at.call(q, width * frac + rng.randf_range(-1.0, 1.0)))
					q += 8.0
				if pts.size() >= 2:
					ruts.append(pts)
				cur = end_p + rng.randf_range(40.0, 120.0)
	var verge := PackedVector2Array()
	var bed := PackedVector2Array()
	for q in v_lo:
		verge.append(q)
	for q in b_lo:
		bed.append(q)
	for i in range(v_hi.size() - 1, -1, -1):
		verge.append(v_hi[i])
		bed.append(b_hi[i])
	return {"bed": bed, "verge": verge, "ruts": ruts, "tufts": tufts}


## GFX-167: a wobbling polygon for a trail along `path_rect`: the long edges are `inset` px in from the rect's sides plus a smooth
## seeded wobble of up to `amp` px (samples every 8 px), the ends square. `inset` + `amp` must stay below half the width.
## Deterministic; inside the rect.
static func trail_edge_polygon(path_rect: Rect2, seed_value: int, inset: float, amp: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "trail_edge"])
	var along_x := path_rect.size.x >= path_rect.size.y
	var len_total := path_rect.size.x if along_x else path_rect.size.y
	var width := path_rect.size.y if along_x else path_rect.size.x
	var ins := minf(inset, width * 0.4)  # the two edges never cross, so the polygon always triangulates
	var a := minf(amp, maxf((width * 0.5 - ins) * 0.5 - 0.5, 0.0))
	var n := maxi(int(len_total / 8.0), 2)
	var ph1 := rng.randf_range(0.0, TAU)
	var ph2 := rng.randf_range(0.0, TAU)
	var lo: Array[Vector2] = []
	var hi: Array[Vector2] = []
	for i in n + 1:
		var p := len_total * float(i) / float(n)
		var wob_a := (sin(ph1 + p / 23.0) * 0.6 + rng.randf_range(-0.4, 0.4)) * a
		var wob_b := (sin(ph2 + p / 29.0) * 0.6 + rng.randf_range(-0.4, 0.4)) * a
		var o1 := ins + a + wob_a
		var o2 := width - ins - a + wob_b
		if along_x:
			lo.append(Vector2(path_rect.position.x + p, path_rect.position.y + o1))
			hi.append(Vector2(path_rect.position.x + p, path_rect.position.y + o2))
		else:
			lo.append(Vector2(path_rect.position.x + o1, path_rect.position.y + p))
			hi.append(Vector2(path_rect.position.x + o2, path_rect.position.y + p))
	var out := PackedVector2Array()
	for q in lo:
		out.append(q)
	for i in range(hi.size() - 1, -1, -1):
		out.append(hi[i])
	return out


## GFX-149: the trail's sideways wander at `p` along the road (linear between the seeded knots).
static func _trail_offset(knots: Array[float], vals: Array[float], p: float) -> float:
	var i := 0
	while i + 2 < knots.size() and knots[i + 1] <= p:
		i += 1
	var span := maxf(knots[i + 1] - knots[i], 0.001)
	return lerpf(vals[i], vals[i + 1], clampf((p - knots[i]) / span, 0.0, 1.0))


## GFX-141: ragged road edges. Small rects (2-6 px deep, 6-20 px long) along both long edges every 10-30 px: a rect inside
## `path_rect` is a bite of verge into the road, one outside it is road spilling onto the verge. Skipped where a crossing road,
## a bridge or a place keepout of `region` meets the edge.
static func road_verge(path_rect: Rect2, seed_value: int, region: Dictionary = {}) -> Array[Rect2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var along_x := path_rect.size.x >= path_rect.size.y
	var len_total := path_rect.size.x if along_x else path_rect.size.y
	var width := path_rect.size.y if along_x else path_rect.size.x
	var map: Dictionary = region.get("map", {})
	var avoid: Array[Rect2] = []
	for lm: Dictionary in map.get("landmarks", []):
		if str(lm.get("kind", "")) == "stream":
			var sz: Array = lm["size"]
			var c: Array = lm["pos"]
			avoid.append(Rect2(float(c[0]) - float(sz[0]) * 0.5, float(c[1]) - float(sz[1]) * 0.5, float(sz[0]), float(sz[1])).grow(6.0))
	for pr: Variant in map.get("paths", []):
		var pa: Array = pr
		var other := Rect2(float(pa[0]), float(pa[1]), float(pa[2]), float(pa[3]))
		if other != path_rect and other.grow(8.0).intersects(path_rect):
			avoid.append(other.grow(8.0))
	for pl: Dictionary in region.get("places", []):
		avoid.append(Npcs.place_keepout(pl))
	var out: Array[Rect2] = []
	for side in 2:
		var pos := rng.randf_range(0.0, 12.0)
		while pos < len_total - 6.0:
			var l := minf(rng.randf_range(6.0, 20.0), len_total - pos)
			var depth := rng.randf_range(2.0, 6.0)
			var inward := rng.randf() < 0.5
			var across: float
			if side == 0:
				across = 0.0 if inward else -depth
			else:
				across = width - depth if inward else width
			var r := _road_rect(path_rect, along_x, pos, across, l, depth)
			var hit := false
			for a: Rect2 in avoid:
				if a.intersects(r):
					hit = true
					break
			if not hit:
				out.append(r)
			pos += l + rng.randf_range(10.0, 30.0)
	return out


## GFX-148: a 3-5 px ragged snow bank polygon along the outer long edge of a verge rect `v` (deterministic by seed).
static func snow_bank(v: Rect2, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var along_x := v.size.x >= v.size.y
	var len_total := v.size.x if along_x else v.size.y
	var n := maxi(int(len_total / 4.0), 2)
	var top := PackedVector2Array()
	var low := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var depth := rng.randf_range(3.0, 5.0)
		if i == 0 or i == n:
			depth = 1.5  # the bank tapers at both ends
		if along_x:
			top.append(Vector2(v.position.x + len_total * t, v.position.y - 1.0))
			low.append(Vector2(v.position.x + len_total * t, v.position.y - 1.0 + depth))
		else:
			top.append(Vector2(v.position.x - 1.0, v.position.y + len_total * t))
			low.append(Vector2(v.position.x - 1.0 + depth, v.position.y + len_total * t))
	low.reverse()
	var out := top
	out.append_array(low)
	return out


## GFX-148: the across-road offset of a wheel track: `frac` of the road `width`, plus `wobble`, clamped so a track of
## `thick` px stays on the road (narrow roads shrink the wobble to a tenth of their width).
static func track_offset(width: float, frac: float, wobble: float, thick: float) -> float:
	var lim := minf(3.0, width * 0.1)
	var off := width * frac - 1.0 + clampf(wobble, -lim, lim)
	return clampf(off, 0.0, maxf(width - thick, 0.0))


## GFX-148: a 3-4 board jetty from a raised platform `court` toward the nearest of `pools` (rects). Returns the boards
## (each 8 px long across 14 px of width, laid end to end) or [] when no pool is within 120 px of the platform.
static func platform_jetty(court: Rect2, pools: Array[Rect2]) -> Array[Rect2]:
	var best := INF
	var target := Vector2.ZERO
	for pr in pools:
		var near := Vector2(clampf(court.get_center().x, pr.position.x, pr.end.x), clampf(court.get_center().y, pr.position.y, pr.end.y))
		var edge := Vector2(clampf(near.x, court.position.x, court.end.x), clampf(near.y, court.position.y, court.end.y))
		var d := edge.distance_to(near)
		if d < best:
			best = d
			target = pr.get_center()
	if best > 120.0:
		return []
	var out: Array[Rect2] = []
	var dir := target - court.get_center()
	var horizontal := absf(dir.x) / maxf(court.size.x, 1.0) > absf(dir.y) / maxf(court.size.y, 1.0)
	var n := 4 if best > 24.0 else 3
	for i in n:
		if horizontal:
			var x := court.end.x + float(i) * 9.0 if dir.x > 0.0 else court.position.x - float(i + 1) * 9.0 + 1.0
			out.append(Rect2(x, clampf(target.y, court.position.y + 10.0, court.end.y - 10.0) - 7.0, 8.0, 14.0))
		else:
			var y := court.end.y + 10.0 + float(i) * 9.0 if dir.y > 0.0 else court.position.y - float(i + 1) * 9.0 + 1.0
			out.append(Rect2(clampf(target.x, court.position.x + 10.0, court.end.x - 10.0) - 7.0, y, 14.0, 8.0))
	return out


## GFX-148: an irregular low-alpha ground shadow polygon (lobed, radius varies >= 10%) under a building base.
static func shadow_blob(center: Vector2, radii: Vector2, seed_value: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2.from_angle(a) * radii * pond_mask_radius(a, seed_value, 0.15))
	return pts


static func _road_rect(path_rect: Rect2, along_x: bool, along: float, across: float, length: float, thick: float) -> Rect2:
	if along_x:
		return Rect2(path_rect.position.x + along, path_rect.position.y + across, length, thick)
	return Rect2(path_rect.position.x + across, path_rect.position.y + along, thick, length)


## GFX-113: map.high (a sect on a mountain): rail (bool: a carved rail round the sect hall court), wisps (int 0-8 drifting cloud wisps)
## lean_pines (int 0-8 pines leaning out over the top cliffs), crags (GFX-123, int 0-8 rock outcrops) drifts (int 0-12 snow drift patches) and peak (GFX-205, bool: PeakDressing cliff faces, terraces, stairs, pine clusters and mist).
const HIGH_KEYS: PackedStringArray = ["rail", "wisps", "lean_pines", "crags", "drifts", "peak"]
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
					elif key == "rail" or key == "peak":
						if not high[key] is bool:
							errors.append("Region '%s' map.high.%s must be a bool" % [region["id"], key])
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
		if region.get("map", {}).has("turf") and not (region["map"]["turf"] is String and String(region["map"]["turf"]).is_valid_html_color()):
			errors.append("Region '%s' map.turf must be a hex colour" % region["id"])  # GFX-220
		var speckle: Variant = region.get("map", {}).get("speckle", 1.0)  # GFX-164
		if not ((speckle is float or speckle is int) and float(speckle) >= 0.0 and float(speckle) <= 1.0):
			errors.append("Region '%s' map.speckle must be 0-1" % region["id"])
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
			elif key == "groves":
				if not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_GROVES:
					errors.append("Region '%s' map.decor.groves must be 0-%d" % [region["id"], MAX_GROVES])
			elif key == "undergrowth_kinds":
				var uk: Variant = decor[key]
				if not (uk is Dictionary) or (uk as Dictionary).is_empty():
					errors.append("Region '%s' map.decor.undergrowth_kinds must be a non-empty object" % region["id"])
				else:
					for ukey: Variant in uk:
						if not UNDERGROWTH_KINDS.has(String(ukey)) or not ((uk[ukey] is float or uk[ukey] is int) and float(uk[ukey]) > 0.0):
							errors.append("Region '%s' map.decor.undergrowth_kinds '%s' must be one of (%s) with weight > 0" % [region["id"], ukey, ", ".join(UNDERGROWTH_KINDS)])
			elif key == "edge_belt":
				if not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_EDGE_BELT:
					errors.append("Region '%s' map.decor.edge_belt must be 0-%d" % [region["id"], MAX_EDGE_BELT])
			elif key == "canopy_masses":
				if not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_CANOPY_MASSES:
					errors.append("Region '%s' map.decor.canopy_masses must be 0-%d" % [region["id"], MAX_CANOPY_MASSES])
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


## GFX-140: the layout of a tilled field inside `rect`: a ragged `outline`, alternating furrow `rows` ({rect, dark}) along
## the long side, and `crops` (Vector2 positions on the dark rows; none in winter) plus the `look` of GFX-096.
## Everything except the outline lies inside `rect.grow(-6)`; deterministic from `seed_value`.
static func field_layout(rect: Rect2, seed_value: int, season: String, no_snow: bool = false) -> Dictionary:
	var look := field_look(season, seed_value, no_snow)
	var vertical := rect.size.y > rect.size.x
	var inner := rect.grow(-6.0)
	var rows: Array[Dictionary] = []
	var crops: Array[Vector2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cross := inner.size.x if vertical else inner.size.y
	var along := inner.size.y if vertical else inner.size.x
	var i := 0
	while float(i + 1) * 4.0 <= cross:
		var band := Rect2(inner.position + (Vector2(i * 4.0, 0) if vertical else Vector2(0, i * 4.0)), Vector2(4.0, along) if vertical else Vector2(along, 4.0))
		var dark := i % 2 == 0
		rows.append({"rect": band, "dark": dark})
		if dark and look["style"] != "bare":
			var k := 3.0 + rng.randf_range(0.0, 3.0)
			while k < along - 3.0:
				var c := band.get_center()
				crops.append(Vector2(c.x, inner.position.y + k) if vertical else Vector2(inner.position.x + k, c.y))
				k += 8.0
		i += 1
	return {"outline": ragged_outline(rect, hash("%s|field" % seed_value), 16.0, 4.0), "rows": rows, "crops": crops,
		"look": look, "vertical": vertical}


## GFX-147/GFX-160: the bands of a hillside terrace inside `rect`: 3-4 wide flat strips stacked top to bottom, each spanning the
## full place width (2 px in from each side) with near-straight edges (a gentle 2-3 px seeded wobble). Neighbouring bands share
## one boundary curve (the upper band reaches 2 px under it), so the slope has no gaps. Bands stay inside `rect`; same seed,
## same bands. Returned top (highest) to bottom; points run along the upper edge left to right, then back along the lower edge.
## Fade the ends into the hillside with `terrace_end_alpha`.
static func terrace_bands(rect: Rect2, seed_value: int) -> Array[PackedVector2Array]:
	# GFX-167: each band has its own length (60-100% of the width, 12-px minimum slack kept) and offset, so the ends stagger
	# and the stack never reads as one rectangle. Top curve left to right, then the bottom curve right to left.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := 3 if rect.size.y < 90.0 else 4
	if rect.size.y >= 70.0 and rng.randi() % 2 == 0:
		n += 1
	var step := rect.size.y / float(n)
	var full := rect.size.x - 4.0
	var bow := terrace_bow(rect, seed_value)
	var cx := rect.get_center().x
	var half_w := maxf(rect.size.x / 2.0, 1.0)
	var out: Array[PackedVector2Array] = []
	for i in n:
		var length := full * rng.randf_range(0.6, 1.0)
		var left := rect.position.x + 2.0 + (full - length) * rng.randf_range(0.0, 1.0)
		var cols := maxi(int(length / 8.0), 4)
		var amp_t := rng.randf_range(1.0, 1.5)
		var amp_b := rng.randf_range(1.0, 1.5)
		var ph_t := rng.randf_range(0.0, TAU)
		var ph_b := rng.randf_range(0.0, TAU)
		var fq_t := rng.randf_range(1.0, 2.0)
		var fq_b := rng.randf_range(1.0, 2.0)
		var top_y := rect.position.y + step * float(i) + 1.0
		var bot_y := rect.position.y + step * float(i + 1) + 1.0
		if i == n - 1:
			bot_y = rect.end.y - 1.0 - 2.0 * amp_b - bow
		var poly := PackedVector2Array()
		for c in cols + 1:
			var t := float(c) / float(cols)
			var px := left + length * t
			var arc := bow * pow((px - cx) / half_w, 2.0)  # GFX-173: every band bows along one contour, ends lower than the middle
			poly.append(Vector2(px, top_y + arc + amp_t * (1.0 + sin(ph_t + TAU * fq_t * t)) + rng.randf_range(0.0, 0.4)))
		var drop := 2.0 if i < n - 1 else 0.0
		for c in range(cols, -1, -1):
			var t2 := float(c) / float(cols)
			var qx := left + length * t2
			var arc2 := bow * pow((qx - cx) / half_w, 2.0)
			poly.append(Vector2(qx, bot_y + arc2 + amp_b * (1.0 + sin(ph_b + TAU * fq_b * t2)) + rng.randf_range(0.0, 0.4) + drop))
		out.append(poly)
	return out


## GFX-173: how far the terrace steps' ends sag below their middles (3-6 px, scaled down for small places); the contour they follow.
static func terrace_bow(rect: Rect2, seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7919
	return minf(rng.randf_range(3.0, 6.0), rect.size.y / 10.0)


## GFX-173: the look of a terrace site by its name: "scorched" (Thunder-Struck), "orchid" (Cloud-Sea Orchid) or "plain".
static func terrace_variant(place_name: String) -> String:
	var n := place_name.to_lower()
	if n.contains("thunder") or n.contains("scorch"):
		return "scorched"
	if n.contains("orchid"):
		return "orchid"
	return "plain"


## GFX-173: a jagged lightning split from the top of the terrace down through its steps: points from `top` (upper edge) to
## `bottom`, zig-zagging up to 6 px sideways; deterministic per seed.
static func lightning_split(top: Vector2, bottom: Vector2, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array([top])
	var segs := 5
	for i in range(1, segs):
		var t := float(i) / float(segs)
		pts.append(top.lerp(bottom, t) + Vector2(rng.randf_range(-6.0, 6.0), 0.0))
	pts.append(bottom)
	return pts


## GFX-173: plant colours of a terrace variant (`tinted` tufts, plain tufts) given the season crop colour and place tint.
static func terrace_plant_colors(variant: String, plant: Color, tint: Color) -> Array[Color]:
	if variant == "scorched":
		return [Color("2a2622"), Color("3a332c")]
	if variant == "orchid":
		return [Color("e8e0f4"), plant.lerp(Color("c9b8e6"), 0.4)]
	return [tint.lerp(plant, 0.25), plant.darkened(0.1)]


## GFX-167: the x extents (left, right) of each band, for tests and the renderer.
static func terrace_band_spans(bands: Array[PackedVector2Array]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for poly in bands:
		out.append(Vector2(poly[0].x, poly[poly.size() / 2 - 1].x))
	return out


## GFX-160: opacity of a terrace band at `x`: it fades from 0 at either end into the hillside to 1 over `ramp` px.
static func terrace_end_alpha(x: float, left: float, right: float, ramp: float = 12.0) -> float:
	return clampf(minf(x - left, right - x) / ramp, 0.0, 1.0)


## GFX-160: the soil of band `i` on a hillside whose ground colour is `ground`: the ground warmed toward brown and darkened a
## little more for each band down (no fixed brown that reads as wood on slate ground); a grey cast in snow.
static func terrace_earth(ground: Color, i: int, snowy: bool) -> Color:
	var c := ground.lerp(Color("8a6a40"), 0.3).darkened(0.1 + 0.04 * float(i))
	if ground.get_luminance() < 0.4:  # GFX-166: on dark slate the band is a lighter weathered earth, not a dark box
		c = ground.lerp(Color("8a7a5c"), 0.45).lightened(0.1 - 0.04 * float(i))
	return c.lerp(Color("8a8f94"), 0.2) if snowy else c


## GFX-160: crop tufts of one band: 2-3 staggered rows of short tufts, as [{pos: Vector2, tinted: bool}]; every 3rd tuft of a
## row is `tinted` (the place colour), the rest are plain green. Tufts stay `margin` px inside the band's x range and 4 px off its edges.
static func terrace_crops(poly: PackedVector2Array, seed_value: int, margin: float = 10.0) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	var half := poly.size() / 2
	var cols := half - 1
	var minx: float = poly[0].x + margin
	var maxx: float = poly[half - 1].x - margin
	var rows := 2 if _band_height(poly) < 22.0 else 3
	for r in rows:
		var x := minx + float(r) * 3.0
		var n := 0
		while x < maxx:
			var t := clampf((x - poly[0].x) / maxf(poly[half - 1].x - poly[0].x, 1.0), 0.0, 1.0)
			var c := mini(int(t * float(cols)), cols - 1)
			var f := t * float(cols) - float(c)
			var up := lerpf(poly[c].y, poly[c + 1].y, f)
			var lo := lerpf(poly[poly.size() - 1 - c].y, poly[poly.size() - 2 - c].y, f)
			var y := lerpf(up + 4.0, lo - 4.0, (float(r) + 0.5) / float(rows))
			out.append({"pos": Vector2(x + rng.randf_range(-1.0, 1.0), y), "tinted": n % 3 == 1})
			n += 1
			x += rng.randf_range(8.0, 11.0)
	return out


static func _band_height(poly: PackedVector2Array) -> float:
	var half := poly.size() / 2
	return poly[poly.size() - 1 - half / 2].y - poly[half / 2].y


## GFX-153: how a snow drift of a ridge region looks in `season`: {show, scale: Vector2, color: Color, alpha, lumps}. Winter keeps the full white
## drift; spring and autumn leave a smaller, cool grey-blue remnant in 2-3 lumps (hidden in 1 of 2 drifts in spring, 2 of 3 in autumn); summer none.
static func drift_look(season: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "drift_look"])
	match season:
		"Winter":
			return {"show": true, "scale": Vector2.ONE, "color": Color("e8eef4"), "alpha": 1.0, "lumps": 1}
		"Summer":
			return {"show": false, "scale": Vector2.ONE, "color": Color("c9d3dc"), "alpha": 0.0, "lumps": 0}
		_:
			var hide_in := 2 if season == "Autumn" else 1
			var of := 3 if season == "Autumn" else 2
			return {"show": rng.randi() % of >= hide_in, "scale": Vector2(0.45, 0.6), "color": Color("c9d3dc"), "alpha": 0.85, "lumps": rng.randi_range(2, 3)}


## GFX-191: whether a ridge's (map.high) snow drifts draw at all: only in Winter; elsewhere the pale remnants read as glitches.
## Regions without map.high keep GFX-153's remnants.
static func drift_visible(season: String, map: Dictionary) -> bool:
	return season == "Winter" or not map.get("high", null) is Dictionary


## GFX-153: the lumps of a remnant drift as rects along `r` (a slice of its width each, 4-10 px gaps, hugging the foot of the ledge).
static func drift_lumps(r: Rect2, lumps: int, seed_value: int) -> Array[Rect2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "drift_lumps"])
	var out: Array[Rect2] = []
	var n := maxi(lumps, 1)
	var gaps := 0.0
	var gap_list: Array[float] = []
	for i in n - 1:
		gap_list.append(rng.randf_range(4.0, 10.0))
		gaps += gap_list[i]
	var w := maxf((r.size.x - gaps) / float(n), 4.0)
	var x := r.position.x
	for i in n:
		var h := r.size.y * rng.randf_range(0.7, 1.0)
		out.append(Rect2(x, r.end.y - h, w, h))
		x += w + (gap_list[i] if i < n - 1 else 0.0)
	return out


## GFX-167: a snow drift as a low mound: a flat base on r's bottom edge and a domed, slightly uneven top (no corners), so it
## blends into the snow instead of reading as a white bar. Points run along the base left to right, then back over the top.
## Always inside r; deterministic.
static func drift_mound(r: Rect2, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "drift_mound"])
	var n := maxi(int(r.size.x / 8.0), 6)
	var out := PackedVector2Array()
	out.append(Vector2(r.position.x, r.end.y))
	out.append(Vector2(r.end.x, r.end.y))
	for i in range(n - 1, 0, -1):  # the end points are the base corners already
		var t := float(i) / float(n)
		var dome := pow(sin(PI * t), 0.6)
		var h := r.size.y * dome * rng.randf_range(0.88, 1.0)
		out.append(Vector2(r.position.x + r.size.x * t, r.end.y - h))
	return out


## GFX-153: a crag silhouette for `r`: an uneven stepped top, sides sloping in (the top 6-12 px narrower than the base) and a base on r's
## bottom edge. Clockwise from the bottom-left; deterministic.
static func crag_outline(r: Rect2, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "crag_outline"])
	var inset := rng.randf_range(6.0, 12.0)
	var top_x0 := r.position.x + inset
	var top_x1 := r.end.x - inset
	var steps := rng.randi_range(3, 5)
	var out := PackedVector2Array()
	out.append(Vector2(r.position.x, r.end.y))
	out.append(Vector2(top_x0 + rng.randf_range(0.0, 2.0), r.position.y + r.size.y * 0.25))
	for i in steps + 1:
		var x := lerpf(top_x0, top_x1, float(i) / float(steps))
		out.append(Vector2(x, r.position.y + rng.randf_range(0.0, minf(10.0, r.size.y * 0.25))))
	out.append(Vector2(top_x1 - rng.randf_range(0.0, 2.0), r.position.y + r.size.y * 0.25))
	out.append(Vector2(r.end.x, r.end.y))
	return out


## GFX-164: the darker grit verge of a scree trail: the road rect, 5 px in from its sides, so it shows about 5 px outside the bed.
static func scree_verge_rect(path_rect: Rect2) -> Rect2:
	return path_rect.grow(-5.0)


## GFX-153: the bed colour of a scree trail (its grit) and the stone colour that sits on it: on a bed darker than 0.45 luminance the
## stones are lightened by 0.22 (and lit tops by a further 0.1, see `scree_stone_lit`), else they keep the road colour `base`.
## GFX-170: moss on a stone trail: small irregular patches inside the bed (a path_rect inset 3 px), [{rect: Rect2}]; deterministic.
static func moss_patches(path_rect: Rect2, seed_value: int) -> Array[Rect2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "moss"])
	var out: Array[Rect2] = []
	var along_x := path_rect.size.x >= path_rect.size.y
	var length := path_rect.size.x if along_x else path_rect.size.y
	var width := path_rect.size.y if along_x else path_rect.size.x
	var p := rng.randf_range(0.0, 20.0)
	while p < length - 12.0:
		var l := rng.randf_range(5.0, 14.0)
		var w := rng.randf_range(2.0, 5.0)
		var across := rng.randf_range(4.0, maxf(width - 4.0 - w, 4.5))
		out.append(Rect2(path_rect.position + (Vector2(p, across) if along_x else Vector2(across, p)), Vector2(l, w) if along_x else Vector2(w, l)))
		p += rng.randf_range(14.0, 40.0)
	return out


## GFX-170: grass tufts along both verges of a trail, just outside its rect (1-3 px), [{pos: Vector2, h: int}]; deterministic.
static func verge_tufts(path_rect: Rect2, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "tufts"])
	var out: Array[Dictionary] = []
	var along_x := path_rect.size.x >= path_rect.size.y
	var length := path_rect.size.x if along_x else path_rect.size.y
	for side in 2:
		var p := rng.randf_range(0.0, 16.0)
		while p < length:
			var off := rng.randf_range(1.0, 3.0)
			var across := (-off) if side == 0 else ((path_rect.size.y if along_x else path_rect.size.x) + off)
			out.append({"pos": path_rect.position + (Vector2(p, across) if along_x else Vector2(across, p)), "h": rng.randi_range(2, 4)})
			p += rng.randf_range(10.0, 34.0)
	return out


static func scree_bed_color(ground: Color) -> Color:
	return ground.lightened(0.12).lerp(Color("8a7a62"), 0.15)


static func scree_stone_base(base: Color, ground: Color) -> Color:
	return base.lightened(0.22) if scree_bed_color(ground).get_luminance() < 0.45 else base


static func scree_stone_lit(base: Color, ground: Color) -> Color:
	return scree_stone_base(base, ground).lightened(0.1) if scree_bed_color(ground).get_luminance() < 0.45 else base.lightened(0.05)


## GFX-150: the heights of a ledge's 3-6 steps along its length as fractions of its full height: always one step at 1.0 and one at
## <= 0.6, so the silhouette varies at least 40 %. `rising[i]` is true when step i is higher than the one before it (the lit top facet).
static func ledge_steps(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "ledge_steps"])
	var n := rng.randi_range(3, 6)
	var heights: Array[float] = []
	for i in n:
		heights.append(rng.randf_range(0.4, 1.0))
	var hi := rng.randi_range(0, n - 1)
	var lo := (hi + rng.randi_range(1, n - 1)) % n
	heights[hi] = 1.0
	heights[lo] = rng.randf_range(0.4, 0.6)
	var rising: Array[bool] = []
	for i in n:
		rising.append(i > 0 and heights[i] > heights[i - 1])
	return {"heights": heights, "rising": rising}


## GFX-150: 3-5 overlapping soft ellipses for a cloud wisp of `w` x `h`, [Rect2] relative to the wisp's top-left. Every ellipse is at
## least 10 px tall and 16 px wide, so a wisp never reads as a thin bar.
static func wisp_puffs(w: float, h: float, seed_value: int) -> Array[Rect2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "wisp_puffs"])
	var out: Array[Rect2] = []
	var hh := maxf(h, 14.0)
	for k in rng.randi_range(3, 5):
		var pw := maxf(w * rng.randf_range(0.28, 0.5), 16.0)
		var ph := clampf(hh * rng.randf_range(0.6, 1.0), 10.0, maxf(hh, 10.0))
		var cx := w * (0.15 + 0.7 * rng.randf())
		var cy := hh * rng.randf_range(0.35, 0.65)
		out.append(Rect2(cx - pw / 2.0, cy - ph / 2.0, pw, ph))
	return out


## GFX-150: 4-8 large soft tonal patches on a scree map (lichen, rust, shale), [{center, rx, ry, kind, seed}], seeded by the region id;
## no patch's bounding box touches a `keepouts` rect (paths, places).
static func ridge_patches(region: Dictionary, keepouts: Array[Rect2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	if String(map.get("ground_style", "")) != "scree":
		return out
	var size_arr: Array = map.get("size", [1600, 1000])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|ridge_patches")
	var kinds := ["lichen", "rust", "shale"]
	var want := rng.randi_range(4, 8)
	for attempt in 80:
		if out.size() >= want:
			break
		var rx := rng.randf_range(50.0, 110.0)
		var ry := rng.randf_range(30.0, 60.0)
		var c := Vector2(rng.randf_range(rx + 8.0, float(size_arr[0]) - rx - 8.0), rng.randf_range(ry + 8.0, float(size_arr[1]) - ry - 8.0))
		var box := Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0)
		var blocked := false
		for k in keepouts:
			if k.intersects(box):
				blocked = true
				break
		var kind: String = kinds[rng.randi() % 3]
		var sd := rng.randi()
		if not blocked:
			out.append({"center": c, "rx": rx, "ry": ry, "kind": kind, "seed": sd})
	return out


## GFX-220: olive alpine turf patches of a scree map, [{center, rx, ry, seed}] (ragged ovals), denser and larger near the
## road and the `places` rects, clear of every `keepouts` rect, seeded by the region id. Needs map.turf (a colour); else none.
static func ridge_turf(region: Dictionary, keepouts: Array[Rect2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Dictionary = region.get("map", {})
	if String(map.get("ground_style", "")) != "scree" or not map.has("turf"):
		return out
	var size_arr: Array = map.get("size", [1600, 1000])
	var near: Array[Rect2] = []
	for pr in map.get("paths", []):
		near.append(Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3])).grow(90.0))
	for p: Dictionary in region.get("places", []):
		var pos: Array = p.get("pos", [0, 0])
		near.append(Rect2(float(pos[0]) - 70.0, float(pos[1]) - 60.0, 140.0, 120.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|ridge_turf")
	for attempt in 160:
		if out.size() >= 22:
			break
		var rx := rng.randf_range(22.0, 54.0)
		var ry := rng.randf_range(12.0, 26.0)
		var c := Vector2(rng.randf_range(rx + 8.0, float(size_arr[0]) - rx - 8.0), rng.randf_range(ry + 8.0, float(size_arr[1]) - ry - 8.0))
		var box := Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0)
		var is_near := false
		for n in near:
			if n.has_point(c):
				is_near = true
				break
		if not is_near and rng.randf() > 0.1:
			continue  # lighter away from the road and places
		var blocked := false
		for k in keepouts:
			if k.intersects(box):
				blocked = true
				break
		if not blocked:
			out.append({"center": c, "rx": rx, "ry": ry, "seed": rng.randi(), "near": is_near})
	return out


## GFX-143: the layout of a rented field plot inside `rect` (GFX-140's field_layout look at the plot's own size). `stage` is the
## plot's crop state: -1 empty (bare furrows), 0..3 the growth stage of its most advanced crop (FieldPlots.growth_stage; 3 = ripe).
## Returns field_layout's keys plus `border` (1-2 low wattle/stone strips, Rect2, along the sides picked by the seed, outside the
## furrows), `crop_style` ("" | sprout | young | leafy | ripe), `crop_color`, `snow` (winter troughs) and `ripe`.
## Crops show whatever the season (a frozen field keeps its crop); empty plots show none.
static func plot_layout(rect: Rect2, seed_value: int, season: String, stage: int, no_snow: bool = false) -> Dictionary:
	var lay := field_layout(rect, seed_value, "Summer", no_snow)
	var snow := is_snowy(season) and not no_snow
	var look: Dictionary = lay["look"].duplicate()
	look["snow"] = snow
	var style := ""
	var color := Color("00000000")
	match stage:
		0:
			style = "sprout"
			color = Color("8fd16a")
		1:
			style = "young"
			color = Color("6fbf4c")
		2:
			style = "leafy"
			color = Color("3f8a30")
		3:
			style = "ripe"
			color = Color("d9aa3a")
	if style == "":
		lay["crops"] = [] as Array[Vector2]
	look["style"] = style if style != "" else "bare"
	look["color"] = color
	look["sheaves"] = false
	lay["look"] = look
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|border" % seed_value)
	var border: Array[Rect2] = []
	var first := rng.randi_range(0, 3)
	var picks: Array[int] = [first]
	if rng.randf() < 0.5:
		picks.append((first + 1) % 4)
	for side: int in picks:
		match side:
			0: border.append(Rect2(rect.position.x + 2.0, rect.position.y, rect.size.x - 4.0, 3.0))
			1: border.append(Rect2(rect.end.x - 3.0, rect.position.y + 2.0, 3.0, rect.size.y - 4.0))
			2: border.append(Rect2(rect.position.x + 2.0, rect.end.y - 3.0, rect.size.x - 4.0, 3.0))
			_: border.append(Rect2(rect.position.x, rect.position.y + 2.0, 3.0, rect.size.y - 4.0))
	lay["border"] = border
	lay["crop_style"] = style
	lay["crop_color"] = color
	lay["snow"] = snow
	lay["ripe"] = stage == 3
	return lay


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
	var want := rng.randi_range(10, 16)
	while pools.size() < want and tries < 800:
		tries += 1
		var rx := rng.randf_range(15.0, 45.0)  # GFX-136: pools 30-90 px wide
		var ry := rx * rng.randf_range(0.4, 0.65)
		var c := Vector2(rng.randf_range(rx + 40.0, size.x - rx - 40.0), rng.randf_range(ry + 40.0, size.y - ry - 40.0))
		var rect := Rect2(c - Vector2(rx, ry) * 1.2, Vector2(rx, ry) * 2.4)
		if _marsh_hits(rect, keepouts, taken, 14.0):
			continue
		var pts := PackedVector2Array()
		var n := 18
		var shape_seed := rng.randi()
		for i in n:
			var a := TAU * float(i) / float(n)
			var j := pond_mask_radius(a, shape_seed, 0.22) * rng.randf_range(0.94, 1.06)
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
	# GFX-136: dark mud patches, half-sunk bones and dead stumps on open ground (never on a keepout or a pool).
	var mud: Array[Dictionary] = []
	var bones: Array[Dictionary] = []
	var dead: Array[Dictionary] = []
	var mud_want := rng.randi_range(6, 10)
	tries = 0
	while mud.size() < mud_want and tries < 600:
		tries += 1
		var w := rng.randf_range(40.0, 90.0)
		var h := w * rng.randf_range(0.4, 0.6)
		var r := Rect2(Vector2(rng.randf_range(30.0, size.x - w - 30.0), rng.randf_range(30.0, size.y - h - 30.0)), Vector2(w, h))
		if _marsh_hits(r.grow(6.0), keepouts, taken, 8.0):
			continue
		taken.append(r)
		mud.append({"rect": r, "pts": ragged_outline(r, rng.randi(), minf(h * 0.45, 14.0), 4.0)})
	var dead_want := rng.randi_range(6, 10)
	tries = 0
	while dead.size() < dead_want and tries < 600:
		tries += 1
		var at := Vector2(rng.randf_range(40.0, size.x - 40.0), rng.randf_range(60.0, size.y - 40.0))
		var r := Rect2(at - Vector2(16, 40), Vector2(32, 46))
		if _marsh_hits(r, keepouts, taken, 6.0):
			continue
		taken.append(r)
		dead.append({"pos": at, "stump": rng.randf() < 0.4, "h": rng.randf_range(30.0, 48.0), "lean": rng.randf_range(-6.0, 6.0)})
	var bone_want := rng.randi_range(5, 8)
	tries = 0
	while bones.size() < bone_want and tries < 600:
		tries += 1
		var at := Vector2(rng.randf_range(40.0, size.x - 40.0), rng.randf_range(40.0, size.y - 40.0))
		var r := Rect2(at - Vector2(8, 5), Vector2(16, 10))
		if _marsh_hits(r, keepouts, taken, 4.0):
			continue
		taken.append(r)
		bones.append({"pos": at, "angle": rng.randf() * PI, "len": rng.randf_range(7.0, 12.0)})
	# GFX-177: reed fringes round every pool, floating dead leaves and low mist. A separate rng keeps the features above unchanged.
	var frng := RandomNumberGenerator.new()
	frng.seed = region_seed + 177
	var fringe: Array[Dictionary] = []
	var leaves: Array[Dictionary] = []
	var mist: Array[Dictionary] = []
	for pool: Dictionary in pools:
		var pc: Vector2 = pool["center"]
		var ppts: PackedVector2Array = pool["pts"]
		for i in ppts.size():
			if frng.randf() < 0.45:
				continue
			var at: Vector2 = pc + (ppts[i] - pc) * 1.2
			if _marsh_hits(Rect2(at - Vector2(4, 8), Vector2(8, 10)), keepouts, [], 0.0):
				continue
			fringe.append({"pos": at, "h": frng.randf_range(7.0, 13.0), "lean": frng.randf_range(-3.0, 3.0)})
		var pr: Rect2 = pool["rect"]
		for k in frng.randi_range(2, 4):
			var la := frng.randf() * TAU
			var lr := frng.randf_range(0.0, 0.55)
			leaves.append({"pos": pc + Vector2(cos(la) * pr.size.x * 0.4 * lr, sin(la) * pr.size.y * 0.4 * lr), "angle": frng.randf() * PI})
		mist.append({"pos": pc + Vector2(frng.randf_range(-10.0, 10.0), -pr.size.y * 0.1), "w": pr.size.x * frng.randf_range(0.9, 1.4)})
	return {"pools": pools, "reeds": reeds, "mud": mud, "bones": bones, "dead": dead, "fringe": fringe, "leaves": leaves, "mist": mist}

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


## GFX-135: how far out the pond's outer (bank) edge reaches along `angle`, as a fraction of the landmark ellipse: 0.72 .. 1.0.
static func pond_edge(angle: float, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	var v := 0.0
	var lobes := rng.randi_range(2, 3)
	for k in lobes:  # GFX-142: low-frequency lobes (period >= 120 degrees) make coves and a bulge
		var f := float(rng.randi_range(1, 3))
		v += rng.randf_range(0.6, 1.0) * sin(angle * f + rng.randf() * TAU) / float(lobes)
	var ripple := (pond_mask_radius(angle, seed, 0.12) - 1.0) / 0.12  # -1..1
	var e := 0.84 + 0.5 * v + 0.03 * ripple
	return clampf(e, 0.72, 1.0)


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


## GFX-178: amplitude (px) of a stream's meander (the bed swings this far either side of its axis).
const STREAM_AMP := 40.0
## GFX-178: distance (px) over which the meander eases in beyond the 24 px kept straight at a crossing or a place.
const STREAM_EASE := 60.0


## GFX-178: sideways offset (px, |x| <= STREAM_AMP) of a stream at world coordinate `along` its length: a seeded sine
## (wavelength 320-520 px) plus a smaller seeded harmonic, exactly 0 within 24 px of any `spans` entry (x = start, y = end
## along the same axis: path crossings, and places, jetties and spots near the axis) and easing in over the next STREAM_EASE px.
static func stream_offset(along: float, seed: int, spans: Array[Vector2]) -> float:
	var near := INF
	for sp in spans:
		near = minf(near, maxf(0.0, maxf(sp.x - along, along - sp.y)))
	if near <= 24.0:
		return 0.0
	var ease_in := clampf((near - 24.0) / STREAM_EASE, 0.0, 1.0)
	var wave := 320.0 + float(absi(seed) % 201)
	var phase := float(absi(seed / 7) % 628) / 100.0
	var phase2 := float(absi(seed / 11) % 628) / 100.0
	var v := sin(TAU * along / wave + phase) * 0.85 + sin(TAU * along / (wave * 0.41) + phase2) * 0.15
	return clampf(v * 1.15, -1.0, 1.0) * STREAM_AMP * ease_in


## GFX-178: the bed's width (px, 24-38) at `along`: breathes on a seeded wave, a steady 30 right at a bridge or place.
static func stream_width(along: float, seed: int, spans: Array[Vector2]) -> float:
	var near := INF
	for sp in spans:
		near = minf(near, maxf(0.0, maxf(sp.x - along, along - sp.y)))
	var ease_in := clampf((near - 24.0) / STREAM_EASE, 0.0, 1.0)
	var wave := 170.0 + float(absi(seed) % 130)
	var phase := float(absi(seed / 5) % 628) / 100.0
	return lerpf(30.0, 31.0 + sin(TAU * along / wave + phase) * 7.0, ease_in)


## GFX-135/178: the stretches along a stream landmark's axis where a path crosses it, or where a place, abode, jetty,
## other landmark, NPC spot, spawn or the arrival point lies within STREAM_AMP + 16 px of the axis (for stream_offset).
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
	var reach := r.grow(STREAM_AMP + 16.0)
	var boxes: Array[Rect2] = []
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var psz: Array = p.get("size", [64, 64])
		var pc := Vector2(float(p["pos"][0]), float(p["pos"][1]))
		boxes.append(Rect2(pc - Vector2(float(psz[0]), float(psz[1])) / 2.0, Vector2(float(psz[0]), float(psz[1]))))
	for o: Dictionary in region.get("map", {}).get("landmarks", []):
		var kind := String(o.get("kind", ""))
		if kind == "stream" or kind == "clouds":
			continue
		var osz := Vector2(float(o["size"][0]), float(o["size"][1]))
		var orect := Rect2(Vector2(float(o["pos"][0]), float(o["pos"][1])) - osz / 2.0, osz)
		boxes.append(jetty_layout(region, o)["rect"] if kind == "jetty" else orect)
	var pts: Array = region.get("npc_spots", []).duplicate()
	if region.has("spawn"):
		pts.append(region["spawn"])
	for pt: Array in pts:
		boxes.append(Rect2(float(pt[0]) - 8.0, float(pt[1]) - 8.0, 16.0, 16.0))
	for b in boxes:
		if b.intersects(reach):
			out.append(Vector2(b.position.x, b.end.x) if horizontal else Vector2(b.position.y, b.end.y))
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
static func marsh_keepouts(region: Dictionary, extra: Array[Rect2] = []) -> Array[Rect2]:
	var out := blocked_rects(region)
	for lm in landmark_rects(region):
		out.append(lm.grow(14.0))
	for p: Dictionary in region.get("places", []):  # GFX-136: the name label band above/below each place
		var pp: Array = p.get("pos", [0, 0])
		var ps: Array = p.get("size", [64, 64])
		out.append(Rect2(float(pp[0]) - maxf(float(ps[0]) / 2.0, 60.0), float(pp[1]) - float(ps[1]) / 2.0 - 36.0, maxf(float(ps[0]), 120.0), float(ps[1]) + 72.0))
	for spot: Array in region.get("npc_spots", []):
		out.append(Rect2(float(spot[0]) - 40.0, float(spot[1]) - 40.0, 80.0, 80.0))
	for e in extra:  # WU-564: e.g. the region gate (posts, roof, name board), which the world passes in
		out.append(e.grow(10.0))
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
## "cobbles": [Rect2] small dark block cobbles, "courts"/"lanes": [Rect2] flagstone floors (GFX-174), "scorch": [{center, radius}] around gather places with look crater}.
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
			var sc := Vector2(float(pos[0]), float(pos[1]))
			var srad := maxf(float(sz[0]), float(sz[1])) * 0.8
			var souts: Array[PackedVector2Array] = []  # GFX-138: five ragged nested outlines instead of plain circles
			for k in 5:
				var f := 1.0 - float(k) / 5.0
				souts.append(ragged_outline(Rect2(sc - Vector2(srad, srad) * f, Vector2(srad, srad) * 2.0 * f), hash("%s|scorch|%d" % [region.get("id", ""), k]), srad * f, maxf(3.0, srad * 0.07)))
			scorch.append({"center": sc, "radius": srad, "outlines": souts})
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
	# GFX-174: flagstone courts under the big halls and short cobbled lanes joining each stall to a street (all draw-only)
	var courts: Array[Rect2] = []
	var keeps: Array[Rect2] = []
	var linkable: Array[Rect2] = roads.duplicate()  # streets and the plaza
	var plz: Variant = map.get("plaza", null)
	if plz is Array and plz.size() == 4:
		linkable.append(Rect2(float(plz[0]), float(plz[1]), float(plz[2]), float(plz[3])))
	for pl: Dictionary in region.get("places", []):
		keeps.append(Npcs.place_keepout(pl))
	for pl: Dictionary in region.get("places", []):
		if not (str(pl.get("type", "")) in ["auction", "sect_hall", "workshop", "clinic"]):
			continue
		var k := Npcs.place_keepout(pl)
		var cr := Rect2(k.position - Vector2(14, 8), k.size + Vector2(28, 36))
		cr = cr.intersection(Rect2(Vector2(10, 10), size - Vector2(20, 20)))
		courts.append(cr)
		var link := _court_link(cr, linkable, keeps)  # GFX-200: the forecourt reaches the nearest street, so no hall stands in mud
		if link.size.x > 0.0:
			courts.append(link)
	var crater_bounds: Array[Rect2] = []
	for pl: Dictionary in region.get("places", []):
		if str(pl.get("look", "")) == "crater":
			var cc := Vector2(float(pl["pos"][0]), float(pl["pos"][1]))
			var cs: Array = pl.get("size", [100, 100])
			crater_bounds.append(Rect2(cc - Vector2(float(cs[0]), float(cs[1])) * 0.5, Vector2(float(cs[0]), float(cs[1]))).grow(52.0))
	var lanes: Array[Rect2] = []
	var lane_targets: Array[Rect2] = roads + courts  # GFX-176: a stall may also join a court or a building's front
	for pl: Dictionary in region.get("places", []):
		lane_targets.append(Npcs.place_keepout(pl))
	for i in lms.size():
		if str(map["landmarks"][i].get("kind", "")) != "stall":
			continue
		var lr: Rect2 = lms[i]
		var best := Rect2()
		var best_len := 1e9
		for rd in lane_targets:
			var lane := Rect2()
			if rd.size.x > rd.size.y:  # a vertical lane to a horizontal street
				var lx := lr.get_center().x - 6.0
				if lr.end.y <= rd.position.y:
					lane = Rect2(lx, lr.end.y, 12.0, rd.position.y - lr.end.y)
				elif lr.position.y >= rd.end.y:
					lane = Rect2(lx, rd.end.y, 12.0, lr.position.y - rd.end.y)
			else:  # a horizontal lane to a vertical street
				var ly := lr.get_center().y - 6.0
				if lr.end.x <= rd.position.x:
					lane = Rect2(lr.end.x, ly, rd.position.x - lr.end.x, 12.0)
				elif lr.position.x >= rd.end.x:
					lane = Rect2(rd.end.x, ly, lr.position.x - rd.end.x, 12.0)
			var ln := maxf(lane.size.x, lane.size.y)
			if ln > 0.0 and ln < best_len:
				best = lane
				best_len = ln
		if best.size.x > 0.0 and best_len <= 260.0 and best_len >= 10.0:  # GFX-176: every stall reaches its nearest street or court
			var lane_solid: Array[Rect2] = []  # places only (no label band: a lane may pass a name, it is floor)
			for pl: Dictionary in region.get("places", []):
				lane_solid.append(Npcs.place_keepout(pl).grow(-1.0))  # GFX-176: a lane may end right at a building front
			var bad := _market_blocked(best, [] as Array[Rect2], lane_solid, lms, 1.0, size, lr)
			for cb in crater_bounds:
				if cb.intersects(best):
					bad = true
			if not avenue.intersects(best) and not bad:
				lanes.append(best)
	var floors: Array[Rect2] = courts + lanes
	var planters: Array[Rect2] = []  # GFX-200: a few potted trees by hall doors (draw-only, kept off roads, places and stalls)
	for pl: Dictionary in region.get("places", []):
		if not (str(pl.get("type", "")) in ["auction", "sect_hall", "workshop", "clinic"]) or planters.size() >= 5:
			continue
		var pk := Npcs.place_keepout(pl)
		for sx in [-1.0, 1.0]:
			var pr := Rect2(pk.get_center().x + sx * 26.0 - 5.0, pk.end.y + 12.0, 10.0, 12.0)
			if planters.size() < 5 and not _market_blocked(pr, roads, solid, lms, 2.0, size, Rect2()) and not _hits_any(planters, pr.grow(6.0)):
				planters.append(pr)
	var patches: Array[Rect2] = []  # packed earth only toward the region edges and round the crater rim
	for i in 200:
		var pr := Rect2(rng.randf_range(20.0, size.x - 60.0), rng.randf_range(20.0, size.y - 40.0), rng.randf_range(24.0, 44.0), rng.randf_range(12.0, 22.0))
		var edge_d := minf(minf(pr.position.x, size.x - pr.end.x), minf(pr.position.y, size.y - pr.end.y))
		var rimmed := false
		for cb in crater_bounds:
			if cb.grow(36.0).intersects(pr):
				rimmed = true
		if patches.size() < 8 and (edge_d < 150.0 or rimmed) and not _market_blocked(pr, roads, solid, lms, 6.0, size, Rect2()) and not avenue.intersects(pr) and not _hits_any(floors, pr):
			patches.append(pr)
	var cobbles: Array[Rect2] = []
	for i in 600:
		var cr := Rect2(rng.randf_range(10.0, size.x - 16.0), rng.randf_range(10.0, size.y - 14.0), 5.0, 4.0)
		if not _market_blocked(cr, roads, solid, lms, 2.0, size, Rect2()) and not avenue.intersects(cr) and not _hits_any(floors, cr):
			cobbles.append(cr)
	var out := {"props": props, "patches": patches, "cobbles": cobbles, "scorch": scorch, "avenue": avenue, "avenue_slabs": _avenue_slabs(avenue), "ring": PackedVector2Array(), "shards": [] as Array[Rect2], "fence": [] as Array[Dictionary], "courts": courts, "lanes": lanes, "planters": planters}
	var arng := RandomNumberGenerator.new()
	arng.seed = hash("%s|avenue" % region.get("id", ""))
	# GFX-134: clusters of crates, barrels and sacks along the avenue (appended to props so they draw and test alike)
	var clusters := 0
	var tight: Array[Rect2] = []  # GFX-138: the avenue is hemmed in by places, so its crates keep only a thin margin from them
	for pl: Dictionary in region.get("places", []):
		tight.append(Npcs.place_keepout(pl).grow(2.0))
	var anchors: Array[float] = []  # GFX-138: cluster y positions, at least 120 px apart so they spread along the whole avenue
	for attempt in 400:
		if clusters >= 3:
			break
		var side := -1.0 if attempt % 2 == 0 else 1.0
		var cy := arng.randf_range(avenue.position.y + 30.0, avenue.end.y - 60.0)
		var near := false
		for ay in anchors:
			if absf(ay - cy) < 120.0:
				near = true
		if near:
			continue
		var cx := avenue.position.x - 22.0 if side < 0.0 else avenue.end.x + 8.0
		var placed: Array[Dictionary] = []
		for n in 3:
			var rect := Rect2(Vector2(cx + (float(n % 2) * 12.0 * -side), cy + float(n) * 11.0).round(), Vector2(10, 10))
			if _market_blocked(rect, roads, tight, lms, 1.0, size, Rect2()):
				continue
			var clash := false
			for q in props + placed:
				if (q["rect"] as Rect2).grow(2.0).intersects(rect):
					clash = true
			if not clash:
				placed.append({"kind": kinds[arng.randi() % 3], "rect": rect})
		if placed.size() >= 2:
			props.append_array(placed)
			anchors.append(cy)
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
		var kept: Array[Rect2] = []  # GFX-168: no paving stone inside the bowl; the avenue stops at its kerb
		for sl: Rect2 in out["avenue_slabs"]:
			if not slab_in_bowl(out["ring"], sl):
				kept.append(sl)
		out["avenue_slabs"] = kept
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
		var rim_flags: Array[Rect2] = []  # GFX-171: a ring path of loose flags just outside the rim, joining the avenue's end
		for i in 22:
			var fa := TAU * (float(i) + arng.randf_range(-0.2, 0.2)) / 22.0
			var fat := cpos + Vector2(cos(fa) * (ring_rect.size.x * 0.5 + 9.0), sin(fa) * (ring_rect.size.y * 0.5 + 9.0))
			var fr := Rect2((fat - Vector2(5, 4)).round(), Vector2(arng.randi_range(8, 11), arng.randi_range(6, 8)))
			if _market_blocked(fr, roads, inner_solid, lms, 1.0, size, Rect2()):
				continue
			rim_flags.append(fr)
		out["rim_flags"] = rim_flags
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
		# GFX-138: short second runs along the south side, one each side of the avenue road (never across it)
		for sx: float in [-1.0, 1.0]:
			var south_posts: Array[Rect2] = []
			for k in 4:
				var spr := Rect2(Vector2(cpos.x + sx * (45.0 + float(k) * 22.0) - 2.0, cpos.y + ring_rect.size.y * 0.5 + 4.0).round(), Vector2(4, 8))
				if not _market_blocked(spr, roads, inner_solid, lms, 2.0, size, Rect2()):
					south_posts.append(spr)
			if south_posts.size() >= 2:
				fence.append({"posts": south_posts})
		out["fence"] = fence
	_market_earth_dress(out, region, roads, solid, lms, size)
	return out


## GFX-171: the nested rings of a meteor crater, outermost first: [{frac, color, shift}]. `frac` scales the bowl outline about
## its centre (strictly shrinking inward), `shift` nudges that ring toward the lower right (so the upper-left lip reads lit),
## `color` is derived from the ground colour and never darker than ground.darkened(CRATER_FLOOR_DARKEN). Deterministic per seed.
const CRATER_FLOOR_DARKEN := 0.55

static func crater_rings(radius: float, seed: int, ground: Color = Color("6b6250")) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var limit := ground.darkened(CRATER_FLOOR_DARKEN)
	var tones: Array[float] = [-0.14, 0.12, 0.26, 0.4, 0.5]  # rim lightens, then darker slopes, floor at 0.5
	var out: Array[Dictionary] = []
	var fracs: Array[float] = [1.0, 0.9, 0.74, 0.58, 0.4]
	for i in fracs.size():
		var f: float = fracs[i] - rng.randf_range(0.0, 0.03) * float(i)
		var col: Color
		if i == 0:
			col = ground.lightened(0.12).blend(Color(0.55, 0.45, 0.3, 0.35))
		else:
			col = ground.darkened(tones[i]).blend(Color(0.2, 0.12, 0.08, 0.12))
		if col.get_luminance() < limit.get_luminance():
			col = limit
		out.append({"frac": f, "color": col, "shift": Vector2(1.0, 1.0) * radius * 0.04 * float(i)})
	return out


## GFX-168: true when a paving slab touches the crater bowl (any corner or its centre lies inside the ring polygon).
static func slab_in_bowl(ring: PackedVector2Array, slab: Rect2) -> bool:
	if ring.size() < 3:
		return false
	for pt: Vector2 in [slab.position, Vector2(slab.end.x, slab.position.y), slab.end, Vector2(slab.position.x, slab.end.y), slab.get_center()]:
		if Geometry2D.is_point_in_polygon(pt, ring):
			return true
	return false


## GFX-155: dress the packed earth between a market's streets: "loose_flags" [{rect, tilt}] (1 in 5 cells, a sixth of them
## tilted), "straw" [Vector2] wisps by stalls, "ruts" [PackedVector2Array] cart ruts that start at the avenue, and "kerbs"
## [Rect2] larger stones along each street edge. Nothing lies in a street, place or landmark (kerbs sit on the street edge).
static func _market_earth_dress(out: Dictionary, region: Dictionary, roads: Array[Rect2], solid: Array[Rect2], lms: Array[Rect2], size: Vector2) -> void:
	var rid := str(region.get("id", ""))
	var avenue: Rect2 = out["avenue"]
	var flags: Array[Dictionary] = []
	var cell := 16.0
	var cy := 0.0
	while cy < size.y:
		var cx := 0.0
		while cx < size.x:
			var h := absi(hash("%s|loose|%d|%d" % [rid, int(cx), int(cy)]))
			if h % 5 == 0:
				var fr := Rect2(Vector2(cx + 3.0 + float(h / 5 % 5), cy + 3.0 + float(h / 25 % 5)), Vector2(8, 6))
				if not _market_blocked(fr, roads, solid, lms, PAVED_REACH, size, Rect2()) and not avenue.grow(PAVED_REACH).intersects(fr):
					flags.append({"rect": fr, "tilt": (h / 125) % 6 == 0})
			cx += cell
		cy += cell
	out["loose_flags"] = flags
	var straw: Array[Vector2] = []
	for i in lms.size():
		if str(region["map"]["landmarks"][i].get("kind", "")) != "stall":
			continue
		var lr: Rect2 = lms[i]
		for n in 3:
			var h := absi(hash("%s|straw|%d|%d" % [rid, i, n]))
			var at := Vector2(lr.position.x - 10.0 + float(h % int(lr.size.x + 20.0)), lr.end.y + 3.0 + float(h / 7 % 10))
			var sr := Rect2(at, Vector2(6, 3))
			if not _market_blocked(sr, roads, solid, lms, 1.0, size, Rect2()):
				straw.append(at)
	out["straw"] = straw
	var ruts: Array[PackedVector2Array] = []
	if avenue.size.x > 0.0:
		for n in 3:
			var h := absi(hash("%s|rut|%d" % [rid, n]))
			var dir := -1.0 if n % 2 == 0 else 1.0
			var y0 := avenue.position.y + 40.0 + float(h % int(maxf(avenue.size.y - 80.0, 1.0)))
			var pt := Vector2(avenue.position.x if dir < 0.0 else avenue.end.x, y0)
			var line := PackedVector2Array([pt])
			for k in 14:
				pt += Vector2(dir * 9.0, sin(float(k) * 0.7 + float(h % 7)) * 2.0)
				if _market_blocked(Rect2(pt - Vector2(2, 2), Vector2(4, 4)), roads, solid, lms, 0.0, size, Rect2()) and not avenue.grow(2.0).has_point(pt):
					break
				line.append(pt)
			if line.size() >= 4:
				ruts.append(line)
	out["ruts"] = ruts
	var kerbs: Array[Rect2] = []
	for r in roads:
		var zone := r.grow(PAVED_REACH)
		for side in 2:
			var along_x := r.size.x > r.size.y
			var t := zone.position.x if along_x else zone.position.y
			var tend := zone.end.x if along_x else zone.end.y
			while t < tend:
				var fixed := (zone.position.y if side == 0 else zone.end.y - 6.0) if along_x else (zone.position.x if side == 0 else zone.end.x - 6.0)
				var kr := Rect2(Vector2(t, fixed), Vector2(12, 6)) if along_x else Rect2(Vector2(fixed, t), Vector2(6, 12))
				var crossing := false
				for r2 in roads:
					if r2 != r and r2.grow(PAVED_REACH - 2.0).intersects(kr):
						crossing = true
				if not crossing and kr.position.x >= 8.0 and kr.position.y >= 8.0 and kr.end.x <= size.x - 8.0 and kr.end.y <= size.y - 8.0:
					var blocked := false
					for k in solid:
						if k.intersects(kr):
							blocked = true
					for k in lms:
						if k.intersects(kr):
							blocked = true
					if not blocked:
						kerbs.append(kr)
				t += 13.0
	out["kerbs"] = kerbs


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
			stone_keep.append(Npcs.place_keepout(pl))  # GFX-138: the plain keepout (no extra margin) so the ring may wrap a cottage's far side
		stone_keep.append_array(landmark_rects(region))
		# GFX-138: try a dense ring of angles so the free sides still get an arc of at least 8 stones when a cottage blocks one side
		for i in 30:
			if stones.size() >= 14:
				break
			var a := TAU * float(i) / 30.0 + rng.randf_range(-0.08, 0.08)
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
const YARD_PATH_FALLBACK := 520.0  # GFX-138: a house that finds no short path may take a longer one round a field
const YARD_PATH_MAX_PLACE := 420.0  # GFX-132: temple, workshop, clinic, sect hall may sit further from a road
const YARD_PROP_SIZES := {"woodpile": Vector2(20, 12), "water_jar": Vector2(10, 12), "veg_row": Vector2(36, 20), "washing_line": Vector2(40, 24), "bench": Vector2(22, 10), "drying_rack": Vector2(34, 18), "cat": Vector2(12, 8), "hens": Vector2(34, 10)}


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
			if float(c["len"]) > limit and not (own_pl[b] < 0 and float(c["len"]) <= YARD_PATH_FALLBACK):
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
		kinds.erase("hens")  # WU-564: hens only ever come with the Hen Coop (below)
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
	var coop := Critters.coop_rect(region)  # WU-564: three hens pecking just in front of the Hen Coop's door
	if coop.size != Vector2.ZERO:
		var hsz: Vector2 = YARD_PROP_SIZES["hens"]
		var hrect := Rect2(coop.get_center().x - hsz.x / 2.0, coop.end.y + 6.0, hsz.x, hsz.y)
		if not _market_blocked(hrect, [] as Array[Rect2], [] as Array[Rect2], [] as Array[Rect2], 0.0, size, Rect2()):
			props_out.append({"kind": "hens", "rect": hrect})
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


static func _hits_any(rects: Array[Rect2], r: Rect2) -> bool:
	for q in rects:
		if q.grow(2.0).intersects(r):
			return true
	return false


## GFX-200: a 28 px flagstone strip from a court to the nearest road (empty when it already touches one or a place is in the way).
static func _court_link(court: Rect2, roads: Array[Rect2], solid: Array[Rect2]) -> Rect2:
	var best := Rect2()
	var best_len := 1e9
	for rd in roads:
		if rd.intersects(court):
			return Rect2()
		var link := Rect2()
		if rd.size.x > rd.size.y:
			var lx := court.get_center().x - 14.0
			if court.end.y <= rd.position.y:
				link = Rect2(lx, court.end.y, 28.0, rd.position.y - court.end.y)
			elif court.position.y >= rd.end.y:
				link = Rect2(lx, rd.end.y, 28.0, court.position.y - rd.end.y)
		else:
			var ly := court.get_center().y - 14.0
			if court.end.x <= rd.position.x:
				link = Rect2(court.end.x, ly, rd.position.x - court.end.x, 28.0)
			elif court.position.x >= rd.end.x:
				link = Rect2(rd.end.x, ly, court.position.x - rd.end.x, 28.0)
		var ln := maxf(link.size.x, link.size.y)
		if ln > 0.0 and ln < best_len:
			best = link
			best_len = ln
	if best_len > 300.0:
		return Rect2()
	for r in solid:
		if r.grow(-2.0).intersects(best):
			return Rect2()
	return best


## GFX-200: 3 px stone gutters along both sides of the longest east-west street, broken where another street crosses.
static func street_gutters(map: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var main := Rect2()
	var others: Array[Rect2] = []
	for r in map.get("paths", []):
		var rc := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		if rc.size.x > rc.size.y and rc.size.x > main.size.x:
			if main.size.x > 0.0:
				others.append(main)
			main = rc
		else:
			others.append(rc)
	if main.size.x <= 0.0:
		return out
	for edge_y in [main.position.y - 3.0, main.end.y]:
		var x := main.position.x
		var cuts: Array[Vector2] = []
		for o in others:
			if o.size.y > o.size.x and o.position.x < main.end.x and o.end.x > main.position.x:
				cuts.append(Vector2(o.position.x, o.end.x))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for c in cuts:
			if c.x > x:
				out.append(Rect2(x, edge_y, c.x - x, 3.0))
			x = maxf(x, c.y)
		if x < main.end.x:
			out.append(Rect2(x, edge_y, main.end.x - x, 3.0))
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
		if pr.grow(-minf(10.0, minf(pr.size.x, pr.size.y) * 0.4)).intersects(Rect2(at - Vector2(2, 2), Vector2(4, 4))):
			return
	var stalks: Array[Dictionary] = []
	for i in rng.randi_range(3, 7):
		stalks.append({"dx": rng.randf_range(-10.0, 10.0), "h": rng.randf_range(12.0, 22.0)})
	clump_rects.append(rect)
	out.append({"pos": at, "stalks": stalks})
