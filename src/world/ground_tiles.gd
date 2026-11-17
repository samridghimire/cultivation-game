class_name GroundTiles
extends RefCounted
## Generated 16x16 pixel-style ground and path tiles (GFX-007). A fallback used only when
## no `ground_*`/`path_*` sprite is mapped; the pack replaces it with a data edit.

const SIZE := 16

static var _cache: Dictionary = {}


## PERF-008: forget every generated texture (the load-time script times cold builds).
static func clear_cache() -> void:
	_cache.clear()


## A deterministic seamless tile: `base` speckled with darker and lighter pixels. Ground
## tiles get a few two-pixel grass blades, path tiles darker pebbles.
static func make_tile(base: Color, seed_text: String, kind: String) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text + kind)
	var dark_share := 0.18 if kind == "path" else 0.14
	for y in SIZE:
		for x in SIZE:
			var roll := rng.randf()
			if roll < dark_share:
				img.set_pixel(x, y, base.darkened(0.12))
			elif roll < dark_share + 0.06:
				img.set_pixel(x, y, base.lightened(0.10))
	if kind == "ground":
		for i in rng.randi_range(2, 3):
			# Blades stay inside rows 0..15, so none continues off the tile edge.
			var bx := rng.randi_range(0, SIZE - 1)
			var by := rng.randi_range(0, SIZE - 2)
			img.set_pixel(bx, by, base.lightened(0.18))
			img.set_pixel(bx, by + 1, base.lightened(0.18))
	return ImageTexture.create_from_image(img)


## `make_tile`, memoised so a region redraw does not rebuild it.
static func cached(base: Color, seed_text: String, kind: String) -> ImageTexture:
	var key := "%s|%s|%s" % [base.to_html(), seed_text, kind]
	if not _cache.has(key):
		_cache[key] = make_tile(base, seed_text, kind)
	return _cache[key]


## Which of the four grass variants (0 plain, 1 clover, 2 darker tuft patch, 3 flowers) the 16-px cell
## (cx, cy) of region `rid` gets: about 70% plain so the lawn does not look noisy (GFX-026).
static func variant_for(rid: String, cx: int, cy: int) -> int:
	var roll := absi(hash("%s|%d|%d" % [rid, cx, cy])) % 100
	if roll < 70:
		return 0
	if roll < 80:
		return 1
	if roll < 90:
		return 2
	return 3


## One grass variant tile. Flowers only bloom when `flowers` is true (spring/summer); otherwise variant 3 is plain.
static func make_variant(base: Color, rid: String, variant: int, flowers: bool) -> ImageTexture:
	var img := make_tile(base, rid, "ground").get_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|v%d" % [rid, variant])
	match variant:
		1:
			var clover := base.darkened(0.2)
			for i in 3:
				var x := rng.randi_range(1, SIZE - 3)
				var y := rng.randi_range(1, SIZE - 3)
				img.fill_rect(Rect2i(x, y, 2, 2), clover)
				img.set_pixel(x, y, base.lightened(0.22))
		2:
			# GFX-082: a barely darker tint (mean luminance within 3% of the plain cell), so cells never meet in hard blocks.
			var dark := base.darkened(0.03)
			for y in SIZE:
				for x in SIZE:
					if rng.randf() < 0.55:
						img.set_pixel(x, y, dark)
			for i in 2:
				var bx := rng.randi_range(0, SIZE - 1)
				var by := rng.randi_range(0, SIZE - 2)
				img.set_pixel(bx, by, base.lightened(0.2))
				img.set_pixel(bx, by + 1, base.lightened(0.2))
		3:
			if flowers:
				var blooms := [Color("f4efe0"), Color("f2d24b"), Color("e88aa8")]
				for i in 3:
					img.set_pixel(rng.randi_range(1, SIZE - 2), rng.randi_range(1, SIZE - 2), blooms[rng.randi() % blooms.size()])
	return ImageTexture.create_from_image(img)


