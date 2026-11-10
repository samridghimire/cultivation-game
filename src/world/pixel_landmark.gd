class_name PixelLandmark
extends RefCounted
## Generated pixel-art map landmarks (GFX-022): house, well, stall, pine and lantern are fixed templates (half the
## on-screen size, drawn at Sprites.scale()); pond, field and fence are built to fill their rect at that scale,
## so they never stretch. Shares PixelPlace's palette and helpers. Rendering only: pure, deterministic, cached.

const KINDS := ["house", "well", "stall", "pine", "lantern", "pond", "field", "fence", "wall", "cliff", "stream", "jetty"]
const FIXED := ["house", "well", "stall", "pine", "lantern", "jetty"]

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
## `dashes` false leaves streams without baked ripple dashes (GFX-051: WaterLife scrolls its own).
static func texture(kind: String, size: Vector2, tint: Color = Color("3f7fa8"), frozen: bool = false, dashes: bool = true, style: String = "thatch", water: String = "clear") -> ImageTexture:
	style = PixelPlace.effective_style("family_home" if kind == "house" else kind, style)
	var px := pixel_size(kind, size)
	if frozen and kind == "pond":
		return frozen_pond(px, tint)
	if kind != "pond" or not PlaceLooks.WATER_KINDS.has(water):
		water = "clear"
	var key := "%s|%s|%s|%s|%s|%s" % [kind, px, tint.to_html(), dashes, style, water]
	if not _cache.has(key):
		var r: Array[String] = rows(kind, size, dashes, style) if water == "clear" else _rows_of(_pond(px.x, px.y, true, water))
		_cache[key] = PixelPlace.from_rows(r, tint, false, style)
	return _cache[key]


