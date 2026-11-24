class_name ContestStage
extends Node2D
## GFX-253: during a sect's contest month a raised square platform stands on the hall court: four banner poles in the
## sect's robe colour, disciples standing around it and two sparring on top. Decoration only (no collision, no names).
## shown() and layout() are pure; outside the month nothing is drawn.

const SIZE := Vector2(92.0, 40.0)
const EDGE := 30.0
const RING_GAP := 30.0
const MIN_FIGURES := 6
const MAX_FIGURES := 8
const BLOCKER_CLEAR := 24.0
const SPAR_SECS := 0.9

var _platform := Rect2()
var _figures: Array[Vector2] = []
var _fig_looks: Array = []
var _spar_looks: Array = []
var _robe := PixelFigure.DEFAULT_ROBE
var _wood := false
var _moving := false
var _clock := 0.0
var _scale := 3.0


## True while `total_days` falls in the sect's contest month (sects.json `contest.month`); {} contest never shows.
static func shown(contest: Dictionary, total_days: int) -> bool:
	return not contest.is_empty() and Calendar.month_of(total_days) == int(contest.get("month", 0))


## The platform rect and the standing spots for `count` disciples. The platform sits in the court's south part on the
## side of the door column with more room (the column from the hall door stays free); spots ring it, inside the court,
## clear of `blockers` and of each other. Returns {platform: Rect2, spots: Array[Vector2]}. Deterministic.
static func layout(court: Rect2, hall: Rect2, count: int, blockers: Array[Vector2] = [], map_size: Vector2 = Vector2(100000, 100000), avoid: Array[Rect2] = []) -> Dictionary:
	var platform := _pick_platform(court, hall, map_size, avoid)
	var beside := not court.encloses(platform)
	var spots: Array[Vector2] = []
	var ring := platform.grow(RING_GAP)
	var cand: Array[Vector2] = []
	var x := ring.position.x
	while x <= ring.end.x + 0.1:  # south then north edge
		cand.append(Vector2(x, ring.end.y))
		cand.append(Vector2(x, ring.position.y))
		x += 34.0
	var y := ring.position.y + 24.0
	while y < ring.end.y - 12.0:  # the two sides
		cand.append(Vector2(ring.position.x, y))
		cand.append(Vector2(ring.end.x, y))
		y += 34.0
	var inner := Rect2(Vector2.ZERO, map_size).grow(-8.0)
	for p in cand:
		if spots.size() >= clampi(count, MIN_FIGURES, MAX_FIGURES):
			break
		if not inner.has_point(p) or platform.grow(8.0).has_point(p):
			continue
		if hall.grow(10.0).has_point(p) or (not beside and (p.y < hall.end.y + 10.0 or (court.has_point(p) and p.y < court.end.y - 20.0))):
			continue  # never over the hall or the court's open middle
		var ok := true
		for r in avoid:
			ok = ok and not r.has_point(p)
		for b in blockers:
			ok = ok and b.distance_to(p) >= BLOCKER_CLEAR
		for s in spots:
			ok = ok and s.distance_to(p) >= 34.0
		if ok:
			spots.append(p)
	return {"platform": platform, "spots": spots}


## GFX-255: the platform inside the court when it fits (the door column stays free), else on the open ground beside the
## hall (the side nearer the map's middle, which faces the road), clear of `avoid` (labels, neighbours); never south of the court.
static func _pick_platform(court: Rect2, hall: Rect2, map_size: Vector2, avoid: Array[Rect2]) -> Rect2:
	var door_x := hall.get_center().x
	var bounds := Rect2(Vector2.ZERO, map_size).grow(-10.0)
	var east_room := court.end.x - door_x
	var west_room := door_x - court.position.x
	var cy := court.end.y - 14.0 - SIZE.y / 2.0
	var in_court: Array[Rect2] = []
	for k in [0.55, 0.4]:
		var cx: float = door_x + east_room * k if east_room >= west_room else door_x - west_room * k
		in_court.append(Rect2(Vector2(cx, cy) - SIZE / 2.0, SIZE))
	var side: Array[Rect2] = []
	var east_first := hall.get_center().x < map_size.x / 2.0
	for east in [east_first, not east_first]:
		var sx := hall.end.x + 24.0 + SIZE.x / 2.0 if east else hall.position.x - 24.0 - SIZE.x / 2.0
		side.append(Rect2(Vector2(sx, hall.get_center().y) - SIZE / 2.0, SIZE))
	var fallback := Rect2()
	for r in in_court + side:
		var in_c := court.encloses(r)
		var fits := (r.position.y >= hall.end.y + 8.0) if in_c else (bounds.encloses(r) and not r.grow(14.0).intersects(hall))
		var clear := fits
		for a in avoid:
			clear = clear and not a.intersects(r.grow(10.0))
		if clear:
			return r
	return fallback if fallback != Rect2() else in_court[0]


