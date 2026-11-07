class_name Critters
extends RefCounted
## GFX-086: pure rules for the small ambient critters of a village map (hens, ducks, butterflies).
## regions.json `map.ambient_critters: [{kind, pos: [x, y]}]`; the world draws what `today` returns.
## Chimney smoke already lives in VillageLife (GFX-040), so it is not a critter kind.

const KINDS: PackedStringArray = ["hen", "duck", "butterfly"]
## Every critter kind that may appear in a given season (lower-case or capitalised both work).
const SEASONS := {
	"hen": ["spring", "summer", "autumn", "winter"],
	"duck": ["spring", "summer", "autumn"],  # the pond is frozen in winter
	"butterfly": ["spring", "summer"],
}
## A duck must float this far inside a pond's bounding rect.
const WATER_MARGIN := 6.0


## CRIT-001: world flag key holding {day, taken: [entry indexes]} of the eggs picked today.
static func egg_flag(region_id: String) -> String:
	return "eggs_" + region_id


## CRIT-001: today's eggs for a region's `entries` (its map.ambient_critters): [{index, pos, item}], at most one per
## hen that has `lays`, near the hen's pos. Pure, seeded by region id and day; hens only lay in season.
static func eggs_today(region_id: String, entries: Array, day: int, season: String = "spring") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in entries.size():
		var e: Dictionary = entries[i]
		if String(e.get("kind", "")) != "hen" or not e.has("lays") or not in_season("hen", season):
			continue
		var lays: Dictionary = e["lays"]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("egg:%s:%d:%d" % [region_id, day, i])
		if rng.randf() >= float(lays.get("chance", 0.0)):
			continue
		var pos := Vector2(float(e["pos"][0]), float(e["pos"][1])) + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(10.0, 26.0))
		out.append({"index": i, "pos": pos, "item": String(lays["item"])})
	return out


## Eggs not yet picked today, given the world flags.
static func eggs_left(region_id: String, entries: Array, day: int, flags: Dictionary, season: String = "spring") -> Array[Dictionary]:
	var rec: Variant = flags.get(egg_flag(region_id))
	var taken: Array = []
	if rec is Dictionary and int(rec.get("day", -1)) == day:
		for t: Variant in rec.get("taken", []):
			taken.append(int(t))  # JSON saves hand back floats
	return eggs_today(region_id, entries, day, season).filter(func(e: Dictionary) -> bool: return not taken.has(int(e["index"])))


## Marks entry `index` picked today (the record is overwritten on a new day).
static func mark_egg(flags: Dictionary, region_id: String, index: int, day: int) -> void:
	var rec: Variant = flags.get(egg_flag(region_id))
	var taken: Array = []
	if rec is Dictionary and int(rec.get("day", -1)) == day:
		for t: Variant in rec.get("taken", []):
			taken.append(int(t))
	taken.append(index)
	flags[egg_flag(region_id)] = {"day": day, "taken": taken}


