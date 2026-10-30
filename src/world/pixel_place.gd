class_name PixelPlace
extends RefCounted
## Generated pixel-art buildings and stalls (GFX-021): village places use these until a sprite pack is mapped
## in data/sprites.json (GFX-002/003). Each kind is a small canvas of text rows (one char per pixel, drawn at
## Sprites.scale()), assembled from rectangles and hip roofs, then outlined on its silhouette edge.
## . transparent, o outline, w wall, W wall shade, r roof (the place colour), R roof shade, h roof highlight,
## d door / dark opening, t timber, T timber shade, p paper / window, g gold trim, s stone, S stone shade.
## Rendering only: pure and deterministic, no node access.

const KINDS := ["merchant", "workshop", "sect_hall", "clinic", "orphanage", "family_home", "bounty_board", "travel", "auction"]
const PALETTE := ".owWrRhdtTpgsS"
const OUTLINE := Color("2b2118")
const DOOR := Color("3a2f26")
const COLORS := {
	"o": OUTLINE, "w": Color("d9cdb4"), "W": Color("b3a68c"), "d": DOOR, "t": Color("6e5636"), "T": Color("4f3d26"),
	"p": Color("e8dcc0"), "g": Color("c9a24a"), "s": Color("8a8478"), "S": Color("6a6559"),
}

static var _cache: Dictionary = {}


static func supports(kind: String) -> bool:
	return KINDS.has(kind)


## Pixel size of the template for `kind` (travel flips with the gate's orientation).
static func template_size(kind: String, horizontal: bool = true) -> Vector2i:
	var r := rows(kind, horizontal)
	return Vector2i(r[0].length(), r.size()) if not r.is_empty() else Vector2i.ZERO


