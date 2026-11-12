class_name MarketLayout
extends RefCounted
## GFX-119: pure, seeded layout of a bustling market (`map.market`): small awning stalls, handcarts, lantern strings
## between neighbouring stalls and the front-of-stall waypoints ambient shoppers walk between. No Nodes, no randomness
## outside the region-id seed, so a market always looks the same.

const KEYS: PackedStringArray = ["stalls", "carts", "shoppers"]
const STALL_MAX := 16
const CART_MAX := 4
const SHOPPER_MAX := 6
const STALL_SIZE := Vector2(60.0, 36.0)
const CART_SIZE := Vector2(40.0, 24.0)
const ROAD_REACH := 150.0  # a stall stands within this of a road...
const CRATER_REACH := 230.0  # ...or of the gather (crater) place
const GAP := 14.0  # air kept round places, paths, labels and other stalls
const STRING_REACH := 170.0
const TRIES := 400
const AWNINGS: Array[String] = ["c23b2e", "d9a441", "3f6e8c", "7a4fa0", "6f9f4a", "e8d28a"]
const GOODS: PackedStringArray = ["crates", "jars", "cloth", "scrolls", "fruit"]


## Count of `key` in the region's map.market (0 without one).
static func count(region: Dictionary, key: String) -> int:
	var m: Variant = region.get("map", {}).get("market", null)
	if not m is Dictionary:
		return 0
	return int(m.get(key, 0))


## {stalls: [{rect, awning: String, goods: String, seed}], carts: [{rect, seed}], strings: [[Vector2, Vector2]], fronts: [Vector2]}.
static func layout(region: Dictionary) -> Dictionary:
	var out := {"stalls": [], "carts": [], "strings": [], "fronts": []}
	var map: Dictionary = region.get("map", {})
	if not map.get("market", null) is Dictionary:
		return out
	var size_arr: Array = map.get("size", [1600, 1000])
	var bounds := Rect2(Vector2.ZERO, Vector2(float(size_arr[0]), float(size_arr[1]))).grow(-40.0)
	var forbid: Array[Rect2] = []
	var roads: Array[Rect2] = []
	for r in map.get("paths", []):
		var pr := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		roads.append(pr)
		forbid.append(pr.grow(GAP))
	var crater := Vector2(-1e9, -1e9)
	for p: Dictionary in region.get("places", []) + region.get("abodes", []):
		var pos := Vector2(float(p["pos"][0]), float(p["pos"][1]))
		var sz := Vector2(float(p["size"][0]), float(p["size"][1]))
		# Room above for the place label and below for the [E] chip.
		forbid.append(Rect2(pos - sz / 2.0, sz).grow(GAP).grow_individual(0.0, 22.0, 0.0, 22.0))
		if String(p.get("type", "")) == "gather":
			crater = pos
	forbid.append_array(Scenery.landmark_rects(region))
	var points: Array[Vector2] = [Vector2(float(region.get("spawn", [0, 0])[0]), float(region.get("spawn", [0, 0])[1]))]
	for s in region.get("npc_spots", []):
		points.append(Vector2(float(s[0]), float(s[1])))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(region.get("id", "")) + "|market")
	var taken: Array[Rect2] = []
	var stalls: Array = out["stalls"]
	var want_stalls := clampi(count(region, "stalls"), 0, STALL_MAX)
	for i in TRIES:
		if stalls.size() >= want_stalls:
			break
		var rect := Rect2(Vector2(rng.randf_range(bounds.position.x, bounds.end.x - STALL_SIZE.x), rng.randf_range(bounds.position.y, bounds.end.y - STALL_SIZE.y)).round(), STALL_SIZE)
		if not _near_road(rect, roads, crater) or not _fits(rect, bounds, forbid, taken, points):
			continue
		taken.append(rect.grow(GAP))
		stalls.append({"rect": rect, "awning": AWNINGS[rng.randi() % AWNINGS.size()], "goods": GOODS[rng.randi() % GOODS.size()], "seed": rng.randi()})
	var carts: Array = out["carts"]
	var want_carts := clampi(count(region, "carts"), 0, CART_MAX)
	for i in TRIES:
		if carts.size() >= want_carts:
			break
		var rect := Rect2(Vector2(rng.randf_range(bounds.position.x, bounds.end.x - CART_SIZE.x), rng.randf_range(bounds.position.y, bounds.end.y - CART_SIZE.y)).round(), CART_SIZE)
		if not _near_road(rect, roads, crater) or not _fits(rect, bounds, forbid, taken, points):
			continue
		taken.append(rect.grow(GAP))
		carts.append({"rect": rect, "seed": rng.randi()})
	# Lantern strings: each stall to its nearest right-hand neighbour in the same row (centres within STRING_REACH).
	var strings: Array = out["strings"]
	for a in stalls:
		var best: Variant = null
		var best_d := STRING_REACH
		for b in stalls:
			var ca: Vector2 = (a["rect"] as Rect2).get_center()
			var cb: Vector2 = (b["rect"] as Rect2).get_center()
			if cb.x > ca.x and absf(cb.y - ca.y) < 40.0 and ca.distance_to(cb) < best_d:
				best_d = ca.distance_to(cb)
				best = b
		if best != null:
			strings.append([(a["rect"] as Rect2).get_center() + Vector2(0, -STALL_SIZE.y / 2.0 - 4.0), (best["rect"] as Rect2).get_center() + Vector2(0, -STALL_SIZE.y / 2.0 - 4.0)])
	# Shopper waypoints: just in front of each stall, where that spot is open ground.
	var fronts: Array = out["fronts"]
	for s in stalls:
		var r: Rect2 = s["rect"]
		var f := Vector2(r.get_center().x, r.end.y + 16.0)
		if bounds.has_point(f) and not _in_any(f, forbid, r):
			fronts.append(f)
	return out


