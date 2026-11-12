class_name MarketLife
extends Node2D
## GFX-119: a bustling market (map.market): code-drawn awning stalls with goods, handcarts, lantern strings between the
## stalls (the lanterns glow warmer on grey or wet days) and a few ambient shoppers strolling stall to stall. The layout is
## MarketLayout (seeded by region id); shoppers are seeded per day and stand still under reduce_motion.

const OUTLINE := Color("2b2118")
const STRING_COLOR := Color("1a120c")
const LANTERN_RED := Color("f0553a")
const LANTERN_CORE := Color("fff0b0")
const WOOD := Color("6e4a2a")
const ROBES: Array[String] = ["8a5a2b", "5f7f9f", "9f4f4f", "6f8f5a", "a08a4a", "7a5f8f"]

var _region_id := ""
var _data: Dictionary = {}
var _winter := false
var _dim := false
var _moving := false
var _day := 0
var _clock := 0.0
var _shoppers: Array[Dictionary] = []


## Rebuilds for `region` (an empty dict or one without map.market draws nothing).
func setup(region: Dictionary, season: String, weather: String, day: int, moving: bool) -> void:
	_region_id = String(region.get("id", ""))
	_data = MarketLayout.layout(region) if not region.is_empty() else {"stalls": [], "carts": [], "strings": [], "fronts": []}
	_winter = Scenery.is_snowy(season)
	_dim = weather != "clear"
	_day = day
	_moving = moving
	_clock = 0.0
	_shoppers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_region_id, "|robes", day])
	if not (_data["fronts"] as Array).is_empty():
		for n in clampi(MarketLayout.count(region, "shoppers"), 0, MarketLayout.SHOPPER_MAX):
			_shoppers.append({"n": n, "look": PlaceLooks.figure_look({"robe": ROBES[rng.randi() % ROBES.size()], "style": "bun" if n % 2 == 0 else "hood"}, Color.GRAY)})
	set_process(_moving and not _shoppers.is_empty())
	queue_redraw()


func shopper_position(n: int) -> Vector2:
	return MarketLayout.shopper_pos(_data["fronts"], _region_id, _day, n, _clock, _moving)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	for c: Dictionary in _data["carts"]:
		_draw_cart(c["rect"])
	for s: Dictionary in _data["stalls"]:
		_draw_stall(s)
	for pair: Array in _data["strings"]:
		_draw_string(pair[0], pair[1])
	var scale_px := float(Sprites.scale())
	for sh: Dictionary in _shoppers:
		var n := int(sh["n"])
		var p := shopper_position(n)
		var step := int(_clock * 5.0) % 4 if _moving else 0
		var tex := PixelFigure.frame(sh["look"], "down", step)
		var ts := Vector2(tex.get_size()) * scale_px
		var shadow := Scenery.figure_shadow(ts, _winter)
		PlaceArt.ellipse(self, p + Vector2(0, 1), shadow.size / 2.0, Scenery.figure_shadow_color(_winter))
		draw_texture_rect(tex, Rect2(p - Vector2(ts.x / 2.0, ts.y), ts), false)


