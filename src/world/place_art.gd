class_name PlaceArt
extends RefCounted
## Placeholder art for world places (VIS-003), drawn in the place's _draw():
## one look per regions.json place type plus "npc". Shapes scale with the
## place's size and are tinted with its color. Unknown kinds draw a plain box.

## Kinds with their own look; anything else is a plain box.
const KINDS := ["meditation", "merchant", "workshop", "sect_hall", "travel", "gather", "explore", "deed_giver", "npc"]
const OUTLINE := Color("2a2018")
const WOOD := Color("6b4a2e")
const STONE := Color("8d8a82")


static func draw(ci: CanvasItem, kind: String, size: Vector2, color: Color) -> void:
	var h := size / 2.0
	match kind:
		"meditation":
			_meditation(ci, h, color)
		"merchant":
			_merchant(ci, h, color)
		"workshop":
			_workshop(ci, h, color)
		"sect_hall":
			_sect_hall(ci, h, color)
		"travel":
			_gate(ci, h, color)
		"gather":
			_herb_patch(ci, h, color)
		"explore":
			_cave(ci, h, color)
		"deed_giver", "npc":
			_figure(ci, h, color)
		_:
			ci.draw_rect(Rect2(-h, size), color)
			ci.draw_rect(Rect2(-h, size), color.darkened(0.5), false, 2.0)


## Ellipse filled (or outlined with width > 0) centered at `center`.
static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, width: float = -1.0) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(center + Vector2.from_angle(TAU * i / 32.0) * radii)
	if width > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, color, width)
	else:
		ci.draw_colored_polygon(pts, color)


## A pool of qi (the place color) ringed by flat stones.
static func _meditation(ci: CanvasItem, h: Vector2, c: Color) -> void:
	ellipse(ci, Vector2.ZERO, h, c.lightened(0.35))
	ellipse(ci, Vector2.ZERO, h * 0.75, c)
	for i in 10:
		var p := Vector2.from_angle(TAU * i / 10.0) * h * 0.92
		ellipse(ci, p, Vector2(6, 4), STONE)
		ellipse(ci, p, Vector2(6, 4), OUTLINE, 1.0)
	ellipse(ci, Vector2.ZERO, h * 0.25, Color(1, 1, 1, 0.35))


## A wooden counter with a striped awning in the place color.
static func _merchant(ci: CanvasItem, h: Vector2, c: Color) -> void:
	var counter := Rect2(Vector2(-h.x, 0), Vector2(h.x * 2.0, h.y))
	ci.draw_rect(counter, WOOD)
	ci.draw_rect(counter, OUTLINE, false, 2.0)
	ci.draw_line(Vector2(-h.x + 3, -h.y), Vector2(-h.x + 3, 0), WOOD.darkened(0.3), 3.0)
	ci.draw_line(Vector2(h.x - 3, -h.y), Vector2(h.x - 3, 0), WOOD.darkened(0.3), 3.0)
	var stripes := 6
	var w := h.x * 2.0 / stripes
	for i in stripes:
		var col := c if i % 2 == 0 else c.lightened(0.6)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-h.x + i * w, -h.y), Vector2(-h.x + (i + 1) * w, -h.y),
			Vector2(-h.x + (i + 1) * w, -h.y * 0.4), Vector2(-h.x + i * w, -h.y * 0.4)]), col)
	ci.draw_rect(Rect2(Vector2(-h.x, -h.y), Vector2(h.x * 2.0, h.y * 0.6)), OUTLINE, false, 1.5)
	# Goods on the counter.
	for i in 3:
		ellipse(ci, Vector2(-h.x * 0.5 + i * h.x * 0.5, h.y * 0.2), Vector2(5, 4), c.lightened(0.2))


## A house with a dark roof, a chimney and a glowing furnace door.
static func _workshop(ci: CanvasItem, h: Vector2, c: Color) -> void:
	var wall := Rect2(Vector2(-h.x, -h.y * 0.2), Vector2(h.x * 2.0, h.y * 1.2))
	ci.draw_rect(wall, c)
	ci.draw_rect(wall, OUTLINE, false, 2.0)
	ci.draw_rect(Rect2(Vector2(h.x * 0.45, -h.y), Vector2(h.x * 0.2, h.y * 0.6)), STONE.darkened(0.2))
	var roof := PackedVector2Array([Vector2(-h.x - 6, -h.y * 0.2), Vector2(0, -h.y * 0.9), Vector2(h.x + 6, -h.y * 0.2)])
	ci.draw_colored_polygon(roof, c.darkened(0.55))
	ci.draw_rect(Rect2(Vector2(-h.x * 0.25, h.y * 0.3), Vector2(h.x * 0.5, h.y * 0.7)), Color("e8762c"))
	ci.draw_rect(Rect2(Vector2(-h.x * 0.15, h.y * 0.5), Vector2(h.x * 0.3, h.y * 0.5)), Color("ffd36b"))


