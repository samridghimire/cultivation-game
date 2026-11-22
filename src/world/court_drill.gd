class_name CourtDrill
extends Node2D
## GFX-241: disciples drilling on a sect hall's court (sects.json `court_drill`: count 2-6, form sword|fist|ledger).
## Decoration only: no collision, no names. positions() is pure; the node draws PixelFigure people in the sect's robe
## in a 3-pose loop (ready, strike, return), the back row a beat behind. Stands still under reduced motion.

const POSE_SECS := 1.2
const ROW_LAG := 0.15
const EDGE := 28.0  ## clear of the court edge
const DOOR_CLEAR := 48.0  ## the free column down to the hall door
const MIN_GAP := 22.0
const SLOT := 30.0
const FORMS: Array[String] = ["sword", "fist", "ledger"]

var _figures: Array[Dictionary] = []  # {pos, row, look}
var _form := "sword"
var _moving := false
var _clock := 0.0
var _scale := 3.0


## True when today's weather and festivals leave the court open for a drill.
static func drill_today(weather: String, festival_here: bool) -> bool:
	return not festival_here and weather != "rain" and weather != "storm"


## Figure feet positions: two rows in the court's south part (below `top_y` when given), none in the door column,
## none within MIN_GAP of another, none within `blockers` (map px circles of 24 px). Deterministic.
static func positions(court: Rect2, count: int, door_x: float, top_y: float = -1.0, blockers: Array[Vector2] = []) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var top := top_y if top_y >= 0.0 else court.position.y + court.size.y * 0.55
	var bottom := court.end.y - EDGE
	var rows: Array[float] = []
	if bottom - top >= MIN_GAP + 8.0:
		rows.append(bottom - MIN_GAP - 14.0)
	rows.append(bottom)
	var slots: Array[float] = []
	var x := court.position.x + EDGE
	while x <= court.end.x - EDGE:
		if absf(x - door_x) >= DOOR_CLEAR / 2.0:
			slots.append(x)
		x += SLOT
	for r in rows.size():
		var want := count / rows.size() + (1 if r < count % rows.size() else 0)
		var y := rows[r]
		var free: Array[float] = []
		for sx in slots:
			var p := Vector2(sx + (SLOT / 2.0 if r == 1 else 0.0), y)
			if absf(p.x - door_x) < DOOR_CLEAR / 2.0 or p.x > court.end.x - EDGE:
				continue
			var blocked := false
			for b in blockers:
				if b.distance_to(p) < 24.0:
					blocked = true
			if not blocked:
				free.append(p.x)
		var take := mini(want, free.size())
		for i in take:
			var idx := int(round(float(i) * float(free.size() - 1) / float(maxi(take - 1, 1)))) if take > 1 else free.size() / 2
			out.append(Vector2(free[idx], y))
	return out


## Rebuilds for one sect hall. `court` and `door_x` come from SectCourt; `hall` is the hall's rect.
func setup(sect_def: SectDef, court: Rect2, hall: Rect2, blockers: Array[Vector2], moving: bool) -> void:
	_figures.clear()
	_clock = 0.0
	_moving = moving
	_scale = float(Sprites.scale())
	_form = String(sect_def.court_drill.get("form", "sword"))
	var robe := Color(sect_def.robe_color) if sect_def.robe_color != "" else PixelFigure.DEFAULT_ROBE
	var spots := positions(court, int(sect_def.court_drill.get("count", 0)), hall.get_center().x, hall.end.y + 36.0, blockers)
	var row_y := -1.0
	var row := 0
	for p in spots:
		if row_y >= 0.0 and not is_equal_approx(p.y, row_y):
			row += 1
		row_y = p.y
		var look := PlaceLooks.figure_look({"robe": robe.to_html(false), "style": "bun" if _figures.size() % 2 == 0 else "hood"}, Color.GRAY)
		_figures.append({"pos": p, "row": row, "look": look})
	visible = not _figures.is_empty()
	set_process(_moving and visible)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## 0 ready, 1 strike, 2 return for a figure of `row` at `clock` seconds.
static func pose_at(clock: float, row: int) -> int:
	return posmod(int(floorf((clock - ROW_LAG * float(row)) / POSE_SECS)), 3)


func figure_count() -> int:
	return _figures.size()


func _draw() -> void:
	for f: Dictionary in _figures:
		var p: Vector2 = f["pos"]
		var pose := pose_at(_clock, int(f["row"])) if _moving else 0
		var tex := PixelFigure.frame(f["look"], "down" if pose != 1 else "right", 0)
		var ts := Vector2(tex.get_size()) * _scale
		PlaceArt.ellipse(self, p + Vector2(0, 1), Vector2(ts.x * 0.35, 3.0), Color(0, 0, 0, 0.22))
		var lunge := Vector2(5.0 * _scale / 3.0, 0) if pose == 1 and _form != "ledger" else Vector2.ZERO
		draw_texture_rect(tex, Rect2(p + lunge - Vector2(ts.x / 2.0, ts.y), ts), false)
		_draw_tool(p + lunge, ts, pose)


func _draw_tool(p: Vector2, ts: Vector2, pose: int) -> void:
	var hand := p + Vector2(ts.x * 0.42, -ts.y * 0.35)
	match _form:
		"sword":
			var tip := hand + (Vector2(ts.x * 0.7, -2.0) if pose == 1 else Vector2(2.0, -ts.y * 0.55))
			draw_line(hand, tip, Color("d9e2ea"), 2.0)
		"fist":
			if pose == 1:
				draw_circle(hand + Vector2(ts.x * 0.25, 0), 3.0, Color("e8c9a0"))
		"ledger":
			var page := int(_clock / 3.0) % 2
			var board := Rect2(hand + Vector2(-ts.x * 0.3, -4.0), Vector2(10.0, 13.0))
			draw_rect(board, Color("e9dfc3") if page == 0 else Color("d9ceb0"))
			draw_rect(board, Color("2b2118"), false, 1.0)
