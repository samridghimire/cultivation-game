class_name LectureHallScene
extends Node2D
## WU-641: while a member's monthly lecture is open (Sects.check_lecture says so), the home hall's front shows the
## lecturing elder on a mat, a few seated disciples facing them and a small gold bell over the elder. Decoration only
## (no collision, no names). staged() and layout() are pure; outside the window nothing is drawn.

const MAT_SIZE := Vector2(84.0, 26.0)
const SEATS := 4
const BLOCKER_CLEAR := 22.0
const GOLD := Color("d8b04a")

var _mat := Rect2()
var _elder := Vector2.ZERO
var _seats: Array[Vector2] = []
var _looks: Array = []
var _elder_look: Variant = null
var _robe := PixelFigure.DEFAULT_ROBE
var _moving := false
var _clock := 0.0
var _scale := 3.0
var _mate_seat := -1  # WU-647: index in _seats of the sect-mate friend, -1 when none
var _mate_name := ""


## True when `c` is a member of `sect_id`'s sect, that sect lives in `region_id` and its lecture can be attended on `total_days`.
static func staged(c: CharacterData, data: GameData, region_id: String, total_days: int) -> bool:
	if c == null or c.is_rogue() or not data.sects.has(c.sect["id"]):
		return false
	if (data.sects[c.sect["id"]] as SectDef).home_region != region_id:
		return false
	return Sects.check_lecture(c, data, total_days) == ""


## {mat, elder, seats, bell}: the mat centred on the hall door just south of the hall, the elder on it, the seats in a
## row south of the mat, all on the map and clear of `blockers`. Deterministic.
static func layout(hall: Rect2, map_size: Vector2, blockers: Array[Vector2] = []) -> Dictionary:
	var centre := Vector2(hall.get_center().x, hall.end.y + 16.0 + MAT_SIZE.y / 2.0)
	var bounds := Rect2(Vector2.ZERO, map_size).grow(-12.0)
	var mat := Rect2(centre - MAT_SIZE / 2.0, MAT_SIZE)
	var seats: Array[Vector2] = []
	var row_y := mat.end.y + 26.0
	for dx in [-54.0, 54.0, -18.0, 18.0]:
		var p := Vector2(centre.x + dx, row_y)
		var ok := bounds.has_point(p)
		for b in blockers:
			ok = ok and b.distance_to(p) >= BLOCKER_CLEAR
		if ok:
			seats.append(p)
	var elder := mat.get_center() + Vector2(0, 4.0)
	return {"mat": mat, "elder": elder, "seats": seats, "bell": elder + Vector2(20.0, -52.0)}


## Rebuilds for one hall; hidden unless `on`.
## WU-647: `mate_id` (Sects.lecture_mate) sits in the front row beside the elder's mat with their name label.
func setup(on: bool, sect_def: SectDef, hall: Rect2, blockers: Array[Vector2], map_size: Vector2, moving: bool, mate_id: String = "", mate_name: String = "") -> void:
	_mate_seat = -1
	_mate_name = ""
	_seats.clear()
	_looks.clear()
	_clock = 0.0
	_moving = moving
	_scale = float(Sprites.scale())
	visible = on and sect_def != null
	set_process(false)
	if not visible:
		queue_redraw()
		return
	_robe = Color(sect_def.robe_color) if sect_def.robe_color != "" else PixelFigure.DEFAULT_ROBE
	var lay := layout(hall, map_size, blockers)
	_mat = lay["mat"]
	_elder = lay["elder"]
	for p: Vector2 in lay["seats"]:
		_seats.append(p)
		_looks.append(PlaceLooks.figure_look({"robe": _robe.to_html(false), "style": "bun" if _seats.size() % 2 == 0 else "hood", "hair": "dark"}, Color.GRAY))
	if mate_id != "" and not _seats.is_empty():
		_mate_seat = _seats.size() - 1  # the seat nearest the mat's centre
		_mate_name = mate_name
		_looks[_mate_seat] = preload("res://src/world/interactables/npc.gd").look_of(mate_id, _robe)
	var elder_look := PlaceLooks.figure_look({"robe": _robe.to_html(false), "style": "bun", "hair": "grey"}, Color.GRAY)
	elder_look["accessories"] = PackedStringArray(["white_hair"])
	_elder_look = elder_look
	set_process(_moving)
	queue_redraw()


func seat_count() -> int:
	return _seats.size()


## The seated sect-mate's name, "" when none sits.
func mate_name() -> String:
	return _mate_name


func mate_seat_pos() -> Vector2:
	return _seats[_mate_seat] if _mate_seat >= 0 else Vector2(-1, -1)


func mat_rect() -> Rect2:
	return _mat


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var line := Color("2b2118")
	draw_rect(_mat, Color("8c3b32"))
	draw_rect(_mat, line, false, 1.0)
	draw_rect(_mat.grow(-3.0), GOLD, false, 1.0)
	_draw_person(_elder, _elder_look, "down", 0.0)
	for i in _seats.size():
		var p := _seats[i]
		PlaceArt.ellipse(self, p + Vector2(0, 2), Vector2(13.0, 5.0), Color("6b4e2e"))  # a cushion
		_draw_person(p, _looks[i], "up", 7.0)
		if i == _mate_seat:
			var font := ThemeDB.fallback_font
			var at := p + Vector2(-60.0, 22.0)
			draw_string(font, at + Vector2(1, 1), _mate_name, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, Color(0, 0, 0, 0.8))
			draw_string(font, at, _mate_name, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, Color("f2e3b8"))
	var bob := sin(_clock * 2.4) * 2.0 if _moving else 0.0
	_draw_bell(_elder + Vector2(20.0, -52.0 + bob))


## `sink` lowers the figure so the cushion hides its legs (seated).
func _draw_person(p: Vector2, look: Variant, dir: String, sink: float) -> void:
	var tex := PixelFigure.frame(look, dir, 0)
	var ts := Vector2(tex.get_size()) * _scale
	PlaceArt.ellipse(self, p + Vector2(0, 1), Vector2(ts.x * 0.35, 3.0), Color(0, 0, 0, 0.22))
	draw_texture_rect(tex, Rect2(p + Vector2(-ts.x / 2.0, -ts.y + sink), ts), false)


func _draw_bell(c: Vector2) -> void:
	var body := PackedVector2Array([c + Vector2(-5, 5), c + Vector2(-4, -2), c + Vector2(0, -6), c + Vector2(4, -2), c + Vector2(5, 5)])
	draw_colored_polygon(body, GOLD)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[0]]), Color("2b2118"), 1.0)
	draw_circle(c + Vector2(0, 7), 1.6, Color("2b2118"))
