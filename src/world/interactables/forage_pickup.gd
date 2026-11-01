class_name ForagePickup
extends Interactable
## WU-427: a small pickup on the map (GameState.forage_here). Walking up shows "[E] Pick Dew Grass"; interact
## picks it directly (no menu) through GameState.pick_forage. It sparkles every ~3 s (static with reduce_motion).

const PX := 4  # each sprite pixel is drawn 4x4: 8x8 art becomes 32 px (GFX-049: finds you can see)
const SPARKLE_PERIOD := 3.0
const SPARKLE_LEN := 0.3
const POP_SECONDS := 0.25
const MIN_GAP := 40.0
const OUTLINE := Color("2a2018")
const KINDS := {
	"herb": {"colors": {"a": Color("4fae5c"), "b": Color("8fd684")}, "rows": ["....b...", "..b.ab..", "..ab.a..", "...aab..", "..baa...", "...ab...", "...a....", "........"]},
	"mushroom": {"colors": {"a": Color("c4503c"), "b": Color("f0e4c8")}, "rows": ["........", "..aaaa..", ".abaaba.", ".aaaaaa.", "..bbbb..", "...bb...", "...bb...", "........"]},
	"ore": {"colors": {"a": Color("8a93a3"), "b": Color("e8f2ff")}, "rows": ["........", "........", "...aa...", "..abaa..", ".aabaaa.", ".aaaaaa.", "..aaaa..", "........"]},
	"sack": {"colors": {"a": Color("b8925a"), "b": Color("8a6a3a")}, "rows": ["........", "...bb...", "..abba..", "..aaaa..", ".aaaaaa.", ".aaaaaa.", "..aaaa..", "........"]},
}

var slot := 0
var item_id := ""
var amount := 1
var taken := false
var _t := 0.0
var _sparkle := false
var _pop := 0.0
static var _cache: Dictionary = {}


## Setup before add_child: forage `slot` holding `amount` of `p_item`, standing at `pos`.
func setup(p_slot: int, p_item: String, p_amount: int, pos: Vector2) -> void:
	slot = p_slot
	item_id = p_item
	amount = p_amount
	position = pos
	size = Vector2(32, 32)
	reach = 24.0
	art_kind = "forage"
	var def: Dictionary = GameState.data.items.get(p_item, {}) if GameState.data != null else {}
	display_name = "Pick %s" % String(def.get("name", p_item))
	_t = float(hash("%d:%s" % [p_slot, p_item]) % 300) / 100.0  # sparkles are not in step


## Which sprite an item gets: by tag, a small sack as the fallback.
static func sprite_kind(tags: Array) -> String:
	for t: String in ["herb", "mushroom", "ore"]:
		if tags.has(t):
			return t
	if tags.has("stone"):
		return "ore"
	return "sack"


static func texture_for(kind: String) -> Texture2D:
	if not _cache.has(kind):
		var def: Dictionary = KINDS[kind]
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		var pal: Dictionary = def["colors"]
		var rows: Array = def["rows"]
		for y in 8:
			for x in 8:
				var ch: String = (rows[y] as String).substr(x, 1)
				if pal.has(ch):
					img.set_pixel(x, y, pal[ch])
		# 1 px outline around the painted pixels (drawn only where the neighbour is empty).
		var out := img.duplicate() as Image
		for y in 8:
			for x in 8:
				if img.get_pixel(x, y).a > 0.0:
					continue
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Vector2i(x, y) + d
					if n.x >= 0 and n.y >= 0 and n.x < 8 and n.y < 8 and img.get_pixel(n.x, n.y).a > 0.0:
						out.set_pixel(x, y, OUTLINE)
						break
		_cache[kind] = ImageTexture.create_from_image(out)
	return _cache[kind]


func label_text() -> String:
	return ""  # the interact prompt names it; no floating label


func get_options() -> Array[Dictionary]:
	return []


func is_available() -> bool:
	return not taken


## Player calls this instead of opening a menu. True when it handled the interact press.
func use_directly() -> bool:
	if taken:
		return true
	if not GameState.pick_forage(slot):
		return true
	taken = true
	monitoring = false
	monitorable = false
	_float_text("+%d %s" % [amount, Items.item_plural(GameState.data, item_id, amount)])
	if MotionFx.reduced():
		queue_free()
	else:
		_pop = 0.001
	return true