## The whole ground of a region as one texture, 1 px per sprite pixel (the caller scales it): 16-px
## cells picked by `variant_for`. Built once per region and season-bloom state, so `_draw()` stays cheap.
static func ground_texture(base: Color, rid: String, size_px: Vector2i, flowers: bool, season: String = "", style: String = "grass", zones: Array = [], scree_density: float = 1.0, life: Dictionary = {}) -> ImageTexture:
	var key := "ground|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [base.to_html(), rid, size_px, flowers, season, style, zones, scree_density, life]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
	var variants: Array[Image] = []
	for v in 4:
		variants.append(make_variant(base, rid, v, flowers).get_image())
	for cy in ceili(float(size_px.y) / SIZE):
		for cx in ceili(float(size_px.x) / SIZE):
			var src := variants[variant_for(rid, cx, cy)]
			var w := mini(SIZE, size_px.x - cx * SIZE)
			var h := mini(SIZE, size_px.y - cy * SIZE)
			img.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(cx * SIZE, cy * SIZE))
	var lively := LIVELY_STYLES.has(style)
	var dry_tips: Array[Vector2i] = []
	var shade_grid: PackedFloat32Array = PackedFloat32Array()
	if lively:
		shade_grid = shade_grid_for(rid, size_px)
		_apply_patches(img, base, shade_grid)
		_apply_clover(img, base, rid, style, life.get("avoid", []))
		_apply_worn(img, rid, life.get("worn", []), life.get("path_color", base.lerp(Color("7a6a48"), 0.5)), shade_grid)
		if style == "grass":
			dry_tips = _meadow_life(img, base, rid, season, life.get("avoid", []), life.get("worn", []))  # GFX-181
	_apply_style(img, base, rid, style, zones, scree_density, float(life.get("speckle", 1.0)))
	if style == "scree":
		_scree_slopes(img, base, rid)  # GFX-159
		_alpine_life(img, rid, season)  # GFX-175
	var summer: Image = img.duplicate() if season == "Winter" and style == "paved" and not zones.is_empty() else null
	_apply_season(img, rid, season, PAVED_SNOW if style == "paved" else WINTER_SNOW)
	if summer != null:
		_winter_streets(img, summer, rid, zones)
	if lively and season == "Winter":
		_vary_snow(img, shade_grid)
		for t in dry_tips:  # GFX-181: dry stalks poke through the snow
			_set_clipped(img, t.x, t.y, Color("b59a62"))
			_set_clipped(img, t.x, t.y + 1, Color("8a7447"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


const LIVELY_STYLES := ["grass", "litter", "bog"]  ## GFX-130: the styles that get patches, clover and worn ground
const PATCH_CELLS := [96, 40]


static func _lattice(rid: String, octave: int, cx: int, cy: int) -> float:
	return float(absi(hash("%s|patch%d|%d|%d" % [rid, octave, cx, cy])) % 2001) / 1000.0 - 1.0


## GFX-130: low-frequency value noise in -1..1 (two octaves, ~96 px and ~40 px cells, smoothstep between lattice values).
static func patch_shade(rid: String, x: int, y: int) -> float:
	var total := 0.0
	for o in PATCH_CELLS.size():
		var cell := float(PATCH_CELLS[o])
		var fx := float(x) / cell
		var fy := float(y) / cell
		var cx := floori(fx)
		var cy := floori(fy)
		var tx := smoothstep(0.0, 1.0, fx - cx)
		var ty := smoothstep(0.0, 1.0, fy - cy)
		var top := lerpf(_lattice(rid, o, cx, cy), _lattice(rid, o, cx + 1, cy), tx)
		var bot := lerpf(_lattice(rid, o, cx, cy + 1), _lattice(rid, o, cx + 1, cy + 1), tx)
		total += lerpf(top, bot, ty) * (0.7 if o == 0 else 0.3)
	return clampf(total * 1.35, -1.0, 1.0)


## `patch_shade` for every pixel of a region image, with the lattice computed once per cell (fast).
static func shade_grid_for(rid: String, size_px: Vector2i) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(size_px.x * size_px.y)
	var lat: Array = []
	for o in PATCH_CELLS.size():
		var cell: int = PATCH_CELLS[o]
		var gw := size_px.x / cell + 2
		var gh := size_px.y / cell + 2
		var l := PackedFloat32Array()
		l.resize(gw * gh)
		for cy in gh:
			for cx in gw:
				l[cy * gw + cx] = _lattice(rid, o, cx, cy)
		lat.append(l)
	for y in size_px.y:
		for x in size_px.x:
			var total := 0.0
			for o in PATCH_CELLS.size():
				var cell: int = PATCH_CELLS[o]
				var gw := size_px.x / cell + 2
				var l: PackedFloat32Array = lat[o]
				var fx := float(x) / cell
				var fy := float(y) / cell
				var cx := int(fx)
				var cy := int(fy)
				var tx := smoothstep(0.0, 1.0, fx - cx)
				var ty := smoothstep(0.0, 1.0, fy - cy)
				var top := lerpf(l[cy * gw + cx], l[cy * gw + cx + 1], tx)
				var bot := lerpf(l[(cy + 1) * gw + cx], l[(cy + 1) * gw + cx + 1], tx)
				total += lerpf(top, bot, ty) * (0.7 if o == 0 else 0.3)
			grid[y * size_px.x + x] = clampf(total * 1.35, -1.0, 1.0)
	return grid


static func _apply_patches(img: Image, base: Color, grid: PackedFloat32Array) -> void:
	var w := img.get_width()
	var light := base.lightened(0.10)
	var dark := base.darkened(0.12)
	for y in img.get_height():
		for x in w:
			var s := grid[y * w + x]
			if s > 0.35:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(light, smoothstep(0.35, 0.8, s)))
			elif s < -0.35:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(dark, smoothstep(0.35, 0.8, -s)))


