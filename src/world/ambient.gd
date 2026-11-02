class_name Ambient
extends RefCounted
## Ambient particle presets for the world scene (WU-057). Particles are plain
## squares tinted via `color`; low alpha and few of them keep places readable.

## Kinds a region's map.ambient may name.
const KINDS: PackedStringArray = Scenery.AMBIENT_KINDS
const MAX_AMOUNT := 40

const PRESETS := {
	"petals": {"amount": 24, "color": Color(1.0, 0.75, 0.82, 0.55), "gravity": Vector2(6, 14), "speed": 8.0, "size": 3.0, "lifetime": 9.0},
	"leaves": {"amount": 24, "color": Color(0.85, 0.5, 0.2, 0.55), "gravity": Vector2(-8, 16), "speed": 10.0, "size": 3.5, "lifetime": 9.0},
	"snow": {"amount": 40, "color": Color(1.0, 1.0, 1.0, 0.6), "gravity": Vector2(-4, 18), "speed": 6.0, "size": 2.5, "lifetime": 10.0},
	"mist": {"amount": 14, "color": Color(0.85, 0.9, 0.9, 0.12), "gravity": Vector2(5, 0), "speed": 6.0, "size": 40.0, "lifetime": 14.0},
	"embers": {"amount": 24, "color": Color(1.0, 0.55, 0.2, 0.7), "gravity": Vector2(0, -14), "speed": 10.0, "size": 2.5, "lifetime": 6.0},
	"fireflies": {"amount": 20, "color": Color(0.95, 1.0, 0.45, 0.7), "gravity": Vector2.ZERO, "speed": 12.0, "size": 2.5, "lifetime": 7.0},
}

## Weather presets (WU-399), not region-selectable: rain is drawn as 1x5 streaks, fog as sheets.
const RAIN := {"amount": 450, "color": Color("c8d8f0", 0.7), "gravity": Vector2(70, 420), "speed": 40.0, "size": 1.0, "lifetime": 2.5}
const STORM_TINT := Color(0.62, 0.66, 0.78)
const LIGHTNING_MIN_SECONDS := 6.0
const LIGHTNING_MAX_SECONDS := 14.0
const FLASH_SECONDS := 0.08
const FLASH_ALPHA := 0.35
const CLOUDY_TINT := Color(0.9, 0.9, 0.9)
## GFX-055: a rainy day is visibly greyer and cooler than a clear one (it was untinted).
const RAIN_TINT := Color(0.84, 0.88, 0.95)
const FOG_SHEETS := 2
## GFX-044: presets with a `size` at or above this draw a soft round blob instead of a square.
const SOFT_MIN_SIZE := 16.0
const SOFT_TEX_SIZE := 32
## Fraction of a fog sheet's width over which its alpha fades out at each side.
const FOG_EDGE := 0.25

static var _soft_tex: ImageTexture
static var _fog_tex: Dictionary = {}


## A 32 px radial gradient, alpha 1 at the centre to 0 at the edge; built once and cached.
static func soft_texture() -> ImageTexture:
	if _soft_tex == null:
		var n := SOFT_TEX_SIZE
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var mid := (n - 1) / 2.0
		for y in n:
			for x in n:
				var d := Vector2(x - mid, y - mid).length() / (n / 2.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex


## A fog sheet texture: alpha 1 in the middle, fading to 0 over the outer FOG_EDGE of the width (and height).
static func fog_texture(w: int = 64, h: int = 64) -> ImageTexture:
	var key := Vector2i(w, h)
	if not _fog_tex.has(key):
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var ax := minf(x + 0.5, w - x - 0.5) / (w * FOG_EDGE)
				var ay := minf(y + 0.5, h - y - 0.5) / (h * FOG_EDGE)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(minf(ax, ay), 0.0, 1.0)))
		_fog_tex[key] = ImageTexture.create_from_image(img)
	return _fog_tex[key]


## What the world draws for a day's weather: {"emitter": preset name or "", "fog": bool, "tint": Color}.
## Rain, snow and fog replace the season ambient; cloudy only dims the light; clear changes nothing.
static func weather_plan(kind: String) -> Dictionary:
	match kind:
		"rain":
			return {"emitter": "rain", "fog": false, "tint": RAIN_TINT}
		"snow":
			return {"emitter": "snow", "fog": false, "tint": Color.WHITE}
		"storm":
			return {"emitter": "storm", "fog": false, "tint": STORM_TINT}
		"fog":
			return {"emitter": "", "fog": true, "tint": Color.WHITE}
		"cloudy":
			return {"emitter": "", "fog": false, "tint": CLOUDY_TINT}
	return {"emitter": "", "fog": false, "tint": Color.WHITE}


