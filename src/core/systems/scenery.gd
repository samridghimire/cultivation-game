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
		for i in clampi(int(cfg[count_key(kind)]), 0, MAX_COUNT):
			for attempt in TRIES:
				var pos := Vector2(rng.randf_range(EDGE, size.x - EDGE), rng.randf_range(EDGE, size.y - EDGE))
				if is_clear(pos, blocked, spots):
					out.append({"kind": kind, "pos": pos, "scale": rng.randf_range(0.8, 1.25), "color": color})
					break
	return out


## Paths as-is, places and abodes grown by CLEARANCE (both are centered on pos).
static func blocked_rects(region: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in region.get("map", {}).get("paths", []):
		out.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var pos: Array = p.get("pos", [0, 0])
		var sz: Array = p.get("size", [64, 64])
		var size := Vector2(float(sz[0]), float(sz[1]))
		out.append(Rect2(Vector2(float(pos[0]), float(pos[1])) - size / 2.0, size).grow(CLEARANCE))
	return out


static func is_clear(pos: Vector2, blocked: Array[Rect2], spots: Array[Vector2]) -> bool:
	for r in blocked:
		if r.has_point(pos):
			return false
	for s in spots:
		if pos.distance_to(s) < SPOT_RADIUS + CLEARANCE:
			return false
	return true


## Load errors for map.decor in data/regions.json.
static func validate(data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	for region: Dictionary in data.regions.values():
		var decor: Variant = region.get("map", {}).get("decor", {})
		if not decor is Dictionary:
			errors.append("Region '%s' map.decor must be an object" % region["id"])
			continue
		for key in decor:
			if not DEFAULTS.has(key):
				errors.append("Region '%s' map.decor has unknown key '%s'" % [region["id"], key])
			elif String(key).ends_with("_color"):
				if not (decor[key] is String and Color.html_is_valid(decor[key])):
					errors.append("Region '%s' map.decor.%s is not a color" % [region["id"], key])
			elif not (decor[key] is float or decor[key] is int) or int(decor[key]) < 0 or int(decor[key]) > MAX_COUNT:
				errors.append("Region '%s' map.decor.%s must be 0-%d" % [region["id"], key, MAX_COUNT])
	return errors