## GFX-130: 6-12 clover/moss blobs (sprite px, 20-48 wide) per region, none touching a rect in `avoid`.
static func clover_rects(rid: String, size_px: Vector2i, avoid: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var n := 6 + absi(hash(rid + "|clover")) % 7
	for i in n * 3:
		if out.size() >= n:
			break
		var r := absi(hash("%s|clover|%d" % [rid, i]))
		var w := 20 + r % 29
		var h := 20 + (r / 64) % 29
		if size_px.x <= w or size_px.y <= h:
			continue
		var rect := Rect2(float((r / 4096) % (size_px.x - w)), float((r / 1048576) % (size_px.y - h)), w, h)
		var ok := true
		for a: Rect2 in avoid:
			if a.intersects(rect.grow(2.0)):
				ok = false
				break
		if ok:
			out.append(rect)
	return out


static func _apply_clover(img: Image, base: Color, rid: String, style: String, avoid: Array) -> void:
	var moss := style != "grass"
	var tint := base.darkened(0.2).lerp(Color("3f6a52"), 0.3) if moss else base.lerp(Color("5f9a4c"), 0.35).lightened(0.03)
	var rects := clover_rects(rid, Vector2i(img.get_width(), img.get_height()), avoid)
	for i in rects.size():
		var rc := rects[i]
		var c := rc.get_center()
		for y in range(int(rc.position.y), int(rc.end.y)):
			for x in range(int(rc.position.x), int(rc.end.x)):
				var d := Vector2((x - c.x) / (rc.size.x * 0.5), (y - c.y) / (rc.size.y * 0.5)).length()
				var edge := float(absi(hash("%s|cl%d|%d|%d" % [rid, i, x / 3, y / 3])) % 30) / 100.0
				if d + edge * 0.5 < 1.0:
					var a := clampf(1.0 - d, 0.0, 1.0) * 0.9 + 0.1
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(tint, minf(a, 0.7)))
					var dot := absi(hash("%s|dot%d|%d|%d" % [rid, i, x, y])) % 23
					if dot == 0:
						img.set_pixel(x, y, base.lightened(0.2 if moss else 0.16).lerp(tint, 0.3))


## GFX-130: grass thins to the path colour (35%) in a ragged ellipse under each `worn` Rect2 (sprite px).
static func _apply_worn(img: Image, rid: String, worn: Array, path_color: Color, grid: PackedFloat32Array) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for rc: Rect2 in worn:
		var c := rc.get_center()
		var x0 := maxi(0, int(rc.position.x))
		var x1 := mini(w, int(rc.end.x))
		var y0 := maxi(0, int(rc.position.y))
		var y1 := mini(h, int(rc.end.y))
		for y in range(y0, y1):
			for x in range(x0, x1):
				var d := Vector2((x - c.x) / (rc.size.x * 0.5), (y - c.y) / (rc.size.y * 0.5)).length()
				d += grid[y * w + x] * 0.18
				if d > 0.75 and d < 1.25:  # GFX-181: ragged lobes near the rim
					d += (float(absi(hash("%s|wr|%d|%d" % [rid, x / 4, y / 4])) % 100) / 100.0 - 0.5) * 0.3
				if d < 1.0:
					var col := img.get_pixel(x, y).lerp(path_color, 0.35 * smoothstep(1.0, 0.5, d))
					if d < 0.8 and absi(hash("%s|wp|%d|%d" % [rid, x, y])) % 70 == 0:  # pebble
						var pc := path_color.darkened(0.25) if (x + y) % 2 == 0 else path_color.lightened(0.2)
						col = pc
						img.set_pixel(x, y, col)
						_set_clipped(img, x + 1, y, pc.darkened(0.1))
						continue
					img.set_pixel(x, y, col)


## GFX-130: winter snow 0.75..1.0 by patch shade, so it is not one flat sheet (the base pass already put 0.7 on).
static func _vary_snow(img: Image, grid: PackedFloat32Array) -> void:
	var w := img.get_width()
	for y in img.get_height():
		for x in w:
			var t := (grid[y * w + x] + 1.0) * 0.5
			var amount := 0.75 + 0.25 * t
			var extra := (amount - WINTER_SNOW) / (1.0 - WINTER_SNOW) * 0.5
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(SNOW, extra * 0.5))


## GFX-164: whether a speckle blob (hash `r`) survives a map's `speckle` factor (1.0 keeps all, 0.33 about a third).
static func speckle_keep(r: int, speckle: float) -> bool:
	var m := ((r * 2654435761) >> 11) & 0xFFFFF  # multiplicative mix so similar hashes disperse
	return float(m % 100) < speckle * 100.0


## GFX-164: the tone level 0..3 of slope band `band`: always differs from the band before it, so every edge shows a step.
static func scree_band_level(rid: String, band: int) -> int:
	var level := absi(hash("%s|slope|%d" % [rid, band])) % 4
	if band > 0 and level == scree_band_level(rid, band - 1):
		level = (level + 1 + absi(hash("%s|slopeflip|%d" % [rid, band])) % 3) % 4
	return level


## GFX-159/164: scree slope tone: broad seeded horizontal bands (about 110 px), four tone levels 0.09 apart, lighter toward the top.
static func scree_slope_shade(rid: String, y: int, height: int) -> float:
	var band := maxi(y, 0) / 110
	var up := 1.0 - float(y) / float(maxi(height, 1))
	return (up - 0.5) * 0.12 + (float(scree_band_level(rid, band)) - 1.5) * 0.09