## GFX-043: a pond frozen over: pale blue-white ice with 2-3 crack lines; the outer 2 px keep the (icy) rim.
static func frozen_pond(px: Vector2i, water: Color) -> ImageTexture:
	var key := "frozen|%s|%s" % [px, water.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := PixelPlace.from_rows(_rows_of(_pond(px.x, px.y, false)), water).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var ice := Color("e3f0fa")
	var crack := Color("a9c6dc")
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var edge := x < 2 or y < 2 or x >= w - 2 or y >= h - 2 or src.get_pixel(maxi(x - 2, 0), y).a <= 0.0 or src.get_pixel(mini(x + 2, w - 1), y).a <= 0.0 or src.get_pixel(x, maxi(y - 2, 0)).a <= 0.0 or src.get_pixel(x, mini(y + 2, h - 1)).a <= 0.0
			img.set_pixel(x, y, Color(c.lerp(Color("f2f8ff"), 0.6), c.a) if edge else Color(ice, c.a))
	# Cracks: three short zig-zag lines from fixed fractions of the pond.
	for k in 3:
		var x := int(w * (0.25 + 0.25 * k))
		var y := int(h * (0.3 + 0.1 * k))
		for i in maxi(3, h / 3):
			var cx := x + (i * (k + 1)) % 3 - 1 + i / 2 * (1 if k != 1 else -1)
			var cy := y + i
			if cx >= 2 and cy >= 2 and cx < w - 2 and cy < h - 2 and img.get_pixel(cx, cy).a > 0.0:
				img.set_pixel(cx, cy, crack)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Template rows (all of one length) for `kind` in a rect of `size`.
static func rows(kind: String, size: Vector2, dashes: bool = true, style: String = "thatch") -> Array[String]:
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
			c = _stream(n.x, n.y, dashes)
		"jetty":
			c = _jetty()
		_:
			return []
	if kind != "pond" and kind != "stream":
		PixelPlace.apply_style_rows(c, style)
		PixelPlace.outline(c)
	return _rows_of(c)


static func _rows_of(c: Array) -> Array[String]:
	var out: Array[String] = []
	for row: Array in c:
		out.append("".join(row))
	return out


## GFX-045: planks on posts, the long side touching the water (south edge); snow caps come from world.gd.
static func _jetty() -> Array:
	var c := PixelPlace.canvas(44, 14)
	PixelPlace.rect(c, 0, 1, 44, 8, "t")
	PixelPlace.rect(c, 0, 1, 44, 1, "p")
	PixelPlace.rect(c, 0, 8, 44, 1, "T")
	for x in range(5, 44, 6):
		PixelPlace.rect(c, x, 2, 1, 6, "T")
	for x: int in [1, 14, 28, 41]:
		PixelPlace.rect(c, x, 9, 2, 5, "T")
	return c


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


## GFX-045: a pond with a 1-px mud ring, a 2-px darker shore rim, a highlight arc on the far (north) side and
## 3-5 reed clumps on the edge (none when `reeds` is false, i.e. frozen).
static func _pond(w: int, h: int, reeds: bool = true, water: String = "clear") -> Array:
	var c := PixelPlace.canvas(w, h)
	var cx := w / 2.0
	var cy := h / 2.0
	PixelPlace.ell(c, cx, cy, w / 2.0, h / 2.0, "e")
	PixelPlace.ell(c, cx, cy, w / 2.0 - 1.0, h / 2.0 - 1.0, "R")
	PixelPlace.ell(c, cx, cy, w / 2.0 - 3.0, h / 2.0 - 3.0, "r")
	PixelPlace.ell(c, w * 0.4, h * 0.38, w * 0.18, h * 0.14, "h")
	PixelPlace.ell(c, w * 0.62, h * 0.72, w * 0.12, h * 0.07, "R")
	# Highlight arc: the top of the inner water edge.
	for i in range(0, 15):
		var a := PI * (1.15 + 0.7 * float(i) / 14.0)
		var x := roundi(cx + cos(a) * (w / 2.0 - 4.0))
		var y := roundi(cy + sin(a) * (h / 2.0 - 4.0))
		if x >= 0 and y >= 0 and x < w and y < h and c[y][x] == "r":
			c[y][x] = "h"
	if water == "murky":
		PixelPlace.ell(c, cx, cy, w / 2.0, h / 2.0, "T")
		PixelPlace.ell(c, cx, cy, w / 2.0 - 2.0, h / 2.0 - 2.0, "R")
		PixelPlace.ell(c, cx, cy, w / 2.0 - 4.0, h / 2.0 - 4.0, "r")
		for k in 4:  # lily pads: 5x3 green ovals with a pale dot
			var lx := roundi(cx + cos(float(k) * 1.9 + 0.5) * w * 0.22)
			var ly := roundi(cy + sin(float(k) * 1.9 + 0.5) * h * 0.2)
			PixelPlace.ell(c, lx, ly, 3.0, 1.8, "v")
			PixelPlace.rect(c, lx, ly - 1, 1, 1, "n" if k % 2 == 0 else "v")
	elif water == "icy":
		PixelPlace.ell(c, cx, cy, w / 2.0, h / 2.0, "b")
		PixelPlace.ell(c, cx, cy, w / 2.0 - 1.0, h / 2.0 - 1.0, "n")
		PixelPlace.ell(c, cx, cy, w / 2.0 - 3.0, h / 2.0 - 3.0, "r")
		PixelPlace.ell(c, w * 0.4, h * 0.38, w * 0.18, h * 0.14, "h")
		reeds = false
	if reeds:
		var count := 3 + (w + h) % 3
		for k in count:
			var a := TAU * (float(k) + 0.37 * float((w * 3 + h) % 5)) / float(count)
			var x := roundi(cx + cos(a) * (w / 2.0 - 1.0))
			var y := roundi(cy + sin(a) * (h / 2.0 - 1.0))
			for dy in 4:
				for dx in 2:
					if x + dx >= 0 and x + dx < w and y - dy >= 0 and y - dy < h and (dx == 0 or dy < 3):
						c[y - dy][x + dx] = "v"
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


## Two-tone water with light ripple dashes, 2-px darker banks on the long edges and a stone every ~60 px.
static func _stream(w: int, h: int, dashes: bool = true) -> Array:
	var c := PixelPlace.canvas(w, h)
	PixelPlace.rect(c, 0, 0, w, h, "r")
	var step := maxi(8, 60 / maxi(1, Sprites.scale()))
	if w >= h:
		PixelPlace.rect(c, 0, 0, w, mini(2, h), "R")
		PixelPlace.rect(c, 0, maxi(0, h - 2), w, mini(2, h), "R")
		var y := 4
		while dashes and y < h - 3:
			var x := (y * 5) % 9
			while x < w:
				PixelPlace.rect(c, x, y, 4, 1, "h")
				x += 11
			y += 5
		var sx := step / 2
		while sx < w - 1:
			PixelPlace.rect(c, sx, 0, 2, 1, "s")
			PixelPlace.rect(c, sx + step / 3, maxi(0, h - 1), 2, 1, "s")
			sx += step
	else:
		PixelPlace.rect(c, 0, 0, mini(2, w), h, "R")
		PixelPlace.rect(c, maxi(0, w - 2), 0, mini(2, w), h, "R")
		var x := 4
		while dashes and x < w - 3:
			var y := (x * 5) % 9
			while y < h:
				PixelPlace.rect(c, x, y, 1, 4, "h")
				y += 11
			x += 5
		var sy := step / 2
		while sy < h - 1:
			PixelPlace.rect(c, 0, sy, 1, 2, "s")
			PixelPlace.rect(c, maxi(0, w - 1), sy + step / 3, 1, 2, "s")
			sy += step
	return c
