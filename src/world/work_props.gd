class_name WorkProps
extends RefCounted
## GFX-219: the small two-frame prop a villager works with while idle (broom, hoe, rod, scroll,
## raised hand, axe, seated pose). Pure drawing helpers: the node keeps a clock and calls
## `frame_at` / `draw`. Frame 1 follows frame 0 every PERIOD / 2 seconds; reduce_motion pins frame 0.

const ACTIVITIES: Array = PlaceLooks.ACTIVITIES
## Seconds for a full 2-frame cycle (a frame change every 0.6 s).
const PERIOD := 1.2


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


## Draws the prop for `activity` on `canvas` (a CanvasItem inside its _draw). `o` is the local point
## beside the villager's body where the prop's origin sits (their hand), `s` the pixel scale.
static func draw(canvas: CanvasItem, activity: String, frame: int, o: Vector2, s: float) -> void:
	var wood := Color("7a5a36")
	var dark := Color("4a3a26")
	var steel := Color("b8bcc2")
	match activity:
		"sweep":
			var dx := 0.0 if frame == 0 else 3.0
			for i in 9:
				canvas.draw_rect(Rect2(o + Vector2(dx * (1.0 - i / 9.0), -8.0 + i) * s, Vector2(1, 1) * s), wood)
			canvas.draw_rect(Rect2(o + Vector2(dx - 2.0, 1.0) * s, Vector2(5, 3) * s), Color("c9a85a"))
		"hoe":
			var up := frame == 1
			var top := Vector2(2, -9) if up else Vector2(4, -4)
			for i in 8:
				canvas.draw_rect(Rect2(o + top.lerp(Vector2(0, 3), i / 8.0) * s, Vector2(1, 1) * s), wood)
			canvas.draw_rect(Rect2(o + (top + Vector2(-1, -1)) * s, Vector2(3, 2) * s), steel)
		"fish":
			for i in 10:
				canvas.draw_rect(Rect2(o + Vector2(float(i) * 0.9, -float(i) * 0.9) * s, Vector2(1, 1) * s), wood)
			var bob := 0.0 if frame == 0 else 2.0
			var tip := o + Vector2(9, -9) * s
			canvas.draw_rect(Rect2(tip, Vector2(1, 12 + bob) * s), Color(0.85, 0.9, 0.95, 0.8))
			canvas.draw_rect(Rect2(tip + Vector2(-1, 12 + bob) * s, Vector2(3, 2) * s), Color("c8503c"))
		"read":
			var w := 7.0 if frame == 0 else 5.0
			canvas.draw_rect(Rect2(o + Vector2(-1, -3) * s, Vector2(w, 6) * s), Color("efe4c4"))
			canvas.draw_rect(Rect2(o + Vector2(-1, -3) * s, Vector2(w, 1) * s), dark)
			canvas.draw_rect(Rect2(o + Vector2(0, -1) * s, Vector2(w - 2.0, 1) * s), dark)
			canvas.draw_rect(Rect2(o + Vector2(0, 1) * s, Vector2(w - 3.0, 1) * s), dark)
		"hawk":
			var lift := 0.0 if frame == 0 else -3.0
			canvas.draw_rect(Rect2(o + Vector2(0, -2.0 + lift) * s, Vector2(2, 5) * s), Color("e6bf99"))
			canvas.draw_rect(Rect2(o + Vector2(-1, -4.0 + lift) * s, Vector2(4, 3) * s), Color("e6bf99"))
		"chop":
			var raised := frame == 0
			var top := Vector2(3, -9) if raised else Vector2(8, -2)
			for i in 8:
				canvas.draw_rect(Rect2(o + top.lerp(Vector2(0, 3), i / 8.0) * s, Vector2(1, 1) * s), wood)
			canvas.draw_rect(Rect2(o + (top + Vector2(-1, -1)) * s, Vector2(3, 3) * s), steel)
		"sit":
			var d := 0.0 if frame == 0 else 1.0
			canvas.draw_rect(Rect2(o + Vector2(-9, 3.0 + d) * s, Vector2(12, 3) * s), Color("8a6b45"))
			canvas.draw_rect(Rect2(o + Vector2(-9, 3.0 + d) * s, Vector2(12, 1) * s), Color("a8885a"))
