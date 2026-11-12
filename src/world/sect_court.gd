class_name SectCourt
extends RefCounted
## GFX-068: the paved court in front of a sect hall and the mountain gate where the main path enters its region.
## Pure geometry (court_rect, gate) plus small _draw helpers; no node access.

const SCALE := 1.6
const STONE := 16.0
const TOP_MARGIN := 22.0  ## grass between the court's north edge and the hall roof
const GATE_X := 250.0  ## how far in from the map edge the gate stands (GFX-074: its pillars stand >= 120 px clear of the exit post)
const EXIT_CLEAR := 120.0


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
	for scale in [1.9, 1.7, 1.5, 1.35]:
		var size := Vector2(hr.size.x * (1.0 + (scale - 1.0) * 0.7), hr.size.y * scale)
		var r := Rect2(Vector2(hr.get_center().x - size.x / 2.0, hr.position.y - TOP_MARGIN), size)
		if bounds.encloses(r) and _clear(r, hall, region):
			return r
	# GFX-074: a hall hemmed in by neighbours gets a wide, shallow court (sideways and north, hardly any south).
	for ext in [40.0, 28.0, 16.0]:
		var r := Rect2(hr.position.x - ext, hr.position.y - TOP_MARGIN, hr.size.x + ext * 2.0, hr.size.y + TOP_MARGIN + 4.0)
		if bounds.encloses(r) and _clear(r, hall, region):
			return r
	return hr


## GFX-121: the ground a sect hall stands on: `hall_ground` on the place (planks | terrace | stone, default stone).
const GROUNDS: Array[String] = ["stone", "planks", "terrace"]


static func court_style(place: Dictionary) -> String:
	var g := String(place.get("hall_ground", "stone"))
	return g if GROUNDS.has(g) else "stone"


## GFX-071: what a place really covers: the drawn landmark (about 1.3x its size), the 22 px label band above
## it and 12 px of clearance.
static func place_footprint(place: Dictionary) -> Rect2:
	return Npcs.building_footprint(place)  # WU-489: one set of numbers


## WU-484: a person's final position: off the gate and off every building (Npcs.settle_stand).
static func settle_stand(pos: Vector2, region: Dictionary, named: bool) -> Vector2:
	var g := gate(region)
	var out := nudge_off_gate(pos, g)
	out = Npcs.settle_stand(out, region, named)
	return nudge_off_gate(out, g)


static func _clear(r: Rect2, hall: Dictionary, region: Dictionary) -> bool:
	for p in region["map"].get("paths", []):
		if r.intersects(Rect2(p[0], p[1], p[2], p[3])):
			return false
	for place: Dictionary in region.get("places", []):
		if place == hall:
			continue
		if r.intersects(place_footprint(place)):
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
	return {"path": path, "x": GATE_X if from_left else map_w - GATE_X, "name": String(region.get("name", "")), "color": post, "map_w": map_w}


## Flagstones, three steps to the door and two stone lanterns. `hall` is the hall's rect, `court` from court_rect().
static func draw_court(ci: CanvasItem, hall: Rect2, court: Rect2, snowy: bool, style: String = "stone") -> void:
	if style == "planks":
		_draw_planks_court(ci, hall, court, snowy)
		return
	if style == "terrace":
		_draw_terrace_court(ci, hall, court, snowy)
		return
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