static func texture(kind: String, size: Vector2, color: Color) -> ImageTexture:
	var horizontal := size.x >= size.y
	var key := "%s|%s|%s" % [kind, color.to_html(), horizontal if kind == "travel" else true]
	if _cache.has(key):
		return _cache[key]
	var r := rows(kind, horizontal)
	var img := Image.create(r[0].length(), r.size(), false, Image.FORMAT_RGBA8)
	var palette := COLORS.duplicate()
	palette["r"] = color
	palette["R"] = color.darkened(0.3)
	palette["h"] = color.lightened(0.2)
	for y in r.size():
		for x in r[y].length():
			var ch := r[y][x]
			img.set_pixel(x, y, palette[ch] if palette.has(ch) else Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Template rows for `kind` (empty for unsupported kinds); each row has the same length.
static func rows(kind: String, horizontal: bool = true) -> Array[String]:
	var c: Array
	match kind:
		"merchant":
			c = _merchant()
		"workshop":
			c = _workshop()
		"sect_hall":
			c = _sect_hall()
		"clinic":
			c = _clinic()
		"orphanage":
			c = _orphanage()
		"family_home":
			c = _family_home()
		"bounty_board":
			c = _bounty_board()
		"auction":
			c = _auction()
		"travel":
			c = _gate_h() if horizontal else _gate_v()
		_:
			return []
	_outline(c)
	var out: Array[String] = []
	for row: Array in c:
		out.append("".join(row))
	return out


static func _canvas(w: int, h: int) -> Array:
	var c: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(".")
		c.append(row)
	return c


static func _rect(c: Array, x: int, y: int, w: int, h: int, ch: String) -> void:
	for yy in range(maxi(y, 0), mini(y + h, c.size())):
		for xx in range(maxi(x, 0), mini(x + w, c[yy].size())):
			c[yy][xx] = ch


## A filled box with the bottom row and right column in the shade char (light from the top-left).
static func _box(c: Array, x: int, y: int, w: int, h: int, main: String, shade: String) -> void:
	_rect(c, x, y, w, h, main)
	_rect(c, x, y + h - 1, w, 1, shade)
	_rect(c, x + w - 1, y, 1, h, shade)


## A hip roof: row i is inset (h-1-i) pixels, highlight on top/left, shade at the bottom/right, a tile line every 3rd row.
static func _roof(c: Array, x: int, y: int, w: int, h: int) -> void:
	for i in h:
		var inset := h - 1 - i
		var rw := w - 2 * inset
		var rx := x + inset
		_rect(c, rx, y + i, rw, 1, "h" if i == 0 else ("R" if i % 3 == 2 else "r"))
		if i > 0:
			_rect(c, rx, y + i, 1, 1, "h")
			_rect(c, rx + rw - 1, y + i, 1, 1, "R")
	_rect(c, x, y + h - 1, w, 1, "R")


static func _outline(c: Array) -> void:
	var edge: Array[Vector2i] = []
	var h := c.size()
	var w: int = c[0].size()
	for y in h:
		for x in w:
			if c[y][x] == ".":
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or c[ny][nx] == ".":
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		c[p.y][p.x] = "o"


static func _merchant() -> Array:
	var c := _canvas(30, 28)
	_rect(c, 2, 8, 2, 20, "t")
	_rect(c, 26, 8, 2, 20, "t")
	_rect(c, 4, 10, 22, 9, "d")
	_rect(c, 6, 15, 3, 3, "h")
	_rect(c, 12, 14, 3, 4, "g")
	_rect(c, 18, 15, 3, 3, "h")
	_rect(c, 23, 16, 2, 2, "p")
	_box(c, 3, 19, 24, 9, "t", "T")
	for x in 30:
		var red := (x / 3) % 2 == 0
		_rect(c, x, 1, 1, 8, "r" if red else "p")
		if red:
			_rect(c, x, 1, 1, 1, "h")
			_rect(c, x, 8, 1, 1, "R")
	return c


static func _workshop() -> Array:
	var c := _canvas(64, 44)
	_box(c, 6, 20, 52, 24, "w", "W")
	_rect(c, 6, 20, 2, 24, "t")
	_rect(c, 56, 20, 2, 24, "T")
	_rect(c, 10, 27, 8, 6, "p")
	_rect(c, 46, 27, 8, 6, "p")
	_rect(c, 26, 29, 12, 15, "d")
	_rect(c, 28, 35, 8, 9, "g")
	_rect(c, 30, 38, 4, 6, "p")
	_roof(c, 2, 8, 60, 14)
	_box(c, 46, 0, 6, 12, "s", "S")
	return c


static func _sect_hall() -> Array:
	var c := _canvas(78, 54)
	_box(c, 10, 49, 58, 5, "s", "S")
	_box(c, 12, 30, 54, 19, "w", "W")
	for px in [14, 28, 48, 62]:
		_rect(c, px, 30, 3, 19, "r")
	_rect(c, 34, 36, 10, 13, "d")
	_roof(c, 2, 22, 74, 10)
	_box(c, 22, 13, 34, 10, "w", "W")
	_rect(c, 36, 16, 6, 5, "p")
	_roof(c, 12, 3, 54, 10)
	_rect(c, 26, 3, 26, 1, "g")
	_rect(c, 38, 0, 2, 4, "g")
	return c


static func _clinic() -> Array:
	var c := _canvas(50, 36)
	_box(c, 4, 14, 42, 22, "w", "W")
	_rect(c, 8, 21, 7, 7, "p")
	_rect(c, 35, 21, 7, 7, "p")
	_rect(c, 21, 22, 8, 14, "d")
	_rect(c, 17, 20, 1, 3, "t")
	_rect(c, 16, 23, 3, 3, "g")
	_rect(c, 15, 26, 5, 4, "g")
	_roof(c, 1, 4, 48, 11)
	return c


static func _orphanage() -> Array:
	var c := _canvas(54, 38)
	_box(c, 6, 34, 42, 4, "s", "S")
	_box(c, 8, 18, 38, 17, "w", "W")
	_rect(c, 23, 23, 8, 12, "R")
	_rect(c, 29, 29, 1, 1, "g")
	_rect(c, 11, 24, 3, 5, "g")
	_rect(c, 40, 24, 3, 5, "g")
	_roof(c, 1, 4, 52, 15)
	_rect(c, 20, 3, 14, 2, "g")
	return c


static func _family_home() -> Array:
	var c := _canvas(40, 30)
	_box(c, 4, 13, 32, 17, "w", "W")
	_rect(c, 7, 18, 6, 5, "g")
	_rect(c, 27, 18, 6, 5, "g")
	_rect(c, 17, 19, 7, 11, "d")
	_roof(c, 1, 3, 38, 11)
	_box(c, 28, 0, 4, 7, "s", "S")
	return c


static func _bounty_board() -> Array:
	var c := _canvas(34, 28)
	_rect(c, 3, 6, 3, 22, "t")
	_rect(c, 28, 6, 3, 22, "T")
	_box(c, 1, 3, 32, 17, "t", "T")
	_rect(c, 3, 5, 28, 13, "w")
	for n: Array in [[5, 7, 6, 7], [14, 6, 6, 8], [23, 8, 6, 6]]:
		_rect(c, n[0], n[1], n[2], n[3], "p")
		_rect(c, n[0] + 1, n[1] + 2, n[2] - 2, 1, "d")
	return c


static func _auction() -> Array:
	var c := _canvas(68, 48)
	_box(c, 6, 44, 56, 4, "s", "S")
	_box(c, 8, 22, 52, 23, "w", "W")
	_rect(c, 8, 22, 2, 23, "t")
	_rect(c, 58, 22, 2, 23, "T")
	_rect(c, 12, 28, 7, 7, "p")
	_rect(c, 49, 28, 7, 7, "p")
	_rect(c, 27, 34, 14, 11, "d")
	_roof(c, 1, 8, 66, 15)
	_rect(c, 20, 8, 28, 1, "g")
	_rect(c, 30, 20, 8, 13, "R")
	_rect(c, 30, 20, 8, 2, "g")
	_rect(c, 33, 26, 2, 4, "g")
	_rect(c, 33, 0, 1, 8, "t")
	_rect(c, 34, 0, 5, 3, "R")
	return c


static func _gate_h() -> Array:
	var c := _canvas(58, 18)
	_box(c, 2, 4, 5, 14, "t", "T")
	_box(c, 51, 4, 5, 14, "t", "T")
	_rect(c, 1, 16, 7, 2, "s")
	_rect(c, 50, 16, 7, 2, "s")
	_box(c, 7, 5, 44, 3, "t", "T")
	_rect(c, 0, 0, 58, 4, "r")
	_rect(c, 0, 0, 58, 1, "h")
	_rect(c, 0, 3, 58, 1, "R")
	_rect(c, 24, 8, 10, 5, "g")
	_rect(c, 27, 10, 4, 1, "d")
	return c


## The same gate seen side-on: end posts at the top and bottom, the roof beam running between them.
static func _gate_v() -> Array:
	var c := _canvas(18, 58)
	_box(c, 3, 0, 12, 7, "t", "T")
	_box(c, 3, 51, 12, 7, "t", "T")
	_rect(c, 2, 7, 14, 1, "S")
	_rect(c, 4, 7, 10, 44, "r")
	_rect(c, 4, 7, 1, 44, "h")
	_rect(c, 13, 7, 1, 44, "R")
	_rect(c, 6, 25, 6, 10, "g")
	_rect(c, 8, 28, 2, 4, "d")
	return c