## Errors for one region's `map.ambient_critters` (empty when fine).
static func validate(region: Dictionary, items: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	var map: Dictionary = region.get("map", {})
	if not map.has("ambient_critters"):
		return errors
	var rid := String(region.get("id", "?"))
	var list: Variant = map["ambient_critters"]
	if not list is Array:
		errors.append("Region '%s' map.ambient_critters must be an array" % rid)
		return errors
	var size := Vector2(1600, 1000)
	if map.has("size") and map["size"] is Array and (map["size"] as Array).size() == 2:
		size = Vector2(float(map["size"][0]), float(map["size"][1]))
	for i in (list as Array).size():
		var e: Variant = list[i]
		if not e is Dictionary:
			errors.append("Region '%s' map.ambient_critters[%d] must be an object" % [rid, i])
			continue
		var kind := String(e.get("kind", ""))
		if not KINDS.has(kind):
			errors.append("Region '%s' map.ambient_critters[%d] kind '%s' is not one of %s" % [rid, i, kind, ", ".join(KINDS)])
			continue
		var pos: Variant = e.get("pos", null)
		if not (pos is Array and (pos as Array).size() == 2 and (pos[0] is float or pos[0] is int) and (pos[1] is float or pos[1] is int)):
			errors.append("Region '%s' map.ambient_critters[%d] pos must be [x, y]" % [rid, i])
			continue
		if e.has("lays"):
			var lays: Variant = e["lays"]
			if kind != "hen" or not (lays is Dictionary):
				errors.append("Region '%s' map.ambient_critters[%d] lays is only for a hen, as {item, chance}" % [rid, i])
			else:
				var ch: Variant = lays.get("chance")
				if not (ch is float or ch is int) or float(ch) < 0.0 or float(ch) > 1.0:
					errors.append("Region '%s' map.ambient_critters[%d] lays.chance must be 0..1" % [rid, i])
				if not items.is_empty() and not items.has(String(lays.get("item", ""))):
					errors.append("Region '%s' map.ambient_critters[%d] lays.item '%s' is not an item" % [rid, i, lays.get("item", "")])
		var p := Vector2(float(pos[0]), float(pos[1]))
		if p.x < 0.0 or p.y < 0.0 or p.x > size.x or p.y > size.y:
			errors.append("Region '%s' map.ambient_critters[%d] pos is outside the map" % [rid, i])
		elif kind == "duck" and pond_at(region, p).size == Vector2.ZERO:
			errors.append("Region '%s' map.ambient_critters[%d] duck must be on a pond landmark" % [rid, i])
	return errors


## The pond landmark rect (shrunk by WATER_MARGIN) containing `p`; a zero Rect2 when none does.
static func pond_at(region: Dictionary, p: Vector2) -> Rect2:
	for lm: Dictionary in region.get("map", {}).get("landmarks", []):
		if String(lm.get("kind", "")) != "pond":
			continue
		var size := Vector2(float(lm["size"][0]), float(lm["size"][1]))
		var rect := Rect2(Vector2(float(lm["pos"][0]), float(lm["pos"][1])) - size / 2.0, size).grow(-WATER_MARGIN)
		if rect.has_point(p):
			return rect
	return Rect2()


## True when `kind` shows in `season` ("Spring" or "spring").
static func in_season(kind: String, season: String) -> bool:
	return (SEASONS.get(kind, []) as Array).has(season.to_lower())


## Today's critters: [{kind, pos, home (Rect2: the roaming box), seed (int)}], none when `enabled` is false.
## Deterministic from the region id and day (no global randomness).
static func today(region: Dictionary, season: String, day: int, enabled: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not enabled:
		return out
	var list: Array = region.get("map", {}).get("ambient_critters", [])
	for i in list.size():
		var e: Dictionary = list[i]
		var kind := String(e["kind"])
		if not in_season(kind, season):
			continue
		var pos := Vector2(float(e["pos"][0]), float(e["pos"][1]))
		var seed_value := hash([String(region.get("id", "")), day, i])
		var home := Rect2(pos - Vector2(18, 10), Vector2(36, 20))
		if kind == "duck":
			home = pond_at(region, pos)
		elif kind == "butterfly":
			home = Rect2(pos - Vector2(40, 30), Vector2(80, 60))
		out.append({"kind": kind, "pos": pos, "home": home, "seed": seed_value})
	return out


## Where a critter is at time `t` (seconds): a slow, seeded wander inside its home box. Still (the
## start position) when `still`. Pure.
static func position_at(c: Dictionary, t: float, still: bool) -> Vector2:
	var pos: Vector2 = c["pos"]
	if still:
		return pos
	var home: Rect2 = c["home"]
	var s := float(int(c["seed"]) % 628) / 100.0
	var speed := 0.5 if c["kind"] != "butterfly" else 1.3
	var off := Vector2(sin(t * speed + s), cos(t * speed * 0.7 + s * 1.7)) * 0.5
	var p := pos + Vector2(off.x * home.size.x * 0.5, off.y * home.size.y * 0.5)
	if home.size != Vector2.ZERO:
		p = Vector2(clampf(p.x, home.position.x, home.end.x), clampf(p.y, home.position.y, home.end.y))
	return p


## GFX-088: how close the player must be before a critter notices, by kind.
const FLEE_RADIUS := {"hen": 48.0, "duck": 56.0, "butterfly": 32.0}
## ...and how far it moves at contact (a hen runs 40-60 px, a duck paddles, a butterfly rises 20 px).
const FLEE_DIST := {"hen": 60.0, "duck": 36.0, "butterfly": 20.0}


## Offset a critter takes to get away from the player: zero beyond `radius`, pointing directly away,
## `max_dist` long at contact and shrinking linearly to nothing at the radius. Pure.
static func flee_offset(critter_pos: Vector2, player_pos: Vector2, radius: float, max_dist: float) -> Vector2:
	var d := critter_pos - player_pos
	var dist := d.length()
	if radius <= 0.0 or dist >= radius:
		return Vector2.ZERO
	var dir := Vector2.RIGHT if dist < 0.001 else d / dist
	return dir * max_dist * (1.0 - dist / radius)


## `p` pulled inside a pond rect (a zero rect leaves it alone). Pure.
static func clamp_to_pond(p: Vector2, pond: Rect2) -> Vector2:
	if pond.size == Vector2.ZERO:
		return p
	return Vector2(clampf(p.x, pond.position.x, pond.end.x), clampf(p.y, pond.position.y, pond.end.y))


## Offset for critter `c` (with its wander position `p`) given the player: ducks and hens flee away,
## butterflies rise straight up by the same strength.
static func startle_offset(c: Dictionary, p: Vector2, player_pos: Vector2) -> Vector2:
	var kind := String(c["kind"])
	var away := flee_offset(p, player_pos, float(FLEE_RADIUS.get(kind, 0.0)), float(FLEE_DIST.get(kind, 0.0)))
	if kind == "butterfly":
		return Vector2(0.0, -away.length())
	return away