static func _near_road(rect: Rect2, roads: Array[Rect2], crater: Vector2) -> bool:
	for r in roads:
		if r.grow(ROAD_REACH).intersects(rect):
			return true
	return rect.get_center().distance_to(crater) < CRATER_REACH


static func _fits(rect: Rect2, bounds: Rect2, forbid: Array[Rect2], taken: Array[Rect2], points: Array[Vector2]) -> bool:
	if not bounds.encloses(rect):
		return false
	for f in forbid:
		if f.intersects(rect):
			return false
	for t in taken:
		if t.intersects(rect):
			return false
	for p in points:
		if rect.grow(24.0).has_point(p):
			return false
	return true


static func _in_any(p: Vector2, rects: Array[Rect2], own: Rect2) -> bool:
	for r in rects:
		if r.has_point(p) and not own.grow(GAP).has_point(p):
			return true
	return false


## Where shopper `n` stands `t` seconds into the day-seeded walk between the stalls' `fronts`: it dwells at a front,
## then strolls to the next one the seed picks. Static (the first front) when `moving` is false or there are fewer than two fronts.
static func shopper_pos(fronts: Array, region_id: String, day: int, n: int, t: float, moving: bool) -> Vector2:
	if fronts.is_empty():
		return Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([region_id, "|shopper", day, n])
	var cur := rng.randi() % fronts.size()
	if not moving or fronts.size() < 2:
		return fronts[cur]
	var clock := t
	for leg in 64:
		var nxt := (cur + 1 + rng.randi() % (fronts.size() - 1)) % fronts.size()
		var dwell := rng.randf_range(2.0, 5.0)
		if clock < dwell:
			return fronts[cur]
		clock -= dwell
		var walk: float = (fronts[cur] as Vector2).distance_to(fronts[nxt]) / 28.0
		if clock < walk:
			return (fronts[cur] as Vector2).lerp(fronts[nxt], clock / maxf(walk, 0.01))
		clock -= walk
		cur = nxt
	return fronts[cur]


## Load errors for map.market.
static func validate(region: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var m: Variant = region.get("map", {}).get("market", null)
	if m == null:
		return errors
	if not m is Dictionary:
		errors.append("Region '%s' map.market must be an object" % region["id"])
		return errors
	for key in m:
		var cap := STALL_MAX if key == "stalls" else (CART_MAX if key == "carts" else SHOPPER_MAX)
		if not KEYS.has(String(key)):
			errors.append("Region '%s' map.market has unknown key '%s'" % [region["id"], key])
		elif not (m[key] is float or m[key] is int) or int(m[key]) < 0 or int(m[key]) > cap:
			errors.append("Region '%s' map.market.%s must be 0-%d" % [region["id"], key, cap])
	return errors
