class_name SectCourt
extends RefCounted
## GFX-068: the paved court in front of a sect hall and the mountain gate where the main path enters its region.
## Pure geometry (court_rect, gate) plus small _draw helpers; no node access.

const SCALE := 1.6
const STONE := 16.0
const TOP_MARGIN := 22.0  ## grass between the court's north edge and the hall roof
const GATE_X := 210.0  ## how far in from the map edge the gate stands
const GATE_NAME_W := 184.0
const GATE_ROOF_RISE := 46.0  ## GFX-070: lintel centre above the path's top edge (minus 20)


static func _rect(entry: Dictionary) -> Rect2:
	var pos: Array = entry.get("pos", [0, 0])
	var size: Array = entry.get("size", [64, 64])
	return Rect2(Vector2(float(pos[0]) - float(size[0]) / 2.0, float(pos[1]) - float(size[1]) / 2.0), Vector2(float(size[0]), float(size[1])))


## True for a hall that belongs to a sect (MISSION-002's `sect` field).
static func is_sect_hall(place: Dictionary) -> bool:
	return String(place.get("type", "")) == "sect_hall" and String(place.get("sect", "")) != ""


## GFX-070: the court under `hall`: the hall stands in its north half (22 px of grass above it for the label),
## the rest of the court lies south of it. Inside the map and clear of every path and other place.
## Tries smaller scales until one is clear; the hall's own rect is the last resort.
static func court_rect(hall: Dictionary, region: Dictionary) -> Rect2:
	var hr := _rect(hall)
	var map_size := Vector2(float(region["map"]["size"][0]), float(region["map"]["size"][1]))
	var bounds := Rect2(Vector2.ZERO, map_size).grow(-8.0)
	for scale in [1.9, 1.7, 1.5]:
		var size := Vector2(hr.size.x * (1.0 + (scale - 1.0) * 0.7), hr.size.y * scale)
		var r := Rect2(Vector2(hr.get_center().x - size.x / 2.0, hr.position.y - TOP_MARGIN), size)
		if bounds.encloses(r) and _clear(r, hall, region):
			return r
	return hr


static func _clear(r: Rect2, hall: Dictionary, region: Dictionary) -> bool:
	for p in region["map"].get("paths", []):
		if r.intersects(Rect2(p[0], p[1], p[2], p[3])):
			return false
	for place: Dictionary in region.get("places", []):
		if place == hall:
			continue
		if r.intersects(_rect(place)):
			return false
	return true


## {"path": Rect2, "x": float, "name": String} for the gate, or {} when the region has no sect hall with a sect.
## The gate stands on the first path, GATE_X in from the map edge nearest the region's travel place.
static func gate(region: Dictionary) -> Dictionary:
	var has_hall := false
	var post := Color("6f7f90")
	for place: Dictionary in region.get("places", []):
		if is_sect_hall(place):
			has_hall = true
			post = Color(String(place.get("color", "6f7f90"))).darkened(0.25)
	var paths: Array = region.get("map", {}).get("paths", [])
	if not has_hall or paths.is_empty():
		return {}
	var p: Array = paths[0]
	var path := Rect2(p[0], p[1], p[2], p[3])
	var map_w := float(region["map"]["size"][0])
	var from_left := true
	for place: Dictionary in region["places"]:
		if String(place.get("type", "")) == "travel":
			from_left = float(place["pos"][0]) < map_w / 2.0
			break
	return {"path": path, "x": GATE_X if from_left else map_w - GATE_X, "name": String(region.get("name", "")), "color": post}


