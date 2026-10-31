class_name GroundTiles
extends RefCounted
## Generated 16x16 pixel-style ground and path tiles (GFX-007). A fallback used only when
## no `ground_*`/`path_*` sprite is mapped; the pack replaces it with a data edit.

const SIZE := 16

static var _cache: Dictionary = {}


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
			var dark := base.darkened(0.1)
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
static func ground_texture(base: Color, rid: String, size_px: Vector2i, flowers: bool, season: String = "") -> ImageTexture:
	var key := "ground|%s|%s|%s|%s|%s" % [base.to_html(), rid, size_px, flowers, season]
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
	_apply_season(img, rid, season)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


const OCHRE := Color("b59a4a")
const SNOW := Color("dfe6ee")
const PATH_SNOW := Color("cfd6de")
const FLOWER_COLORS := [Color("f4efe0"), Color("e88aa8"), Color("f2d24b")]
const LEAF_COLORS := [Color("c8622a"), Color("d9902f"), Color("a8481f")]


## GFX-039: the season a region's ground is drawn in: a region whose map has `no_snow` keeps its summer ground in winter.
static func ground_season(season: String, map: Dictionary) -> String:
	if season == "Winter" and bool(map.get("no_snow", false)):
		return ""
	return season


## Recolours a finished ground image for `season` ("Spring", "Autumn", "Winter"; anything else is left alone).
## No rng: every choice comes from `variant_for`-style hashes, so the same inputs give the same image.
static func _apply_season(img: Image, rid: String, season: String) -> void:
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
			_tint_image(img, SNOW, 0.55)
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
static func path_texture(base: Color, rid: String, size_px: Vector2i, season: String = "") -> ImageTexture:
	var key := "pathrect|%s|%s|%s|%s" % [base.to_html(), rid, size_px, season]
	if _cache.has(key):
		return _cache[key]
	var w := maxi(size_px.x, 1)
	var h := maxi(size_px.y, 1)
	var tile := make_tile(base, rid, "path").get_image()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, tile.get_pixel(x % SIZE, y % SIZE))
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
