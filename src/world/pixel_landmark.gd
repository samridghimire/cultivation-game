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
static func texture(kind: String, size: Vector2, tint: Color = Color("3f7fa8"), frozen: bool = false, dashes: bool = true, style: String = "thatch", water: String = "clear", shape: Dictionary = {}) -> ImageTexture:
	style = PixelPlace.effective_style("family_home" if kind == "house" else kind, style)
	var px := pixel_size(kind, size)
	var shape_key := str(shape)
	if kind == "pond":  # GFX-135: ragged shoreline, bank, shallows, stones and reeds
		var pkey := "pond2|%s|%s|%s|%s|%s|%s" % [px, tint.to_html(), frozen, water, shape_key, Sprites.scale()]
		if not _cache.has(pkey):
			_cache[pkey] = ImageTexture.create_from_image(pond_image(px, tint, frozen, water, int(shape.get("seed", 0))))
		return _cache[pkey]
	if kind == "stream" and not shape.is_empty():
		var skey := "stream2|%s|%s|%s|%s" % [px, frozen, dashes, shape_key]
		if not _cache.has(skey):
			var base: Image = (frozen_stream(px) if frozen else _stream_texture(px, dashes)).get_image()
			_cache[skey] = ImageTexture.create_from_image(meander(base, shape))
		return _cache[skey]
	if frozen and kind == "stream":
		return frozen_stream(px)
	if kind != "pond" or not PlaceLooks.WATER_KINDS.has(water):
		water = "clear"
	var key := "%s|%s|%s|%s|%s|%s" % [kind, px, tint.to_html(), dashes, style, water]
	if not _cache.has(key):
		var r: Array[String] = rows(kind, size, dashes, style) if water == "clear" else _rows_of(_pond(px.x, px.y, true, water))
		_cache[key] = PixelPlace.from_rows(r, tint, false, style)
	return _cache[key]


static func _stream_texture(px: Vector2i, dashes: bool) -> ImageTexture:
	return PixelPlace.from_rows(_rows_of(_stream(px.x, px.y, dashes)), Color("3f7fa8"))


## GFX-135: a stream bent into a meander: the water is cropped to leave STREAM_AMP either side, then each column
## (row for a vertical stream) is shifted sideways by Scenery.stream_offset, 0 near path crossings so bridges still meet it.
## `shape` = {seed, spans, origin (world coordinate of the first pixel along the stream)}; the tint of unshifted
## stream rows is the caller's.
static func meander(src: Image, shape: Dictionary) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var horizontal := w >= h
	var thick := h if horizontal else w
	var length := w if horizontal else h
	var sc := float(Sprites.scale())
	var amp := ceili(Scenery.STREAM_AMP / sc)
	if thick < amp * 2 + 8:
		return src
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var spans: Array[Vector2] = []
	for sp in shape.get("spans", []):
		spans.append(sp)
	for a in length:
		var off := roundi(Scenery.stream_offset(float(shape.get("origin", 0.0)) + float(a) * sc, int(shape.get("seed", 0)), spans) / sc)
		for c in thick:
			var sc_i := c - off
			if sc_i < amp or sc_i >= thick - amp:
				continue
			var col := src.get_pixel(a, sc_i) if horizontal else src.get_pixel(sc_i, a)
			if horizontal:
				out.set_pixel(a, c, col)
			else:
				out.set_pixel(c, a, col)
	return out


