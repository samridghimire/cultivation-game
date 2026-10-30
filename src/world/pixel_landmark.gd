class_name PixelLandmark
extends RefCounted
## Generated pixel-art map landmarks (GFX-022): house, well, stall, pine and lantern are fixed templates (half the
## on-screen size, drawn at Sprites.scale()); pond, field and fence are built to fill their rect at that scale,
## so they never stretch. Shares PixelPlace's palette and helpers. Rendering only: pure, deterministic, cached.

const KINDS := ["house", "well", "stall", "pine", "lantern", "pond", "field", "fence", "wall", "cliff", "stream"]
const FIXED := ["house", "well", "stall", "pine", "lantern"]

static var _cache: Dictionary = {}


static func supports(kind: String) -> bool:
	return KINDS.has(kind)


## Pixel size of the texture for a landmark rect of `size` on-screen pixels.
static func pixel_size(kind: String, size: Vector2) -> Vector2i:
	if FIXED.has(kind):
		var r := rows(kind, size)
		return Vector2i(r[0].length(), r.size())
	var s := float(Sprites.scale())
	return Vector2i(maxi(3, roundi(size.x / s)), maxi(3, roundi(size.y / s)))


## `tint` is the pond's water colour; other kinds ignore it.
static func texture(kind: String, size: Vector2, tint: Color = Color("3f7fa8")) -> ImageTexture:
	var px := pixel_size(kind, size)
	var key := "%s|%s|%s" % [kind, px, tint.to_html()]
	if not _cache.has(key):
		_cache[key] = PixelPlace.from_rows(rows(kind, size), tint)
	return _cache[key]


## Template rows (all of one length) for `kind` in a rect of `size`.
static func rows(kind: String, size: Vector2) -> Array[String]:
	var c: Array
	var n := pixel_size(kind, size) if not FIXED.has(kind) else Vector2i.ZERO
	match kind:
		"house":
			c = _house()
		"well":
			c = _well()
		"stall":
			c = _stall()
		"pine":
			c = _pine()
		"lantern":
			c = _lantern()
		"pond":
			c = _pond(n.x, n.y)
		"field":
			c = _field(n.x, n.y)
		"fence":
			c = _fence(n.x, n.y)
		"wall":
			c = _wall(n.x, n.y)
		"cliff":
			c = _cliff(n.x, n.y)
		"stream":
			c = _stream(n.x, n.y)
		_:
			return []
	if kind != "pond" and kind != "stream":
		PixelPlace.outline(c)
	var out: Array[String] = []
	for row: Array in c:
		out.append("".join(row))
	return out


static func _house() -> Array:
	var c := PixelPlace.canvas(50, 36)
	PixelPlace.box(c, 5, 16, 40, 20, "w", "W")
	PixelPlace.rect(c, 10, 22, 7, 6, "d")
	PixelPlace.rect(c, 11, 23, 5, 4, "g")
	PixelPlace.box(c, 22, 24, 8, 12, "t", "T")
	PixelPlace.roof(c, 1, 3, 48, 14)
	PixelPlace.box(c, 36, 0, 5, 7, "s", "S")
	return c


static func _well() -> Array:
	var c := PixelPlace.canvas(20, 20)
	PixelPlace.ell(c, 10, 12, 9, 7, "S")
	PixelPlace.ell(c, 10, 11, 9, 6, "s")
	PixelPlace.ell(c, 10, 11, 6, 4, "d")
	PixelPlace.rect(c, 8, 10, 4, 1, "p")
	PixelPlace.rect(c, 2, 2, 1, 9, "t")
	PixelPlace.rect(c, 17, 2, 1, 9, "T")
	PixelPlace.rect(c, 1, 1, 18, 2, "r")
	return c


static func _stall() -> Array:
	var c := PixelPlace.canvas(40, 25)
	PixelPlace.rect(c, 2, 8, 2, 17, "t")
	PixelPlace.rect(c, 36, 8, 2, 17, "T")
	PixelPlace.box(c, 3, 15, 34, 10, "t", "T")
	for x in 40:
		var red := (x / 4) % 2 == 0
		PixelPlace.rect(c, x, 1, 1, 8, "r" if red else "p")
	for x in [8, 17, 26]:
		PixelPlace.rect(c, x, 12, 4, 3, "h")
	PixelPlace.rect(c, 0, 9, 40, 1, "R")
	return c


static func _pine() -> Array:
	var c := PixelPlace.canvas(20, 28)
	PixelPlace.rect(c, 9, 22, 3, 6, "t")
	for i in 3:
		var top := i * 6
		for j in 10:
			var half := (j + 2 + i) / 2 + 1
			var row := top + j
			if row > 24:
				break
			PixelPlace.rect(c, 10 - half, row, half * 2, 1, "R" if j > 6 else "v")
			PixelPlace.rect(c, 10 - half, row, 1, 1, "h")
	return c