## GFX-121: a raised boardwalk platform on short stilts with a rail along its front and reeds at its edge.
static func _draw_planks_court(ci: CanvasItem, hall: Rect2, court: Rect2, snowy: bool) -> void:
	var wood := Color("6b5238") if not snowy else Color("a9a597")
	var seam := wood.darkened(0.4)
	ci.draw_rect(Rect2(court.position.x + 2.0, court.end.y + 2.0, court.size.x, 6.0), Color(0.05, 0.08, 0.06, 0.35))
	ci.draw_rect(court, wood)
	var y := court.position.y + 8.0
	var row := 0
	while y < court.end.y:
		ci.draw_line(Vector2(court.position.x, y), Vector2(court.end.x, y), seam, 1.0)
		var x := court.position.x + (12.0 if row % 2 == 1 else 0.0) + 24.0
		while x < court.end.x:
			ci.draw_line(Vector2(x, y), Vector2(x, minf(y + 8.0, court.end.y)), seam, 1.0)
			x += 36.0
		y += 8.0
		row += 1
	ci.draw_rect(court, seam.darkened(0.2), false, 2.0)
	# Stilts under the front edge.
	var px := court.position.x + 8.0
	while px < court.end.x - 4.0:
		ci.draw_rect(Rect2(px, court.end.y, 4.0, 7.0), Color("2b2118"))
		px += 36.0
	# A low rail along the front with a gap in front of the door.
	var cx := hall.get_center().x
	var rail := Color("3a2a1c")
	for seg: Vector2 in [Vector2(court.position.x + 2.0, cx - 24.0), Vector2(cx + 24.0, court.end.x - 2.0)]:
		ci.draw_line(Vector2(seg.x, court.end.y - 4.0), Vector2(seg.y, court.end.y - 4.0), rail, 2.0)
		var rx := seg.x
		while rx <= seg.y:
			ci.draw_line(Vector2(rx, court.end.y - 4.0), Vector2(rx, court.end.y - 10.0), rail, 2.0)
			rx += 32.0
	# Steps up into the hall.
	for i in 3:
		var w := 40.0 + 12.0 * i
		var step := Rect2(cx - w / 2.0, hall.end.y - 14.0 + 5.0 * i, w, 5.0)
		ci.draw_rect(step, wood.lightened(0.2 - 0.05 * i))
		ci.draw_rect(Rect2(step.position.x, step.end.y - 1.0, w, 1.0), seam)
	# Two red lanterns flank the hall.
	for lx in [court.position.x + 14.0, court.end.x - 14.0]:
		var c := Vector2(lx, hall.get_center().y + 18.0)
		ci.draw_rect(Rect2(c.x - 1.0, c.y - 6.0, 2.0, 20.0), Color("2b2118"))
		ci.draw_rect(Rect2(c.x - 5.0, c.y - 14.0, 10.0, 12.0), Color("8e1f1f"))
		ci.draw_rect(Rect2(c.x - 3.0, c.y - 12.0, 6.0, 8.0), Color("e04b3a"))
		ci.draw_rect(Rect2(c.x - 6.0, c.y - 15.0, 12.0, 2.0), Color("2b2118"))
	# Reeds along the west and north edges (iced in winter).
	var reed := Color("6b7a3a") if not snowy else Color("b9d2dc")
	for i in int(court.size.y / 9.0):
		var ry := court.position.y + 6.0 + i * 9.0
		ci.draw_line(Vector2(court.position.x - 2.0, ry + 8.0), Vector2(court.position.x - 4.0, ry - 4.0), reed, 1.0)
		ci.draw_line(Vector2(court.position.x - 5.0, ry + 8.0), Vector2(court.position.x - 6.0, ry), reed.darkened(0.2), 1.0)
	for i in int(court.size.x / 11.0):
		var rx := court.position.x + 6.0 + i * 11.0
		ci.draw_line(Vector2(rx, court.position.y - 1.0), Vector2(rx - 1.0, court.position.y - 9.0), reed, 1.0)


