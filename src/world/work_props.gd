class_name WorkProps
extends RefCounted
## GFX-219: the small two-frame prop a villager works with while idle (broom, hoe, rod, scroll,
## raised hand, axe, seated pose). Pure drawing helpers: the node keeps a clock and calls
## `frame_at` / `draw`. Frame 1 follows frame 0 every PERIOD / 2 seconds; reduce_motion pins frame 0.

const ACTIVITIES: Array = PlaceLooks.ACTIVITIES
## Seconds for a full 2-frame cycle (a frame change every 0.6 s).
const PERIOD := 1.2
## GFX-229: work vignettes draw this much larger than the figure's pixel scale (snapped to whole pixels).
const PROP_SCALE := 1.5


static func is_valid(activity: String) -> bool:
	return ACTIVITIES.has(activity)


## Which of the two frames shows at time `t` seconds for a villager with random `phase` (seconds).
static func frame_at(t: float, phase: float, reduced: bool) -> int:
	if reduced:
		return 0
	return int(floorf((t + phase) / (PERIOD / 2.0))) % 2


## A stable 0..PERIOD phase from an id so villagers do not swing in unison.
static func phase_of(id: String) -> float:
	return float(absi(hash(id)) % 120) / 100.0


## The pixel scale work props draw at: 1.5x the base, rounded to a whole pixel step (at least the base).
static func prop_scale(base: float) -> float:
	return maxf(base, roundf(base * PROP_SCALE))


## Draws the prop for `activity` on `canvas` (a CanvasItem inside its _draw). `o` is the local point
## beside the villager's body where the prop's origin sits (their hand), `s` the pixel scale.
static func draw(canvas: CanvasItem, activity: String, frame: int, o: Vector2, scale: float) -> void:
	var s := prop_scale(scale)
	var wood := Color("7a5a36")
	var dark := Color("4a3a26")
	var steel := Color("b8bcc2")
	match activity:
		"sweep":
			var dx := 0.0 if frame == 0 else 3.0
			for i in 9:
				_px(canvas, o, s, dx * (1.0 - i / 9.0), -8.0 + i, 1, 1, wood)
			_px(canvas, o, s, dx - 2.0, 1, 5, 3, Color("c9a85a"))
			if frame == 1:  # a small dust puff behind the bristles
				for d: Vector2 in [Vector2(5, 2), Vector2(7, 0), Vector2(8, 3), Vector2(10, 1)]:
					_px(canvas, o, s, dx + d.x, d.y, 1, 1, Color(0.85, 0.8, 0.7, 0.8))
		"hoe":
			for r in 3:  # a dark furrow strip, three rows
				_px(canvas, o, s, 1, 5 + r * 2, 14, 1, dark)
				_px(canvas, o, s, 1, 6 + r * 2, 14, 1, Color("6a5236") if r < 2 else Color(0, 0, 0, 0))
			var up := frame == 1
			var top := Vector2(2, -7) if up else Vector2(4, -3)
			for i in 8:
				_px(canvas, o, s, lerpf(top.x, 0.0, i / 8.0), lerpf(top.y, 4.0, i / 8.0), 1, 1, wood)
			_px(canvas, o, s, top.x - 1.0, top.y - 1.0, 3, 2, steel)
		"fish":
			_px(canvas, o, s, 4, 4, 13, 4, Color("3d7fa8"))  # the water the line reaches
			_px(canvas, o, s, 6, 5, 3, 1, Color("8cc4e0"))
			_px(canvas, o, s, 12, 6, 3, 1, Color("8cc4e0"))
			for i in 10:
				_px(canvas, o, s, float(i) * 0.9, -float(i) * 0.9 + 1.0, 1, 1, wood)
			var bob := 0.0 if frame == 0 else 1.0
			var tipx := 9.0
			_px(canvas, o, s, tipx, -8, 1, 12 + bob, Color(0.85, 0.9, 0.95, 0.8))
			_px(canvas, o, s, tipx - 1.0, 4 + bob, 3, 2, Color("c8503c"))
		"read":
			var w := 7.0 if frame == 0 else 5.0
			_px(canvas, o, s, -1, -4, w, 6, Color("efe4c4"))
			_px(canvas, o, s, -1, -4, w, 1, dark)
			_px(canvas, o, s, 0, -2, w - 2.0, 1, dark)
			_px(canvas, o, s, 0, 0, w - 3.0, 1, dark)
			_px(canvas, o, s, -3, 2, 13, 2, Color("a8885a"))  # the low table / lectern top
			_px(canvas, o, s, -3, 2, 13, 1, Color("c9a870"))
			_px(canvas, o, s, -2, 4, 1, 4, dark)
			_px(canvas, o, s, 8, 4, 1, 4, dark)
		"hawk":
			var lift := 0.0 if frame == 0 else -3.0
			_px(canvas, o, s, 0, -2.0 + lift, 2, 5, Color("e6bf99"))
			_px(canvas, o, s, -1, -4.0 + lift, 4, 3, Color("e6bf99"))
			_px(canvas, o, s, 5, 3, 9, 5, Color("c9a85a"))  # a basket of goods beside the hand
			_px(canvas, o, s, 5, 3, 9, 1, Color("8a6b2e"))
			_px(canvas, o, s, 5, 5, 9, 1, Color("a8883a"))
			_px(canvas, o, s, 6, 1, 3, 2, Color("c8503c"))
			_px(canvas, o, s, 9, 1, 3, 2, Color("7aa84a"))
			_px(canvas, o, s, 12, 2, 2, 1, Color("e0c050"))
		"chop":
			_px(canvas, o, s, 4, 4, 9, 5, Color("5a3e22"))  # stump with a ringed top
			_px(canvas, o, s, 4, 3, 9, 2, Color("c9a066"))
			_px(canvas, o, s, 7, 3, 3, 1, Color("8a6a3c"))
			if frame == 0:
				_px(canvas, o, s, 5, 0, 7, 3, Color("a8804a"))  # the log waits on the stump
				_px(canvas, o, s, 5, 0, 7, 1, Color("c9a066"))
			else:
				_px(canvas, o, s, 3, 1, 4, 2, Color("a8804a"))  # split in two halves
				_px(canvas, o, s, 10, 2, 4, 2, Color("a8804a"))
			var top := Vector2(3, -9) if frame == 0 else Vector2(8, -1)
			for i in 8:
				_px(canvas, o, s, lerpf(top.x, 0.0, i / 8.0), lerpf(top.y, 3.0, i / 8.0), 1, 1, wood)
			_px(canvas, o, s, top.x - 1.0, top.y - 1.0, 3, 3, steel)
			_px(canvas, o, s, 15, 7, 4, 2, Color("a8804a"))  # a pile of three logs
			_px(canvas, o, s, 19, 7, 4, 2, Color("8a6a3c"))
			_px(canvas, o, s, 17, 5, 4, 2, Color("a8804a"))
		"sit":
			var d := 0.0 if frame == 0 else 1.0
			_px(canvas, o, s, -9, 3.0 + d, 12, 3, Color("8a6b45"))
			_px(canvas, o, s, -9, 3.0 + d, 12, 1, Color("a8885a"))