func _draw_stall(s: Dictionary) -> void:
	var r: Rect2 = s["rect"]
	var awning := Color(String(s["awning"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s["seed"])
	# Counter and goods first, awning on top.
	var counter := Rect2(r.position.x + 4.0, r.position.y + 16.0, r.size.x - 8.0, r.size.y - 16.0)
	draw_rect(Rect2(counter.position + Vector2(2, 3), counter.size), Color(0, 0, 0, 0.22))
	draw_rect(counter, WOOD)
	draw_rect(counter, OUTLINE, false, 1.0)
	_draw_goods(String(s["goods"]), counter, rng)
	var top := Rect2(r.position.x, r.position.y, r.size.x, 18.0)
	draw_rect(top, awning)
	var x := top.position.x
	var k := 0
	while x < top.end.x:  # stripes and a scalloped hem
		var w := minf(10.0, top.end.x - x)
		if k % 2 == 0:
			draw_rect(Rect2(x, top.position.y, w, top.size.y), awning.lightened(0.35))
		draw_circle(Vector2(x + w / 2.0, top.end.y), w / 2.0, awning if k % 2 else awning.lightened(0.35))
		x += 10.0
		k += 1
	draw_rect(top, OUTLINE, false, 1.0)
	if _winter:
		draw_rect(Rect2(top.position.x, top.position.y - 2.0, top.size.x, 5.0), Color("e8eef4"))


func _draw_goods(kind: String, counter: Rect2, rng: RandomNumberGenerator) -> void:
	var y := counter.position.y + 1.0
	var x := counter.position.x + 3.0
	while x < counter.end.x - 8.0:
		match kind:
			"crates":
				draw_rect(Rect2(x, y, 9, 8), Color("a07a44"))
				draw_rect(Rect2(x, y, 9, 8), OUTLINE, false, 1.0)
			"jars":
				draw_circle(Vector2(x + 4, y + 5), 4.0, Color("c9823a") if rng.randf() < 0.5 else Color("8fa5b5"))
				draw_rect(Rect2(x + 2, y, 4, 2), OUTLINE)
			"cloth":
				draw_rect(Rect2(x, y + 1, 9, 7), Color.from_hsv(rng.randf(), 0.5, 0.85))
				draw_line(Vector2(x, y + 4), Vector2(x + 9, y + 4), Color(1, 1, 1, 0.4), 1.0)
			"scrolls":
				draw_rect(Rect2(x, y + 2, 9, 3), Color("e8dcc0"))
				draw_rect(Rect2(x - 1, y + 2, 1, 3), Color("8a5a2b"))
				draw_rect(Rect2(x + 9, y + 2, 1, 3), Color("8a5a2b"))
			_:
				draw_circle(Vector2(x + 4, y + 5), 3.0, Color("d9573a") if rng.randf() < 0.5 else Color("e8c14a"))
		x += 12.0


func _draw_cart(r: Rect2) -> void:
	draw_rect(Rect2(r.position.x + 2, r.end.y - 2, r.size.x, 4), Color(0, 0, 0, 0.22))
	var bed := Rect2(r.position.x, r.position.y + 4.0, r.size.x - 8.0, r.size.y - 12.0)
	draw_rect(bed, WOOD.lightened(0.1))
	draw_rect(bed, OUTLINE, false, 1.0)
	for i in 3:  # sacks / goods heaped on the bed
		draw_circle(Vector2(bed.position.x + 7.0 + i * 9.0, bed.position.y), 5.0, Color("c9b38a"))
	draw_line(Vector2(bed.end.x, bed.position.y + 4.0), Vector2(r.end.x, bed.position.y + 8.0), OUTLINE, 2.0)  # the shaft
	draw_circle(Vector2(bed.position.x + bed.size.x / 2.0, r.end.y - 3.0), 6.0, OUTLINE)
	draw_circle(Vector2(bed.position.x + bed.size.x / 2.0, r.end.y - 3.0), 4.0, WOOD)


func _draw_string(a: Vector2, b: Vector2) -> void:
	var mid := (a + b) / 2.0 + Vector2(0, 12)
	var prev := a
	var steps := maxi(6, int(a.distance_to(b) / 8.0))
	var count := 0
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		var q: Vector2 = (1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * mid + t * t * b
		draw_line(prev, q, STRING_COLOR, 2.0)  # WU-521: a darker, thicker string reads at 1x
		if s % 3 == 0 and s < steps:
			var c := q + Vector2(0, 6)
			draw_circle(c, 12.0 if _dim else 9.0, Color(1.0, 0.8, 0.4, 0.34 if _dim else 0.22))  # the glow reads on grey days
			draw_circle(c, 5.0, LANTERN_RED)
			draw_circle(c, 5.0, Color("ffd45a"), false, 1.5)
			draw_circle(c, 2.0, LANTERN_CORE)
			count += 1
		prev = q
