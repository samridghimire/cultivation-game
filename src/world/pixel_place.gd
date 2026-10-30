class_name PixelPlace
extends RefCounted
## Generated pixel-art buildings and stalls (GFX-021): village places use these until a sprite pack is mapped
## in data/sprites.json (GFX-002/003). Each kind is a small canvas of text rows (one char per pixel, drawn at
## Sprites.scale()), assembled from rectangles and hip roofs, then outlined on its silhouette edge.
## . transparent, o outline, w wall, W wall shade, r roof (the place colour), R roof shade, h roof highlight,
## d door / dark opening, t timber, T timber shade, p paper / window, g gold trim, s stone, S stone shade,
## e earth, v foliage (GFX-022 nature places: meditation, gather, explore, inheritance, abode, secret_realm, camp).
## Rendering only: pure and deterministic, no node access.

const KINDS := ["merchant", "workshop", "sect_hall", "clinic", "orphanage", "family_home", "bounty_board", "travel", "auction"]
const NATURE_KINDS := ["meditation", "gather", "explore", "inheritance", "abode", "secret_realm", "camp"]
const PALETTE := ".owWrRhdtTpgsSev"
const OUTLINE := Color("2b2118")
const DOOR := Color("3a2f26")
const COLORS := {
	"o": OUTLINE, "w": Color("d9cdb4"), "W": Color("b3a68c"), "d": DOOR, "t": Color("6e5636"), "T": Color("4f3d26"),
	"p": Color("e8dcc0"), "g": Color("c9a24a"), "s": Color("8a8478"), "S": Color("6a6559"), "e": Color("6e5a3c"), "v": Color("4f7a3a"),
}

static var _cache: Dictionary = {}


static func supports(kind: String) -> bool:
	return KINDS.has(kind) or NATURE_KINDS.has(kind)


## Pixel size of the template for `kind` (travel flips with the gate's orientation).
static func template_size(kind: String, horizontal: bool = true) -> Vector2i:
	var r := rows(kind, horizontal)
	return Vector2i(r[0].length(), r.size()) if not r.is_empty() else Vector2i.ZERO


static func texture(kind: String, size: Vector2, color: Color, active: bool = false) -> ImageTexture:
	var horizontal := size.x >= size.y
	var key := "%s|%s|%s|%s" % [kind, color.to_html(), horizontal if kind == "travel" else true, active]
	if not _cache.has(key):
		_cache[key] = from_rows(rows(kind, horizontal, active), color, active)
	return _cache[key]


