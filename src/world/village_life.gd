class_name VillageLife
extends Node2D
## GFX-040: small looping ambient touches for a region: chimney smoke over houses, pond ripples
## and jumping fish, and a flock of birds crossing on clear days. One node per region, built by
## World. With reduce_motion the smoke/ripples/fish/birds are not created (the smoke emitters
## stay but do not emit, so a still frame shows nothing odd). Frozen (winter) ponds get no ripples.

const MAX_SMOKE_AMOUNT := 6
const RIPPLE_MIN := 3.0
const RIPPLE_MAX := 6.0
const FISH_GAP := 10.0
const BIRD_GAP := 40.0
const SMOKE_COLOR := Color(0.78, 0.78, 0.8, 0.5)

var _region: Dictionary = {}
var _season := "Spring"
var _weather := "clear"
var _reduce := false
var _map_size := Vector2(1600, 1000)
var _ponds: Array[Rect2] = []
var _ripple_clock := 0.0
var _fish_clock := 0.0
var _bird_clock := 0.0
var _ripples: Array[Dictionary] = []
var _fish: Dictionary = {}
var _birds: Array[Vector2] = []
var _bird_t := -1.0
var _bird_y := 40.0
var _seed := 0
var _count := 0


## A smoke emitter at `pos` (a chimney top): few grey puffs rising with a sway; fewer in summer.
static func make_smoke(pos: Vector2, season: String, reduce_motion: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Smoke"
	p.amount = 3 if season == "Summer" else 5
	p.lifetime = 3.5
	p.position = pos
	p.direction = Vector2(0.15, -1.0)
	p.spread = 12.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector2(3, -2)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = SMOKE_COLOR
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.7))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	p.local_coords = false
	p.emitting = not reduce_motion
	p.z_index = 40
	return p


## True if ponds are frozen (no ripples, no fish): winter.
static func pond_frozen(season: String) -> bool:
	return Scenery.is_snowy(season)


## True when a bird flock may cross: clear weather and motion allowed.
static func birds_fly(weather: String, reduce_motion: bool) -> bool:
	return weather == "clear" and not reduce_motion


## Deterministic point inside the ellipse of `rect` for the n-th event of a region seed.
static func point_in(rect: Rect2, seed_value: int, n: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, n, rect.position.x, rect.position.y])
	var a := rng.randf() * TAU
	var d := sqrt(rng.randf()) * 0.8
	return rect.get_center() + Vector2(cos(a) * rect.size.x / 2.0, sin(a) * rect.size.y / 2.0) * d


## Rebuilds the effects for a region; `rid` seeds the ripple points.
func setup(region: Dictionary, season: String, weather: String, reduce_motion: bool, map_size: Vector2) -> void:
	for c in get_children():
		c.queue_free()
	_region = region
	_season = season
	_weather = weather
	_reduce = reduce_motion
	_map_size = map_size
	_seed = hash(str(region.get("id", "")))
	_ponds.clear()
	_ripples.clear()
	_fish = {}
	_birds.clear()
	_bird_t = -1.0
	z_index = 41
	for lm: Dictionary in region.get("map", {}).get("landmarks", []):
		var size := Vector2(float(lm["size"][0]), float(lm["size"][1]))
		var rect := Rect2(Vector2(float(lm["pos"][0]), float(lm["pos"][1])) - size / 2.0, size)
		match String(lm.get("kind", "")):
			"house":
				add_child(make_smoke(rect.position + Vector2(size.x * 0.72, 4), season, reduce_motion))
			"pond":
				if not pond_frozen(season) and not reduce_motion:
					_ponds.append(rect)
	# GFX-067: a smithy's chimney smokes steadily.
	for pl: Dictionary in region.get("places", []):
		if String(pl.get("type", "")) == "merchant" and float(pl["size"][0]) >= PixelPlace.SHOP_MIN_WIDTH \
				and PixelPlace.shop_look(String(pl.get("display_name", ""))) == "shop_smithy":
			var psize := Vector2(float(pl["size"][0]), float(pl["size"][1]))
			var ppos := Vector2(float(pl["pos"][0]), float(pl["pos"][1]))
			var smoke := make_smoke(ppos + PixelPlace.smithy_smoke_offset(psize), season, reduce_motion)
			smoke.name = "SmithySmoke"
			smoke.amount = 8
			add_child(smoke)
	set_process(not reduce_motion)
	queue_redraw()


func _process(delta: float) -> void:
	if _reduce:
		return
	var moving := false
	if not _ponds.is_empty():
		_ripple_clock -= delta
		if _ripple_clock <= 0.0:
			_count += 1
			var rect := _ponds[_count % _ponds.size()]
			_ripples.append({"pos": point_in(rect, _seed, _count), "t": 0.0})
			_ripple_clock = lerpf(RIPPLE_MIN, RIPPLE_MAX, fposmod(float(hash([_seed, _count])), 100.0) / 100.0)
		_fish_clock -= delta
		if _fish_clock <= 0.0 and _fish.is_empty():
			_count += 1
			_fish = {"pos": point_in(_ponds[_count % _ponds.size()], _seed, _count), "t": 0.0}
			_fish_clock = FISH_GAP
		moving = true
	for r in _ripples:
		r["t"] = float(r["t"]) + delta
	_ripples = _ripples.filter(func(r: Dictionary) -> bool: return float(r["t"]) < 1.6)
	if not _fish.is_empty():
		_fish["t"] = float(_fish["t"]) + delta
		if float(_fish["t"]) > 0.7:
			_fish = {}
	if birds_fly(_weather, _reduce):
		_bird_clock -= delta
		if _bird_t < 0.0 and _bird_clock <= 0.0:
			_bird_t = 0.0
			_bird_y = 30.0 + fposmod(float(hash([_seed, _count + 7])), 60.0)
			_bird_clock = BIRD_GAP
		if _bird_t >= 0.0:
			_bird_t += delta
			if _bird_t * 60.0 > _map_size.x + 80.0:
				_bird_t = -1.0
		moving = true
	if moving:
		queue_redraw()


func _draw() -> void:
	for r in _ripples:
		var t := float(r["t"]) / 1.6
		draw_arc(r["pos"], 2.0 + t * 9.0, 0.0, TAU, 16, Color(1, 1, 1, 0.6 * (1.0 - t)), 1.0)
	if not _fish.is_empty():
		var t := float(_fish["t"]) / 0.7
		var p: Vector2 = _fish["pos"]
		var h := sin(t * PI) * 4.0
		draw_rect(Rect2(p + Vector2(-2, -h - 1), Vector2(4, 1)), Color("dfe8f0"))
		draw_rect(Rect2(p + Vector2(-2, -h), Vector2(2, 1)), Color("8fb0c8"))
	if _bird_t >= 0.0:
		var x0 := -40.0 + _bird_t * 60.0
		for i in 4:
			var bp := Vector2(x0 - i * 14.0, _bird_y + (i % 2) * 8.0 + sin(_bird_t * 2.0 + i) * 2.0)
			var flap := int(_bird_t * 6.0 + i) % 2
			draw_rect(Rect2(bp, Vector2(1, 1)), Color("2a2a30"))
			draw_rect(Rect2(bp + Vector2(-1, flap), Vector2(1, 1)), Color("2a2a30"))
			draw_rect(Rect2(bp + Vector2(1, flap), Vector2(1, 1)), Color("2a2a30"))
