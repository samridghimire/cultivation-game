class_name TitleBackdrop
extends Control
## GFX-105: the title-screen backdrop as a code-drawn 320x200 pixel scene (dithered night sky, pixel moon and stars,
## three jagged mountain ranges, a pavilion on a peak, pines, a robed figure on a rock) shown at an integer scale with
## nearest filtering. Drifting pixel clouds and twinkling stars move in _process (nothing moves with `reduce_motion`).
## No binary assets; all randomness comes from a fixed-seed RandomNumberGenerator.

const W := 320
const H := 200
const SEED := 7
const SKY_TOP := Color(0.04, 0.05, 0.14)
const SKY_MID := Color(0.10, 0.09, 0.24)
const SKY_LOW := Color(0.26, 0.17, 0.34)
const MOON := Color(0.95, 0.94, 0.84)
const MOON_SHADE := Color(0.80, 0.80, 0.72)
const MOON_RIM := Color(0.70, 0.72, 0.66)
const STAR := Color(0.92, 0.92, 1.0)
const CLOUD := Color(0.62, 0.60, 0.78, 0.38)
## Per range: base ridge row, wobble amplitude, sine frequency, phase, colour.
const RANGES: Array[Dictionary] = [
	{"base": 112, "amp": 20.0, "freq": 1.4, "phase": 0.6, "color": Color(0.20, 0.18, 0.36)},
	{"base": 140, "amp": 16.0, "freq": 2.1, "phase": 2.3, "color": Color(0.12, 0.11, 0.25)},
	{"base": 168, "amp": 11.0, "freq": 2.8, "phase": 4.4, "color": Color(0.06, 0.06, 0.14)},
]
const MOON_POS := Vector2i(262, 38)
const PAVILION_X := 214

var _time: float = 0.0
var _image: Image
var _texture: ImageTexture
var _stars: Array[Vector2i] = []
var _clouds: Array[Dictionary] = []
var _cloud_shift: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image = build_scene()
	_texture = ImageTexture.create_from_image(_image)
	_stars = star_positions()
	_clouds = cloud_strips()


func _process(delta: float) -> void:
	if reduced_motion():
		return
	_time += delta
	_cloud_shift = _time
	queue_redraw()


static func reduced_motion() -> bool:
	return bool(Settings.get_value("reduce_motion"))


## Integer scale of the 320x200 canvas inside a screen of `screen` pixels (at least 1).
static func pixel_scale(screen: Vector2) -> int:
	return maxi(1, int(floor(minf(screen.x / W, screen.y / H))))


## Top-left of the scaled canvas, centred in `screen`.
static func canvas_origin(screen: Vector2) -> Vector2:
	var s := pixel_scale(screen)
	return Vector2((screen.x - W * s) / 2.0, (screen.y - H * s) / 2.0).floor()


## Ridge row (whole pixels, smaller = higher) of `range_index` at column x. Deterministic.
static func ridge_row(range_index: int, x: int) -> int:
	var r: Dictionary = RANGES[range_index]
	var f: float = r["freq"]
	var p: float = r["phase"]
	var u := float(x) / W
	var wave := sin(u * TAU * f + p) * 0.55 + sin(u * TAU * f * 2.7 + p * 1.9) * 0.3 + sin(u * TAU * f * 6.1 + p * 0.7) * 0.15
	return int(round(float(r["base"]) - float(r["amp"]) * wave))


## The 36 fixed star pixels (upper sky, away from the moon).
static func star_positions() -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var out: Array[Vector2i] = []
	while out.size() < 36:
		var p := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, 92))
		if Vector2(p).distance_to(Vector2(MOON_POS)) > 18.0:
			out.append(p)
	return out


## Cloud strips: {y, x, len, speed}. x is the start column before drifting.
static func cloud_strips() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var out: Array[Dictionary] = []
	for i in 3:
		out.append({"y": 54 + i * 24 + rng.randi_range(0, 6), "x": rng.randi_range(0, W), "len": rng.randi_range(70, 110), "speed": 2.0 + i * 2.0})
	return out


## The static 320x200 scene. Same pixels every call.
static func build_scene() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	_paint_sky(img)
	_paint_moon(img)
	for p in star_positions():
		img.set_pixelv(p, STAR)
	for i in RANGES.size():
		_paint_range(img, i)
	_paint_pavilion(img)
	_paint_pines(img)
	_paint_rock_and_figure(img)
	return img


static func _paint_sky(img: Image) -> void:
	for y in H:
		for x in W:
			# Three bands; a 4-row checker dither blends each boundary.
			var c := SKY_TOP
			var d := (x + y) % 2 == 0
			if y >= 100 or (y >= 96 and d):
				c = SKY_LOW
			elif y >= 52 or (y >= 48 and d):
				c = SKY_MID
			img.set_pixel(x, y, c)


static func _paint_moon(img: Image) -> void:
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var d2 := dx * dx + dy * dy
			if d2 > 100:
				continue
			var c := MOON_RIM if d2 > 81 else MOON
			img.set_pixel(MOON_POS.x + dx, MOON_POS.y + dy, c)
	for crater in [Vector2i(-3, -3), Vector2i(4, 2)]:
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			img.set_pixelv(MOON_POS + crater + off, MOON_SHADE)


