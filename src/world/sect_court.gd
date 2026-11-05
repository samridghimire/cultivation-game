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


## GFX-074: "marsh" for the Withered Bone Marsh's dark court, "stone" elsewhere.
static func court_style(region: Dictionary) -> String:
	return "marsh" if "marsh" in String(region.get("id", "")) else "stone"


## GFX-071: what a place really covers: the drawn landmark (about 1.3x its size), the 22 px label band above
## it and 12 px of clearance.
static func place_footprint(place: Dictionary) -> Rect2:
	var r := _rect(place)
	var big := Rect2(r.get_center() - r.size * 0.65, r.size * 1.3)
	big.position.y -= 22.0
	big.size.y += 22.0
	return big.grow(12.0)


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
	if style == "marsh":
		_draw_marsh_court(ci, hall, court, snowy)
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


## GFX-074: dark flagstones, steps up into the hall, two red lanterns and reeds along the court's edge.
static func _draw_marsh_court(ci: CanvasItem, hall: Rect2, court: Rect2, snowy: bool) -> void:
	var base := Color("3b4140") if not snowy else Color("8d969a")
	var mortar := base.darkened(0.45)
	ci.draw_rect(court, base)
	var row := 0
	var y := court.position.y
	while y < court.end.y:
		ci.draw_line(Vector2(court.position.x, y), Vector2(court.end.x, y), mortar, 1.0)
		var x := court.position.x + (STONE / 2.0 if row % 2 == 1 else 0.0)
		while x < court.end.x:
			if x > court.position.x:
				ci.draw_line(Vector2(x, y), Vector2(x, minf(y + STONE, court.end.y)), mortar, 1.0)
			x += STONE * 2.0
		y += STONE
		row += 1
	ci.draw_rect(court, mortar.darkened(0.3), false, 2.0)
	ci.draw_rect(Rect2(court.position.x + 3.0, court.end.y + 2.0, court.size.x, 4.0), Color(0, 0, 0, 0.25))
	# Steps rise into the hall's lower edge (the court is shallow here).
	for i in 3:
		var w := 40.0 + 12.0 * i
		var step := Rect2(hall.get_center().x - w / 2.0, hall.end.y - 14.0 + 5.0 * i, w, 5.0)
		ci.draw_rect(step, base.lightened(0.2 - 0.05 * i))
		ci.draw_rect(Rect2(step.position.x, step.end.y - 1.0, w, 1.0), mortar)
	# Two red lanterns flank the hall on the court's flagstones.
	for lx in [court.position.x + 14.0, court.end.x - 14.0]:
		var c := Vector2(lx, hall.get_center().y + 18.0)
		ci.draw_rect(Rect2(c.x - 1.0, c.y - 6.0, 2.0, 20.0), Color("2b2118"))
		ci.draw_rect(Rect2(c.x - 5.0, c.y - 14.0, 10.0, 12.0), Color("8e1f1f"))
		ci.draw_rect(Rect2(c.x - 3.0, c.y - 12.0, 6.0, 8.0), Color("e04b3a"))
		ci.draw_rect(Rect2(c.x - 6.0, c.y - 15.0, 12.0, 2.0), Color("2b2118"))
	# Reeds along the west and north edges.
	var reed := Color("6b7a3a") if not snowy else Color("a9b49a")
	var n := int(court.size.y / 9.0)
	for i in n:
		var ry := court.position.y + 6.0 + i * 9.0
		ci.draw_line(Vector2(court.position.x - 2.0, ry + 8.0), Vector2(court.position.x - 4.0, ry - 4.0), reed, 1.0)
		ci.draw_line(Vector2(court.position.x - 5.0, ry + 8.0), Vector2(court.position.x - 6.0, ry), reed.darkened(0.2), 1.0)
	for i in int(court.size.x / 11.0):
		var rx := court.position.x + 6.0 + i * 11.0
		ci.draw_line(Vector2(rx, court.position.y - 1.0), Vector2(rx - 1.0, court.position.y - 9.0), reed, 1.0)


const STELE_W := 170.0
const POST_TOP := 38.0  ## post height above its foot line