func _float_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UIStyle.ACCENT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 20
	label.position = position + Vector2(-40, -34)
	get_parent().add_child(label)
	if MotionFx.reduced():
		get_tree().create_timer(1.0).timeout.connect(label.queue_free)
		return
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 28.0, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)


func _physics_process(delta: float) -> void:
	if _pop > 0.0:
		_pop += delta
		var k := clampf(_pop / POP_SECONDS, 0.0, 1.0)
		scale = Vector2.ONE * (1.0 + 0.2 * minf(k * 2.0, 1.0))
		modulate.a = 1.0 - k
		if k >= 1.0:
			queue_free()
		return
	if MotionFx.reduced():
		return
	_t += delta
	var on := fmod(_t, SPARKLE_PERIOD) < SPARKLE_LEN
	if on != _sparkle:
		_sparkle = on
		queue_redraw()


func draw_generated_art() -> bool:
	var tags: Array = GameState.data.items.get(item_id, {}).get("tags", []) if GameState.data != null else []
	var tex := texture_for(sprite_kind(tags))
	var half := 4.0 * PX
	var disc := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		disc.append(Vector2(0, half * 0.55) + Vector2(cos(a) * 10.0, sin(a) * 4.0))
	draw_colored_polygon(disc, Color(1, 0.95, 0.7, 0.28))
	draw_texture_rect(tex, Rect2(Vector2(-half, -half), Vector2(8 * PX, 8 * PX)), false)
	if _sparkle:
		var c := Color(1, 1, 0.8, 0.9)
		draw_rect(Rect2(8, -16, 2, 2), c)
		draw_rect(Rect2(7, -15, 4, 1), c)
		draw_rect(Rect2(8, -17, 2, 4), c)
	return true


## Spots for `count` pickups: seeded, off `blocked` rects and path centre lines, MIN_GAP from each other and from
## `avoid`; of a few candidates the one nearest a tree or path edge wins, so pickups read as found things.
static func pick_spots(region_id: String, day: int, count: int, map_size: Vector2, blocked: Array[Rect2],
		paths: Array[Rect2], trees: Array[Vector2], avoid: Array[Vector2]) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("forage:%s:%d:spots" % [region_id, day])
	var taken_spots: Array[Vector2] = avoid.duplicate()
	var out: Array[Vector2] = []
	for i in count:
		var best := Vector2.ZERO
		var best_score := INF
		var found := false
		for attempt in 40:
			var spot := Vector2(rng.randf_range(60.0, map_size.x - 60.0), rng.randf_range(60.0, map_size.y - 60.0))
			if not _spot_ok(spot, blocked, paths, taken_spots):
				continue
			var score := _nearest(spot, trees, 70.0) + _path_edge_gap(spot, paths)
			if not found or score < best_score:
				best = spot
				best_score = score
				found = true
			if attempt >= 14 and found:
				break
		if found:
			out.append(best)
			taken_spots.append(best)
		else:
			out.append(Vector2(-1000, -1000))  # no room: caller skips it
	return out


static func _spot_ok(spot: Vector2, blocked: Array[Rect2], paths: Array[Rect2], taken_spots: Array[Vector2]) -> bool:
	for r in blocked:
		if r.grow(16.0).has_point(spot):
			return false
	for p in paths:
		if p.grow(12.0).has_point(spot) and _centre_gap(spot, p) < 16.0:
			return false
	for q in taken_spots:
		if spot.distance_to(q) < MIN_GAP:
			return false
	return true


## Distance from `spot` to the centre line of path rect `p` (its long axis).
static func _centre_gap(spot: Vector2, p: Rect2) -> float:
	if p.size.x >= p.size.y:
		return absf(spot.y - (p.position.y + p.size.y / 2.0))
	return absf(spot.x - (p.position.x + p.size.x / 2.0))


## 0 near a tree (within 70 px) rising to 70; lower is better.
static func _nearest(spot: Vector2, points: Array[Vector2], cap: float) -> float:
	var best := cap
	for q in points:
		best = minf(best, spot.distance_to(q))
	return best


## Distance to the nearest path edge band, capped at 70 (lower = closer to a path's side).
static func _path_edge_gap(spot: Vector2, paths: Array[Rect2]) -> float:
	var best := 70.0
	for p in paths:
		if p.grow(70.0).has_point(spot):
			best = minf(best, absf(_centre_gap(spot, p) - (minf(p.size.x, p.size.y) / 2.0 + 20.0)))
	return best