## GFX-181: pure hashed blob centres (x, y, size) for the meadow, never inside an `avoid` rect.
static func meadow_blobs(rid: String, kind: String, count: int, size_px: Vector2i, avoid: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in count:
		var r := absi(hash("%s|mdw|%s|%d" % [rid, kind, i]))
		var b := Vector3(float(r % maxi(size_px.x, 1)), float((r / 4096) % maxi(size_px.y, 1)), 10.0 + float((r / 64) % 22))
		if not _in_rects(avoid, b.x, b.y):
			out.append(b)
	return out


static func _in_rects(rects: Array, x: float, y: float) -> bool:
	for a: Rect2 in rects:
		if a.has_point(Vector2(x, y)):
			return true
	return false


static func _tuft(img: Image, x: int, y: int, height: int, base: Color, tip: Color) -> void:
	for k in height:
		var c := base.darkened(0.18).lerp(tip, float(k) / maxf(height - 1, 1.0))
		_set_clipped(img, x, y - k, c)
		if k >= 1 and height >= 3:
			_set_clipped(img, x + (1 if k % 2 == 0 else -1), y - k, c.darkened(0.06))


## GFX-181: tuft clumps, lone tufts and a season detail on the village meadow. Returns the dry-tip pixels
## that winter re-draws over its snow.
static func _meadow_life(img: Image, base: Color, rid: String, season: String, avoid: Array, worn: Array) -> Array[Vector2i]:
	var size_px := Vector2i(img.get_width(), img.get_height())
	var area := float(size_px.x * size_px.y) / 1000000.0
	var tips: Array[Vector2i] = []
	var tip_col := base.lightened(0.12)
	if season == "Autumn":
		tip_col = Color("a8602f")
	var alt_tip := Color("c9a55a")
	var clumps := meadow_blobs(rid, "clump", maxi(3, int(area * 10.0)), size_px, avoid)
	for ci in clumps.size():
		var b := clumps[ci]
		var r := absi(hash("%s|mdw|c|%d" % [rid, ci]))
		var n := 4 + r % 6
		var decorated := r % 3 == 0
		for j in n:
			var rj := absi(hash("%s|mdw|t|%d|%d" % [rid, ci, j]))
			var x := int(b.x) + int(rj % 29) - 14
			var y := int(b.y) + int((rj / 64) % 29) - 14
			if _in_rects(avoid, x, y):
				continue
			var tc := alt_tip if season == "Autumn" and j % 2 == 0 else tip_col
			_tuft(img, x, y, 3 + (rj / 4096) % 3, base, tc)
			if season == "Winter" and j % 2 == 0:
				tips.append(Vector2i(x, y - 3))
			if decorated and j == 0:
				if season == "Spring":
					_set_clipped(img, x + 2, y - 1, Color("f4efe0") if r % 2 == 0 else Color("f2e68a"))
				elif season == "Summer":
					_set_clipped(img, x + 2, y - 1, FLOWER_COLORS[(r / 8) % FLOWER_COLORS.size()])
	for b in meadow_blobs(rid, "lone", int(area * 60.0), size_px, avoid):
		_tuft(img, int(b.x), int(b.y), 2 + int(b.z) % 2, base, tip_col)
	if season == "Autumn":
		var leaves := [Color("b0442a"), Color("c9742f"), Color("d99a3a")]
		for b in meadow_blobs(rid, "leaf", int(area * 40.0), size_px, avoid):
			var lc: Color = leaves[int(b.z) % leaves.size()]
			_set_clipped(img, int(b.x), int(b.y), lc)
			_set_clipped(img, int(b.x) + 1, int(b.y), lc.darkened(0.12))
	# tuft fringe just outside each worn yard's rim
	for wi in worn.size():
		var rc: Rect2 = worn[wi]
		var c := rc.get_center()
		for k in 6:
			var rk := absi(hash("%s|mdw|f|%d|%d" % [rid, wi, k]))
			var ang := float(rk % 628) / 100.0
			var x := int(c.x + cos(ang) * rc.size.x * 0.5 * 1.04)
			var y := int(c.y + sin(ang) * rc.size.y * 0.5 * 1.04)
			if not _in_rects(avoid, x, y):
				_tuft(img, x, y, 3, base, tip_col)
	return tips


## GFX-175: alpine variety on a scree ground: darker damp hollows, pale scree fans, lichen patches and hardy
## grass tufts, plus a season detail (spring snow patches, summer flowers, autumn rust grass). Pure hashes of
## the region id (no rng); winter's own snow pass runs afterwards, so no extra winter detail here.
static func alpine_blobs(rid: String, kind: String, count: int, size_px: Vector2i) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in count:
		var r := absi(hash("%s|alp|%s|%d" % [rid, kind, i]))
		out.append(Vector3(float(r % maxi(size_px.x, 1)), float((r / 4096) % maxi(size_px.y, 1)), 10.0 + float((r / 64) % 22)))
	return out


static func _blend_blob(img: Image, b: Vector3, squash: float, tint: Color, strength: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rx := b.z
	var ry := b.z * squash
	for y in range(maxi(0, int(b.y - ry)), mini(h, int(b.y + ry) + 1)):
		for x in range(maxi(0, int(b.x - rx)), mini(w, int(b.x + rx) + 1)):
			var d := Vector2((x - b.x) / rx, (y - b.y) / ry).length()
			var edge := 0.78 + 0.22 * sin(float(x) * 0.7 + float(y) * 0.5)  # ragged rim
			if d < edge:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(tint, strength * (1.0 - d / edge) * 0.8 + strength * 0.2))


static func _alpine_life(img: Image, rid: String, season: String) -> void:
	var size_px := Vector2i(img.get_width(), img.get_height())
	var area := float(size_px.x * size_px.y) / 1000000.0
	var n := maxi(4, int(area * 14.0))
	for b in alpine_blobs(rid, "hollow", n, size_px):
		_blend_blob(img, b, 0.6, Color("3a4450"), 0.5)
	# GFX-179: scree fans are drawn at each outcrop's foot by world.gd, no random fans in the ground
	for b in alpine_blobs(rid, "lichen", n * 2, size_px):
		_blend_blob(img, Vector3(b.x, b.y, b.z * 0.5), 0.7, Color("8d9a5a"), 0.5)
	var grass := Color("6b8248")
	if season == "Autumn":
		grass = Color("a8602f")
	for b in alpine_blobs(rid, "tuft", n * 8, size_px):
		var x := int(b.x)
		var y := int(b.y)
		for o in [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(1, -2), Vector2i(0, -2)]:
			_set_clipped(img, x + o.x, y + o.y, grass.darkened(0.12 * float(o.y == 0)))
	match season:
		"Spring":
			for b in alpine_blobs(rid, "snow", maxi(3, n / 2), size_px):
				_blend_blob(img, Vector3(b.x, b.y, b.z * 1.1), 0.55, Color("eef3f7"), 0.9)
		"Summer":
			for b in alpine_blobs(rid, "flower", n * 6, size_px):
				_set_clipped(img, int(b.x), int(b.y), FLOWER_COLORS[int(b.z) % FLOWER_COLORS.size()])


static func _scree_slopes(img: Image, base: Color, rid: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x in w:  # GFX-164: the band edges wander with x (never a straight line)
		var off := int(10.0 * sin(float(x) * 0.021 + 1.3) + 7.0 * sin(float(x) * 0.0063) + 4.0 * sin(float(x) * 0.09))
		var wobble := (float(absi(hash("%s|sl|%d" % [rid, x / 40])) % 5) - 2.0) * 0.004
		for y in h:
			var f := scree_slope_shade(rid, y + off, h) + wobble
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.lightened(f) if f >= 0.0 else c.darkened(-f))


## GFX-053: 3-6 big soft tint patches on a scree ground, seeded from the region id: frost above y 300, moss below.
static func _scree_patches(img: Image, base: Color, rid: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var n := 3 + absi(hash(rid + "|patches")) % 4
	for i in n:
		var r := absi(hash("%s|patch|%d" % [rid, i]))
		var centre := Vector2(float(r % w), float((r / 4096) % h))
		var radius := 90.0 + float((r / 64) % 90)
		var frost := centre.y < 300.0
		var tint := Color("dfe9f2") if frost else Color("3f6a52")
		var x0 := maxi(0, int(centre.x - radius))
		var x1 := mini(w, int(centre.x + radius))
		var y0 := maxi(0, int(centre.y - radius * 0.7))
		var y1 := mini(h, int(centre.y + radius * 0.7))
		for y in range(y0, y1):
			for x in range(x0, x1):
				var d := Vector2((x - centre.x) / radius, (y - centre.y) / (radius * 0.7)).length()
				if d < 1.0:
					var a := (1.0 - d) * (1.0 - d) * 0.35
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(tint, a))


## GFX-054: true when (x, y) (sprite px) lies in one of the paved `zones` (Rect2 in sprite px), whose edge is
## roughened by up to 6 px of per-8px-cell jitter so the flagstones fade into the earth in ragged steps.
static func in_paved_zone(zones: Array, rid: String, x: int, y: int, inset: float = 0.0) -> bool:
	var jitter := float(absi(hash("%s|%d|%d|zone" % [rid, x / 8, y / 8])) % 7) + inset
	for z: Rect2 in zones:
		if z.grow(-jitter).has_point(Vector2(x, y)):
			return true
	return false


## PERF-008: the per-8x8-cell jitter `in_paved_zone` hashes for every pixel, computed once per cell
## (row-major, `ceil(w / 8)` columns). `in_paved_zone_grid` reads it and answers exactly as `in_paved_zone` does.
static func zone_jitter_grid(rid: String, w: int, h: int) -> PackedFloat32Array:
	var cols := ceili(float(w) / 8.0)
	var rows := ceili(float(h) / 8.0)
	var grid := PackedFloat32Array()
	grid.resize(cols * rows)
	for cy in rows:
		for cx in cols:
			grid[cy * cols + cx] = float(absi(hash("%s|%d|%d|zone" % [rid, cx, cy])) % 7)
	return grid


static func in_paved_zone_grid(zones: Array, grid: PackedFloat32Array, cols: int, x: int, y: int, inset: float = 0.0) -> bool:
	var jitter := grid[(y / 8) * cols + x / 8] + inset
	for z: Rect2 in zones:
		if z.grow(-jitter).has_point(Vector2(x, y)):
			return true
	return false


## GFX-158: how far a winter market pixel is tinted toward snow: swept stone stays dark (0.2) with snow only in a 4 px
## band along the kerbs (0.7); earth lots get a heavy but uneven cover (0.8) with about a quarter bare patches (0.3).
## PERF-008: `shade` is the pixel's `patch_shade` (a `shade_grid_for` entry), or NAN to compute it here.
static func winter_street_amount(paved: bool, in_band: bool, rid: String, x: int, y: int, shade: float = NAN) -> float:
	if paved:
		return 0.2 if not in_band else 0.7
	var jitter := float(absi(hash("%s|%d|%d|slush" % [rid, x, y])) % 100) / 100.0 * 0.2 - 0.1  # ragged patch edges
	if is_nan(shade):
		shade = patch_shade(rid, x, y)
	return 0.3 if shade + jitter < -0.3 else 0.8


## GFX-158: re-tints a paved market's winter ground from its `summer` pixels (streets vs earth lots, see above).
static func _winter_streets(img: Image, summer: Image, rid: String, zones: Array) -> void:
	var cols := ceili(float(img.get_width()) / 8.0)
	var jit := zone_jitter_grid(rid, img.get_width(), img.get_height())
	var shades := shade_grid_for(rid, Vector2i(img.get_width(), img.get_height()))
	for y in img.get_height():
		for x in img.get_width():
			var paved := in_paved_zone_grid(zones, jit, cols, x, y)
			var band := paved and not in_paved_zone_grid(zones, jit, cols, x, y, 4.0)
			var a := winter_street_amount(paved, band, rid, x, y, shades[y * img.get_width() + x])
			img.set_pixel(x, y, summer.get_pixel(x, y).lerp(SNOW, a))


## GFX-054: packed earth between the streets: the ground colour warmed and darkened with sparse pebbles.
static func _earth_pixel(base: Color, rid: String, x: int, y: int) -> Color:
	var earth := base.lerp(Color("7a6a48"), 0.3).darkened(0.08)
	var r := absi(hash("%s|%d|%d|earth" % [rid, x, y]))
	if r % 53 == 0:
		return earth.lightened(0.14)
	if r % 17 == 0:
		return earth.darkened(0.1)
	return earth.darkened(float((x / 4 + y / 4) % 3) * 0.02)


const STYLES := PlaceLooks.GROUND_STYLES


## GFX-042: redraws a finished grass ground image in a regional style. "grass" is left alone. Every choice comes
## from hashes of (rid, cell), so the same inputs give the same image.
static func _apply_style(img: Image, base: Color, rid: String, style: String, zones: Array = [], scree_density: float = 1.0, speckle: float = 1.0) -> void:
	var w := img.get_width()
	var h := img.get_height()
	match style:
		"paved":
			# 16 px flagstones in offset rows, a 1 px darker mortar line, +-4% brightness per stone.
			var mortar := base.darkened(0.3)
			var jit := zone_jitter_grid(rid, w, h)
			var jcols := ceili(float(w) / 8.0)
			var stones := {}
			for y in h:
				var row := y / SIZE
				var shift := 8 if row % 2 == 1 else 0
				for x in w:
					if not zones.is_empty() and not in_paved_zone_grid(zones, jit, jcols, x, y):
						img.set_pixel(x, y, _earth_pixel(base, rid, x, y))
						continue
					var col := (x + shift) / SIZE
					var edge := y % SIZE == 0 or (x + shift) % SIZE == 0
					if edge:
						img.set_pixel(x, y, mortar)
					else:
						var skey := row * 4096 + col  # PERF-008: a stone's variant and tone are hashed once, not per pixel
						if not stones.has(skey):
							stones[skey] = [variant_for(rid, col, row), (float(absi(hash("%s|%d|%d|stone" % [rid, col, row])) % 81) - 40.0) / 1000.0]
						var v: int = stones[skey][0]
						var f: float = stones[skey][1]
						var c := base.lightened(f) if f >= 0.0 else base.darkened(-f)
						if (x * 7 + y * 13 + v) % 11 == 0:
							c = c.darkened(0.06)
						img.set_pixel(x, y, c)
		"scree":
			for cy in ceili(float(h) / SIZE):
				for cx in ceili(float(w) / SIZE):
					var roll := absi(hash("%s|%d|%d|scree" % [rid, cx, cy]))
					for i in roundi((1 + roll % 3) * scree_density * 0.5):  # GFX-159: half the speckle; GFX-068: half the blobs; GFX-079: map.scree_density
						var r2 := absi(hash("%s|%d|%d|scree|%d" % [rid, cx, cy, i]))
						if not speckle_keep(r2, speckle):
							continue
						var pw := 2 + r2 % 3
						var ph := 2 + (r2 / 8) % 2
						var px := cx * SIZE + (r2 / 64) % (SIZE - 4)
						var py := cy * SIZE + (r2 / 1024) % (SIZE - 3)
						var shade := base.lightened(0.07 * minf(speckle + 0.3, 1.0)) if r2 % 2 == 0 else base.darkened(0.1 * minf(speckle + 0.3, 1.0))  # GFX-053: half the contrast; GFX-164: fainter on a sparse map
						_fill_clipped(img, Rect2i(px, py, pw, ph), shade)
					if roll % 8 == 0:
						var cx0 := cx * SIZE + (roll / 4) % (SIZE - 6)
						var cy0 := cy * SIZE + (roll / 64) % (SIZE - 6)
						for k in 5:
							_set_clipped(img, cx0 + k, cy0 + k / 2, base.darkened(0.15))
			_scree_patches(img, base, rid)
		"litter":
			# Grass with darker leaf-litter specks (2x1 px) scattered over it.
			for cy in ceili(float(h) / SIZE):
				for cx in ceili(float(w) / SIZE):
					var roll := absi(hash("%s|%d|%d|litter" % [rid, cx, cy]))
					for i in 3 + roll % 3:
						var r2 := absi(hash("%s|%d|%d|litter|%d" % [rid, cx, cy, i]))
						_fill_clipped(img, Rect2i(cx * SIZE + r2 % (SIZE - 2), cy * SIZE + (r2 / 16) % SIZE, 2, 1), base.darkened(0.3 if r2 % 3 else 0.15))
		"bog":
			for cy in ceili(float(h) / SIZE):
				for cx in ceili(float(w) / SIZE):
					var roll := absi(hash("%s|%d|%d|bog" % [rid, cx, cy]))
					# GFX-046: half as many dark puddles as before; length and strength vary per tile, so the ground
					# reads as wet rather than dirty. Lighter bluish patches (about 3 of 5 tiles) sit between them.
					if roll % 20 == 0:
						var pw := 2 + (roll / 10) % 4 + 2
						var ph := 2 + (roll / 64) % 2
						var px := cx * SIZE + (roll / 512) % 8
						var py := cy * SIZE + (roll / 4096) % 10
						var strength := 0.25 + float((roll / 7) % 6) * 0.05
						_fill_clipped(img, Rect2i(px, py, pw, ph), base.lerp(base.darkened(0.45), strength * 2.0))
					elif (roll / 11) % 5 < 1:
						var pw := 5 + (roll / 13) % 6
						var ph := 3 + (roll / 128) % 3
						var px := cx * SIZE + 1 + (roll / 1024) % (SIZE - pw - 2)
						var py := cy * SIZE + 1 + (roll / 8192) % (SIZE - ph - 2)
						var puddle := base.darkened(0.12).lerp(Color("2c4656"), 0.4)
						_fill_clipped(img, Rect2i(px + 1, py, pw - 2, ph), puddle)
						_fill_clipped(img, Rect2i(px, py + 1, pw, ph - 2), puddle)
						_fill_clipped(img, Rect2i(px + 1, py, maxi(1, pw - 4), 1), puddle.lightened(0.12))
					if roll % 20 == 1:
						# Reed tufts: about half as many as before, position and shape (2-3) vary per tile.
						var r3 := absi(hash("%s|%d|%d|reed" % [rid, cx, cy]))
						var rx := cx * SIZE + 2 + r3 % (SIZE - 8)
						var ry := cy * SIZE + 4 + (r3 / 64) % (SIZE - 10)
						var reed := base.lightened(0.3)
						match (r3 / 4096) % 3:
							0:
								for k in 3:
									_fill_clipped(img, Rect2i(rx + k * 2, ry + (k % 2), 1, 3 + k % 2), reed)
							1:
								for k in 4:
									_fill_clipped(img, Rect2i(rx + k, ry + (k * 3) % 3, 1, 3), reed)
							_:
								_fill_clipped(img, Rect2i(rx, ry + 1, 1, 4), reed)
								_fill_clipped(img, Rect2i(rx + 2, ry, 1, 5), reed)


static func _set_clipped(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _fill_clipped(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_set_clipped(img, x, y, c)


const OCHRE := Color("b59a4a")
const SNOW := Color("dfe6ee")
const PATH_SNOW := Color("cfd6de")
const WINTER_SNOW := 0.7  ## how far winter ground is tinted toward SNOW
const PAVED_SNOW := 0.45  ## GFX-064: paved ground is tinted less, so the flagstone grid still shows through the snow
const FLOWER_COLORS := [Color("f4efe0"), Color("e88aa8"), Color("f2d24b")]
const LEAF_COLORS := [Color("c8622a"), Color("d9902f"), Color("a8481f")]


## GFX-039: the season a region's ground is drawn in: a region whose map has `no_snow` keeps its summer ground in winter.
static func ground_season(season: String, map: Dictionary) -> String:
	if season == "Winter" and bool(map.get("no_snow", false)):
		return ""
	return season


## Recolours a finished ground image for `season` ("Spring", "Autumn", "Winter"; anything else is left alone).
## No rng: every choice comes from `variant_for`-style hashes, so the same inputs give the same image.
static func _apply_season(img: Image, rid: String, season: String, snow_amount: float = WINTER_SNOW) -> void:
	var w := img.get_width()
	var h := img.get_height()
	match season:
		"Spring":
			for cy in ceili(float(h) / SIZE):
				for cx in ceili(float(w) / SIZE):
					var roll := absi(hash("%s|%d|%d|spring" % [rid, cx, cy]))
					if roll % 2 != 0:
						continue
					var x := cx * SIZE + (roll / 2) % SIZE
					var y := cy * SIZE + (roll / 32) % SIZE
					if x < w and y < h:
						img.set_pixel(x, y, FLOWER_COLORS[(roll / 512) % FLOWER_COLORS.size()])
		"Autumn":
			_tint_image(img, OCHRE, 0.25)
			for cy in ceili(float(h) / SIZE):
				for cx in ceili(float(w) / SIZE):
					var roll := absi(hash("%s|%d|%d|autumn" % [rid, cx, cy]))
					if roll % 3 != 0:
						continue
					var x := cx * SIZE + (roll / 3) % (SIZE - 1)
					var y := cy * SIZE + (roll / 64) % SIZE
					if x + 1 < w and y < h:
						var leaf: Color = LEAF_COLORS[(roll / 1024) % LEAF_COLORS.size()]
						img.set_pixel(x, y, leaf)
						img.set_pixel(x + 1, y, leaf)
		"Winter":
			var summer := img.duplicate() as Image
			_tint_image(img, SNOW, snow_amount)
			for cy in ceili(float(h) / SIZE):
				for cx in ceili(float(w) / SIZE):
					var roll := absi(hash("%s|%d|%d|winter" % [rid, cx, cy]))
					var px := cx * SIZE + 2 + roll % (SIZE - 4)
					var py := cy * SIZE + 2 + (roll / 16) % (SIZE - 4)
					# An irregular 3-6 px patch of grass: a seed pixel and a few hash-picked neighbours.
					var count := 3 + (roll / 256) % 4
					var offsets := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(0, -1)]
					var start := (roll / 1024) % offsets.size()
					for i in count:
						var o: Vector2i = offsets[(start + i) % offsets.size()]
						var x := px + o.x
						var y := py + o.y
						if x >= 0 and y >= 0 and x < w and y < h:
							img.set_pixel(x, y, summer.get_pixel(x, y))


static func _tint_image(img: Image, toward: Color, amount: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c.lerp(toward, amount), c.a))


## A path rectangle of `size_px` sprite pixels: the path tile with an irregular 2-3 px fringe along each
## edge cut away (transparent, so the grass or a crossing path shows) and rounded corners.
static func path_texture(base: Color, rid: String, size_px: Vector2i, season: String = "", style: String = "grass") -> ImageTexture:
	var key := "pathrect|%s|%s|%s|%s|%s" % [base.to_html(), rid, size_px, season, style]
	if _cache.has(key):
		return _cache[key]
	var w := maxi(size_px.x, 1)
	var h := maxi(size_px.y, 1)
	var tile := make_tile(base, rid, "path").get_image()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, tile.get_pixel(x % SIZE, y % SIZE))
	if style == "paved":
		# A main street: wider (24 px), lighter flagstones with a faint mortar line.
		var lit := base.lightened(0.12)
		for y in h:
			var shift := 12 if (y / 24) % 2 == 1 else 0
			for x in w:
				var col := (x + shift) / 24
				var f := (float(absi(hash("%s|%d|%d|street" % [rid, col, y / 24])) % 61) - 30.0) / 1000.0
				var c := lit.lightened(f) if f >= 0.0 else lit.darkened(-f)
				if y % 24 == 0 or (x + shift) % 24 == 0:
					c = base.darkened(0.12)
				img.set_pixel(x, y, c)
	var clear := Color(0, 0, 0, 0)
	for side in 4:
		var length := w if side < 2 else h
		for i in length:
			var depth := 2 + absi(hash("%s|%d|%d|%d|%d" % [rid, side, i, w, h])) % 2
			for d in depth:
				match side:
					0: img.set_pixel(i, d, clear)
					1: img.set_pixel(i, h - 1 - d, clear)
					2: img.set_pixel(d, i, clear)
					_: img.set_pixel(w - 1 - d, i, clear)
	# Rounded corners: clear what lies outside a quarter circle of radius 3 at each corner.
	for corner in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		var sx := 1 if corner.x == 0 else -1
		var sy := 1 if corner.y == 0 else -1
		for dy in 4:
			for dx in 4:
				if Vector2(dx - 3, dy - 3).length() > 3.2:
					var px: int = corner.x + sx * dx
					var py: int = corner.y + sy * dy
					if px >= 0 and py >= 0 and px < w and py < h:
						img.set_pixel(px, py, clear)
	if season == "Winter":
		_tint_image(img, PATH_SNOW, 0.35)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The darker outline colour drawn along path rectangles.
static func edge_color(base: Color) -> Color:
	return base.darkened(0.25)
