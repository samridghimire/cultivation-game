class_name FoliageFx
extends Node2D
## GFX-214: grass that parts, leaves that fall. Walking on grass kicks a tiny puff of 2-4 bits every
## PUFF_STEP px (petals in spring where the region has flowers); in autumn (or a `leaves` ambient
## region) at most MAX_LEAVES leaves drop from visible trees. One fixed pool of CAP particles, no
## per-frame allocation. reduce_motion: no puffs, leaves lie still where they spawn.

const CAP := 40
const MAX_LEAVES := 6
const PUFF_STEP := 28.0
const PUFF_LIFE := 0.4
const LEAF_FALL := 2.5
const LEAF_LIE := 4.0
const FADE := 0.6
const REDRAW_EVERY := 0.0625

## Each slot: {on, kind ("bit"|"petal"|"leaf"), pos, vel0, age, life, color, fall, sway}
var _pool: Array[Dictionary] = []
var _enabled := false
var _reduce := false
var _grass := false  ## the region's ground is grass/litter (not scree, bog, paved)
var _petals := false
var _leaves := false
var _snowy := false
var _grass_color := Color("5f8a45")
var _road_rects: Array[Rect2] = []
var _trees: Array[Vector2] = []
var _view := Rect2()
var _last := Vector2.INF
var _rng := RandomNumberGenerator.new()
var _since_redraw := 0.0
var _leaf_timer := 0.0


func _init() -> void:
	_rng.seed = 214
	for i in CAP:
		_pool.append({"on": false})


## True when walking here kicks up grass: grass/litter ground and not snow-covered.
static func grass_ground(style: String, snowy: bool) -> bool:
	return (style == "grass" or style == "litter") and not snowy


## True when leaves fall: an autumn region with trees, or any season where map.ambient says leaves.
static func leaves_fall(season: String, map: Dictionary) -> bool:
	if Ambient.kind_for(map.get("ambient", {}), season) == "leaves":
		return true
	return season == "Autumn" and str(map.get("ground_style", "grass")) in ["grass", "litter"]


func setup(region: Dictionary, yards: Dictionary, decor: Array[Dictionary], season: String, snowy: bool, enabled: bool, reduce_motion: bool) -> void:
	var map: Dictionary = region.get("map", {})
	_enabled = enabled
	_reduce = reduce_motion
	_snowy = snowy
	_grass = grass_ground(str(map.get("ground_style", "grass")), snowy)
	var cfg := Scenery.settings(region)
	_grass_color = Color(str(cfg.get("grass_color", "5f8a45")))
	_petals = season == "Spring" and int(cfg.get("flowers", 0)) > 0
	_leaves = enabled and leaves_fall(season, map) and not snowy
	_road_rects.clear()
	for r in map.get("paths", []):
		_road_rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	for f: Dictionary in yards.get("footpaths", []):
		_road_rects.append(f["rect"] as Rect2)
	_trees.clear()
	for d in decor:
		if str(d["kind"]) == "tree" and str(d.get("tree_kind", "round")) != "dead":
			_trees.append(d["pos"] as Vector2)
	for s in _pool:
		s["on"] = false
	_last = Vector2.INF
	_leaf_timer = 0.0
	queue_redraw()


## The Ambient effects setting changed: off clears everything.
func set_enabled(on: bool, season: String, map: Dictionary) -> void:
	_enabled = on
	_leaves = on and leaves_fall(season, map) and not _snowy  # same rule as setup (a `leaves` ambient region may be scree)
	if not on:
		for s in _pool:
			s["on"] = false
		queue_redraw()


func live_count() -> int:
	var n := 0
	for s in _pool:
		if bool(s["on"]):
			n += 1
	return n


func leaf_count() -> int:
	var n := 0
	for s in _pool:
		if bool(s["on"]) and s["kind"] == "leaf":
			n += 1
	return n


func puffs_enabled() -> bool:
	return _enabled and _grass and not _reduce


func leaves_enabled() -> bool:
	return _leaves


func set_view(rect: Rect2) -> void:
	_view = rect