## GFX-121: pale stone flags on a raised terrace, a step along the front and snow on the edge in winter.
static func _draw_terrace_court(ci: CanvasItem, hall: Rect2, court: Rect2, snowy: bool) -> void:
	var base := Color("c9ccd0") if not snowy else Color("e6eaee")
	var mortar := base.darkened(0.22)
	ci.draw_rect(Rect2(court.position.x + 3.0, court.end.y + 2.0, court.size.x, 7.0), Color(0, 0, 0, 0.25))
	ci.draw_rect(court, base)
	var row := 0
	var y := court.position.y
	while y < court.end.y:
		ci.draw_line(Vector2(court.position.x, y), Vector2(court.end.x, y), mortar, 1.0)
		var x := court.position.x + (STONE if row % 2 == 1 else 0.0)
		while x < court.end.x:
			if x > court.position.x:
				ci.draw_line(Vector2(x, y), Vector2(x, minf(y + STONE, court.end.y)), mortar, 1.0)
			x += STONE * 2.0
		y += STONE
		row += 1
	ci.draw_rect(court, mortar.darkened(0.2), false, 2.0)
	# The front step: a lighter lip over a shaded riser.
	ci.draw_rect(Rect2(court.position.x, court.end.y - 6.0, court.size.x, 6.0), base.darkened(0.12))
	ci.draw_rect(Rect2(court.position.x, court.end.y - 6.0, court.size.x, 2.0), base.lightened(0.2))
	var cx := hall.get_center().x
	for i in 3:
		var w := 44.0 + 14.0 * i
		var step := Rect2(cx - w / 2.0, hall.end.y + 6.0 * i, w, 6.0)
		ci.draw_rect(step, base.lightened(0.15 - 0.04 * i))
		ci.draw_rect(Rect2(step.position.x, step.end.y - 1.0, w, 1.0), mortar)
	for side in [-1.0, 1.0]:
		var c := Vector2(court.get_center().x + side * (court.size.x / 2.0 - 16.0), court.end.y - 22.0)
		ci.draw_rect(Rect2(c.x - 5.0, c.y + 8.0, 10.0, 4.0), mortar)
		ci.draw_rect(Rect2(c.x - 3.0, c.y - 2.0, 6.0, 10.0), base.darkened(0.15))
		ci.draw_rect(Rect2(c.x - 6.0, c.y - 9.0, 12.0, 7.0), base.lightened(0.1))
		ci.draw_rect(Rect2(c.x - 3.0, c.y - 7.0, 6.0, 3.0), Color("f2c75c"))
	if snowy:
		ci.draw_rect(Rect2(court.position.x - 2.0, court.position.y - 3.0, court.size.x + 4.0, 4.0), Color("f4f8fb"))
		ci.draw_rect(Rect2(court.position.x - 2.0, court.end.y - 2.0, court.size.x + 4.0, 5.0), Color("f4f8fb"))
		for i in int(court.size.x / 28.0):
			ci.draw_rect(Rect2(court.position.x + 8.0 + i * 28.0, court.end.y + 3.0, 6.0, 4.0), Color("d6e6ef"))


const STELE_W := 136.0  ## the hanging name board (its minimum width)
const STELE_MAX_W := 160.0  ## GFX-103: the board grows to fit the name up to this width
const STELE_PAD := 12.0
const STELE_SIZES: Array[int] = [13, 12, 11]  ## font sizes tried, largest first, before the name goes on two lines
const POST_H := 64.0  ## post height above its foot line (GFX-076)
const POST_BASE := 8.0  ## plinth below the foot line
const ROOF_W := 40.0
const GATE_KEEP := 24.0  ## decor and idle villagers stay this far off the gate
const DECOR_KEEP := 40.0  ## GFX-082: trees and rocks stay this far off the gate and every travel place


## GFX-082: `decor` (Scenery.place output) without anything within DECOR_KEEP px of the gate's rect or of a travel
## place's rect, or whose tree footprint touches the gate. One rule for every region.
static func filter_decor(region: Dictionary, decor: Array[Dictionary]) -> Array[Dictionary]:
	var keeps: Array[Rect2] = []
	var g := gate(region)
	if not g.is_empty():
		keeps.append(gate_rect(g).grow(DECOR_KEEP))
	for place: Dictionary in region.get("places", []):
		if String(place.get("type", "")) != "travel":
			continue
		var pos: Array = place.get("pos", [0, 0])
		var sz: Array = place.get("size", [64, 64])
		var size := Vector2(float(sz[0]), float(sz[1]))
		keeps.append(Rect2(Vector2(float(pos[0]), float(pos[1])) - size / 2.0, size).grow(DECOR_KEEP))
	var out: Array[Dictionary] = []
	for d in decor:
		var foot := Rect2(d["pos"] - Vector2(16, 44), Vector2(32, 60))
		var hit := false
		for k in keeps:
			if k.has_point(d["pos"]) or k.intersects(foot):
				hit = true
				break
		if not hit:
			out.append(d)
	return out


## GFX-103: how the name fits the board: {w, size, lines}. Widen up to STELE_MAX_W, then the next smaller size,
## then two lines (split at the space nearest the middle) at the smallest size.
static func board_layout(name: String, font: Font) -> Dictionary:
	for fs: int in STELE_SIZES:
		var need := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + STELE_PAD
		if need <= STELE_MAX_W:
			return {"w": maxf(STELE_W, need), "size": fs, "lines": [name]}
	var fs: int = STELE_SIZES[-1]
	var mid := name.length() / 2
	var cut := -1
	for i in name.length():
		if name[i] == " " and (cut < 0 or absi(i - mid) < absi(cut - mid)):
			cut = i
	var lines: Array = [name] if cut < 0 else [name.substr(0, cut), name.substr(cut + 1)]
	return {"w": STELE_MAX_W, "size": fs, "lines": lines}