## GFX-071: the pieces of the gate seen side-on: the roof band (north-south, over the road), both posts, the stele.
static func gate_parts(g: Dictionary) -> Dictionary:
	var path: Rect2 = g["path"]
	var gx: float = g["x"]
	var top := path.position.y - 20.0
	var bottom := path.end.y + 4.0
	var west: bool = gx < float(g.get("map_w", 1e9)) / 2.0
	var stele_x := gx + 18.0 if west else gx - 18.0 - STELE_W  # GFX-074: the board stands on the map side of the gate
	return {
		"roof": Rect2(gx - 14.0, top - POST_TOP - 8.0, 28.0, bottom - top + 16.0),
		"posts": [Rect2(gx - 11.0, top - POST_TOP, 22.0, POST_TOP + 16.0), Rect2(gx - 11.0, bottom - POST_TOP, 22.0, POST_TOP + 16.0)],
		"stele": Rect2(stele_x, top - POST_TOP - 6.0, STELE_W, POST_TOP + 12.0),
	}


## The screen rect the drawn gate covers (roof band, posts and name stele).
static func gate_rect(g: Dictionary) -> Rect2:
	var parts := gate_parts(g)
	var r: Rect2 = parts["roof"]
	r = r.merge(parts["stele"])
	for p: Rect2 in parts["posts"]:
		r = r.merge(p)
	return r


## GFX-071: a roofed gate seen from the south with the road passing under it: two posts on the path's edges,
## a tiled roof band running north-south between their tops, and the name on a stone stele beside the north post.
static func draw_gate(ci: CanvasItem, g: Dictionary, font: Font) -> void:
	var parts := gate_parts(g)
	var roof: Color = g["color"]
	var wood := Color("5a4030")
	var dark := Color("2b2118")
	var posts: Array = parts["posts"]
	var band: Rect2 = parts["roof"]
	var north: Rect2 = posts[0]
	var south: Rect2 = posts[1]
	_draw_post(ci, north, wood, dark)
	# Roof band with upturned ends sticking 8 px past each post.
	ci.draw_rect(band.grow(1.5), dark)
	ci.draw_rect(band, roof)
	ci.draw_rect(Rect2(band.position.x, band.position.y, 5.0, band.size.y), roof.lightened(0.25))
	var y := band.position.y + 3.0
	while y < band.end.y:
		ci.draw_line(Vector2(band.position.x, y), Vector2(band.end.x, y), roof.darkened(0.3), 1.0)
		y += 4.0
	for cap_y in [band.position.y, band.end.y - 3.0]:
		ci.draw_rect(Rect2(band.position.x - 2.0, cap_y, band.size.x + 4.0, 3.0), roof.lightened(0.15))
	_draw_post(ci, south, wood, dark)
	# Name stele: a plinth with the board on it, facing the viewer.
	var st: Rect2 = parts["stele"]
	var plinth := Rect2(st.get_center().x - 40.0, st.position.y + 26.0, 80.0, st.size.y - 26.0)
	ci.draw_rect(plinth.grow(1.0), dark)
	ci.draw_rect(plinth, Color("8d939b"))
	var board := Rect2(st.position.x, st.position.y, STELE_W, 26.0)
	ci.draw_rect(board.grow(2.0), dark)
	ci.draw_rect(board, wood.darkened(0.2))
	ci.draw_string(font, board.position + Vector2(0.0, 18.0), String(g["name"]), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 14, Color("f2e3b8"))


static func _draw_post(ci: CanvasItem, r: Rect2, wood: Color, dark: Color) -> void:
	var foot_y := r.end.y - 14.0
	ci.draw_rect(Rect2(r.position.x, foot_y, 22.0, 14.0), dark)
	ci.draw_rect(Rect2(r.position.x + 1.0, foot_y + 1.0, 20.0, 12.0), Color("8d939b"))
	ci.draw_rect(Rect2(r.position.x + 5.0, r.position.y, 12.0, 44.0), dark)
	ci.draw_rect(Rect2(r.position.x + 6.0, r.position.y + 1.0, 10.0, 42.0), wood)
	ci.draw_rect(Rect2(r.position.x + 6.0, r.position.y + 1.0, 3.0, 42.0), wood.lightened(0.2))