func _free_slot() -> int:
	for i in _pool.size():
		if not bool(_pool[i]["on"]):
			return i
	return -1


## Feed the player's position each frame (feet position is pos + (0, 14)).
func track(pos: Vector2) -> void:
	if _last == Vector2.INF:
		_last = pos
		return
	if _last.distance_to(pos) < PUFF_STEP:
		return
	_last = pos
	if not puffs_enabled():
		return
	var feet := pos + Vector2(0, 14)
	if Footprints.on_road(_road_rects, feet):
		return
	var n := _rng.randi_range(2, 4)
	for i in n:
		var idx := _free_slot()
		if idx < 0:
			return
		var col := _grass_color.lightened(0.15)
		if _petals:
			col = Color.from_hsv(_rng.randf_range(0.85, 0.98), 0.25, 1.0)
		_pool[idx] = {"on": true, "kind": "petal" if _petals else "bit", "pos": feet + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-2, 2)),
			"vel0": Vector2(_rng.randf_range(-5, 5), 0), "age": 0.0, "life": PUFF_LIFE, "color": col,
			"hop": _rng.randf_range(4.0, 8.0), "sway": 0.0}
	queue_redraw()


func _spawn_leaf() -> void:
	if _trees.is_empty() or leaf_count() >= MAX_LEAVES:
		return
	var visible_trees: Array[Vector2] = []
	for t in _trees:
		if _view.has_area() and not _view.has_point(t):
			continue
		visible_trees.append(t)
	if visible_trees.is_empty():
		return
	var idx := _free_slot()
	if idx < 0:
		return
	var tree: Vector2 = visible_trees[_rng.randi() % visible_trees.size()]
	var crown := tree + Vector2(_rng.randf_range(-12, 12), -38)
	_pool[idx] = {"on": true, "kind": "leaf", "pos": crown, "vel0": Vector2.ZERO, "age": 0.0,
		"life": LEAF_FALL + LEAF_LIE, "color": Color(0.85, 0.5, 0.2, 0.9).lerp(Color(0.7, 0.3, 0.15, 0.9), _rng.randf()),
		"hop": _rng.randf_range(30.0, 50.0), "sway": _rng.randf_range(0.0, TAU)}
	if _reduce:  # lies still where it spawns, on the ground under the crown
		_pool[idx]["pos"] = tree + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(0, 8))
		_pool[idx]["age"] = LEAF_FALL
		_pool[idx]["life"] = LEAF_FALL + LEAF_LIE


func advance(delta: float) -> void:
	if not _enabled:
		return
	var any := false
	for s in _pool:
		if not bool(s["on"]):
			continue
		any = true
		if _reduce and s["kind"] == "leaf":
			continue  # lies still, never fades under reduce_motion
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) >= float(s["life"]):
			s["on"] = false
	if _leaves:
		_leaf_timer -= delta
		if _leaf_timer <= 0.0:
			_leaf_timer = _rng.randf_range(0.5, 1.5)
			_spawn_leaf()
	_since_redraw += delta
	if any and _since_redraw >= REDRAW_EVERY:
		_since_redraw = 0.0
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for s in _pool:
		if not bool(s["on"]):
			continue
		var age := float(s["age"])
		var life := float(s["life"])
		var p: Vector2 = s["pos"]
		var col: Color = s["color"]
		match str(s["kind"]):
			"leaf":
				var fall_t := clampf(age / LEAF_FALL, 0.0, 1.0)
				var q := p + Vector2(sin(age * 2.2 + float(s["sway"])) * 6.0 * (1.0 - fall_t), float(s["hop"]) * fall_t)
				col.a *= clampf((life - age) / FADE, 0.0, 1.0)
				draw_rect(Rect2(q, Vector2(3, 2)), col)
			_:
				var t := clampf(age / life, 0.0, 1.0)
				var h := float(s["hop"]) * sin(t * PI)
				var q: Vector2 = p + (s["vel0"] as Vector2) * age + Vector2(0, -h)
				col.a *= 1.0 - t
				draw_rect(Rect2(q, Vector2(2, 2)), col)