## GFX-076: the gate in 3/4 view. Posts stand on the north and south road verges (feet 4 px off the path); the roof
## is lifted by the post height and spans from the north post's top to the south post's top; the name board hangs
## under the roof's south end.
static func gate_parts(g: Dictionary) -> Dictionary:
	var path: Rect2 = g["path"]
	var gx: float = g["x"]
	var north_foot := path.position.y - 4.0
	var south_foot := path.end.y + 4.0
	var top := north_foot - POST_H
	var roof_end := south_foot - POST_H
	var board_w := float(board_layout(String(g.get("name", "")), ThemeDB.fallback_font)["w"])
	return {
		"roof": Rect2(gx - ROOF_W / 2.0, top, ROOF_W, roof_end - top),
		"posts": [Rect2(gx - 13.0, top, 26.0, POST_H + POST_BASE), Rect2(gx - 13.0, roof_end, 26.0, POST_H + POST_BASE)],
		"stele": Rect2(gx - board_w / 2.0, roof_end + 10.0, board_w, 22.0),
	}


## The screen rect the drawn gate covers (roof, posts and name board).
static func gate_rect(g: Dictionary) -> Rect2:
	var parts := gate_parts(g)
	var r: Rect2 = parts["roof"]
	r = r.merge(parts["stele"])
	for p: Rect2 in parts["posts"]:
		r = r.merge(p)
	return r


## GFX-076: `pos` pushed out of the gate's keep-out zone (gate_rect grown by GATE_KEEP), along the shortest way out.
static func nudge_off_gate(pos: Vector2, g: Dictionary) -> Vector2:
	if g.is_empty():
		return pos
	var keep := gate_rect(g).grow(GATE_KEEP)
	if not keep.has_point(pos):
		return pos
	var options: Array[Vector2] = [
		Vector2(keep.position.x - 1.0, pos.y), Vector2(keep.end.x + 1.0, pos.y),
		Vector2(pos.x, keep.position.y - 1.0), Vector2(pos.x, keep.end.y + 1.0),
	]
	var best := options[0]
	for o in options:
		if o.distance_to(pos) < best.distance_to(pos):
			best = o
	return best


## GFX-076: two posts either side of the road, a lifted roof joining their tops (lighter top face, darker south
## edge, upturned eave ends), a soft shadow on the road under it and the region's name on a board.
static func draw_gate(ci: CanvasItem, g: Dictionary, font: Font) -> void:
	var parts := gate_parts(g)
	var roof: Color = g["color"]
	var wood := Color("5a4030")
	var dark := Color("2b2118")
	var posts: Array = parts["posts"]
	var band: Rect2 = parts["roof"]
	var path: Rect2 = g["path"]
	ci.draw_rect(Rect2(band.position.x - 2.0, path.position.y, band.size.x + 4.0, path.size.y), Color(0, 0, 0, 0.2))
	ci.draw_rect(band.grow(1.5), dark)
	ci.draw_rect(band, roof.lightened(0.15))
	var y := band.position.y + 4.0
	while y < band.end.y - 6.0:
		ci.draw_line(Vector2(band.position.x, y), Vector2(band.end.x, y), roof.darkened(0.15), 1.0)
		y += 5.0
	ci.draw_rect(Rect2(band.position.x, band.end.y - 6.0, band.size.x, 6.0), roof.darkened(0.35))
	for ex in [band.position.x - 4.0, band.end.x - 2.0]:
		for ey in [band.position.y - 3.0, band.end.y - 4.0]:
			ci.draw_rect(Rect2(ex, ey, 6.0, 4.0), roof.lightened(0.3))
	for post: Rect2 in posts:
		_draw_post(ci, post, wood, dark)
	var board: Rect2 = parts["stele"]
	ci.draw_rect(board.grow(2.0), dark)
	ci.draw_rect(board, wood.darkened(0.2))
	ci.draw_line(Vector2(board.position.x + 10.0, board.position.y - 2.0), Vector2(board.position.x + 10.0, board.position.y - 8.0), dark, 2.0)
	ci.draw_line(Vector2(board.end.x - 10.0, board.position.y - 2.0), Vector2(board.end.x - 10.0, board.position.y - 8.0), dark, 2.0)
	var fit := board_layout(String(g["name"]), font)
	var lines: Array = fit["lines"]
	for i in lines.size():
		var dy := 16.0 if lines.size() == 1 else 10.0 + 10.0 * i
		ci.draw_string(font, board.position + Vector2(0.0, dy), String(lines[i]), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, int(fit["size"]), Color("f2e3b8"))