## True when the weather takes the place of the season's ambient particles.
static func replaces_season(kind: String) -> bool:
	return kind == "rain" or kind == "storm" or kind == "snow" or kind == "fog"


## Rain: a CPUParticles2D of slanted 2x8 px streaks (GFX-055: were 1x5 and invisible at 1280x800) over `area`.
static func make_rain(area: Vector2) -> CPUParticles2D:
	var p := make_emitter("snow", area)
	p.name = "Rain"
	p.amount = int(RAIN["amount"])
	p.lifetime = float(RAIN["lifetime"])
	p.preprocess = p.lifetime
	p.initial_velocity_min = float(RAIN["speed"]) * 0.5
	p.initial_velocity_max = float(RAIN["speed"])
	p.gravity = RAIN["gravity"]
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color = RAIN["color"]
	var img := Image.create(2, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	p.particle_flag_align_y = true
	return p


## True on days that leave the ground wet (rain and storm).
static func is_wet(kind: String) -> bool:
	return kind == "rain" or kind == "storm"


## Storm rain: the rain emitter at 1.5x density.
static func make_storm_rain(area: Vector2) -> CPUParticles2D:
	var p := make_rain(area)
	p.amount = int(RAIN["amount"] * 1.5)
	return p


## Seconds until the next lightning flash, 6-14 s, seeded from the day and the strike number.
static func lightning_gap(day: int, n: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, n, "lightning"])
	return rng.randf_range(LIGHTNING_MIN_SECONDS, LIGHTNING_MAX_SECONDS)


## Whether lightning flashes at all: never with reduce_motion.
static func lightning_enabled(reduce_motion: bool) -> bool:
	return not reduce_motion


## Fog: two large translucent sheets drifting slowly in opposite directions; the caller adds the node.
## `strength` (0..1, a region's map.mist) scales the sheets' alpha.
static func make_fog(area: Vector2, animate: bool, strength: float = 1.0) -> Node2D:
	var root := Node2D.new()
	root.name = "Fog"
	root.z_index = 50
	for i in FOG_SHEETS:
		var sheet := TextureRect.new()
		sheet.texture = fog_texture()
		sheet.stretch_mode = TextureRect.STRETCH_SCALE
		sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sheet.modulate = Color(0.88, 0.92, 0.94, 0.16 * clampf(strength, 0.0, 1.0))
		sheet.size = area * 1.4
		sheet.position = Vector2(-area.x * 0.2, -area.y * 0.2)
		sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(sheet)
		if animate:
			var dx := 60.0 if i == 0 else -60.0
			var tween := sheet.create_tween().set_loops()
			tween.tween_property(sheet, "position:x", sheet.position.x + dx, 20.0)
			tween.tween_property(sheet, "position:x", sheet.position.x, 20.0)
	return root


## The kind shown in a season ("Spring"...), from a map.ambient dict
## ({"spring": "petals", "any": "mist"}); "" for none. A season entry wins over "any".
static func kind_for(ambient: Dictionary, season: String) -> String:
	var kind := String(ambient.get(season.to_lower(), ambient.get("any", "")))
	return kind if KINDS.has(kind) else ""


## A CPUParticles2D covering `area` for the kind, or null for an unknown kind.
## `strength` (0..1, a region's map.mist) scales the "mist" preset's alpha.
static func make_emitter(kind: String, area: Vector2, strength: float = 1.0) -> CPUParticles2D:
	if not PRESETS.has(kind):
		return null
	var preset: Dictionary = PRESETS[kind]
	var p := CPUParticles2D.new()
	p.name = "Ambient"
	p.amount = mini(int(preset["amount"]), MAX_AMOUNT)
	p.lifetime = float(preset["lifetime"])
	p.preprocess = p.lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2.0
	p.position = area / 2.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = float(preset["speed"]) * 0.3
	p.initial_velocity_max = float(preset["speed"])
	p.gravity = preset["gravity"]
	p.scale_amount_min = float(preset["size"]) * 0.6
	p.scale_amount_max = float(preset["size"])
	p.color = preset["color"]
	if kind == "mist":
		p.color.a *= clampf(strength, 0.0, 1.0)
	if float(preset["size"]) >= SOFT_MIN_SIZE:
		p.texture = soft_texture()
		# The 32 px texture is the particle: scale 1.0 = 32 px, so size / 32.
		p.scale_amount_min = float(preset["size"]) * 0.6 / SOFT_TEX_SIZE
		p.scale_amount_max = float(preset["size"]) / SOFT_TEX_SIZE
	p.z_index = 50
	return p