static func _px(canvas: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	if c.a <= 0.0:
		return
	canvas.draw_rect(Rect2(o + Vector2(roundf(x), roundf(y)) * s, Vector2(w, h) * s), c)


## GFX-226/228: a low table (14x6 px: dark wood top with a lit edge, two legs), a cup on each side and steam
## over one, centred on `c` (tea between two seated figures).
static func draw_tea(canvas: CanvasItem, frame: int, c: Vector2, s: float) -> void:
	_px(canvas, c, s, -7, 0, 14, 3, Color("6a4a2a"))
	_px(canvas, c, s, -7, 0, 14, 1, Color("c9a870"))  # the lit edge
	_px(canvas, c, s, -6, 3, 1, 3, Color("3a2a1a"))
	_px(canvas, c, s, 5, 3, 1, 3, Color("3a2a1a"))
	for cx: float in [-4.0, 2.0]:  # a cup on each side
		_px(canvas, c, s, cx, -3, 3, 3, Color("efe4c4"))
		_px(canvas, c, s, cx, -3, 3, 1, Color("6a8a4a"))
	var steam := Color(0.95, 0.95, 0.95, 0.75)
	if frame == 0:
		_px(canvas, c, s, 3, -5, 1, 1, steam)
		_px(canvas, c, s, 4, -7, 1, 1, steam)
	else:
		_px(canvas, c, s, 4, -5, 1, 1, steam)
		_px(canvas, c, s, 3, -7, 1, 1, steam)


## GFX-236: a squat bronze incense burner (12x10 art px: tripod feet, dark rim, a glowing ember), feet at `c`.
static func draw_burner(canvas: CanvasItem, c: Vector2, s: float) -> void:
	_px(canvas, c, s, -5, -2, 1, 2, Color("3a2a1a"))
	_px(canvas, c, s, 4, -2, 1, 2, Color("3a2a1a"))
	_px(canvas, c, s, -6, -8, 12, 6, Color("8a6a30"))
	_px(canvas, c, s, -6, -8, 12, 1, Color("c9a050"))
	_px(canvas, c, s, -6, -9, 12, 1, Color("3a2a1a"))  # the dark rim
	_px(canvas, c, s, -1, -9, 2, 1, Color("ff8a30"))  # the ember


## GFX-228: a flat floor cushion under a seated figure, centred on `c` (its feet).
static func draw_cushion(canvas: CanvasItem, c: Vector2, s: float) -> void:
	_px(canvas, c, s, -7, -2, 14, 4, Color("8a3a3a"))
	_px(canvas, c, s, -7, -2, 14, 1, Color("b05a50"))
	_px(canvas, c, s, -7, 1, 14, 1, Color("5a2424"))