## A hall with a two-tier roof with upturned eaves and a central door.
static func _sect_hall(ci: CanvasItem, h: Vector2, c: Color) -> void:
	var wall := Rect2(Vector2(-h.x * 0.85, -h.y * 0.1), Vector2(h.x * 1.7, h.y * 1.1))
	ci.draw_rect(wall, c)
	ci.draw_rect(wall, OUTLINE, false, 2.0)
	var roof_color := Color("2f3a3f")
	for tier in 2:
		var y := -h.y * (0.1 + 0.45 * tier)
		var wx := h.x * (1.0 - 0.3 * tier)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-wx - 8, y - 8), Vector2(-wx * 0.7, y - h.y * 0.35), Vector2(wx * 0.7, y - h.y * 0.35),
			Vector2(wx + 8, y - 8), Vector2(wx * 0.8, y), Vector2(-wx * 0.8, y)]), roof_color)
	ci.draw_rect(Rect2(Vector2(-h.x * 0.15, h.y * 0.35), Vector2(h.x * 0.3, h.y * 0.65)), c.darkened(0.6))
	for x in [-0.6, 0.6]:
		ci.draw_line(Vector2(h.x * x, -h.y * 0.1), Vector2(h.x * x, h.y), c.darkened(0.35), 4.0)


## A paifang gate: two pillars and a crossbeam, oriented along the long side.
static func _gate(ci: CanvasItem, h: Vector2, c: Color) -> void:
	var vertical := h.y > h.x
	var a := Vector2(0, -h.y) if vertical else Vector2(-h.x, 0)
	var b := -a
	var pillar := Vector2(maxf(h.x, h.y) * 0.18, maxf(h.x, h.y) * 0.18)
	ci.draw_line(a, b, c.lightened(0.3), minf(h.x, h.y) * 1.2)
	for p in [a * 0.85, b * 0.85]:
		ci.draw_rect(Rect2(p - pillar / 2.0, pillar), c.darkened(0.3))
		ci.draw_rect(Rect2(p - pillar / 2.0, pillar), OUTLINE, false, 1.5)
	ci.draw_line(a * 1.05, b * 1.05, c.darkened(0.5), 5.0)


## Tilled soil with sprouting herbs in the place color.
static func _herb_patch(ci: CanvasItem, h: Vector2, c: Color) -> void:
	ellipse(ci, Vector2.ZERO, h, Color("5a4330"))
	ellipse(ci, Vector2.ZERO, h, OUTLINE, 1.5)
	for row in 2:
		for col in 4:
			var p := Vector2(-h.x * 0.6 + col * h.x * 0.4, -h.y * 0.25 + row * h.y * 0.5)
			ci.draw_line(p + Vector2(0, 5), p + Vector2(-4, -3), c, 2.0)
			ci.draw_line(p + Vector2(0, 5), p + Vector2(4, -3), c, 2.0)
			ci.draw_circle(p + Vector2(0, -4), 2.5, c.lightened(0.3))


## A rock mound (tinted with the place color) with a dark cave mouth.
static func _cave(ci: CanvasItem, h: Vector2, c: Color) -> void:
	var rock := STONE.lerp(c, 0.4)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-h.x, h.y), Vector2(-h.x * 0.8, -h.y * 0.3), Vector2(-h.x * 0.3, -h.y),
		Vector2(h.x * 0.35, -h.y * 0.85), Vector2(h.x * 0.85, -h.y * 0.2), Vector2(h.x, h.y)]), rock)
	ci.draw_line(Vector2(-h.x * 0.3, -h.y), Vector2(h.x * 0.35, -h.y * 0.85), rock.lightened(0.3), 3.0)
	var mouth := PackedVector2Array()
	for i in 17:
		mouth.append(Vector2.from_angle(PI + PI * i / 16.0) * Vector2(h.x * 0.4, h.y * 0.75) + Vector2(0, h.y))
	ci.draw_colored_polygon(mouth, Color("140f0c"))


## A small robed figure: robe in the NPC color, head and hair.
static func _figure(ci: CanvasItem, h: Vector2, c: Color) -> void:
	ellipse(ci, Vector2(0, h.y * 0.9), Vector2(h.x * 0.8, h.y * 0.25), Color(0, 0, 0, 0.3))
	var robe := PackedVector2Array([Vector2(-h.x * 0.45, -h.y * 0.3), Vector2(h.x * 0.45, -h.y * 0.3), Vector2(h.x * 0.8, h.y * 0.9), Vector2(-h.x * 0.8, h.y * 0.9)])
	ci.draw_colored_polygon(robe, c)
	robe.append(robe[0])
	ci.draw_polyline(robe, OUTLINE, 1.5)
	var head := Vector2(0, -h.y * 0.6)
	ci.draw_circle(head, h.x * 0.45, Color("e8d9a8"))
	ci.draw_arc(head, h.x * 0.45, 0, TAU, 20, OUTLINE, 1.5)
	ci.draw_circle(head + Vector2(0, -h.y * 0.35), h.x * 0.22, Color("2a2018"))