## Rebuilds for one sect hall; hides itself outside the contest month.
func setup(sect_def: SectDef, court: Rect2, hall: Rect2, blockers: Array[Vector2], map_size: Vector2, total_days: int, wooden: bool, moving: bool, avoid: Array[Rect2] = []) -> void:
	_figures.clear()
	_fig_looks.clear()
	_spar_looks.clear()
	_clock = 0.0
	_moving = moving
	_wood = wooden
	_scale = float(Sprites.scale())
	visible = shown(sect_def.contest, total_days)
	set_process(false)
	if not visible:
		queue_redraw()
		return
	_robe = Color(sect_def.robe_color) if sect_def.robe_color != "" else PixelFigure.DEFAULT_ROBE
	var lay := layout(court, hall, MAX_FIGURES, blockers, map_size, avoid)
	_platform = lay["platform"]
	for p: Vector2 in lay["spots"]:
		_figures.append(p)
		_fig_looks.append(_look(_figures.size()))
	for i in 2:
		_spar_looks.append(_look(i))
	set_process(_moving)
	queue_redraw()


func _look(i: int) -> Variant:
	return PlaceLooks.figure_look({"robe": _robe.to_html(false), "style": "bun" if i % 2 == 0 else "hood"}, Color.GRAY)


func figure_count() -> int:
	return _figures.size()


func platform_rect() -> Rect2:
	return _platform


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var top := Color("a07a4c") if _wood else Color("b9b3a4")
	var side := Color("6b4e2e") if _wood else Color("8a8578")
	var line := Color("2b2118")
	var lift := 8.0
	draw_rect(Rect2(_platform.position + Vector2(0, lift), _platform.size), side)  # front face
	draw_rect(Rect2(_platform.position + Vector2(0, lift), _platform.size), line, false, 1.0)
	draw_rect(_platform, top)
	draw_rect(_platform, line, false, 1.0)
	for k in range(1, 4):  # planks / flagstone seams
		var sx := _platform.position.x + _platform.size.x * float(k) / 4.0
		draw_line(Vector2(sx, _platform.position.y), Vector2(sx, _platform.end.y), side, 1.0)
	for f in _figures:
		_draw_person(f, _fig_looks[_figures.find(f)], "down", Vector2.ZERO)
	var mid := _platform.get_center() + Vector2(0, 4)
	var strike := _moving and int(floorf(_clock / SPAR_SECS)) % 2 == 1
	var dx := 5.0 if strike else 0.0
	_draw_person(mid + Vector2(-14.0 + dx, 0), _spar_looks[0], "right", Vector2.ZERO)
	_draw_person(mid + Vector2(14.0 - dx * 0.4, 0), _spar_looks[1], "left", Vector2.ZERO)
	for corner in [_platform.position, Vector2(_platform.end.x, _platform.position.y), Vector2(_platform.position.x, _platform.end.y + lift), Vector2(_platform.end.x, _platform.end.y + lift)]:
		_draw_pole(corner)


func _draw_person(p: Vector2, look: Variant, dir: String, off: Vector2) -> void:
	var tex := PixelFigure.frame(look, dir, 0)
	var ts := Vector2(tex.get_size()) * _scale
	PlaceArt.ellipse(self, p + Vector2(0, 1), Vector2(ts.x * 0.35, 3.0), Color(0, 0, 0, 0.22))
	draw_texture_rect(tex, Rect2(p + off - Vector2(ts.x / 2.0, ts.y), ts), false)


func _draw_pole(base: Vector2) -> void:
	var tip := base + Vector2(0, -34.0)
	draw_line(base, tip, Color("4a3520"), 2.0)
	var sway := sin(_clock * 2.0 + base.x * 0.1) * 1.5 if _moving else 0.0
	var flag := PackedVector2Array([tip, tip + Vector2(13.0 + sway, 3.0), tip + Vector2(13.0 + sway, 12.0), tip + Vector2(0, 14.0)])
	draw_colored_polygon(flag, _robe)
	draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[3], flag[0]]), Color("2b2118"), 1.0)