static func _paint_range(img: Image, index: int) -> void:
	var col: Color = RANGES[index]["color"]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 10 + index
	var jitter := 0
	for x in W:
		jitter = clampi(jitter + rng.randi_range(-1, 1), -2, 2)
		var top := clampi(ridge_row(index, x) + jitter, 0, H - 1)
		for y in range(top, H):
			img.set_pixel(x, y, col)
		# One lighter rim pixel on the crest gives the ridge an edge.
		img.set_pixel(x, top, col.lightened(0.18))


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < W and yy >= 0 and yy < H:
				img.set_pixel(xx, yy, c)


## Two-tier pavilion with upturned eaves, two red pillars and a lit window, on the middle range.
static func _paint_pavilion(img: Image) -> void:
	var base := ridge_row(0, PAVILION_X)
	for x in range(PAVILION_X - 9, PAVILION_X + 10):
		base = mini(base, ridge_row(0, x))
	var roof := Color(0.10, 0.08, 0.16)
	var pillar := Color(0.72, 0.16, 0.14)
	var win := Color(1.0, 0.85, 0.40)
	var floor_y := base + 2
	_rect(img, PAVILION_X - 8, floor_y, 17, 2, Color(0.08, 0.07, 0.12))
	_rect(img, PAVILION_X - 6, floor_y + 2, 13, 12, RANGES[0]["color"])
	_rect(img, PAVILION_X - 6, floor_y - 7, 2, 7, pillar)
	_rect(img, PAVILION_X + 5, floor_y - 7, 2, 7, pillar)
	_rect(img, PAVILION_X - 3, floor_y - 5, 6, 5, Color(0.14, 0.11, 0.18))
	img.set_pixel(PAVILION_X, floor_y - 3, win)
	img.set_pixel(PAVILION_X, floor_y - 4, win)
	# Lower roof with upturned tips, then upper tier and finial.
	_rect(img, PAVILION_X - 9, floor_y - 9, 19, 2, roof)
	img.set_pixel(PAVILION_X - 10, floor_y - 10, roof)
	img.set_pixel(PAVILION_X + 10, floor_y - 10, roof)
	_rect(img, PAVILION_X - 6, floor_y - 12, 13, 3, roof)
	img.set_pixel(PAVILION_X - 7, floor_y - 13, roof)
	img.set_pixel(PAVILION_X + 7, floor_y - 13, roof)
	_rect(img, PAVILION_X - 3, floor_y - 14, 7, 2, roof)
	_rect(img, PAVILION_X, floor_y - 17, 1, 3, roof)


static func _paint_pines(img: Image) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 30
	var col := Color(0.03, 0.04, 0.09)
	for i in 9:
		var x := 20 + i * 33 + rng.randi_range(-8, 8)
		var top := ridge_row(2, x) + 1
		var tall := rng.randi_range(14, 22)
		_rect(img, x, top - 2, 1, 4, col)
		for tier in 4:
			var half := 1 + tier * 2 * tall / 20
			var y := top - tall + tier * (tall / 4)
			_rect(img, x - half, y + tall / 4, half * 2 + 1, tall / 4 + 1, col)
		img.set_pixel(x, top - tall * 3 / 4 - 1, col)


## A rock in the foreground (right of the menu column) with a small robed figure gazing up at the pavilion.
static func _paint_rock_and_figure(img: Image) -> void:
	var rock := Color(0.09, 0.09, 0.17)
	var fx := 158
	var ground := 184
	_rect(img, fx - 9, ground - 2, 20, 4, rock)
	_rect(img, fx - 6, ground - 5, 14, 3, rock)
	_rect(img, fx - 3, ground - 7, 8, 2, rock)
	var robe := Color(0.82, 0.80, 0.70)
	var hair := Color(0.04, 0.04, 0.06)
	var top := ground - 7 - 9
	_rect(img, fx - 1, top, 3, 1, hair)
	_rect(img, fx - 1, top + 1, 3, 2, Color(0.88, 0.72, 0.58))
	_rect(img, fx - 1, top + 3, 3, 3, robe)
	_rect(img, fx - 2, top + 6, 5, 3, robe)
	img.set_pixel(fx + 2, top + 4, robe)
	_rect(img, fx - 2, top + 3, 1, 3, robe.darkened(0.25))


func _draw() -> void:
	if _texture == null:
		return
	var s := pixel_scale(size)
	var origin := canvas_origin(size)
	draw_rect(Rect2(Vector2.ZERO, size), SKY_TOP)
	draw_rect(Rect2(origin, Vector2(W, H) * s), SKY_TOP)
	draw_texture_rect(_texture, Rect2(origin, Vector2(W, H) * s), false)
	# Twinkle: a few stars dim and brighten.
	if not reduced_motion():
		for i in 4:
			var on := int(floor(_time * 1.3 + i * 1.7)) % 2 == 0
			if not on:
				draw_rect(Rect2(origin + Vector2(_stars[i * 7]) * s, Vector2(s, s)), SKY_TOP)
	for c in _clouds:
		var len: int = c["len"]
		var span := W + len
		var x0 := int(fposmod(float(c["x"]) - _cloud_shift * float(c["speed"]), float(span))) - len
		var y: int = c["y"]
		for row in 3:
			var inset := 0 if row == 1 else 6
			var a := maxi(x0 + inset, 0)
			var b := mini(x0 + len - inset, W)
			if b > a:
				draw_rect(Rect2(origin + Vector2(a, y + row * 2) * s, Vector2(b - a, 2) * s), CLOUD)
