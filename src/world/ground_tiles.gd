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


## The darker outline colour drawn along path rectangles.
static func edge_color(base: Color) -> Color:
	return base.darkened(0.25)
