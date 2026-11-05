class_name BeastTracks
extends RefCounted
## WU-450: the trail of prints a great beast leaves on the ground. Pure: positions come from a local seeded rng
## (never GameState.rng) and nothing here touches nodes. The world draws the result under labels and figures.

const COUNT_MIN := 8
const COUNT_MAX := 12
const EDGE_MARGIN := 60.0
const MIN_ALPHA := 0.18
const MAX_ALPHA := 0.7
const STOP_SHORT := 70.0  ## the trail ends this far from the beast

## Print shape by the beast's id: hoof (boar, ram, stag, elk), three_toed (crane), webbed (toad), else paw.
static func shape_for(enemy_id: String) -> String:
	if enemy_id.contains("crane") or enemy_id.contains("bird"):
		return "three_toed"
	if enemy_id.contains("toad") or enemy_id.contains("frog"):
		return "webbed"
	for k: String in ["boar", "ram", "stag", "elk", "deer", "tusker"]:
		if enemy_id.contains(k):
			return "hoof"
	return "paw"


## The great beast whose trail shows today: the region's active great enemy on the day before it walks (`day + 1`)
## or on its own day; "" when the region has none, it is beaten (and has no return beast), or it is not due.
static func beast_for(data: GameData, c: CharacterData, region_id: String, day: int) -> String:
	var def: Dictionary = data.regions.get(region_id, {}).get("roamers", {}).get("great", {})
	if def.is_empty():
		return ""
	if not (Wildlife.tracks_today(data, region_id, day, c.realm_index) or Wildlife.next_great_day(data, region_id, day, c.realm_index) == day):
		return ""
	var enemy := Wildlife.active_great_enemy(c, data, region_id)
	if enemy == "" or c.great_beasts.has(enemy):
		return ""
	return enemy


## 8-12 prints from a map edge toward `spot` (the beast's spawn area), skipping any inside `clear_rects` or
## `blocked`: [{pos, angle, alpha, side}]. Alpha fades with distance from the beast (freshest nearest it).
static func trail(region_id: String, day: int, map_size: Vector2, spot: Vector2, blocked: Array[Rect2], clear_rects: Array[Rect2]) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:tracks" % [region_id, day])
	var best: Array[Dictionary] = []
	for attempt in 12:  # try other edges when places and paths swallow too many prints
		var out := _attempt(rng, map_size, spot, blocked, clear_rects)
		if out.size() > best.size():
			best = out
		if best.size() >= COUNT_MIN:
			break
	return best


static func _attempt(rng: RandomNumberGenerator, map_size: Vector2, spot: Vector2, blocked: Array[Rect2], clear_rects: Array[Rect2]) -> Array[Dictionary]:
	var start := Vector2.ZERO
	match rng.randi_range(0, 3):  # which edge the beast came from
		0: start = Vector2(rng.randf_range(0.2, 0.8) * map_size.x, EDGE_MARGIN)
		1: start = Vector2(rng.randf_range(0.2, 0.8) * map_size.x, map_size.y - EDGE_MARGIN)
		2: start = Vector2(EDGE_MARGIN, rng.randf_range(0.2, 0.8) * map_size.y)
		_: start = Vector2(map_size.x - EDGE_MARGIN, rng.randf_range(0.2, 0.8) * map_size.y)
	var out: Array[Dictionary] = []
	var total := (spot - start).length() - STOP_SHORT
	if total < 120.0:
		return out
	var dir := (spot - start).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var n := rng.randi_range(COUNT_MIN, COUNT_MAX)
	var step := total / float(n)
	for i in n:
		var side := 1 if i % 2 == 0 else -1
		var pos := start + dir * (step * (float(i) + 0.5)) + perp * (side * 14.0 + rng.randf_range(-6.0, 6.0))
		var ok := true
		for r in blocked:
			if r.grow(8.0).has_point(pos):
				ok = false
		for r in clear_rects:
			if r.has_point(pos):
				ok = false
		if not ok:
			continue
		out.append({"pos": pos, "angle": dir.angle(), "alpha": lerpf(MIN_ALPHA, MAX_ALPHA, float(i) / float(n - 1)), "side": side})
	return out


## Draws one print on `canvas`: `p` centre, `angle` heading, `shape` from shape_for, `a` alpha.
static func draw_print(canvas: CanvasItem, p: Vector2, angle: float, shape: String, a: float, side: int = 1) -> void:
	var col := Color(0.8, 0.7, 0.52, a)  # pale dust: reads on dark forest and bog ground
	canvas.draw_set_transform(p, angle, Vector2(1.4, 1.4))
	match shape:
		"hoof":  # two split halves
			canvas.draw_rect(Rect2(-7, -9, 12, 7), col)
			canvas.draw_rect(Rect2(-7, 2, 12, 7), col)
		"three_toed":  # three long toes fanning forward and a heel
			canvas.draw_rect(Rect2(-8, -1, 16, 3), col)
			canvas.draw_rect(Rect2(-6, -9, 12, 3), col)
			canvas.draw_rect(Rect2(-6, 7, 12, 3), col)
			canvas.draw_rect(Rect2(-12, -3, 5, 6), col)
		"webbed":  # a wide fan with a web between four toes
			canvas.draw_rect(Rect2(-6, -10, 12, 20), col)
			canvas.draw_rect(Rect2(6, -12, 5, 4), col)
			canvas.draw_rect(Rect2(6, 8, 5, 4), col)
			canvas.draw_rect(Rect2(8, -3, 5, 6), col)
		_:  # pad and four toes
			canvas.draw_rect(Rect2(-8, -6, 11, 12), col)
			for t in 4:
				canvas.draw_rect(Rect2(5, -9 + t * 5, 5, 4), col)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