## Builds a texture from template rows; `r` takes `color` (brighter when `active`), R / h are its shade / highlight.
static func from_rows(r: Array[String], color: Color, active: bool = false) -> ImageTexture:
	var img := Image.create(r[0].length(), r.size(), false, Image.FORMAT_RGBA8)
	var palette := COLORS.duplicate()
	var base := color.lightened(0.25) if active else color
	palette["r"] = base
	palette["R"] = base.darkened(0.3)
	palette["h"] = base.lightened(0.2)
	for y in r.size():
		for x in r[y].length():
			var ch := r[y][x]
			img.set_pixel(x, y, palette[ch] if palette.has(ch) else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## Template rows for `kind` (empty for unsupported kinds); each row has the same length.
static func rows(kind: String, horizontal: bool = true, active: bool = false) -> Array[String]:
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
		"meditation":
			c = _meditation()
		"gather":
			c = _gather()
		"explore":
			c = _cave()
		"inheritance":
			c = _stele()
		"abode":
			c = _dwelling()
		"secret_realm":
			c = _rift(active)
		"camp":
			c = _camp()
		_:
			return []
	outline(c)
	var out: Array[String] = []
	for row: Array in c:
		out.append("".join(row))
	return out


static func canvas(w: int, h: int) -> Array:
	var c: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(".")
		c.append(row)
	return c


static func rect(c: Array, x: int, y: int, w: int, h: int, ch: String) -> void:
	for yy in range(maxi(y, 0), mini(y + h, c.size())):
		for xx in range(maxi(x, 0), mini(x + w, c[yy].size())):
			c[yy][xx] = ch


## A filled box with the bottom row and right column in the shade char (light from the top-left).
static func box(c: Array, x: int, y: int, w: int, h: int, main: String, shade: String) -> void:
	rect(c, x, y, w, h, main)
	rect(c, x, y + h - 1, w, 1, shade)
	rect(c, x + w - 1, y, 1, h, shade)


## A hip roof: row i is inset (h-1-i) pixels, highlight on top/left, shade at the bottom/right, a tile line every 3rd row.
static func roof(c: Array, x: int, y: int, w: int, h: int) -> void:
	for i in h:
		var inset := h - 1 - i
		var rw := w - 2 * inset
		var rx := x + inset
		rect(c, rx, y + i, rw, 1, "h" if i == 0 else ("R" if i % 3 == 2 else "r"))
		if i > 0:
			rect(c, rx, y + i, 1, 1, "h")
			rect(c, rx + rw - 1, y + i, 1, 1, "R")
	rect(c, x, y + h - 1, w, 1, "R")


## A filled ellipse centred on (cx, cy) with radii rx, ry.
static func ell(c: Array, cx: float, cy: float, rx: float, ry: float, ch: String) -> void:
	for y in c.size():
		for x in c[y].size():
			var dx: float = (x + 0.5 - cx) / rx
			var dy: float = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				c[y][x] = ch


static func outline(c: Array) -> void:
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
	var c := canvas(30, 28)
	rect(c, 2, 8, 2, 20, "t")
	rect(c, 26, 8, 2, 20, "t")
	rect(c, 4, 10, 22, 9, "d")
	rect(c, 6, 15, 3, 3, "h")
	rect(c, 12, 14, 3, 4, "g")
	rect(c, 18, 15, 3, 3, "h")
	rect(c, 23, 16, 2, 2, "p")
	box(c, 3, 19, 24, 9, "t", "T")
	for x in 30:
		var red := (x / 3) % 2 == 0
		rect(c, x, 1, 1, 8, "r" if red else "p")
		if red:
			rect(c, x, 1, 1, 1, "h")
			rect(c, x, 8, 1, 1, "R")
	return c


static func _workshop() -> Array:
	var c := canvas(64, 44)
	box(c, 6, 20, 52, 24, "w", "W")
	rect(c, 6, 20, 2, 24, "t")
	rect(c, 56, 20, 2, 24, "T")
	rect(c, 10, 27, 8, 6, "p")
	rect(c, 46, 27, 8, 6, "p")
	rect(c, 26, 29, 12, 15, "d")
	rect(c, 28, 35, 8, 9, "g")
	rect(c, 30, 38, 4, 6, "p")
	roof(c, 2, 8, 60, 14)
	box(c, 46, 0, 6, 12, "s", "S")
	return c


static func _sect_hall() -> Array:
	var c := canvas(78, 54)
	box(c, 10, 49, 58, 5, "s", "S")
	box(c, 12, 30, 54, 19, "w", "W")
	for px in [14, 28, 48, 62]:
		rect(c, px, 30, 3, 19, "r")
	rect(c, 34, 36, 10, 13, "d")
	roof(c, 2, 22, 74, 10)
	box(c, 22, 13, 34, 10, "w", "W")
	rect(c, 36, 16, 6, 5, "p")
	roof(c, 12, 3, 54, 10)
	rect(c, 26, 3, 26, 1, "g")
	rect(c, 38, 0, 2, 4, "g")
	return c


static func _clinic() -> Array:
	var c := canvas(50, 36)
	box(c, 4, 14, 42, 22, "w", "W")
	rect(c, 8, 21, 7, 7, "p")
	rect(c, 35, 21, 7, 7, "p")
	rect(c, 21, 22, 8, 14, "d")
	rect(c, 17, 20, 1, 3, "t")
	rect(c, 16, 23, 3, 3, "g")
	rect(c, 15, 26, 5, 4, "g")
	roof(c, 1, 4, 48, 11)
	return c


static func _orphanage() -> Array:
	var c := canvas(54, 38)
	box(c, 6, 34, 42, 4, "s", "S")
	box(c, 8, 18, 38, 17, "w", "W")
	rect(c, 23, 23, 8, 12, "R")
	rect(c, 29, 29, 1, 1, "g")
	rect(c, 11, 24, 3, 5, "g")
	rect(c, 40, 24, 3, 5, "g")
	roof(c, 1, 4, 52, 15)
	rect(c, 20, 3, 14, 2, "g")
	return c


static func _family_home() -> Array:
	var c := canvas(40, 30)
	box(c, 4, 13, 32, 17, "w", "W")
	rect(c, 7, 18, 6, 5, "g")
	rect(c, 27, 18, 6, 5, "g")
	rect(c, 17, 19, 7, 11, "d")
	roof(c, 1, 3, 38, 11)
	box(c, 28, 0, 4, 7, "s", "S")
	return c


static func _bounty_board() -> Array:
	var c := canvas(34, 28)
	rect(c, 3, 6, 3, 22, "t")
	rect(c, 28, 6, 3, 22, "T")
	box(c, 1, 3, 32, 17, "t", "T")
	rect(c, 3, 5, 28, 13, "w")
	for n: Array in [[5, 7, 6, 7], [14, 6, 6, 8], [23, 8, 6, 6]]:
		rect(c, n[0], n[1], n[2], n[3], "p")
		rect(c, n[0] + 1, n[1] + 2, n[2] - 2, 1, "d")
	return c


static func _auction() -> Array:
	var c := canvas(68, 48)
	box(c, 6, 44, 56, 4, "s", "S")
	box(c, 8, 22, 52, 23, "w", "W")
	rect(c, 8, 22, 2, 23, "t")
	rect(c, 58, 22, 2, 23, "T")
	rect(c, 12, 28, 7, 7, "p")
	rect(c, 49, 28, 7, 7, "p")
	rect(c, 27, 34, 14, 11, "d")
	roof(c, 1, 8, 66, 15)
	rect(c, 20, 8, 28, 1, "g")
	rect(c, 30, 20, 8, 13, "R")
	rect(c, 30, 20, 8, 2, "g")
	rect(c, 33, 26, 2, 4, "g")
	rect(c, 33, 0, 1, 8, "t")
	rect(c, 34, 0, 5, 3, "R")
	return c


static func _gate_h() -> Array:
	var c := canvas(58, 18)
	box(c, 2, 4, 5, 14, "t", "T")
	box(c, 51, 4, 5, 14, "t", "T")
	rect(c, 1, 16, 7, 2, "s")
	rect(c, 50, 16, 7, 2, "s")
	box(c, 7, 5, 44, 3, "t", "T")
	rect(c, 0, 0, 58, 4, "r")
	rect(c, 0, 0, 58, 1, "h")
	rect(c, 0, 3, 58, 1, "R")
	rect(c, 24, 8, 10, 5, "g")
	rect(c, 27, 10, 4, 1, "d")
	return c


## The same gate seen side-on: end posts at the top and bottom, the roof beam running between them.
static func _gate_v() -> Array:
	var c := canvas(18, 58)
	box(c, 3, 0, 12, 7, "t", "T")
	box(c, 3, 51, 12, 7, "t", "T")
	rect(c, 2, 7, 14, 1, "S")
	rect(c, 4, 7, 10, 44, "r")
	rect(c, 4, 7, 1, 44, "h")
	rect(c, 13, 7, 1, 44, "R")
	rect(c, 6, 25, 6, 10, "g")
	rect(c, 8, 28, 2, 4, "d")
	return c


## A flat stone dais ringed with boulders and a cushion in the middle.
static func _meditation() -> Array:
	var c := canvas(44, 30)
	ell(c, 22, 17, 21, 12, "S")
	ell(c, 22, 15, 20, 11, "s")
	ell(c, 22, 15, 14, 7, "S")
	ell(c, 22, 14, 13, 6, "W")
	ell(c, 22, 13, 5, 3, "r")
	rect(c, 17, 12, 10, 1, "h")
	for p: Array in [[2, 8], [10, 2], [32, 2], [40, 8], [3, 20], [38, 21]]:
		rect(c, p[0], p[1], 4, 3, "s")
		rect(c, p[0], p[1] + 2, 4, 1, "S")
	return c


## A mound of turned earth with sprouting herbs (tinted by the place colour).
static func _gather() -> Array:
	var c := canvas(50, 34)
	ell(c, 25, 21, 24, 12, "e")
	ell(c, 25, 19, 22, 10, "e")
	for p: Array in [[8, 14], [18, 9], [30, 11], [40, 16], [13, 22], [25, 19], [35, 24]]:
		rect(c, p[0], p[1] + 2, 1, 5, "v")
		rect(c, p[0] - 2, p[1] + 1, 5, 2, "r")
		rect(c, p[0] - 1, p[1], 3, 1, "h")
		rect(c, p[0], p[1] - 2, 1, 2, "h")
	return c


## A cave mouth in a rock face.
static func _cave() -> Array:
	var c := canvas(54, 38)
	ell(c, 27, 24, 26, 12, "s")
	ell(c, 27, 17, 23, 16, "s")
	ell(c, 30, 19, 17, 12, "S")
	ell(c, 27, 16, 23, 15, "s")
	rect(c, 0, 28, 54, 10, ".")
	rect(c, 3, 28, 48, 7, "s")
	rect(c, 3, 34, 48, 3, "S")
	ell(c, 27, 28, 10, 13, "d")
	rect(c, 17, 28, 20, 8, "d")
	rect(c, 23, 34, 8, 3, "S")
	for p: Array in [[10, 10], [38, 8], [15, 5], [42, 15]]:
		rect(c, p[0], p[1], 5, 2, "v")
	return c


## A tall carved stone stele on a stepped base, glowing gold characters.
static func _stele() -> Array:
	var c := canvas(44, 32)
	box(c, 6, 26, 32, 6, "s", "S")
	box(c, 11, 22, 22, 5, "s", "S")
	box(c, 15, 2, 14, 21, "s", "S")
	rect(c, 17, 0, 10, 3, "s")
	rect(c, 15, 2, 14, 1, "W")
	for y in [7, 12, 17]:
		rect(c, 18, y, 8, 1, "g")
		rect(c, 20, y + 2, 4, 1, "g")
	return c


## A hermit's cave dwelling: a rock mound with a plank door and a paper window.
static func _dwelling() -> Array:
	var c := canvas(48, 36)
	ell(c, 24, 24, 23, 13, "s")
	ell(c, 24, 18, 20, 16, "s")
	ell(c, 28, 20, 15, 12, "S")
	ell(c, 24, 17, 19, 15, "s")
	rect(c, 0, 30, 48, 6, ".")
	rect(c, 3, 30, 42, 5, "s")
	rect(c, 3, 34, 42, 2, "S")
	box(c, 19, 20, 10, 15, "t", "T")
	rect(c, 23, 24, 2, 10, "T")
	rect(c, 9, 22, 6, 5, "p")
	rect(c, 9, 24, 6, 1, "d")
	rect(c, 34, 20, 4, 2, "v")
	rect(c, 8, 8, 4, 2, "v")
	return c


## A swirling ring of light; `active` (a realm is open) fills the middle with bright qi.
static func _rift(active: bool) -> Array:
	var c := canvas(48, 38)
	ell(c, 24, 19, 23, 18, "R")
	ell(c, 24, 19, 21, 16, "r")
	ell(c, 24, 19, 16, 12, "R")
	ell(c, 24, 19, 12, 9, "d")
	for p: Array in [[4, 14], [8, 6], [16, 1], [30, 1], [40, 8], [42, 20], [36, 31], [20, 35], [8, 29]]:
		rect(c, p[0], p[1], 3, 2, "h")
	if active:
		ell(c, 24, 19, 8, 6, "h")
		ell(c, 24, 19, 4, 3, "p")
	else:
		ell(c, 24, 19, 3, 2, "S")
	return c


## A small tent, a ring of stones and a campfire.
static func _camp() -> Array:
	var c := canvas(30, 19)
	_roof_tent(c)
	rect(c, 20, 15, 8, 3, "s")
	rect(c, 21, 17, 6, 1, "S")
	rect(c, 22, 12, 4, 4, "g")
	rect(c, 23, 10, 2, 3, "h")
	rect(c, 21, 17, 6, 1, "t")
	return c


static func _roof_tent(c: Array) -> void:
	for i in 14:
		var half := i / 2 + 1
		rect(c, 9 - half, 2 + i, half * 2, 1, "r")
		rect(c, 9 - half, 2 + i, 1, 1, "h")
		rect(c, 9 + half - 1, 2 + i, 1, 1, "R")
	rect(c, 7, 12, 4, 4, "d")
	rect(c, 9, 0, 1, 3, "t")