static func _draw_post(ci: CanvasItem, r: Rect2, wood: Color, dark: Color) -> void:
	var foot_y := r.end.y - POST_BASE
	ci.draw_rect(Rect2(r.position.x, foot_y, r.size.x, POST_BASE), dark)
	ci.draw_rect(Rect2(r.position.x + 1.0, foot_y + 1.0, r.size.x - 2.0, POST_BASE - 2.0), Color("8d939b"))
	var cx := r.get_center().x
	ci.draw_rect(Rect2(cx - 7.0, r.position.y + 4.0, 14.0, foot_y - r.position.y - 4.0), dark)
	ci.draw_rect(Rect2(cx - 6.0, r.position.y + 4.0, 12.0, foot_y - r.position.y - 5.0), wood)
	ci.draw_rect(Rect2(cx - 6.0, r.position.y + 4.0, 3.0, foot_y - r.position.y - 5.0), wood.lightened(0.2))
	ci.draw_rect(Rect2(cx - 10.0, r.position.y, 20.0, 6.0), dark)
	ci.draw_rect(Rect2(cx - 9.0, r.position.y + 1.0, 18.0, 4.0), wood.lightened(0.1))


## GFX-113: a carved rail along the court's open sides (west, east and south), as posts every 24 px and a rail between them;
## the south side leaves a 40 px gap at the court's centre for the walk. Returns {posts: Array[Rect2], rails: Array[Rect2]}.
static func rail_parts(court: Rect2) -> Dictionary:
	var posts: Array[Rect2] = []
	var rails: Array[Rect2] = []
	var inner := court.grow(-3.0)
	var gap_l := court.get_center().x - 20.0
	var gap_r := court.get_center().x + 20.0
	var y := inner.position.y + 24.0
	while y <= inner.end.y:
		posts.append(Rect2(inner.position.x - 2.0, y - 8.0, 4.0, 10.0))
		posts.append(Rect2(inner.end.x - 2.0, y - 8.0, 4.0, 10.0))
		y += 24.0
	rails.append(Rect2(inner.position.x - 1.0, inner.position.y + 14.0, 2.0, inner.size.y - 14.0))
	rails.append(Rect2(inner.end.x - 1.0, inner.position.y + 14.0, 2.0, inner.size.y - 14.0))
	var x := inner.position.x
	while x <= inner.end.x:
		if x < gap_l - 4.0 or x > gap_r + 4.0:
			posts.append(Rect2(x - 2.0, inner.end.y - 8.0, 4.0, 10.0))
		x += 24.0
	rails.append(Rect2(inner.position.x, inner.end.y - 6.0, gap_l - inner.position.x, 2.0))
	rails.append(Rect2(gap_r, inner.end.y - 6.0, inner.end.x - gap_r, 2.0))
	return {"posts": posts, "rails": rails}


static func draw_rail(ci: CanvasItem, court: Rect2, snowy: bool) -> void:
	var parts := rail_parts(court)
	var wood := Color("6b5a48")
	var lit := Color("a58c6c")
	for r: Rect2 in parts["rails"]:
		ci.draw_rect(r, wood)
		ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), lit)
	for p: Rect2 in parts["posts"]:
		ci.draw_rect(p, wood)
		ci.draw_rect(Rect2(p.position.x - 1.0, p.position.y - 2.0, p.size.x + 2.0, 3.0), lit)
		if snowy:
			ci.draw_rect(Rect2(p.position.x - 1.0, p.position.y - 3.0, p.size.x + 2.0, 2.0), Color("eef3f7"))