## GFX-135: a pond as an image: ragged mask (Scenery.pond_edge), a muddy/sandy bank band with a darker wet edge, lighter shallows,
## deep water in the middle, a few stones and reed clumps on the bank. Frozen ponds are pale ice with seeded cracks and snow drifts
## on the bank. Seeded: same inputs, same pixels.
static func pond_image(px: Vector2i, water: Color, frozen: bool, kind: String, seed: int) -> Image:
	var w := px.x
	var h := px.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cx := w / 2.0
	var cy := h / 2.0
	var u := 1.0 / minf(cx, cy)  # one pixel in normalised units
	var marsh := kind == "murky"
	var bank := Color("3b3326") if marsh else (Color("9aa9b2") if kind == "icy" else Color("a08a62"))
	var wet := bank.darkened(0.3)
	var shallow := water.lightened(0.15)
	var ice := Color("d6e6f2")
	var snow := Color("f4f8fc")
	for y in h:
		for x in w:
			var nx := (x + 0.5 - cx) / cx
			var ny := (y + 0.5 - cy) / cy
			var d := Vector2(nx, ny).length()
			var edge := Scenery.pond_edge(atan2(ny, nx), seed)
			if d > edge:
				continue
			var depth := (edge - d) / u  # pixels in from the outer edge
			var jitter := float((x * 7 + y * 13) % 5) * 0.03
			var col: Color
			if depth < 2.0:
				col = bank.lightened(jitter) if not frozen else (snow if (x * 5 + y * 3) % 7 < 5 else bank)
			elif depth < 3.0:
				col = wet if not frozen else ice.darkened(0.12)
			elif depth < 5.0:
				col = shallow if not frozen else ice.lightened(0.04)
			else:
				col = water.lightened(jitter * 0.4) if not frozen else ice
				var hl := Vector2((x + 0.5 - w * 0.4) / (w * 0.18), (y + 0.5 - h * 0.38) / (h * 0.12)).length()
				if hl < 1.0 and not frozen:
					col = water.lightened(0.2)
			img.set_pixel(x, y, col)
	if frozen:  # 2-4 seeded crack lines
		var crack := Color("a9c6dc")
		for k in rng.randi_range(2, 4):
			var p := Vector2(rng.randf_range(0.3, 0.7) * w, rng.randf_range(0.3, 0.7) * h)
			var dir := Vector2.from_angle(rng.randf() * TAU)
			for i in rng.randi_range(5, 12):
				p += dir.rotated(rng.randf_range(-0.5, 0.5))
				var ix := int(p.x)
				var iy := int(p.y)
				if ix >= 0 and iy >= 0 and ix < w and iy < h and img.get_pixel(ix, iy).a > 0.0:
					img.set_pixel(ix, iy, crack)
	# Bank life: up to 6 stones, 3-5 reed clumps (more in a marsh).
	var stones := rng.randi_range(2, 3) if marsh else rng.randi_range(4, 6)
	var reeds := rng.randi_range(5, 7) if marsh else rng.randi_range(3, 5)
	for k in stones:
		var a := rng.randf() * TAU
		var e := Scenery.pond_edge(a, seed) - u
		var sx := int(cx + cos(a) * e * cx)
		var sy := int(cy + sin(a) * e * cy)
		for off: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
			if sx + off.x >= 0 and sx + off.x < w and sy >= 0 and sy < h:
				img.set_pixel(sx + off.x, sy, Color("8a8478") if k % 2 == 0 else Color("b3ad9f"))
	for k in reeds:
		var a := rng.randf() * TAU
		var e := Scenery.pond_edge(a, seed) - u
		var rx := int(cx + cos(a) * e * cx)
		var ry := int(cy + sin(a) * e * cy)
		var tall := rng.randi_range(3, 5)
		for dy in tall:
			for dx in 2:
				var tx := rx + dx
				var ty := ry - dy
				if tx >= 0 and tx < w and ty >= 0 and ty < h and (dx == 0 or dy < tall - 1):
					var top := dy == tall - 1
					var rc := Color("4f7a3a") if not frozen else Color("8a8a5a")
					img.set_pixel(tx, ty, snow if (frozen and top) else (Color("6b4a2a") if top else rc))
	return img


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


## GFX-116: a stream frozen over: pale ice, a few 1-px white crack lines along its length, snow lips on both banks.
static func frozen_stream(px: Vector2i) -> ImageTexture:
	var key := "frozen_stream|%s" % px
	if _cache.has(key):
		return _cache[key]
	var w := px.x
	var h := px.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("dcebf7"))
	var lip := Color("f8fbff")
	var crack := Color("ffffff")
	var shade := Color("b4cde0")
	var along_x := w >= h
	var thick := mini(w, h)
	for y in h:
		for x in w:
			var across := y if along_x else x
			if across < 2 or across >= thick - 2:
				img.set_pixel(x, y, lip)
			elif across == 2 or across == thick - 3:
				img.set_pixel(x, y, shade)
	# 1-px white crack lines: short staggered dashes at fixed fractions of the width.
	for k in 3:
		var lane := 4 + (thick - 8) * (k + 1) / 4
		var pos := (k * 37) % 23
		var length := w if along_x else h
		while pos < length:
			var run := 5 + (pos * 7 + k) % 6
			for i in run:
				var a := pos + i
				if a >= length:
					break
				var off := lane + ((a / 4 + k) % 3 - 1)
				off = clampi(off, 3, thick - 4)
				img.set_pixel(a if along_x else off, off if along_x else a, crack)
			pos += run + 12 + (pos * 3 + k * 5) % 14
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