## Flagstones, three steps to the door and two stone lanterns. `hall` is the hall's rect, `court` from court_rect().
static func draw_court(ci: CanvasItem, hall: Rect2, court: Rect2, snowy: bool) -> void:
	var base := Color("8d939b") if not snowy else Color("c3cad2")
	var mortar := base.darkened(0.3)
	ci.draw_rect(court, base)
	var row := 0
	var y := court.position.y
	while y < court.end.y:
		var shift := STONE / 2.0 if row % 2 == 1 else 0.0
		ci.draw_line(Vector2(court.position.x, y), Vector2(court.end.x, y), mortar, 1.0)
		var x := court.position.x + shift
		while x < court.end.x:
			if x > court.position.x:
				ci.draw_line(Vector2(x, y), Vector2(x, minf(y + STONE, court.end.y)), mortar, 1.0)
			x += STONE * 2.0
		y += STONE
		row += 1
	# Paler cross of flagstones from the steps to the hall door, and along the court's width below them.
	var walk := base.lightened(0.14)
	var cx := hall.get_center().x
	ci.draw_rect(Rect2(cx - 14.0, hall.end.y, 28.0, court.end.y - hall.end.y), walk)
	ci.draw_rect(Rect2(court.position.x + 4.0, hall.end.y + 30.0, court.size.x - 8.0, 20.0), walk)
	ci.draw_rect(Rect2(cx - 14.0, hall.end.y, 1.0, court.end.y - hall.end.y), mortar)
	ci.draw_rect(Rect2(cx + 13.0, hall.end.y, 1.0, court.end.y - hall.end.y), mortar)
	ci.draw_rect(court, mortar.darkened(0.2), false, 2.0)
	ci.draw_rect(Rect2(court.position.x + 3.0, court.end.y + 2.0, court.size.x, 5.0), Color(0, 0, 0, 0.22))
	# Three steps below the hall, each a little wider and lighter than the one above.
	for i in 3:
		var w := 44.0 + 14.0 * i
		var step := Rect2(hall.get_center().x - w / 2.0, hall.end.y + 6.0 * i, w, 6.0)
		ci.draw_rect(step, base.lightened(0.18 - 0.05 * i))
		ci.draw_rect(Rect2(step.position.x, step.end.y - 1.0, w, 1.0), mortar)
	for side in [-1.0, 1.0]:
		var c := Vector2(court.get_center().x + side * (court.size.x / 2.0 - 16.0), court.end.y - 18.0)
		ci.draw_rect(Rect2(c.x - 5.0, c.y + 8.0, 10.0, 4.0), mortar)
		ci.draw_rect(Rect2(c.x - 3.0, c.y - 2.0, 6.0, 10.0), base.darkened(0.15))
		ci.draw_rect(Rect2(c.x - 6.0, c.y - 9.0, 12.0, 7.0), base.lightened(0.1))
		ci.draw_rect(Rect2(c.x - 3.0, c.y - 7.0, 6.0, 3.0), Color("f2c75c"))


## The screen rect the drawn gate covers (lintel and board to the stone feet).
static func gate_rect(g: Dictionary) -> Rect2:
	var path: Rect2 = g["path"]
	var top := path.position.y - 20.0 - GATE_ROOF_RISE - 14.0
	var bottom := path.end.y + 4.0 + 16.0
	return Rect2(g["x"] - GATE_NAME_W / 2.0 - 14.0, top, GATE_NAME_W + 28.0, bottom - top)


## GFX-070: a roofed gate across the path: two tall posts, a tiled lintel with upturned ends in the hall's
## colour, and the name board hanging under it. About twice the old height.
static func draw_gate(ci: CanvasItem, g: Dictionary, font: Font) -> void:
	var path: Rect2 = g["path"]
	var gx: float = g["x"]
	var top := path.position.y - 20.0
	var bottom := path.end.y + 4.0
	var roof: Color = g["color"]
	var wood := Color("5a4030")
	var dark := Color("2b2118")
	var span := maxf(GATE_NAME_W, 120.0) / 2.0 + 14.0
	# Posts: one each side of the path, drawn as tall pillars on a stone foot.
	for py in [top, bottom]:
		ci.draw_rect(Rect2(gx - 11.0, py + 2.0, 22.0, 14.0), dark)
		ci.draw_rect(Rect2(gx - 10.0, py + 3.0, 20.0, 12.0), Color("8d939b"))
		ci.draw_rect(Rect2(gx - 6.0, py - 38.0, 12.0, 44.0), dark)
		ci.draw_rect(Rect2(gx - 5.0, py - 37.0, 10.0, 42.0), wood)
		ci.draw_rect(Rect2(gx - 5.0, py - 37.0, 3.0, 42.0), wood.lightened(0.2))
	# Lintel: a curved tiled roof band with upturned ends, centred on the path.
	var cy := top - GATE_ROOF_RISE
	var pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var x := gx - span + t * span * 2.0
		pts.append(Vector2(x, cy - 7.0 * pow(absf(t * 2.0 - 1.0), 2.2)))
	ci.draw_polyline(pts, dark, 14.0)
	ci.draw_polyline(pts, roof, 11.0)
	var hi := PackedVector2Array()
	for p in pts:
		hi.append(p + Vector2(0.0, -4.0))
	ci.draw_polyline(hi, roof.lightened(0.25), 2.0)
	for i in range(0, pts.size(), 2):
		ci.draw_line(pts[i] + Vector2(0.0, -4.0), pts[i] + Vector2(0.0, 5.0), roof.darkened(0.3), 1.0)
	# Name board hanging under the lintel.
	var board := Rect2(gx - GATE_NAME_W / 2.0, cy + 8.0, GATE_NAME_W, 22.0)
	ci.draw_line(Vector2(board.position.x + 12.0, cy + 4.0), Vector2(board.position.x + 12.0, board.position.y), dark, 2.0)
	ci.draw_line(Vector2(board.end.x - 12.0, cy + 4.0), Vector2(board.end.x - 12.0, board.position.y), dark, 2.0)
	ci.draw_rect(board.grow(2.0), dark)
	ci.draw_rect(board, wood.darkened(0.2))
	ci.draw_string(font, board.position + Vector2(0.0, 16.0), String(g["name"]), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 14, Color("f2e3b8"))