static func _lantern() -> Array:
	var c := PixelPlace.canvas(8, 12)
	PixelPlace.rect(c, 3, 6, 2, 6, "t")
	PixelPlace.rect(c, 1, 0, 6, 6, "r")
	PixelPlace.rect(c, 2, 1, 4, 4, "g")
	PixelPlace.rect(c, 1, 0, 6, 1, "R")
	return c


## A pond with a 1-px sandy shore and a lighter patch of water.
static func _pond(w: int, h: int) -> Array:
	var c := PixelPlace.canvas(w, h)
	PixelPlace.ell(c, w / 2.0, h / 2.0, w / 2.0, h / 2.0, "e")
	PixelPlace.ell(c, w / 2.0, h / 2.0, w / 2.0 - 1.0, h / 2.0 - 1.0, "r")
	PixelPlace.ell(c, w * 0.4, h * 0.38, w * 0.18, h * 0.14, "h")
	PixelPlace.ell(c, w * 0.62, h * 0.72, w * 0.12, h * 0.07, "R")
	return c


## Ploughed earth in 4-px furrows with green sprouts, in a timber border; built from 16-px rows so it tiles.
static func _field(w: int, h: int) -> Array:
	var c := PixelPlace.canvas(w, h)
	PixelPlace.rect(c, 0, 0, w, h, "e")
	var y := 2
	while y < h - 2:
		PixelPlace.rect(c, 2, y, w - 4, 1, "T")
		var x := 3 + (y / 4 % 2) * 2
		while x < w - 3:
			PixelPlace.rect(c, x, y + 1, 1, 2, "v")
			x += 4
		y += 4
	return c


## Two rails and posts every 10 px.
static func _fence(w: int, h: int) -> Array:
	var c := PixelPlace.canvas(w, h)
	var top := maxi(1, h / 4)
	PixelPlace.rect(c, 0, top, w, 1, "t")
	PixelPlace.rect(c, 0, h - top - 2, w, 1, "t")
	var x := 1
	while x < w:
		PixelPlace.rect(c, x, 0, 2, h, "t")
		PixelPlace.rect(c, x + 1, 0, 1, h, "T")
		x += 10
	return c


## Grey stone blocks in 4-px courses (staggered joints) under a darker top course.
static func _wall(w: int, h: int) -> Array:
	var c := PixelPlace.canvas(w, h)
	PixelPlace.rect(c, 0, 0, w, h, "s")
	PixelPlace.rect(c, 0, 0, w, mini(3, h), "S")
	var y := 3
	var row := 0
	while y < h:
		PixelPlace.rect(c, 0, y, w, 1, "S")
		var x := 4 if row % 2 == 0 else 0
		while x < w:
			PixelPlace.rect(c, x, y + 1, 1, 3, "S")
			x += 8
		y += 4
		row += 1
	return c


## A brown rock face: a lit top edge, vertical cracks and darker earth patches, a shaded foot.
static func _cliff(w: int, h: int) -> Array:
	var c := PixelPlace.canvas(w, h)
	PixelPlace.rect(c, 0, 0, w, h, "t")
	PixelPlace.rect(c, 0, 0, w, mini(2, h), "W")
	PixelPlace.rect(c, 0, h - 2, w, 2, "T")
	var x := 3
	while x < w - 2:
		var len := 4 + (x * 7) % 9
		PixelPlace.rect(c, x, 2 + (x * 5) % 6, 1, mini(len, h - 4), "T")
		PixelPlace.rect(c, x + 5, 4 + (x * 3) % 7, 3, 2, "e")
		x += 11
	return c


## Two-tone water with a light ripple row, a darker bank on the long edges.
static func _stream(w: int, h: int) -> Array:
	var c := PixelPlace.canvas(w, h)
	PixelPlace.rect(c, 0, 0, w, h, "r")
	if w >= h:
		PixelPlace.rect(c, 0, 0, w, 1, "R")
		PixelPlace.rect(c, 0, h - 1, w, 1, "R")
		var y := 3
		while y < h - 2:
			var x := (y * 5) % 9
			while x < w:
				PixelPlace.rect(c, x, y, 4, 1, "h")
				x += 11
			y += 5
	else:
		PixelPlace.rect(c, 0, 0, 1, h, "R")
		PixelPlace.rect(c, w - 1, 0, 1, h, "R")
		var x := 3
		while x < w - 2:
			var y := (x * 5) % 9
			while y < h:
				PixelPlace.rect(c, x, y, 1, 4, "h")
				y += 11
			x += 5
	return c
